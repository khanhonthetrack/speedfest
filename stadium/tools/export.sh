#!/usr/bin/env bash
# Exports SpeedFest Stadium for Windows and/or Linux (Godot 4.7.2 export templates installed) and
# zips each build with PLAYING.txt and the credits: build/stadium/SpeedFestStadium-<os>.zip.
#   stadium/tools/export.sh [windows|linux|all]       (GODOT=... for another godot binary)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(cd "$ROOT/.." && pwd)/build/stadium"
WHICH="${1:-all}"
GD="${GODOT:-godot}"
timeout 600 "$GD" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
PY=""
for c in python3 python py; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c "import zipfile" >/dev/null 2>&1; then PY="$c"; break; fi
done
[[ -n "$PY" ]] || { echo "export.sh: needs Python 3 (for the zip)"; exit 1; }
for os in windows linux; do
  [[ "$WHICH" == all || "$WHICH" == "$os" ]] || continue
  preset=$([[ $os == windows ]] && echo Windows || echo Linux)
  exe=$([[ $os == windows ]] && echo SpeedFestStadium.exe || echo SpeedFestStadium.x86_64)
  rm -rf "$OUT/$os" && mkdir -p "$OUT/$os"
  "$GD" --headless --path "$ROOT" --export-release "$preset" "$OUT/$os/$exe"
  cp "$ROOT/PLAYING.txt" "$OUT/$os/"
  cp "$ROOT/audio/music/CREDITS.md" "$OUT/$os/CREDITS-music.md"
  cp "$ROOT/audio/sfx/CREDITS.md" "$OUT/$os/CREDITS-sounds.md"
  cp "$ROOT/assets/fonts/OFL-Orbitron.txt" "$ROOT/assets/fonts/OFL-Rajdhani.txt" "$OUT/$os/"
  "$PY" - "$OUT/$os" "$OUT/SpeedFestStadium-$os.zip" <<'PYEOF'
import os, sys, zipfile
src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name in sorted(os.listdir(src)):
        info = zipfile.ZipInfo('SpeedFestStadium/' + name)
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = (0o755 if name.endswith(('.x86_64', '.exe')) else 0o644) << 16
        with open(os.path.join(src, name), 'rb') as f:
            z.writestr(info, f.read())
print('EXPORTED', dst, os.path.getsize(dst) // (1 << 20), 'MB')
PYEOF
done
