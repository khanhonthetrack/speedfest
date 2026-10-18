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
const S_ROULETTE := 30
const TOP := 1.345              ## the road surface
const CROWN := 0.19             ## dead ends and the base sink this much toward their noses

## Left half of the cross-section, (x, y) with x across the road (centre 16), from the bottom
## centre round the left curb to the top centre; each point's material is the segment's from it.
## Air: keel underneath. Ground: the curb's outer face runs down to the terrain (1 m).
## Visual keys (textured with HD graphics, TmMaterials.TEXTURED): curb_outer (the curb's outer
## face), curb_top (its rounded top), curb_face (its face towards the road), shoulder (the strip at
## road level), road_lip (the low lip at the road's edge); the surface ids stay TMNF's.
const HALF_AIR := [
	[16.0, 0.0, "structure", S_METAL], [14.339, 0.0, "structure", S_METAL], [9.758, 0.418, "structure", S_METAL],
	[5.177, 0.836, "metal", S_METAL], [5.177, 1.243, "grid", S_METAL], [3.212, 1.243, "metal", S_METAL],
	[2.004, 1.243, "curb_outer", S_RUBBER], [1.712, 1.753, "curb_outer", S_RUBBER],
]
const HALF_GROUND := [
	[16.0, 1.0, "", TmGeo.NO_COLLISION], [1.0, 1.0, "curb_outer", S_METAL], [1.282, 1.851, "curb_outer", S_METAL],
]
## The curb and the road surface, shared by both (air starts at the curb's outer rubber face).
const HALF_TOP_AIR := [[1.419, 2.263, "curb_outer", S_METAL], [1.492, 2.482, "curb_outer", S_METAL]]
const HALF_TOP := [
	[1.565, 2.701, "curb_top", S_METAL], [1.616, 2.739, "curb_top", S_METAL], [1.668, 2.777, "curb_top", S_METAL],
	[1.792, 2.777, "curb_top", S_METAL], [1.834, 2.636, "curb_top", S_METAL], [1.875, 2.495, "curb_top", S_METAL],
	[2.735, 2.495, "curb_top", S_METAL], [2.753, 2.444, "curb_top", S_METAL], [2.770, 2.394, "curb_face", S_RUBBER],
	[2.857, 2.358, "curb_face", S_RUBBER], [2.943, 2.322, "curb_face", S_RUBBER],
	[3.022, 2.269, "curb_face", S_RUBBER], [3.101, 2.216, "curb_face", S_RUBBER],
	[3.166, 2.143, "curb_face", S_RUBBER], [3.231, 2.069, "curb_face", S_RUBBER],
	[3.272, 1.968, "curb_face", S_RUBBER], [3.312, 1.867, "curb_face", S_RUBBER],
	[3.312, 1.606, "curb_face", S_RUBBER], [3.280, 1.475, "curb_face", S_RUBBER],
	[3.248, TOP, "shoulder", S_METAL], [5.177, TOP, "road_lip", S_RUBBER], [5.232, 1.376, "road_lip", S_RUBBER],
	[5.508, 1.361, "road_lip", S_RUBBER], [5.540, TOP, "asphalt", S_ROAD],
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
const LOOP_UNDER := [[3.212, 1.243, "structure", S_METAL], [5.163, 1.243, "structure", S_METAL],
	[14.292, 0.656, "structure", S_METAL], [14.339, 0.0, "structure", S_METAL]]
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
## Turbo booster pods (measured): the outline (z, radius) about the axis at y TURBO_POD_Y (x 2
## and 30), closed on the axis; the fins over them (z, y), TURBO_FIN_HALF either side of the axis.
const TURBO_POD_Y := 4.854
const TURBO_POD := [[7.633, 0.0], [7.633, 1.53], [7.723, 1.78], [8.569, 1.946], [10.152, 1.97], [10.666, 1.72],
	[14.21, 1.72], [14.299, 1.822], [14.403, 1.97], [17.446, 1.97], [17.656, 1.70], [17.656, 0.0]]
## The tray over each pod: its line (z, y), TURBO_FIN_HALF either side of the pod's axis; the side
## panels reach this far below and above it.
const TURBO_FIN_HALF := 0.802
const TURBO_TRAY := [Vector2(8.441, 7.01), Vector2(17.446, 7.01), Vector2(23.611, 2.972), Vector2(25.898, 2.972)]
const TURBO_PANEL := [0.17, 0.916]
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
var _road_surf := S_ROAD
var _gate_kind := "cp"            ## the gate's kind for this shape (TmGateDress.kind_of)
var _curb_mat := "curb_face"      ## the curbs' face towards the road (a gate block's: its word)
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
	if rest in ["Bump/Air", "Bump/Ground", "Bump/SlopeAir", "Bump/TiltAir", "Bump/TiltGround"]:
		return true
	return ARMS.has(_form(rest)) or rest.begins_with("Slope/StraightAir") or rest.begins_with("Slope/StraightGround") \
		or rest.begins_with("GTCurve/") \
		or ((rest.begins_with("Turbo/") or rest.begins_with("TurboRoulette/")) and _form(rest.get_slice("/", 1)) in ["", "Up", "Down", "Left", "Right"]) \
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
	for g in ["Checkpoint/", "MultiLap/", "Finish/", "Start/"]:
		if rest.begins_with(g):
			_curb_mat = "curb_" + _sign_kind()
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
		# on a slope: the flat bump sheared like the slope (0.25, one level down at its foot); tilted:
		# sheared like the tilted straight from level 0 (measured: the same profile on both)
		_bump(geo, ground and not rest.contains("Tilt"))
		if rest.begins_with("Bump/Slope"):
			geo.shear_y(0.0, 0.25, -8.0)
		elif rest.begins_with("Bump/Tilt"):
			var t: Array = TILT_PLANES["Road/Tilt/Straight"]
			geo.shear_y(float(t[1]), float(t[2]), float(t[3]) - 8.0)
	elif ARMS.has(form):
		_junction(geo, form, ground)
	elif rest.begins_with("Slope/") and SLOPES.has(_form(rest.trim_prefix("Slope/"))):
		_profile_slope(geo, SLOPES[_form(rest.trim_prefix("Slope/"))], ground)
	elif rest.begins_with("Slope/Straight"):
		_sweep(geo, [Vector3(16, 0, 0), Vector3(16, 8, 32)], [Vector3(1, 0, 0), Vector3(1, 0, 0)], ground)
	elif rest.begins_with("GTCurve/"):
		var k := int(rest.trim_prefix("GTCurve/").substr(0, 1))
		if k < 2 or k > 5:
			return null
		_curve(geo, k, ground)
	elif rest.begins_with("Turbo/") or rest.begins_with("TurboRoulette/") or rest.begins_with("FreeWheeling/"):
		# the roulette gate is the turbo gate with its own pad (measured: the same 1820 faces)
		_road_mat = "turbo_roulette" if rest.begins_with("TurboRoulette/") else "turbo"
		_road_surf = S_TURBO if rest.begins_with("Turbo/") else (S_ROULETTE if rest.begins_with("TurboRoulette/") else S_FREEWHEEL)
		# Up/Down/Left/Right: the flat pad sheared like the checkpoint of that slope or tilt
		# (measured: the pad's plane), the air section on the ground too
		var dir := _form(rest.get_slice("/", 1))
		_straight(geo, 0.0, 32.0, ground and dir.is_empty())
		_turbo_gate(geo)
		var t: Array = TILT_PLANES.get("Road/Main/Checkpoint" + dir, ["", 0.0, 0.0, 0.0])
		geo.shear_y(float(t[1]), float(t[2]), float(t[3]))
		_turbo_sides(geo, float(t[1]), float(t[2]), float(t[3]))
	elif rest.begins_with("Checkpoint/") or rest.begins_with("MultiLap/"):
		_straight(geo, 0.0, 32.0, ground)
		_gate(geo, 16.0)
	elif rest.begins_with("Finish/"):
		# the road comes in from -z and ends past the line in a nose
		_straight(geo, 0.0, 17.0, ground)
		_nose(geo, 17.0, 1.0, ground, TOP - 0.04)
		_gate(geo, 12.0)
	elif rest.begins_with("Start/"):
		# the road leaves to +z from a nose behind the spawn (z 11.2); the line near the far end
		_straight(geo, 8.0, 32.0, ground)
		_nose(geo, 8.0, -1.0, ground, TOP - 0.04)
		_gate(geo, 28.0)
	else:
		return null
	var node := geo.build()
	for zc: float in _gates:
		TmGateDress.dress(node, _gate_kind, zc, TOP, geo.sheared)
	return node


## The closed cross-section as wall_sweep points: (d = x - 16, y).
func _section(ground: bool) -> Array:
	var left: Array = (HALF_GROUND if ground else HALF_AIR + HALF_TOP_AIR) + HALF_TOP
	var out := []
	for q in left:
		out.append([Vector2(float(q[0]) - 16.0, float(q[1])), String(q[2]), int(q[3])])
	# the right half mirrored, walked back from the top centre to the bottom; a segment keeps the
	# material of its mirrored twin (which starts at the next point of the left half)
	out.append([Vector2(0.0, TOP), _road_mat, _road_surf])
	for i in range(left.size() - 1, 0, -1):
		var q: Array = left[i]
		var prev: Array = left[i - 1]
		out.append([Vector2(16.0 - float(q[0]), float(q[1])), String(prev[2]), int(prev[3])])
	for p in out:
		if p[1] == "asphalt":
			p[1] = _road_mat
			p[2] = _road_surf
		elif p[1] == "curb_face":
			p[1] = _curb_mat
	return out


## The left curb alone (the section up to the asphalt's edge), closed underneath; d = x.
func _curb_section(ground: bool) -> Array:
	var left: Array = (HALF_GROUND.slice(1) if ground else HALF_AIR.slice(5) + HALF_TOP_AIR) + HALF_TOP
	var out := []
	for q in left:
		out.append([Vector2(float(q[0]), float(q[1])), String(q[2]), int(q[3])])
	var bottom := 1.0 if ground else 1.243
	out[out.size() - 1][1] = ""                      # the curb's inner end is internal
	out[out.size() - 1][2] = TmGeo.NO_COLLISION
	out.append([Vector2(ROAD_EDGE, bottom), "" if ground else "metal", TmGeo.NO_COLLISION if ground else S_METAL])
	return out


func _sweep(geo: TmGeo, path: Array, lateral: Array, ground: bool, y_at := Callable(), p_at := Callable()) -> void:
	geo.wall_sweep(_section(ground), path, lateral, true, "metal", S_METAL, y_at, p_at)


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


## The loop's section (d, y) like _section(): the road's curbs, the grid between them, LOOP_UNDER.
func _loop_section() -> Array:
	var half := []
	for q in HALF_AIR.slice(6) + HALF_TOP_AIR + HALF_TOP:
		half.append(q)
		if float(q[0]) >= 3.248 - 0.001 and float(q[1]) <= TOP + 0.001:
			break         # the curb's inner foot: the grid starts here
	var out := []
	for q in half:
		out.append([Vector2(float(q[0]) - 16.0, float(q[1])), String(q[2]), int(q[3])])
	for i in range(half.size() - 1, -1, -1):
		var q: Array = half[i]
		var prev: Array = half[i - 1] if i > 0 else LOOP_UNDER[0]
		out.append([Vector2(16.0 - float(q[0]), float(q[1])), String(prev[2]), int(prev[3])])
	# the underside: from the right curb's foot in to the centre, then out to the left curb's
	for q in LOOP_UNDER:
		out.append([Vector2(16.0 - float(q[0]), float(q[1])), String(q[2]), int(q[3])])
	for i in range(LOOP_UNDER.size() - 1, -1, -1):
		var q: Array = LOOP_UNDER[i]
		out.append([Vector2(float(q[0]) - 16.0, float(q[1])), String(q[2]), int(q[3])])
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
	geo.wall_sweep(sec, path, lat, true, "metal", S_METAL, Callable(), p_at)
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
				true, "metal", S_METAL)
	var top := 8.0
	if variant == "Slope":
		geo.shear_y(0.0, 0.25, 0.0)
		top = 16.0
	elif variant == "Tilt":
		geo.shear_y(TILT, 0.0, -0.038)
		top = 16.0
	if pillars:
		for c: Vector2 in HOLE_PILLARS[_hole_form(rest)]:
			geo.pipe(Vector3(c.x, 0, c.y), Vector3(c.x, top, c.y), PILLAR_R, 24, "structure", S_ROAD)


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
		var mat := "metal"
		var surf := S_METAL
		for k in sec.size():
			var p: Vector2 = sec[k][0]
			var q: Vector2 = sec[(k + 1) % sec.size()][0]
			if Geometry2D.get_closest_point_to_segment(a, p, q).distance_to(a) < 0.002 \
					and Geometry2D.get_closest_point_to_segment(b, p, q).distance_to(b) < 0.002:
				mat = sec[k][1]
				surf = sec[k][2]
				break
		out.append([a, mat, surf])
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
			return [Vector2((p.x - 16.0) * side, p.y), q[1], q[2]])
		geo.wall_sweep(sec, [Vector3(16, 8, 0), Vector3(16, 8, 32)], [Vector3(1, 0, 0), Vector3(1, 0, 0)], true, "metal", S_METAL)
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
	var y_at := Callable()
	if ground:
		y_at = func(y: float, i: int) -> float: return 1.0 - (path[i] as Vector3).y if y <= 1.001 else y
	_sweep(geo, path, lat, ground, y_at)


