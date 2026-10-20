extends RefCounted
## Stadium "Platform" blocks: the raised decks (top at 8 m, a slab down to 1 m whose sides that
## don't continue into a neighbour end in a rounded lip over a fabric skirt), the turbo deck (a
## thin plate over a fan housing), the checkpoint arch, and the grid walls that stand on the decks'
## edges. Our own geometry from measured numbers (TMNF block-local metres: x right, y up, z
## forward; see TmGeo; sections from tools/research/tmnf/section_loop.py).
##
## A road-type deck's shape index (0 base, 1 dead end, 2 corner, 3 straight, 4 T, 5 cross) sets
## the sides it continues through, as for the tubes: the dead end opens to +z, the corner to +z and
## -x, the straight to +z and -z, the T adds -x.

const RoadShapes := preload("res://blocks/shapes/road.gd")

const S_DECK := 16              # StadiumPlatform (TmTuning.Surface.ASPHALT)
const S_METAL := 4
const S_TURBO := 7
const S_SLIDING := 10           # the fabric skirt (SlidingRubber)
const S_SIGNS := 9
const TOP := 8.0
const UNDER := 7.325            ## the deck plate's underside
const BOTTOM := 1.0
const INSET := 3.3              ## the lip's depth into the deck; the slab's body starts behind it

## Lip of a side that doesn't continue: (d inward from the edge, y), closed loop.
## As TMNF's: the rim is bands of the border atlas (rows at the segment's ends, from TMNF's UVs:
## the ribbed edge, the black underside with the blue line), the flat underside and the foot
## ledge TMNF's light plates, the skirt its white fabric.
const LIP := [
	[INSET, TOP, "platform", S_DECK], [0.0, TOP, "border_ribs", S_METAL, Vector2(150.0, 162.4)],
	[0.0, 7.9, "border_ribs", S_METAL, Vector2(162.4, 177.5)], [0.122, 7.9, "border_ribs", S_METAL, Vector2(177.5, 216.7)],
	[0.249, 7.611, "border_black", S_METAL, Vector2(216.7, 256.1)], [0.505, 7.423, "border_black", S_METAL, Vector2(256.1, 300.0)],
	[0.847, UNDER, "road_under", S_METAL], [3.085, UNDER, "fabric", S_SLIDING], [2.835, 7.15, "fabric", S_SLIDING],
	[2.695, 6.795, "fabric", S_SLIDING], [2.635, 4.298, "fabric", S_SLIDING], [2.695, 1.836, "fabric", S_SLIDING],
	[2.835, 1.444, "fabric", S_SLIDING], [3.133, 1.207, "road_under", S_METAL], [2.802, 1.207, "road_under", S_METAL],
	[2.802, BOTTOM, "road_under", S_METAL], [INSET, BOTTOM, "", TmGeo.NO_COLLISION],
]
## Under the deck (measured): TMNF's dark plate at the body's floor (PLATE_IN in from each closed
## side, to the edge on open ones), a hub hanging from its centre (in HUB[0] from the block's edges
## at the floor, HUB[1] at the level's ground), and beams 1 m deep, BEAM_HALF either side of the
## column lines (COLUMNS, both ways): from each column of a closed side in to the square the
## lines make (its outer end BEAM_END, (d, y)), and along each side of that square whose block
## edge is open. On each closed side two truss columns (centred COLUMNS along it, COLUMN_W wide;
## TMNF's dark open frames, cut-out truss cards)
## slant from the beam's end up under the rim.
const PLATE_IN := 2.802
const HUB := [10.0, 12.0]
const BEAM_HALF := 0.73
const BEAM_END := [Vector2(2.0, 0.0), Vector2(1.61, 0.6), Vector2(2.8, BOTTOM)]
const COLUMNS := [8.0, 24.0]
const COLUMN_W := 1.0
const COLUMN_FOOT := [Vector2(1.73, 0.64), Vector2(2.8, 1.0)]       ## (d, y) its two bottom edges (on the beam's end)
const COLUMN_HEAD := [Vector2(0.17, 7.09), Vector2(0.72, 7.29)]     ## and top edges (under the rim)
const COLUMN_PANELS := 3.0                                           ## its frame's diagonal panels
## The turbo plate's rounded edge (every side) and the strip of plate behind it to TURBO_PLATE_IN:
## its edge the border atlas' ribs, the bevel TMNF's TURBO sign (ours: texgen/turbo.py turbo_rim, v
## across the bevel as rows of 512; mirrored, as TMNF's reads from outside), the underside TMNF's
## light plates (the slab beyond is dark).
const TURBO_PLATE_IN := 3.08
const PLATE_LIP := [
	[TURBO_PLATE_IN, TOP, "turbo", S_TURBO], [0.0, TOP, "border_ribs", S_METAL, Vector2(161.5, 191.9)],
	[0.0, 7.9, "border_ribs", S_METAL, Vector2(191.9, 200.0)], [0.122, 7.9, "turbo_rim_out", S_SIGNS, Vector2(0.0, 163.4)],
	[0.249, 7.611, "turbo_rim_out", S_SIGNS, Vector2(163.4, 370.2)], [0.505, 7.423, "turbo_rim_out", S_SIGNS, Vector2(370.2, 512.0)],
	[0.847, UNDER, "road_under", S_METAL], [TURBO_PLATE_IN, UNDER, "", TmGeo.NO_COLLISION],
]
## The turbo deck's advert bands (TMNF's Pub8x1B, measured): their bottom and top edges' distance
## from the centre line (x), heights, and z extent.
const TURBO_PUB := [12.5, 12.68, 6.46, 7.32, 3.32, 28.68]
## The turbo deck's floor under the plate (measured): its edge (d, y) at the deck's foot, the
## border atlas' orange band facing out, the light floor from TURBO_FLOOR_IN in at FLOOR_Y.
const FLOOR_Y := 1.207
const TURBO_FLOOR_IN := 3.3
const TURBO_FLOOR := [
	[TURBO_FLOOR_IN, FLOOR_Y, "road_under", S_DECK], [2.802, FLOOR_Y, "border_orange", S_METAL, Vector2(297.9, 366.8)],
	[2.802, BOTTOM, "", TmGeo.NO_COLLISION], [TURBO_FLOOR_IN, BOTTOM, "", TmGeo.NO_COLLISION],
]
## Its four jet turbines (measured): axes along z at TURBINE_X x TURBINE_Y, intakes at TURBINE_Z
## facing -z; the outline (z from the intake, radius, key of the segment from it) round to the
## fan's plane; hung from a cross beam (TURBINE_BEAM: z from the intake, x across, bottom y) on
## a pylon.
const TURBINE_X := [5.44, 26.56]
const TURBINE_Y := 3.39
const TURBINE_Z := [2.52, 18.52]
const TURBINE := [
	[0.0, 1.52, "road_under"], [-0.5, 1.6, "road_under"], [-0.4, 1.86, "road_under"], [0.3, 1.97, "road_under"],
	[3.0, 1.97, "platform_tray"], [3.4, 1.72, "platform_tray"], [5.2, 1.72, "platform_tray"], [5.5, 2.0, "road_metal"],
	[9.0, 2.0, "platform_tray"], [9.4, 1.79, "platform_tray"], [10.0, 1.79, "road_metal"], [10.0, 0.0, "road_metal"],
	[0.0, 0.0, "road_grid"],
]
const TURBINE_BEAM := [Vector2(5.5, 9.0), Vector2(3.92, 28.08), 6.1]

