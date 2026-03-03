// k6 WebSocket Benchmark — ramp connections toward 100k
// Usage: k6 run --out json=results/ws_<lang>.json k6/ws_test.js -e TARGET=ws://host:port/ws
import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const target = __ENV.TARGET || 'ws://localhost:8001/ws';

const wsConnErrors = new Counter('ws_conn_errors');
const wsConnRate   = new Rate('ws_conn_success');
const wsMsgLat     = new Trend('ws_msg_latency_ms');
const wsConns      = new Counter('ws_total_connections');

export const options = {
  stages: [
    { duration: '30s', target: 1000  },
    { duration: '30s', target: 5000  },
    { duration: '30s', target: 10000 },
    { duration: '30s', target: 25000 },
    { duration: '30s', target: 50000 },
    { duration: '30s', target: 75000 },
    { duration: '60s', target: 100000},
    { duration: '30s', target: 100000},  // sustain
    { duration: '15s', target: 0     },
  ],
  thresholds: {
    ws_conn_success: ['rate>0.70'],
  },
};

export default function () {
  const res = ws.connect(target, {}, function (socket) {
    wsConns.add(1);

    socket.on('open', () => {
      wsConnRate.add(true);
      // Subscribe to a broadcast topic
      socket.send(JSON.stringify({ action: 'subscribe', topic: 'benchmark' }));
    });

    socket.on('message', (data) => {
      try {
        const msg = JSON.parse(data);
        if (msg.ts) {
          wsMsgLat.add(Date.now() - msg.ts);
        }
      } catch (_) {}
    });

    socket.on('error', () => {
      wsConnErrors.add(1);
      wsConnRate.add(false);
    });

    // Stay connected for 60s, sending a ping every 5s
    for (let i = 0; i < 12; i++) {
      socket.send(JSON.stringify({
        action: 'broadcast',
        topic: 'benchmark',
        payload: { msg: `ping_${__VU}`, ts: Date.now() },
      }));
      sleep(5);
    }

    socket.close();
  });

  check(res, { 'ws status is 101': (r) => r && r.status === 101 });
}
