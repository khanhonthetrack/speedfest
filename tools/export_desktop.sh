#!/usr/bin/env bash
# Export the PC builds (Forward+, desktop textures, the 2K "hd" assets included):
#   build/windows/SpeedFest.exe (+ console wrapper)   build/linux/speedfest.x86_64
# then zip them for download: build/SpeedFest-windows.zip, build/SpeedFest-linux.zip.
# usage: tools/export_desktop.sh [windows|linux|all] [--debug]
#   BAKE_SHADERS=1  bake Vulkan shaders into the build (shorter first launch). The baker needs a
#                   real RenderingDevice, so this runs the editor under Xvfb with software Vulkan
#                   (mesa-vulkan-drivers) instead of --headless; much slower.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WHICH="${1:-all}"
case "$WHICH" in windows|linux|all) ;; *) echo "usage: tools/export_desktop.sh [windows|linux|all] [--debug]" >&2; exit 2 ;; esac
MODE="--export-release"
[[ "${2:-}" == "--debug" ]] && MODE="--export-debug"
RUN=(godot --headless)
[[ "${BAKE_SHADERS:-0}" == "1" ]] && RUN=(xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan)
"$ROOT/tools/godot_import.sh" >/dev/null 2>&1 || true
export_one() { # preset dir file zipname
  mkdir -p "$ROOT/build/$2"
  rm -f "$ROOT/build/$2"/*
  "${RUN[@]}" --path "$ROOT/game" $MODE "$1" "$ROOT/build/$2/$3" 2>&1 | grep -vE "^\s*$" | tail -5
  test -s "$ROOT/build/$2/$3"
  (cd "$ROOT/build" && rm -f "$4" && python3 -c "import shutil,sys; shutil.make_archive(sys.argv[1], 'zip', '.', sys.argv[2])" "${4%.zip}" "$2")
  ls -la "$ROOT/build/$2" "$ROOT/build/$4"
}
[[ "$WHICH" == "all" || "$WHICH" == "windows" ]] && export_one "Windows" windows SpeedFest.exe SpeedFest-windows.zip
[[ "$WHICH" == "all" || "$WHICH" == "linux" ]] && export_one "Linux" linux speedfest.x86_64 SpeedFest-linux.zip
exit 0
