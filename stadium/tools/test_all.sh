#!/usr/bin/env bash
# Run every headless lab of the Stadium remake. Prints STADIUM_TESTS PASS/FAIL.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
timeout 300 "${GODOT:-godot}" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
FAIL=0
# TMNF_DIR=/path/to/TmNationsForever also checks the GBX reader on the official campaign
EXTRA=""; [[ -n "${TMNF_DIR:-}" ]] && EXTRA="--tmnf=$TMNF_DIR"
# Each suite's output goes to a file, not through $( ... ): the test servers test_online and
# test_community start (node server/server.js) share the client's stdout, and a client that dies
# before killing them would leave the pipe open and the gate waiting for ever.
TMP="$(mktemp -d "${TMPDIR:-/tmp}/stadium_tests.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
# Kill the test servers a suite left behind: test_online's ports 18091-18093, test_community's
# 18095 ([s] keeps the pattern from matching a command line that holds it). Git Bash has no pkill.
kill_test_servers() {
  command -v pkill >/dev/null 2>&1 || return 0
  local p='[s]erver/server\.js --port=(1809[123]|18095)( |$)'
  pkill -f "$p" || return 0
  for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "$p" >/dev/null || return 0; sleep 0.2; done
  pkill -KILL -f "$p"; return 0
}
kill_test_servers
for t in test_model_lab test_car_body test_car_shapes test_car_pack test_car_models test_texture_mod test_skyline test_gbx test_blocks test_ghost test_replay test_tyre_marks test_editor test_menu test_sound test_opponent test_top_bar test_online test_community test_race test_track_areas test_tracks; do
  OUT="$TMP/$t.txt"
  "$ROOT/tools/run.sh" "res://tests/$t.tscn" --headless --timeout 1200 -- $EXTRA >"$OUT" 2>&1
  CODE=$?
  kill_test_servers
  grep -E "TEST_FAIL|SCRIPT ERROR|TEST_SUMMARY" "$OUT" | sed "s/^/[$t] /"
  # a run that crashed or timed out (124) never printed its summary: say which suite it was
  grep -q "TEST_SUMMARY" "$OUT" || echo "[$t] TEST_FAIL no TEST_SUMMARY: the run ended early (exit code $CODE)"
  if ! grep -q "TEST_SUMMARY ok=[0-9]* fail=0" "$OUT"; then FAIL=1; fi
done
# the online server's own tests (Node.js; skipped without it)
if command -v node >/dev/null 2>&1; then
  [[ -d "$ROOT/server/node_modules/ws" ]] || (cd "$ROOT/server" && npm install --silent >/dev/null 2>&1)
  if (cd "$ROOT/server" && npm test >/tmp/stadium_server_test.txt 2>&1); then echo "[server] npm test PASS"; else echo "[server] npm test FAIL"; FAIL=1; fi
fi
if [[ $FAIL -eq 0 ]]; then echo "STADIUM_TESTS PASS"; else echo "STADIUM_TESTS FAIL"; exit 1; fi
