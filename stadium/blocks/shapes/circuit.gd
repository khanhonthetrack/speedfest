extends RefCounted
## Stadium "Circuit" blocks: the raised plate (base), its slopes, and the tall border walls. Our own
## geometry from measured numbers (TMNF block-local metres: x right, y up, z forward; see TmGeo).
##
## Every border is one wall section swept along a path: its inner (road) face runs 8.985 m inside
## the border's cell; corners and GT curves are arcs about the footprint's inner corner (radius
## 32k - 8.985) or outer corner (32(k - 1) + 8.985); the ledge behind the wall (top 8 m) fills the
## rest of the footprint. Slopes rise 16 m per block (0.5); start/end ease in over a block.

const S_ASPHALT := 16   # TmTuning.Surface ids
const S_METAL := 4
const S_RUBBER := 9
const S_CONCRETE := 0
const FACE := 23.015            ## the wall's inner face, from the cell's road side (z)
const LEDGE_D := 4.075          ## the stands' foot behind the face (d), where the ledge starts
const LEDGE_Y := 8.0
const FLOOR_Y := 0.24

## Wall section: (d, y) points around the solid, d = offset from the inner face outward, with the
## material/surface of the segment starting at each point. Rubber bumper at the foot, logo band,
## rubber top lip at 15-16 m, cap, stands and screen outside, down to the stands' foot.
const WALL := [
	[-0.465, 0.10, "rubber", S_RUBBER], [-0.585, 0.31, "rubber", S_RUBBER], [-0.645, 0.54, "rubber", S_RUBBER],
	[-0.615, 0.81, "rubber", S_RUBBER], [-0.415, 1.28, "structure", S_METAL], [-0.415, 1.79, "structure", S_METAL],
	[0.305, 2.41, "structure", S_METAL], [-0.055, 2.65, "structure", S_METAL], [-0.125, 2.87, "structure", S_METAL],
	[-0.125, 3.22, "structure", S_METAL], [0.0, 3.40, "logo", S_METAL], [0.0, 7.00, "wall", S_RUBBER],
	[-0.135, 7.07, "wall", S_RUBBER], [-0.135, 14.86, "rubber_white", S_RUBBER], [-0.065, 15.61, "rubber_white", S_RUBBER],
	[0.105, 15.83, "rubber_white", S_RUBBER], [0.415, 15.96, "rubber_white", S_RUBBER], [0.775, 16.0, "fabric", S_METAL],
	[2.665, 16.0, "fabric", S_METAL], [2.835, 15.94, "fabric", S_METAL], [2.885, 15.77, "fabric", S_METAL],
	[2.885, 15.28, "fabric", S_METAL], [2.595, 15.06, "stands", S_CONCRETE], [2.595, 12.66, "screen", S_METAL],
	[2.595, 9.63, "stands", S_CONCRETE], [2.595, 9.42, "rubber", S_RUBBER], [3.565, 9.09, "rubber", S_RUBBER],
	[3.935, 8.81, "rubber", S_RUBBER], [4.145, 8.33, "rubber", S_RUBBER], [4.075, 8.0, "wall_dark", S_METAL],
	[4.075, 0.24, "structure", S_METAL], [3.595, 0.24, "structure", S_METAL], [3.415, 0.0, "structure", S_METAL],
	[-0.245, 0.0, "rubber", S_RUBBER],
]

