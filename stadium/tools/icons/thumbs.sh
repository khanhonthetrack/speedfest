#!/usr/bin/env bash
# Renders the campaign's track pictures for the menu's cards (TMNF shows a shot of each track on its
# campaign cards): each track of tracks/campaign.json built by race/map_view.tscn, seen from above
# and behind its start, cropped to the card's shape and saved small into assets/ui/thumbs/<ID>.jpg
# (our own renders of our own tracks). Under a renderer (Forward+, Xvfb on Linux); about 30 s a track.
# usage: stadium/tools/icons/thumbs.sh [A01 B05 ...]   (no ids: every campaign track)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/assets/ui/thumbs"
TMP="$(mktemp -d)"
mkdir -p "$OUT"
IDS=("$@")
if [[ ${#IDS[@]} -eq 0 ]]; then
  mapfile -t IDS < <(python3 -c "import json,sys;[print(t) for s in json.load(open(sys.argv[1]))['series'] for t in s['tracks']]" "$ROOT/tracks/campaign.json")
fi
for id in "${IDS[@]}"; do
  "$ROOT/tools/run.sh" res://race/map_view.tscn --timeout 300 -- --track="$id" --view=rel:-6,20,-32,0,0,45 --fov=55 \
    --frames=30 --shot="$TMP/$id.png" >/dev/null 2>&1
  if [[ -f "$TMP/$id.png" ]]; then
    python3 - "$TMP/$id.png" "$OUT/$id.jpg" <<'EOF'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGB')
w, h = im.size
cw = int(h * 1.58)                       # the card's picture: 180 x 114
im = im.crop(((w - cw) // 2, 0, (w - cw) // 2 + cw, h)).resize((316, 200), Image.LANCZOS)
im.save(sys.argv[2], quality=84, optimize=True)
EOF
    echo "THUMB $id"
  else
    echo "THUMB_FAIL $id"
  fi
done
rm -rf "${TMP:?}"
