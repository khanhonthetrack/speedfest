#!/usr/bin/env bash
# Screenshots of every ui_menus screen on Forward+ and Compatibility.
# usage: game/tests/ui_menus/screenshots.sh [outdir]   (lobby room view needs a server: see lobby_smoke.sh)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="${1:-${TMPDIR:-/tmp}/speedfest-ui-shots}"
mkdir -p "$OUT"
shot() { # name scene renderer args...
  local name="$1" scene="$2" r="$3"; shift 3
  local flag=""; [[ "$r" == "compat" ]] && flag="--compat"
  "$ROOT/tools/run_scene.sh" "$scene" $flag -- --frames=90 --shot="$OUT/${name}_$r.png" "$@" 2>&1 | grep -E "SCREENSHOT|SCRIPT ERROR" || echo "FAILED $name $r"
}
for r in fwd compat; do
  shot main_menu res://ui/main_menu.tscn $r
  shot main_menu_name res://ui/main_menu.tscn $r --name_prompt
  shot track_select res://ui/track_select.tscn $r
  for t in 0 1 2 3 4; do shot garage_tab$t res://ui/garage.tscn $r --tab=$t; done
  shot settings res://ui/settings_menu.tscn $r
  shot lobby_connect res://ui/online_lobby.tscn $r --lobby_no_autoconnect
done
echo "shots in $OUT"