## The road (asphalt and curbs) swept along z through measured surface heights (evenly spaced over
## the block), its underside cut off at floor_y where it rises off a platform deck; mat: the
## surface's material (the platform's own where the ramp is part of a platform block).
func ramp(geo: TmGeo, heights: Array, floor_y: float, mat := "asphalt") -> void:
	_road_mat = mat
	var path := []
	var lat := []
	for i in heights.size():
		path.append(Vector3(16, float(heights[i]) - TOP, 32.0 * i / (heights.size() - 1)))
		lat.append(Vector3(1, 0, 0))
	var y_at := func(y: float, i: int) -> float: return maxf(y, floor_y - (path[i] as Vector3).y)
	_sweep(geo, path, lat, false, y_at)
	_road_mat = "asphalt"


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
	geo.wall_sweep(curb, path, lat, true, "metal", S_METAL)


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
	geo.wall_sweep(curb, path, lat, true, "metal", S_METAL)


func _straight(geo: TmGeo, z0: float, z1: float, ground: bool) -> void:
	_sweep(geo, [Vector3(16, 0, z0), Vector3(16, 0, z1)], [Vector3(1, 0, 0), Vector3(1, 0, 0)], ground)


## A road end's low nose beyond z0 (toward dir): a thin plate 2.3 m long under the curbs' ends.
func _nose(geo: TmGeo, z0: float, dir: float, ground: bool, top := TOP - CROWN - 0.04) -> void:
	var z1 := z0 + dir * 2.3
	var y0 := 1.0 if ground else 1.05
	geo.box(Vector3(1.05, y0, minf(z0, z1)), Vector3(30.95, top, maxf(z0, z1)), "structure", S_METAL,
		"metal", S_METAL)