const SIDES := [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)]
const ARMS := {
	"Base": [], "Deadend": [0], "Corner": [0, 1], "Straight": [0, 2], "TShaped": [0, 2, 1], "Cross": [0, 1, 2, 3],
}

const WALL_PLAN := [
	[8.000, 1.345, "grid", 4], [1.000, 1.345, "wall", 16], [0.000, 1.345, "metal", 4],
	[0.000, 1.215, "metal", 4], [0.084, 1.100, "metal", 4], [0.203, 1.018, "metal", 4],
	[0.333, 1.000, "metal", 4], [0.333, 0.510, "metal", 4], [0.667, 0.510, "metal", 4],
	[0.667, 1.000, "metal", 4], [1.000, 1.000, "grid", 4], [8.000, 1.000, "metal", 4],
	[8.333, 1.000, "metal", 4], [8.333, 0.510, "metal", 4], [8.667, 0.510, "metal", 4],
	[8.667, 1.000, "structure", 4], [13.100, 1.000, "metal", 4], [13.255, 0.687, "metal", 4],
	[13.579, 0.478, "metal", 4], [13.996, 0.410, "metal", 4], [14.437, 0.401, "metal", 4],
	[14.795, 0.851, "metal", 4], [17.205, 0.851, "metal", 4], [17.563, 0.401, "metal", 4],
	[18.004, 0.410, "metal", 4], [18.421, 0.478, "metal", 4], [18.745, 0.687, "metal", 4],
	[18.900, 1.000, "structure", 4], [23.333, 1.000, "metal", 4], [23.333, 0.510, "metal", 4],
	[23.667, 0.510, "metal", 4], [23.667, 1.000, "metal", 4], [24.000, 1.000, "grid", 4],
	[31.000, 1.000, "metal", 4], [31.333, 1.000, "metal", 4], [31.333, 0.510, "metal", 4],
	[31.667, 0.510, "metal", 4], [31.667, 1.000, "metal", 4], [31.797, 1.018, "metal", 4],
	[31.916, 1.100, "metal", 4], [32.000, 1.215, "metal", 4], [32.000, 1.345, "wall", 16],
	[31.000, 1.345, "grid", 4], [24.000, 1.345, "platform_wall", 16]
]
## The platform checkpoint (TMNF's, measured): the road's gate (RoadShapes._gate: arch, feet,
## light rigs) CP_GATE_SCALE wider about the centre line and CP_GATE_DY higher, on the deck; under
## its feet each x side's edge set back along CP_NOTCH_Z (CP_NOTCH: a dark strip along the top
## behind an orange band, a steeper bevel, the dark plate under it; then the lip's from its
## underside on); elsewhere the rim's bevel the CHECKPOINT sign (CP_RIM_ROWS: the sign's rows on
## its three segments; mirrored, as TMNF's reads from outside).
const CP_GATE_SCALE := 1.089
const CP_GATE_DY := 5.52
const CP_NOTCH_Z := Vector2(12.0, 20.0)
const CP_NOTCH := [
	[INSET, TOP, "platform", S_DECK], [2.16, TOP, "border_orange", S_METAL, Vector2(298.0, 366.0)],
	[2.0, TOP, "platform_tray", S_DECK], [0.49, TOP, "border_ribs", S_METAL, Vector2(161.0, 192.0)],
	[0.49, 7.9, "border_ribs", S_METAL, Vector2(192.0, 216.0)], [1.22, UNDER, "platform_tray", S_METAL],
]
const CP_RIM_ROWS := [Vector2(0.0, 157.0), Vector2(157.0, 367.5), Vector2(367.5, 512.0)]
## The arch's outer line (the circle it lies on: centre (x, y), radius) the billboard's fall follows.
const ARCH_CENTRE := Vector2(16, -8.976)
const ARCH_OUTER_R := 23.302
## The billboard: a band leaning in over the arch, curved in plan about a vertical axis at
## ARCH_BOARD_AXIS (x, z); its section (radius from the axis, y) at the top, its half-angle, and
## how much of the arch's fall toward its ends it follows (measured: its ends at x 5.94 / 26.06,
## 2.0 m lower and 2.8 m nearer the front than its middle).
const ARCH_BOARD_AXIS := Vector2(16, -0.35)
const ARCH_BOARD := [[18.90, 15.53, "screen", S_METAL], [17.37, 17.65, "screen", S_METAL],
	[17.53, 17.76, "screen", S_METAL], [19.06, 15.64, "screen", S_METAL]]
const ARCH_BOARD_HALF := 32.2
const ARCH_BOARD_FALL := 0.91
## The curved strut from the deck's front corner up to the arch (centre line, measured), mirrored.
const ARCH_STRUT := [Vector3(0.97, 7.8, 5.9), Vector3(1.08, 9.6, 8.2), Vector3(1.27, 10.2, 9.0), Vector3(1.55, 10.8, 9.8),
	Vector3(1.9, 11.4, 10.6), Vector3(2.34, 11.9, 11.4), Vector3(2.85, 12.5, 12.1), Vector3(3.44, 13.0, 12.85),
	Vector3(4.1, 13.5, 13.5)]

## Curved grid walls: GT curve size -> frame segments round the quarter circle (measured).
const CURVE_WALL_SEGMENTS := {"2": 2, "3": 4}

## Platform to Road/Main ramp: the road's surface heights every 2 m from the deck (z 0) up to the
## road block's level (z 32).
const TO_ROAD_MAIN := [8.0, 8.008, 8.017, 8.071, 8.125, 8.248, 8.372, 8.522, 8.672, 8.85, 9.028, 9.137,
	9.247, 9.289, 9.331, 9.338, 9.345]

