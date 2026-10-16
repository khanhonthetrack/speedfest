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
const LIP := [
	[INSET, TOP, "platform", S_DECK], [0.0, TOP, "metal", S_METAL], [0.0, 7.9, "structure", S_METAL],
	[0.122, 7.9, "metal", S_METAL], [0.249, 7.611, "metal", S_METAL], [0.505, 7.423, "metal", S_METAL],
	[0.847, UNDER, "structure", S_METAL], [3.085, UNDER, "fabric", S_SLIDING], [2.835, 7.15, "fabric", S_SLIDING],
	[2.695, 6.795, "fabric", S_SLIDING], [2.635, 4.298, "fabric", S_SLIDING], [2.695, 1.836, "fabric", S_SLIDING],
	[2.835, 1.444, "fabric", S_SLIDING], [3.133, 1.207, "structure", S_METAL], [2.802, 1.207, "metal", S_METAL],
	[2.802, BOTTOM, "structure", S_METAL], [INSET, BOTTOM, "", TmGeo.NO_COLLISION],
]
## The turbo plate's rounded underside edge (every side).
const PLATE_LIP := [
	[1.0, TOP, "turbo", S_TURBO], [0.0, TOP, "metal", S_METAL], [0.0, 7.9, "structure", S_METAL],
	[0.122, 7.9, "rubber", S_SIGNS], [0.249, 7.611, "rubber", S_SIGNS], [0.505, 7.423, "rubber", S_SIGNS],
	[0.847, UNDER, "structure", S_METAL], [1.0, UNDER, "", TmGeo.NO_COLLISION],
]

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
	[31.000, 1.345, "grid", 4], [24.000, 1.345, "platform", 16]
]
## The platform checkpoint's arch: the ring section moved out to radius 21.91 .. 23.30 about this
## centre (and 0.1 m back along z), its half-angle, and the billboard (z, radius) on its back.
const ARCH_CENTRE := Vector2(16, -8.976)
const ARCH_DR := 9.348
const ARCH_DZ := -0.105
const ARCH_HALF := 33.8
## The billboard: a band leaning in over the arch, curved in plan about a vertical axis at
## ARCH_BOARD_AXIS (x, z); its section (radius from the axis, y) at the top, and its half-angle.
const ARCH_BOARD_AXIS := Vector2(16, 4.43)
const ARCH_BOARD := [[14.12, 15.53, "screen", S_METAL], [12.59, 17.65, "screen", S_METAL],
	[12.75, 17.76, "screen", S_METAL], [14.28, 15.64, "screen", S_METAL]]
const ARCH_BOARD_HALF := 44.0
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
## into the end lips (z from the end, y), measured.
const SLOPE_PLATE := [
	[0.0, TOP, "metal", S_METAL], [0.0, 7.9, "structure", S_METAL], [0.122, 7.9, "metal", S_METAL],
	[0.249, 7.611, "metal", S_METAL], [0.505, 7.423, "metal", S_METAL], [0.847, UNDER, "structure", S_METAL],
	[3.08, UNDER, "structure", S_METAL], [3.08, 7.12, "stands", S_METAL], [28.92, 7.12, "structure", S_METAL],
	[28.92, UNDER, "structure", S_METAL], [31.153, UNDER, "metal", S_METAL], [31.495, 7.423, "metal", S_METAL],
	[31.751, 7.611, "metal", S_METAL], [31.878, 7.9, "structure", S_METAL], [32.0, 7.9, "metal", S_METAL],
	[32.0, TOP, "platform", S_DECK],
]
const SLOPE_END := [[0.0, 7.9], [0.122, 7.9], [0.249, 7.611], [0.505, 7.423], [0.847, UNDER], [3.07, UNDER], [3.09, 7.12]]
const SLOPES := {
	"2StraightAir": [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0],
	"BiSlope2StartAir": [8.0, 8.0, 8.0, 8.092, 8.269, 8.521, 8.854, 9.268, 9.743, 10.271, 10.86, 11.52, 12.243,
		13.045, 13.941, 14.926, 16.0],
	"BiSlope2EndAir": [0.0, 0.99, 1.919, 2.776, 3.561, 4.279, 4.932, 5.519, 6.049, 6.53, 6.953, 7.306, 7.591,
		7.805, 7.931, 7.971, 8.0],
}
## Checkpoints on slopes and banks: the flat checkpoint sheared, (kx, kz, dy) of TmGeo.shear_y.
const CHECKPOINT_SHEAR := {
	"UpAir": [0.0, 0.5, 0.0], "DownAir": [0.0, -0.5, 16.0], "LeftAir": [-0.5, 0.0, 16.0], "RightAir": [0.5, 0.0, 0.0],
}

