#!/usr/bin/env bash
# End-to-end online round for the race module: real Node server + N headless Godot clients
# (AutoPilot host/guests) that play one round in race.tscn and go back to the lobby.
#
# usage: game/tests/race/online_round_test.sh [num_clients=2] [duration_s=20] [extra race args...]
#   default race args: --test_track --gate_runner=60 (race module's own track + teleport driver,
#   so it works while Car/Track are stubs). Pass e.g. "--autodrive" with real modules merged:
#   game/tests/race/online_round_test.sh 2 45 --autodrive --track=arena
#   env RACE_TEST_OUT=/dir keeps logs there.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
N="${1:-2}"; DUR="${2:-20}"; shift 2 2>/dev/null || shift $#
EXTRA=("$@")
[[ ${#EXTRA[@]} -eq 0 ]] && EXTRA=(--test_track --gate_runner=60)
OUT="${RACE_TEST_OUT:-$(mktemp -d -t speedfest-race-XXXXXX)}"
mkdir -p "$OUT"
if [[ ! -d "$ROOT/server/node_modules/ws" ]]; then
  (cd "$ROOT/server" && npm install --no-audit --no-fund >/dev/null 2>&1) || { echo "FAIL: npm install"; exit 1; }
fi
if [[ ! -d "$ROOT/game/.godot/imported" ]]; then "$ROOT/tools/godot_import.sh" >/dev/null 2>&1 || true; fi
PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
RESULTS_MS=4000 PORT=$PORT HOST=127.0.0.1 PUBLIC_DIR="$OUT/no-public" node "$ROOT/server/server.js" >"$OUT/server.log" 2>&1 &
SERVER_PID=$!
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; kill "$SERVER_PID" 2>/dev/null; wait 2>/dev/null; }
trap cleanup EXIT
for _ in $(seq 1 50); do curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break; sleep 0.2; done
URL="ws://127.0.0.1:$PORT/ws"
TMO=$((DUR + 60))
client() { # role name car
  timeout "$TMO" godot --headless --path "$ROOT/game" --audio-driver Dummy -- \
    --auto_online="$1" --url="$URL" --name="$2" --car="$3" --expect="$N" --duration="$DUR" \
    --quit_after_round "${EXTRA[@]}" >"$OUT/client_$2.log" 2>&1
}
CARS=(kaze brute veloce)
client host Host kaze & PIDS+=($!)
NAMES=(Host)
sleep 1.5
for i in $(seq 1 $((N - 1))); do
  client guest "Guest$i" "${CARS[$((i % 3))]}" & PIDS+=($!)
  NAMES+=("Guest$i")
done
FAIL=0
for idx in "${!PIDS[@]}"; do wait "${PIDS[$idx]}" || { echo "client ${NAMES[$idx]}: non-zero exit"; FAIL=1; }; done
PIDS=()
check() { # name log pattern
  if grep -qE "$3" "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; FAIL=1; fi
}
for n in "${NAMES[@]}"; do
  L="$OUT/client_$n.log"
  echo "client $n:"
  check "race online" "$L" "^RACE ready .*online=true"
  check "synced GO" "$L" "^RACE go synced late_ms=([0-9]|[1-4][0-9])$"
  check "checkpoint 0" "$L" "^RACE checkpoint 0 "
  check "finish" "$L" "^RACE finish ms="
  check "finish accepted" "$L" "^RACE finish_result accepted=true"
  check "remote car" "$L" "^RACE remote_car add"
  check "remote snapshots" "$L" "^RACE remote_stats id=[0-9]+ snapshots=[1-9][0-9]+"
  check "round over" "$L" "^RACE state ROUND_OVER"
  check "results" "$L" "^RACE results \[.*best_ms"
  check "to lobby" "$L" "^RACE to_lobby"
  grep -E "SCRIPT ERROR|^ERROR" "$L" | grep -v "online_lobby" | head -5 && { echo "  (errors above)"; }
done
DNF=$(grep -h "^RACE results" "$OUT"/client_Host.log | grep -o '"best_ms":-1' | wc -l)
[[ "$DNF" -eq 0 ]] || { echo "  FAIL someone DNF in results"; FAIL=1; }
echo "--- server log ---"; tail -15 "$OUT/server.log"
if [[ $FAIL -ne 0 ]]; then echo "FAIL race online_round_test (logs: $OUT)"; exit 1; fi
echo "PASS race online_round_test: $N clients (logs: $OUT)"
