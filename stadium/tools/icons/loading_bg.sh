#!/usr/bin/env bash
# Renders the loading screen's background (ui/tm_loading.gd; TMNF puts action art there): our car on
# a track's start, seen low from the front, then blurred as if rushing past (sharp around the car,
# streaked toward the edges) and darkened at the corners, into assets/ui/loading_bg.jpg (our own
# render of our own car). Under a renderer (Forward+, Xvfb on Linux).
# usage: stadium/tools/icons/loading_bg.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
"$ROOT/tools/run.sh" res://race/map_view.tscn --timeout 300 -- --track=A03 --car=ours --view=car:30:4.8 \
  --frames=30 --shot="$TMP/bg.png" >/dev/null 2>&1
python3 - "$TMP/bg.png" "$ROOT/assets/ui/loading_bg.jpg" <<'EOF'
import sys
import numpy as np
from PIL import Image, ImageFilter
im = Image.open(sys.argv[1]).convert('RGB')
w, h = im.size
soft = im.filter(ImageFilter.GaussianBlur(3))
a = np.asarray(soft).astype(np.float32)
streak = np.zeros_like(a)
n = 41                                   # a sideways streak, as the car rushes past
for dx in range(-(n // 2), n // 2 + 1):
    streak += np.roll(a, dx, axis=1)
streak /= n
yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
d = np.sqrt(((xx - w * 0.33) / (w * 0.5)) ** 2 + ((yy - h * 0.62) / (h * 0.55)) ** 2)
k = np.clip((d - 0.35) / 0.6, 0, 1)[..., None]         # sharp (softly) around the car
out = a * (1 - k) + streak * k
v = np.clip(1.0 - 0.45 * np.clip(np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) - 0.55, 0, 1), 0, 1)
out = out * v[..., None] * 0.9
Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).resize((1280, 720), Image.LANCZOS).save(sys.argv[2], quality=82, optimize=True)
EOF
rm -rf "${TMP:?}"
ls -la "$ROOT/assets/ui/loading_bg.jpg"
