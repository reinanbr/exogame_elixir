// k6 CRUD Benchmark — ramp-up until failure
// Usage: k6 run --out json=results/crud_<lang>.json k6/crud_test.js -e TARGET=http://host:port
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const target = __ENV.TARGET || 'http://localhost:8001';

const insertErrors = new Counter('insert_errors');
const insertRate   = new Rate('insert_success_rate');
const insertLat    = new Trend('insert_latency_ms');
const readLat      = new Trend('read_latency_ms');

export const options = {
  stages: [
    { duration: '30s', target: 50   },
    { duration: '30s', target: 200  },
    { duration: '30s', target: 500  },
    { duration: '30s', target: 1000 },
    { duration: '30s', target: 2000 },
    { duration: '30s', target: 3000 },
    { duration: '30s', target: 5000 },
    { duration: '30s', target: 5000 },  // sustain
    { duration: '15s', target: 0    },  // cool-down
  ],
  thresholds: {
    http_req_failed:       ['rate<0.30'],
    insert_success_rate:   ['rate>0.70'],
    insert_latency_ms:     ['p(95)<5000'],
  },
};

export default function () {
  // ---- INSERT ----
  const payload = JSON.stringify({
    name:  `item_${__VU}_${__ITER}`,
    value: `payload_${Date.now()}_${Math.random().toString(36).slice(2)}`,
  });

  const insertRes = http.post(`${target}/items`, payload, {
    headers: { 'Content-Type': 'application/json' },
    timeout: '10s',
  });

  const ok = check(insertRes, {
    'insert status 200|201': (r) => r.status === 200 || r.status === 201,
  });

  insertRate.add(ok);
  if (!ok) insertErrors.add(1);
  insertLat.add(insertRes.timings.duration);

  // ---- READ (by id) ----
  let itemId = 1;
  try {
    const body = JSON.parse(insertRes.body);
    if (body && body.id) itemId = body.id;
  } catch (_) {}

  const readRes = http.get(`${target}/items/${itemId}`, { timeout: '10s' });
  check(readRes, { 'read status 200': (r) => r.status === 200 });
  readLat.add(readRes.timings.duration);

  sleep(0.01); // 10ms think-time
}
