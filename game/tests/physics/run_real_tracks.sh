#!/usr/bin/env bash
# Integration matrix (needs the real tracks module): every car on every track, analog AutoDriver
# and keyboard emulation. Prints one line per run and REAL_TRACKS_ALL_OK when all have 0 respawns.
# usage: game/tests/physics/run_real_tracks.sh [tracks...]   (default: arena downtown coast)
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TRACKS=("$@"); [[ ${#TRACKS[@]} -eq 0 ]] && TRACKS=(arena downtown coast)
FAIL=0
for t in "${TRACKS[@]}"; do for c in kaze brute veloce; do for kb in false true; do
  out=$("$ROOT/tools/run_scene.sh" res://tests/physics/test_real_tracks.tscn --headless --timeout 400 -- --track=$t --car=$c --keyboard=$kb 2>&1)
  line=$(echo "$out" | grep -E "^RESULT" | tail -1)
  where=$(echo "$out" | grep -E "respawn #" | sed -E 's/.*at cp (-?[0-9]+) \(pos \(([^)]*)\)\)/cp\1@(\2)/' | tr '\n' ' ')
  [[ -z "$line" ]] && line="DID NOT FINISH"
  echo "$t $c kb=$kb: $line ${where}"
  echo "$out" | grep -q "TEST_SUMMARY ok=[0-9]* fail=0" || FAIL=1
done; done; done
[[ $FAIL -eq 0 ]] && echo "REAL_TRACKS_ALL_OK" || echo "REAL_TRACKS_SOME_FAILED"
exit $FAIL
