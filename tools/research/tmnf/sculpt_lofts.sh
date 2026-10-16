#!/usr/bin/env bash
# Regenerates stadium/blocks/data/sculpt_lofts.json (the Sculpt pieces' lofts, our own resampled
# rings) from the local measurements. usage: sculpt_lofts.sh MEAS_DIR [PYTHON]
set -euo pipefail
T="$(cd "$(dirname "$0")" && pwd)"
MEAS="$1"
PY="${2:-${PYTHON:-python3}}"
OUT="$T/../../../stadium/blocks/data/sculpt_lofts.json"
rm -f "$OUT"
B=Sculpt/Bridge/BridgeSuspendSlope2
"$PY" -I "$T/loft_sections.py" "$MEAS" "$OUT" "\
Sculpt/A/Ground=Sculpt/A/Ground:StadiumSculpt:1.05:92.5:1:40,\
Sculpt/A/Ground#pads=Sculpt/A/Ground:StadiumFabric:1.02:1.68:0.33:16:flat,\
Sculpt/B/Ground=Sculpt/B/Ground:StadiumSculpt2:1.05:98:1:40,\
Sculpt/C/Ground=Sculpt/C/Ground:StadiumPlatformPillar:1.05:92:1:24,\
$B=$B:StadiumSculptAuvent2+StadiumPlatformPillar+StadiumWarpStands2:7.7:171.5:1:32:z,\
$B#struts=$B:StadiumSculptStructureAlpha:13.8:104.8:1:12:z"
