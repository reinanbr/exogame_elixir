const std = @import("std");
const zap = @import("zap");
const pg = @import("pg");

const Allocator = std.mem.Allocator;

// ── Global state ──────────────────────────────────────────────────────
var pool: *pg.Pool = undefined;
var ws_hub: WsHub = undefined;

// ── WebSocket Hub ─────────────────────────────────────────────────────
const WsHub = struct {
    clients: std.AutoHashMap(*zap.WebSocket, void),
    mutex: std.Thread.Mutex,

    fn init(alloc: Allocator) WsHub {
        return .{
            .clients = std.AutoHashMap(*zap.WebSocket, void).init(alloc),
            .mutex = .{},
        };
    }

    fn add(self: *WsHub, ws: *zap.WebSocket) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.clients.put(ws, {}) catch {};
    }

    fn remove(self: *WsHub, ws: *zap.WebSocket) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        _ = self.clients.remove(ws);
    }

    fn broadcast(self: *WsHub, msg: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        var it = self.clients.keyIterator();
        while (it.next()) |ws_ptr| {
            ws_ptr.*.send(.{ .text = msg }) catch {};
        }
    }
};

// ── JSON helpers ──────────────────────────────────────────────────────
fn jsonItem(alloc: Allocator, id: i32, name: []const u8, value: []const u8) ![]const u8 {
    return std.fmt.allocPrint(alloc,
        \\{{"id":{d},"name":"{s}","value":"{s}"}}
    , .{ id, name, value });
}

fn parseJsonField(body: []const u8, field: []const u8) ?[]const u8 {
    const needle = std.fmt.comptimePrint("\"{s}\":", .{field});
    const idx = std.mem.indexOf(u8, body, needle) orelse return null;
    const start_raw = idx + needle.len;
    // skip whitespace
    var start = start_raw;
    while (start < body.len and (body[start] == ' ' or body[start] == '"')) : (start += 1) {}
    if (body[start - 1] == '"') {
        const end = std.mem.indexOfPos(u8, body, start, "\"") orelse return null;
        return body[start..end];
    }
    return null;
}

// ── HTTP handlers ─────────────────────────────────────────────────────
fn handlePostItems(r: zap.Request) void {
    const alloc = std.heap.page_allocator;
    const body = r.body orelse {
        r.setStatus(.bad_request);
        r.sendBody("{\"error\":\"empty body\"}") catch {};
        return;
    };

    const name = parseJsonField(body, "name") orelse {
        r.setStatus(.bad_request);
        r.sendBody("{\"error\":\"missing name\"}") catch {};
        return;
    };
    const value = parseJsonField(body, "value") orelse "";

    const conn = pool.acquire() catch {
        r.setStatus(.service_unavailable);
        r.sendBody("{\"error\":\"db\"}") catch {};
        return;
    };
    defer conn.release();

    const result = conn.queryOpts(
        "INSERT INTO items (name, value) VALUES ($1, $2) RETURNING id, name, value",
        .{ name, value },
        .{ .column_format = .text },
    ) catch {
        r.setStatus(.internal_server_error);
        r.sendBody("{\"error\":\"query failed\"}") catch {};
        return;
    };
    defer result.deinit();

    if (result.next()) |row| {
        const id = row.get(i32, 0);
        const rname = row.get([]const u8, 1);
        const rvalue = row.get([]const u8, 2);
        const json_resp = jsonItem(alloc, id, rname, rvalue) catch {
            r.setStatus(.internal_server_error);
            return;
        };
        defer alloc.free(json_resp);
        r.setStatus(.created);
        r.setHeader("Content-Type", "application/json") catch {};
        r.sendBody(json_resp) catch {};
    }
}

fn handleGetItem(r: zap.Request) void {
    const alloc = std.heap.page_allocator;
    // Extract id from path /items/{id}
    const path = r.path orelse {
        r.setStatus(.bad_request);
        return;
    };
    const prefix = "/items/";
    if (!std.mem.startsWith(u8, path, prefix)) {
        r.setStatus(.not_found);
        return;
    }
    const id_str = path[prefix.len..];
    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        r.setStatus(.bad_request);
        r.sendBody("{\"error\":\"invalid id\"}") catch {};
        return;
    };

    const conn = pool.acquire() catch {
        r.setStatus(.service_unavailable);
        return;
    };
    defer conn.release();

    const result = conn.queryOpts(
        "SELECT id, name, value FROM items WHERE id=$1",
        .{id},
        .{ .column_format = .text },
    ) catch {
        r.setStatus(.internal_server_error);
        return;
    };
    defer result.deinit();

    if (result.next()) |row| {
        const rid = row.get(i32, 0);
        const rname = row.get([]const u8, 1);
        const rvalue = row.get([]const u8, 2);
        const json_resp = jsonItem(alloc, rid, rname, rvalue) catch {
            r.setStatus(.internal_server_error);
            return;
        };
        defer alloc.free(json_resp);
        r.setHeader("Content-Type", "application/json") catch {};
        r.sendBody(json_resp) catch {};
    } else {
        r.setStatus(.not_found);
        r.sendBody("{\"error\":\"not found\"}") catch {};
    }
}

fn onRequest(r: zap.Request) void {
    const path = r.path orelse return;
    const method = r.method orelse return;

    if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/items")) {
        handlePostItems(r);
    } else if (std.mem.eql(u8, method, "GET") and std.mem.startsWith(u8, path, "/items/")) {
        handleGetItem(r);
    } else {
        r.setStatus(.not_found);
        r.sendBody("{\"error\":\"not found\"}") catch {};
    }
}

// ── WebSocket handlers ────────────────────────────────────────────────
fn onWsOpen(ws: *zap.WebSocket) void {
    ws_hub.add(ws);
}

fn onWsClose(ws: *zap.WebSocket) void {
    ws_hub.remove(ws);
}

fn onWsMessage(ws: *zap.WebSocket, msg: []const u8) void {
    _ = ws;
    // Broadcast to all connected clients
    ws_hub.broadcast(msg);
}

// ── Main ──────────────────────────────────────────────────────────────
pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const db_host = std.posix.getenv("DB_HOST") orelse "postgres";
    const conninfo = std.fmt.allocPrint(
        alloc,
        "host={s} port=5432 dbname=bench user=bench password=bench",
        .{db_host},
    ) catch unreachable;

    // Retry DB connection
    var retries: u32 = 0;
    while (retries < 30) : (retries += 1) {
        pool = pg.Pool.init(alloc, .{ .connection_string = conninfo, .size = 16 }) catch {
            std.time.sleep(1_000_000_000);
            continue;
        };
        break;
    }

    ws_hub = WsHub.init(alloc);

    var listener = zap.HttpListener.init(.{
        .port = 8080,
        .on_request = onRequest,
        .max_connections = 120_000,
        .num_workers = 4,
    });
    listener.addWebSocketHandler("/ws", .{
        .on_open = onWsOpen,
        .on_close = onWsClose,
        .on_message = onWsMessage,
    }) catch {};

    listener.listen() catch |err| {
        std.log.err("Failed to start listener: {}", .{err});
        return err;
    };

    std.log.info("Zig/Zap server listening on :8080", .{});

    listener.run();
}
