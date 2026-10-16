class_name TmMapBuilder
extends RefCounted
## Builds a Stadium map (TmChallenge) from the recreated block library: each block's shape is made
## by TmBlockLib in block-local space and placed with TMNF's convention (TmBlockCatalogue). Blocks
## without a recreated shape yet get a translucent placeholder box per unit.

var challenge: TmChallenge
var lib: TmBlockLib
var root: Node3D
var start := Transform3D()          ## car spawn (Godot, TmCar frame)
var has_start := false
var checkpoints: Array[Transform3D] = []
var finishes: Array[Transform3D] = []
var stats := {"blocks": 0, "built": 0, "placeholder": 0, "unknown": 0}
var missing := {}                   ## shape name -> count (no generator yet)

var _placeholder_mats := {}


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
		var node := lib.make(shape, entry, ground)
		if node == null:
			stats["placeholder"] += 1
			missing[shape] = int(missing.get(shape, 0)) + 1
			node = _placeholder(id, entry, ground)
		else:
			stats["built"] += 1
		node.name = "%s_%d_%d_%d" % [id, coord.x, coord.y, coord.z]
		node.transform = xf
		node.set_meta("block", id)
		blocks_node.add_child(node)
		var wp := int(entry.get("waypoint", TmBlockCatalogue.Waypoint.NONE))
		var spawn_world := xf * TmBlockCatalogue.spawn(entry, ground)
		match wp:
			TmBlockCatalogue.Waypoint.START, TmBlockCatalogue.Waypoint.START_FINISH:
				start = spawn_world
				has_start = true
			TmBlockCatalogue.Waypoint.CHECKPOINT:
				checkpoints.append(spawn_world)
			TmBlockCatalogue.Waypoint.FINISH:
				finishes.append(spawn_world)


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
