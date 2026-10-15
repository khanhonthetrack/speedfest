#!/usr/bin/env bash
# LIVE room end to end: a real server (short rounds) and N headless Godot clients that jump into
# the rotation, finish a run, see the results and get carried into the next track.
# usage: tools/live_smoke_test.sh [num_clients=2]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
N="${1:-2}"
OUT="${NET_TEST_OUT:-$(mktemp -d -t speedfest-live-XXXXXX)}"
mkdir -p "$OUT"

if [[ ! -d "$ROOT/server/node_modules/ws" ]]; then
  (cd "$ROOT/server" && npm install --no-audit --no-fund >/dev/null 2>&1) || { echo "FAIL: npm install"; exit 1; }
fi
if [[ ! -d "$ROOT/game/.godot/imported" ]]; then "$ROOT/tools/godot_import.sh" >/dev/null 2>&1 || true; fi

PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
COUNTDOWN_MS=1500 FINISH_GRACE_MS=500 LIVE_ROUND_S=6 LIVE_RESULTS_MS=2500 HEARTBEAT_MS=3000 PORT=$PORT HOST=127.0.0.1 \
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

URL="ws://127.0.0.1:$PORT/ws"
for i in $(seq 1 "$N"); do
  timeout 120 godot --headless --path "$ROOT/game" --audio-driver Dummy res://tests/net/live_client_test.tscn -- \
    --url="$URL" --name="Live$i" --timeout_s=60 >"$OUT/client_Live$i.log" 2>&1 &
  PIDS+=($!)
  sleep 1 # the second client drops into a round that is already running
done

STATUS=0
for p in "${PIDS[@]}"; do wait "$p" || STATUS=1; done
PIDS=()
OKS=$(cat "$OUT"/client_*.log | grep -c '^TEST_OK' || true)
FAILS=$(cat "$OUT"/client_*.log | grep -c '^TEST_FAIL' || true)
SUMMARIES=$(cat "$OUT"/client_*.log | grep -c '^TEST_SUMMARY' || true)
grep -h '^TEST_FAIL' "$OUT"/client_*.log
if [[ $STATUS -ne 0 || $FAILS -ne 0 || $SUMMARIES -ne $N ]]; then
  echo "--- server log ---"; tail -30 "$OUT/server.log"
  echo "FAIL live_smoke_test: $OKS ok, $FAILS failed, $SUMMARIES/$N clients finished (logs: $OUT)"
  exit 1
fi
echo "PASS live_smoke_test: $N clients, $OKS checks ok (logs: $OUT)"