## Platform slopes: a thin plate with a lip on every edge, sheared through the slope's surface
## heights (every 2 m along z); its section across (x, y) at a top of 8 m, and the underside's rise
## into the end lips (z from the end, y), measured. As TMNF's: the rim the deck lip's atlas bands
## (rows as LIP's; the right half walked back, its rows reversed), the underside's ledges its light
## plates, the panel between them its dark Stands2.
const SLOPE_PLATE := [
	[0.0, TOP, "border_ribs", S_METAL, Vector2(150.0, 162.4)], [0.0, 7.9, "border_ribs", S_METAL, Vector2(162.4, 177.5)],
	[0.122, 7.9, "border_ribs", S_METAL, Vector2(177.5, 216.7)], [0.249, 7.611, "border_black", S_METAL, Vector2(216.7, 256.1)],
	[0.505, 7.423, "border_black", S_METAL, Vector2(256.1, 300.0)], [0.847, UNDER, "road_under", S_METAL],
	[3.08, UNDER, "road_under", S_METAL], [3.08, 7.12, "platform_tray", S_METAL], [28.92, 7.12, "road_under", S_METAL],
	[28.92, UNDER, "road_under", S_METAL], [31.153, UNDER, "border_black", S_METAL, Vector2(300.0, 256.1)],
	[31.495, 7.423, "border_black", S_METAL, Vector2(256.1, 216.7)], [31.751, 7.611, "border_ribs", S_METAL, Vector2(216.7, 177.5)],
	[31.878, 7.9, "border_ribs", S_METAL, Vector2(177.5, 162.4)], [32.0, 7.9, "border_ribs", S_METAL, Vector2(162.4, 150.0)],
	[32.0, TOP, "platform", S_DECK],
]
## Under a slope (measured, TMNF's Stands2 and its trusses): a round post (SLOPE_POST: radius,
## sides) from the level's ground up to the plate's middle, and from it a cross of struts
## SLOPE_BEAM_HALF wide, reaching SLOPE_BEAM_LEN either way and slanting down away from it (their
## top's and bottom's depth below the plate: [top at the centre, at the end, bottom at the centre,
## at the end], across x and along z); from each strut's end a truss (SLOPE_TRUSS: half width,
## height) slants up to under the rim at SLOPE_TRUSS_RIM.
const SLOPE_POST := [1.64, 16]
const SLOPE_BEAM_HALF := 0.9
const SLOPE_BEAM_LEN := 7.86
const SLOPE_STRUT_X := [0.0, 1.83, 1.23, 3.04]
const SLOPE_STRUT_Z := [0.27, 1.47, 1.54, 2.67]
const SLOPE_TRUSS := Vector2(0.49, 0.9)
const SLOPE_TRUSS_RIM := 1.58
const SLOPE_END := [[0.0, 7.9], [0.122, 7.9], [0.249, 7.611], [0.505, 7.423], [0.847, UNDER], [3.07, UNDER], [3.09, 7.12]]
const SLOPES := {
	"2StraightAir": [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0],
	"BiSlope2StartAir": [8.0, 8.0, 8.0, 8.092, 8.269, 8.521, 8.854, 9.268, 9.743, 10.271, 10.86, 11.52, 12.243,
		13.045, 13.941, 14.926, 16.0],
	"BiSlope2EndAir": [0.0, 0.99, 1.919, 2.776, 3.561, 4.279, 4.932, 5.519, 6.049, 6.53, 6.953, 7.306, 7.591,
		7.805, 7.931, 7.971, 8.0],
}
## Checkpoints and turbo decks on slopes and banks: the flat piece sheared, (kx, kz, dy) of
## TmGeo.shear_y (measured: the deck's top plane).
const CHECKPOINT_SHEAR := {
	"UpAir": [0.0, 0.5, 0.0], "DownAir": [0.0, -0.5, 16.0], "LeftAir": [-0.5, 0.0, 16.0], "RightAir": [0.5, 0.0, 0.0],
}

## Vertical checkpoint ring about (16, 16) in the x-y plane: the ring's section (z, radius) with
## rounded sign faces front and back; four 76-degree arcs between the diagonals.
## As TMNF's: its outer and inner faces the border atlas' light panel (rows across them: RING_ROWS),
## the rounded front and back faces the CHECKPOINT band (gate_cp, along the ring), the bevels the
## ribbed edge (_ring_uv).
const RING_SECTION := [
	[18.2, 13.954, "border_panel", S_METAL], [14.011, 13.954, "border_ribs", S_METAL],
	[13.976, 13.852, "gate_cp", S_METAL], [13.59, 13.555, "gate_cp", S_METAL], [13.48, 13.258, "gate_cp", S_METAL],
	[13.59, 12.961, "gate_cp", S_METAL], [13.976, 12.664, "border_ribs", S_METAL],
	[14.011, 12.563, "border_panel", S_METAL], [18.2, 12.563, "border_ribs", S_METAL],
	[18.235, 12.664, "gate_cp", S_METAL], [18.621, 12.961, "gate_cp", S_METAL], [18.731, 13.258, "gate_cp", S_METAL],
	[18.621, 13.555, "gate_cp", S_METAL], [18.235, 13.852, "border_ribs", S_METAL],
]
const RING_ROWS := Vector2(140.0, 6.0)
const RING_RIB_ROW := 210.0
const RING_ARC := 38.0          ## each arc spans +-38 degrees about an axis direction
## The billboard bands leaning out of the ring's front face over each diagonal (17-73 degrees).
const RING_PANEL := [[13.35, 16.39, "screen", S_METAL], [14.52, 14.365, "screen", S_METAL],
	[14.52, 14.125, "screen", S_METAL], [13.35, 16.15, "screen", S_METAL]]

## Loops: the riding surface's radius, and the plan's depth outside it (the fins).
const LOOP_R := 30.705
const LOOP_OUT := 32.05


func handles(shape: String) -> bool:
	return shape.begins_with("Platform/Road/") or shape.begins_with("Platform/Wall/") \
		or shape == "Platform/Turbo/Air" or shape == "Platform/Checkpoint/Air" \
		or (shape.begins_with("Platform/Turbo/") and CHECKPOINT_SHEAR.has(shape.trim_prefix("Platform/Turbo/"))) \
		or (shape.begins_with("Platform/Slope/") and SLOPES.has(shape.trim_prefix("Platform/Slope/"))) \
		or (shape.begins_with("Platform/Checkpoint/") and CHECKPOINT_SHEAR.has(shape.trim_prefix("Platform/Checkpoint/"))) \
		or shape == "Platform/Checkpoint/RingVAir" or shape.begins_with("Platform/ToRoad/") \
		or (shape.begins_with("Platform/GTCurve/") and CURVE_WALL_SEGMENTS.has(shape.substr(17, 1))) \
		or shape in ["Platform/Loop/StartAir", "Platform/Loop/StartGround", "Platform/Loop/EndAir"]


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var parts := shape.split("/")
	var geo := TmGeo.new()
	match parts[1]:
		"Road":
			var form := parts[2].trim_suffix("Air")
			if not ARMS.has(form):
				return null
			_deck(geo, _closed(ARMS[form]))
		"Loop":
			# a quarter of a loop in the y-z plane, riding on the inside: the start rises from the
			# road (at the +z edge) to vertical at the -z edge, the end (stacked 4 levels above,
			# sharing the centre) carries on to the ceiling at the +z edge
			if parts[2].begins_with("Start"):
				_loop(geo, Vector2(32, 32), PI * 1.5, PI)
			else:
				_loop(geo, Vector2(0, 32), PI, PI * 0.5)
		"GTCurve":
			# "2Wall1Air": a grid wall k blocks round the curve, `units` levels high
			var k := int(parts[2].substr(0, 1))
			var units := int(parts[2].trim_suffix("Air").substr(5))
			if units < 1:
				return null
			_curve_wall(geo, k, units)
		"Turbo":
			_turbo(geo)
			if CHECKPOINT_SHEAR.has(parts[2]):
				var k: Array = CHECKPOINT_SHEAR[parts[2]]
				geo.shear_y(k[0], k[1], k[2])
		"Checkpoint":
			if parts[2] == "RingVAir":
				_ring_v(geo)
			else:
				_checkpoint_deck(geo)
				_checkpoint_arch(geo)
				if CHECKPOINT_SHEAR.has(parts[2]):
					var k: Array = CHECKPOINT_SHEAR[parts[2]]
					geo.shear_y(k[0], k[1], k[2])
		"Slope":
			_slope(geo, SLOPES[parts[2]])
		"ToRoad":
			var form := parts[2]
			if form == "ToRoadMainAir":
				# the deck, and the road rising off it to the Road/Main block above (one level up)
				_deck(geo, _closed([0, 2]))
				RoadShapes.new().ramp(geo, TO_ROAD_MAIN, TOP, "platform")
			elif form in ["Air", "Ground", "2Air", "2Ground", "2MirrorAir", "2MirrorGround"]:
				RoadShapes.new().to_platform(geo, 2 if form.begins_with("2") else 1, form.ends_with("Ground"),
					form.contains("Mirror"))
			else:
				return null
		"Wall":
			match parts[2]:
				"BorderAir":
					_border_wall(geo)
				"1Air":
					_grid_wall(geo, 1, false)
				"2Air":
					_grid_wall(geo, 2, false)
				"4Air":
					_grid_wall(geo, 4, false)
				"2PubAir":
					_grid_wall(geo, 2, true)
				_:
					return null
		_:
			return null
	return geo.build()


