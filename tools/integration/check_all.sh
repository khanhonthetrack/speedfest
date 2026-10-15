#!/usr/bin/env bash
# Integration gate: compile check, every module test suite, server tests, and an AutoDriver
# finish check on every track in the real race scene. Prints one line per check and a summary.
#
# usage: tools/integration/check_all.sh [--quick]     (--quick skips the autodrive and online checks)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
QUICK=0; [[ "${1:-}" == "--quick" ]] && QUICK=1
FAILS=0
report() { # name status detail
  printf "%-34s %s %s\n" "$1" "$2" "$3"
  [[ "$2" == "OK" ]] || FAILS=$((FAILS + 1))
}

tools/godot_import.sh >/dev/null 2>&1
out=$(tools/check_scripts.sh 2>&1)
if echo "$out" | grep -q "SCRIPT_ERRORS=0"; then report compile OK "$(echo "$out" | grep SCRIPT_OK_COUNT)"
else report compile FAIL "$(echo "$out" | grep -E 'SCRIPT_ERROR|Parse' | head -3 | tr '\n' ' ')"; fi

# Every test scene that ends with TestHooks.finish() (skip demos/benches/drivers).
for scene in $(cd game && ls tests/*/test_*.tscn tests/*/*_test.tscn 2>/dev/null | sort -u | grep -v "tests/net/net_client_test"); do  # net_client_test needs a server: covered by net_smoke
  name="${scene%.tscn}"
  out=$(timeout 600 tools/run_scene.sh "res://$scene" --headless --timeout 600 -- --frames=4000 2>&1)
  sum=$(echo "$out" | grep -E "TEST_SUMMARY" | tail -1)
  if [[ -n "$sum" ]] && echo "$sum" | grep -q "fail=0"; then report "$name" OK "$sum"
  else report "$name" FAIL "$(echo "$out" | grep -E 'TEST_FAIL|SCRIPT ERROR|TEST_SUMMARY' | head -3 | tr '\n' ' ')"; fi
done

if [[ -x game/tests/physics/run_all.sh ]]; then
  out=$(timeout 900 game/tests/physics/run_all.sh 2>&1)
  if echo "$out" | grep -q PHYSICS_ALL_OK; then report physics/run_all OK ""; else report physics/run_all FAIL "$(echo "$out" | tail -3 | tr '\n' ' ')"; fi
fi

if [[ -d server/node_modules ]] || (cd server && npm install --no-audit --no-fund >/dev/null 2>&1); then
  out=$(cd server && npm test 2>&1)
  if echo "$out" | grep -q "^# fail 0"; then report server/npm_test OK "$(echo "$out" | grep '^# pass')"
  else report server/npm_test FAIL "$(echo "$out" | grep -E 'not ok' | head -3 | tr '\n' ' ')"; fi
fi

if [[ $QUICK -eq 0 ]]; then
  for t in arena downtown coast; do
    out=$(timeout 900 tools/run_scene.sh res://race/race.tscn --headless --timeout 900 -- --frames=4800 --track=$t --autodrive 2>&1)
    fin=$(echo "$out" | grep -E "RACE finish" | head -1)
    resp=$(echo "$out" | grep -c "RACE respawn")
    if [[ -n "$fin" ]]; then report "autodrive/$t" OK "$fin respawns=$resp"
    else report "autodrive/$t" FAIL "no finish; $(echo "$out" | grep -E 'RACE checkpoint' | tail -1) respawns=$resp"; fi
  done
  out=$(timeout 600 tools/net_smoke_test.sh 2>&1 | tail -1)
  if echo "$out" | grep -q PASS; then report net_smoke OK "$out"; else report net_smoke FAIL "$out"; fi
  out=$(timeout 300 tools/live_smoke_test.sh 2>&1 | tail -1)
  if echo "$out" | grep -q PASS; then report live_smoke OK "$out"; else report live_smoke FAIL "$out"; fi
  if [[ -x game/tests/race/online_round_test.sh ]]; then
    out=$(timeout 900 game/tests/race/online_round_test.sh 3 75 --autodrive --track=arena 2>&1)
    finishes=$(echo "$out" | grep -c " finished ")
    if echo "$out" | tail -1 | grep -q PASS; then report online_round OK "finishes=$finishes"
    else report online_round FAIL "$(echo "$out" | tail -2 | tr '\n' ' ')"; fi
  fi
fi

echo "CHECK_ALL $([[ $FAILS -eq 0 ]] && echo PASS || echo "FAIL ($FAILS)")"
exit $([[ $FAILS -eq 0 ]] && echo 0 || echo 1)
