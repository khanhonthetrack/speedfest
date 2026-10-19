extends Node
## Headless: builds every part combination of every car, checks triangle and draw-call budgets,
## exercises the whole CarVisual API, and checks that paint-only style changes don't rebuild meshes.

const MAX_TRIS := 28000    # session 7: +~2k for the cabin tub, seats and driver
const MAX_DRAWS := 12


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var worst_tris := 0
	var worst_draws := 0
	var combos := 0
	var errors := 0
	var full: bool = TestHooks.arg("full", true)
	for id in CarDefs.IDS:
		var cv := CarVisual.new()
		add_child(cv)
		cv.build(id, CarDefs.default_style(id))
		var keys := ["hood", "front", "rear", "skirts", "spoiler"]
		var counts: Array = []
		for k in keys:
			counts.append(int(CarDefs.PART_COUNTS[k]))
		var total := 1
		for c in counts:
			total *= c
		for n in total:
			if not full and n % 7 != 0:
				continue
			var st := CarDefs.default_style(id)
			var rem := n
			for i in keys.size():
				st[keys[i]] = rem % int(counts[i])
				rem /= int(counts[i])
			st["rims"] = n % int(CarDefs.PART_COUNTS["rims"])
			cv.apply_style(st)
			combos += 1
			var tris := cv.get_triangle_count()
			var draws := _draw_calls(cv)
			worst_tris = maxi(worst_tris, tris)
			worst_draws = maxi(worst_draws, draws)
			if tris > MAX_TRIS or draws > MAX_DRAWS or tris <= 0:
				errors += 1
				if errors < 6:
					TestHooks.fail("budget_%s_%d" % [id, n], "tris=%d draws=%d style=%s" % [tris, draws, str(st)])
		TestHooks.check(_has_surfaces(cv, ["paint", "glass", "trim", "chrome", "lights"]), "surfaces_%s" % id)
		_api(cv, id)
		cv.queue_free()
	print("combos=%d worst_tris=%d worst_draws=%d ms=%d" % [combos, worst_tris, worst_draws, Time.get_ticks_msec() - t0])
	TestHooks.check(errors == 0, "all_combos_within_budget", "%d over budget" % errors)
	_sanitize()
	TestHooks.finish()


## Draw calls of one car in the normal (non-nitro) state.
func _draw_calls(cv: CarVisual) -> int:
	var n := 0
	for c in _all(cv):
		if c is MeshInstance3D and (c as MeshInstance3D).visible and (c as MeshInstance3D).mesh:
			n += (c as MeshInstance3D).mesh.get_surface_count()
		elif c is MultiMeshInstance3D:
			n += 1
		elif c is Label3D:
			n += 1
	return n


func _all(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all(c))
	return out


func _has_surfaces(cv: CarVisual, names: Array) -> bool:
	var body := cv.get_node("Body") as MeshInstance3D
	var have: Array = []
	for i in body.mesh.get_surface_count():
		have.append((body.mesh as ArrayMesh).surface_get_name(i))
	for nm in names:
		if not nm in have:
			print("missing surface ", nm, " have ", have)
			return false
	return true


func _api(cv: CarVisual, id: String) -> void:
	var st := CarDefs.default_style(id)
	cv.apply_style(st)
	var body := cv.get_node("Body") as MeshInstance3D
	var mesh_before := body.mesh
	var wheels_before := (cv.get_node("Wheels") as MultiMeshInstance3D).multimesh
	# paint-only changes must not rebuild geometry
	for fin in CarDefs.FINISHES:
		for liv in CarDefs.LIVERIES:
			st["finish"] = fin
			st["livery"] = liv
			st["paint"] = "#3080ff"
			st["hood_carbon"] = not st["hood_carbon"]
			cv.apply_style(st)
	for mode in CarDefs.UNDERGLOW_MODES:
		st["underglow_mode"] = mode
		cv.apply_style(st)
	st["ride_height"] = -1.0
	cv.apply_style(st)
	var low := body.position.y
	st["ride_height"] = 1.0
	cv.apply_style(st)
	TestHooks.check(body.position.y > low + 0.05, "ride_height_%s" % id, "low=%f high=%f" % [low, body.position.y])
	TestHooks.check(body.mesh == mesh_before and (cv.get_node("Wheels") as MultiMeshInstance3D).multimesh == wheels_before,
		"paint_only_no_rebuild_%s" % id)
	st["plate"] = "TEST 1"
	cv.apply_style(st)
	TestHooks.check((body.get_node("Plate") as Label3D).text == "TEST 1", "plate_%s" % id)
	cv.set_wheel_state(0.3, [1.0, 2.0, 3.0, 4.0], [0.02, -0.02, 0.0, 0.01])
	cv.set_wheel_state(0.0, [], [])
	cv.set_lights(true, true)
	cv.set_nitro(true)
	cv.set_nitro(false)
	cv.set_ghost(0.4)
	TestHooks.check(body.material_override != null and body.material_override.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED, "ghost_%s" % id)
	cv.set_ghost(1.0)
	TestHooks.check(body.material_override == null, "unghost_%s" % id)
	cv.set_underglow_enabled(false)
	cv.set_underglow_enabled(true)
	cv.set_headlights_real(true)
	cv.set_headlights_real(false)
	var ex := cv.get_exhaust_points()
	TestHooks.check(ex.size() >= 1, "exhausts_%s" % id)
	# wheels sit inside the body width and touch the ground
	var g := CarDefs.geometry(id)
	var p := cv.get_wheel_transform(0).origin
	TestHooks.check(is_equal_approx(p.y, 0.0) and is_equal_approx(p.x, -float(g["track_front"]) * 0.5) and p.z < 0.0, "wheel_fl_pos_%s" % id, str(p))
	# rebuild with a different car id on the same node
	cv.build("veloce" if id != "veloce" else "kaze", {})
	TestHooks.check(cv.get_triangle_count() > 1000, "rebuild_other_%s" % id)


func _sanitize() -> void:
	var cv := CarVisual.new()
	add_child(cv)
	cv.build("nope", {"paint": "notacolor", "rims": 99, "spoiler": -3, "livery": "bogus"})
	TestHooks.check(cv.car_id == "kaze" and cv.get_triangle_count() > 1000, "bad_input_sanitized")
	cv.queue_free()