## Which of the four sides (SIDES order) don't continue, given the shape's arms.
static func _closed(arms: Array) -> Array:
	var c := []
	for i in 4:
		c.append(not arms.has(i))
	return c


## The deck slab: a lip along every closed side (mitred where two meet, square to the block edge
## where the next side continues), the body behind them from the floor (1 m) to the top (8 m).
func _deck(geo: TmGeo, closed: Array) -> void:
	for i in 4:
		if closed[i]:
			_edge_sweep(geo, LIP, i, closed)
	_deck_body(geo, closed)


## The checkpoint's deck (CP_*): closed all round, its rim the CHECKPOINT sign but under the gate's
## feet, where the x sides' edge is set back.
func _checkpoint_deck(geo: TmGeo) -> void:
	var all := [true, true, true, true]
	var rim := LIP.duplicate(true)
	for k in 3:
		var q: Array = rim[3 + k]
		rim[3 + k] = [q[0], q[1], "curb_cp_out", S_SIGNS, CP_RIM_ROWS[k]]
	var notch: Array = CP_NOTCH + LIP.slice(7)
	for i in 4:
		if i == 1 or i == 3:
			_edge_sweep(geo, rim, i, all, false, 0.0, CP_NOTCH_Z.x)
			_edge_sweep(geo, notch, i, all, false, CP_NOTCH_Z.x, CP_NOTCH_Z.y)
			_edge_sweep(geo, rim, i, all, false, CP_NOTCH_Z.y, 32.0)
		else:
			_edge_sweep(geo, rim, i, all)
	_deck_body(geo, all)


## The deck's body behind its lips (inset on closed sides) and its underside.
func _deck_body(geo: TmGeo, closed: Array) -> void:
	var inset := func(i: int) -> float: return INSET if closed[i] else 0.0
	var lo := Vector3(inset.call(1), BOTTOM, inset.call(2))
	var hi := Vector3(32.0 - inset.call(3), TOP, 32.0 - inset.call(0))
	_body(geo, lo, hi, closed)
	_underside(geo, closed)


## TMNF's plate, hub and beams under the body and the truss columns on the closed sides.
func _underside(geo: TmGeo, closed: Array) -> void:
	var y_plate := BOTTOM - 0.01
	var e := func(i: int) -> float: return PLATE_IN if closed[i] else 0.0
	_out_quad(geo, Vector3(e.call(1), y_plate, e.call(2)), Vector3(32.0 - e.call(3), y_plate, e.call(2)),
		Vector3(32.0 - e.call(3), y_plate, 32.0 - e.call(0)), Vector3(e.call(1), y_plate, 32.0 - e.call(0)), Vector3.DOWN)
	# the hub: a frustum from the plate down to the ground
	var a0: float = HUB[0]
	var a1: float = HUB[1]
	var up := [Vector3(a0, y_plate, a0), Vector3(32.0 - a0, y_plate, a0), Vector3(32.0 - a0, y_plate, 32.0 - a0), Vector3(a0, y_plate, 32.0 - a0)]
	var dn := [Vector3(a1, 0.0, a1), Vector3(32.0 - a1, 0.0, a1), Vector3(32.0 - a1, 0.0, 32.0 - a1), Vector3(a1, 0.0, 32.0 - a1)]
	_out_quad(geo, dn[0], dn[1], dn[2], dn[3], Vector3.DOWN)
	for k in 4:
		var k1 := (k + 1) % 4
		var mid: Vector3 = (dn[k] + dn[k1]) * 0.5 - Vector3(16, 0, 16)
		_out_quad(geo, dn[k], dn[k1], up[k1], up[k], mid.normalized() + Vector3.DOWN)
	for i in 4:
		var o: Vector3 = SIDES[i]
		var t := Vector3(o.z, 0.0, -o.x)
		var edge := Vector3(16, 0, 16) + o * 16.0
		# (d in from side i, y, s along it) -> block coordinates
		var at := func(d: float, y: float, s: float) -> Vector3: return edge - o * d + Vector3(0, y, 0) + t * (s - 16.0)
		if closed[i]:
			for c: float in COLUMNS:
				var prof := BEAM_END + [Vector2(c + BEAM_HALF, BOTTOM), Vector2(c + BEAM_HALF, 0.0)]
				_beam(geo, at, prof, c - BEAM_HALF, c + BEAM_HALF)
		else:
			var c0: float = COLUMNS[0]
			var c1: float = COLUMNS[1]
			var prof := [Vector2(c0 - BEAM_HALF, 0.0), Vector2(c0 - BEAM_HALF, BOTTOM), Vector2(c0 + BEAM_HALF, BOTTOM),
				Vector2(c0 + BEAM_HALF, 0.0)]
			_beam(geo, at, prof, c0 - BEAM_HALF, c1 + BEAM_HALF)
	for i in 4:
		if not closed[i]:
			continue
		var o: Vector3 = SIDES[i]
		var t := Vector3(o.z, 0.0, -o.x)
		var edge := Vector3(16, 0, 16) + o * 16.0
		for c: float in COLUMNS:
			var along := t * (c - 16.0)
			var pts := []
			for q: Vector2 in COLUMN_FOOT + COLUMN_HEAD:
				for s: float in [-0.5, 0.5]:
					pts.append(edge - o * q.x + Vector3(0, q.y, 0) + along + t * s * COLUMN_W)
			# pts: foot (outer, inner) x (-, +), head (outer, inner) x (-, +); each face TMNF's open
			# frame (a dark truss card, its diagonals up the column: u along it, v across)
			var face := func(a: int, b: int, cc: int, d: int) -> void:
				var pa: Vector3 = pts[a]
				var pb: Vector3 = pts[b]
				var pc: Vector3 = pts[cc]
				var pd: Vector3 = pts[d]
				var mid := (pa + pb + pc + pd) * 0.25
				var cen := Vector3.ZERO
				for p: Vector3 in pts:
					cen += p / 8.0
				var u := COLUMN_PANELS / 8.0
				if (pb - pa).cross(pc - pa).dot(mid - cen) < 0.0:
					geo.quad_uv(pa, pd, pc, pb, "girder_dark", S_METAL, Vector2(0, 0), Vector2(u, 0), Vector2(u, 1), Vector2(0, 1))
				else:
					geo.quad_uv(pa, pb, pc, pd, "girder_dark", S_METAL, Vector2(0, 0), Vector2(0, 1), Vector2(u, 1), Vector2(u, 0))
			face.call(0, 1, 5, 4)      # outer face
			face.call(2, 3, 7, 6)      # inner face
			face.call(0, 2, 6, 4)      # one side
			face.call(1, 3, 7, 5)      # the other
			face.call(0, 1, 3, 2)      # foot


