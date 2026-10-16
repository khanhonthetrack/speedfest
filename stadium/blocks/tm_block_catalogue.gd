class_name TmBlockCatalogue
extends RefCounted
## The Stadium block catalogue and TMNF's block placement.
##
## blocks/data/block_catalogue.json is layout data measured from the game's block infos (names,
## unit footprints, clip sides, spawn, waypoint type and the shape name of each variant; no
## geometry): tools/research/tmnf/export_blockinfo.py. Per block id:
##   kind ("classic", "road", ...), waypoint (0 start, 1 finish, 2 checkpoint, 3 none),
##   spawn / spawn_ground (TMNF iso4: 3x3 rotation then position, block-local),
##   ground / air: {units: [[ox, oy, oz, [clip per side]]], mobils: [[shape name, alternatives...]]}
##
## TMNF coordinates are left-handed; Godot's = TMNF's with x negated (an unrotated TMNF car then
## has TmCar's frame: +X left, +Z forward). Sides: 0 +Z, 1 +X, 2 -Z, 3 -X (Godot). A block's
## `dir` turns it by dir x 90 deg about +Y, and its rotated footprint's min corner sits at coord x
## (32, 8, 32) (checked: 96.8% of the campaign's classic-block clips meet a clip).

const BLOCK := Vector3(32.0, 8.0, 32.0)
const PATH := "res://blocks/data/block_catalogue.json"

enum Waypoint { START, FINISH, CHECKPOINT, NONE, START_FINISH }

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


## The catalogue entry of a block id ({} if unknown).
static func info(id: String) -> Dictionary:
	return data().get(id, {})


static func variant(entry: Dictionary, ground: bool) -> Dictionary:
	return entry.get("ground" if ground else "air", {})


## Footprint in units (x, y, z) of the ground or air variant.
static func footprint(entry: Dictionary, ground: bool) -> Vector3i:
	var size := Vector3i.ONE
	for u in variant(entry, ground).get("units", []):
		size.x = maxi(size.x, int(u[0]) + 1)
		size.y = maxi(size.y, int(u[1]) + 1)
		size.z = maxi(size.z, int(u[2]) + 1)
	return size


## Shape (mesh) name of a placed block: mobil group `index` (a road block's shape: 0 base, 1 dead
## end, 2 corner, 3 straight, 4 T, 5 cross; 0 for others), alternative `alt` (visual variety).
static func shape_name(entry: Dictionary, ground: bool, index: int, alt: int) -> String:
	var groups: Array = variant(entry, ground).get("mobils", [])
	if groups.is_empty():
		return ""
	var g: Array = groups[clampi(index, 0, groups.size() - 1)]
	if g.is_empty():
		return ""
	return String(g[clampi(alt, 0, g.size() - 1)])


## TMNF position (block-local or world) -> Godot.
static func tm_to_godot(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, p.z)


## Godot transform that places a block's local space (Godot coordinates, x = -TMNF x).
static func block_transform(entry: Dictionary, coord: Vector3i, dir: int, ground: bool) -> Transform3D:
	var size := footprint(entry, ground)
	var d := posmod(dir, 4)
	# the rotated footprint box's min corner (TMNF x, z; one step: (x, z) -> (-z, x))
	var minx := INF
	var minz := INF
	for c in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.z), Vector2(size.x, size.z)]:
		var p: Vector2 = c * BLOCK.x
		for _i in d:
			p = Vector2(-p.y, p.x)
		minx = minf(minx, p.x)
		minz = minf(minz, p.y)
	var t := Vector3(coord.x * BLOCK.x - minx, coord.y * BLOCK.y, coord.z * BLOCK.z - minz)
	return Transform3D(Basis(Vector3.UP, d * PI * 0.5), tm_to_godot(t))


## A TMNF iso4 (rotation rows then position) as a Godot transform (block-local).
static func iso4_to_godot(iso: Array) -> Transform3D:
	if iso.size() < 12:
		return Transform3D.IDENTITY
	# TMNF basis columns (x, y, z axes) are the rows' transposes; mirror x on both sides
	var bx := Vector3(float(iso[0]), float(iso[3]), float(iso[6]))
	var by := Vector3(float(iso[1]), float(iso[4]), float(iso[7]))
	var bz := Vector3(float(iso[2]), float(iso[5]), float(iso[8]))
	var b := Basis(tm_to_godot(bx) * -1.0, tm_to_godot(by), tm_to_godot(bz))
	return Transform3D(b, tm_to_godot(Vector3(float(iso[9]), float(iso[10]), float(iso[11]))))


## Car spawn of a start block, block-local (Godot; TmCar frame: +Z forward).
static func spawn(entry: Dictionary, ground: bool) -> Transform3D:
	var iso: Variant = entry.get("spawn_ground" if ground else "spawn", null)
	if iso == null:
		iso = entry.get("spawn", null)
	return iso4_to_godot(iso if iso is Array else [])
