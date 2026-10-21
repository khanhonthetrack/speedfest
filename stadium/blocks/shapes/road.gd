extends RefCounted
## Stadium "Road/Main" blocks: the classic road (a 21 m asphalt strip at 1.345 m between grid
## shoulders and rounded curbs; elevated pieces have a shallow keel below, ground pieces run their
## curbs' outer faces down to the terrain). Our own geometry from measured numbers (TMNF
## block-local metres: x right, y up, z forward; see TmGeo).
##
## Straights and slopes sweep the section along z (slopes shear it up 8 m per block, as TMNF does);
## corners and GT curves sweep it around the footprint's corner (road centre radius 32k - 16);
## junctions (T, cross) are a flat deck with straight curbs along the closed sides and the curb
## revolved around each block corner where two arms meet; dead ends and the lone base piece are
## short crowned sweeps ending in a low nose. Shape index: 0 base, 1 dead end (opens to +z),
## 2 corner (+z, -x), 3 straight (+z, -z), 4 T (adds -x), 5 cross.

const S_ROAD := 16              # StadiumRoad (asphalt)
const S_METAL := 4
const S_RUBBER := 9
const S_TURBO := 7
const S_FREEWHEEL := 29
const TOP := 1.345              ## the road surface
const CROWN := 0.19             ## dead ends and the base sink this much toward their noses

## Left half of the cross-section, (x, y) with x across the road (centre 16), from the bottom
## centre round the left curb to the top centre; each point's material is the segment's from it.
## Air: keel underneath. Ground: the curb's outer face runs down to the terrain (1 m).
## As TMNF's: the curbs, the road's lip and the keel's plates are bands of the border atlas
## (TmMaterials "border_*", texgen/borders.py; the fifth column: the atlas rows at the segment's
## two ends, measured from TMNF's UVs: TmGeo.sweep), the keel's underside TMNF's light plates
## ("road_under"); curb_face (the curb's face towards the road, a gate block's own word there) and
## shoulder (the strip at road level; on the ground the border's green band) see _entry().
const HALF_AIR := [
	[16.0, 0.0, "border_ribs", S_METAL, Vector2(213.9, 152.1)], [14.339, 0.0, "road_under", S_METAL],
	[9.758, 0.418, "road_under", S_METAL], [5.177, 0.836, "border_ribs", S_METAL, Vector2(215.0, 188.0)],
	[5.177, 1.243, "road_grid", S_METAL], [3.212, 1.243, "border_ribs", S_METAL, Vector2(206.8, 152.1)],
	[2.004, 1.243, "border_black", S_RUBBER, Vector2(299.8, 258.0)],
	[1.712, 1.753, "border_black", S_RUBBER, Vector2(258.0, 216.1)],
]
const HALF_GROUND := [
	[16.0, 1.0, "", TmGeo.NO_COLLISION], [1.0, 1.0, "border_panel", S_METAL, Vector2(150.0, 92.4)],
	[1.282, 1.851, "border_panel", S_METAL, Vector2(92.4, 34.8)],
]
## A gate block's on the ground: the curb's outer face its sign (as TMNF's: _entry), split where the
## air curb's top starts (HALF_TOP_AIR follows), the face's rows spread as the air curb's.
const HALF_GROUND_GATE := [
	[16.0, 1.0, "", TmGeo.NO_COLLISION], [1.0, 1.0, "border_black", S_METAL, Vector2(300.0, 243.5)],
	[1.282, 1.851, "border_black", S_METAL, Vector2(243.5, 216.1)],
]
## The curb and the road surface, shared by both (air starts at the curb's outer rubber face).
const HALF_TOP_AIR := [[1.419, 2.263, "border_panel", S_METAL, Vector2(0.0, 17.4)],
	[1.492, 2.482, "border_panel", S_METAL, Vector2(17.4, 34.8)]]
const HALF_TOP := [
	[1.565, 2.701, "border_panel", S_METAL, Vector2(34.8, 30.7)], [1.616, 2.739, "border_panel", S_METAL, Vector2(30.7, 26.6)],
	[1.668, 2.777, "border_panel", S_METAL, Vector2(26.6, 18.9)], [1.792, 2.777, "border_panel", S_METAL, Vector2(18.9, 9.5)],
	[1.834, 2.636, "border_panel", S_METAL, Vector2(9.5, 0.0)], [1.875, 2.495, "border_ribs", S_METAL, Vector2(152.1, 206.8)],
	[2.735, 2.495, "border_ribs", S_METAL, Vector2(206.8, 210.4)], [2.753, 2.444, "border_ribs", S_METAL, Vector2(210.4, 214.0)],
	[2.770, 2.394, "curb_face", S_RUBBER, Vector2(216.1, 222.2)], [2.857, 2.358, "curb_face", S_RUBBER, Vector2(222.2, 228.4)],
	[2.943, 2.322, "curb_face", S_RUBBER, Vector2(228.4, 234.2)], [3.022, 2.269, "curb_face", S_RUBBER, Vector2(234.2, 240.1)],
	[3.101, 2.216, "curb_face", S_RUBBER, Vector2(240.1, 246.8)], [3.166, 2.143, "curb_face", S_RUBBER, Vector2(246.8, 253.4)],
	[3.231, 2.069, "curb_face", S_RUBBER, Vector2(253.4, 259.8)], [3.272, 1.968, "curb_face", S_RUBBER, Vector2(259.8, 266.2)],
	[3.312, 1.867, "curb_face", S_RUBBER, Vector2(266.2, 283.1)], [3.312, 1.606, "curb_face", S_RUBBER, Vector2(283.1, 291.6)],
	[3.280, 1.475, "curb_face", S_RUBBER, Vector2(291.6, 300.0)],
	[3.248, TOP, "shoulder", S_METAL], [5.177, TOP, "border_blue", S_RUBBER, Vector2(367.1, 371.7)],
	[5.232, 1.376, "border_blue", S_RUBBER, Vector2(371.7, 387.6)], [5.508, 1.361, "border_blue", S_RUBBER, Vector2(387.6, 390.1)],
	[5.540, TOP, "asphalt", S_ROAD],
]
const ROAD_EDGE := 5.540        ## where the asphalt starts (x)
const SHOULDER := 5.177         ## the grid shoulder's inner edge (x)
const KEEL_HALF := 1.661        ## half the keel's flat bottom plate (16 - 14.339)
## Stretch (Road/Main/Stretch): TMNF's sweep frames to the middle of the block (z, how far each
## curb has moved in, m), mirrored for the second half (measured: the section only translates;
## every shift is a multiple of 7.479 / 62).
const STRETCH := [[0.0, 0.0], [0.5, 0.0], [1.156, 0.121], [2.125, 0.483], [3.562, 1.207], [5.625, 2.413],
	[8.031, 3.86], [10.5, 5.308], [12.75, 6.514], [14.5, 7.238], [16.0, 7.479]]

const ARMS := {
	"Base": [], "Deadend": [0], "Corner": [0, 1], "Straight": [0, 2], "TShaped": [0, 2, 1], "Cross": [0, 1, 2, 3],
}
const SIDES := [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)]

## Turbo gate: the U-frame round the road (x, y), 14.4 -> 17.45 m along z.
const TURBO_FRAME := [
	[4.000, 4.854, "structure", 22], [3.879, 5.538, "structure", 22], [3.532, 6.140, "structure", 22],
	[3.000, 6.586, "structure", 22], [2.347, 6.824, "structure", 22], [1.653, 6.824, "structure", 22],
	[1.000, 6.586, "structure", 22], [0.468, 6.140, "structure", 22], [0.121, 5.538, "structure", 22],
	[0.000, 4.854, "structure", 22], [0.000, 1.976, "structure", 22], [0.121, 1.292, "structure", 22],
	[0.468, 0.690, "structure", 22], [1.000, 0.244, "structure", 22], [1.653, 0.000, "structure", 22],
	[30.347, 0.000, "structure", 22], [31.000, 0.244, "structure", 22], [31.532, 0.690, "structure", 22],
	[31.879, 1.292, "structure", 22], [32.000, 1.976, "structure", 22], [32.000, 4.854, "structure", 22],
	[31.879, 5.538, "structure", 22], [31.532, 6.140, "structure", 22], [31.000, 6.586, "structure", 22],
	[30.347, 6.824, "structure", 22], [29.653, 6.824, "structure", 22], [29.000, 6.586, "structure", 22],
	[28.468, 6.140, "structure", 22], [28.121, 5.538, "structure", 22], [28.000, 4.854, "structure", 22],
	[28.000, 3.810, "structure", 22], [28.688, 2.765, "structure", 4], [28.688, 1.000, "structure", 22],
	[3.312, 1.000, "structure", 4], [3.312, 2.765, "structure", 22], [4.000, 3.810, "structure", 22]
]
## Loops: frames per half loop, the road's own section at each end, the base circle's radius, and
## the underside between the curbs (x, y as in HALF_AIR, from the curb's foot to the centre).
const LOOP_FRAMES := 64
const LOOP_ROAD_FRAMES := 4
const LOOP_BASE_R := 44.0
const LOOP_UNDER := [[3.212, 1.243, "road_metal", S_METAL], [3.3, 1.243, "road_grid", S_METAL],
	[5.163, 1.243, "road_metal", S_METAL], [5.163, 0.84, "road_metal", S_METAL], [5.54, 0.84, "road_metal", S_METAL],
	[5.54, 1.219, "road_grid", S_METAL], [14.292, 0.656, "road_metal", S_METAL], [14.339, 0.0, "road_metal", S_METAL]]
## TMNF's clamps across the loop's back, every 22.5 degrees round it: a bar either side of the spine
## (LOOP_CLAMP: from d0 to d1 across, h up from the spine's foot, the tube's radius) with dark blocks
## at its ends and middle (LOOP_CLAMP_BLOCK: half sizes across, radially, along the loop).
const LOOP_CLAMP := [2.85, 13.18, 0.45, 0.28]
const LOOP_CLAMP_BLOCK := Vector3(0.3, 0.55, 0.4)
## Jump ramps (Ramp/, Ramp/Low): a thin plate over a dead-end road, rising from the road at z 24 to
## its lip at z 1.985 through TMNF's frames (z, top y; Low lifts half as much); its half-width grows
## linearly from RAMP_HALF[0] at the lip to RAMP_HALF[1] at the road, metal along the outer
## RAMP_EDGE m of each side, grid between; RAMP_T thick until it meets the road (z RAMP_THIN).
## Two struts (RAMP_STRUT_W x RAMP_STRUT_T) prop it from under the lip down to the ground.
const RAMP := [[1.985, 7.947], [2.612, 7.659], [3.24, 7.37], [3.872, 7.081], [4.51, 6.791], [5.154, 6.5],
	[5.807, 6.207], [6.471, 5.913], [7.147, 5.617], [7.838, 5.318], [8.541, 5.019], [9.255, 4.721],
	[9.979, 4.427], [10.711, 4.138], [11.45, 3.856], [12.194, 3.582], [12.942, 3.32], [13.693, 3.069],
	[14.443, 2.833], [15.191, 2.611], [15.934, 2.406], [16.671, 2.219], [17.397, 2.05], [18.112, 1.902],
	[18.813, 1.775], [19.498, 1.671], [20.168, 1.588], [20.825, 1.521], [21.473, 1.469], [22.112, 1.428],
	[22.744, 1.395], [23.373, 1.369], [24.0, 1.345]]
const RAMP_HALF := [8.0, 10.0]
const RAMP_EDGE := 2.0
const RAMP_T := 0.207
const RAMP_THIN := 20.5
## A strut's centre line (x, y) at z 3.87 and 16 (the left one; the other is mirrored).
const RAMP_STRUT := [Vector3(10.38, 6.77, 3.87), Vector3(15.52, -0.3, 16.0)]
const RAMP_STRUT_W := 1.1
const RAMP_STRUT_T := 0.205
## Turbo booster pods (measured): the outline (z, radius, key of the segment from it) about the axis
## at y TURBO_POD_Y (x 2 and 30), closed on the axis; as TMNF's jet turbines, a fan in the intake
## (grey disc, dark blades), the cowl light, the body dark; the fins over them (z, y),
## TURBO_FIN_HALF either side of the axis.
const TURBO_POD_Y := 4.854
const TURBO_POD := [[7.633, 0.0, "road_grid"], [7.633, 1.53, "road_under"], [7.723, 1.78, "road_under"],
	[8.569, 1.946, "road_under"], [10.152, 1.97, "platform_tray"], [10.666, 1.72, "platform_tray"],
	[14.21, 1.72, "platform_tray"], [14.299, 1.822, "platform_tray"], [14.403, 1.97, "road_metal"],
	[17.446, 1.97, "platform_tray"], [17.656, 1.70, "road_metal"], [17.656, 0.0, "road_metal"]]