## A beam under the deck: the profile (d, y) points round its section, swept along s0..s1
## (`at` maps (d, y, s) to the block); its two ends closed, its top (at the plate) left out.
func _beam(geo: TmGeo, at: Callable, prof: Array, s0: float, s1: float) -> void:
	var c := Vector2.ZERO
	for q: Vector2 in prof:
		c += q / prof.size()
	for k in prof.size():
		var p: Vector2 = prof[k]
		var q: Vector2 = prof[(k + 1) % prof.size()]
		if p.y >= BOTTOM - 1e-3 and q.y >= BOTTOM - 1e-3:
			continue
		var mid := (p + q) * 0.5 - c
		var out: Vector3 = at.call(c.x + mid.x, mid.y + 1.0, 16.0) - at.call(c.x, 1.0, 16.0)
		_out_quad(geo, at.call(p.x, p.y, s0), at.call(q.x, q.y, s0), at.call(q.x, q.y, s1), at.call(p.x, p.y, s1), out)
	for s: float in [s0, s1]:
		var ring := prof.map(func(q: Vector2) -> Vector3: return at.call(q.x, q.y, s))
		var dir: Vector3 = at.call(c.x, c.y, s) - at.call(c.x, c.y, (s0 + s1) * 0.5)
		for k in range(1, ring.size() - 1):
			var a: Vector3 = ring[0]
			var b: Vector3 = ring[k]
			var d: Vector3 = ring[k + 1]
			if (b - a).cross(d - a).dot(dir) < 0.0:
				geo.tri(a, d, b, "platform_tray", S_METAL)
			else:
				geo.tri(a, b, d, "platform_tray", S_METAL)


## A dark quad under the deck facing `out` (whichever way its corners run).
func _out_quad(geo: TmGeo, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) < 0.0:
		geo.quad(a, d, c, b, "platform_tray", S_METAL)
	else:
		geo.quad(a, b, c, d, "platform_tray", S_METAL)


## A box whose faces toward closed sides are left out (the lips cover them); its faces at open
## sides (seen where nothing continues the deck) TMNF's dark Stands2.
func _body(geo: TmGeo, lo: Vector3, hi: Vector3, closed: Array) -> void:
	var p := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	geo.quad(p[4], p[7], p[6], p[5], "platform", S_DECK)        # top
	geo.quad(p[0], p[1], p[2], p[3], "", S_METAL)               # floor (on the tray)
	if not closed[2]:
		geo.quad(p[0], p[4], p[5], p[1], "platform_tray", S_METAL)      # -z
	if not closed[0]:
		geo.quad(p[2], p[6], p[7], p[3], "platform_tray", S_METAL)      # +z
	if not closed[1]:
		geo.quad(p[3], p[7], p[4], p[0], "platform_tray", S_METAL)      # -x
	if not closed[3]:
		geo.quad(p[1], p[5], p[6], p[2], "platform_tray", S_METAL)      # +x


## Sweeps an edge section (d inward, y) along side i of the block, from s0 to s1 m along it; an
## end at a corner is mitred against a closed neighbouring side, else square to the block edge
## (the ends between two parts of a side closed dark).
func _edge_sweep(geo: TmGeo, table: Array, i: int, closed: Array, mid := false, s0 := 0.0, s1 := 32.0) -> void:
	var o: Vector3 = SIDES[i]
	var t := Vector3(o.z, 0.0, -o.x)
	var c := Vector3(16, 0, 16)
	var a := c + o * 16.0 + t * (s0 - 16.0)
	var b := c + o * 16.0 + t * (s1 - 16.0)
	var n := -o
	# the neighbour at a has outward -t, at b +t
	var at_a := SIDES.find(-t)
	var at_b := SIDES.find(t)
	var la := n + t if closed[at_a] and s0 <= 0.0 else n
	var lb := n - t if closed[at_b] and s1 >= 32.0 else n
	var cap := "metal" if s0 <= 0.0 and s1 >= 32.0 else "platform_tray"
	var sec := table.map(func(q: Array) -> Array: return [Vector2(q[0], q[1]), q[2], q[3]] + q.slice(4))
	if mid:      # a vertex half way (a texture mirrored about the centre line needs one)
		geo.wall_sweep(sec, [a, (a + b) * 0.5, b], [la, n, lb], true, cap, S_METAL)
	else:
		geo.wall_sweep(sec, [a, b], [la, lb], true, cap, S_METAL)


## Turbo deck (TMNF's): a thin plate (8 -> 7.325 m) with a turbo top and its TURBO rim, over the
## deck's floor and underside (TURBO_FLOOR, _underside: its truss columns too), the white fabric
## box in the middle and the four turbines either side of it (TURBINE).
func _turbo(geo: TmGeo) -> void:
	var all := [true, true, true, true]
	for i in 4:
		_edge_sweep(geo, PLATE_LIP, i, all, true)
		_edge_sweep(geo, TURBO_FLOOR, i, all)
	# the plate in two halves (its texture is mirrored about x = 16)
	var p0 := TURBO_PLATE_IN
	var p1 := 32.0 - TURBO_PLATE_IN
	geo.box(Vector3(p0, UNDER, p0), Vector3(16.0, TOP, p1), "road_metal", S_METAL, "turbo", S_TURBO)
	geo.box(Vector3(16.0, UNDER, p0), Vector3(p1, TOP, p1), "road_metal", S_METAL, "turbo", S_TURBO)
	geo.box(Vector3(10.64, FLOOR_Y, 2.64), Vector3(21.36, UNDER, 29.36), "fabric", S_SLIDING)
	# TMNF's advert band under the plate along each x side (its Pub8x1B; our adverts), facing out
	for side: float in [-1.0, 1.0]:
		var xb := 16.0 + side * TURBO_PUB[0]
		var xt := 16.0 + side * TURBO_PUB[1]
		var z0: float = TURBO_PUB[4]
		var z1: float = TURBO_PUB[5]
		geo.screen_rect(Vector3(xb, TURBO_PUB[2], z0 + 0.18), Vector3(xb, TURBO_PUB[2], z1 - 0.18),
			Vector3(xt, TURBO_PUB[3], z1), Vector3(xt, TURBO_PUB[3], z0), "screen", TmGeo.NO_COLLISION,
			1 if side > 0.0 else 0, Vector3(side, 0, 0), 0.8)
	var f0 := TURBO_FLOOR_IN
	var f1 := 32.0 - TURBO_FLOOR_IN
	geo.quad(Vector3(f0, FLOOR_Y, f0), Vector3(f0, FLOOR_Y, f1), Vector3(f1, FLOOR_Y, f1), Vector3(f1, FLOOR_Y, f0), "platform", S_DECK)
	_underside(geo, all)
	var beam_z: Vector2 = TURBINE_BEAM[0]
	var beam_x: Vector2 = TURBINE_BEAM[1]
	for z0: float in TURBINE_Z:
		geo.box(Vector3(beam_x.x, float(TURBINE_BEAM[2]), z0 + beam_z.x), Vector3(beam_x.y, UNDER, z0 + beam_z.y),
			"platform_tray", S_METAL)
		for x: float in TURBINE_X:
			_turbine(geo, Vector3(x, TURBINE_Y, z0))
			geo.box(Vector3(x - 0.4, TURBINE_Y + 1.8, z0 + beam_z.x + 0.5), Vector3(x + 0.4, float(TURBINE_BEAM[2]),
				z0 + beam_z.y - 0.5), "platform_tray", S_METAL)
	# the pad's texture as TMNF lays it: 16 m a tile along z, mirrored about the centre line
	geo.remap_uv("turbo", func(p: Vector3) -> Vector2: return Vector2(p.z / 16.0, -0.5 - 1.5 * absf(p.x - 16.0) / 16.0))


