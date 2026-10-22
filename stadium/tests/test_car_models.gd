extends Node
## Our own cars (TmCarVisual.model): the hypercar's body (assets/car/hypercar.glb, made by
## tools/assets/hypercar.py) loads with every surface in one of our materials, fits the car (its
## size, a triangle budget, no bodywork inside a tyre at rest), and a visual of it has its four
## wheels where the open-wheeler has them, without the open-wheeler's guards and arms; the
## player's pick (TmUi.car_model) and a replay's header carry it.
## The road cars (TmRoadCars, PLAN M16): each one's glb and manifest load, fit a car (size, a
## triangle budget, no bodywork inside its tyres at rest, wheels where its manifest puts them),
## every surface is dressed, its five liveries name known patterns and reach the paint shader;
## the hypercar's liveries too (the first its own, no sponsors on it); the garage's pick (car and
## livery) is a setting and replays keep it.
## Run: stadium/tools/run.sh res://tests/test_car_models.tscn --headless

const T := preload("res://core/tm_tuning.gd")


func _ready() -> void:
	var mesh := TmCarVisual._hyper_mesh()
	TestHooks.check(mesh != null, "hyper_body_loads", TmCarVisual.HYPER_GLB)
	if mesh == null:
		TestHooks.finish()
		return
	var names := []
	var tris := 0
	var verts := PackedVector3Array()
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s)
		names.append(m.resource_name if m != null else mesh.surface_get_name(s))
		var arr := mesh.surface_get_arrays(s)
		tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		verts.append_array(arr[Mesh.ARRAY_VERTEX])
	names.sort()
	TestHooks.check(names.all(func(n: String) -> bool: return TmCarVisual.HYPER_MATS.has(n)) and names.has("paint")
		and names.has("light") and names.has("glass_dark"), "hyper_surfaces_dressed", str(names))
	TestHooks.check(tris > 10000 and tris < 45000, "hyper_triangle_budget", "%d triangles" % tris)
	var box := mesh.get_aabb()
	TestHooks.check(box.size.z > 4.6 and box.size.z < 5.0 and box.size.x > 2.1 and box.size.x < 2.3 and box.end.y < 1.2
		and box.position.y > 0.05, "hyper_size", str(box))
	# no part of the body inside a tyre (the wells are cut round them; visual coordinates)
	var inside := []
	for i in 4:
		var c := TmCarVisual.wheel_centre(i)
		var hw: float = TmCarVisual.TYRE_HW[0 if i < 2 else 1]
		for v in verts:
			if absf(v.x - c.x) < hw and Vector2(v.y - c.y, v.z - c.z).length() < TmCarVisual.TYRE_R + 0.01:
				inside.append(v)
	TestHooks.check(inside.is_empty(), "hyper_wheels_clear_of_the_body", "%d body points inside a tyre, e.g. %s" % [
		inside.size(), inside.slice(0, 4)])
	# a visual of it: ours wheels, no guards nor arms
	var v := TmCarVisual.new()
	v.model = "hyper"
	v.ghost_speed = 20.0
	add_child(v)
	await get_tree().process_frame
	await get_tree().process_frame
	TestHooks.check(v._wheels.size() == 4 and v._rest[0].is_equal_approx(TmCarVisual.wheel_centre(0) - TmCarVisual.VIS)
		and v._rest[3].is_equal_approx(TmCarVisual.wheel_centre(3) - TmCarVisual.VIS), "hyper_wheels_where_ours_are",
		str(v._rest))
	TestHooks.check(v._arms.is_empty(), "hyper_no_suspension_arms")
	var guards := 0
	for mi: MeshInstance3D in v.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == TmCarVisual._shared.get("hubFL") or mi.mesh == TmCarVisual._shared.get("hubBL"):
			guards += 1
	TestHooks.check(guards == 0, "hyper_no_open_wheel_guards")
	var body := v.get_child(0) as MeshInstance3D
	TestHooks.check(body != null and body.mesh == mesh and body.position.is_equal_approx(-TmCarVisual.VIS), "hyper_body_placed")
	var dressed := true
	for s in mesh.get_surface_count():
		dressed = dressed and body.get_surface_override_material(s) != null
	TestHooks.check(dressed, "hyper_body_materials")
	TestHooks.check(absf(v._spins[0].rotation.x) > 0.0, "hyper_wheels_spin")
	# the open-wheeler stays as it was
	var f := TmCarVisual.new()
	add_child(f)
	await get_tree().process_frame
	TestHooks.check(not f._arms.is_empty() and (f.get_child(0) as MeshInstance3D).mesh == TmCarVisual._shared["body"],
		"formula_unchanged")
	# a ghost of it
	var g := TmCarVisual.new()
	g.model = "hyper"
	g.ghost = true
	add_child(g)
	await get_tree().process_frame
	var gm := (g.get_child(0) as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
	TestHooks.check(gm != null and gm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "hyper_ghost_translucent")
	# the player's pick, and a replay's header
	var was := String(TmUi.setting("car_model"))
	TmUi.set_setting("car_model", "hyper")
	TestHooks.check(TmUi.car_model() == "hyper", "setting_hyper")
	TmUi.set_setting("car_model", "tank")
	TestHooks.check(TmUi.car_model() == "", "setting_unknown_is_ours")
	TmUi.set_setting("car_model", was)
	await _road_cars()
	var r := TmReplay.new()
	r.model = "hyper"
	var back := TmReplay.new()
	back._set_header(r.header())
	TestHooks.check(back.model == "hyper", "replay_keeps_the_car")
	var old := r.header()
	old.erase("model")
	back._set_header(old)
	TestHooks.check(back.model == "", "replay_before_models_is_ours")
	r.model = "zenith"
	r.livery = 3
	back._set_header(r.header())
	TestHooks.check(back.model == "zenith" and back.livery == 3, "replay_keeps_the_road_car_and_livery")
	old = r.header()
	old.erase("livery")
	back._set_header(old)
	TestHooks.check(back.livery == 0, "replay_before_liveries_is_the_first")
	TestHooks.finish()


func _road_cars() -> void:
	TestHooks.check(TmRoadCars.CARS.size() == 16, "sixteen_road_cars", str(TmRoadCars.CARS.size()))
	var bad := []
	for c: Array in TmRoadCars.CARS:
		var id := String(c[0])
		var rc := TmRoadCars.meshes(id)
		var man := TmRoadCars.manifest(id)
		var parts_ok := rc.has("Body") and rc.has("WheelF") and rc.has("WheelR") and rc.has("BrakeF") and rc.has("BrakeR")
		var an: Dictionary = man.get("anchors", {})
		var man_ok := (man.get("wheels", []) as Array).size() == 4 and (an.get("belt", []) as Array).size() == 24 \
			and String(man.get("name", "")) == String(c[1])
		if not parts_ok or not man_ok:
			bad.append("%s: parts %s manifest %s" % [id, parts_ok, man_ok])
			continue
		var body: ArrayMesh = rc["Body"]
		var tris := 0
		var verts := PackedVector3Array()
		for s in body.get_surface_count():
			var arr := body.surface_get_arrays(s)
			tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			verts.append_array(arr[Mesh.ARRAY_VERTEX])
		var box := body.get_aabb()
		if tris > 95000 or box.size.z < 4.0 or box.size.z > 5.0 or box.size.x < 1.6 or box.size.x > 2.1 or box.end.y > 1.6 \
				or box.position.y < 0.05:
			bad.append("%s: %d triangles, box %s" % [id, tris, box])
		# no bodywork inside a tyre at rest (its own wheels: the manifest's places and sizes)
		var inside := 0
		var where := []
		for i in 4:
			var w: Array = man["wheels"][i]
			var cw := Vector3(float(w[0]), float(w[1]), float(w[2]))
			var r := float(man["tyre_r"][0 if i < 2 else 1])
			var hw := float(man["tyre_hw"][0 if i < 2 else 1])
			for v in verts:
				if absf(v.x - cw.x) < hw - 0.01 and Vector2(v.y - cw.y, v.z - cw.z).length() < r - 0.005:
					inside += 1
					if where.size() < 3:
						where.append(v)
		if inside > 0:
			bad.append("%s: %d body points inside its tyres, e.g. %s" % [id, inside, where])
		# its liveries
		var lvs := TmRoadCars.liveries(id)
		var known := lvs.size() == 5
		for l: Dictionary in lvs:
			known = known and TmRoadCars.PATTERNS.has(String(l.get("pattern", ""))) and not String(l.get("name", "")).is_empty()
		if not known:
			bad.append("%s: liveries %d" % [id, lvs.size()])
	TestHooks.check(bad.is_empty(), "road_cars_load_and_fit", str(bad))
	# one drawn: its own wheels at its manifest's places, every surface dressed, the livery's pattern
	var v := TmCarVisual.new()
	v.model = "nemesis"
	v.livery = 2
	v.ghost_speed = 15.0
	add_child(v)
	await get_tree().process_frame
	await get_tree().process_frame
	var man := TmRoadCars.manifest("nemesis")
	var w0: Array = man["wheels"][0]
	var w3: Array = man["wheels"][3]
	TestHooks.check(v._wheels.size() == 4 and v._rest[0].is_equal_approx(Vector3(float(w0[0]), float(w0[1]), float(w0[2])) - TmCarVisual.VIS)
		and v._rest[3].is_equal_approx(Vector3(float(w3[0]), float(w3[1]), float(w3[2])) - TmCarVisual.VIS), "road_car_wheels_placed",
		str(v._rest))
	TestHooks.check(absf(v._spins[0].rotation.x) > 0.0 and v._arms.is_empty(), "road_car_wheels_spin")
	var dressed := true
	var paint: ShaderMaterial = null
	for mi: MeshInstance3D in v.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s)
			dressed = dressed and m != null
			if m is ShaderMaterial and int((m as ShaderMaterial).get_shader_parameter("mode")) == 4:
				paint = m
	TestHooks.check(dressed, "road_car_dressed")
	var lv := TmRoadCars.livery("nemesis", 2)
	TestHooks.check(paint != null and int(paint.get_shader_parameter("livery")) == TmRoadCars.PATTERNS.find(String(lv["pattern"]))
		and (paint.get_shader_parameter("an_belt") as PackedFloat32Array).size() == 24, "road_car_livery_in_the_paint")
	# right-side wheels are the left ones mirrored
	var right := v._spins[1].get_child(0) as MeshInstance3D
	TestHooks.check(right != null and right.scale.x < 0.0, "road_car_right_wheels_mirrored")
	v.queue_free()
	# the hypercar's liveries: its own first, then the livery shader on its manifest's lines
	TestHooks.check(TmRoadCars.liveries("hyper").size() == 5 and not TmRoadCars.manifest("hyper").is_empty(), "hyper_liveries")
	var h := TmCarVisual.new()
	h.model = "hyper"
	h.livery = 2
	add_child(h)
	await get_tree().process_frame
	var hm := (h.get_child(0) as MeshInstance3D)
	var mode4 := false
	for s in hm.mesh.get_surface_count():
		var m := hm.get_surface_override_material(s)
		if m is ShaderMaterial and int((m as ShaderMaterial).get_shader_parameter("mode")) == 4:
			mode4 = true
	TestHooks.check(mode4, "hyper_livery_drawn")
	TestHooks.check(not TmCarVisual.HYPER_STICKERS.any(func(st: Array) -> bool: return String(st[0]) == "livery_sponsor"),
		"hyper_no_sponsors")
	h.queue_free()
	# the garage's pick
	var was := String(TmUi.setting("car_model"))
	var was_l: Variant = TmUi.setting("car_liveries")
	TmUi.set_setting("car_model", "corrida")
	TmUi.set_car_livery("corrida", 4)
	TestHooks.check(TmUi.car_model() == "corrida" and TmUi.car_livery() == 4, "setting_road_car_and_livery")
	TmUi.set_car_livery("corrida", 99)
	TestHooks.check(TmUi.car_livery() == 4, "setting_livery_clamped")
	TestHooks.check(TmUi.car_livery("") == 0, "formula_has_no_livery")
	TmUi.set_setting("car_model", was)
	TmUi.set_setting("car_liveries", was_l)