## Its back cap: eight bolt rings (radii TURBO_BOLT) TURBO_BOLT_AT out round a boss (TURBO_BOSS;
## read off TMNF's look, as the platform turbines')
const TURBO_BOLT := [0.13, 0.29]
const TURBO_BOLT_AT := 1.12
const TURBO_BOSS := [0.32, 0.56]
## The tray over each pod: its line (z, y), TURBO_FIN_HALF either side of the pod's axis; the side
## panels reach this far below and above it.
const TURBO_FIN_HALF := 0.802
const TURBO_TRAY := [Vector2(8.441, 7.01), Vector2(17.446, 7.01), Vector2(23.611, 2.972), Vector2(25.898, 2.972)]
const TURBO_PANEL := [0.17, 0.916]
## The arch's feet (measured; _gate_feet; x, y the left foot's): the clamp's outline round the
## curb (x, y, half its thickness there), the strap over the curb's top (z from the foot, y; across
## GATE_STRAP_X), the strut's axis (from the clamp to the arch's end) and its section (across,
## along z), the lattice's lower and upper edge, the light rigs' centres, their z extents from the
## gate's centre.
const GATE_CLAMP := [Vector3(2.25, 0.59, 0.22), Vector3(3.34, 1.08, 0.185), Vector3(2.65, 2.89, 0.195),
	Vector3(1.53, 2.89, 0.53), Vector3(1.32, 2.24, 0.54)]
const GATE_STRAP := [Vector2(-0.89, 2.48), Vector2(-0.6, 2.79), Vector2(-0.19, 2.87), Vector2(0.19, 2.87),
	Vector2(0.6, 2.79), Vector2(0.89, 2.48)]
const GATE_STRAP_X := Vector2(2.13, 2.4)
const GATE_FOOT_Z := [-2.161, 2.131]
const GATE_STRUT := [Vector2(2.685, 2.59), Vector2(4.49, 4.30)]
const GATE_STRUT_HEX := [Vector2(0.21, 0.0), Vector2(0.14, 0.09), Vector2(0.0, 0.14), Vector2(-0.14, 0.09),
	Vector2(-0.21, 0.0), Vector2(-0.14, -0.09), Vector2(0.0, -0.14), Vector2(0.14, -0.09)]
const GATE_LATTICE := [Vector2(2.75, 2.66), Vector2(4.44, 4.25)]
const GATE_LATTICE_Z := Vector2(-2.13, 2.17)
const GATE_SPOTS := [Vector2(3.195, 3.16), Vector2(3.835, 3.755)]
const GATE_SPOT_SIDE := 0.6
const GATE_SPOT_Z := Vector2(-1.39, 1.45)
## The arch's faces carry the gate's word every GATE_WORD metres along the arch (TMNF's RaceSigns
## band, measured: 3.08 m a word; the gate block's curbs every 4 m); the arch's length is fitted to
## a whole number of words.
const GATE_WORD := 3.08
## A gate's line across the road (TMNF's: the border atlas' blue band, rows LINE_ROWS, LINE_HALF
## either side of the gate's centre) and the start / finish roads' texture tile along z (m).
const LINE_HALF := 0.181
const LINE_ROWS := Vector2(367.1, 390.4)
const RACE_TILE := 6.0
## The arch's top and underside (TMNF's, measured at the crown): strips across its depth [z from the
## gate's centre at the strip's start, at its end, the atlas rows there, key]: ribbed edges either
## side, between them the top dark and the underside the light panel.
const GATE_TOP := [[-2.1, -1.234, Vector2(207.0, 151.9), "border_ribs"], [-1.234, 1.234, Vector2(151.9, 151.9), "border_ribs"],
	[1.234, 2.1, Vector2(151.9, 207.0), "border_ribs"]]
const GATE_UNDER := [[-2.1, -1.234, Vector2(207.0, 150.7), "border_ribs"], [-1.234, 1.234, Vector2(150.7, 0.0), "border_panel"],
	[1.234, 2.1, Vector2(151.9, 207.0), "border_ribs"]]
const GATE_ARCH_ENDS := [8, 25]                 ## GATE_ARCH's segments at the feet (the arch's ends)
const GATE_ARCH_CENTRE := Vector2(16.0, -9.0)   ## about the centre of the arch's circle
## Checkpoint / finish / multilap gate: the arch band (x, y), 4.2 m along z.
const GATE_ARCH := [
	[16.000, 8.806, "structure", 22], [14.407, 8.743, "structure", 22], [12.824, 8.552, "structure", 22],
	[11.262, 8.236, "structure", 22], [9.729, 7.795, "structure", 22], [8.237, 7.234, "structure", 22],
	[6.794, 6.556, "structure", 22], [5.410, 5.764, "structure", 22], [4.094, 4.865, "structure", 4],
	[4.924, 3.748, "metal", 4], [6.149, 4.585, "metal", 4], [7.436, 5.321, "metal", 4],
	[8.778, 5.952, "metal", 4], [10.167, 6.474, "metal", 4], [11.592, 6.884, "metal", 4],
	[13.046, 7.178, "metal", 4], [14.518, 7.356, "metal", 4], [16.000, 7.415, "metal", 4],
	[17.482, 7.356, "metal", 4], [18.954, 7.178, "metal", 4], [20.408, 6.884, "metal", 4],
	[21.833, 6.474, "metal", 4], [23.222, 5.952, "metal", 4], [24.564, 5.321, "metal", 4],
	[25.851, 4.585, "metal", 4], [27.076, 3.748, "structure", 4], [27.906, 4.865, "structure", 22],
	[26.590, 5.764, "structure", 22], [25.206, 6.556, "structure", 22], [23.763, 7.234, "structure", 22],
	[22.271, 7.795, "structure", 22], [20.738, 8.236, "structure", 22], [19.176, 8.552, "structure", 22],
	[17.593, 8.743, "structure", 22]
]

## Road slope pieces: road-surface heights along z every 2 m at the centre line (measured).
const SLOPES := {
	"BiSlopeStart": [1.345, 1.376, 1.407, 1.438, 1.469, 1.556, 1.643, 1.730, 1.817, 1.964, 2.112, 2.260, 2.408, 2.623, 2.838, 3.053, 3.267, 3.549, 3.830, 4.112, 4.393, 4.743, 5.093, 5.443, 5.792, 6.208, 6.624, 7.041, 7.457, 7.929, 8.401, 8.873, 9.345],
	"BiSlopeEnd": [1.345, 1.826, 2.307, 2.770, 3.234, 3.666, 4.098, 4.499, 4.900, 5.265, 5.630, 5.962, 6.294, 6.592, 6.890, 7.155, 7.420, 7.652, 7.883, 8.083, 8.282, 8.446, 8.610, 8.742, 8.874, 8.975, 9.076, 9.148, 9.220, 9.264, 9.308, 9.327, 9.345],
	"Base": [1.345, 1.407, 1.631, 1.997, 2.490, 3.097, 3.793, 4.553, 5.345, 6.137, 6.897, 7.593, 8.199, 8.692, 9.058, 9.283, 9.345],
	"Base2": [1.345, 1.469, 1.918, 2.650, 3.636, 4.849, 6.241, 7.761, 9.345, 10.929, 12.449, 13.840, 15.054, 16.040, 16.771, 17.220, 17.345],
	"UBottom": [9.345, 8.873, 8.457, 8.107, 7.825, 7.611, 7.463, 7.376, 7.345, 7.376, 7.463, 7.611, 7.825, 8.107, 8.457, 8.873, 9.345],
	"UTop": [1.345, 1.817, 2.233, 2.583, 2.864, 3.079, 3.227, 3.314, 3.345, 3.314, 3.227, 3.079, 2.864, 2.583, 2.233, 1.817, 1.345],
}
## Ground slopes: where TMNF stands a pillar under the raised end (z along the piece, m; measured)
const SLOPE_PILLAR := {"Base": 26.0, "Base2": 26.0, "BiSlopeStart": 55.5, "UBottom": 16.0}
## Road/Main/Bump: the road dipping 1.86 m in the middle of a two-level block (heights every 2 m).
const BUMP := [9.345, 9.199, 8.885, 8.53, 8.199, 7.916, 7.692, 7.543, 7.483, 7.543, 7.692, 7.916, 8.199, 8.53, 8.885,
	9.199, 9.345]
const BUMP_T := 0.483

## Platform/ToRoad2: the running curb's edge line, an arc of this radius about (R, 0) from the
## road end (0, 0), and the angle where it stops short of the far corner.
const TO_PLATFORM_R := 83.13
const TO_PLATFORM_END := 48.0

## Tilted roads (Road/Tilt, and Road/Main pieces' tilted variants): the bank rises TILT per metre
## across, the centre line TILT_RISE above a flat road's (measured: every point of a tilted piece is
## the flat one sheared). Pieces lying in one tilted plane are their flat counterpart sheared by
## y += kx * x + kz * z + dy (TmGeo.shear_y), from the plane fitted to each measured piece:
## shape -> [build, kx, kz, dy], build = "straight", "checkpoint", or "curve:<radius>:<cx>:<cz>:<a0>".
const TILT := 0.2512
const TILT_RISE := 3.981
const TILT_PLANES := {
	"Road/Tilt/Straight": ["straight", 0.2512, 0.0, -0.038],
	"Road/Tilt/CornerDownLeft": ["curve:16:0:32:-90", 0.251, 0.0, 0.005],
	"Road/Tilt/CornerDownRight": ["curve:16:0:0:0", 0.251, 0.0, -0.002],
	"Road/Tilt/CornerUpLeft": ["curve:16:32:32:180", 0.2512, 0.0, -0.038],
	"Road/Tilt/CornerUpRight": ["curve:16:32:0:90", 0.2512, 0.0, -0.038],
	"Road/Tilt/GTCurve/2DownLeft": ["curve:48:0:64:-90", 0.25, 0.0, 0.001],
	"Road/Tilt/GTCurve/2DownRight": ["curve:48:0:0:0", 0.25, 0.0, -0.003],
	"Road/Tilt/GTCurve/2UpLeft": ["curve:48:64:64:180", 0.2506, 0.0, -0.042],
	"Road/Tilt/GTCurve/2UpRight": ["curve:48:64:0:90", 0.2506, 0.0, -0.04],
	"Road/Main/CheckpointLeft": ["checkpoint", -0.2512, 0.0, 8.0],
	"Road/Main/CheckpointRight": ["checkpoint", 0.2512, 0.0, -0.038],
	"Road/Main/CheckpointUp": ["checkpoint", 0.0, 0.25, 0.0],
	"Road/Main/CheckpointDown": ["checkpoint", 0.0, -0.25, 8.0],
}
## Banked curves (Road/Tilt/Corner, GTCurve/2-4): the bank rises toward the outside.
const TILT_BANKED := {"Road/Tilt/Corner": 1, "Road/Tilt/GTCurve/2": 2, "Road/Tilt/GTCurve/3": 3, "Road/Tilt/GTCurve/4": 4}
## Transitions from a flat road one level up to the tilted road: the road turns down about its high
## edge; every 1/8 of the length (measured), the share of the full bank, and of the centre line's
## full drop (8 - TILT_RISE).
const TILT_EASE := [0.0, 0.0179, 0.0908, 0.26, 0.5, 0.74, 0.9092, 0.9821, 1.0]
const TILT_DROP := [0.0, 0.0373, 0.1309, 0.2914, 0.4996, 0.7069, 0.8671, 0.9619, 1.0]
const TILT_TRANSITIONS := {
	"Road/Tilt/Transition/1Left": [1, 1.0], "Road/Tilt/Transition/1Right": [1, -1.0],
	"Road/Tilt/Transition/2Left": [2, 1.0], "Road/Tilt/Transition/2Right": [2, -1.0],
}

## Diagonal transitions (Road/Tilt/Transition/2DiagLeft, mirrored for Right): the flat road turning
## into the tilted road one level up along the 2x2 GT diagonal's S-curve, the bank and the climb
## easing in; TMNF's frames (measured): road centre x, y (surface), z, the lateral's horizontal
## angle (degrees from +x toward +z) and the bank (rise per metre across).
const TILT_DIAG := [[16.0, 1.345, 0.0, 0.0, 0.0], [16.023, 1.368, 1.475, -1.821, 0.0], [16.107, 1.397, 3.123, -3.989, 0.0002],
	[16.296, 1.453, 5.134, -6.83, 0.0009], [16.683, 1.574, 7.652, -10.692, 0.0023], [17.416, 1.812, 10.761, -15.902, 0.0047],
	[18.578, 2.214, 14.146, -22.005, 0.0092], [20.183, 2.782, 17.558, -28.33, 0.0172], [22.17, 3.508, 20.825, -34.127, 0.0299],
	[24.408, 4.36, 23.843, -38.802, 0.0486], [26.834, 5.301, 26.672, -42.196, 0.0718], [29.386, 6.305, 29.377, -44.246, 0.0979],
	[32.0, 7.343, 32.019, -44.933, 0.1256], [34.615, 8.38, 34.66, -44.255, 0.1532], [37.166, 9.382, 37.363, -42.215, 0.1794],
	[39.593, 10.322, 40.191, -38.827, 0.2026], [41.83, 11.173, 43.205, -34.157, 0.2213], [43.817, 11.9, 46.468, -28.36, 0.234],
	[45.422, 12.469, 49.876, -22.032, 0.242], [46.584, 12.873, 53.256, -15.923, 0.2465], [47.317, 13.114, 56.361, -10.707, 0.2489],
	[47.704, 13.236, 58.874, -6.84, 0.2503], [47.894, 13.292, 60.882, -3.994, 0.251], [47.977, 13.321, 62.528, -1.823, 0.2512],
	[48.0, 13.326, 64.0, 0.0, 0.2512]]
