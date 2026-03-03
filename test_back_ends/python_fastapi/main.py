"""Bench – FastAPI/Uvicorn  (CRUD + WebSocket pub/sub)"""
from __future__ import annotations
import asyncio, json, os
from collections import defaultdict
from contextlib import asynccontextmanager
from typing import Any

import asyncpg
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import ORJSONResponse
from pydantic import BaseModel

DB_HOST = os.getenv("DB_HOST", "postgres")
DSN = f"postgresql://bench:bench@{DB_HOST}:5432/bench"

pool: asyncpg.Pool | None = None

# ── WS Hub ──────────────────────────────────────────────────────────
class Hub:
    __slots__ = ("_topics",)
    def __init__(self) -> None:
        self._topics: dict[str, set[WebSocket]] = defaultdict(set)

    def subscribe(self, topic: str, ws: WebSocket) -> None:
        self._topics[topic].add(ws)

    def unsubscribe(self, ws: WebSocket) -> None:
        for conns in self._topics.values():
            conns.discard(ws)

    async def broadcast(self, topic: str, payload: Any) -> None:
        msg = json.dumps(payload) if not isinstance(payload, str) else payload
        dead: list[WebSocket] = []
        for ws in self._topics.get(topic, set()):
            try:
                await ws.send_text(msg)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self._topics[topic].discard(ws)

hub = Hub()

# ── App lifecycle ───────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(_app: FastAPI):
    global pool
    for _ in range(30):
        try:
            pool = await asyncpg.create_pool(DSN, min_size=10, max_size=50)
            break
        except Exception:
            await asyncio.sleep(1)
    yield
    if pool:
        await pool.close()

app = FastAPI(lifespan=lifespan, default_response_class=ORJSONResponse)

# ── Models ──────────────────────────────────────────────────────────
class ItemIn(BaseModel):
    name: str
    value: str

# ── CRUD ────────────────────────────────────────────────────────────
@app.post("/items", status_code=201)
async def create_item(item: ItemIn):
    row = await pool.fetchrow(
        "INSERT INTO items(name,value) VALUES($1,$2) RETURNING id,name,value,created_at::text",
        item.name, item.value,
    )
    return dict(row)

@app.get("/items/{item_id}")
async def get_item(item_id: int):
    row = await pool.fetchrow(
        "SELECT id,name,value,created_at::text FROM items WHERE id=$1", item_id,
    )
    if row is None:
        return ORJSONResponse({"error": "not found"}, status_code=404)
    return dict(row)

# ── WebSocket ───────────────────────────────────────────────────────
@app.websocket("/ws")
async def ws_endpoint(ws: WebSocket):
    await ws.accept()
    try:
        while True:
            data = await ws.receive_text()
            try:
                msg = json.loads(data)
            except json.JSONDecodeError:
                continue
            action = msg.get("action", "")
            topic = msg.get("topic", "default")
            if action == "subscribe":
                hub.subscribe(topic, ws)
            elif action == "broadcast":
                await hub.broadcast(topic, msg.get("payload", {}))
    except WebSocketDisconnect:
        pass
    finally:
        hub.unsubscribe(ws)
