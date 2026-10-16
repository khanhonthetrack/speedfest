extends Node
## Block library test (no TMNF install needed): builds every shape the catalogue names that a
## family recreates, and checks each one: a visual mesh, a collision body whose per-face surface
## ids match its faces, and geometry inside the block's footprint (1 m slack). Prints coverage.

const SLACK := 1.0
## Pieces whose own TMNF mesh reaches further out than their footprint (measured), extra slack m.
const OVERHANG := {"Sculpt/B/Ground": 1.5, "Sculpt/ArchRing/StartGround": 2.5, "Sculpt/ArchRing/StartGroundMirror": 2.5,
	"Sculpt/ArchRing/EndGround": 2.5, "Sculpt/ArchRing/EndGroundMirror": 2.5}


func _ready() -> void:
	var lib := TmBlockLib.new()
	TestHooks.check(lib.load_errors.is_empty(), "families_load", "%s" % [lib.load_errors])
	var cat := TmBlockCatalogue.data()
	TestHooks.check(cat.size() > 250, "catalogue_loaded", "%d blocks" % cat.size())
	var shapes := {}          # shape name -> footprint (units, of the first block using it)
	for id: String in cat:
		var entry: Dictionary = cat[id]
		for ground in [false, true]:
			for group: Array in TmBlockCatalogue.variant(entry, ground).get("mobils", []):
				for s: String in group:
					if not s.is_empty() and not shapes.has(s):
						shapes[s] = TmBlockCatalogue.footprint(entry, ground)
	var built := 0
	var bad := 0
	var names := shapes.keys()
	names.sort()
	for s: String in names:
		var node := lib.make(s, {}, s.contains("Ground"))
		if node == null:
			continue
		built += 1
		var why := _check_shape(node, shapes[s], s.begins_with("Zone/") or s.begins_with("Road/Dirt"),
			float(OVERHANG.get(s, 0.0)))
		if not why.is_empty():
			bad += 1
			TestHooks.fail("shape_%s" % s, why)
		node.free()
	print("BLOCKS built %d of %d catalogue shapes" % [built, shapes.size()])
	TestHooks.check(built >= 100, "shapes_built", "%d" % built)
	TestHooks.check(bad == 0, "shapes_valid", "%d invalid" % bad)
	TestHooks.finish()


## zone: terrain tiles stand 9 m up (level 0 is the ground), so their bounds reach 9 m higher.
func _check_shape(node: Node3D, size: Vector3i, zone := false, extra := 0.0) -> String:
	var mi := node.get_node_or_null("Mesh") as MeshInstance3D
	if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return "no visual mesh"
	var body := node.get_node_or_null("Body") as StaticBody3D
	if body == null:
		return "no collision body"
	var shape := (body.get_child(0) as CollisionShape3D).shape as ConcavePolygonShape3D
	var faces := shape.get_faces()
	var surf: PackedInt32Array = body.get_meta("surfaces", PackedInt32Array())
	if faces.is_empty() or faces.size() != surf.size() * 3:
		return "%d collision vertices for %d surface ids" % [faces.size(), surf.size()]
	# block-local Godot space: x in [-32 sx, 0], y in [0, 8 sy], z in [0, 32 sz]
	var lo := Vector3(-32.0 * size.x, -1.0 if zone else 0.0, 0.0) - Vector3.ONE * (SLACK + extra)
	var hi := Vector3(0.0, 8.0 * size.y + (9.0 if zone else 0.0), 32.0 * size.z) + Vector3.ONE * (SLACK + extra)
	var box := mi.mesh.get_aabb()
	for p: Vector3 in faces:
		box = box.expand(p)
	if box.position.x < lo.x or box.position.y < lo.y or box.position.z < lo.z \
			or box.end.x > hi.x or box.end.y > hi.y or box.end.z > hi.z:
		return "outside its footprint %s: %s" % [size, box]
	return ""