## Curved transitions (2CurveLeft, mirrored for Right): the flat road one level up turning down into
## the tilted road round the 2-block GT curve (radius 48 about (0, 0)); same columns and the same
## bank per frame as TILT_DIAG.
const TILT_CURVE := [[48.0, 9.345, 0.0, 0.0, 0.0], [47.986, 9.345, 1.178, 1.406, 0.0], [47.933, 9.337, 2.539, 3.032, 0.0002],
	[47.81, 9.313, 4.265, 5.098, 0.0009], [47.553, 9.266, 6.533, 7.822, 0.0023], [47.049, 9.187, 9.509, 11.426, 0.0047],
	[46.212, 9.069, 12.979, 15.689, 0.0092], [44.992, 8.904, 16.724, 20.391, 0.0172], [43.391, 8.684, 20.523, 25.312, 0.0299],
	[41.471, 8.401, 24.17, 30.234, 0.0486], [39.244, 8.072, 27.639, 35.156, 0.0718], [36.728, 7.711, 30.904, 40.078, 0.0979],
	[33.941, 7.335, 33.941, 45.0, 0.1256], [30.904, 6.959, 36.728, 49.922, 0.1532], [27.639, 6.598, 39.244, 54.844, 0.1794],
	[24.17, 6.269, 41.471, 59.766, 0.2026], [20.523, 5.987, 43.391, 64.688, 0.2213], [16.724, 5.767, 44.992, 69.609, 0.234],
	[12.98, 5.602, 46.212, 74.312, 0.242], [9.509, 5.483, 47.049, 78.574, 0.2465], [6.533, 5.405, 47.553, 82.178, 0.2489],
	[4.265, 5.357, 47.81, 84.902, 0.2503], [2.539, 5.334, 47.933, 86.968, 0.251], [1.178, 5.326, 47.986, 88.594, 0.2512],
	[0.0, 5.326, 48.0, 90.0, 0.2512]]
const TILT_FRAMED := {"Road/Tilt/Transition/2DiagLeft": TILT_DIAG, "Road/Tilt/Transition/2DiagRight": TILT_DIAG,
	"Road/Tilt/Transition/2CurveLeft": TILT_CURVE, "Road/Tilt/Transition/2CurveRight": TILT_CURVE}
## GT diagonals: S-curves moving the road sideways, swept through TMNF's own frames (measured:
## blocks/data/gt_diag_frames.json from tools/research/tmnf/sweep_frames.py; per frame the centre
## x, z, the lateral's angle from +x toward +z in degrees, and the section's width scale); size ->
## the footprint's width along x. Mirror flips x; Slope rises 0.25 per metre along z; Tilt lies in a
## tilted plane (shear, fitted per piece).
const GT_DIAG := {"2x2": 64.0, "3x2": 64.0, "4x3": 96.0}
const GT_DIAG_FRAMES := "res://blocks/data/gt_diag_frames.json"
const GT_DIAG_TILT := {"2x2Tilt": [0.251, -0.03], "2x2TiltMirror": [-0.251, 16.032], "3x2Tilt": [0.251, -0.032],
	"3x2TiltMirror": [-0.251, 16.03]}

## Holes: the opening through the road (x0, x1, z0, z1); HolePillar covers it with a grate and runs
## pillars (radius PILLAR_R) through it: form -> pillar positions (x, z).
## Segments of the corner (k = 1) and the GT curves' quarter circles (measured: TMNF's polygons).
const CURVE_STEPS := {1: 16, 2: 32, 3: 48, 4: 32, 5: 96}
## Y junctions: form -> [branch, slope (rise per metre along z), lift].
const Y_SHAPED := {
	"Curve2": ["curve", 0.0, 0.0], "Diag2": ["diag", 0.0, 0.0],
	"Diag2SlopeUp": ["diag", -0.25, 16.0], "Diag2SlopeDown": ["diag", 0.25, 0.0],
}
const HOLE := [11.25, 20.75, 6.25, 25.75]
const PILLAR_R := 1.375
const HOLE_PILLARS := {
	"": [Vector2(16, 16)], "2Front": [Vector2(12, 16), Vector2(20, 16)], "2Line": [Vector2(16, 8), Vector2(16, 24)],
	"3": [Vector2(16, 4), Vector2(10, 28), Vector2(22, 28)],
}


static var _diag_cache := {}

var _road_mat := "asphalt"
var _green_shoulders := false      ## the shoulders the border's green band in the air too (ramp)
var _road_surf := S_ROAD
var _gate_kind := "cp"            ## the gate's kind for this shape (TmGateDress.kind_of)
var _curb_mat := "curb_face"      ## the curbs' face towards the road (a gate block's: its sign)
## The curb face's atlas rows, top to bottom (HALF_TOP; the outer face's in the air the same), where
## a gate block's sign is spread.
const CURB_ROWS := Vector2(216.1, 300.0)
var _gates: Array[float] = []     ## where this shape's gates stand (z), dressed after building


func handles(shape: String) -> bool:
	if shape == "Grass/Checkpoint/Ground" or shape in ["Ramp/Air", "Ramp/Ground", "Ramp/LowAir", "Ramp/LowGround"] \
			or shape in ["Loop/LeftAir", "Loop/LeftGround", "Loop/RightAir", "Loop/RightGround"]:
		return true
	var base := _form(shape).trim_suffix("/")
	if TILT_PLANES.has(base) or TILT_BANKED.has(base) or TILT_TRANSITIONS.has(base) or TILT_FRAMED.has(base):
		return true
	if not shape.begins_with("Road/Main/"):
		return false
	var rest := shape.trim_prefix("Road/Main/")
	if rest.begins_with("Slope/") and SLOPES.has(_form(rest.trim_prefix("Slope/"))):
		return true
	if rest.begins_with("GTDiag/") and GT_DIAG.has(rest.trim_prefix("GTDiag/").substr(0, 3)):
		return true
	if rest.begins_with("Hole/") or (rest.begins_with("HolePillar/") and HOLE_PILLARS.has(_hole_form(rest))):
		return true
	if rest.begins_with("YShaped/") and Y_SHAPED.has(_form(rest.trim_prefix("YShaped/"))):
		return true
	if rest.begins_with("Stretch/") and _form(rest.trim_prefix("Stretch/")) in ["", "Slope", "Tilt"]:
		return true
	if rest in ["Bump/Air", "Bump/Ground"]:
		return true
	return ARMS.has(_form(rest)) or rest.begins_with("Slope/StraightAir") or rest.begins_with("Slope/StraightGround") \
		or rest.begins_with("GTCurve/") \
		or (rest.begins_with("Turbo/") and _form(rest.get_slice("/", 1)) in ["", "Up", "Down", "Left", "Right"]) \
		or rest.begins_with("FreeWheeling/") or rest.begins_with("Checkpoint/") or rest.begins_with("MultiLap/") \
		or rest.begins_with("Finish/") or rest.begins_with("Start/")


## The shape's form, without its variant suffix (Air, Ground, or an alternative GroundA/B/C).
static func _form(rest: String) -> String:
	for suffix in ["GroundA", "GroundB", "GroundC", "Ground", "Air"]:
		if rest.ends_with(suffix):
			return rest.trim_suffix(suffix)
	return rest


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var rest := shape.trim_prefix("Road/Main/")
	var ground := rest.contains("Ground")
	var geo := TmGeo.new()
	_road_mat = "asphalt"
	_road_surf = S_ROAD
	_gate_kind = TmGateDress.kind_of(rest)
	_curb_mat = "curb_face"
	for g in ["Checkpoint", "MultiLap/", "Finish/", "Start/"]:
		if rest.begins_with(g):
			_curb_mat = "curb_" + _gate_kind
	_gates.clear()
	var form := _form(rest)
	var base := _form(shape).trim_suffix("/")
	if shape == "Grass/Checkpoint/Ground":
		# the road's gate over the grass (the map lays the grass), 0.19 m lower (measured)
		_gate(geo, 16.0)
		geo.shear_y(0.0, 0.0, -0.19)
	elif TILT_PLANES.has(base) or TILT_BANKED.has(base) or TILT_TRANSITIONS.has(base):
		# tilted pieces: the air section also on the ground (the raised side stands on pillars)
		_tilt(geo, base)
	elif TILT_FRAMED.has(base):
		_tilt_framed(geo, TILT_FRAMED[base], base.ends_with("Right"))
	elif rest.begins_with("GTDiag/"):
		_gt_diag(geo, _form(rest.trim_prefix("GTDiag/")), ground)
	elif rest.begins_with("Hole/") or rest.begins_with("HolePillar/"):
		_hole(geo, rest, ground)
	elif rest.begins_with("YShaped/"):
		_y_shaped(geo, _form(rest.trim_prefix("YShaped/")), ground)
	elif shape.begins_with("Ramp/"):
		_jump_ramp(geo, rest.contains("Low"), ground)
	elif shape.begins_with("Loop/"):
		_loop(geo, shape.begins_with("Loop/Left"))
	elif rest.begins_with("Stretch/"):
		_stretch(geo, _form(rest.trim_prefix("Stretch/")), ground)
	elif rest.begins_with("Bump/"):
		_bump(geo, ground)
	elif ARMS.has(form):
		_junction(geo, form, ground)
	elif rest.begins_with("Slope/") and SLOPES.has(_form(rest.trim_prefix("Slope/"))):
		var kind := _form(rest.trim_prefix("Slope/"))
		_profile_slope(geo, SLOPES[kind], ground)
		if ground and SLOPE_PILLAR.has(kind):
			var heights: Array = SLOPES[kind]
			_ground_pillar(geo, float(SLOPE_PILLAR[kind]), func(z: float) -> float:
				var f := clampf(z / 2.0, 0.0, heights.size() - 1.001)
				return lerpf(float(heights[floori(f)]), float(heights[floori(f) + 1]), f - floorf(f)) - TOP)
	elif rest.begins_with("Slope/Straight"):
		_sweep(geo, [Vector3(16, 0, 0), Vector3(16, 8, 32)], [Vector3(1, 0, 0), Vector3(1, 0, 0)], false)
		if ground:
			_ground_pillar(geo, 26.0, func(z: float) -> float: return z * 0.25)
	elif rest.begins_with("GTCurve/"):
		var k := int(rest.trim_prefix("GTCurve/").substr(0, 1))
		if k < 2 or k > 5:
			return null
		_curve(geo, k, ground)
	elif rest.begins_with("Turbo/") or rest.begins_with("FreeWheeling/"):
		_road_mat = "turbo" if rest.begins_with("Turbo/") else "freewheel"
		if rest.begins_with("Turbo/"):
			_curb_mat = "turbo_rim"
		_road_surf = S_TURBO if rest.begins_with("Turbo/") else S_FREEWHEEL
		# Up/Down/Left/Right: the flat pad sheared like the checkpoint of that slope or tilt
		# (measured: the pad's plane), the air section on the ground too
		var dir := _form(rest.get_slice("/", 1))
		_straight(geo, 0.0, 32.0, ground and dir.is_empty())
		# the pad's texture as TMNF lays it: 16 m a tile along z, mirrored about the centre line
		geo.remap_uv(_road_mat, func(p: Vector3) -> Vector2: return Vector2(p.z / 16.0, absf(p.x - 16.0) / 10.46))
		_turbo_gate(geo)
		var t: Array = TILT_PLANES.get("Road/Main/Checkpoint" + dir, ["", 0.0, 0.0, 0.0])
		geo.shear_y(float(t[1]), float(t[2]), float(t[3]))
		_turbo_sides(geo, float(t[1]), float(t[2]), float(t[3]))
	elif rest.begins_with("Checkpoint/") or rest.begins_with("MultiLap/"):
		_straight(geo, 0.0, 32.0, ground)
		_gate(geo, 16.0)
		if rest.begins_with("MultiLap/"):
			_race_road(geo, "race_start", 8.0, 24.0)
	elif rest.begins_with("Finish/"):
		# the road comes in from -z and ends past the line in a nose; all of it the finish road
		_straight(geo, 0.0, 17.0, ground)
		_nose(geo, 17.0, 1.0, ground, TOP - 0.04)
		_gate(geo, 12.0)
		_race_road(geo, "race_finish", -1.0, 18.0)
	elif rest.begins_with("Start/"):
		# the road leaves to +z from a nose behind the spawn (z 11.2); the line near the far end,
		# the start road up to it
		_straight(geo, 8.0, 32.0, ground)
		_nose(geo, 8.0, -1.0, ground, TOP - 0.04)
		_gate(geo, 28.0)
		_race_road(geo, "race_start", 7.0, 28.0 - LINE_HALF)
	else:
		return null
	var node := geo.build()
	for zc: float in _gates:
		TmGateDress.dress(node, _gate_kind, zc, geo.sheared)
	return node


## The closed cross-section as wall_sweep points: (d = x - 16, y).
func _section(ground: bool) -> Array:
	var left := _outer_half(ground) + HALF_TOP
	var out := []
	for q in left:
		out.append(_entry(q, Vector2(float(q[0]) - 16.0, float(q[1])), ground))
	# the right half mirrored, walked back from the top centre to the bottom; a segment keeps the
	# material of its mirrored twin (which starts at the next point of the left half)
	out.append([Vector2(0.0, TOP), _road_mat, _road_surf])
	for i in range(left.size() - 1, 0, -1):
		var q: Array = left[i]
		var prev: Array = left[i - 1]
		out.append(_entry(prev, Vector2(16.0 - float(q[0]), float(q[1])), ground, true))
	for p in out:
		if p[1] == "asphalt":
			p[1] = _road_mat
			p[2] = _road_surf
	return out