## Checkpoint / finish / multilap / start gate centred at z: TMNF's arch (its measured section)
## swept 4.2 m along the road, its front and back faces a moulded rubber band with the gate's word
## running along the arch ("gate_<kind>", UVs along the arch), its underside lit in the gate's
## colour, light rigs on its shoulders aimed at the road. TMNF's two sign boards on top are left
## out (the review's gate option B: they read as horns); TmGateDress adds an LED screen in the
## crown instead (TmGateScreen), and paints the road (start/finish pads, the checkpoint line).
func _gate(geo: TmGeo, zc: float) -> void:
	_gates.append(zc)
	var sec := GATE_ARCH.map(func(q: Array) -> Array: return [Vector2(q[0], q[1]), "gate_shell", q[3]])
	geo.wall_sweep(sec, [Vector3(0, 0, zc - 2.1), Vector3(0, 0, zc + 2.1)], [Vector3(1, 0, 0), Vector3(1, 0, 0)],
		false, "gate_shell", S_METAL)
	_gate_faces(geo, zc)
	_gate_strips(geo, zc)
	for x0 in [2.9, 27.7]:
		geo.box(Vector3(x0, 2.5, zc - 1.4), Vector3(x0 + 1.4, 4.4, zc + 1.4), "gate_shell", S_METAL, "", -2, 0.06)
	_gate_lights(geo, zc)