## One turbine with its intake at c, facing -z: the outline revolved, the fan in the intake (a
## dark hub and four dark blades on the grey disc).
func _turbine(geo: TmGeo, c: Vector3) -> void:
	var sec := TURBINE.map(func(q: Array) -> Array: return [c.z + float(q[0]), float(q[1]), q[2], S_METAL])
	geo.revolve_z(sec, Vector2(c.x, c.y), 0.0, 360.0, 16, false)
	var hub := [[c.z - 0.45, 0.0, "road_metal", S_METAL], [c.z - 0.02, 0.45, "road_metal", S_METAL], [c.z - 0.02, 0.0, "road_metal", S_METAL]]
	geo.revolve_z(hub, Vector2(c.x, c.y), 0.0, 360.0, 12, false)
	geo.fan(c + Vector3(0, 0, -0.03), 0.4, 1.5, 0.32, "platform_tray")


## The grid wall's plan (x across, depth) swept round an arc in the y-z plane about c = (y, z) from
## angle a0 to a1 (angle 0 = +z, PI/2 = +y): depth 1.345 (the wall's back) rides at LOOP_R.
func _loop(geo: TmGeo, c: Vector2, a0: float, a1: float) -> void:
	var steps := 24
	var n := WALL_PLAN.size()
	var at := func(q: Array, a: float) -> Vector3:
		var r := LOOP_OUT - float(q[1])
		return Vector3(float(q[0]), c.x + r * sin(a), c.y + r * cos(a))
	for i in steps:
		var b0 := lerpf(a0, a1, float(i) / steps)
		var b1 := lerpf(a0, a1, float(i + 1) / steps)
		var mid := (b0 + b1) * 0.5
		var centre := Vector3(16.0, c.x + (LOOP_OUT - 0.67) * sin(mid), c.y + (LOOP_OUT - 0.67) * cos(mid))
		for k in n:
			var q0: Array = WALL_PLAN[k]
			var q1: Array = WALL_PLAN[(k + 1) % n]
			var a: Vector3 = at.call(q0, b0)
			var b: Vector3 = at.call(q1, b0)
			var cc: Vector3 = at.call(q1, b1)
			var d: Vector3 = at.call(q0, b1)
			var out := (a + b + cc + d) * 0.25 - centre
			# faces point away from the section's middle
			if (b - a).cross(cc - a).dot(out) < 0.0:
				geo.quad(a, d, cc, b, q0[2], q0[3])
			else:
				geo.quad(a, b, cc, d, q0[2], q0[3])


## A platform slope through surface heights h (every 32 / (n - 1) m along z): the lipped plate
## swept along the profile (its underside rising into the end lips), on a square pillar in the
## middle of the block.
func _slope(geo: TmGeo, h: Array) -> void:
	var height := func(z: float) -> float:
		var f := clampf(z / 32.0, 0.0, 1.0) * (h.size() - 1)
		var i := mini(int(f), h.size() - 2)
		return lerpf(float(h[i]), float(h[i + 1]), f - i)
	var under := func(z: float) -> float:
		var e := minf(z, 32.0 - z)
		for k in range(SLOPE_END.size() - 1, -1, -1):
			if e >= float(SLOPE_END[k][0]):
				if k == SLOPE_END.size() - 1:
					return float(SLOPE_END[k][1])
				var a: Array = SLOPE_END[k]
				var b: Array = SLOPE_END[k + 1]
				return lerpf(float(a[1]), float(b[1]), (e - float(a[0])) / (float(b[0]) - float(a[0])))
		return 7.9
	var zs: Array[float] = []
	for q: Array in SLOPE_END:
		zs.append(float(q[0]))
	for k in range(2, 15):
		zs.append(2.0 * k)
	for q: Array in SLOPE_END:
		zs.append(32.0 - float(q[0]))
	zs.sort()
	var path := []
	var lat := []
	for z in zs:
		path.append(Vector3(16, float(height.call(z)) - TOP, z))
		lat.append(Vector3(1, 0, 0))
	var sec := SLOPE_PLATE.map(func(q: Array) -> Array: return [Vector2(float(q[0]) - 16.0, q[1]), q[2], q[3]] + q.slice(4))
	var y_at := func(y: float, i: int) -> float:
		return y if y >= TOP - 0.01 else maxf(y, float(under.call((path[i] as Vector3).z)))
	geo.wall_sweep(sec, path, lat, true, "road_metal", S_METAL, y_at)
	_slope_frame(geo, func(z: float) -> float: return float(height.call(z)) - 0.88)


