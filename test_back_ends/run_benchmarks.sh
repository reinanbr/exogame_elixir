#!/usr/bin/env bash
set -euo pipefail

# ── Benchmark Orchestration Script ─────────────────────────────────────
# Runs each backend sequentially: build → start → warm-up → k6 CRUD test
# → k6 WS test → collect results → stop.
#
# Usage:
#   ./run_benchmarks.sh            # Run all backends
#   ./run_benchmarks.sh rust go    # Run specific backends only
#
# Prerequisites:
#   - Docker & docker-compose (v1.28+ for profile support)
#   - k6 installed locally (or use Docker k6)
#   - ulimit -n >= 120000 (for 100k WS connections)

DC="docker-compose --compatibility"
DOCKER="docker"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Use sudo for docker-compose if the current user is not in the docker group
if ! docker info > /dev/null 2>&1; then
  if sudo docker info > /dev/null 2>&1; then
    DC="sudo docker-compose --compatibility"
    DOCKER="sudo docker"
  else
    echo "ERROR: Cannot connect to Docker daemon. Ensure Docker is running and you have permission."
    exit 1
  fi
fi

RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

# Service name → Docker Compose profile mapping
declare -A SERVICES=(
  [rust]=rust-actix
  [go]=go-fiber
  [python]=python-fastapi
  [node]=node-fastify
  [php]=php-swoole
  [elixir]=elixir-phoenix
  [zig]=zig-zap
  [c]=c-mongoose
  [lisp]=lisp-hunchentoot
  [java]=java-quarkus
  [fortran]=fortran-server
  [cobol]=cobol-server
  [erlang]=erlang-cowboy
  [ruby]=ruby-falcon
  [clojure]=clojure-httpkit
  [scala]=scala-pekko
)

# Friendly display names
declare -A DISPLAY_NAMES=(
  [rust]="Rust / Actix-web"
  [go]="Go / Fiber"
  [python]="Python / FastAPI"
  [node]="Node.js / Fastify"
  [php]="PHP / Swoole"
  [elixir]="Elixir / Phoenix"
  [zig]="Zig / Zap"
  [c]="C / Mongoose"
  [lisp]="Common Lisp / Hunchentoot"
  [java]="Java / Quarkus"
  [fortran]="Fortran / C-Mongoose"
  [cobol]="COBOL / C-Mongoose"
  [erlang]="Erlang / Cowboy"
  [ruby]="Ruby / Falcon"
  [clojure]="Clojure / Http-kit"
  [scala]="Scala / Pekko HTTP"
)

# Default: all backends in a sensible order
ALL_BACKENDS=(rust go c zig java scala clojure elixir erlang node python php ruby fortran cobol lisp)

