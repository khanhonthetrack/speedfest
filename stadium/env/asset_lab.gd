extends Node3D
## Looks at a glTF model from disk (or every one in --dir= side by side) in our light (no import: loaded at run time), framed whole on a
## concrete plaza: --glb=/abs/model.glb [--yaw=35] [--pitch=18] [--dist=1.0 (times the framing)]
## [--scale=1] [--mood=night] [--dress=false: its own materials] [--glass=blue] --frames=N --shot=/abs.png.
## In our materials (TmCityAssets) unless --dress=false. Prints the model's size and triangles.

func _ready() -> void:
	TmStadiumEnv.add(self)
	var path := String(TestHooks.arg("glb", ""))
	var model: Node3D
	if TestHooks.has_arg("dir"):
		# a gallery: every .glb of the directory (--match=prefix) in a row, by name
		model = Node3D.new()
		var dir := String(TestHooks.arg("dir", ""))
		var files := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool:
			return f.ends_with(".glb") and f.begins_with(String(TestHooks.arg("match", ""))))
		files.sort()
		var x := 0.0
		for f: String in files:
			var one := _load(dir.path_join(f))
			if one == null:
				continue
			var b := _bounds(one)
			one.position = Vector3(x - b.position.x, 0.0, 0.0)
			model.add_child(one)
			x += b.size.x + 25.0
		path = dir
	else:
		model = _load(path)
	if model == null:
		push_error("asset_lab: can't read %s" % path)
		TestHooks.finish()
		return
	model.scale = Vector3.ONE * float(TestHooks.arg("scale", 1.0))
	add_child(model)
	if String(TestHooks.arg("dress", "true")) != "false":
		TmCityAssets.dress(model, String(TestHooks.arg("glass", "blue")), 7)
	var box := AABB()
	var first := true
	var tris := 0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += (idx.size() if not idx.is_empty() else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	print("ASSET %s size %s at %s, %d triangles" % [path.get_file(), box.size, box.position, tris])
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20000, 20000)
	ground.mesh = pm
	ground.material_override = TmMaterials.get_material("concrete")
	ground.position.y = box.position.y - 0.02
	add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 20000.0
	add_child(cam)
	cam.current = true
	var c := box.get_center()
	var r := box.size.length() * 0.5
	var yaw := deg_to_rad(float(TestHooks.arg("yaw", 35.0)))
	var pitch := deg_to_rad(float(TestHooks.arg("pitch", 18.0)))
	var d := r / tan(deg_to_rad(cam.fov * 0.5)) * float(TestHooks.arg("dist", 1.0))
	cam.position = c + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * d
	cam.look_at(c)


func _load(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh != null:
			var b := mi.transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
	return box