## TMNF's frame under a slope: the post, the cross of beams and the four trusses (SLOPE_*);
## plate(z): the plate's underside along the slope.
func _slope_frame(geo: TmGeo, plate: Callable) -> void:
	var post_top := float(plate.call(16.0)) - 0.5
	geo.pipe(Vector3(16, 0, 16), Vector3(16, post_top, 16), float(SLOPE_POST[0]), int(SLOPE_POST[1]), "platform_tray", S_METAL)
	var hw := SLOPE_BEAM_HALF
	var ln := SLOPE_BEAM_LEN
	for along_z in [false, true]:
		var w := Vector3(0, 0, 1) if along_z else Vector3(1, 0, 0)
		var n := Vector3(1, 0, 0) if along_z else Vector3(0, 0, 1)
		var dep: Array = SLOPE_STRUT_Z if along_z else SLOPE_STRUT_X
		var ss := [-ln, -6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0, ln]
		var top := func(p: Vector3, s: float) -> Vector3:
			return Vector3(p.x, float(plate.call(p.z)) - lerpf(float(dep[0]), float(dep[1]), absf(s) / ln), p.z)
		var low := func(p: Vector3, s: float) -> Vector3:
			return Vector3(p.x, float(plate.call(p.z)) - lerpf(float(dep[2]), float(dep[3]), absf(s) / ln), p.z)
		for k in ss.size() - 1:
			var s0: float = ss[k]
			var s1: float = ss[k + 1]
			var c0 := Vector3(16, 0, 16) + w * s0
			var c1 := Vector3(16, 0, 16) + w * s1
			for side: float in [-1.0, 1.0]:
				var a: Vector3 = c0 + n * side * hw
				var b: Vector3 = c1 + n * side * hw
				_out_quad(geo, top.call(a, s0), top.call(b, s1), low.call(b, s1), low.call(a, s0), n * side)
			for f: Callable in [top, low]:
				_out_quad(geo, f.call(c0 - n * hw, s0), f.call(c1 - n * hw, s1), f.call(c1 + n * hw, s1),
					f.call(c0 + n * hw, s0), Vector3.UP if f == top else Vector3.DOWN)
		for e: float in [-1.0, 1.0]:
			var c := Vector3(16, 0, 16) + w * e * ln
			var a: Vector3 = c - n * hw
			var b: Vector3 = c + n * hw
			_out_quad(geo, top.call(a, ln), top.call(b, ln), low.call(b, ln), low.call(a, ln), w * e)
			# the truss from the strut's end up to under the rim
			var rim := Vector3(16, 0, 16) + w * e * (16.0 - SLOPE_TRUSS_RIM)
			var p0: Vector3 = (top.call(c, ln) + low.call(c, ln)) * 0.5
			var p1 := Vector3(rim.x, float(plate.call(rim.z)) - SLOPE_TRUSS.y * 0.5 + 0.15, rim.z)
			_strut(geo, p0, p1, n, SLOPE_TRUSS.x, SLOPE_TRUSS.y)


## A straight strut of rectangular section (half width hw across n, height h, centred on the
## line a -> b), its ends closed: TMNF's trusses under the platform pieces.
func _strut(geo: TmGeo, a: Vector3, b: Vector3, n: Vector3, hw: float, h: float) -> void:
	var up := Vector3(0, h * 0.5, 0)
	var ring := func(p: Vector3) -> Array:
		return [p - n * hw - up, p + n * hw - up, p + n * hw + up, p - n * hw + up]
	var ra: Array = ring.call(a)
	var rb: Array = ring.call(b)
	var mid := (a + b) * 0.5
	for k in 4:
		var k1 := (k + 1) % 4
		var out: Vector3 = ((ra[k] + ra[k1]) * 0.5 + (rb[k] + rb[k1]) * 0.5) * 0.5 - mid
		var q := [ra[k], ra[k1], rb[k1], rb[k]]
		if (q[1] - q[0]).cross(q[2] - q[0]).dot(out) < 0.0:
			geo.quad(q[0], q[3], q[2], q[1], "truss", S_METAL)
		else:
			geo.quad(q[0], q[1], q[2], q[3], "truss", S_METAL)
	for r: Array in [ra, rb]:
		var out: Vector3 = (r[0] + r[2]) * 0.5 - mid
		if (r[1] - r[0]).cross(r[2] - r[0]).dot(out) < 0.0:
			geo.quad(r[0], r[3], r[2], r[1], "truss", S_METAL)
		else:
			geo.quad(r[0], r[1], r[2], r[3], "truss", S_METAL)


## A (z, radius) section revolved about the axis through centre (x, y) along z from angle a0 to a1
## (degrees, from +x toward +y); caps close both ends.
func _revolve_z(geo: TmGeo, section: Array, a0: float, a1: float, steps: int, caps := true,
		centre := Vector2(16, 16)) -> void:
	geo.revolve_z(section, centre, a0, a1, steps, caps)


## The vertical checkpoint ring (no deck: cars pass through it, usually in the air): four arcs, the
## brackets holding it to the cells above and below, a light either side of each diagonal gap, and
## billboard bands on the front face.
func _ring_v(geo: TmGeo) -> void:
	for k in 4:
		var c := 90.0 * k
		var part := TmGeo.new()
		_revolve_z(part, RING_SECTION, c - RING_ARC, c + RING_ARC, 16)
		_ring_uv(part, RING_SECTION, Vector2(16, 16), c)
		geo.merge(part)
		_revolve_z(geo, RING_PANEL, c + 17.0, c + 73.0, 12)
		for a in [c + 40.0, c + 50.0]:
			_revolve_z(geo, [[13.6, 12.6, "lamp", TmGeo.NO_COLLISION], [15.0, 12.6, "lamp", TmGeo.NO_COLLISION],
				[15.0, 13.6, "lamp", TmGeo.NO_COLLISION], [13.6, 13.6, "lamp", TmGeo.NO_COLLISION]], a - 1.0, a + 1.0, 1)
	for y in [0.0, 29.83]:
		geo.box(Vector3(14.7, y, 14.41), Vector3(17.3, y + 2.17, 17.59), "structure", S_METAL, "", -2, 0.05)
		geo.box(Vector3(15.5, y + 0.16, 12.96), Vector3(16.5, y + 2.0, 19.04), "structure", S_METAL, "", -2, 0.04)


## The UVs of a ring arc revolved from `sec` about centre (x, y) round the angle mid (degrees): the
## panel faces' atlas rows across them (front to back), the ribbed bevels one row, the CHECKPOINT
## band along the arc (metres, a word centred at mid; read left to right from the front (-z) and
## from the back; its top at the outer edge).
func _ring_uv(part: TmGeo, sec: Array, centre: Vector2, mid: float) -> void:
	var z0 := INF
	var z1 := -INF
	var r0 := INF
	var r1 := -INF
	for q: Array in sec:
		z0 = minf(z0, float(q[0]))
		z1 = maxf(z1, float(q[0]))
		r0 = minf(r0, float(q[1]))
		r1 = maxf(r1, float(q[1]))
	var zm := (z0 + z1) * 0.5
	var rm := (r0 + r1) * 0.5
	var along := func(p: Vector3) -> float:
		return wrapf(atan2(p.y - centre.y, p.x - centre.x) - deg_to_rad(mid), -PI, PI) * rm
	part.remap_uv("border_panel", func(p: Vector3) -> Vector2:
		return Vector2(float(along.call(p)) / 16.0, lerpf(RING_ROWS.x, RING_ROWS.y, (p.z - z0) / (z1 - z0)) / 512.0))
	part.remap_uv("border_ribs", func(p: Vector3) -> Vector2: return Vector2(float(along.call(p)) / 16.0, RING_RIB_ROW / 512.0))
	part.remap_uv("gate_cp", func(p: Vector3) -> Vector2:
		var r := Vector2(p.x - centre.x, p.y - centre.y).length()
		var u := -float(along.call(p)) if p.z < zm else float(along.call(p))
		return Vector2(u + 4.0, (r1 - r) * 1.25 / (r1 - r0)))


