/*
 * Benchmark C server using Mongoose (embedded HTTP/WebSocket) + libpq
 * API: POST /items, GET /items/:id, WS /ws
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include "mongoose.h"
#include <libpq-fe.h>

#define MAX_WS_CLIENTS 120000
#define LISTEN_URL     "http://0.0.0.0:8080"

/* ── WebSocket Hub ─────────────────────────────────────────────────── */
static struct mg_connection *ws_clients[MAX_WS_CLIENTS];
static int ws_count = 0;
static pthread_mutex_t ws_mutex = PTHREAD_MUTEX_INITIALIZER;

static void hub_add(struct mg_connection *c) {
    pthread_mutex_lock(&ws_mutex);
    if (ws_count < MAX_WS_CLIENTS) ws_clients[ws_count++] = c;
    pthread_mutex_unlock(&ws_mutex);
}

static void hub_remove(struct mg_connection *c) {
    pthread_mutex_lock(&ws_mutex);
    for (int i = 0; i < ws_count; i++) {
        if (ws_clients[i] == c) {
            ws_clients[i] = ws_clients[--ws_count];
            break;
        }
    }
    pthread_mutex_unlock(&ws_mutex);
}

static void hub_broadcast(const char *msg, size_t len) {
    pthread_mutex_lock(&ws_mutex);
    for (int i = 0; i < ws_count; i++) {
        mg_ws_send(ws_clients[i], msg, len, WEBSOCKET_OP_TEXT);
    }
    pthread_mutex_unlock(&ws_mutex);
}

/* ── PostgreSQL connection pool (simple array) ─────────────────────── */
#define POOL_SIZE 16
static PGconn *pg_pool[POOL_SIZE];
static int pg_used[POOL_SIZE];
static pthread_mutex_t pg_mutex = PTHREAD_MUTEX_INITIALIZER;

static PGconn *pg_acquire(void) {
    pthread_mutex_lock(&pg_mutex);
    for (int i = 0; i < POOL_SIZE; i++) {
        if (!pg_used[i]) {
            pg_used[i] = 1;
            pthread_mutex_unlock(&pg_mutex);
            return pg_pool[i];
        }
    }
    pthread_mutex_unlock(&pg_mutex);
    return NULL; /* all busy */
}

static void pg_release(PGconn *conn) {
    pthread_mutex_lock(&pg_mutex);
    for (int i = 0; i < POOL_SIZE; i++) {
        if (pg_pool[i] == conn) { pg_used[i] = 0; break; }
    }
    pthread_mutex_unlock(&pg_mutex);
}

static int pg_pool_init(void) {
    const char *host = getenv("DB_HOST");
    if (!host) host = "postgres";
    char conninfo[256];
    snprintf(conninfo, sizeof(conninfo),
             "host=%s port=5432 dbname=bench user=bench password=bench", host);

    for (int attempt = 0; attempt < 30; attempt++) {
        PGconn *test = PQconnectdb(conninfo);
        if (PQstatus(test) == CONNECTION_OK) {
            PQfinish(test);
            for (int i = 0; i < POOL_SIZE; i++) {
                pg_pool[i] = PQconnectdb(conninfo);
                pg_used[i] = 0;
                if (PQstatus(pg_pool[i]) != CONNECTION_OK) {
                    fprintf(stderr, "PG connect failed: %s\n", PQerrorMessage(pg_pool[i]));
                    return -1;
                }
            }
            return 0;
        }
        PQfinish(test);
        fprintf(stderr, "DB not ready, retrying (%d/30)...\n", attempt + 1);
        sleep(1);
    }
    return -1;
}

/* ── JSON helpers ──────────────────────────────────────────────────── */
/* Very minimal JSON field extraction (finds "key":"value") */
static int json_get_string(const char *json, size_t json_len,
                           const char *key, char *out, size_t out_sz) {
    char needle[128];
    snprintf(needle, sizeof(needle), "\"%s\"", key);
    const char *p = memmem(json, json_len, needle, strlen(needle));
    if (!p) return -1;
    p += strlen(needle);
    while (*p == ' ' || *p == ':' || *p == '\t') p++;
    if (*p != '"') return -1;
    p++;
    const char *end = strchr(p, '"');
    if (!end) return -1;
    size_t len = (size_t)(end - p);
    if (len >= out_sz) len = out_sz - 1;
    memcpy(out, p, len);
    out[len] = '\0';
    return 0;
}

