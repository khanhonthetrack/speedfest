#!/usr/bin/env bash
# End-to-end online smoke test: real Node server + 3 real headless Godot clients.
# Starts server/ on a free port with short round timers, runs one host and two guests of
# res://tests/net/net_client_test.tscn in parallel, and prints PASS or FAIL.
#
# usage: tools/net_smoke_test.sh [num_clients=3]
#   env NET_TEST_OUT=/dir  keep logs there (default: a temp dir, printed at the end)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
N="${1:-3}"
OUT="${NET_TEST_OUT:-$(mktemp -d -t speedfest-net-XXXXXX)}"
mkdir -p "$OUT"

if [[ ! -d "$ROOT/server/node_modules/ws" ]]; then
  (cd "$ROOT/server" && npm install --no-audit --no-fund >/dev/null 2>&1) || { echo "FAIL: npm install"; exit 1; }
fi
if [[ ! -d "$ROOT/game/.godot/imported" ]]; then "$ROOT/tools/godot_import.sh" >/dev/null 2>&1 || true; fi

PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
COUNTDOWN_MS=1500 RESULTS_MS=2500 FINISH_GRACE_MS=500 HEARTBEAT_MS=3000 PORT=$PORT HOST=127.0.0.1 \
  PUBLIC_DIR="$OUT/no-public" node "$ROOT/server/server.js" >"$OUT/server.log" 2>&1 &
SERVER_PID=$!
PIDS=()
cleanup() {
  for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done
  kill "$SERVER_PID" 2>/dev/null
  wait 2>/dev/null
}
trap cleanup EXIT

for _ in $(seq 1 50); do
  curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
  sleep 0.2
done
if ! curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
  echo "FAIL: server did not start (see $OUT/server.log)"; cat "$OUT/server.log"; exit 1
fi

ROOM="smoke$RANDOM"
URL="ws://127.0.0.1:$PORT/ws"
run_client() { # role name index
  timeout 120 godot --headless --path "$ROOT/game" --audio-driver Dummy res://tests/net/net_client_test.tscn -- \
    --url="$URL" --role="$1" --name="$2" --index="$3" --players="$N" --room="$ROOM" --duration=4 --timeout_s=90 \
    >"$OUT/client_$2.log" 2>&1
}

run_client host Host 0 &
PIDS+=($!)
NAMES=(Host)
for i in $(seq 1 $((N - 1))); do
  run_client guest "Guest$i" "$i" &
  PIDS+=($!)
  NAMES+=("Guest$i")
done

STATUS=0
for idx in "${!PIDS[@]}"; do
  if ! wait "${PIDS[$idx]}"; then
    STATUS=1
    echo "client ${NAMES[$idx]}: non-zero exit"
  fi
done
PIDS=()

OKS=$(cat "$OUT"/client_*.log | grep -c '^TEST_OK' || true)
FAILS=$(cat "$OUT"/client_*.log | grep -c '^TEST_FAIL' || true)
SUMMARIES=$(cat "$OUT"/client_*.log | grep -c '^TEST_SUMMARY' || true)
grep -h '^TEST_FAIL' "$OUT"/client_*.log
if [[ $STATUS -ne 0 || $FAILS -ne 0 || $SUMMARIES -ne $N ]]; then
  echo "--- server log ---"; tail -30 "$OUT/server.log"
  echo "FAIL net_smoke_test: $OKS ok, $FAILS failed, $SUMMARIES/$N clients finished (logs: $OUT)"
  exit 1
fi
echo "--- server log ---"; cat "$OUT/server.log"
echo "PASS net_smoke_test: $N clients, $OKS checks ok (logs: $OUT)"