## A table point (HALF_*) as a section entry at p ([p, key, surface] and its atlas rows, reversed
## for the mirrored half's twin): the curb's face is the border's black band, the shoulder the grid
## (on the ground the border's green band; on a ramp off a platform both, and the curb's outer
## underside the orange band). A gate block's curbs carry its sign on both faces, as
## TMNF's (its word every 4 m, the face's rows spread over the sign: texgen/gates.py, turbo.py; on
## the outer face mirrored, as TMNF's read from outside: the "_out" materials).
func _entry(q: Array, p: Vector2, ground: bool, mirror := false) -> Array:
	var key := String(q[2])
	var rows := q[4] as Vector2 if q.size() > 4 else Vector2(-1, -1)
	if key == "curb_face" and _curb_mat == "curb_face":
		key = "border_black"
	elif key == "curb_face" or (key == "border_black" and _curb_mat != "curb_face"):
		key = _curb_mat if key == "curb_face" else _curb_mat + "_out"
		rows = (rows - Vector2(CURB_ROWS.x, CURB_ROWS.x)) * (512.0 / (CURB_ROWS.y - CURB_ROWS.x))
	elif key == "shoulder" and (ground or _green_shoulders):
		key = "border_green"
		rows = Vector2(392.7, 511.0)
	elif key == "border_black" and _green_shoulders and not ground:
		# the ramp off a platform: the curb's outer underside the orange band, its blue line at the
		# bottom (TMNF's rows run 300 at the top to 367 at the bottom)
		key = "border_orange"
		rows = Vector2(300.0, 300.0) + (rows - Vector2(216.1, 216.1)) * (67.0 / (299.8 - 216.1))
	elif key == "shoulder":
		key = "road_grid"
	if rows.x < 0.0:
		return [p, key, int(q[3])]
	return [p, key, int(q[3]), Vector2(rows.y, rows.x) if mirror else rows]


## The left half's points up to the curb's top (HALF_TOP's start): air, ground, a gate block's ground.
func _outer_half(ground: bool) -> Array:
	if not ground:
		return HALF_AIR + HALF_TOP_AIR
	return HALF_GROUND if _curb_mat == "curb_face" else HALF_GROUND_GATE + HALF_TOP_AIR


## The left curb alone (the section up to the asphalt's edge), closed underneath; d = x.
func _curb_section(ground: bool) -> Array:
	var left: Array = (_outer_half(ground).slice(1) if ground else HALF_AIR.slice(5) + HALF_TOP_AIR) + HALF_TOP
	var out := []
	for q in left:
		out.append(_entry(q, Vector2(float(q[0]), float(q[1])), ground))
	var bottom := 1.0 if ground else 1.243
	out[out.size() - 1][1] = ""                      # the curb's inner end is internal
	out[out.size() - 1][2] = TmGeo.NO_COLLISION
	out.append([Vector2(ROAD_EDGE, bottom), "" if ground else "road_grid", TmGeo.NO_COLLISION if ground else S_METAL])
	return out


func _sweep(geo: TmGeo, path: Array, lateral: Array, ground: bool, y_at := Callable(), p_at := Callable()) -> void:
	geo.wall_sweep(_section(ground), path, lateral, true, "road_metal", S_METAL, y_at, p_at)


## Loop (Loop/RightAir, LeftAir, and their ground variants): half a vertical loop (the block placed
## the other way round is the other half). The road rises from the bottom round a circle about
## (y 44, z 0), its base on radius 44, to the top, upside down at z 0; meanwhile it moves 64 m
## sideways, 1 m per frame of 180/64 deg, so the loop clears itself; the lateral stays along x
## (measured frames). The first and last LOOP_ROAD_FRAMES frames carry the road's own section,
## the rest the loop's: the road's curbs with grid between them and a shallow keel (LOOP_UNDER).
func _loop(geo: TmGeo, left: bool) -> void:
	var road := _section(false)
	var sec := _loop_section()
	var frames := []
	for i in LOOP_FRAMES + 1:
		var th := PI * float(i) / LOOP_FRAMES
		var up := Vector3(0, cos(th), -sin(th))
		var x := 16.0 + i if left else 80.0 - i
		var o := Vector3(x, LOOP_BASE_R - LOOP_BASE_R * cos(th), LOOP_BASE_R * sin(th))
		frames.append(Transform3D(Basis(Vector3(1, 0, 0), up, Vector3(1, 0, 0).cross(up)), o))
	var n := LOOP_ROAD_FRAMES
	_sweep_frames(geo, road, frames.slice(0, n + 1))
	_sweep_frames(geo, sec, frames.slice(n, LOOP_FRAMES - n + 1))
	_sweep_frames(geo, road, frames.slice(LOOP_FRAMES - n))
	var cl: Array = LOOP_CLAMP
	var bk: Vector3 = LOOP_CLAMP_BLOCK
	for k in range(1, 8):
		var f: Transform3D = frames[k * LOOP_FRAMES / 8]
		var lat := f.basis.x
		var up := f.basis.y
		var along := lat.cross(up)
		for s: float in [-1.0, 1.0]:
			var a := f.origin + lat * s * float(cl[0]) + up * float(cl[2])
			var b := f.origin + lat * s * float(cl[1]) + up * float(cl[2])
			geo.pipe(a, b, cl[3], 8, "mast", S_METAL)
			for t: float in [0.0, 0.5, 1.0]:
				_obox(geo, a.lerp(b, t), lat * bk.x, up * bk.y, along * bk.z, "stands_dark", S_METAL)


## A box centred at c with half axes u, v, w (any orientation), faces outward.
static func _obox(geo: TmGeo, c: Vector3, u: Vector3, v: Vector3, w: Vector3, key: String, surface: int) -> void:
	for axes: Array in [[u, v, w], [v, w, u], [w, u, v]]:
		for s: float in [-1.0, 1.0]:
			var n: Vector3 = axes[0] * s
			var a: Vector3 = axes[1]
			var b: Vector3 = axes[2]
			var q := [c + n - a - b, c + n + a - b, c + n + a + b, c + n - a + b]
			if ((q[1] - q[0]) as Vector3).cross(q[2] - q[0]).dot(n) > 0.0:
				geo.quad(q[0], q[1], q[2], q[3], key, surface)
			else:
				geo.quad(q[0], q[3], q[2], q[1], key, surface)


## The loop's section (d, y) like _section(): the road's curbs, the grid between them, LOOP_UNDER
## (TMNF's back: grates, the dark spine down its middle and a rail under each edge).
func _loop_section() -> Array:
	var half := []
	for q in HALF_AIR.slice(6) + HALF_TOP_AIR + HALF_TOP:
		half.append(q)
		if float(q[0]) >= 3.248 - 0.001 and float(q[1]) <= TOP + 0.001:
			break         # the curb's inner foot: the grid starts here
	var out := []
	for q in half:
		out.append(_entry(q, Vector2(float(q[0]) - 16.0, float(q[1])), false))
	for i in range(half.size() - 1, -1, -1):
		var q: Array = half[i]
		var prev: Array = half[i - 1] if i > 0 else LOOP_UNDER[0]
		out.append(_entry(prev, Vector2(16.0 - float(q[0]), float(q[1])), false, true))
	# the underside: from the right curb's foot in to the centre, then out to the left curb's
	for q in LOOP_UNDER:
		out.append([Vector2(16.0 - float(q[0]), float(q[1])), String(q[2]), int(q[3])])
	for i in range(LOOP_UNDER.size() - 1, -1, -1):
		var q: Array = LOOP_UNDER[i]
		var m: Array = LOOP_UNDER[maxi(i - 1, 0)]       # mirrored: the segment back to point i - 1
		out.append([Vector2(float(q[0]) - 16.0, float(q[1])), String(m[2]), int(m[3])])
	return out


## Sweeps a closed (d, y) section through frames (basis x = lateral, y = up; travel = x cross y),
## faces outward; the ends stay open (the road carries on into the next block).
func _sweep_frames(geo: TmGeo, section: Array, frames: Array) -> void:
	var loop := section
	if TmGeo.loop_area(loop) < 0.0:
		loop = TmGeo.reversed_loop(loop)
	geo.sweep(loop + [loop[0]], frames)


## Jump ramp (Ramp/Air, Ground, LowAir, LowGround): the dead-end road (opening to +z) and the
## ramp plate over it, with its struts; low: the plate lifts half as much.
func _jump_ramp(geo: TmGeo, low: bool, ground: bool) -> void:
	_junction(geo, "Deadend", ground)
	var lift := 0.5 if low else 1.0
	var z0 := float(RAMP[0][0])
	var z1 := float(RAMP[RAMP.size() - 1][0])
	var path := []
	var lat := []
	for f in RAMP:
		path.append(Vector3(16, TOP + (float(f[1]) - TOP) * lift, float(f[0])))
		lat.append(Vector3(1, 0, 0))
	# the section's points are placeholders, moved per frame: |d| 10 = the edge, 8 = the edge strip's
	# inner side; y -1 = the underside
	var sec := [[Vector2(-10, 0), "metal", S_METAL], [Vector2(-8, 0), "grid", S_METAL], [Vector2(8, 0), "metal", S_METAL],
		[Vector2(10, 0), "metal", S_METAL], [Vector2(10, -1), "structure", S_METAL], [Vector2(8, -1), "structure", S_METAL],
		[Vector2(-8, -1), "structure", S_METAL], [Vector2(-10, -1), "metal", S_METAL]]
	var p_at := func(p: Vector2, i: int) -> Vector2:
		var z := float(RAMP[i][0])
		var half := lerpf(RAMP_HALF[0], RAMP_HALF[1], (z - z0) / (z1 - z0))
		var d := half if absf(p.x) > 9.0 else half - RAMP_EDGE
		return Vector2(signf(p.x) * d, 0.0 if p.y == 0.0 else (-RAMP_T if z < RAMP_THIN else 0.0))
	geo.wall_sweep(sec, path, lat, true, "road_metal", S_METAL, Callable(), p_at)
	# the struts, cut where they meet the ground (ground pieces) or at their foot
	for mirror in [false, true]:
		var a: Vector3 = RAMP_STRUT[0]
		var b: Vector3 = RAMP_STRUT[1]
		if low:
			a.y = TOP + (a.y - TOP) * lift
		if mirror:
			a.x = 32.0 - a.x
			b.x = 32.0 - b.x
		var strut := [[Vector2(-RAMP_STRUT_W * 0.5, -RAMP_STRUT_T * 0.5), "structure", S_METAL],
			[Vector2(RAMP_STRUT_W * 0.5, -RAMP_STRUT_T * 0.5), "structure", S_METAL],
			[Vector2(RAMP_STRUT_W * 0.5, RAMP_STRUT_T * 0.5), "structure", S_METAL],
			[Vector2(-RAMP_STRUT_W * 0.5, RAMP_STRUT_T * 0.5), "structure", S_METAL]]
		geo.wall_sweep(strut, [a, b], [Vector3(1, 0, 0), Vector3(1, 0, 0)], true, "structure", S_METAL)


## Stretch: a straight whose curbs close in toward the middle and open out again, swept through
## TMNF's frames (STRETCH: z, how far each curb has moved in); both halves of the section move
## (the keel's bottom plate stays), slope and tilt variants sheared like the straight.
func _stretch(geo: TmGeo, variant: String, ground: bool) -> void:
	# the frames over the whole block: the table to the middle, then mirrored back out
	var frames: Array = STRETCH.duplicate()
	for i in range(STRETCH.size() - 2, -1, -1):
		frames.append([32.0 - float(STRETCH[i][0]), STRETCH[i][1]])
	var path := []
	var lat := []
	for f in frames:
		path.append(Vector3(16, 0, float(f[0])))
		lat.append(Vector3(1, 0, 0))
	var p_at := func(p: Vector2, i: int) -> Vector2:
		if p.y < 0.01 or absf(p.x) < 0.001:
			return p       # the keel's bottom plate and the centre stay
		var d := absf(p.x) - float(frames[i][1])
		if p.y < 0.5:
			d = maxf(d, KEEL_HALF)
		return Vector2(signf(p.x) * d, p.y)
	_sweep(geo, path, lat, ground and variant == "", Callable(), p_at)
	if variant == "Slope":
		geo.shear_y(0.0, 0.25, 0.0)
	elif variant == "Tilt":
		var t: Array = TILT_PLANES["Road/Tilt/Straight"]
		geo.shear_y(float(t[1]), float(t[2]), float(t[3]))


## GT curves (and the 1x1 corner, k = 1): the section around the footprint's corner (0, 32k).
func _curve(geo: TmGeo, k: int, ground: bool) -> void:
	_arc_road(geo, Vector2(0, 32.0 * k), 32.0 * k - 16.0, -90.0, ground, 0.0, 0.0, CURVE_STEPS.get(k, 0))