## The word a gate block shows: a start/finish line (MultiLap) ends our races, so it says FINISH.
func _sign_kind() -> String:
	return "finish" if _gate_kind == "lap" else _gate_kind


## Lit strips along the arch's underside at its front and back edges, in the gate's colour.
func _gate_strips(geo: TmGeo, zc: float) -> void:
	var inner: Array = _arch_lines()[1]
	var key := "gate_glow_" + _gate_kind
	for zz: Array in [[zc - 2.1, zc - 1.92], [zc + 1.92, zc + 2.1]]:
		for i in inner.size() - 1:
			var p: Vector2 = inner[i]
			var q: Vector2 = inner[i + 1]
			var d := (q - p).normalized()
			var n := Vector2(-d.y, d.x)
			if n.dot(Vector2(16.0, 0.0) - p) < 0.0:
				n = -n
			var o := n * 0.006
			var a := Vector3(p.x + o.x, p.y + o.y, float(zz[0]))
			var b := Vector3(q.x + o.x, q.y + o.y, float(zz[0]))
			var c := Vector3(q.x + o.x, q.y + o.y, float(zz[1]))
			var e := Vector3(p.x + o.x, p.y + o.y, float(zz[1]))
			var nrm := Vector3(n.x, n.y, 0.0)
			if (b - a).cross(c - a).dot(nrm) < 0.0:
				geo.quad(a, e, c, b, key, TmGeo.NO_COLLISION)
			else:
				geo.quad(a, b, c, e, key, TmGeo.NO_COLLISION)


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
	var fit := maxf(1.0, roundf(length / TmGeo.UV_TILE)) * TmGeo.UV_TILE / length
	var key := "gate_" + _sign_kind()
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


