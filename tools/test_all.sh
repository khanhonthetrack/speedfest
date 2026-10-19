#!/usr/bin/env bash
# Run every headless test scene in game/tests (test_*.tscn). Prints TESTS PASS/FAIL.
# usage: tools/test_all.sh [name ...]   (default: all)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
timeout 300 godot --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
FAIL=0
if [[ $# -gt 0 ]]; then
  TESTS=("$@")
else
  mapfile -t TESTS < <(cd "$ROOT/game/tests" && ls test_*.tscn 2>/dev/null | sed 's/\.tscn$//' | sort)
fi
# TMNF_DIR=/path/to/TmNationsForever also checks the GBX reader on the official campaign
EXTRA=""; [[ -n "${TMNF_DIR:-}" ]] && EXTRA="--tmnf=$TMNF_DIR"
for t in "${TESTS[@]}"; do
  OUT=$("$ROOT/tools/run_scene.sh" "res://tests/$t.tscn" --headless --timeout 600 -- $EXTRA 2>&1)
  echo "$OUT" | grep -E "TEST_FAIL|SCRIPT ERROR|TEST_SUMMARY" | sed "s/^/[$t] /"
  if ! echo "$OUT" | grep -q "TEST_SUMMARY ok=[0-9]* fail=0"; then echo "[$t] NO SUMMARY / FAILED"; FAIL=1; fi
done
if [[ $FAIL -eq 0 ]]; then echo "TESTS PASS"; else echo "TESTS FAIL"; exit 1; fi