## A quarter-circle road of centre-line radius r about c (x, z), from angle a0 to a0 + 90 (degrees,
## from +x toward +z); bank: rise per metre toward the outside, rise: the centre line's lift.
func _arc_road(geo: TmGeo, c: Vector2, r: float, a0: float, ground: bool, bank := 0.0, rise := 0.0,
		steps := 0) -> void:
	if steps <= 0:
		steps = maxi(8, int(r / 6.0))
	var path := []
	var lat := []
	for i in steps + 1:
		var a := deg_to_rad(a0 + 90.0 * float(i) / steps)
		var d := Vector3(cos(a), 0.0, sin(a))
		path.append(Vector3(c.x, rise, c.y) + d * r)
		lat.append(d + Vector3.UP * bank)
	_sweep(geo, path, lat, ground)


## "HolePillar/2FrontAir" -> "2Front"; slope and tilt variants have one pillar ("").
static func _hole_form(rest: String) -> String:
	var f := _form(rest.get_slice("/", 1))
	return "" if f in ["Slope", "Tilt"] else f


## A straight with an opening through it (Hole), or the opening grated over with pillars through it
## (HolePillar); slope and tilt variants sheared like their plain counterparts.
func _hole(geo: TmGeo, rest: String, ground: bool) -> void:
	var variant := _form(rest.get_slice("/", 1))
	var pillars := rest.begins_with("HolePillar/")
	var flat := ground and variant not in ["Slope", "Tilt"]
	if pillars:
		_straight(geo, 0.0, 32.0, flat)
		var g := Vector3(HOLE[0], TOP + 0.01, HOLE[2])
		var h := Vector3(HOLE[1], TOP + 0.01, HOLE[3])
		geo.quad(g, Vector3(g.x, g.y, h.z), h, Vector3(h.x, g.y, g.z), "grid", TmGeo.NO_COLLISION)
	else:
		_straight(geo, 0.0, HOLE[2], flat)
		_straight(geo, HOLE[3], 32.0, flat)
		var sec := _section(flat)
		for part in [_clip_x(sec, -100.0, HOLE[0] - 16.0), _clip_x(sec, HOLE[1] - 16.0, 100.0)]:
			geo.wall_sweep(part, [Vector3(16, 0, HOLE[2]), Vector3(16, 0, HOLE[3])], [Vector3(1, 0, 0), Vector3(1, 0, 0)],
				true, "road_metal", S_METAL)
	var top := 8.0
	if variant == "Slope":
		geo.shear_y(0.0, 0.25, 0.0)
		top = 16.0
	elif variant == "Tilt":
		geo.shear_y(TILT, 0.0, -0.038)
		top = 16.0
	if pillars:
		for c: Vector2 in HOLE_PILLARS[_hole_form(rest)]:
			geo.pipe(Vector3(c.x, 0, c.y), Vector3(c.x, top, c.y), PILLAR_R, 24, "pillar", S_ROAD)


## A closed section [[Vector2(d, y), mat, surface], ...] cut to lo <= d <= hi; the new edges along
## the cut are metal.
static func _clip_x(sec: Array, lo: float, hi: float) -> Array:
	var poly := PackedVector2Array()
	for q in sec:
		poly.append(q[0])
	var box := PackedVector2Array([Vector2(lo, -100), Vector2(hi, -100), Vector2(hi, 100), Vector2(lo, 100)])
	var parts := Geometry2D.intersect_polygons(poly, box)
	if parts.is_empty():
		return []
	var cut: PackedVector2Array = parts[0]
	var out := []
	for i in cut.size():
		var a := cut[i]
		var b := cut[(i + 1) % cut.size()]
		var entry := [a, "road_metal", S_METAL]
		for k in sec.size():
			var p: Vector2 = sec[k][0]
			var q: Vector2 = sec[(k + 1) % sec.size()][0]
			if Geometry2D.get_closest_point_to_segment(a, p, q).distance_to(a) < 0.002 \
					and Geometry2D.get_closest_point_to_segment(b, p, q).distance_to(b) < 0.002:
				entry = [a, sec[k][1], sec[k][2]]
				if (sec[k] as Array).size() > 3:
					# atlas rows at the cut's ends, along the segment
					var rows: Vector2 = sec[k][3]
					var l := maxf(p.distance_to(q), 1e-6)
					entry.append(Vector2(lerpf(rows.x, rows.y, p.distance_to(a) / l), lerpf(rows.x, rows.y, p.distance_to(b) / l)))
				break
		out.append(entry)
	return out


## A GT diagonal, e.g. "2x2", "2x2Mirror", "3x2Slope", "2x2TiltMirror": the road swept along the
## measured centre line (read smoothly), then mirrored, sloped or tilted.
func _gt_diag(geo: TmGeo, form: String, ground: bool) -> void:
	var width: float = GT_DIAG[form.substr(0, 3)]
	var mirror := form.contains("Mirror")
	var path := []
	var lat := []
	for f: Array in _diag_frames().get(form.substr(0, 3), []):
		var a := deg_to_rad(float(f[2]))
		var l := Vector3(cos(a), 0, sin(a)) * float(f[3])
		if mirror:
			l.z = -l.z
		path.append(Vector3(width - float(f[0]) if mirror else float(f[0]), 0, float(f[1])))
		lat.append(l)
	_sweep(geo, path, lat, ground and not form.contains("Tilt"))
	if form.contains("Slope"):
		geo.shear_y(0.0, 0.25, 0.0)
	elif form.contains("Tilt"):
		var k: Array = GT_DIAG_TILT.get(form, [0.0, 0.0])
		geo.shear_y(float(k[0]), 0.0, float(k[1]))


## Y junctions: one branch (the 2-block GT curve or GT diagonal, both ending at the top centre,
## x 48) cut where it meets its mirror image across x = 48, plus that image (measured: the outer
## curbs meet in a V there); the slopes shear it, rising 0.25 per metre.
func _y_shaped(geo: TmGeo, form: String, ground: bool) -> void:
	var y: Array = Y_SHAPED[form]
	if String(y[0]) == "curve":
		_curve(geo, 2, ground)
	else:
		_gt_diag(geo, "2x2", ground)
	geo.clip(Vector3(1, 0, 0), 48.0)
	geo.add_mirror_x(48.0)
	if float(y[1]) != 0.0 or float(y[2]) != 0.0:
		geo.shear_y(0.0, float(y[1]), float(y[2]))


static func _diag_frames() -> Dictionary:
	if _diag_cache.is_empty():
		var f := FileAccess.open(GT_DIAG_FRAMES, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_diag_cache = (parsed as Dictionary).get("frames", {})
	return _diag_cache


## Tilted pieces: planar ones built flat then sheared, banked curves, and the transitions.
func _tilt(geo: TmGeo, base: String) -> void:
	if TILT_PLANES.has(base):
		var t: Array = TILT_PLANES[base]
		var build := String(t[0])
		if build == "straight":
			_straight(geo, 0.0, 32.0, false)
		elif build == "checkpoint":
			_straight(geo, 0.0, 32.0, false)
			_gate(geo, 16.0)
		else:
			var p := build.split(":")
			_arc_road(geo, Vector2(float(p[2]), float(p[3])), float(p[1]), float(p[4]), false, 0.0, 0.0,
				CURVE_STEPS.get(int((float(p[1]) + 16.0) / 32.0), 0))
		geo.shear_y(float(t[1]), float(t[2]), float(t[3]))
	elif TILT_BANKED.has(base):
		var k: int = TILT_BANKED[base]
		_arc_road(geo, Vector2(0, 32.0 * k), 32.0 * k - 16.0, -90.0, false, TILT, TILT_RISE, CURVE_STEPS.get(k, 0))
	else:
		var tr: Array = TILT_TRANSITIONS[base]
		var length := 32.0 * int(tr[0])
		var side := float(tr[1])
		var path := []
		var lat := []
		var n := int(length / 2.0)
		for i in n + 1:
			var t := float(i) / n
			path.append(Vector3(16, 8.0 - (8.0 - TILT_RISE) * _ease(TILT_DROP, t), length * t))
			lat.append(Vector3(1, side * TILT * _ease(TILT_EASE, t), 0))
		_sweep(geo, path, lat, false)


## Diagonal and curved transitions: the air section swept through a frame table (TILT_DIAG,
## TILT_CURVE), mirrored across x 32 for the Right pieces.
func _tilt_framed(geo: TmGeo, table: Array, right: bool) -> void:
	var path := []
	var lat := []
	for f: Array in table:
		var a := deg_to_rad(float(f[3]))
		var l := Vector3(cos(a), float(f[4]), sin(a))
		var x := float(f[0])
		if right:
			x = 64.0 - x
			l = Vector3(l.x, -l.y, -l.z)
		path.append(Vector3(x, float(f[1]) - TOP, float(f[2])))
		lat.append(l)
	_sweep(geo, path, lat, false)


## A table of values at evenly spaced t in [0, 1], read smoothly (Catmull-Rom) at t.
static func _ease(table: Array, t: float) -> float:
	var n := table.size() - 1
	var f := clampf(t, 0.0, 1.0) * n
	var i := mini(int(f), n - 1)
	var at := func(k: int) -> float: return float(table[clampi(k, 0, n)])
	var u := f - i
	var p0: float = at.call(i - 1)
	var p1: float = at.call(i)
	var p2: float = at.call(i + 1)
	var p3: float = at.call(i + 2)
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)


## Road-type pieces by their arms (SIDES indices).
func _junction(geo: TmGeo, form: String, ground: bool) -> void:
	match form:
		"Straight":
			_straight(geo, 0.0, 32.0, ground)
		"Corner":
			_curve(geo, 1, ground)
		"Deadend":
			# crowned: level from the open end to z 24, sinking CROWN toward the nose at z 16
			var path := [Vector3(16, 0, 16), Vector3(16, 0, 24), Vector3(16, 0, 32)]
			var drop := [CROWN, 0.0, 0.0]
			_sweep(geo, path, [Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0)], ground,
				func(y: float, i: int) -> float: return y - drop[i])
			_nose(geo, 16.0, -1.0, ground)
		"Base":
			var path := [Vector3(16, 0, 8), Vector3(16, 0, 16), Vector3(16, 0, 24)]
			var drop := [CROWN, 0.0, CROWN]
			_sweep(geo, path, [Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0)], ground,
				func(y: float, i: int) -> float: return y - drop[i])
			_nose(geo, 8.0, -1.0, ground)
			_nose(geo, 24.0, 1.0, ground)
		_:
			_cross(geo, ARMS[form], ground)


## Bump: a road one level up whose curbs and shoulders stay level while the asphalt between them
## dips through BUMP (measured): the curbs swept along z, the asphalt a slab (BUMP_T thick)
## through the profile, and the channel's sides from the dip up to the road's level.
func _bump(geo: TmGeo, ground: bool) -> void:
	var curb := _curb_section(ground)
	for side: float in [1.0, -1.0]:
		var sec := curb.map(func(q: Array) -> Array:
			var p: Vector2 = q[0]
			return [Vector2((p.x - 16.0) * side, p.y), q[1], q[2]] + q.slice(3))
		geo.wall_sweep(sec, [Vector3(16, 8, 0), Vector3(16, 8, 32)], [Vector3(1, 0, 0), Vector3(1, 0, 0)], true, "road_metal", S_METAL)
	var path := []
	var lat := []
	for i in BUMP.size():
		path.append(Vector3(16, float(BUMP[i]), 2.0 * i))
		lat.append(Vector3(1, 0, 0))
	var half := 16.0 - ROAD_EDGE
	var slab := [[Vector2(-half, -BUMP_T), "structure", S_METAL], [Vector2(half, -BUMP_T), "structure", S_METAL],
		[Vector2(half, 0.0), _road_mat, _road_surf], [Vector2(-half, 0.0), "structure", S_METAL]]
	geo.wall_sweep(slab, path, lat, true, "structure", S_METAL)
	for x: float in [ROAD_EDGE, 32.0 - ROAD_EDGE]:
		for i in BUMP.size() - 1:
			var y0 := float(BUMP[i])
			var y1 := float(BUMP[i + 1])
			var a := Vector3(x, y0, 2.0 * i)
			var b := Vector3(x, y1, 2.0 * (i + 1))
			geo.quad(a, b, Vector3(x, 8.0 + TOP, b.z), Vector3(x, 8.0 + TOP, a.z), "structure", S_METAL)
			geo.quad(a, Vector3(x, 8.0 + TOP, a.z), Vector3(x, 8.0 + TOP, b.z), b, "structure", S_METAL)


## A road piece following a measured height profile along z (every 2 m), the section sheared up as
## TMNF does; ground pieces keep their base on the terrain (1 m).
func _profile_slope(geo: TmGeo, heights: Array, ground: bool) -> void:
	var path := []
	var lat := []
	for i in heights.size():
		path.append(Vector3(16, float(heights[i]) - TOP, 2.0 * i))
		lat.append(Vector3(1, 0, 0))
	# on the ground TMNF keeps the raised road's section (its keel runs into the terrain at the
	# low end) where it leaves the ground; a road flat on the ground (U top) keeps the ground's
	var flat := ground and float(heights.max()) - float(heights.min()) < 2.5 and float(heights[0]) <= TOP
	var y_at := Callable()
	if flat:
		y_at = func(y: float, i: int) -> float: return 1.0 - (path[i] as Vector3).y if y <= 1.001 else y
	_sweep(geo, path, lat, flat, y_at)