## The turbo gate's sides, over each curb: a booster pod (a collar round the fan, a slimmer body
## through the frame, a cap behind it) and on it a grid tray between two thin translucent panels,
## level over the pod and the frame, then down to the curb. On a road sheared by (kx, kz, dy) each
## side keeps its shape: lifted with the road at its axis, sheared only along the slope, the tray's
## level part never dipping toward the front (measured on the sloped and tilted pads).
func _turbo_sides(geo: TmGeo, kx := 0.0, kz := 0.0, dy := 0.0) -> void:
	var pod := TURBO_POD.map(func(q: Array) -> Array: return [q[0], q[1], "structure", 22])
	for x: float in [2.0, 30.0]:
		var side := TmGeo.new()
		var lift := kx * x + dy
		side.revolve_z(pod, Vector2(x, TURBO_POD_Y + lift), 0.0, 360.0, 36, false)
		var tray := []
		for q: Vector2 in TURBO_TRAY:
			tray.append(Vector2(q.x, q.y + lift))
		tray[0].y += maxf(0.0, kz * (tray[1].x - tray[0].x))
		var x0 := x - TURBO_FIN_HALF
		var x1 := x + TURBO_FIN_HALF
		var lo: float = TURBO_PANEL[0]
		var hi: float = TURBO_PANEL[1]
		for i in tray.size() - 1:
			var a: Vector2 = tray[i]
			var b: Vector2 = tray[i + 1]
			side.quad(Vector3(x0, a.y, a.x), Vector3(x0, b.y, b.x), Vector3(x1, b.y, b.x), Vector3(x1, a.y, a.x), "grid", S_METAL)
			for px: float in [x0, x1]:
				side.quad(Vector3(px, a.y - lo, a.x), Vector3(px, b.y - lo, b.x), Vector3(px, b.y + hi, b.x),
					Vector3(px, a.y + hi, a.x), "glass", S_METAL)
		var f: Vector2 = tray[0]
		var e: Vector2 = tray[tray.size() - 1]
		side.quad(Vector3(x0, f.y - lo, f.x), Vector3(x0, f.y + hi, f.x), Vector3(x1, f.y + hi, f.x),
			Vector3(x1, f.y - lo, f.x), "glass", S_METAL)
		side.quad(Vector3(x0, e.y - lo, e.x), Vector3(x0, e.y, e.x), Vector3(x1, e.y, e.x), Vector3(x1, e.y - lo, e.x),
			"glass", S_METAL)
		side.shear_y(0.0, kz, 0.0)
		geo.merge(side)


## T and cross: a flat deck, curbs along the closed sides (full length), and the curb revolved
## around each block corner between two open sides.
func _cross(geo: TmGeo, arms: Array, ground: bool) -> void:
	var closed := []
	for i in 4:
		closed.append(not arms.has(i))
	var inset := func(i: int) -> float: return SHOULDER if closed[i] else 0.0
	var lo := Vector3(inset.call(1), 1.0 if ground else 0.0, inset.call(2))
	var hi := Vector3(32.0 - inset.call(3), TOP, 32.0 - inset.call(0))
	geo.box(lo, hi, "structure", S_METAL, _road_mat, _road_surf)
	var curb := _curb_section(ground)
	for i in 4:
		var o: Vector3 = SIDES[i]
		var t := Vector3(o.z, 0.0, -o.x)
		var c := Vector3(16, 0, 16)
		if closed[i]:
			# d measured inward from the edge: lateral = -o, the path along the edge
			geo.wall_sweep(curb, [c + o * 16.0 - t * 16.0, c + o * 16.0 + t * 16.0], [-o, -o], true, "metal", S_METAL)
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
			geo.wall_sweep(curb, path, lat, true, "metal", S_METAL)
