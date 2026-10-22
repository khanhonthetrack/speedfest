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
## Tuning (PLAN M17): every car of ours with tuning has its kit (8 spoilers, 5 hood shapes), the rim
## library loads, each part has 7-10 choices; a tuned road car and a tuned hypercar draw the picked
## spoiler (or none, or their own), hood shape and finish, the library's rims scaled to their wheels
## (mirrored on the right), the underglow (decal, lights, tubes; none on ghosts); the pick is a
## setting per car (clamped, none for the open-wheeler) and replays keep it.
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
		var parts_ok := rc.has("Body") and rc.has("BrakeF") and rc.has("BrakeR") and (rc.has("WheelF") and rc.has("WheelR")
			or rc.has("TyreF") and rc.has("TyreR") and rc.has("RimF") and rc.has("RimR"))
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
	TestHooks.check(not TmCarVisual.STICKERS.any(func(st: Array) -> bool: return String(st[0]) == "livery_sponsor"),
		"formula_no_sponsors")
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
	await _tuning()


func _tuning() -> void:
	TestHooks.check(TmRoadCars.TUNING.all(func(part: String) -> bool:
		return TmRoadCars.options(part).size() >= 7 and TmRoadCars.options(part).size() <= 10), "tuning_choices")
	var bad := []
	for id: String in TmRoadCars.CARS.map(func(c: Array) -> String: return String(c[0])) + ["hyper"]:
		var kit := TmRoadCars.kit(id)
		for k in range(2, 10):
			if not kit.has("Spoiler%d" % k):
				bad.append("%s Spoiler%d" % [id, k])
		for shape: String in ["Vents", "Scoop", "Bulge", "Louvres", "Cowl"]:
			if not kit.has("Hood" + shape):
				bad.append("%s Hood%s" % [id, shape])
		if id != "hyper" and not TmRoadCars.meshes(id).has("TyreF"):
			bad.append("%s: no TyreF" % id)
	TestHooks.check(bad.is_empty(), "tuning_kits_complete", str(bad))
	# every car's underglow fitted: four tubes under its body (two sills, two across), a light at
	# each, the light on the road baked round it
	var ugbad := []
	for id: String in TmRoadCars.CARS.map(func(c: Array) -> String: return String(c[0])) + ["hyper"]:
		var f := TmUnderglow.fit(id)
		if f.is_empty():
			ugbad.append("%s: no fitting" % id)
			continue
		var ug: Dictionary = TmRoadCars.manifest(id)["underglow"]
		var box := (TmCarVisual._hyper_mesh() if id == "hyper" else TmRoadCars.meshes(id)["Body"] as Mesh).get_aabb()
		var r: Array = f["rect"]
		if (ug["tubes"] as Array).size() != 4 or (f["lights"] as Array).size() != 4:
			ugbad.append("%s: %d tubes" % [id, (ug["tubes"] as Array).size()])
		for line: Array in ug["tubes"]:
			for p: Array in line:
				if absf(p[0]) > box.end.x - 0.05 or p[1] < 0.03 or p[1] > 0.4 or p[2] < box.position.z or p[2] > box.end.z:
					ugbad.append("%s: a tube at %s" % [id, p])
					break
		if r[0] > box.position.x or r[2] < box.end.x or r[1] > box.position.z or r[3] < box.end.z:
			ugbad.append("%s: rect %s" % [id, r])
	TestHooks.check(ugbad.is_empty(), "underglow_fitted", str(ugbad))
	# the baked light (kobold): the front picture brightest at the front, the rear's at the rear,
	# nothing at the border, the tyres' shadows in it
	var kf := TmUnderglow.fit("kobold")
	var front_img := (kf["f"] as Texture2D).get_image()
	var rear_img := (kf["r"] as Texture2D).get_image()
	var kr: Array = kf["rect"]
	var px := func(img: Image, x: float, z: float) -> float:
		var w := img.get_width()
		var h := img.get_height()
		var c := clampi(int((x - float(kr[0])) / (float(kr[2]) - float(kr[0])) * w), 0, w - 1)
		var row := clampi(int((z - float(kr[1])) / (float(kr[3]) - float(kr[1])) * h), 0, h - 1)
		return img.get_pixel(c, row).r
	var kug: Dictionary = TmRoadCars.manifest("kobold")["underglow"]
	var tf: Array = kug["tubes"][2][kug["tubes"][2].size() / 2]       # the middle of the front tube
	var tr: Array = kug["tubes"][3][kug["tubes"][3].size() / 2]
	var wf: Array = TmRoadCars.manifest("kobold")["wheels"][0]
	var near_wheel: float = px.call(front_img, float(wf[0]), float(wf[2]))
	var beside_wheel: float = px.call(front_img, float(wf[0]) - 0.45, float(wf[2]))
	TestHooks.check(px.call(front_img, tf[0], tf[2]) > 0.8 and px.call(front_img, tr[0], tr[2]) < px.call(rear_img, tr[0], tr[2])
		and px.call(rear_img, tr[0], tr[2]) > 0.8 and px.call(front_img, kr[0], kr[1]) < 0.02 and px.call(rear_img, kr[2], kr[3]) < 0.02
		and near_wheel < beside_wheel, "underglow_baked",
		"%.2f %.2f %.2f wheel %.2f beside %.2f" % [px.call(front_img, tf[0], tf[2]), px.call(front_img, tr[0], tr[2]), px.call(rear_img, tr[0], tr[2]), near_wheel, beside_wheel])
	TestHooks.check(TmRoadCars.rims().size() == 9, "tuning_rim_library", str(TmRoadCars.rims().keys()))
	# a tuned road car: the kit's GT wing for its own, the scoop, a carbon hood, mesh rims, cyan underglow
	var v := TmCarVisual.new()
	v.model = "kobold"
	v.tuning = {"spoiler": 6, "rims": 3, "glow": 2, "hood": 9}
	add_child(v)
	await get_tree().process_frame
	var kit := TmRoadCars.kit("kobold")
	var sp := v.get_node_or_null("Spoiler") as MeshInstance3D
	var hood := v.get_node_or_null("Hood") as MeshInstance3D
	TestHooks.check(sp != null and sp.mesh == kit["Spoiler6"] and hood != null and hood.mesh == kit["HoodScoop"]
		and sp.get_surface_override_material(0) != null, "tuned_spoiler_and_hood")
	var man := TmRoadCars.manifest("kobold")
	var rim_l := _rim(v, 0)
	var rim_r := _rim(v, 1)
	var want := Vector3(float(man["tyre_hw"][0]) / TmRoadCars.RIM_REF.y, float(man["rim_r"][0]) / TmRoadCars.RIM_REF.x, 0.0)
	TestHooks.check(rim_l != null and rim_l.mesh == TmRoadCars.rims()["Rim3"] and absf(rim_l.scale.x - want.x) < 1e-4
		and absf(rim_l.scale.y - want.y) < 1e-4 and rim_r != null and rim_r.scale.x < 0.0, "tuned_rims_scaled",
		"%s %s" % [rim_l.scale if rim_l else null, want])
	var stock_rims := 0
	for i in 4:
		for c in v._spins[i].get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh == TmRoadCars.meshes("kobold").get("RimF"):
				stock_rims += 1
	TestHooks.check(stock_rims == 0, "tuned_rims_replace_the_stock_ones")
	var ug := v.get_node_or_null("Underglow") as TmUnderglow
	var cyan: Color = TmRoadCars.GLOWS[2]["colour"]
	var lights := v.find_children("GlowLight*", "OmniLight3D", true, false)
	var tubes := v.get_node_or_null("Underglow/GlowTubes") as MeshInstance3D
	var gf := v.get_node_or_null("Underglow/GlowFront") as Decal
	var gr := v.get_node_or_null("Underglow/GlowRear") as Decal
	TestHooks.check(ug != null and gf != null and gr != null and gf.modulate.is_equal_approx(cyan) and gr.modulate.is_equal_approx(cyan)
		and gf.texture_emission == TmUnderglow.fit("kobold")["f"] and lights.size() == 4
		and lights.all(func(l: OmniLight3D) -> bool: return l.light_color.is_equal_approx(cyan))
		and tubes != null and tubes.mesh.get_surface_count() == 2 and v.get_node_or_null("Underglow/GlowHalo") != null
		and ug.position.is_equal_approx(-TmCarVisual.VIS), "tuned_underglow",
		"%s %s %d %s" % [ug, gf.modulate if gf else null, lights.size(), tubes])
	TestHooks.check(_paint_param(v, 4, "liv_hood") == 1, "tuned_hood_carbon")
	v.queue_free()
	# its own spoiler at 0, none at 1; no underglow on a ghost
	var s0 := TmCarVisual.new()
	s0.model = "kobold"
	add_child(s0)
	var s1 := TmCarVisual.new()
	s1.model = "kobold"
	s1.ghost = true
	s1.tuning = {"spoiler": 1, "glow": 5}
	add_child(s1)
	await get_tree().process_frame
	var own := s0.get_node_or_null("Spoiler") as MeshInstance3D
	TestHooks.check(own != null and own.mesh == TmRoadCars.meshes("kobold")["Spoiler"] and s1.get_node_or_null("Spoiler") == null
		and s0.get_node_or_null("Underglow") == null and s1.get_node_or_null("Underglow") == null, "tuned_stock_and_none")
	s0.queue_free()
	s1.queue_free()
	# the hypercar: no wing, the library's rims on our tyres, a carbon front deck under its own livery
	var h := TmCarVisual.new()
	h.model = "hyper"
	h.tuning = {"spoiler": 1, "rims": 5, "glow": 9, "hood": 1}
	add_child(h)
	var h0 := TmCarVisual.new()
	h0.model = "hyper"
	add_child(h0)
	await get_tree().process_frame
	var hr := _rim(h, 0)
	TestHooks.check(h.get_node_or_null("Spoiler") == null and h0.get_node_or_null("Spoiler") != null
		and (h0.get_node_or_null("Spoiler") as MeshInstance3D).mesh == TmCarVisual._hyper_mesh("HyperSpoiler"), "tuned_hyper_spoiler")
	TestHooks.check(hr != null and hr.mesh == TmRoadCars.rims()["Rim5"] and absf(hr.scale.x - TmCarVisual.TYRE_HW[0] / TmRoadCars.RIM_REF.y) < 1e-4,
		"tuned_hyper_rims")
	TestHooks.check(_paint_param(h, 3, "liv_hood") == 1 and _paint_param(h0, 3, "liv_hood") == 0, "tuned_hyper_hood")
	var c0: Color = (h.get_node("Underglow/GlowFront") as Decal).modulate
	var hu := h.get_node("Underglow") as TmUnderglow
	for k in 30:
		await get_tree().process_frame
	TestHooks.check(not (h.get_node("Underglow/GlowFront") as Decal).modulate.is_equal_approx(c0)
		and float(hu._tube_mat.get_shader_parameter("phase")) > 0.0 and hu.colour_at(0.0) != hu.colour_at(1.0), "tuned_rainbow_cycles")
	h.queue_free()
	h0.queue_free()
	# a two-tone glow: the front's colour at the nose fading to the rear's at the tail
	var two := TmCarVisual.new()
	two.model = "frigate"
	var synth := TmRoadCars.GLOWS.map(func(g: Dictionary) -> String: return String(g["name"])).find("Synthwave")
	two.tuning = {"glow": synth}
	add_child(two)
	await get_tree().process_frame
	var cs: Array = TmRoadCars.GLOWS[synth]["colours"]
	var tu := two.get_node_or_null("Underglow") as TmUnderglow
	TestHooks.check(tu != null and tu.colour_at(0.0).is_equal_approx(cs[0]) and tu.colour_at(1.0).is_equal_approx(cs[1])
		and (two.get_node("Underglow/GlowFront") as Decal).modulate.r > (two.get_node("Underglow/GlowRear") as Decal).modulate.r
		and (two.get_node("Underglow/GlowFront") as Decal).modulate.g < (two.get_node("Underglow/GlowRear") as Decal).modulate.g,
		"tuned_two_tone")
	two.queue_free()
	# the pick: per car, clamped, none for the open-wheeler; replays keep it
	var was: Variant = TmUi.setting("car_tuning")
	TmUi.set_car_tuning("zenith", "spoiler", 7)
	TmUi.set_car_tuning("zenith", "glow", 99)
	var t := TmUi.car_tuning("zenith")
	TestHooks.check(int(t["spoiler"]) == 7 and int(t["glow"]) == TmRoadCars.GLOWS.size() - 1 and int(t["rims"]) == 0
		and TmUi.car_tuning("").is_empty() and int(TmUi.car_tuning("albion")["spoiler"]) == 0, "setting_tuning_per_car")
	var r := TmReplay.new()
	r.model = "zenith"
	r.tuning = t
	var back := TmReplay.new()
	back._set_header(r.header())
	TestHooks.check(int(back.tuning["spoiler"]) == 7, "replay_keeps_the_tuning")
	var old := r.header()
	old.erase("tuning")
	back._set_header(old)
	TestHooks.check(int(back.tuning.get("spoiler", -1)) == 0, "replay_before_tuning_is_stock")
	TmUi.set_setting("car_tuning", was)


## Wheel i's library rim (a tuned car's), or null.
func _rim(v: TmCarVisual, i: int) -> MeshInstance3D:
	for c in v._spins[i].get_children():
		if c is MeshInstance3D and String(c.name).begins_with("Rim"):
			return c
	return null


## The value of a paint material's parameter (the first surface in shader mode `mode`), -1 if none.
func _paint_param(v: TmCarVisual, mode: int, param: String) -> int:
	for mi: MeshInstance3D in v.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s)
			if m is ShaderMaterial and int((m as ShaderMaterial).get_shader_parameter("mode")) == mode:
				return int((m as ShaderMaterial).get_shader_parameter(param))
	return -1