## The round pillar TMNF stands under a ground slope's raised end (measured: on the centre line at
## z, r 1.42 m, a flared foot on the terrain and a flared head under the keel): keel(z) is the
## keel's bottom (block-local y) along the road.
func _ground_pillar(geo: TmGeo, z: float, keel: Callable) -> void:
	var c := Vector2(16.0, z)
	var head := func(q: Vector2) -> float: return float(keel.call(q.y))
	geo.ring(c, 12, 2.0, func(_q: Vector2) -> float: return 1.0, 1.42, func(_q: Vector2) -> float: return 2.0, "road_metal", S_METAL)
	geo.ring(c, 12, 1.42, func(_q: Vector2) -> float: return 2.0, 1.42, func(q: Vector2) -> float: return float(head.call(q)) - 0.8, "pillar", S_ROAD)
	geo.ring(c, 12, 1.42, func(q: Vector2) -> float: return float(head.call(q)) - 0.8, 2.0, head, "road_metal", S_METAL)


## The road (asphalt and curbs) swept along z through measured surface heights (evenly spaced over
## the block), its underside cut off at floor_y where it rises off a platform deck; mat: the
## surface's material (the platform's own where the ramp is part of a platform block).
func ramp(geo: TmGeo, heights: Array, floor_y: float, mat := "asphalt") -> void:
	_road_mat = mat
	_green_shoulders = true      # TMNF's ramp off a platform has the ground road's green shoulders
	var path := []
	var lat := []
	for i in heights.size():
		path.append(Vector3(16, float(heights[i]) - TOP, 32.0 * i / (heights.size() - 1)))
		lat.append(Vector3(1, 0, 0))
	var y_at := func(y: float, i: int) -> float: return maxf(y, floor_y - (path[i] as Vector3).y)
	_sweep(geo, path, lat, false, y_at)
	_road_mat = "asphalt"
	_green_shoulders = false


## Road/Main onto a platform floor at road level (Platform/ToRoad, where the platform loops begin):
## a plate the width of the block at the road's height. One block (blocks = 1): the road from z 16
## to 32, its curbs turned out round the side midpoints onto the plate. Two blocks (z 0 -> 64, the
## road at z 0): one curb turns out at once round its corner, the other runs on across the plate
## on an arc of radius TO_PLATFORM_R tangent to the road (measured) to near the far corner; mirror
## swaps the sides.
func to_platform(geo: TmGeo, blocks: int, ground: bool, mirror: bool) -> void:
	var len := 32.0 * blocks
	var plate_z1 := 16.0 if blocks == 1 else len
	geo.box(Vector3(0, 1.0, 0), Vector3(32, TOP, plate_z1), "structure", S_METAL, "platform" if blocks == 1 else "asphalt", S_ROAD)
	if not ground:
		geo.box(Vector3(14.34, 0.4, 0), Vector3(17.66, 1.0, plate_z1), "structure", S_METAL)
	var curb := _curb_section(ground)
	var mx := func(v: Vector3) -> Vector3: return Vector3(32.0 - v.x, v.y, v.z) if mirror else v
	var ml := func(v: Vector3) -> Vector3: return Vector3(-v.x, v.y, v.z) if mirror else v
	if blocks == 1:
		_straight(geo, 16.0, 32.0, ground)
		_turn_out(geo, curb, Vector3(0, 0, 16), Vector3(1, 0, 0), Vector3(0, 0, -1))
		_turn_out(geo, curb, Vector3(32, 0, 16), Vector3(-1, 0, 0), Vector3(0, 0, -1))
		return
	# the curb that turns out at once, round the corner at the road's end
	_turn_out(geo, curb, mx.call(Vector3(32, 0, 0)), ml.call(Vector3(-1, 0, 0)), Vector3(0, 0, 1))
	# the one that runs across: its edge line on the arc, d inward toward the arc's centre
	var path := []
	var lat := []
	var steps := 24
	for k in steps + 1:
		var a := deg_to_rad(TO_PLATFORM_END) * k / steps
		path.append(mx.call(Vector3(TO_PLATFORM_R * (1.0 - cos(a)), 0, TO_PLATFORM_R * sin(a))))
		lat.append(ml.call(Vector3(cos(a), 0, -sin(a))))
	geo.wall_sweep(curb, path, lat, true, "road_metal", S_METAL)


## A curb turned through a quarter circle about a point on the block's edge: its section's lateral
## goes from `from` (along the road) to `to` (along the edge it ends on).
func _turn_out(geo: TmGeo, curb: Array, c: Vector3, from: Vector3, to: Vector3) -> void:
	var path := []
	var lat := []
	var steps := 6
	for s in steps + 1:
		var ang := PI * 0.5 * float(s) / steps
		lat.append((from * cos(ang) + to * sin(ang)).normalized())
		path.append(c)
	geo.wall_sweep(curb, path, lat, true, "road_metal", S_METAL)


func _straight(geo: TmGeo, z0: float, z1: float, ground: bool) -> void:
	_sweep(geo, [Vector3(16, 0, z0), Vector3(16, 0, z1)], [Vector3(1, 0, 0), Vector3(1, 0, 0)], ground)


## A road end's low nose beyond z0 (toward dir): a thin plate 2.3 m long under the curbs' ends.
func _nose(geo: TmGeo, z0: float, dir: float, ground: bool, top := TOP - CROWN - 0.04) -> void:
	var z1 := z0 + dir * 2.3
	var y0 := 1.0 if ground else 1.05
	geo.box(Vector3(1.05, y0, minf(z0, z1)), Vector3(30.95, top, maxf(z0, z1)), "road_under", S_METAL,
		"road_grid", S_METAL)


## Checkpoint / finish / multilap / start gate centred at z: TMNF's arch (its measured section)
## swept 4.2 m along the road, its front and back faces a moulded rubber band with the gate's word
## running along the arch ("gate_<kind>", UVs along the arch), its top and underside TMNF's border
## atlas strips (_gate_shell), light rigs on its shoulders aimed at the road. TMNF's two sign boards on top are left
## out (the review's gate option B: they read as horns); TmGateDress adds an LED screen in the
## crown instead (TmGateScreen). The road takes TMNF's line across it (_gate_line). The arch's
## ends stand on the curbs as TMNF's do (_gate_feet); the dirt roads' gates are this one resized
## (dirt.gd CHECKPOINTS), strap_dy moving the clamps' straps down onto their bumpers.
func _gate(geo: TmGeo, zc: float, strap_dy := 0.0) -> void:
	_gates.append(zc)
	_gate_line(geo, zc)
	# the arch's band swept for its collision and its ends at the feet; its top and underside
	# TMNF's atlas strips (_gate_shell), its faces the word band (_gate_faces)
	var sec := []
	for k in GATE_ARCH.size():
		var q: Array = GATE_ARCH[k]
		sec.append([Vector2(q[0], q[1]), "gate_shell" if GATE_ARCH_ENDS.has(k) else "", q[3]])
	geo.wall_sweep(sec, [Vector3(0, 0, zc - 2.1), Vector3(0, 0, zc + 2.1)], [Vector3(1, 0, 0), Vector3(1, 0, 0)],
		false, "gate_shell", S_METAL)
	_gate_shell(geo, zc)
	_gate_faces(geo, zc)
	_gate_feet(geo, zc, strap_dy)
	_gate_lights(geo, zc)


## TMNF's line across the road at a gate: the road top cut LINE_HALF either side of zc and laid
## with the border atlas' blue band (u across the road, 16 m a tile).
func _gate_line(geo: TmGeo, zc: float) -> void:
	geo.split_mat(_road_mat, Vector3(0, 0, 1), [zc - LINE_HALF, zc + LINE_HALF], [_road_mat, "gate_line", _road_mat])
	geo.remap_uv("gate_line", func(p: Vector3) -> Vector2:
		return Vector2(p.x / 16.0, lerpf(LINE_ROWS.x, LINE_ROWS.y, (p.z - zc + LINE_HALF) / (2.0 * LINE_HALF)) / 512.0))


## TMNF's start / finish road (RoadRace: texgen/gates.py race_road) on the road top between z0 and
## z1 (the rest stays asphalt; a finish block's road is laid with it whole): u along the road,
## RACE_TILE m a tile, v from the edge (0) to the centre line (1), mirrored.
func _race_road(geo: TmGeo, key: String, z0: float, z1: float) -> void:
	geo.split_mat("asphalt", Vector3(0, 0, 1), [z0, z1], ["asphalt", key, "asphalt"])
	geo.remap_uv(key, func(p: Vector3) -> Vector2:
		return Vector2(p.z / RACE_TILE, 1.0 - absf(p.x - 16.0) / (16.0 - ROAD_EDGE)))


## The arch's feet (TMNF's, measured), each end alike (the right one mirrored): at GATE_FOOT_Z from
## the gate's centre a dark clamp round the curb (GATE_CLAMP, its outer flange the thickest) with
## a strap over the curb's top (GATE_STRAP, strap_dy higher: a dirt gate's on its bumper), from it
## an eight-sided strut up to the arch's end (GATE_STRUT, GATE_STRUT_HEX), between the struts a dark
## see-through lattice (GATE_LATTICE: its lower and upper edge, along GATE_LATTICE_Z) and on it two
## light rigs aimed down at the road (GATE_SPOTS: their centres, GATE_SPOT_SIDE square, along
## GATE_SPOT_Z). (TMNF's checkpoints also have a clamp at z 5.8 holding a brace up to the sign
## boards over the arch; with the boards (left out: the owner's option B) they are left out.)
func _gate_feet(geo: TmGeo, zc: float, strap_dy := 0.0) -> void:
	var axis: Vector2 = (GATE_STRUT[1] - GATE_STRUT[0]).normalized()
	for right in [false, true]:
		var mx := func(q: Vector2) -> Vector2: return Vector2(32.0 - q.x, q.y) if right else q
		for zf: float in GATE_FOOT_Z:
			var z := zc + zf
			var front := []
			var back := []
			for q: Vector3 in GATE_CLAMP:
				var p: Vector2 = mx.call(Vector2(q.x, q.y))
				front.append(Vector3(p.x, p.y, z - q.z))
				back.append(Vector3(p.x, p.y, z + q.z))
			_extrude(geo, front, back, "road_metal", S_METAL)
			var x0: Vector2 = mx.call(Vector2(GATE_STRAP_X.x, 0.0))
			var x1: Vector2 = mx.call(Vector2(GATE_STRAP_X.y, 0.0))
			_extrude(geo, GATE_STRAP.map(func(q: Vector2) -> Vector3: return Vector3(x0.x, q.y + strap_dy, z + q.x)),
				GATE_STRAP.map(func(q: Vector2) -> Vector3: return Vector3(x1.x, q.y + strap_dy, z + q.x)), "road_metal", S_METAL)
			var rings := []
			for end: Vector2 in GATE_STRUT:
				rings.append(GATE_STRUT_HEX.map(func(h: Vector2) -> Vector3:
					var p: Vector2 = mx.call(end + Vector2(-axis.y, axis.x) * h.x)
					return Vector3(p.x, p.y, z + h.y)))
			_extrude(geo, rings[0], rings[1], "road_metal", S_METAL, false)
		var a: Vector2 = mx.call(GATE_LATTICE[0])
		var b: Vector2 = mx.call(GATE_LATTICE[1])
		var z0 := zc + GATE_LATTICE_Z.x
		var z1 := zc + GATE_LATTICE_Z.y
		# (one face: the translucent material shows both sides)
		geo.quad(Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1),
			"glass_dark", TmGeo.NO_COLLISION)
		# the light rigs: square housings turned with the lattice, their lamps facing the road
		var dir := (GATE_LATTICE[1] - GATE_LATTICE[0]).normalized()
		var nrm := Vector2(dir.y, -dir.x)          # toward the road and down (left foot)
		var h := GATE_SPOT_SIDE * 0.5
		for c: Vector2 in GATE_SPOTS:
			var sq := [c - dir * h - nrm * h, c + dir * h - nrm * h, c + dir * h + nrm * h, c - dir * h + nrm * h]
			_prism(geo, sq.map(mx), zc + GATE_SPOT_Z.x, zc + GATE_SPOT_Z.y, "gate_shell", TmGeo.NO_COLLISION)
			var f0: Vector2 = mx.call(c + nrm * (h + 0.01) - dir * (h - 0.06))
			var f1: Vector2 = mx.call(c + nrm * (h + 0.01) + dir * (h - 0.06))
			var face := [Vector3(f0.x, f0.y, zc + GATE_SPOT_Z.x + 0.08), Vector3(f1.x, f1.y, zc + GATE_SPOT_Z.x + 0.08),
				Vector3(f1.x, f1.y, zc + GATE_SPOT_Z.y - 0.08), Vector3(f0.x, f0.y, zc + GATE_SPOT_Z.y - 0.08)]
			var uvs := [Vector2(0, 1), Vector2(0, 0), Vector2(2, 0), Vector2(2, 1)]
			var out3 := Vector3(-nrm.x if right else nrm.x, nrm.y, 0.0)
			if (face[1] - face[0]).cross(face[2] - face[0]).dot(out3) < 0.0:
				geo.quad_uv(face[0], face[3], face[2], face[1], "gate_lamps", TmGeo.NO_COLLISION, uvs[0], uvs[3], uvs[2], uvs[1])
			else:
				geo.quad_uv(face[0], face[1], face[2], face[3], "gate_lamps", TmGeo.NO_COLLISION, uvs[0], uvs[1], uvs[2], uvs[3])