## Vertical checkpoint ring about (16, 16) in the x-y plane: the ring's section (z, radius) with
## rounded sign faces front and back; four 76-degree arcs between the diagonals.
const RING_SECTION := [
	[18.2, 13.954, "rubber_white", S_METAL], [14.011, 13.954, "rubber_white", S_METAL],
	[13.976, 13.852, "logo", S_METAL], [13.59, 13.555, "logo", S_METAL], [13.48, 13.258, "logo", S_METAL],
	[13.59, 12.961, "logo", S_METAL], [13.976, 12.664, "rubber_white", S_METAL],
	[14.011, 12.563, "rubber_white", S_METAL], [18.2, 12.563, "rubber_white", S_METAL],
	[18.235, 12.664, "logo", S_METAL], [18.621, 12.961, "logo", S_METAL], [18.731, 13.258, "logo", S_METAL],
	[18.621, 13.555, "logo", S_METAL], [18.235, 13.852, "rubber_white", S_METAL],
]
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
		"Checkpoint":
			if parts[2] == "RingVAir":
				_ring_v(geo)
			else:
				_deck(geo, _closed([]))       # a lip on every side, the body inset all round
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
					geo.box(Vector3(0, 0, 0), Vector3(32, 8, 1.345), "wall", S_DECK)
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
	var inset := func(i: int) -> float: return INSET if closed[i] else 0.0
	var lo := Vector3(inset.call(1), BOTTOM, inset.call(2))
	var hi := Vector3(32.0 - inset.call(3), TOP, 32.0 - inset.call(0))
	_body(geo, lo, hi, closed)


## A box whose faces toward closed sides are left out (the lips cover them).
func _body(geo: TmGeo, lo: Vector3, hi: Vector3, closed: Array) -> void:
	var p := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	geo.quad(p[4], p[7], p[6], p[5], "platform", S_DECK)        # top
	geo.quad(p[0], p[1], p[2], p[3], "structure", S_METAL)      # floor
	if not closed[2]:
		geo.quad(p[0], p[4], p[5], p[1], "metal", S_METAL)      # -z
	if not closed[0]:
		geo.quad(p[2], p[6], p[7], p[3], "metal", S_METAL)      # +z
	if not closed[1]:
		geo.quad(p[3], p[7], p[4], p[0], "metal", S_METAL)      # -x
	if not closed[3]:
		geo.quad(p[1], p[5], p[6], p[2], "metal", S_METAL)      # +x


## Sweeps an edge section (d inward, y) along side i of the block; each end is mitred against a
## closed neighbouring side, or square to the block edge.
func _edge_sweep(geo: TmGeo, table: Array, i: int, closed: Array) -> void:
	var o: Vector3 = SIDES[i]
	var t := Vector3(o.z, 0.0, -o.x)
	var c := Vector3(16, 0, 16)
	var a := c + o * 16.0 - t * 16.0
	var b := c + o * 16.0 + t * 16.0
	var n := -o
	# the neighbour at a has outward -t, at b +t
	var at_a := SIDES.find(-t)
	var at_b := SIDES.find(t)
	var la := n + t if closed[at_a] else n
	var lb := n - t if closed[at_b] else n
	var sec := table.map(func(q: Array) -> Array: return [Vector2(q[0], q[1]), q[2], q[3]])
	geo.wall_sweep(sec, [a, b], [la, lb], true, "metal", S_METAL)


## Turbo deck: a thin plate (8 -> 7.325 m) with a turbo top and rounded underside edges, over a
## fan housing.
func _turbo(geo: TmGeo) -> void:
	var all := [true, true, true, true]
	for i in 4:
		_edge_sweep(geo, PLATE_LIP, i, all)
	var lo := Vector3(1.0, UNDER, 1.0)
	var hi := Vector3(31.0, TOP, 31.0)
	geo.box(lo, hi, "structure", S_METAL, "turbo", S_TURBO)
	geo.box(Vector3(10.64, 1.21, 2.64), Vector3(21.36, UNDER, 29.36), "fabric", S_SLIDING)


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
	var sec := SLOPE_PLATE.map(func(q: Array) -> Array: return [Vector2(float(q[0]) - 16.0, q[1]), q[2], q[3]])
	var y_at := func(y: float, i: int) -> float:
		return y if y >= TOP - 0.01 else maxf(y, float(under.call((path[i] as Vector3).z)))
	geo.wall_sweep(sec, path, lat, true, "metal", S_METAL, y_at)
	geo.box(Vector3(14.37, 0, 14.37), Vector3(17.64, float(height.call(16.0)) - 0.88, 17.64), "stands", S_METAL)


