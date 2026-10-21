extends Node
## Our own cars (TmCarVisual.model): the hypercar's body (assets/car/hypercar.glb, made by
## tools/assets/hypercar.py) loads with every surface in one of our materials, fits the car (its
## size, a triangle budget, no bodywork inside a tyre at rest), and a visual of it has its four
## wheels where the open-wheeler has them, without the open-wheeler's guards and arms; the
## player's pick (TmUi.car_model) and a replay's header carry it.
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
	var r := TmReplay.new()
	r.model = "hyper"
	var back := TmReplay.new()
	back._set_header(r.header())
	TestHooks.check(back.model == "hyper", "replay_keeps_the_car")
	var old := r.header()
	old.erase("model")
	back._set_header(old)
	TestHooks.check(back.model == "", "replay_before_models_is_ours")
	TestHooks.finish()
