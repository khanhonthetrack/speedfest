#!/usr/bin/env bash
# Run every headless lab of the Stadium remake. Prints STADIUM_TESTS PASS/FAIL.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
timeout 300 "${GODOT:-godot}" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
FAIL=0
# TMNF_DIR=/path/to/TmNationsForever also checks the GBX reader on the official campaign
EXTRA=""; [[ -n "${TMNF_DIR:-}" ]] && EXTRA="--tmnf=$TMNF_DIR"
for t in test_model_lab test_car_body test_car_shapes test_car_pack test_car_models test_texture_mod test_skyline test_gbx test_blocks test_ghost test_replay test_tyre_marks test_editor test_menu test_sound test_opponent test_top_bar test_online test_community test_race test_track_areas test_tracks; do
  OUT=$("$ROOT/tools/run.sh" "res://tests/$t.tscn" --headless --timeout 1200 -- $EXTRA 2>&1)
  echo "$OUT" | grep -E "TEST_FAIL|SCRIPT ERROR|TEST_SUMMARY" | sed "s/^/[$t] /"
  if ! echo "$OUT" | grep -q "TEST_SUMMARY ok=[0-9]* fail=0"; then FAIL=1; fi
done
# the online server's own tests (Node.js; skipped without it)
if command -v node >/dev/null 2>&1; then
  [[ -d "$ROOT/server/node_modules/ws" ]] || (cd "$ROOT/server" && npm install --silent >/dev/null 2>&1)
  if (cd "$ROOT/server" && npm test >/tmp/stadium_server_test.txt 2>&1); then echo "[server] npm test PASS"; else echo "[server] npm test FAIL"; FAIL=1; fi
fi
if [[ $FAIL -eq 0 ]]; then echo "STADIUM_TESTS PASS"; else echo "STADIUM_TESTS FAIL"; exit 1; fi