## A (z, radius) section revolved about the axis through centre (x, y) along z from angle a0 to a1
## (degrees, from +x toward +y); caps close both ends.
func _revolve_z(geo: TmGeo, section: Array, a0: float, a1: float, steps: int, caps := true,
		centre := Vector2(16, 16)) -> void:
	var loop := []
	for q in section:
		loop.append([Vector2(float(q[0]), float(q[1])), String(q[2]), int(q[3])])
	if TmGeo.loop_area(loop) < 0.0:
		loop = TmGeo.reversed_loop(loop)
	var frames := []
	for k in steps + 1:
		var a := deg_to_rad(lerpf(a0, a1, float(k) / steps))
		var up := Vector3(cos(a), sin(a), 0)
		var fwd := Vector3(-sin(a), cos(a), 0)
		frames.append(Transform3D(Basis(Vector3(0, 0, 1), up, fwd), Vector3(centre.x, centre.y, 0)))
	geo.sweep(loop + [loop[0]], frames)
	if caps:
		var mat: String = loop[0][1]
		geo._section_cap(loop, frames[0], -1.0, mat, loop[0][2])
		geo._section_cap(loop, frames[steps], 1.0, mat, loop[0][2])


## The vertical checkpoint ring (no deck: cars pass through it, usually in the air): four arcs, the
## brackets holding it to the cells above and below, a light either side of each diagonal gap, and
## billboard bands on the front face.
func _ring_v(geo: TmGeo) -> void:
	for k in 4:
		var c := 90.0 * k
		_revolve_z(geo, RING_SECTION, c - RING_ARC, c + RING_ARC, 16)
		_revolve_z(geo, RING_PANEL, c + 17.0, c + 73.0, 12)
		for a in [c + 40.0, c + 50.0]:
			_revolve_z(geo, [[13.6, 12.6, "lamp", TmGeo.NO_COLLISION], [15.0, 12.6, "lamp", TmGeo.NO_COLLISION],
				[15.0, 13.6, "lamp", TmGeo.NO_COLLISION], [13.6, 13.6, "lamp", TmGeo.NO_COLLISION]], a - 1.0, a + 1.0, 1)
	for y in [0.0, 29.83]:
		geo.box(Vector3(14.7, y, 14.41), Vector3(17.3, y + 2.17, 17.59), "structure", S_METAL)
		geo.box(Vector3(15.5, y + 0.16, 12.96), Vector3(16.5, y + 2.0, 19.04), "structure", S_METAL)


## The checkpoint arch over the deck: the ring's section revolved on a circle of radius 23.3 about
## (16, -8.976) between radial cuts 33.8 degrees either side of the top, a billboard leaning on its
## back, and the two struts holding it from the deck's front corners.
func _checkpoint_arch(geo: TmGeo) -> void:
	var sec := RING_SECTION.map(func(q: Array) -> Array: return [float(q[0]) + ARCH_DZ, float(q[1]) + ARCH_DR, q[2], q[3]])
	_revolve_z(geo, sec, 90.0 - ARCH_HALF, 90.0 + ARCH_HALF, 16, true, ARCH_CENTRE)
	# the billboard follows the arch down toward its ends
	var path := []
	var outward := []
	var drop := []
	for k in 13:
		var a := deg_to_rad(lerpf(90.0 - ARCH_BOARD_HALF, 90.0 + ARCH_BOARD_HALF, k / 12.0))
		var dir := Vector3(cos(a), 0, sin(a))
		path.append(Vector3(ARCH_BOARD_AXIS.x, 0, ARCH_BOARD_AXIS.y))
		outward.append(dir)
		var x := ARCH_BOARD_AXIS.x + dir.x * 13.4
		var r := ARCH_DR + 13.954
		drop.append(0.5 * (sqrt(maxf(0.0, r * r - (x - 16.0) * (x - 16.0))) - r))
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
		geo.box(Vector3(c.x - 0.5, 0, c.y - 0.5), Vector3(c.x + 0.5, 3.42, c.y + 0.5), "stands", S_METAL)


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


## Grid walls `units` blocks high on the cell's -z edge (0 -> 1.345 m): the measured plan
## extruded between 9 cm rails, with a pipe and its clamps every 8 m; the 2-high "Pub" wall has a
## screen instead of the grid.
func _grid_wall(geo: TmGeo, units: int, pub: bool) -> void:
	var h := 8.0 * units
	var plan := WALL_PLAN.map(func(q: Array) -> Array:
		return [Vector2(q[0], q[1]), "screen" if pub and q[2] == "grid" else q[2], q[3]])
	geo.extrude_y(plan, 0.089, h - 0.089)
	geo.box(Vector3(0, 0, 0), Vector3(32, 0.089, 1.345), "wall", S_DECK)
	geo.box(Vector3(0, h - 0.089, 0), Vector3(32, h, 1.345), "wall", S_DECK)
	for k in units:
		var y := 4.0 + 8.0 * k
		geo.pipe(Vector3(0.54, y, 0.39), Vector3(31.46, y, 0.39), 0.3, 8, "pipe", S_DECK)
		for x0 in [0.0, 8.0, 23.0, 31.0]:
			geo.box(Vector3(x0, y - 0.45, 0.0), Vector3(x0 + 1.0, y + 0.45, 1.0), "structure", S_METAL)
		for x0 in [12.42, 18.9]:
			geo.box(Vector3(x0, y - 1.0, 0.0), Vector3(x0 + 0.68, y + 1.0, 1.0), "structure", S_METAL)