## Level walls across a slope (Top: at the top of the slope, facing down it; Bottom: at its foot):
## the wall's section (z, y, material, surface) reshaped to sit on the ramp, the same at every x
## (measured: tools/research/tmnf/section_loop.py).
const SLOPE_TOP_WALL := [
	[9.405, 6.495, "structure", S_ASPHALT], [9.027, 6.629, "structure", S_ASPHALT],
	[8.681, 6.753, "wall", S_RUBBER], [9.039, 7.164, "wall", S_RUBBER], [9.112, 7.429, "wall", S_RUBBER],
	[9.115, 7.780, "wall", S_RUBBER], [9.082, 7.893, "wall", S_RUBBER], [8.985, 7.892, "rubber_white", S_RUBBER],
	[8.985, 8.034, "logo", S_METAL], [8.985, 11.351, "rubber_white", S_RUBBER], [8.985, 11.492, "wall", S_RUBBER],
	[9.115, 11.627, "wall", S_RUBBER], [9.117, 19.417, "rubber_white", S_RUBBER],
	[9.118, 19.798, "rubber_white", S_RUBBER], [9.048, 20.130, "rubber_white", S_RUBBER],
	[8.883, 20.274, "rubber_white", S_RUBBER], [8.573, 20.250, "rubber_white", S_RUBBER],
	[8.214, 20.107, "rubber_white", S_RUBBER], [7.944, 19.972, "wall", S_RUBBER],
	[6.323, 19.162, "wall", S_RUBBER], [6.153, 19.020, "wall", S_RUBBER], [6.103, 18.820, "wall", S_RUBBER],
	[6.102, 18.409, "wall", S_RUBBER], [6.101, 18.334, "wall", S_RUBBER], [6.145, 18.302, "rubber", S_RUBBER],
	[6.386, 18.247, "stands", S_CONCRETE], [6.386, 15.850, "screen", S_METAL],
	[6.386, 12.818, "stands", S_CONCRETE], [6.386, 12.612, "rubber", S_RUBBER],
	[6.281, 12.232, "rubber", S_RUBBER], [5.421, 11.802, "rubber", S_RUBBER], [5.386, 11.683, "rubber", S_RUBBER],
	[5.055, 11.340, "rubber", S_RUBBER], [4.924, 11.128, "rubber", S_RUBBER], [4.843, 10.885, "rubber", S_RUBBER],
	[4.843, 10.624, "rubber", S_RUBBER], [4.908, 10.454, "rubber_white", S_RUBBER],
	[0.000, 8.000, "wall_dark", S_METAL], [0.000, 0.243, "stands", S_CONCRETE],
	[5.387, 2.937, "rubber", S_RUBBER], [5.575, 2.787, "wall", S_RUBBER], [9.228, 4.614, "wall", S_RUBBER],
	[9.449, 4.828, "rubber", S_RUBBER], [9.568, 5.093, "rubber", S_RUBBER], [9.630, 5.353, "rubber", S_RUBBER],
	[9.597, 5.611, "rubber", S_RUBBER], [9.405, 5.983, "structure", S_ASPHALT]
]
const SLOPE_BOTTOM_WALL := [
	[22.595, 5.089, "structure", S_ASPHALT], [22.627, 5.132, "structure", S_ASPHALT],
	[23.319, 6.072, "wall", S_RUBBER], [22.961, 6.126, "wall", S_RUBBER], [22.888, 6.318, "wall", S_RUBBER],
	[22.885, 6.665, "wall", S_RUBBER], [22.918, 6.811, "wall", S_RUBBER],
	[23.015, 6.908, "rubber_white", S_RUBBER], [23.015, 7.049, "logo", S_METAL],
	[23.015, 10.366, "rubber_white", S_RUBBER], [23.015, 10.508, "wall", S_RUBBER],
	[22.885, 10.512, "wall", S_RUBBER], [22.883, 18.299, "rubber_white", S_RUBBER],
	[22.882, 18.681, "rubber_white", S_RUBBER], [22.952, 19.081, "rubber_white", S_RUBBER],
	[23.117, 19.391, "rubber_white", S_RUBBER], [23.427, 19.677, "rubber_white", S_RUBBER],
	[23.786, 19.893, "rubber_white", S_RUBBER], [24.056, 20.028, "wall", S_RUBBER],
	[25.677, 20.838, "wall", S_RUBBER], [25.847, 20.867, "wall", S_RUBBER], [25.897, 20.717, "wall", S_RUBBER],
	[25.898, 20.306, "wall", S_RUBBER], [25.898, 20.232, "wall", S_RUBBER], [25.855, 20.157, "rubber", S_RUBBER],
	[25.614, 19.862, "stands", S_CONCRETE], [25.614, 17.464, "screen", S_METAL],
	[25.614, 14.432, "stands", S_CONCRETE], [25.614, 14.226, "rubber", S_RUBBER],
	[25.719, 13.951, "rubber", S_RUBBER], [26.579, 14.381, "rubber", S_RUBBER],
	[26.614, 14.297, "rubber", S_RUBBER], [26.945, 14.286, "rubber", S_RUBBER],
	[27.076, 14.203, "rubber", S_RUBBER], [27.157, 14.041, "rubber", S_RUBBER],
	[27.157, 13.780, "rubber", S_RUBBER], [27.092, 13.546, "rubber_white", S_RUBBER],
	[32.000, 16.000, "wall_dark", S_METAL], [32.000, 8.243, "stands", S_CONCRETE],
	[26.613, 5.550, "rubber", S_RUBBER], [26.425, 5.213, "wall", S_RUBBER], [22.772, 3.386, "wall", S_RUBBER],
	[22.551, 3.379, "rubber", S_RUBBER], [22.432, 3.525, "rubber", S_RUBBER], [22.370, 3.723, "rubber", S_RUBBER],
	[22.404, 4.014, "rubber", S_RUBBER], [22.595, 4.578, "structure", S_ASPHALT]
]

