extends Node3D
## Asset trial: loads every .glb in a folder at runtime (GLTFDocument, nothing imported into the
## project) and lines the assets up beside a wet night street, under the game's environment, to
## judge downloaded third-party assets against our look before any of them is kept.
## Prints one ASSET line per file (triangles, meshes, materials, textures, size in metres).
## Args:
##   --dir=/abs/folder   the .glb files (e.g. the output of tools/assets/blendswap_convert.py)
##   --theme=city|arena  environment  --view=street|overview  --lights=1 (street-level lights)
##   --frames=24 --shot=/abs/out.png
## Run: tools/run_scene.sh res://tests/visual/asset_trial.tscn -- --dir=/abs/glbs --frames=24 --shot=$PWD/x.png

const HW := 8.0
const GAP := 6.0


func _ready() -> void:
	var theme := String(TestHooks.arg("theme", "city"))
	add_child(SceneryKit.build_environment(theme))
	_street()
	var dir := String(TestHooks.arg("dir", ""))
	var files: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() == "glb":
			files.append(dir.path_join(f))
	files.sort()
	if files.is_empty():
		print("TEST_FAIL asset_trial: no .glb files in '%s'" % dir)
	var z := -6.0
	var side := 1.0
	var far_z := 0.0
	var pair_depth := 4.0
	for path in files:
		var root := _load(path)
		if root == null:
			print("TEST_FAIL asset_trial: could not load %s" % path)
			continue
		var box := _bounds(root, Transform3D.IDENTITY)
		# alternate sides of the street, each asset grounded and set back from the kerb
		root.position = Vector3(side * (HW + 2.0 + box.size.x * 0.5) - box.get_center().x,
				-box.position.y, z - box.size.z * 0.5 - box.get_center().z)
		add_child(root)
		pair_depth = max(pair_depth, box.size.z)
		if side < 0.0:                            # both sides of this stretch are filled
			z -= pair_depth + GAP
			pair_depth = 4.0
		far_z = min(far_z, z - pair_depth)
		side = -side
		_print_stats(path, root, box)
	_camera(String(TestHooks.arg("view", "street")), far_z)


func _load(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


func _bounds(node: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [[node, xf]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var t: Transform3D = item[1]
		if n is Node3D and n != node:
			t = t * (n as Node3D).transform
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var b := t * (n as MeshInstance3D).mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		for c in n.get_children():
			stack.append([c, t])
	return box


func _print_stats(path: String, root: Node, box: AABB) -> void:
	var tris := 0
	var meshes := 0
	var mats := {}
	var textures := {}
	var emissive := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is MeshInstance3D) or (n as MeshInstance3D).mesh == null:
			continue
		var mesh: Mesh = (n as MeshInstance3D).mesh
		meshes += 1
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			tris += idx.size() / 3 if idx.size() > 0 else verts.size() / 3
			var m := mesh.surface_get_material(s) as BaseMaterial3D
			if m == null or mats.has(m):
				continue
			mats[m] = true
			if m.emission_enabled:
				emissive += 1
			for tex: Texture2D in [m.albedo_texture, m.normal_texture, m.roughness_texture, m.emission_texture]:
				if tex != null:
					textures[tex] = Vector2i(tex.get_width(), tex.get_height())
	var biggest := Vector2i.ZERO
	for v: Vector2i in textures.values():
		if v.x * v.y > biggest.x * biggest.y:
			biggest = v
	print("ASSET %s tris=%d meshes=%d materials=%d emissive=%d textures=%d max_tex=%dx%d size_m=%.1fx%.1fx%.1f" % [
		path.get_file(), tris, meshes, mats.size(), emissive, textures.size(), biggest.x, biggest.y,
		box.size.x, box.size.y, box.size.z])


func _street() -> void:
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.05, 0.05, 0.055)
	asphalt.roughness = 0.25                      # wet night street
	var road := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400.0, 600.0)
	road.mesh = pm
	road.material_override = asphalt
	road.position = Vector3(0.0, 0.0, -250.0)
	add_child(road)
	if int(TestHooks.arg("lights", 1)) != 1:
		return
	for k in 8:                                   # warm street-level light pools down the street
		var ol := OmniLight3D.new()
		ol.position = Vector3(0.0, 6.0, -10.0 - k * 25.0)
		ol.light_color = Color(1.0, 0.8, 0.6)
		ol.light_energy = 2.5
		ol.omni_range = 22.0
		add_child(ol)


func _camera(view: String, far_z: float) -> void:
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 3000.0
	if view == "overview":
		cam.position = Vector3(-60.0, 45.0, 25.0)
		cam.look_at_from_position(cam.position, Vector3(0.0, 5.0, far_z * 0.5))
	else:
		cam.position = Vector3(0.0, 2.2, 8.0)
		cam.rotation_degrees = Vector3(-2.0, 0.0, 0.0)
	add_child(cam)
	cam.current = true
