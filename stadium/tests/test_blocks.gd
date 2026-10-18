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
	_check_screen_layout()
	var built := 0
	var bad := 0
	var screens := 0                 # shapes with screens, and those of them that show no ad
	var dark := []
	var names := shapes.keys()
	names.sort()
	for s: String in names:
		var node := lib.make(s, {}, s.contains("Ground"))
		if node == null:
			continue
		built += 1
		var why := _check_shape(node, shapes[s], s.begins_with("Zone/") or s.begins_with("Road/Dirt"),
			float(OVERHANG.get(s, 0.0)))
		if why.is_empty():
			var sc := _screen_faces(node)
			if int(sc[0]) > 0:
				screens += 1
				if int(sc[1]) == 0:
					dark.append(s)
				if int(sc[2]) > 0:
					why = "%d screen vertices without an ad layout (TmGeo.SCREENS)" % int(sc[2])
		if not why.is_empty():
			bad += 1
			TestHooks.fail("shape_%s" % s, why)
		node.free()
	print("BLOCKS built %d of %d catalogue shapes" % [built, shapes.size()])
	print("SCREENS on %d shapes; showing no ad: %s" % [screens, dark])
	TestHooks.check(screens >= 20 and dark.is_empty(), "screens_show_ads", "%d shapes, dark: %s" % [screens, dark])
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


## The screens' layout (TmGeo.SCREENS): slots per board and billboard, letterboxing, the unlit
## strips, and a screen box's two faces each holding a row of slots from 1 to 1 + n.
func _check_screen_layout() -> void:
	TestHooks.check(TmGeo.screen_slots("screen", 25.9, 6.66) == 2 and TmGeo.screen_slots("screen", 6.0, 2.5) == 1
		and TmGeo.screen_slots("led", 1000.0, 8.0) == 63 and TmGeo.screen_slots("screen_on", 45.3, 23.3) == 1,
		"screen_slots", "boards hold 2:1 slots, billboards one")
	var tall := TmGeo.screen_uv("screen", 0.0, 4.0, 0.0, 4.18)     # a 4 x 4.18 screen: letterboxed
	var strip := TmGeo.screen_uv("screen", 0.0, 0.4, 0.0, 2.5)      # a board's end
	var low := TmGeo.screen_uv("screen", 0.0, 30.0, 0.0, 0.5)       # a rim
	TestHooks.check(tall.y < 0.0 and strip == TmGeo.SCREEN_OFF and low == TmGeo.SCREEN_OFF, "screen_uv_fit",
		"%s %s %s" % [tall, strip, low])
	var geo := TmGeo.new()
	geo.screen_box(Vector3(0, 0, 10), Vector3(26, 6.6, 10.6), "screen", TmGeo.NO_COLLISION, 0.03, 4)
	var node := geo.build()
	var mesh := (node.get_node("Mesh") as MeshInstance3D).mesh as ArrayMesh
	var u_lo := INF
	var u_hi := -INF
	var v_lo := INF
	var v_hi := -INF
	var faces := 0
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i) == TmMaterials.get_material("screen"):
			var arr := mesh.surface_get_arrays(i)
			faces = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 6
			for uv: Vector2 in arr[Mesh.ARRAY_TEX_UV]:
				u_lo = minf(u_lo, uv.x)
				u_hi = maxf(u_hi, uv.x)
				v_lo = minf(v_lo, uv.y)
				v_hi = maxf(v_hi, uv.y)
	node.free()
	TestHooks.check(faces == 2 and is_equal_approx(u_lo, 5.0) and is_equal_approx(u_hi, 7.0)
		and is_equal_approx(v_lo, 0.0) and is_equal_approx(v_hi, 1.0), "screen_box_layout",
		"%d faces, u %.2f..%.2f, v %.2f..%.2f" % [faces, u_lo, u_hi, v_lo, v_hi])


## [screen vertices, vertices showing an ad, vertices with no ad layout] of a built block.
func _screen_faces(node: Node3D) -> Array:
	var mi := node.get_node_or_null("Mesh") as MeshInstance3D
	var out := [0, 0, 0]
	var mats := TmGeo.SCREENS.map(func(k: String) -> Material: return TmMaterials.get_material(k))
	for i in mi.mesh.get_surface_count():
		if not mats.has(mi.mesh.surface_get_material(i)):
			continue
		for uv: Vector2 in (mi.mesh as ArrayMesh).surface_get_arrays(i)[Mesh.ARRAY_TEX_UV]:
			out[0] += 1
			if uv == TmGeo.SCREEN_OFF:
				continue
			if absf(uv.x) >= 1.0 - 1e-4:
				out[1] += 1
			else:
				out[2] += 1
	return out
