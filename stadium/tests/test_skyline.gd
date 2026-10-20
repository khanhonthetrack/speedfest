extends Node
## TmSkyline and TmTower: the city builds (and how long it takes), keeps off the Stadium (nothing
## inside its edge), has its districts' towers and the landmarks behind the grandstands, which rise
## over the roofs (their tops seen from the field above the roof's edge); a tower's parts (facade,
## lobby, roofs, beacon) and its merged blocks' materials; the cameras see that far. Night: a map's
## mood (a .Challenge.Gbx's decoration, our spec's "mood", --mood) and the night environment. A
## city track (F01): towers and buildings on its field, none on a cell the track takes nor in the
## way of the car's line (its collision boxes), the field paved, the City series in the campaign.

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
	# night
	var ch := TmChallenge.new()
	ch.decoration = "Night"
	var day := TmChallenge.new()
	day.decoration = "Day"
	var spec_night := TmTrackBuilder.challenge({"id": "N", "mood": "night", "pieces": [["start"], ["s", 2], ["finish"]]})
	TestHooks.check(TmStadiumEnv.mood_of(ch) == "night" and TmStadiumEnv.mood_of(day) == "day"
		and TmStadiumEnv.mood_of(spec_night) == "night", "night_mood_of_maps")
	var holder := Node3D.new()
	add_child(holder)
	TmStadiumEnv.add(holder, "night")
	var moon := holder.get_node_or_null("Moon") as DirectionalLight3D
	TestHooks.check(TmStadiumEnv.night and moon != null and moon.light_energy < 0.5, "night_environment")
	holder.free()
	var lit := Node3D.new()
	add_child(lit)
	TmStadiumEnv.add(lit, "day")
	TestHooks.check(not TmStadiumEnv.night and lit.get_node_or_null("Sun") != null, "day_environment")
	lit.free()
	_city_track()
	TestHooks.finish()


func _city_track() -> void:
	var ch := TmTracks.challenge("F01")
	TestHooks.check(ch.ok() and ch.scenery == "city", "city_track_spec", ch.error)
	if not ch.ok():
		return
	var builder := TmMapBuilder.build(ch)
	add_child(builder.root)
	var t0 := Time.get_ticks_msec()
	var field := TmSkyline.field(builder)
	var ms := Time.get_ticks_msec() - t0
	add_child(field)
	var towers := field.get_node("Towers").get_child_count()
	var boxes: Array[AABB] = []
	for cs in field.get_node("Body").get_children():
		var shape := (cs as CollisionShape3D).shape as BoxShape3D
		boxes.append(AABB(field.position + (cs as Node3D).position - shape.size * 0.5, shape.size))
	print("FIELD_CITY build %d ms, %d towers, %d buildings" % [ms, towers, boxes.size()])
	TestHooks.check(towers >= 5 and towers <= TmSkyline.FIELD_TOWERS and boxes.size() >= 60, "city_field_buildings",
		"%d towers, %d boxes" % [towers, boxes.size()])
	# nothing on a cell the track takes, nothing within 6 m of the car's line (at its height)
	var busy := TmSkyline.track_cells(builder)
	var on_track := 0
	for b in boxes:
		var c := Vector2i(floori(-b.get_center().x / 32.0), floori(b.get_center().z / 32.0))
		if busy.has(c):
			on_track += 1
	var in_way := 0
	for pt: Dictionary in ch.path:
		var p: Vector3 = pt["p"]
		for b in boxes:
			if b.grow(6.0).has_point(p):
				in_way += 1
	TestHooks.check(on_track == 0 and in_way == 0, "city_field_clear_of_track", "%d on track cells, %d line points in a building" % [on_track, in_way])
	var terrain := builder.root.get_node("Terrain")
	var paved := false
	for c in terrain.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override == TmSkyline.paving():
			paved = true
	TestHooks.check(paved, "city_field_paved")
	var city := TmTracks.series().filter(func(s: Dictionary) -> bool: return s["name"] == "City")
	TestHooks.check(city.size() == 1 and (city[0]["tracks"] as Array).size() == 5, "city_series")
	field.free()
	builder.root.free()
