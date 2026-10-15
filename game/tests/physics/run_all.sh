#!/usr/bin/env bash
# Runs every physics test headless for every car. Prints RESULT lines and a pass/fail summary.
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FAIL=0
run() { local out; out=$("$ROOT/tools/run_scene.sh" "$@" 2>&1); echo "$out" | grep -E "RESULT|TEST_FAIL|TEST_SUMMARY|SCRIPT ERROR|ERROR:" ; echo "$out" | grep -q "TEST_SUMMARY ok=[0-9]* fail=0" || FAIL=1; }
run res://tests/physics/test_straight.tscn --headless -- --frames=6000
run res://tests/physics/test_tuning.tscn --headless -- --frames=10
run res://tests/physics/test_input.tscn --headless -- --frames=400
for c in kaze brute veloce; do
  run res://tests/physics/test_stunts.tscn --headless -- --car=$c
  run res://tests/physics/test_handling.tscn --headless -- --car=$c
  run res://tests/physics/test_circuit.tscn --headless -- --car=$c
done
run res://tests/physics/test_stunts.tscn --headless -- --car=kaze --r=25
run res://tests/physics/test_stunts.tscn --headless -- --car=brute --r=15 --fast=false
[[ $FAIL -eq 0 ]] && echo "PHYSICS_ALL_OK" || echo "PHYSICS_SOME_FAILED"
exit $FAIL
