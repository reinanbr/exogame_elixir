<?php
/**
 * Bench – PHP/Swoole (CRUD + WebSocket pub/sub)
 * Runs a single process with coroutines.
 */

use Swoole\Http\Server;
use Swoole\Http\Request;
use Swoole\Http\Response;
use Swoole\WebSocket\Server as WsServer;
use Swoole\WebSocket\Frame;
use Swoole\Coroutine\PostgreSQL;

$dbHost = getenv('DB_HOST') ?: 'postgres';
$dsn = "host={$dbHost} port=5432 dbname=bench user=bench password=bench";

// ── Connection pool (simple channel-based) ───────────────────────────
$pool = new Swoole\Coroutine\Channel(50);
function initPool(string $dsn, Swoole\Coroutine\Channel $pool, int $size = 50): void {
    for ($i = 0; $i < $size; $i++) {
        $pg = new PostgreSQL();
        $ok = $pg->connect($dsn);
        if ($ok) $pool->push($pg);
    }
}
function getConn(Swoole\Coroutine\Channel $pool): PostgreSQL {
    return $pool->pop();
}
function putConn(Swoole\Coroutine\Channel $pool, PostgreSQL $pg): void {
    $pool->push($pg);
}

// ── WS Hub ───────────────────────────────────────────────────────────
$topics = [];  // topic => [fd => true]

function wsSubscribe(int $fd, string $topic): void {
    global $topics;
    $topics[$topic][$fd] = true;
}
function wsUnsubscribe(int $fd): void {
    global $topics;
    foreach ($topics as $t => &$fds) {
        unset($fds[$fd]);
    }
}
function wsBroadcast(WsServer $server, string $topic, string $msg): void {
    global $topics;
    foreach (($topics[$topic] ?? []) as $fd => $_) {
        if ($server->isEstablished($fd)) {
            $server->push($fd, $msg);
        }
    }
}

// ── Server ───────────────────────────────────────────────────────────
$server = new WsServer('0.0.0.0', 8080);
$server->set([
    'worker_num' => swoole_cpu_num(),
    'max_connection' => 120000,
    'open_http2_protocol' => false,
    'buffer_output_size' => 2 * 1024 * 1024,
]);

$server->on('workerStart', function () use ($dsn, $pool) {
    // Wait for DB
    for ($i = 0; $i < 30; $i++) {
        $pg = new PostgreSQL();
        if ($pg->connect($dsn)) {
            $pool->push($pg);
            initPool($dsn, $pool, 49);
            return;
        }
        Swoole\Coroutine::sleep(1);
    }
});

$server->on('request', function (Request $req, Response $res) use ($pool) {
    $method = $req->server['request_method'];
    $uri = $req->server['request_uri'];

    $res->header('Content-Type', 'application/json');

    // POST /items
    if ($method === 'POST' && $uri === '/items') {
        $body = json_decode($req->rawContent(), true);
        if (!$body || !isset($body['name'], $body['value'])) {
            $res->status(400);
            $res->end(json_encode(['error' => 'bad request']));
            return;
        }
        $pg = getConn($pool);
        $result = $pg->query(sprintf(
            "INSERT INTO items(name,value) VALUES('%s','%s') RETURNING id,name,value,created_at::text",
            $pg->escape($body['name']), $pg->escape($body['value'])
        ));
        $row = $pg->fetchAssoc($result);
        putConn($pool, $pg);
        $res->status(201);
        $res->end(json_encode($row));
        return;
    }

    // GET /items/{id}
    if ($method === 'GET' && preg_match('#^/items/(\d+)$#', $uri, $m)) {
        $pg = getConn($pool);
        $result = $pg->query("SELECT id,name,value,created_at::text FROM items WHERE id=" . intval($m[1]));
        $row = $pg->fetchAssoc($result);
        putConn($pool, $pg);
        if (!$row) {
            $res->status(404);
            $res->end(json_encode(['error' => 'not found']));
            return;
        }
        $res->end(json_encode($row));
        return;
    }

    $res->status(404);
    $res->end(json_encode(['error' => 'not found']));
});

$server->on('open', function (WsServer $server, Request $req) {});

$server->on('message', function (WsServer $server, Frame $frame) {
    $msg = json_decode($frame->data, true);
    if (!$msg) return;
    $action = $msg['action'] ?? '';
    $topic = $msg['topic'] ?? 'default';
    switch ($action) {
        case 'subscribe':
            wsSubscribe($frame->fd, $topic);
            break;
        case 'broadcast':
            $payload = json_encode($msg['payload'] ?? new \stdClass());
            wsBroadcast($server, $topic, $payload);
            break;
    }
});

$server->on('close', function (WsServer $server, int $fd) {
    wsUnsubscribe($fd);
});

$server->start();
