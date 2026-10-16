extends RefCounted
## Stadium dirt roads (Road/Dirt: a track sunk 0.6 m into the grass between low berms; Road/DirtHigh:
## one raised on a 7.4 m embankment), their hills, tilts, curves and transitions. TMNF's pieces are
## hand-sculpted terrain, so each is our own bicubic surface through measured control heights 2 m
## apart over its footprint, grass, dirt or asphalt per 2 m cell (blocks/data/dirt_heights.json, from
## tools/research/tmnf/terrain_heights.py). The checkpoints are the straight's terrain under a
## gate. Fences, signs and awnings on some pieces are not recreated yet.

const RoadShapes := preload("res://blocks/shapes/road.gd")

const S_GRASS := 2
const S_DIRT := 6
const S_ROAD := 16
## Survey cell class -> [material, surface id]: grass, dirt, and the asphalt where a piece meets
## Road/Main.
const CLASSES := {"g": ["grass", S_GRASS], "d": ["dirt", S_DIRT], "r": ["asphalt", S_ROAD]}
const PATH := "res://blocks/data/dirt_heights.json"
const QUAD := 1.0               ## render/collision quad size (m)
## Checkpoints: the terrain they stand on, and how far the Road/Main gate is raised for them.
const CHECKPOINTS := {
	"Road/Dirt/RoadDirtCheckpoint/Ground": ["Road/Dirt/StraightGround", 1.0],
	"Road/DirtHigh/RoadDirtCheckpointHigh/Ground": ["Road/DirtHigh/StraightGround", 5.8],
}

static var _shapes: Dictionary = {}


static func shapes() -> Dictionary:
	if _shapes.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_shapes = (parsed as Dictionary).get("shapes", {})
	return _shapes


func handles(shape: String) -> bool:
	return shapes().has(shape) or CHECKPOINTS.has(shape)


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var geo := TmGeo.new()
	if CHECKPOINTS.has(shape):
		var c: Array = CHECKPOINTS[shape]
		_surface(geo, shapes()[c[0]])
		var gate := TmGeo.new()
		RoadShapes.new()._gate(gate, 16.0)
		gate.shear_y(0.0, 0.0, float(c[1]))
		geo.merge(gate)
	elif shapes().has(shape):
		_surface(geo, shapes()[shape])
	else:
		return null
	return geo.build()


## The surface through a shape's control grid, QUAD m quads, grass or dirt by the grid cell.
func _surface(geo: TmGeo, s: Dictionary) -> void:
	var g: Array = s["g"]
	var cls: Array = s["cls"]
	var step := float(s["step"])
	var nx := int(round(float(s["w"]) / QUAD))
	var nz := int(round(float(s["d"]) / QUAD))
	var pts := []
	for j in nz + 1:
		var row := []
		for i in nx + 1:
			var x := i * QUAD
			var z := j * QUAD
			row.append(Vector3(x, _bicubic(g, step, x, z), z))
		pts.append(row)
	for j in nz:
		for i in nx:
			var cj := mini(int((j + 0.5) * QUAD / step), cls.size() - 1)
			var line := String(cls[cj])
			var ci := mini(int((i + 0.5) * QUAD / step), line.length() - 1)
			var m: Array = CLASSES.get(line[ci], CLASSES["d"])
			geo.quad(pts[j][i], pts[j + 1][i], pts[j + 1][i + 1], pts[j][i + 1], m[0], m[1])


static func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


## Catmull-Rom through the grid both ways (rows along z, columns along x, `step` m apart).
static func _bicubic(g: Array, step: float, x: float, z: float) -> float:
	var nz := g.size()
	var nx := (g[0] as Array).size()
	var fx := x / step
	var fz := z / step
	var i := mini(int(fx), nx - 2)
	var j := mini(int(fz), nz - 2)
	var at := func(jj: int, ii: int) -> float: return float(g[clampi(jj, 0, nz - 1)][clampi(ii, 0, nx - 1)])
	var rows := []
	for k in [-1, 0, 1, 2]:
		rows.append(_cr(at.call(j + k, i - 1), at.call(j + k, i), at.call(j + k, i + 1), at.call(j + k, i + 2), fx - i))
	return _cr(rows[0], rows[1], rows[2], rows[3], fz - j)
