extends RefCounted
## Stadium terrain zones: dirt and water fields (flat), and the frontier tiles that shape dirt
## hills, pools and dirt borders. Zone blocks sit at their terrain level: level 0 is the stadium
## ground (9 m block-local, as measured); a dirt hill tile at level L rises from level L - 2 to L
## (TmBlockCatalogue.block_transform). Frontier tiles are our own surfaces through measured
## heights (blocks/data/zone_heights.json, 33 x 33 points 1 m apart: TMNF's hand-sculpted hills
## need that fine a survey), a quad between each four.

const S_CONCRETE := 0
const S_GRASS := 2
const S_DIRT := 6
const S_SLIDING := 10
const GROUND := 9.0             ## level-0 terrain, block-local
const WATER := 8.0              ## water surface (1 m below the ground)
const CLIP_Y := 1.0             ## a clip's triangle (measured; on the terrain where it is placed)
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
		"Zone/Grass/Clip", "Zone/Dirt/DirtClip":
			# the clips TMNF sets where terrain meets other blocks: one triangle from the +z edge to
			# the cell's centre, lying on the terrain (block-local 1 m: the clip sits a unit above)
			var dirt := shape.contains("Dirt")
			geo.tri(Vector3(0, CLIP_Y, 32), Vector3(32, CLIP_Y, 32), Vector3(16, CLIP_Y, 16), "dirt" if dirt else "grass",
				S_DIRT if dirt else S_GRASS)
		"Zone/Water/Base":
			_flat(geo, 2.0, "fabric", S_SLIDING)
			_flat(geo, WATER, "water", TmGeo.NO_COLLISION)
		"Zone/Water/Clip":
			# where water meets another block: the +z half of the water block (measured)
			_flat(geo, 2.0, "fabric", S_SLIDING, 16.0)
			_flat(geo, WATER, "water", TmGeo.NO_COLLISION, 16.0)
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


func _flat(geo: TmGeo, y: float, mat: String, surface: int, z0 := 0.0) -> void:
	geo.quad(Vector3(0, y, z0), Vector3(0, y, 32), Vector3(32, y, 32), Vector3(32, y, z0), mat, surface)


## A 32 x 32 m surface through the grid of heights, a quad between each four, shaded round (each
## point's normal from its neighbours' heights); pools line the basin below the water with fabric.
func _surface(geo: TmGeo, g: Array, mat: String, surface: int, pool: bool) -> void:
	var res := g.size() - 1
	var pts := []
	for j in res + 1:
		var row := []
		for i in res + 1:
			row.append(Vector3(32.0 * i / res, float(g[j][i]), 32.0 * j / res))
		pts.append(row)
	var step := 32.0 / res
	var nrm := func(j: int, i: int) -> Vector3:
		var i0 := maxi(i - 1, 0)
		var i1 := mini(i + 1, res)
		var j0 := maxi(j - 1, 0)
		var j1 := mini(j + 1, res)
		var dx := (float(g[j][i1]) - float(g[j][i0])) / ((i1 - i0) * step)
		var dz := (float(g[j1][i]) - float(g[j0][i])) / ((j1 - j0) * step)
		return Vector3(-dx, 1.0, -dz).normalized()
	for j in res:
		for i in res:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j + 1][i]
			var c: Vector3 = pts[j + 1][i + 1]
			var d: Vector3 = pts[j][i + 1]
			var m := mat
			var s := surface
			if pool and minf(minf(a.y, b.y), minf(c.y, d.y)) < GROUND - 0.3:
				m = "fabric"
				s = S_SLIDING
			var na: Vector3 = nrm.call(j, i)
			var nb: Vector3 = nrm.call(j + 1, i)
			var nc: Vector3 = nrm.call(j + 1, i + 1)
			var nd: Vector3 = nrm.call(j, i + 1)
			geo.tri(a, b, c, m, s, na, nb, nc)
			geo.tri(a, c, d, m, s, na, nc, nd)

