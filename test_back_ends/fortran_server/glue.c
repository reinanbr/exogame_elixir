/*
 * C glue layer for Fortran benchmark server.
 * Uses mongoose for HTTP/WS and libpq for PostgreSQL.
 * Calls Fortran routines for "business logic".
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include "mongoose.h"
#include <libpq-fe.h>

/* Fortran functions */
extern void fortran_process_create(const char *name, int name_len,
                                   const char *val, int val_len,
                                   char *out_buf, int *out_len);
extern int fortran_validate_id(int id);

/* ── WebSocket Hub ─────────────────────────────────────────────────── */
#define MAX_CLIENTS 120000
static struct mg_connection *ws_clients[MAX_CLIENTS];
static int ws_count = 0;
static pthread_mutex_t ws_lock = PTHREAD_MUTEX_INITIALIZER;

static void hub_add(struct mg_connection *c) {
    pthread_mutex_lock(&ws_lock);
    if (ws_count < MAX_CLIENTS) ws_clients[ws_count++] = c;
    pthread_mutex_unlock(&ws_lock);
}
static void hub_remove(struct mg_connection *c) {
    pthread_mutex_lock(&ws_lock);
    for (int i = 0; i < ws_count; i++) {
        if (ws_clients[i] == c) { ws_clients[i] = ws_clients[--ws_count]; break; }
    }
    pthread_mutex_unlock(&ws_lock);
}
static void hub_broadcast(const char *msg, size_t len) {
    pthread_mutex_lock(&ws_lock);
    for (int i = 0; i < ws_count; i++)
        mg_ws_send(ws_clients[i], msg, len, WEBSOCKET_OP_TEXT);
    pthread_mutex_unlock(&ws_lock);
}

/* ── PostgreSQL ────────────────────────────────────────────────────── */
#define POOL_SIZE 16
static PGconn *pg_pool[POOL_SIZE];
static int pg_used[POOL_SIZE];
static pthread_mutex_t pg_lock = PTHREAD_MUTEX_INITIALIZER;

static PGconn *pg_acquire(void) {
    pthread_mutex_lock(&pg_lock);
    for (int i = 0; i < POOL_SIZE; i++) {
        if (!pg_used[i]) { pg_used[i] = 1; pthread_mutex_unlock(&pg_lock); return pg_pool[i]; }
    }
    pthread_mutex_unlock(&pg_lock);
    return NULL;
}
static void pg_release(PGconn *c) {
    pthread_mutex_lock(&pg_lock);
    for (int i = 0; i < POOL_SIZE; i++) {
        if (pg_pool[i] == c) { pg_used[i] = 0; break; }
    }
    pthread_mutex_unlock(&pg_lock);
}

static int pg_pool_init(void) {
    const char *host = getenv("DB_HOST");
    if (!host) host = "postgres";
    char ci[256];
    snprintf(ci, sizeof(ci), "host=%s port=5432 dbname=bench user=bench password=bench", host);
    for (int a = 0; a < 30; a++) {
        PGconn *t = PQconnectdb(ci);
        if (PQstatus(t) == CONNECTION_OK) {
            PQfinish(t);
            for (int i = 0; i < POOL_SIZE; i++) {
                pg_pool[i] = PQconnectdb(ci); pg_used[i] = 0;
            }
            return 0;
        }
        PQfinish(t);
        fprintf(stderr, "DB retry %d/30\n", a+1);
        sleep(1);
    }
    return -1;
}

/* ── JSON helper ───────────────────────────────────────────────────── */
static int json_get_str(const char *j, size_t jl, const char *key, char *o, size_t os) {
    char needle[128]; snprintf(needle, sizeof(needle), "\"%s\"", key);
    const char *p = memmem(j, jl, needle, strlen(needle));
    if (!p) return -1;
    p += strlen(needle);
    while (*p == ' ' || *p == ':' || *p == '\t') p++;
    if (*p != '"') return -1; p++;
    const char *e = strchr(p, '"'); if (!e) return -1;
    size_t l = (size_t)(e-p); if (l >= os) l = os-1;
    memcpy(o, p, l); o[l] = '\0';
    return 0;
}

