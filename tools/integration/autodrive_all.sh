#!/usr/bin/env bash
# AutoDriver race on every track (or the ones given): finish time and respawns per track.
# usage: tools/integration/autodrive_all.sh [--car=kaze] [track ...]      prints AUTODRIVE_ALL ok/total
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CAR="kaze"
TRACKS=()
for a in "$@"; do
  case "$a" in
    --car=*) CAR="${a#--car=}" ;;
    *) TRACKS+=("$a") ;;
  esac
done
if [[ ${#TRACKS[@]} -eq 0 ]]; then
  mapfile -t TRACKS < <(grep -oP '^const IDS: Array\[String\] = \[\K[^]]*' "$ROOT/game/tracks/track_defs.gd" | tr -d '" ' | tr ',' '\n')
fi
OK=0
for t in "${TRACKS[@]}"; do
  out=$(timeout 900 "$ROOT/tools/run_scene.sh" res://race/race.tscn --headless --timeout 900 -- --frames=4800 --track="$t" --car="$CAR" --autodrive 2>&1)
  fin=$(echo "$out" | grep -E "RACE finish" | head -1 | grep -oP 'ms=\K[0-9]+')
  resp=$(echo "$out" | grep -E "RACE (respawn|finish)" | awk '/finish/{exit} /respawn/{n++} END{print n+0}')
  err=$(echo "$out" | grep -c "SCRIPT ERROR")
  if [[ -n "$fin" ]]; then
    OK=$((OK + 1)); printf "AUTODRIVE %-10s OK   %6.2f s  respawns %s\n" "$t" "$(echo "$fin/1000" | bc -l)" "$resp"
  else
    printf "AUTODRIVE %-10s FAIL last: %s respawns %s errors %s\n" "$t" "$(echo "$out" | grep -E 'RACE checkpoint' | head -20 | tail -1)" "$resp" "$err"
  fi
done
echo "AUTODRIVE_ALL $OK/${#TRACKS[@]}"