/* ── HTTP/WS event handler ─────────────────────────────────────────── */
static void ev_handler(struct mg_connection *c, int ev, void *ev_data) {
    if (ev == MG_EV_HTTP_MSG) {
        struct mg_http_message *hm = (struct mg_http_message *)ev_data;

        /* WebSocket upgrade */
        if (mg_match(hm->uri, mg_str("/ws"), NULL)) {
            mg_ws_upgrade(c, hm, NULL);
            return;
        }

        /* POST /items */
        if (mg_match(hm->uri, mg_str("/items")) &&
            mg_strcmp(hm->method, mg_str("POST")) == 0) {
            char name[256] = {0}, value[1024] = {0};
            if (json_get_string(hm->body.buf, hm->body.len, "name", name, sizeof(name)) < 0) {
                mg_http_reply(c, 400, "Content-Type: application/json\r\n",
                              "{\"error\":\"missing name\"}");
                return;
            }
            json_get_string(hm->body.buf, hm->body.len, "value", value, sizeof(value));

            PGconn *pg = pg_acquire();
            if (!pg) {
                mg_http_reply(c, 503, "", "{\"error\":\"db busy\"}");
                return;
            }
            const char *params[2] = {name, value};
            PGresult *res = PQexecParams(pg,
                "INSERT INTO items (name, value) VALUES ($1, $2) RETURNING id, name, value",
                2, NULL, params, NULL, NULL, 0);
            if (PQresultStatus(res) == PGRES_TUPLES_OK && PQntuples(res) > 0) {
                char buf[2048];
                snprintf(buf, sizeof(buf),
                         "{\"id\":%s,\"name\":\"%s\",\"value\":\"%s\"}",
                         PQgetvalue(res, 0, 0),
                         PQgetvalue(res, 0, 1),
                         PQgetvalue(res, 0, 2));
                mg_http_reply(c, 201, "Content-Type: application/json\r\n", "%s", buf);
            } else {
                mg_http_reply(c, 500, "", "{\"error\":\"insert failed\"}");
            }
            PQclear(res);
            pg_release(pg);
            return;
        }

        /* GET /items/:id */
        if (mg_match(hm->uri, mg_str("/items/*"), NULL) &&
            mg_strcmp(hm->method, mg_str("GET")) == 0) {
            /* Extract id */
            struct mg_str uri = hm->uri;
            const char *slash = uri.buf + 7; /* skip "/items/" */
            char id_str[32] = {0};
            size_t id_len = uri.len - 7;
            if (id_len >= sizeof(id_str)) id_len = sizeof(id_str) - 1;
            memcpy(id_str, slash, id_len);

            PGconn *pg = pg_acquire();
            if (!pg) {
                mg_http_reply(c, 503, "", "{\"error\":\"db busy\"}");
                return;
            }
            const char *params[1] = {id_str};
            PGresult *res = PQexecParams(pg,
                "SELECT id, name, value FROM items WHERE id=$1",
                1, NULL, params, NULL, NULL, 0);
            if (PQresultStatus(res) == PGRES_TUPLES_OK && PQntuples(res) > 0) {
                char buf[2048];
                snprintf(buf, sizeof(buf),
                         "{\"id\":%s,\"name\":\"%s\",\"value\":\"%s\"}",
                         PQgetvalue(res, 0, 0),
                         PQgetvalue(res, 0, 1),
                         PQgetvalue(res, 0, 2));
                mg_http_reply(c, 200, "Content-Type: application/json\r\n", "%s", buf);
            } else {
                mg_http_reply(c, 404, "", "{\"error\":\"not found\"}");
            }
            PQclear(res);
            pg_release(pg);
            return;
        }

        mg_http_reply(c, 404, "", "{\"error\":\"not found\"}");

    } else if (ev == MG_EV_WS_OPEN) {
        hub_add(c);

    } else if (ev == MG_EV_WS_MSG) {
        struct mg_ws_message *wm = (struct mg_ws_message *)ev_data;
        hub_broadcast(wm->data.buf, wm->data.len);

    } else if (ev == MG_EV_CLOSE) {
        if (c->is_websocket) hub_remove(c);
    }
}

int main(void) {
    if (pg_pool_init() < 0) {
        fprintf(stderr, "Failed to connect to PostgreSQL\n");
        return 1;
    }
    printf("C/Mongoose server starting on :8080\n");

    struct mg_mgr mgr;
    mg_mgr_init(&mgr);
    mg_http_listen(&mgr, LISTEN_URL, ev_handler, NULL);

    for (;;) mg_mgr_poll(&mgr, 100);
    mg_mgr_free(&mgr);
    return 0;
}