## A convex (or star-shaped) outline (x, y) extruded along z from z0 to z1, its faces outward.
func _prism(geo: TmGeo, poly: Array, z0: float, z1: float, key: String, surface: int) -> void:
	_extrude(geo, poly.map(func(q: Vector2) -> Vector3: return Vector3(q.x, q.y, z0)),
		poly.map(func(q: Vector2) -> Vector3: return Vector3(q.x, q.y, z1)), key, surface)


## A solid between two matching convex rings of points (a0[k] faces b0[k]), its faces outward:
## the sides, and (caps) each ring closed by a fan from its centre.
func _extrude(geo: TmGeo, ring0: Array, ring1: Array, key: String, surface: int, caps := true) -> void:
	var c0 := Vector3.ZERO
	var c1 := Vector3.ZERO
	for k in ring0.size():
		c0 += ring0[k] / ring0.size()
		c1 += ring1[k] / ring1.size()
	var cc := (c0 + c1) * 0.5
	for k in ring0.size():
		var k1 := (k + 1) % ring0.size()
		var f := [ring0[k], ring0[k1], ring1[k1], ring1[k]]
		var mid: Vector3 = (f[0] + f[1] + f[2] + f[3]) * 0.25
		if (f[1] - f[0]).cross(f[2] - f[0]).dot(mid - cc) < 0.0:
			geo.quad(f[0], f[3], f[2], f[1], key, surface)
		else:
			geo.quad(f[0], f[1], f[2], f[3], key, surface)
	if not caps:
		return
	for r in 2:
		var ring: Array = ring0 if r == 0 else ring1
		var c := c0 if r == 0 else c1
		var out := (c0 - c1) if r == 0 else (c1 - c0)
		for k in ring.size():
			var a: Vector3 = ring[k]
			var b: Vector3 = ring[(k + 1) % ring.size()]
			if (a - c).cross(b - c).dot(out) < 0.0:
				geo.tri(c, b, a, key, surface)
			else:
				geo.tri(c, a, b, key, surface)


## The arch's top and underside as TMNF's: its border atlas in strips across the arch's depth
## (GATE_TOP, GATE_UNDER), u along the arch (16 m a tile), each facing away from (top) or toward
## (underside) about the arch's centre.
func _gate_shell(geo: TmGeo, zc: float) -> void:
	var lines := _arch_lines()
	for w in 2:
		var line: Array = lines[w]
		var strips: Array = GATE_TOP if w == 0 else GATE_UNDER
		var s := 0.0
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var ds := a.distance_to(b)
			var o2 := ((a + b) * 0.5 - GATE_ARCH_CENTRE) * (1.0 if w == 0 else -1.0)
			var out := Vector3(o2.x, o2.y, 0.0)
			for st: Array in strips:
				var z0 := zc + float(st[0])
				var z1 := zc + float(st[1])
				var r: Vector2 = st[2]
				var p := [Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1)]
				var uv := [Vector2(s / 16.0, r.x / 512.0), Vector2((s + ds) / 16.0, r.x / 512.0),
					Vector2((s + ds) / 16.0, r.y / 512.0), Vector2(s / 16.0, r.y / 512.0)]
				if ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).dot(out) < 0.0:
					geo.quad_uv(p[0], p[3], p[2], p[1], String(st[3]), TmGeo.NO_COLLISION, uv[0], uv[3], uv[2], uv[1])
				else:
					geo.quad_uv(p[0], p[1], p[2], p[3], String(st[3]), TmGeo.NO_COLLISION, uv[0], uv[1], uv[2], uv[3])
			s += ds


## The arch's outer and inner lines (x, y), from the left foot to the right one (GATE_ARCH: the
## outer line runs from the crown (0) down to the left foot (8), the inner from 9 to 25, the
## outer again from the right foot (26) up to beside the crown (33)).
static func _arch_lines() -> Array:
	var outer := []
	for k in range(8, -1, -1):
		outer.append(Vector2(GATE_ARCH[k][0], GATE_ARCH[k][1]))
	for k in range(GATE_ARCH.size() - 1, 25, -1):
		outer.append(Vector2(GATE_ARCH[k][0], GATE_ARCH[k][1]))
	var inner := []
	for k in range(9, 26):
		inner.append(Vector2(GATE_ARCH[k][0], GATE_ARCH[k][1]))
	return [outer, inner]


## Points evenly spaced along a polyline (by length), n of them.
static func _resample_line(line: Array, n: int) -> Array:
	var acc := [0.0]
	for i in range(1, line.size()):
		acc.append(float(acc[i - 1]) + ((line[i] as Vector2) - (line[i - 1] as Vector2)).length())
	var total: float = acc[acc.size() - 1]
	var out := []
	var j := 0
	for k in n:
		var d := total * k / (n - 1)
		while j < line.size() - 2 and float(acc[j + 1]) < d:
			j += 1
		var seg := float(acc[j + 1]) - float(acc[j])
		var t := 0.0 if seg <= 0.0 else (d - float(acc[j])) / seg
		out.append((line[j] as Vector2).lerp(line[j + 1], clampf(t, 0.0, 1.0)))
	return out


## The arch's front and back faces: strips between its outer and inner lines, the band's text
## running along the arch, upright (the band's top at the outer line), reading left to right
## from either side; collision like the sweep's caps.
func _gate_faces(geo: TmGeo, zc: float) -> void:
	var lines := _arch_lines()
	var n := 41
	var outer := _resample_line(lines[0], n)
	var inner := _resample_line(lines[1], n)
	var length := 0.0
	for i in range(1, n):
		length += (((outer[i] as Vector2) + (inner[i] as Vector2)) * 0.5 - ((outer[i - 1] as Vector2) + (inner[i - 1] as Vector2)) * 0.5).length()
	var fit := maxf(1.0, roundf(length / GATE_WORD)) * GATE_WORD / length
	var key := "gate_" + _gate_kind
	for face: float in [-1.0, 1.0]:
		var z := zc + face * 2.1
		var u := 0.0
		for i in n - 1:
			var o0: Vector2 = outer[i]
			var o1: Vector2 = outer[i + 1]
			var i0: Vector2 = inner[i]
			var i1: Vector2 = inner[i + 1]
			var du := (((o1 + i1) - (o0 + i0)) * 0.5).length() * fit
			# from the front (face -1, seen from -z) u runs with TMNF x; the back face mirrors it
			var ua := u * -face
			var ub := (u + du) * -face
			var a := Vector3(o0.x, o0.y, z)
			var b := Vector3(o1.x, o1.y, z)
			var c := Vector3(i1.x, i1.y, z)
			var d := Vector3(i0.x, i0.y, z)
			var uva := Vector2(ua, 0.0)
			var uvb := Vector2(ub, 0.0)
			var uvc := Vector2(ub, 1.25)
			var uvd := Vector2(ua, 1.25)
			var nrm := Vector3(0, 0, face)
			if (b - a).cross(c - a).dot(nrm) < 0.0:
				geo.tri(a, c, b, key, S_METAL, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, uva, uvc, uvb)
				geo.tri(a, d, c, key, S_METAL, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, uva, uvd, uvc)
			else:
				geo.tri(a, b, c, key, S_METAL, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, uva, uvb, uvc)
				geo.tri(a, c, d, key, S_METAL, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, uva, uvc, uvd)
			u += du


## Light rigs on the arch's shoulders, front and back: a housing with a face of lamps tilted
## down towards the road (visual only; the lamps glow, "gate_lamps").
func _gate_lights(geo: TmGeo, zc: float) -> void:
	for x: float in [7.6, 24.4]:
		var side := -1.0 if x < 16.0 else 1.0
		for face: float in [-1.0, 1.0]:
			var z := zc + face * 2.1
			var rig := TmGeo.new()
			# housing 2 x 1 x 0.45 m, its face towards the road and down
			rig.box(Vector3(-1.0, -0.5, 0.0), Vector3(1.0, 0.5, 0.45), "gate_shell", TmGeo.NO_COLLISION, "", -2, 0.05)
			var f := [Vector3(-0.92, -0.42, -0.01), Vector3(0.92, -0.42, -0.01), Vector3(0.92, 0.42, -0.01), Vector3(-0.92, 0.42, -0.01)]
			var uv := [Vector2(0, 1), Vector2(2, 1), Vector2(2, 0), Vector2(0, 0)]
			rig.tri(f[0], f[2], f[1], "gate_lamps", TmGeo.NO_COLLISION, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, uv[0], uv[2], uv[1])
			rig.tri(f[0], f[3], f[2], "gate_lamps", TmGeo.NO_COLLISION, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, uv[0], uv[3], uv[2])
			# place: on the arch's face, tilted 35 deg down, turned 25 deg in towards the road
			var basis := Basis(Vector3.UP, deg_to_rad(-25.0 * side) if face < 0.0 else deg_to_rad(180.0 + 25.0 * side))
			basis = basis * Basis(Vector3.RIGHT, deg_to_rad(-35.0))
			var pos := TmGeo.g(Vector3(x, 6.9, z + face * 0.46))
			for key: String in rig._vis:
				var grp: TmGeo.Group = rig._vis[key]
				var g2 := geo._group(key)
				for k in grp.v.size():
					g2.v.append(Transform3D(basis, pos) * grp.v[k])
					g2.n.append(basis * grp.n[k])
					g2.uv.append(grp.uv[k])


## Turbo (and free-wheel) gate: the U-frame round the road (sheared with it, see _turbo_sides).
func _turbo_gate(geo: TmGeo) -> void:
	var sec := TURBO_FRAME.map(func(q: Array) -> Array: return [Vector2(q[0], q[1]), q[2], q[3]])
	geo.wall_sweep(sec, [Vector3(0, 0, 14.4), Vector3(0, 0, 17.45)], [Vector3(1, 0, 0), Vector3(1, 0, 0)],
		true, "structure", 22)


## The turbo gate's sides, over each curb: a booster pod (a collar round the fan of nine blades, a
## slimmer body through the frame, a cap behind it) and on it a grid tray between railings (TMNF's;
## our cut-out railing cards, solid to the car),
## level over the pod and the frame, then down to the curb. On a road sheared by (kx, kz, dy) each
## side keeps its shape: lifted with the road at its axis, sheared only along the slope, the tray's
## level part never dipping toward the front (measured on the sloped and tilted pads).
func _turbo_sides(geo: TmGeo, kx := 0.0, kz := 0.0, dy := 0.0) -> void:
	var pod := TURBO_POD.map(func(q: Array) -> Array: return [q[0], q[1], q[2], 22])
	for x: float in [2.0, 30.0]:
		var side := TmGeo.new()
		var lift := kx * x + dy
		side.revolve_z(pod, Vector2(x, TURBO_POD_Y + lift), 0.0, 360.0, 36, false)
		var cap: Array = TURBO_POD[TURBO_POD.size() - 2]
		bolt_rings(side, Vector3(x, TURBO_POD_Y + lift, float(cap[0]) + 0.01), TURBO_BOSS, TURBO_BOLT, TURBO_BOLT_AT)
		var fc := Vector3(x, TURBO_POD_Y + lift, float(TURBO_POD[0][0]) - 0.03)
		side.fan(fc, 0.35, 1.45, 0.16, "road_metal", 9)
		# the dark inside behind the blades, facing out of the pod (-z)
		for k in 24:
			var a0 := TAU * k / 24.0
			var a1 := TAU * (k + 1) / 24.0
			var o := fc + Vector3(0, 0, 0.02)
			side.tri(o, o + Vector3(cos(a1), sin(a1), 0) * 1.5, o + Vector3(cos(a0), sin(a0), 0) * 1.5, "stands_dark",
				TmGeo.NO_COLLISION)
		var tray := []
		for q: Vector2 in TURBO_TRAY:
			tray.append(Vector2(q.x, q.y + lift))
		tray[0].y += maxf(0.0, kz * (tray[1].x - tray[0].x))
		var x0 := x - TURBO_FIN_HALF
		var x1 := x + TURBO_FIN_HALF
		var lo: float = TURBO_PANEL[0]
		var hi: float = TURBO_PANEL[1]
		var u := 0.0
		for i in tray.size() - 1:
			var a: Vector2 = tray[i]
			var b: Vector2 = tray[i + 1]
			side.quad(Vector3(x0, a.y, a.x), Vector3(x0, b.y, b.x), Vector3(x1, b.y, b.x), Vector3(x1, a.y, a.x), "grid", S_METAL)
			# the railing either side (cut-out cards, 8 m a tile; collision on their outline)
			var du := a.distance_to(b) / 8.0
			for px: float in [x0, x1]:
				var q := [Vector3(px, a.y - lo, a.x), Vector3(px, b.y - lo, b.x), Vector3(px, b.y + hi, b.x), Vector3(px, a.y + hi, a.x)]
				side.quad_uv(q[0], q[1], q[2], q[3], "railing", TmGeo.NO_COLLISION, Vector2(u, 1), Vector2(u + du, 1),
					Vector2(u + du, 0), Vector2(u, 0))
				side.quad(q[0], q[1], q[2], q[3], "", S_METAL)
			u += du
		var f: Vector2 = tray[0]
		var e: Vector2 = tray[tray.size() - 1]
		var w := (x1 - x0) / 8.0
		side.quad_uv(Vector3(x0, f.y - lo, f.x), Vector3(x1, f.y - lo, f.x), Vector3(x1, f.y + hi, f.x),
			Vector3(x0, f.y + hi, f.x), "railing", TmGeo.NO_COLLISION, Vector2(0, 1), Vector2(w, 1), Vector2(w, 0), Vector2(0, 0))
		side.quad(Vector3(x0, f.y - lo, f.x), Vector3(x0, f.y + hi, f.x), Vector3(x1, f.y + hi, f.x), Vector3(x1, f.y - lo, f.x), "", S_METAL)
		side.quad(Vector3(x0, e.y - lo, e.x), Vector3(x0, e.y, e.x), Vector3(x1, e.y, e.x), Vector3(x1, e.y - lo, e.x),
			"glass_dark", S_METAL)
		side.shear_y(0.0, kz, 0.0)
		geo.merge(side)