## The checkpoint's gate over the deck (CP_GATE_*: the road's, resized as TMNF's), a billboard leaning
## on the arch's back, and the two struts holding it from the deck's front corners.
func _checkpoint_arch(geo: TmGeo) -> void:
	var gate := TmGeo.new()
	RoadShapes.new()._gate(gate, 16.0)
	gate.scale_move(Vector3(16, 0, 16), Vector3(CP_GATE_SCALE, 1.0, 1.0), Vector3(0.0, CP_GATE_DY, 0.0))
	geo.merge(gate)
	# the billboard follows the arch down toward its ends
	var path := []
	var outward := []
	var drop := []
	for k in 13:
		var a := deg_to_rad(lerpf(90.0 - ARCH_BOARD_HALF, 90.0 + ARCH_BOARD_HALF, k / 12.0))
		var dir := Vector3(cos(a), 0, sin(a))
		path.append(Vector3(ARCH_BOARD_AXIS.x, 0, ARCH_BOARD_AXIS.y))
		outward.append(dir)
		var x := ARCH_BOARD_AXIS.x + dir.x * 18.2
		var r := ARCH_OUTER_R
		drop.append(ARCH_BOARD_FALL * (sqrt(maxf(0.0, r * r - (x - 16.0) * (x - 16.0))) - r))
	var board := ARCH_BOARD.map(func(q: Array) -> Array: return [Vector2(q[0], q[1]), q[2], q[3]])
	geo.wall_sweep(board, path, outward, true, "screen", S_METAL,
		func(y: float, i: int) -> float: return y + float(drop[i]))
	for mirror in [false, true]:
		for k in ARCH_STRUT.size() - 1:
			var a: Vector3 = ARCH_STRUT[k]
			var b: Vector3 = ARCH_STRUT[k + 1]
			if mirror:
				a.x = 32.0 - a.x
				b.x = 32.0 - b.x
			geo.pipe(a, b, 0.55, 6, "structure", S_METAL)
	# short legs under the lips, two per side
	for c: Vector2 in [Vector2(8, 2), Vector2(24, 2), Vector2(8, 30), Vector2(24, 30), Vector2(2, 8), Vector2(2, 24),
			Vector2(30, 8), Vector2(30, 24)]:
		geo.box(Vector3(c.x - 0.5, 0, c.y - 0.5), Vector3(c.x + 0.5, 3.42, c.y + 0.5), "truss", S_METAL, "", -2, 0.05)


## Grid wall round a GT curve: on the arc of radius 32 k about the footprint's corner (0, 32 k), the
## grid panel 1.0 .. 1.345 m in from it between rails the wall's full depth, with frame posts at the
## ends and joints (measured: 2 segments on the 2-block curve, 4 on the 3-block one).
func _curve_wall(geo: TmGeo, k: int, units: int) -> void:
	var r := 32.0 * k
	var c := Vector2(0, r)
	var h := 8.0 * units
	_sector(geo, c, r - 1.345, r - 1.0, -90.0, 0.0, 0.089, h - 0.089, "grid", S_METAL)
	_sector(geo, c, r - 1.345, r, -90.0, 0.0, 0.0, 0.089, "wall", S_DECK)
	_sector(geo, c, r - 1.345, r, -90.0, 0.0, h - 0.089, h, "wall", S_DECK)
	var n: int = CURVE_WALL_SEGMENTS[str(k)]
	for i in n + 1:
		var a := -90.0 + 90.0 * i / n
		_sector(geo, c, r - 1.345, r - 1.0, maxf(-90.0, a - 0.47), minf(0.0, a + 0.47), 0.089, h - 0.089, "metal", S_METAL)


## A vertical prism over an annular sector (radii r0 .. r1 about c, angles a0 .. a1 in degrees from +x
## toward +z) from y0 to y1, closed.
func _sector(geo: TmGeo, c: Vector2, r0: float, r1: float, a0: float, a1: float, y0: float, y1: float,
		mat: String, surf: int) -> void:
	var steps := maxi(2, int(ceil(absf(a1 - a0) / 2.0)))
	var loop := []
	for i in steps + 1:
		var a := deg_to_rad(lerpf(a0, a1, float(i) / steps))
		loop.append([c + Vector2(cos(a), sin(a)) * r1, mat, surf])
	for i in range(steps, -1, -1):
		var a := deg_to_rad(lerpf(a0, a1, float(i) / steps))
		loop.append([c + Vector2(cos(a), sin(a)) * r0, mat, surf])
	geo.extrude_y(loop, y0, y1, true, mat, surf)


## The platform's border wall (the cell's -z edge, 0 -> 1.345 m, 8 m high): its sides dark
## concrete panels, its top, foot and ends the border atlas' orange band with the blue line on the
## outer side (z = 0), as TMNF's (16 m a tile along the top and foot, 8 m up the ends).
func _border_wall(geo: TmGeo) -> void:
	var t := 1.345
	geo.quad(Vector3(0, 0, 0), Vector3(0, 8, 0), Vector3(32, 8, 0), Vector3(32, 0, 0), "platform_wall", S_DECK)
	geo.quad(Vector3(0, 0, t), Vector3(32, 0, t), Vector3(32, 8, t), Vector3(0, 8, t), "platform_wall", S_DECK)
	for x0: float in [0.0, 16.0]:
		geo.band_quad(Vector3(x0, 8, 0), Vector3(x0 + 16, 8, 0), Vector3(x0 + 16, 8, t), Vector3(x0, 8, t),
			"border_orange", S_DECK, 2.0, 1.0, 391.0, 298.0, Vector3.UP)
		geo.band_quad(Vector3(x0, 0, 0), Vector3(x0 + 16, 0, 0), Vector3(x0 + 16, 0, t), Vector3(x0, 0, t),
			"border_orange", S_DECK, 1.0, 2.0, 391.0, 298.0, Vector3.DOWN)
	for x: float in [0.0, 32.0]:
		geo.band_quad(Vector3(x, 0, 0), Vector3(x, 8, 0), Vector3(x, 8, t), Vector3(x, 0, t),
			"border_orange", S_DECK, 0.0, 0.5, 391.0, 298.0, Vector3(-1 if x == 0.0 else 1, 0, 0))


## Grid walls `units` blocks high on the cell's -z edge (0 -> 1.345 m): the measured plan
## extruded between 9 cm rails, with a pipe and its clamps every 8 m; the 2-high "Pub" wall has a
## screen instead of the grid.
func _grid_wall(geo: TmGeo, units: int, pub: bool) -> void:
	var h := 8.0 * units
	var plan := WALL_PLAN.map(func(q: Array) -> Array:
		return [Vector2(q[0], q[1]), "screen" if pub and q[2] == "grid" else q[2], q[3]])
	geo.extrude_y(plan, 0.089, h - 0.089)
	geo.box(Vector3(0, 0, 0), Vector3(32, 0.089, 1.345), "platform_wall", S_DECK)
	geo.box(Vector3(0, h - 0.089, 0), Vector3(32, h, 1.345), "platform_wall", S_DECK)
	for k in units:
		var y := 4.0 + 8.0 * k
		geo.pipe(Vector3(0.54, y, 0.39), Vector3(31.46, y, 0.39), 0.3, 8, "pipe", S_DECK)
		for x0 in [0.0, 8.0, 23.0, 31.0]:
			geo.box(Vector3(x0, y - 0.45, 0.0), Vector3(x0 + 1.0, y + 0.45, 1.0), "structure", S_METAL, "", -2, 0.03)
		for x0 in [12.42, 18.9]:
			geo.box(Vector3(x0, y - 1.0, 0.0), Vector3(x0 + 0.68, y + 1.0, 1.0), "structure", S_METAL, "", -2, 0.03)
