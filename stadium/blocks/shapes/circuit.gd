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

## Circuit slope road heights (z, y) of the base blocks: start eases 0 -> 0.5, end 0.5 -> 0.
const SLOPE_START := [[0, 8.0], [1.92, 8.0], [3.98, 8.0], [6, 8.09], [8, 8.27], [10, 8.52], [12, 8.85], [14, 9.27],
	[16, 9.74], [18, 10.27], [20, 10.86], [22, 11.52], [24, 12.24], [26, 13.05], [28, 13.94], [30, 14.93], [32, 16.0]]
const SLOPE_STRAIGHT := [[0, 8.0], [32, 24.0]]
const SLOPE_END := [[0, 8.0], [2.01, 8.99], [4, 9.92], [6, 10.78], [8, 11.56], [10, 12.28], [12, 12.93], [14, 13.52],
	[16, 14.05], [18, 14.53], [20, 14.95], [22, 15.31], [24, 15.59], [26, 15.81], [28.02, 15.93], [30.08, 15.97], [32, 16.0]]


func handles(shape: String) -> bool:
	return shape.begins_with("Circuit/Road/Base") or shape.begins_with("Circuit/Border/") \
		or shape.begins_with("Circuit/Slope/")


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var geo := TmGeo.new()
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
		if inner:
			var r := s - (32.0 - FACE)
			var a := TmGeo.arc(Vector2(0, 0), r, 0.0, PI * 0.5, dy, 8 * k)
			geo.wall_sweep(section, a[0], a[1])
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
			var a := TmGeo.arc(Vector2(0, s), r, -PI * 0.5, 0.0, dy, 6 * k)
			var outs := []
			for d in a[1]:
				outs.append(-(d as Vector3))
			geo.wall_sweep(section, a[0], outs)
			var poly := PackedVector2Array()
			for i in 6 * k + 1:
				var ang := -PI * 0.5 + PI * 0.5 * float(i) / (6 * k)
				poly.append(Vector2(0, s) + Vector2(cos(ang), sin(ang)) * (r - LEDGE_D))
			poly.append(Vector2(0, s))
			_ledge(geo, poly, dy)
		return true
	if kind == "Diag":
		if inner:
			var out := Vector3(1, 0, 1).normalized()
			_line_wall(geo, section, Vector3(0, 0, FACE), Vector3(FACE, 0, 0), out, dy, false)
			var e := FACE + LEDGE_D * sqrt(2.0)
			_ledge(geo, PackedVector2Array([Vector2(e, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32), Vector2(0, e)]), dy)
		else:
			var out := Vector3(-1, 0, 1).normalized()
			_line_wall(geo, section, Vector3(0, 0, FACE), Vector3(32 - FACE, 0, 32), out, dy, false)
			var e := LEDGE_D * sqrt(2.0)
			_ledge(geo, PackedVector2Array([Vector2(0, 32 - (32 - FACE) + e), Vector2(32 - FACE - e, 32), Vector2(0, 32)]), dy)
		return true
	return false


## The wall section with the ledge (straights: the ledge is part of the section) or without.
func _section(_dy: float) -> Array:
	var out := []
	for p in WALL:
		out.append([Vector2(float(p[0]), float(p[1])), String(p[2]), int(p[3])])
	return out


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
		sec.insert(at + 3, [Vector2(e, FLOOR_Y), "stands", S_CONCRETE])
		sec.insert(at + 4, [Vector2(3.595, FLOOR_Y), "structure", S_METAL])
	var lifted := []
	for p in sec:
		lifted.append([(p[0] as Vector2) + Vector2(0, dy), p[1], p[2]])
	geo.wall_sweep(lifted, [a, b], [outward, outward])


## Ledge behind a curved wall: a solid prism over the polygon (TMNF x, z), floor 0.24 m, top 8 m.
func _ledge(geo: TmGeo, poly: PackedVector2Array, dy: float) -> void:
	geo.flat_polygon(poly, LEDGE_Y + dy, "wall_dark", S_METAL)
	geo.flat_polygon(poly, FLOOR_Y + dy, "structure", S_METAL, true)
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		var a := Vector3(p.x, FLOOR_Y + dy, p.y)
		var b := Vector3(q.x, FLOOR_Y + dy, q.y)
		var c := Vector3(q.x, LEDGE_Y + dy, q.y)
		var d := Vector3(p.x, LEDGE_Y + dy, p.y)
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
	var section := _section(dy)
	if variant.ends_with("Left") or variant.ends_with("Right"):
		var x := 32.0 - FACE if variant.ends_with("Left") else FACE
		var out := Vector3(-1, 0, 0) if variant.ends_with("Left") else Vector3(1, 0, 0)
		var path := []
		var outs := []
		for p in prof:
			path.append(Vector3(x, float(p[1]) - 8.0 + dy, float(p[0])))
			outs.append(out)
		_full_wall(geo, section, path, outs, dy)
		return true
	if variant.ends_with("Top") or variant.ends_with("Bottom"):
		# level walls across the slope (measured base heights)
		var top := variant.ends_with("Top")
		var z := 32.0 - FACE if top else FACE
		var base := 4.63 if top else 3.65
		_line_wall(geo, section, Vector3(0, base, z), Vector3(32, base, z),
			Vector3(0, 0, -1) if top else Vector3(0, 0, 1), dy, true)
		return true
	return false


## A wall with its ledge swept along a (sloped) path.
func _full_wall(geo: TmGeo, section: Array, path: Array, outs: Array, _dy: float) -> void:
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
	geo.wall_sweep(sec, path, outs)


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
