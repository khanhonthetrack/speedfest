#!/usr/bin/env bash
# Renders the home page's picture panels (PLAN M16: our own cars on our own tracks, staged by
# tools/icons/menu_art.tscn) into assets/ui/menu/<name>.jpg, 1440 x 810 (the panels crop them to
# their shape). Under a renderer (Forward+, Xvfb on Linux); at Ultra about 5-15 min a picture
# with software Vulkan, well under a minute on a graphics card.
# usage: stadium/tools/icons/menu_art.sh [solo multiplayer garage story community editor replays]
#        QUALITY=0 OUT=/abs/dir for quick previews (png, uncropped)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${OUT:-$ROOT/assets/ui/menu}"
QUALITY="${QUALITY:-2}"
TMP="$(mktemp -d)"
mkdir -p "$OUT"
declare -A SHOT
# the red hypercar on a day circuit, its ghost at its shoulder, a low sun behind the stands
SHOT[solo]='--track=A01 --at=0.42 --cars=0:hyper:0:0;1:hyper:-3.4:-8:0:g --cam=-5.2,0.75,8.5 --look=-0.6,0.55,-2.5 --fov=36 --dof=14,30,0.10 --sun=210,22'
# four cars side by side through the neon City at night
SHOT[multiplayer]='--track=F02 --at=0.3 --cars=0:hyper:-1.5:0;1:hyper:2.4:-5;7:hyper:-2.6:-11;4::1.6:-17 --cam=-5.5,1.9,11.0 --look=0.3,0.4,-6.0 --fov=40 --dof=22,40,0.08'
# a black car from behind on a wet City night (Story mode's opening, locked for now)
SHOT[story]='--track=F04 --at=0.55 --cars=5:hyper:0:0 --cam=0.8,1.1,-7.5 --look=0,0.7,3.0 --fov=42 --dof=20,60,0.08'
# a line-up of our cars in five colours
SHOT[community]='--track=A05 --at=0.03 --cars=0:hyper:-6:0;2::-3:0;1:hyper:0:0;3::3:0;7:hyper:6:0 --cam=6.0,3.8,15.0 --look=0,0.4,0.0 --fov=38 --dof=20,40,0.08'
# a track from the air over the editor's grid, the Stadium round it
SHOT[editor]='--track=C03 --at=0.5 --cars= --grid --cam=-70,120,-100 --look=0,0,50 --fov=48'
# the Garage: three of our road cars in their liveries, tuned, their underglow on a City night
SHOT[garage]='--track=F02 --at=0.3 --cars=0:zenith:0:0:0:-:0:6.3.1.4;0:taipan:-3.3:-6:0:-:0:7.2.8.0;0:kobold:3.1:-11:0:-:1:4.6.3.3 --cam=-4.2,0.6,6.2 --look=0.2,0.4,-2.8 --fov=38 --dof=14,35,0.08'
# a trackside camera's long lens on the open-wheeler on dirt
SHOT[replays]='--track=A05 --at=0.4 --cars=2::0:0 --cam=14,5.0,4 --look=0,0.5,0 --fov=20 --dof=16,25,0.12'
NAMES=("$@")
[[ ${#NAMES[@]} -eq 0 ]] && NAMES=(solo multiplayer garage story community editor replays)
for n in "${NAMES[@]}"; do
  # shellcheck disable=SC2086
  "$ROOT/tools/run.sh" res://tools/icons/menu_art.tscn --timeout 2400 -- ${SHOT[$n]} --set_quality="$QUALITY" \
    --settings="$TMP/settings.cfg" --frames=80 --shot="$TMP/$n.png" >"$TMP/$n.log" 2>&1
  if [[ ! -f "$TMP/$n.png" ]]; then echo "ART_FAIL $n"; grep -E "ERROR|SCRIPT" "$TMP/$n.log" | head -5; continue; fi
  if [[ "$QUALITY" != "2" ]]; then cp "$TMP/$n.png" "$OUT/$n.png"; echo "ART_PREVIEW $n"; continue; fi
  python3 - "$TMP/$n.png" "$OUT/$n.jpg" <<'EOF'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGB').resize((1440, 810), Image.LANCZOS)
im.save(sys.argv[2], quality=86, optimize=True, progressive=True)
EOF
  echo "ART $n"
done
rm -rf "${TMP:?}"