/* ── Event handler ────────────────────────────────────────────────── */
static void ev_handler(struct mg_connection *c, int ev, void *ev_data) {
    if (ev == MG_EV_HTTP_MSG) {
        struct mg_http_message *hm = ev_data;
        if (mg_match(hm->uri, mg_str("/ws"), NULL)) { mg_ws_upgrade(c, hm, NULL); return; }

        if (mg_match(hm->uri, mg_str("/items")) && mg_strcmp(hm->method, mg_str("POST")) == 0) {
            char name[256]={0}, value[1024]={0};
            if (json_get_str(hm->body.buf, hm->body.len, "name", name, sizeof(name)) < 0) {
                mg_http_reply(c, 400, "", "{\"error\":\"missing name\"}"); return;
            }
            json_get_str(hm->body.buf, hm->body.len, "value", value, sizeof(value));

            /* Call Fortran logic */
            char fbuf[4096]; int flen = 0;
            fortran_process_create(name, (int)strlen(name), value, (int)strlen(value), fbuf, &flen);

            PGconn *pg = pg_acquire();
            if (!pg) { mg_http_reply(c, 503, "", "{\"error\":\"db busy\"}"); return; }
            const char *p[2] = {name, value};
            PGresult *r = PQexecParams(pg,
                "INSERT INTO items (name,value) VALUES ($1,$2) RETURNING id,name,value",
                2, NULL, p, NULL, NULL, 0);
            if (PQresultStatus(r) == PGRES_TUPLES_OK && PQntuples(r) > 0) {
                char buf[2048];
                snprintf(buf, sizeof(buf), "{\"id\":%s,\"name\":\"%s\",\"value\":\"%s\"}",
                         PQgetvalue(r,0,0), PQgetvalue(r,0,1), PQgetvalue(r,0,2));
                mg_http_reply(c, 201, "Content-Type: application/json\r\n", "%s", buf);
            } else {
                mg_http_reply(c, 500, "", "{\"error\":\"insert failed\"}");
            }
            PQclear(r); pg_release(pg);
            return;
        }

        if (mg_match(hm->uri, mg_str("/items/*"), NULL) && mg_strcmp(hm->method, mg_str("GET")) == 0) {
            char id_s[32]={0};
            size_t il = hm->uri.len - 7; if (il >= sizeof(id_s)) il = sizeof(id_s)-1;
            memcpy(id_s, hm->uri.buf+7, il);
            int id = atoi(id_s);

            if (!fortran_validate_id(id)) {
                mg_http_reply(c, 400, "", "{\"error\":\"invalid id\"}"); return;
            }

            PGconn *pg = pg_acquire();
            if (!pg) { mg_http_reply(c, 503, "", "{\"error\":\"db busy\"}"); return; }
            const char *p[1] = {id_s};
            PGresult *r = PQexecParams(pg, "SELECT id,name,value FROM items WHERE id=$1",
                                       1, NULL, p, NULL, NULL, 0);
            if (PQresultStatus(r) == PGRES_TUPLES_OK && PQntuples(r) > 0) {
                char buf[2048];
                snprintf(buf, sizeof(buf), "{\"id\":%s,\"name\":\"%s\",\"value\":\"%s\"}",
                         PQgetvalue(r,0,0), PQgetvalue(r,0,1), PQgetvalue(r,0,2));
                mg_http_reply(c, 200, "Content-Type: application/json\r\n", "%s", buf);
            } else {
                mg_http_reply(c, 404, "", "{\"error\":\"not found\"}");
            }
            PQclear(r); pg_release(pg);
            return;
        }
        mg_http_reply(c, 404, "", "{\"error\":\"not found\"}");
    } else if (ev == MG_EV_WS_OPEN) { hub_add(c);
    } else if (ev == MG_EV_WS_MSG) {
        struct mg_ws_message *wm = ev_data;
        hub_broadcast(wm->data.buf, wm->data.len);
    } else if (ev == MG_EV_CLOSE) { if (c->is_websocket) hub_remove(c); }
}

int main(void) {
    if (pg_pool_init() < 0) { fprintf(stderr, "DB init failed\n"); return 1; }
    printf("Fortran+C/Mongoose server on :8080\n");
    struct mg_mgr mgr; mg_mgr_init(&mgr);
    mg_http_listen(&mgr, "http://0.0.0.0:8080", ev_handler, NULL);
    for (;;) mg_mgr_poll(&mgr, 100);
    return 0;
}
