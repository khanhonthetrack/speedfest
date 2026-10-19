#!/usr/bin/env bash
# Run a scene of SpeedFest (game/). Forces --fixed-fps 100 (one 100 Hz physics tick per frame)
# unless --realtime, so headless runs are deterministic on the slow software renderer.
# usage: tools/run_scene.sh <res://scene.tscn> [--headless] [--realtime] [--timeout S] [-- user args]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../game" && pwd)"
SCENE="$1"; shift
HEADLESS=0; FIXED="--fixed-fps 100"; TIMEOUT=240
while [[ $# -gt 0 ]]; do
  case "$1" in
    --headless) HEADLESS=1; shift ;;
    --realtime) FIXED=""; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done
if [[ ! -d "$ROOT/.godot/imported" ]]; then timeout 300 godot --headless --path "$ROOT" --import >/dev/null 2>&1 || true; fi
if [[ $HEADLESS -eq 1 ]]; then
  timeout "$TIMEOUT" godot --headless --path "$ROOT" $FIXED --audio-driver Dummy "$SCENE" -- "$@"
else
  timeout "$TIMEOUT" xvfb-run -a -s "-screen 0 1600x900x24" godot --path "$ROOT" \
    --rendering-method forward_plus --resolution 1600x900 $FIXED --audio-driver Dummy "$SCENE" -- "$@"
fi