## TMNF's keel under a junction in the air: in each quarter of the block the road's keel section
## (HALF_AIR and its mirror across the centre line: the plates, the dark middle strip, the far
## plates rising again; the step up to the shoulder at SHOULDER) by the distance from the quarter's
## corner, revolved round it, where both its sides are open (between four such corners the middle
## a diamond with hollow sides); where one is closed, by the distance from that side, straight. A
## dark face closes the step where a straight quarter meets a revolved one. Facing down.
func _junction_keel(geo: TmGeo, closed: Array) -> void:
	var ribs: Vector2 = HALF_AIR[0][4]          # the middle strip's rows, at its middle to its edge
	var x_plate := float(HALF_AIR[1][0])         # the strip's edge (14.339)
	var x_mid := float(HALF_AIR[2][0])
	# the profile out from the shoulder: [distance, y, key of the segment from it, rows]
	var prof := [[SHOULDER, float(HALF_AIR[3][1]), "road_under"], [x_mid, float(HALF_AIR[2][1]), "road_under"],
		[x_plate, 0.0, "border_ribs", Vector2(ribs.y, ribs.x)], [16.0, 0.0, "border_ribs", ribs],
		[32.0 - x_plate, 0.0, "road_under"], [32.0 - x_mid, float(HALF_AIR[2][1]), "road_under"], [32.0 - SHOULDER, float(HALF_AIR[3][1]), ""]]
	var y_at := func(r: float) -> float:
		for e in prof.size() - 1:
			var a: Array = prof[e]
			var b: Array = prof[e + 1]
			if r <= float(b[0]) or e == prof.size() - 2:
				return lerpf(float(a[1]), float(b[1]), clampf((r - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0))
		return 0.0
	var step_rows: Vector2 = HALF_AIR[3][4]
	# (which way a quad faces from its diagonals: a clipped ring's quads may be triangles)
	var face := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, key: String, uv: Array, out: Vector3) -> void:
		if (c - a).cross(d - b).dot(out) >= 0.0:
			geo.quad_uv(a, b, c, d, key, S_METAL, uv[0], uv[1], uv[2], uv[3])
		else:
			geo.quad_uv(a, d, c, b, key, S_METAL, uv[0], uv[3], uv[2], uv[1])
	# a segment's UVs at (along, distance) corners: the plates 8 x 4 m a tile, the strip the atlas
	var seg_uv := func(e: int, s0: float, s1: float, r0: float, r1: float) -> Array:
		var seg: Array = prof[e]
		if String(seg[2]) == "border_ribs":
			var rows: Vector2 = seg[3]
			var span := float(prof[e + 1][0]) - float(seg[0])
			var v0 := lerpf(rows.x, rows.y, (r0 - float(seg[0])) / span) / 512.0
			var v1 := lerpf(rows.x, rows.y, (r1 - float(seg[0])) / span) / 512.0
			return [Vector2(s0 / 16.0, v0), Vector2(s1 / 16.0, v0), Vector2(s1 / 16.0, v1), Vector2(s0 / 16.0, v1)]
		return [Vector2(s0 / 8.0, (16.0 - r0) / 4.0), Vector2(s1 / 8.0, (16.0 - r0) / 4.0), Vector2(s1 / 8.0, (16.0 - r1) / 4.0),
			Vector2(s0 / 8.0, (16.0 - r1) / 4.0)]
	var step_uv := func(s0: float, s1: float) -> Array:
		return [Vector2(s0 / 16.0, step_rows.x / 512.0), Vector2(s1 / 16.0, step_rows.x / 512.0),
			Vector2(s1 / 16.0, step_rows.y / 512.0), Vector2(s0 / 16.0, step_rows.y / 512.0)]
	var top := 1.243                             # the shoulder's underside (HALF_AIR)
	# the quarters: corner, its sides (SIDES indices: the one at the corner's x, the one at its z)
	for q: Array in [[Vector2(0, 0), 1, 2], [Vector2(32, 0), 3, 2], [Vector2(32, 32), 3, 0], [Vector2(0, 32), 1, 0]]:
		var cq: Vector2 = q[0]
		var sx := 1.0 if cq.x == 0.0 else -1.0
		var sz := 1.0 if cq.y == 0.0 else -1.0
		var x_closed: bool = closed[q[1]]
		var z_closed: bool = closed[q[2]]
		if x_closed and z_closed:
			continue
		var at := func(d: Vector2) -> Vector3:
			var p := cq + Vector2(sx * d.x, sz * d.y)
			return Vector3(p.x, 0.0, p.y)
		if not x_closed and not z_closed:
			# revolved round the corner, each ring clipped to the quarter (x and z 16 from it)
			var n := 16
			for k in n:
				var t0 := PI * 0.5 * k / n
				var t1 := PI * 0.5 * (k + 1) / n
				var d0 := Vector2(cos(t0), sin(t0))
				var d1 := Vector2(cos(t1), sin(t1))
				var lim0 := 16.0 / maxf(d0.x, d0.y)
				var lim1 := 16.0 / maxf(d1.x, d1.y)
				for e in prof.size() - 1:
					var ra := float(prof[e][0])
					var rb := float(prof[e + 1][0])
					var a0 := minf(ra, lim0)
					var b0 := minf(rb, lim0)
					var a1 := minf(ra, lim1)
					var b1 := minf(rb, lim1)
					if b0 - a0 < 1e-4 and b1 - a1 < 1e-4:
						continue
					var p0: Vector3 = at.call(d0 * a0)
					var p1: Vector3 = at.call(d1 * a1)
					var p2: Vector3 = at.call(d1 * b1)
					var p3: Vector3 = at.call(d0 * b0)
					p0.y = y_at.call(a0)
					p1.y = y_at.call(a1)
					p2.y = y_at.call(b1)
					p3.y = y_at.call(b0)
					var uv: Array = seg_uv.call(e, ra * t0, ra * t1, ra, rb)
					face.call(p0, p1, p2, p3, String(prof[e][2]), uv, Vector3.DOWN)
				# the step up to the shoulder's underside, facing the corner
				var s0: Vector3 = at.call(d0 * SHOULDER)
				var s1: Vector3 = at.call(d1 * SHOULDER)
				var yk := float(prof[0][1])
				face.call(Vector3(s0.x, yk, s0.z), Vector3(s1.x, yk, s1.z), Vector3(s1.x, top, s1.z), Vector3(s0.x, top, s0.z),
					"border_ribs", step_uv.call(SHOULDER * t0, SHOULDER * t1), Vector3(cq.x, 0, cq.y) - (s0 + s1) * 0.5)
			continue
		# straight from the closed side: d across the quarter from it, l along it (0..16)
		var pt := func(d: float, l: float) -> Vector3: return at.call(Vector2(d, l) if x_closed else Vector2(l, d))
		var away := Vector3(sx, 0, 0) if x_closed else Vector3(0, 0, sz)
		for e in 3:
			var ra := float(prof[e][0])
			var rb := float(prof[e + 1][0])
			var ya := float(prof[e][1])
			var yb := float(prof[e + 1][1])
			var p := [pt.call(ra, 0.0), pt.call(ra, 16.0), pt.call(rb, 16.0), pt.call(rb, 0.0)]
			p[0].y = ya
			p[1].y = ya
			p[2].y = yb
			p[3].y = yb
			face.call(p[0], p[1], p[2], p[3], String(prof[e][2]), seg_uv.call(e, 0.0, 16.0, ra, rb), Vector3.DOWN)
		var s0: Vector3 = pt.call(SHOULDER, 0.0)
		var s1: Vector3 = pt.call(SHOULDER, 16.0)
		var yk := float(prof[0][1])
		face.call(Vector3(s0.x, yk, s0.z), Vector3(s1.x, yk, s1.z), Vector3(s1.x, top, s1.z), Vector3(s0.x, top, s0.z),
			"border_ribs", step_uv.call(0.0, 16.0), -away)
		# where it meets the revolved quarter beyond its middle (d 16): the dark face up to that
		# quarter's keel, facing it
		var other := cq + (Vector2(32.0 * sx, 0.0) if x_closed else Vector2(0.0, 32.0 * sz))
		var steps := 16
		for k in steps:
			var l0 := 16.0 * k / steps
			var l1 := 16.0 * (k + 1) / steps
			var e0: Vector3 = pt.call(16.0, l0)
			var e1: Vector3 = pt.call(16.0, l1)
			var h0: float = y_at.call(Vector2(e0.x, e0.z).distance_to(other))
			var h1: float = y_at.call(Vector2(e1.x, e1.z).distance_to(other))
			if h0 < 1e-3 and h1 < 1e-3:
				continue
			face.call(e0, e1, Vector3(e1.x, h1, e1.z), Vector3(e0.x, h0, e0.z), "road_metal",
				[Vector2.ZERO, Vector2(0.01, 0), Vector2(0.01, 0.01), Vector2(0, 0.01)], away)


## A ring of eight bolts round a boss on a turbine's back cap at c (the x-y plane, facing +z):
## light flat rims (radii boss, bolt; the bolts `at` out), visual only.
static func bolt_rings(geo: TmGeo, c: Vector3, boss: Array, bolt: Array, at: float) -> void:
	var rim := func(o: Vector3, r0: float, r1: float, n: int) -> void:
		for k in n:
			var d0 := Vector3(cos(TAU * k / n), sin(TAU * k / n), 0)
			var d1 := Vector3(cos(TAU * (k + 1) / n), sin(TAU * (k + 1) / n), 0)
			# (out, then round toward +angle: wound to face +z)
			geo.quad(o + d0 * r0, o + d0 * r1, o + d1 * r1, o + d1 * r0, "stands_top", TmGeo.NO_COLLISION)
	rim.call(c, float(boss[0]), float(boss[1]), 16)
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		rim.call(c + Vector3(cos(a), sin(a), 0) * at, float(bolt[0]), float(bolt[1]), 10)


## T and cross: a flat deck, curbs along the closed sides (full length), and the curb revolved
## around each block corner between two open sides.
func _cross(geo: TmGeo, arms: Array, ground: bool) -> void:
	var closed := []
	for i in 4:
		closed.append(not arms.has(i))
	var inset := func(i: int) -> float: return SHOULDER if closed[i] else 0.0
	var lo := Vector3(inset.call(1), 1.0 if ground else 0.0, inset.call(2))
	var hi := Vector3(32.0 - inset.call(3), TOP, 32.0 - inset.call(0))
	# the deck: the road on top; underneath on the ground a flat floor (the terrain hides it), in
	# the air TMNF's keel (_junction_keel); the open sides meet the next road's section (collision
	# only)
	geo.quad(Vector3(lo.x, TOP, lo.z), Vector3(lo.x, TOP, hi.z), Vector3(hi.x, TOP, hi.z), Vector3(hi.x, TOP, lo.z), _road_mat, _road_surf)
	if ground:
		geo.quad(Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z), "", S_METAL)
	else:
		_junction_keel(geo, closed)
	var corners := [Vector3(hi.x, 0, hi.z), Vector3(lo.x, 0, hi.z), Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z)]
	for i in 4:
		# side i (SIDES: +z, -x, -z, +x) from corner i to corner i + 1, facing out (on the ground
		# the closed sides' dark border metal under the curbs; in the air the keel's step)
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var mat := "road_metal" if closed[i] and ground else ""
		geo.quad(Vector3(b.x, lo.y, b.z), Vector3(a.x, lo.y, a.z), Vector3(a.x, TOP, a.z), Vector3(b.x, TOP, b.z), mat, S_METAL)
	var curb := _curb_section(ground)
	for i in 4:
		var o: Vector3 = SIDES[i]
		var t := Vector3(o.z, 0.0, -o.x)
		var c := Vector3(16, 0, 16)
		if closed[i]:
			# d measured inward from the edge: lateral = -o, the path along the edge
			geo.wall_sweep(curb, [c + o * 16.0 - t * 16.0, c + o * 16.0 + t * 16.0], [-o, -o], true, "road_metal", S_METAL)
		# the corner at the end of side i (toward +t) between side i and the next side (outward t)
		var j := SIDES.find(t)
		if not closed[i] and not closed[j]:
			var corner := c + o * 16.0 + t * 16.0
			var path := []
			var lat := []
			var steps := 6
			for s in steps + 1:
				var ang := PI * 0.5 * float(s) / steps
				# the radial direction sweeps from -t (toward the corner's side-i neighbour) to -o
				lat.append((-t * cos(ang) - o * sin(ang)).normalized())
				path.append(corner)
			geo.wall_sweep(curb, path, lat, true, "road_metal", S_METAL)
