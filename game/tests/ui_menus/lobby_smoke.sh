#!/usr/bin/env bash
# Lobby UI smoke test against the real server: one host + N-1 guests run the real lobby screen
# headless (driven by lobby_driver.gd pressing its buttons): connect, create / join from the room
# list, ready, chat, host picks track + duration through the chips, START -> every client must
# enter the race scene in online mode. Prints PASS or FAIL.
#
# usage: game/tests/ui_menus/lobby_smoke.sh [num_clients=3]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
N="${1:-3}"
OUT="${LOBBY_TEST_OUT:-$(mktemp -d -t speedfest-lobby-XXXXXX)}"
mkdir -p "$OUT"
if [[ ! -d "$ROOT/server/node_modules/ws" ]]; then
  (cd "$ROOT/server" && npm install --no-audit --no-fund >/dev/null 2>&1) || { echo "FAIL: npm install"; exit 1; }
fi
PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
COUNTDOWN_MS=1500 RESULTS_MS=2500 PORT=$PORT HOST=127.0.0.1 PUBLIC_DIR="$OUT/no-public" \
  node "$ROOT/server/server.js" >"$OUT/server.log" 2>&1 &
SERVER_PID=$!
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; kill "$SERVER_PID" 2>/dev/null; wait 2>/dev/null; }
trap cleanup EXIT
for _ in $(seq 1 50); do curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break; sleep 0.2; done

ROOM="Lobby$RANDOM"
run() { # role name car
  timeout 90 godot --headless --path "$ROOT/game" --audio-driver Dummy res://tests/ui_menus/lobby_driver.tscn -- \
    --url="ws://127.0.0.1:$PORT/ws" --role="$1" --name="$2" --car="$3" --players="$N" --room="$ROOM" --timeout_s=70 \
    >"$OUT/$2.log" 2>&1
}
run host Host kaze &
PIDS+=($!)
NAMES=(Host)
CARS=(brute veloce kaze brute veloce kaze brute)
for i in $(seq 1 $((N - 1))); do
  sleep 0.7
  run guest "Guest$i" "${CARS[$((i - 1))]}" &
  PIDS+=($!)
  NAMES+=("Guest$i")
done
STATUS=0
for idx in "${!PIDS[@]}"; do
  if ! wait "${PIDS[$idx]}"; then STATUS=1; echo "client ${NAMES[$idx]}: non-zero exit"; fi
done
for n in "${NAMES[@]}"; do
  echo "--- $n"; grep -E "TEST_|SCRIPT ERROR|ERROR" "$OUT/$n.log" | head -20
  grep -q "TEST_OK lobby_race_scene_loaded" "$OUT/$n.log" || STATUS=1
  grep -q "TEST_FAIL" "$OUT/$n.log" && STATUS=1
done
echo "logs: $OUT"
if [[ $STATUS -eq 0 ]]; then echo "PASS"; else echo "FAIL"; fi
exit $STATUS
