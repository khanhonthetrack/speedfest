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
const CHECKPOINT_ARCH := [
	[16.000, 14.326, "structure", 4], [14.265, 14.262, "structure", 4], [12.541, 14.071, "structure", 4],
	[10.839, 13.755, "structure", 4], [9.170, 13.315, "structure", 4], [7.545, 12.754, "structure", 4],
	[5.973, 12.075, "structure", 4], [4.466, 11.284, "structure", 4], [3.032, 10.384, "structure", 4],
	[3.937, 9.268, "metal", 4], [5.270, 10.104, "metal", 4], [6.673, 10.841, "metal", 4],
	[8.134, 11.472, "metal", 4], [9.646, 11.994, "metal", 4], [11.199, 12.403, "metal", 4],
	[12.782, 12.698, "metal", 4], [14.386, 12.875, "metal", 4], [16.000, 12.934, "metal", 4],
	[17.614, 12.875, "metal", 4], [19.218, 12.698, "metal", 4], [20.801, 12.403, "metal", 4],
	[22.354, 11.994, "metal", 4], [23.866, 11.472, "metal", 4], [25.327, 10.841, "metal", 4],
	[26.730, 10.104, "metal", 4], [28.063, 9.268, "structure", 4], [28.968, 10.384, "structure", 4],
	[27.534, 11.284, "structure", 4], [26.027, 12.075, "structure", 4], [24.455, 12.754, "structure", 4],
	[22.830, 13.315, "structure", 4], [21.161, 13.755, "structure", 4], [19.459, 14.071, "structure", 4],
	[17.735, 14.262, "structure", 4]
]


## Loops: the riding surface's radius, and the plan's depth outside it (the fins).
const LOOP_R := 30.705
const LOOP_OUT := 32.05


func handles(shape: String) -> bool:
	return shape.begins_with("Platform/Road/") or shape.begins_with("Platform/Wall/") \
		or shape == "Platform/Turbo/Air" or shape == "Platform/Checkpoint/Air" \
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
		"Turbo":
			_turbo(geo)
		"Checkpoint":
			_deck(geo, _closed([0, 2]))
			_checkpoint_arch(geo)
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


## The checkpoint arch over the deck (measured section, 13.4 -> 18.6 m along z).
func _checkpoint_arch(geo: TmGeo) -> void:
	var sec := CHECKPOINT_ARCH.map(func(q: Array) -> Array: return [Vector2(q[0], q[1]), q[2], q[3]])
	# lateral = +x, so (d, y) = (x, y); the path runs along z
	geo.wall_sweep(sec, [Vector3(0, 0, 13.4), Vector3(0, 0, 18.6)], [Vector3(1, 0, 0), Vector3(1, 0, 0)], true, "structure", S_METAL)


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
