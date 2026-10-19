#!/usr/bin/env bash
# Regenerate all SpeedFest audio and import it into Godot with the right loop flags.
# usage: tools/audio/build.sh [--only engines|sfx|music] [--png DIR]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
python3 "$HERE/gen_all.py" "$@"
"$ROOT/tools/godot_import.sh" >/dev/null 2>&1 || true
python3 "$HERE/fix_loops.py"
"$ROOT/tools/godot_import.sh" >/dev/null 2>&1 || true
du -ch "$ROOT"/game/audio/generated/*.ogg | tail -1