# Parse arguments
if [[ $# -gt 0 ]]; then
  BACKENDS=("$@")
else
  BACKENDS=("${ALL_BACKENDS[@]}")
fi

# ── Helper functions ───────────────────────────────────────────────────
log() { echo -e "\n\033[1;36m══════ $1 ══════\033[0m\n"; }
warn() { echo -e "\033[1;33m⚠ $1\033[0m"; }
err()  { echo -e "\033[1;31m✗ $1\033[0m"; }
ok()   { echo -e "\033[1;32m✓ $1\033[0m"; }

wait_for_server() {
  local url="http://localhost:8080/items/1"
  local max_wait=60
  local waited=0
  while ! curl -sf "$url" > /dev/null 2>&1; do
    sleep 1
    waited=$((waited + 1))
    if [[ $waited -ge $max_wait ]]; then
      err "Server did not start within ${max_wait}s"
      return 1
    fi
  done
  ok "Server ready (${waited}s)"
}

reset_db() {
  log "Resetting database"
  $DC exec -T postgres psql -U bench -d bench -c "TRUNCATE items RESTART IDENTITY CASCADE;" 2>/dev/null || true
}

run_k6_crud() {
  local name="$1"
  local out="$RESULTS_DIR/${name}_crud.json"
  log "k6 CRUD test → $name"
  if command -v k6 &>/dev/null; then
    k6 run \
      --out json="$out" \
      --summary-export="$RESULTS_DIR/${name}_crud_summary.json" \
      --tag testid="$name" \
      "$SCRIPT_DIR/k6/crud_test.js" 2>&1 | tee "$RESULTS_DIR/${name}_crud.log"
  else
    $DOCKER run --rm --network=host \
      -v "$SCRIPT_DIR/k6:/scripts:ro" \
      -v "$RESULTS_DIR:/results" \
      grafana/k6:0.53.0 run \
      --out json="/results/${name}_crud.json" \
      --summary-export="/results/${name}_crud_summary.json" \
      --tag testid="$name" \
      /scripts/crud_test.js 2>&1 | tee "$RESULTS_DIR/${name}_crud.log"
  fi
}

run_k6_ws() {
  local name="$1"
  local out="$RESULTS_DIR/${name}_ws.json"
  log "k6 WebSocket test → $name"
  if command -v k6 &>/dev/null; then
    k6 run \
      --out json="$out" \
      --summary-export="$RESULTS_DIR/${name}_ws_summary.json" \
      --tag testid="$name" \
      "$SCRIPT_DIR/k6/ws_test.js" 2>&1 | tee "$RESULTS_DIR/${name}_ws.log"
  else
    $DOCKER run --rm --network=host \
      -v "$SCRIPT_DIR/k6:/scripts:ro" \
      -v "$RESULTS_DIR:/results" \
      grafana/k6:0.53.0 run \
      --out json="/results/${name}_ws.json" \
      --summary-export="/results/${name}_ws_summary.json" \
      --tag testid="$name" \
      /scripts/ws_test.js 2>&1 | tee "$RESULTS_DIR/${name}_ws.log"
  fi
}

# ── Ensure PostgreSQL is running ───────────────────────────────────────
log "Starting PostgreSQL"
# Remove any stale containers (docker-compose v1 can't recreate containers
# created by a different Docker Engine version — results in 'ContainerConfig' error)
$DOCKER rm -f "$(basename "$SCRIPT_DIR")_postgres_1" 2>/dev/null || true
$DC up -d postgres
sleep 3
$DC exec -T postgres pg_isready -U bench -d bench || {
  err "PostgreSQL failed to start"
  exit 1
}
ok "PostgreSQL is ready"

# ── System tuning hints ────────────────────────────────────────────────
CURRENT_NOFILE=$(ulimit -n 2>/dev/null || echo "unknown")
if [[ "$CURRENT_NOFILE" != "unknown" && "$CURRENT_NOFILE" -lt 120000 ]]; then
  warn "ulimit -n is $CURRENT_NOFILE (need ≥120000 for 100k WS test)"
  warn "Run: ulimit -n 200000"
fi

# ── Main benchmark loop ───────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SUMMARY_CSV="$RESULTS_DIR/summary_${TIMESTAMP}.csv"
echo "backend,crud_avg_ms,crud_p95_ms,crud_rps,ws_avg_ms,ws_p95_ms,ws_connections" > "$SUMMARY_CSV"

for backend in "${BACKENDS[@]}"; do
  service="${SERVICES[$backend]:-}"
  display="${DISPLAY_NAMES[$backend]:-$backend}"

  if [[ -z "$service" ]]; then
    warn "Unknown backend: $backend — skipping"
    continue
  fi

  log "BENCHMARK: $display ($backend)"

  # Build
  log "Building $service"
  $DC build "$service" 2>&1 | tail -5

  # Reset DB
  reset_db

  # Start
  log "Starting $service"
  COMPOSE_PROFILES="$backend" $DC up -d "$service"

  # Wait for server
  if ! wait_for_server; then
    err "Skipping $backend — server failed to start"
    COMPOSE_PROFILES="$backend" $DC stop "$service" 2>/dev/null || true
    echo "$backend,ERR,ERR,ERR,ERR,ERR,ERR" >> "$SUMMARY_CSV"
    continue
  fi

  # Warm-up (100 quick requests)
  log "Warm-up"
  for i in $(seq 1 100); do
    curl -sf -X POST http://localhost:8080/items \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"warmup-$i\",\"value\":\"val\"}" > /dev/null 2>&1 || true
  done
  sleep 2

  # Reset DB again for clean benchmark
  reset_db

  # CRUD test
  run_k6_crud "$backend" || warn "CRUD test had errors for $backend"

  # Brief pause between tests
  sleep 5

  # Reset DB for WS test
  reset_db

  # WebSocket test
  run_k6_ws "$backend" || warn "WS test had errors for $backend"

  # Extract summary metrics
  CRUD_SUMMARY="$RESULTS_DIR/${backend}_crud_summary.json"
  WS_SUMMARY="$RESULTS_DIR/${backend}_ws_summary.json"

  if [[ -f "$CRUD_SUMMARY" ]]; then
    crud_avg=$(python3 -c "
import json
with open('$CRUD_SUMMARY') as f:
    d = json.load(f)
    m = d.get('metrics', {})
    req_dur = m.get('http_req_duration', {})
    print(f\"{req_dur.get('avg', 'N/A'):.2f}\")
" 2>/dev/null || echo "N/A")
    crud_p95=$(python3 -c "
import json
with open('$CRUD_SUMMARY') as f:
    d = json.load(f)
    m = d.get('metrics', {})
    req_dur = m.get('http_req_duration', {})
    p = req_dur.get('p(95)', 'N/A')
    print(f'{p:.2f}')
" 2>/dev/null || echo "N/A")
    crud_rps=$(python3 -c "
import json
with open('$CRUD_SUMMARY') as f:
    d = json.load(f)
    m = d.get('metrics', {})
    rps = m.get('http_reqs', {}).get('rate', 'N/A')
    print(f'{rps:.1f}')
" 2>/dev/null || echo "N/A")
  else
    crud_avg="N/A"; crud_p95="N/A"; crud_rps="N/A"
  fi

  if [[ -f "$WS_SUMMARY" ]]; then
    ws_avg=$(python3 -c "
import json
with open('$WS_SUMMARY') as f:
    d = json.load(f)
    m = d.get('metrics', {})
    ws_dur = m.get('ws_session_duration', m.get('http_req_duration', {}))
    print(f\"{ws_dur.get('avg', 'N/A'):.2f}\")
" 2>/dev/null || echo "N/A")
    ws_p95=$(python3 -c "
import json
with open('$WS_SUMMARY') as f:
    d = json.load(f)
    m = d.get('metrics', {})
    ws_dur = m.get('ws_session_duration', m.get('http_req_duration', {}))
    p = ws_dur.get('p(95)', 'N/A')
    print(f'{p:.2f}')
" 2>/dev/null || echo "N/A")
    ws_conns=$(python3 -c "
import json
with open('$WS_SUMMARY') as f:
    d = json.load(f)
    m = d.get('metrics', {})
    vus = m.get('vus_max', {}).get('max', 'N/A')
    print(int(vus))
" 2>/dev/null || echo "N/A")
  else
    ws_avg="N/A"; ws_p95="N/A"; ws_conns="N/A"
  fi

  echo "$backend,$crud_avg,$crud_p95,$crud_rps,$ws_avg,$ws_p95,$ws_conns" >> "$SUMMARY_CSV"

  # Stop service
  log "Stopping $service"
  COMPOSE_PROFILES="$backend" $DC stop "$service"
  sleep 3

  ok "Done: $display"
done

# ── Final summary ──────────────────────────────────────────────────────
log "BENCHMARK COMPLETE"
echo ""
echo "Results directory: $RESULTS_DIR"
echo "Summary CSV: $SUMMARY_CSV"
echo ""
column -t -s',' "$SUMMARY_CSV" 2>/dev/null || cat "$SUMMARY_CSV"
echo ""

# Generate plots
if command -v python3 &>/dev/null; then
  log "Generating plots"
  python3 results/plot_results.py "$SUMMARY_CSV" "$RESULTS_DIR" 2>&1 || warn "Plot generation failed"
fi

ok "All done!"
