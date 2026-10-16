extends RefCounted
## Stadium terrain zones: dirt and water fields (flat), and the frontier tiles that shape dirt
## hills, pools and dirt borders. Zone blocks sit at their terrain level: level 0 is the stadium
## ground (9 m block-local, as measured); a dirt hill tile at level L rises from level L - 2 to L
## (TmBlockCatalogue.block_transform). Frontier tiles are our own bicubic surfaces through
## measured control heights (blocks/data/zone_heights.json, 9 x 9 points 4 m apart).

const S_CONCRETE := 0
const S_GRASS := 2
const S_DIRT := 6
const S_SLIDING := 10
const GROUND := 9.0             ## level-0 terrain, block-local
const WATER := 8.0              ## water surface (1 m below the ground)
const RES := 16                 ## surface quads per side (2 m)
const PATH := "res://blocks/data/zone_heights.json"

static var _heights: Dictionary = {}


static func heights() -> Dictionary:
	if _heights.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_heights = (parsed as Dictionary).get("shapes", {})
	return _heights


func handles(shape: String) -> bool:
	return shape.begins_with("Zone/")


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var geo := TmGeo.new()
	match shape:
		"Zone/Dirt/DirtBase":
			_flat(geo, GROUND, "dirt", S_DIRT)
		"Zone/Grass/Base":
			_flat(geo, GROUND, "grass", S_GRASS)
		"Zone/Water/Base":
			_flat(geo, 2.0, "fabric", S_SLIDING)
			_flat(geo, WATER, "water", TmGeo.NO_COLLISION)
		_:
			var key := shape
			if not heights().has(key):
				# decorated dirt dead ends (tent, door, spotlight): the plain dead end's ground
				if shape.begins_with("Zone/DirtBorder/DirtDeadend"):
					key = "Zone/DirtBorder/DirtDeadend"
				if not heights().has(key):
					return null
			var pool := shape.begins_with("Zone/Pool/")
			_surface(geo, heights()[key], "dirt" if not pool else "grass", S_DIRT if not pool else S_GRASS, pool)
			if pool:
				_flat(geo, WATER, "water", TmGeo.NO_COLLISION)
	return geo.build()


func _flat(geo: TmGeo, y: float, mat: String, surface: int) -> void:
	geo.quad(Vector3(0, y, 0), Vector3(0, y, 32), Vector3(32, y, 32), Vector3(32, y, 0), mat, surface)


## A 32 x 32 m surface through the control grid (Catmull-Rom both ways), RES quads per side;
## pools line the basin below the water with fabric.
func _surface(geo: TmGeo, g: Array, mat: String, surface: int, pool: bool) -> void:
	var pts := []
	for j in RES + 1:
		var row := []
		for i in RES + 1:
			var x := 32.0 * i / RES
			var z := 32.0 * j / RES
			row.append(Vector3(x, _bicubic(g, x, z), z))
		pts.append(row)
	for j in RES:
		for i in RES:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j + 1][i]
			var c: Vector3 = pts[j + 1][i + 1]
			var d: Vector3 = pts[j][i + 1]
			var m := mat
			var s := surface
			if pool and minf(minf(a.y, b.y), minf(c.y, d.y)) < GROUND - 0.3:
				m = "fabric"
				s = S_SLIDING
			geo.quad(a, b, c, d, m, s)


static func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


static func _bicubic(g: Array, x: float, z: float) -> float:
	var n := g.size()
	var fx := x / 32.0 * (n - 1)
	var fz := z / 32.0 * (n - 1)
	var i := mini(int(fx), n - 2)
	var j := mini(int(fz), n - 2)
	var at := func(jj: int, ii: int) -> float: return float(g[clampi(jj, 0, n - 1)][clampi(ii, 0, n - 1)])
	var rows := []
	for k in [-1, 0, 1, 2]:
		rows.append(_cr(at.call(j + k, i - 1), at.call(j + k, i), at.call(j + k, i + 1), at.call(j + k, i + 2), fx - i))
	return _cr(rows[0], rows[1], rows[2], rows[3], fz - j)