## Curved borders (but the 1x1 outer corner) lower the wall's top (above the screen, 12.66 m) by
## TOP_DROP in their middle (16 -> 13.81 m), ramping between these distances (m along the face)
## from each end (measured).
const TOP_DROP := 2.19
const TOP_DIP_CORNER := [2.2, 6.0]
const TOP_DIP_GT := [5.3, 10.4]

## Circuit slope road heights (z, y) of the base blocks: start eases 0 -> 0.5, end 0.5 -> 0.
const SLOPE_START := [[0, 8.0], [1.92, 8.0], [3.98, 8.0], [6, 8.09], [8, 8.27], [10, 8.52], [12, 8.85], [14, 9.27],
	[16, 9.74], [18, 10.27], [20, 10.86], [22, 11.52], [24, 12.24], [26, 13.05], [28, 13.94], [30, 14.93], [32, 16.0]]
const SLOPE_STRAIGHT := [[0, 8.0], [32, 24.0]]
const SLOPE_END := [[0, 8.0], [2.01, 8.99], [4, 9.92], [6, 10.78], [8, 11.56], [10, 12.28], [12, 12.93], [14, 13.52],
	[16, 14.05], [18, 14.53], [20, 14.95], [22, 15.31], [24, 15.59], [26, 15.81], [28.02, 15.93], [30.08, 15.97], [32, 16.0]]


func handles(shape: String) -> bool:
	return shape.begins_with("Circuit/Road/Base") or shape.begins_with("Circuit/Border/") \
		or shape.begins_with("Circuit/Slope/")


var _cells: Array = []        ## the shape's footprint cells (bottom layer, Vector2i x, z units)


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var geo := TmGeo.new()
	_cells = []
	for u in TmBlockCatalogue.shape_units(shape):
		if int(u[1]) == 0:
			_cells.append(Vector2i(int(u[0]), int(u[2])))
	var ground := shape.contains("Ground")
	var dy := 1.0 if ground else 0.0
	var parts := shape.split("/")
	if shape.begins_with("Circuit/Road/Base"):
		if not (shape.ends_with("BaseAir") or shape.ends_with("BaseGround")):
			return null   # bump/hole/pillar variants: not yet
		geo.box(Vector3(0, dy, 0), Vector3(32, 8, 32), "wall_dark", S_METAL, "platform", S_ASPHALT)
	elif shape.begins_with("Circuit/Border/"):
		if not _border(geo, parts[2], parts[3], dy):
			return null
		if ground:
			_ground_floor(geo, parts[2], parts[3])
	else:
		if not _slope(geo, parts[2], parts[3], dy):
			return null
		if ground and not parts[3].begins_with("Base"):
			_ground_floor(geo, "Straight", parts[3])
	return geo.build()


## Ground borders stand on the terrain (the map's ground at 1 m block-local, built separately);
## straights add the 4.7 m concrete strip in front of the wall.
func _ground_floor(geo: TmGeo, kind: String, _variant: String) -> void:
	if kind == "Straight":
		geo.quad(Vector3(32, 1.0, 17.86), Vector3(0, 1.0, 17.86), Vector3(0, 1.0, FACE - 0.47), Vector3(32, 1.0, FACE - 0.47),
			"platform", S_CONCRETE)


