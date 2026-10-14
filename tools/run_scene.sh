#!/usr/bin/env bash
# Run a Godot scene for testing, optionally rendering screenshots.
#
# usage: tools/run_scene.sh <res://scene.tscn> [options] [-- user args]
#   --compat        use the Compatibility renderer (what the web build uses)
#   --headless      no rendering at all (logic tests only; screenshots impossible)
#   --realtime      do not force --fixed-fps 60 (default forces it, so simulation is
#                   deterministic and independent of slow software rendering)
#   --timeout S     kill after S seconds (default 180)
# user args (after --) go to TestHooks, e.g.: -- --frames=120 --shot=/abs/out.png --track=arena
#
# Examples:
#   tools/run_scene.sh res://race/race.tscn -- --frames=180 --shot=$PWD/shot.png --track=arena
#   tools/run_scene.sh res://tests/net/test_net.tscn --headless -- --frames=600
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCENE="$1"; shift
METHOD="forward_plus"; HEADLESS=0; FIXED="--fixed-fps 60"; TIMEOUT=180
while [[ $# -gt 0 ]]; do
  case "$1" in
    --compat) METHOD="gl_compatibility"; shift ;;
    --headless) HEADLESS=1; shift ;;
    --realtime) FIXED=""; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done
if [[ ! -d "$ROOT/game/.godot/imported" ]]; then "$ROOT/tools/godot_import.sh" >/dev/null 2>&1 || true; fi
if [[ $HEADLESS -eq 1 ]]; then
  timeout "$TIMEOUT" godot --headless --path "$ROOT/game" $FIXED --audio-driver Dummy "$SCENE" -- "$@"
else
  timeout "$TIMEOUT" xvfb-run -a -s "-screen 0 1280x720x24" godot --path "$ROOT/game" \
    --rendering-method "$METHOD" --resolution 1280x720 $FIXED --audio-driver Dummy "$SCENE" -- "$@"
fi
