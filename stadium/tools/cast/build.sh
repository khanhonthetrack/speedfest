#!/usr/bin/env bash
# The story's cast (PLAN M20-9): each spec in tools/cast/specs/ built by MPFB in Blender
# (blender/gen_char.py), its textures converted and shared (post.py) into assets/cast/, the textures
# no one uses any more deleted, then Godot's import (cast_import.gd gives the materials).
#   stadium/tools/cast/setup.sh                 # once: Blender, MPFB, the packs (CAST_CACHE)
#   stadium/tools/cast/build.sh [id ...]        # every spec, or only these
# Every asset a spec names must pass the licence gate first (licences.py --spec); the credits are
# rewritten from what ships (--built).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
STADIUM="$(cd "$HERE/../.." && pwd)"
CACHE="${CAST_CACHE:-$HOME/.cache/speedfest-cast}"
[[ -f "$CACHE/env.sh" ]] || { echo "BUILD_FAIL no $CACHE/env.sh: run tools/cast/setup.sh" >&2; exit 1; }
source "$CACHE/env.sh"
CAST="$STADIUM/assets/cast"
GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null || { echo "BUILD_FAIL no godot: put it on PATH or set GODOT=" >&2; exit 1; }
ids=("$@")
if [[ ${#ids[@]} -eq 0 ]]; then
  for f in "$HERE"/specs/*.json; do ids+=("$(basename "$f" .json)"); done
fi
SPECS=(); for id in "${ids[@]}"; do SPECS+=("$HERE/specs/$id.json"); done
python3 -I "$HERE/licences.py" "$CACHE/zips" --spec "${SPECS[@]}" ||
  { echo "BUILD_FAIL licences" >&2; exit 1; }
for id in "${ids[@]}"; do
  out="$CACHE/out/$id"
  rm -rf "$out"
  "$BLENDER" -b -noaudio -P "$HERE/blender/gen_char.py" -- "$HERE/specs/$id.json" "$out" 2>&1 |
    grep -E "^CAST |Error|Traceback" || true
  [[ -f "$out/$id.gltf" ]] || { echo "BUILD_FAIL $id: no glTF" >&2; exit 1; }
  python3 -I "$HERE/post.py" "$out" "$CAST" | tail -1
done
python3 -I "$HERE/post.py" --prune "$CAST"
# the credits name what ships (every built character's sidecar), not what the specs say now
python3 -I "$HERE/licences.py" "$CACHE/zips" --built "$CAST" --credits "$CAST/CREDITS.md" >&2 ||
  { echo "BUILD_FAIL credits: a shipped asset fails the licence gate (LICENCE_FAIL above)" >&2; exit 1; }
timeout 900 "$GODOT" --headless --path "$STADIUM" --import >/dev/null 2>&1 ||
  echo "BUILD_WARN godot's import returned an error: run it by hand and look" >&2
echo "BUILD_OK ${ids[*]}"