## Border walls: Straight, Corner In/Out, GTCurve kIn/kOut, Diag In/Out.
func _border(geo: TmGeo, kind: String, variant: String, dy: float) -> bool:
	var section := _section(dy)
	if kind == "Straight":
		_line_wall(geo, section, Vector3(32, 0, FACE), Vector3(0, 0, FACE), Vector3(0, 0, 1), dy, true)
		return true
	var inner := variant.begins_with("In") or variant.contains("In")
	var k := 1
	if kind == "GTCurve":
		k = int(variant.substr(0, 1))
	if kind == "Corner" or kind == "GTCurve":
		var s := 32.0 * k
		# curves wider than the 1x1 outer corner lower their top in the middle (see TOP_DIP)
		var dip: Array = TOP_DIP_CORNER if kind == "Corner" else TOP_DIP_GT
		if inner:
			var r := s - (32.0 - FACE)
			var a := _arc_dip(Vector2(0, 0), r, 0.0, PI * 0.5, 8 * k, dip)
			geo.wall_sweep(section, a[0], a[1], true, "wall_dark", S_METAL, _dip_fn(a[2]))
			# ledge: the footprint outside the stands' foot circle
			var poly := PackedVector2Array()
			for i in 8 * k + 1:
				var ang := PI * 0.5 * (1.0 - float(i) / (8 * k))
				poly.append(Vector2(cos(ang), sin(ang)) * (r + LEDGE_D))
			poly.append(Vector2(s, 0))
			poly.append(Vector2(s, s))
			poly.append(Vector2(0, s))
			_ledge(geo, poly, dy)
		else:
			var r := s - FACE
			var a := _arc_dip(Vector2(0, s), r, -PI * 0.5, 0.0, 6 * k, [] if kind == "Corner" else dip)
			var outs := []
			for d in a[1]:
				outs.append(-(d as Vector3))
			geo.wall_sweep(section, a[0], outs, true, "wall_dark", S_METAL, _dip_fn(a[2]))
			var poly := PackedVector2Array()
			for i in 6 * k + 1:
				var ang := -PI * 0.5 + PI * 0.5 * float(i) / (6 * k)
				poly.append(Vector2(0, s) + Vector2(cos(ang), sin(ang)) * (r - LEDGE_D))
			poly.append(Vector2(0, s))
			_ledge(geo, poly, dy)
		return true
	if kind == "Diag":
		# 45 deg walls across the cell's corner: the straight wall's section sheared along each
		# cell edge it meets (so the ends match the neighbouring straights), mitred at the middle
		if inner:
			_diag_wall(geo, section, Vector3(0, 0, FACE), Vector3(FACE, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
			var e := FACE + LEDGE_D
			_ledge(geo, PackedVector2Array([Vector2(e, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32), Vector2(0, e)]), dy)
		else:
			_diag_wall(geo, section, Vector3(0, 0, FACE), Vector3(32 - FACE, 0, 32), Vector3(0, 0, 1), Vector3(-1, 0, 0))
			var e := LEDGE_D
			_ledge(geo, PackedVector2Array([Vector2(0, FACE + e), Vector2(32 - FACE - e, 32), Vector2(0, 32)]), dy)
		return true
	return false


## Arc points (TMNF x, z plane at y 0) about c from angle a0 to a1 in `steps` plus knots at the
## dip's ramp ends; returns [points, radial dirs, top drop per point]. The drop ramps 0 -> TOP_DROP
## between dip[0] and dip[1] metres (along the face) from each end.
static func _arc_dip(c: Vector2, r: float, a0: float, a1: float, steps: int, dip: Array) -> Array:
	var span := absf(a1 - a0)
	var ts := []
	for i in steps + 1:
		ts.append(float(i) / steps)
	for m in dip:
		ts.append(float(m) / (r * span))
		ts.append(1.0 - float(m) / (r * span))
	ts.sort()
	var pts := []
	var rad := []
	var drops := []
	var last := -1.0
	for t: float in ts:
		if t - last < 1e-4:
			continue
		last = t
		var ang := lerpf(a0, a1, t)
		var d := Vector3(cos(ang), 0.0, sin(ang))
		pts.append(Vector3(c.x, 0.0, c.y) + d * r)
		rad.append(d)
		var from_end := minf(t, 1.0 - t) * r * span
		drops.append(0.0 if dip.is_empty() else TOP_DROP * clampf((from_end - float(dip[0])) / (float(dip[1]) - float(dip[0])), 0.0, 1.0))
	return [pts, rad, drops]


## The section's heights at a curve point: the top (above the screen) lowered by its drop.
static func _dip_fn(drops: Array) -> Callable:
	return func(y: float, i: int) -> float: return y - float(drops[i]) if y > 14.5 else y


## A diagonal wall a -> b: at a its section runs along l_a (the outward of the straight wall that
## continues it there), at b along l_b; the two sheared halves meet on the mitre at the middle.
func _diag_wall(geo: TmGeo, section: Array, a: Vector3, b: Vector3, l_a: Vector3, l_b: Vector3) -> void:
	geo.wall_sweep(section, [a, (a + b) * 0.5, b], [l_a, (l_a + l_b) * 0.5, l_b])


## The wall section (d, y) with the ground variants' heights (see _lift).
func _section(dy: float) -> Array:
	var out := []
	for p in WALL:
		out.append([Vector2(float(p[0]), _lift(float(p[1]), dy)), String(p[2]), int(p[3])])
	return out


## Ground variants stand on the terrain (dy = 1 m): the wall's lower part (below the 8 m ledge)
## rises by dy and its foot and floors sit on the terrain; the ledge top and the upper wall keep
## their heights (measured).
static func _lift(y: float, dy: float) -> float:
	if dy == 0.0 or y >= 7.5:
		return y
	if y <= FLOOR_Y + 0.01:
		return dy
	return y + dy


## A straight wall from a to b (TMNF x, z; y = base), outward horizontal; full = with the ledge
## out to the cell edge (8.985 m behind the face).
func _line_wall(geo: TmGeo, section: Array, a: Vector3, b: Vector3, outward: Vector3, dy: float, full: bool) -> void:
	var sec := section
	if full:
		sec = []
		for p in section:
			if (p[0] as Vector2).x >= LEDGE_D - 0.01 and (p[0] as Vector2).y < LEDGE_Y + 0.01:
				continue
			sec.append(p)
		# ledge to the cell edge: top at 8 m, outer face, floor
		var e := 32.0 - FACE
		var at := sec.find(sec.filter(func(q): return (q[0] as Vector2).x > 4.0 and absf((q[0] as Vector2).y - 8.33) < 0.01)[0])
		sec.insert(at + 1, [Vector2(4.075, LEDGE_Y), "wall_dark", S_METAL])
		sec.insert(at + 2, [Vector2(e, LEDGE_Y), "wall_dark", S_METAL])
		sec.insert(at + 3, [Vector2(e, _lift(FLOOR_Y, dy)), "stands", S_CONCRETE])
		sec.insert(at + 4, [Vector2(3.595, _lift(FLOOR_Y, dy)), "structure", S_METAL])
	geo.wall_sweep(sec, [a, b], [outward, outward])


## Ledge behind a curved wall: a solid prism over the polygon (TMNF x, z), floor 0.24 m (ground:
## the terrain), top 8 m; clipped to the block's footprint cells (big curves leave out the cells
## near their centre or far corner).
func _ledge(geo: TmGeo, poly: PackedVector2Array, dy: float) -> void:
	if _cells.is_empty():
		_prism(geo, poly, dy)
		return
	var pieces := []
	for c: Vector2i in _cells:
		var o := Vector2(c) * 32.0
		var sq := PackedVector2Array([o, o + Vector2(32, 0), o + Vector2(32, 32), o + Vector2(0, 32)])
		for p: PackedVector2Array in Geometry2D.intersect_polygons(poly, sq):
			if absf(_area(p)) > 0.01:
				pieces.append(p)
	# merge the per-cell pieces into whole polygons
	var merged := []
	for p: PackedVector2Array in pieces:
		var cur := p
		var rest := []
		for q: PackedVector2Array in merged:
			var m := Geometry2D.merge_polygons(cur, q)
			if m.size() == 1:
				cur = m[0]
			else:
				rest.append(q)
		rest.append(cur)
		merged = rest
	for p: PackedVector2Array in merged:
		_prism(geo, p, dy)


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5


func _prism(geo: TmGeo, poly: PackedVector2Array, dy: float) -> void:
	var lo := _lift(FLOOR_Y, dy)
	var hi := LEDGE_Y
	geo.flat_polygon(poly, hi, "wall_dark", S_METAL)
	geo.flat_polygon(poly, lo, "structure", S_METAL, true)
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		var a := Vector3(p.x, lo, p.y)
		var b := Vector3(q.x, lo, q.y)
		var c := Vector3(q.x, hi, q.y)
		var d := Vector3(p.x, hi, p.y)
		# outward: away from the polygon's centroid
		var mid := (a + b) * 0.5
		var cen := Vector3.ZERO
		for v in poly:
			cen += Vector3(v.x, 0, v.y)
		cen /= poly.size()
		if (b - a).cross(c - a).dot(Vector3(mid.x - cen.x, 0, mid.z - cen.z)) < 0.0:
			geo.quad(a, d, c, b, "wall_dark", S_METAL)
		else:
			geo.quad(a, b, c, d, "wall_dark", S_METAL)


## Slope blocks: Base (the road ramp) and the border walls along (Left/Right) or across
## (Top/Bottom) the slope. kind: Start, Straight, End.
func _slope(geo: TmGeo, kind: String, variant: String, dy: float) -> bool:
	var prof: Array = SLOPE_START if kind == "Start" else (SLOPE_END if kind == "End" else SLOPE_STRAIGHT)
	if kind not in ["Start", "Straight", "End"]:
		return false
	if variant.begins_with("Base"):
		_ramp(geo, prof, dy)
		return true
	var section := _section(0.0)
	if variant.ends_with("Left") or variant.ends_with("Right"):
		var x := 32.0 - FACE if variant.ends_with("Left") else FACE
		var out := Vector3(-1, 0, 0) if variant.ends_with("Left") else Vector3(1, 0, 0)
		var path := []
		var outs := []
		for p in prof:
			path.append(Vector3(x, float(p[1]) - 8.0, float(p[0])))
			outs.append(out)
		_full_wall(geo, section, path, outs, dy)
		return true
	if variant.ends_with("Top") or variant.ends_with("Bottom"):
		if kind != "Straight":
			return false
		var table: Array = SLOPE_TOP_WALL if variant.ends_with("Top") else SLOPE_BOTTOM_WALL
		var sec := table.map(func(q: Array) -> Array: return [Vector2(q[0], q[1] + dy), q[2], q[3]])
		geo.wall_sweep(sec, [Vector3(0, 0, 0), Vector3(32, 0, 0)], [Vector3(0, 0, 1), Vector3(0, 0, 1)])
		return true
	return false


## A wall with its ledge swept along a (sloped) path. Ground variants keep the air heights, with
## the foot raised onto the terrain (dy) where the path runs below it.
func _full_wall(geo: TmGeo, section: Array, path: Array, outs: Array, dy: float) -> void:
	var sec := []
	for p in section:
		if (p[0] as Vector2).x >= LEDGE_D - 0.01 and (p[0] as Vector2).y < LEDGE_Y + 0.01:
			continue
		sec.append(p)
	var at := 0
	for i in sec.size():
		if (sec[i][0] as Vector2).x > 4.0 and absf((sec[i][0] as Vector2).y - 8.33) < 0.01:
			at = i
	var e := 32.0 - FACE
	sec.insert(at + 1, [Vector2(4.075, LEDGE_Y), "wall_dark", S_METAL])
	sec.insert(at + 2, [Vector2(e, LEDGE_Y), "wall_dark", S_METAL])
	sec.insert(at + 3, [Vector2(e, FLOOR_Y), "stands", S_CONCRETE])
	sec.insert(at + 4, [Vector2(3.595, FLOOR_Y), "structure", S_METAL])
	var y_at := Callable()
	if dy > 0.0:
		y_at = func(y: float, i: int) -> float: return maxf(y, dy - (path[i] as Vector3).y)
	geo.wall_sweep(sec, path, outs, true, "wall_dark", S_METAL, y_at)


## The circuit ramp: road surface y(z) on x 0..32, solid down to the block floor.
func _ramp(geo: TmGeo, prof: Array, dy: float) -> void:
	var y0 := dy
	for i in prof.size() - 1:
		var z0 := float(prof[i][0])
		var z1 := float(prof[i + 1][0])
		var h0 := float(prof[i][1])
		var h1 := float(prof[i + 1][1])
		# road (up), sides (x = 0 facing -x, x = 32 facing +x), floor (down)
		geo.quad(Vector3(32, h0, z0), Vector3(0, h0, z0), Vector3(0, h1, z1), Vector3(32, h1, z1), "platform", S_ASPHALT)
		geo.quad(Vector3(0, y0, z0), Vector3(0, y0, z1), Vector3(0, h1, z1), Vector3(0, h0, z0), "wall_dark", S_METAL)
		geo.quad(Vector3(32, y0, z0), Vector3(32, h0, z0), Vector3(32, h1, z1), Vector3(32, y0, z1), "wall_dark", S_METAL)
	var hn := float(prof[prof.size() - 1][1])
	var h0 := float(prof[0][1])
	geo.quad(Vector3(0, y0, 0), Vector3(32, y0, 0), Vector3(32, y0, 32), Vector3(0, y0, 32), "structure", S_METAL)
	geo.quad(Vector3(0, y0, 0), Vector3(0, h0, 0), Vector3(32, h0, 0), Vector3(32, y0, 0), "wall_dark", S_METAL)
	geo.quad(Vector3(32, y0, 32), Vector3(32, hn, 32), Vector3(0, hn, 32), Vector3(0, y0, 32), "wall_dark", S_METAL)
