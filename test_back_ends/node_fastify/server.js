import Fastify from 'fastify';
import websocket from '@fastify/websocket';
import pg from 'pg';

const DB_HOST = process.env.DB_HOST || 'postgres';
const pool = new pg.Pool({
  host: DB_HOST, port: 5432, database: 'bench',
  user: 'bench', password: 'bench', max: 50,
});

// ── WS Hub ───────────────────────────────────────────────────────────
const topics = new Map();  // topic -> Set<socket>

function subscribe(topic, socket) {
  if (!topics.has(topic)) topics.set(topic, new Set());
  topics.get(topic).add(socket);
}
function unsubscribe(socket) {
  for (const sockets of topics.values()) sockets.delete(socket);
}
function broadcast(topic, payload) {
  const msg = typeof payload === 'string' ? payload : JSON.stringify(payload);
  const sockets = topics.get(topic);
  if (!sockets) return;
  for (const s of sockets) {
    try { s.send(msg); } catch { sockets.delete(s); }
  }
}

// ── App ──────────────────────────────────────────────────────────────
const app = Fastify({ logger: false });
await app.register(websocket);

// CRUD
app.post('/items', async (req, reply) => {
  const { name, value } = req.body;
  const { rows } = await pool.query(
    'INSERT INTO items(name,value) VALUES($1,$2) RETURNING id,name,value,created_at::text',
    [name, value],
  );
  reply.code(201).send(rows[0]);
});

app.get('/items/:id', async (req, reply) => {
  const { rows } = await pool.query(
    'SELECT id,name,value,created_at::text FROM items WHERE id=$1',
    [req.params.id],
  );
  if (!rows.length) return reply.code(404).send({ error: 'not found' });
  reply.send(rows[0]);
});

// WebSocket
app.get('/ws', { websocket: true }, (socket) => {
  socket.on('message', (raw) => {
    try {
      const msg = JSON.parse(raw.toString());
      const topic = msg.topic || 'default';
      if (msg.action === 'subscribe') subscribe(topic, socket);
      else if (msg.action === 'broadcast') broadcast(topic, msg.payload || {});
    } catch {}
  });
  socket.on('close', () => unsubscribe(socket));
  socket.on('error', () => unsubscribe(socket));
});

// Wait for DB then start
async function start() {
  for (let i = 0; i < 30; i++) {
    try { await pool.query('SELECT 1'); break; } catch { await new Promise(r => setTimeout(r, 1000)); }
  }
  await app.listen({ port: 8080, host: '0.0.0.0' });
  console.log('Fastify listening on :8080');
}
start();
