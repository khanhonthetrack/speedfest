#!/usr/bin/env bash
# Run every headless lab of the Stadium remake. Prints STADIUM_TESTS PASS/FAIL.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
timeout 300 godot --headless --path "$ROOT" --import >/dev/null 2>&1 || true
FAIL=0
for t in test_model_lab test_car_body test_car_shapes; do
  OUT=$("$ROOT/tools/run.sh" "res://tests/$t.tscn" --headless --timeout 600 2>&1)
  echo "$OUT" | grep -E "TEST_FAIL|SCRIPT ERROR|TEST_SUMMARY" | sed "s/^/[$t] /"
  if ! echo "$OUT" | grep -q "TEST_SUMMARY ok=[0-9]* fail=0"; then FAIL=1; fi
done
if [[ $FAIL -eq 0 ]]; then echo "STADIUM_TESTS PASS"; else echo "STADIUM_TESTS FAIL"; exit 1; fi
