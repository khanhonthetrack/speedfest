#!/usr/bin/env bash
# Regenerates stadium/blocks/data/sculpt_lofts.json (the Sculpt pieces' lofts, our own resampled
# rings) from the local measurements. usage: sculpt_lofts.sh MEAS_DIR [PYTHON]
# Each piece: its body, "#struts" (the thin side struts) and "#rail" (the road-edge rails); the
# x-mirrored pieces reuse these (blocks/shapes/sculpt.gd MIRRORED).
set -euo pipefail
T="$(cd "$(dirname "$0")" && pwd)"
MEAS="$1"
PY="${2:-${PYTHON:-python3}}"
OUT="$T/../../../stadium/blocks/data/sculpt_lofts.json"
rm -f "$OUT"
BODY="StadiumSculptAuvent2+StadiumPlatformPillar+StadiumPlatformStands2+StadiumWarpStands2"
STRUT="StadiumSculptStructureAlpha"
RAIL="StadiumPlatformRoadBorder+StadiumPlatformRoadDetails+StadiumRoadBorder+StadiumRoadDetails"
SPEC="\
Sculpt/A/Ground=Sculpt/A/Ground:StadiumSculpt:1.05:92.5:1:40,\
Sculpt/A/Ground#pads=Sculpt/A/Ground:StadiumFabric:1.02:1.68:0.33:16:flat,\
Sculpt/B/Ground=Sculpt/B/Ground:StadiumSculpt2:1.05:98:1:40,\
Sculpt/C/Ground=Sculpt/C/Ground:StadiumPlatformPillar:1.05:92:2:24"
B=Sculpt/Bridge/BridgeSuspendSlope2
SPEC="$SPEC,$B=$B:StadiumSculptAuvent2+StadiumPlatformPillar+StadiumWarpStands2:7.7:171.5:1:32:z,$B#struts=$B:$STRUT:13.8:104.8:1:12:z"
# bridge pieces lying along z: name:z0:z1
for p in BridgeStraightSmallAir:-0.6:32.6 BridgeStraightAir:-0.6:64.6 BridgeSlopeStartAir:7.7:64.6 \
         BridgeSlopeEndAir:-0.6:56.5 BridgeSlopeStartGround:0.1:63.9; do
  n=${p%%:*}; r=${p#*:}; a=${r%%:*}; b=${r#*:}; S="Sculpt/Bridge/$n"
  SPEC="$SPEC,$S=$S:$BODY:$a:$b:2:32:z,$S#struts=$S:$STRUT:$a:$b:2:12:z,$S#rail=$S:$RAIL:$a:$b:1:16:z"
done
# the suspended end falls steeply: 1 m slices keep its slab one tube
S=Sculpt/Bridge/BridgeSuspendSlopeEnd
SPEC="$SPEC,$S=$S:$BODY:-0.6:171.5:1:32:z,$S#struts=$S:$STRUT:-0.6:171.5:1:12:z,$S#rail=$S:$RAIL:-0.6:171.5:1:16:z"
# the bridges' pillars stand up y: name:y0:y1
for p in BridgePillarAir:-0.6:48.6 BridgePillarGround:1.05:48.6; do
  n=${p%%:*}; r=${p#*:}; a=${r%%:*}; b=${r#*:}; S="Sculpt/Bridge/$n"
  # the walkway on the pillar's side only closes together with the column: one material set
  SPEC="$SPEC,$S=$S:$BODY+$RAIL:$a:$b:2:40:flat,$S#struts=$S:$STRUT:$a:$b:2:12"
done
# arch rings: rising curves, sliced across z
ARCH="StadiumPlatformPillar+StadiumPlatformRoadDetails+StadiumPlatformRoadBorder"
for p in StartGround:0.1:165 EndGround:0.1:184.5; do
  n=${p%%:*}; r=${p#*:}; a=${r%%:*}; b=${r#*:}; S="Sculpt/ArchRing/$n"
  SPEC="$SPEC,$S=$S:$ARCH:$a:$b:1:32:z"
done
# the airship: a blimp along z (body, gondola, tail fins)
SPEC="$SPEC,Other/Airship=Other/Airship:StadiumAirship:0.6:183.9:2:40:z"
# the big screen hanging under Fabric/FabricCross3x3Screen
F=Fabric/FabricCross3x3Screen
SPEC="$SPEC,$F#screen=$F:StadiumControlStands2+StadiumRoadDetails+StadiumScreen8x1A+StadiumControlScreen2x1:5.8:39.4:1:32"
"$PY" -I "$T/loft_sections.py" "$MEAS" "$OUT" "$SPEC"
