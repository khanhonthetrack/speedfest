#!/usr/bin/env bash
# Export the PC builds (Forward+, desktop textures, the 2K "hd" assets included):
#   build/windows/SpeedFest.exe (+ console wrapper)   build/linux/speedfest.x86_64
# then zip them for download: build/SpeedFest-windows.zip, build/SpeedFest-linux.zip.
# usage: tools/export_desktop.sh [windows|linux|all] [--debug]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WHICH="${1:-all}"
MODE="--export-release"
[[ "${2:-}" == "--debug" ]] && MODE="--export-debug"
"$ROOT/tools/godot_import.sh" >/dev/null 2>&1 || true
export_one() { # preset dir file zipname
  mkdir -p "$ROOT/build/$2"
  rm -f "$ROOT/build/$2"/*
  godot --headless --path "$ROOT/game" $MODE "$1" "$ROOT/build/$2/$3" 2>&1 | grep -vE "^\s*$" | tail -5
  (cd "$ROOT/build" && rm -f "$4" && python3 -c "import shutil,sys; shutil.make_archive(sys.argv[1], 'zip', '.', sys.argv[2])" "${4%.zip}" "$2")
  ls -la "$ROOT/build/$2" "$ROOT/build/$4"
}
[[ "$WHICH" == "all" || "$WHICH" == "windows" ]] && export_one "Windows" windows SpeedFest.exe SpeedFest-windows.zip
[[ "$WHICH" == "all" || "$WHICH" == "linux" ]] && export_one "Linux" linux speedfest.x86_64 SpeedFest-linux.zip
exit 0
