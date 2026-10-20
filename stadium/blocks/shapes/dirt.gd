extends RefCounted
## Stadium dirt roads (Road/Dirt: a track sunk 0.6 m into the grass between low berms; Road/DirtHigh:
## one raised on a 7.4 m embankment), their hills, tilts, curves and transitions. TMNF's pieces are
## hand-sculpted terrain, so each is our own bicubic surface through measured control heights 2 m
## apart over its footprint, grass, dirt or asphalt per 2 m cell (blocks/data/dirt_heights.json, from
## tools/research/tmnf/terrain_heights.py). The checkpoints are the straight's terrain under a
## gate; where a dirt road meets the road, TMNF's curbs (_to_road_curbs). Fences, signs and awnings
## on some pieces are not recreated yet.

const RoadShapes := preload("res://blocks/shapes/road.gd")

const S_GRASS := 2
const S_DIRT := 6
const S_ROAD := 16
## Survey cell class -> [material, surface id]: grass, dirt (the track, its berms loose dirt: the
## material blends by slope) and the asphalt where a piece meets Road/Main.
const CLASSES := {"g": ["grass", S_GRASS], "d": ["dirt_road", S_DIRT], "r": ["asphalt", S_ROAD]}
const PATH := "res://blocks/data/dirt_heights.json"
const QUAD := 1.0               ## render/collision quad size (m)
const GRASS_EPS := 0.05         ## how far off the grass level (1 m) a corner still counts as on it
## Checkpoints: the terrain they stand on, and how far the Road/Main gate is raised for them.
const CHECKPOINTS := {
	"Road/Dirt/RoadDirtCheckpoint/Ground": ["Road/Dirt/StraightGround", 1.0],
	"Road/DirtHigh/RoadDirtCheckpointHigh/Ground": ["Road/DirtHigh/StraightGround", 5.8],
}

## Where a dirt road meets Road/Main (TMNF's RoadDirtToRoad, measured): the road's ground curbs
## along both sides, full up to TO_ROAD_FULL, then a narrower, lower curb running into the dirt's
## berm (the section's d mapped to TO_ROAD_D.x + (d - 1) * TO_ROAD_D.y, its height above 1 m scaled
## by TO_ROAD_H, sinking TO_ROAD_SINK more by the block's end).
const TO_ROAD := ["Road/Dirt/RoadDirtToRoad/Ground"]
const TO_ROAD_FULL := 17.0
const TO_ROAD_D := Vector2(1.97, 0.476)
const TO_ROAD_H := 0.8
const TO_ROAD_SINK := 0.3

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
		if shape in TO_ROAD:
			_to_road_curbs(geo)
	else:
		return null
	var node := geo.build()
	if CHECKPOINTS.has(shape):
		TmGateDress.crown(node, "cp", 16.0, Vector3(0.0, 0.0, float(CHECKPOINTS[shape][1])), true)
	return node


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
			var c := line[ci]
			var q := [pts[j][i], pts[j + 1][i], pts[j + 1][i + 1], pts[j][i + 1]]
			# the dirt follows the ground's shape, as TMNF's meshes do, not the survey's 2 m cells
			# (their staircase): next to dirt, the ground off the grass's level is dirt and on it
			# grass, the line between them cut through the quads along the level
			if c == "d" or (c == "g" and _near_dirt(cls, cj, ci)):
				_split_tri(geo, q[0], q[1], q[2])
				_split_tri(geo, q[0], q[2], q[3])
				continue
			var m: Array = CLASSES.get(c, CLASSES["d"])
			geo.quad(q[0], q[1], q[2], q[3], m[0], m[1])


## A triangle of the terrain cut where it leaves the grass's level (|y - 1| = GRASS_EPS): dirt off
## it, grass on it.
func _split_tri(geo: TmGeo, a: Vector3, b: Vector3, c: Vector3) -> void:
	var tri := [a, b, c]
	var off := func(p: Vector3) -> float: return absf(p.y - 1.0) - GRASS_EPS
	var dirt := []
	var grass := []
	for k in 3:
		var p: Vector3 = tri[k]
		var r: Vector3 = tri[(k + 1) % 3]
		var dp: float = off.call(p)
		var dr: float = off.call(r)
		if dp > 0.0:
			dirt.append(p)
		else:
			grass.append(p)
		if (dp > 0.0) != (dr > 0.0):
			var m := p.lerp(r, dp / (dp - dr))
			dirt.append(m)
			grass.append(m)
	for poly: Array in [[dirt, CLASSES["d"]], [grass, CLASSES["g"]]]:
		var pp: Array = poly[0]
		for k in range(1, pp.size() - 1):
			geo.tri(pp[0], pp[k], pp[k + 1], poly[1][0], poly[1][1])


## Whether a survey cell (row j, column i) touches a dirt cell (its eight neighbours).
static func _near_dirt(cls: Array, j: int, i: int) -> bool:
	for dj in [-1, 0, 1]:
		for di in [-1, 0, 1]:
			var jj: int = j + dj
			var ii: int = i + di
			if jj >= 0 and jj < cls.size() and ii >= 0 and ii < String(cls[jj]).length() and String(cls[jj])[ii] == "d":
				return true
	return false


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


## TMNF's curbs where the dirt meets the road (TO_ROAD_*): both sides, the full curb then the narrow
## one sinking into the berm.
func _to_road_curbs(geo: TmGeo) -> void:
	var curb: Array = RoadShapes.new()._curb_section(true)
	var lat := [Vector3(1, 0, 0), Vector3(1, 0, 0)]
	for side: float in [1.0, -1.0]:
		var full := curb.map(func(q: Array) -> Array:
			var p: Vector2 = q[0]
			return [Vector2((p.x - 16.0) * side, p.y), q[1], q[2]] + q.slice(3))
		geo.wall_sweep(full, [Vector3(16, 0, 0), Vector3(16, 0, TO_ROAD_FULL)], lat, true, "road_metal", 4)
		var narrow := curb.map(func(q: Array) -> Array:
			var p: Vector2 = q[0]
			var d := TO_ROAD_D.x + (p.x - 1.0) * TO_ROAD_D.y
			return [Vector2((d - 16.0) * side, 1.0 + (p.y - 1.0) * TO_ROAD_H), q[1], q[2]] + q.slice(3))
		geo.wall_sweep(narrow, [Vector3(16, 0, TO_ROAD_FULL), Vector3(16, -TO_ROAD_SINK, 32.0)], lat, true, "road_metal", 4)
