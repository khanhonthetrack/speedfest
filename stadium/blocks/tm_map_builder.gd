class_name TmMapBuilder
extends RefCounted
## Builds a Stadium map (TmChallenge) from the recreated block library: each block's shape is made
## by TmBlockLib in block-local space and placed with TMNF's convention (TmBlockCatalogue). Blocks
## without a recreated shape yet get a translucent placeholder box per unit. The ground (grass,
## collidable) covers every cell without a terrain zone tile.

var challenge: TmChallenge
var lib: TmBlockLib
var root: Node3D
var start := Transform3D()          ## car spawn (Godot, TmCar frame)
var has_start := false
var _start_is_line := false
var checkpoints: Array[Transform3D] = []
var finishes: Array[Transform3D] = []
## Waypoint blocks for the race: [{kind (TmBlockCatalogue.Waypoint), block (id), xform (block,
## Godot), spawn (world Transform3D, TmCar frame), built (false: a placeholder)}]; their triggers:
## TmTriggers.
var waypoints: Array = []
var stats := {"blocks": 0, "built": 0, "empty": 0, "placeholder": 0, "unknown": 0}
var missing := {}                   ## shape name -> count (no generator yet)
## Built road blocks for the decals (TmRoadDecals): [{shape, xform (block, Godot)}].
var road_blocks: Array = []

var _placeholder_mats := {}
var _zone_cells := {}               ## Vector2i (x, z) -> true: cells with a terrain zone tile

const S_GRASS := 2
const GROUND_Y := 9.0               ## level-0 ground (TMNF y)


static func build(ch: TmChallenge, library: TmBlockLib = null) -> TmMapBuilder:
	var b := TmMapBuilder.new()
	b.challenge = ch
	b.lib = library if library != null else TmBlockLib.new()
	b._build()
	return b


func _build() -> void:
	root = Node3D.new()
	root.name = "Map_%s" % challenge.name.validate_node_name()
	var blocks_node := Node3D.new()
	blocks_node.name = "Blocks"
	root.add_child(blocks_node)
	for blk: Dictionary in challenge.blocks:
		if int(blk["flags"]) == 0xFFFFFFFF:
			continue   # free (unplaced) block entries
		stats["blocks"] += 1
		var id := String(blk["name"])
		var entry := TmBlockCatalogue.info(id)
		var ground := bool(blk["ground"])
		var coord: Vector3i = blk["coord"]
		var dir := int(blk["dir"])
		if entry.is_empty():
			stats["unknown"] += 1
			missing["?" + id] = int(missing.get("?" + id, 0)) + 1
			continue
		var flags := int(blk["flags"])
		var shape := TmBlockCatalogue.shape_name(entry, ground, flags & 0x3F, (flags >> 6) & 0x3F)
		var xf := TmBlockCatalogue.block_transform(entry, coord, dir, ground)
		var node: Node3D = null if shape.is_empty() else lib.make(shape, entry, ground)
		_waypoint(id, entry, ground, xf, node != null or shape.is_empty())
		if shape.is_empty():
			stats["empty"] += 1      # this variant has no geometry (e.g. a support's bare position)
			continue
		if node == null:
			stats["placeholder"] += 1
			missing[shape] = int(missing.get(shape, 0)) + 1
			node = _placeholder(id, entry, ground)
		else:
			stats["built"] += 1
			if shape.begins_with("Road/Main/"):
				road_blocks.append({"shape": shape, "xform": xf})
		node.name = "%s_%d_%d_%d" % [id, coord.x, coord.y, coord.z]
		node.transform = xf
		node.set_meta("block", id)
		blocks_node.add_child(node)
		if String(entry.get("kind", "")) in ["flat", "frontier"]:
			_zone_cells[Vector2i(coord.x, coord.z)] = true
	_terrain()
	if TmMaterials.hd():
		root.add_child(TmRoadDecals.place(self))


## Records a waypoint block (start, finish, checkpoint, lap line) for the race, whether or not its
## shape is recreated yet (built false: a placeholder without a floor).
func _waypoint(id: String, entry: Dictionary, ground: bool, xf: Transform3D, built: bool) -> void:
	var wp := int(entry.get("waypoint", TmBlockCatalogue.Waypoint.NONE))
	if wp == TmBlockCatalogue.Waypoint.NONE:
		return
	var spawn_world := xf * TmBlockCatalogue.spawn(entry, ground)
	waypoints.append({"kind": wp, "block": id, "xform": xf, "spawn": spawn_world, "built": built})
	match wp:
		TmBlockCatalogue.Waypoint.START, TmBlockCatalogue.Waypoint.START_FINISH:
			# a start/finish line is the start of a lap race; with a start line too (our tracks
			# finish on one, with road after it), the start line is where the car starts
			if wp == TmBlockCatalogue.Waypoint.START or not has_start or not _start_is_line:
				start = spawn_world
				has_start = true
				_start_is_line = _start_is_line or wp == TmBlockCatalogue.Waypoint.START
		TmBlockCatalogue.Waypoint.CHECKPOINT:
			checkpoints.append(spawn_world)
		TmBlockCatalogue.Waypoint.FINISH:
			finishes.append(spawn_world)


## The stadium ground: grass at 9 m (level 0) on every map cell without a terrain zone tile.
func _terrain() -> void:
	var geo := TmGeo.new()
	var y := GROUND_Y
	for cz in challenge.size.z:
		# merge runs of grass cells along x into one quad
		var cx := 0
		while cx < challenge.size.x:
			if _zone_cells.has(Vector2i(cx, cz)):
				cx += 1
				continue
			var x0 := cx
			while cx < challenge.size.x and not _zone_cells.has(Vector2i(cx, cz)):
				cx += 1
			var a := Vector3(x0 * 32.0, y, cz * 32.0)
			var b := Vector3(cx * 32.0, y, (cz + 1) * 32.0)
			geo.quad(Vector3(a.x, y, a.z), Vector3(a.x, y, b.z), Vector3(b.x, y, b.z), Vector3(b.x, y, a.z), "grass", S_GRASS)
	var node := geo.build()
	node.name = "Terrain"
	root.add_child(node)


func _placeholder(id: String, entry: Dictionary, ground: bool) -> Node3D:
	var n := Node3D.new()
	var mat := _placeholder_mat(id)
	for u in TmBlockCatalogue.variant(entry, ground).get("units", []):
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = TmBlockCatalogue.BLOCK * 0.94
		mi.mesh = box
		mi.material_override = mat
		# unit (ox, oy, oz) in TMNF block-local -> Godot (x negated), box centred in the cell
		var c := Vector3(float(u[0]) + 0.5, float(u[1]) + 0.5, float(u[2]) + 0.5) * TmBlockCatalogue.BLOCK
		mi.position = TmBlockCatalogue.tm_to_godot(c)
		n.add_child(mi)
	return n


func _placeholder_mat(id: String) -> StandardMaterial3D:
	# one colour per block family (the name's third word: Stadium<Family>...)
	var fam := id.trim_prefix("Stadium")
	var cut := 1
	while cut < fam.length() and fam[cut] == fam[cut].to_lower():
		cut += 1
	fam = fam.substr(0, cut)
	if _placeholder_mats.has(fam):
		return _placeholder_mats[fam]
	var m := StandardMaterial3D.new()
	var h := float(hash(fam) % 1000) / 1000.0
	m.albedo_color = Color.from_hsv(h, 0.55, 0.9, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_placeholder_mats[fam] = m
	return m
