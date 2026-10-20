extends Node
## TmSkyline and TmTower: the city builds (and how long it takes), keeps off the Stadium (nothing
## inside its edge), has its districts' towers and the landmarks behind the grandstands, which rise
## over the roofs (their tops seen from the field above the roof's edge); a tower's parts (facade,
## lobby, roofs, beacon) and its merged blocks' materials; the cameras see that far.

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var city := TmSkyline.build()
	var ms := Time.get_ticks_msec() - t0
	add_child(city)
	var towers := city.get_node("Towers").get_children()
	var tris := 0
	var meshes := 0
	var inside := 0
	var stack: Array[Node] = [city]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
			var mi := n as MeshInstance3D
			meshes += 1
			tris += mi.mesh.surface_get_array_len(0) / 3
			if mi.name.begins_with("Blocks_") or mi.name == "Facade":
				# no wall stands on the Stadium (its edge, in the city's frame)
				var vs: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for v in vs:
					var p := mi.global_transform * v
					if absf(p.x) < TmStadiumBuild.EDGE.x and absf(p.z) < TmStadiumBuild.EDGE.y:
						inside += 1
		for ch in n.get_children():
			stack.append(ch)
	print("CITY build %d ms, %d meshes, %d triangles, %d towers" % [ms, meshes, tris, towers.size()])
	TestHooks.check(towers.size() >= 40 and towers.size() <= 320, "skyline_towers", str(towers.size()))
	TestHooks.check(inside == 0, "skyline_off_the_stadium", "%d vertices inside the edge" % inside)
	TestHooks.check(meshes < 1400 and tris < 600000, "skyline_budget", "%d meshes, %d triangles" % [meshes, tris])
	# the landmarks behind the grandstands: from the field's far side their tops clear the roof
	var roof_edge: float = TmStadiumBuild.ROOF[0][1]           # the roof's front edge over the field
	var roof_z: float = absf(TmStadiumBuild.ROOF_Z[0])
	var clear := 0
	for spec: Dictionary in TmSkyline.LANDMARKS:
		var at: Vector2 = spec["at"]
		if absf(at.y) < TmStadiumBuild.EDGE.y:
			continue
		var top := float(spec["height"]) + TmStadiumBuild.BOTTOM     # above the field
		var eye_z := -signf(at.y) * 400.0                             # on the field, 400 m from its centre
		var over := top / absf(at.y - eye_z) > (roof_edge - 2.0) / absf(signf(at.y) * roof_z - eye_z)
		clear += 1 if over else 0
	TestHooks.check(clear >= 3, "skyline_landmarks_over_roofs", str(clear))
	# a tower: its parts, and the facade's material
	var tower := TmTower.build({"height": 200.0, "shape": "octagon", "crown": "spire", "seed": 5})
	add_child(tower)
	var names := tower.get_children().map(func(c: Node) -> String: return String(c.name))
	TestHooks.check("Facade" in names and "Lobby" in names and "Roofs" in names and "Beacon" in names, "tower_parts", str(names))
	var fm := (tower.get_node("Facade") as MeshInstance3D).material_override as ShaderMaterial
	TestHooks.check(fm != null and fm.shader.resource_path.ends_with("tm_tower.gdshader") and float(fm.get_shader_parameter("floor_h")) == 4.0,
		"tower_facade_material")
	var aabb := (tower.get_node("Facade") as MeshInstance3D).get_aabb()
	TestHooks.check(absf(aabb.end.y - 214.0) < 0.5, "tower_height", str(aabb.end.y))  # 200 + the spire's base storey
	var masonry := TmTower.masonry("brick", 3)
	TestHooks.check(float(masonry.get_shader_parameter("frame_metal")) == 0.0, "tower_masonry")
	TestHooks.check(TmSkyline.FAR >= TmSkyline.RADIUS + TmStadiumBuild.EDGE.x, "skyline_cameras_far")
	TestHooks.finish()
