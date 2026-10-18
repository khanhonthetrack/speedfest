extends Node
## Community car packs without downloads: writes (TmTestCar) a small TMNF car model of our own (a CPlugSolid
## as TMNF's exporters write them: binary, and the old text format), a DXT1 Diffuse.dds with the
## header quirks old exporters leave (a wrong linear size, a mipmap chain that stops at 2 x 2), a
## Details.png and an engine sound, zips them like a ManiaPark pack, and checks TmSolid, TmCarPack
## and a TmCarVisual driving it: parts, mirroring into our frame, wheels found and placed by where
## they sit, textures decoded, lamps, the wheels spinning and steering.
## The ManiaPark sample test is tests/test_compat_cars (needs a download).

func _ready() -> void:
	var writer := TmTestCar.new()
	var bin := writer.solid(false)
	var txt := writer.solid(true)
	for pair: Array in [["binary", bin], ["text", txt]]:
		var s := TmSolid.load_bytes(pair[1])
		TestHooks.check(s.ok(), "solid_reads_%s" % pair[0], s.error)
		if not s.ok():
			continue
		TestHooks.check(s.parts.size() == TmTestCar.PARTS.size(), "solid_parts_%s" % pair[0], "%d parts" % s.parts.size())
		TestHooks.check(s.triangle_count() == TmTestCar.PARTS.size() * 12, "solid_triangles_%s" % pair[0], "%d" % s.triangle_count())
		TestHooks.check(s.points.has(TmTestCar.LAMP[0]), "solid_points_%s" % pair[0], str(s.points.keys()))
		# mirrored into our frame: TMNF's FL wheel (+x) is at -x
		var fl: Dictionary = s.parts.filter(func(p: Dictionary) -> bool: return p["name"] == "dFLWheel")[0]
		var c := (fl["xform"] as Transform3D).origin
		TestHooks.check(c.is_equal_approx(Vector3(-0.8, 0.36, 1.4)), "solid_mirrored_%s" % pair[0], str(c))
	# the same model written binary and as text: binary files keep v upwards, text files downwards
	var sb := TmSolid.load_bytes(bin)
	var st := TmSolid.load_bytes(txt)
	if sb.ok() and st.ok():
		var ub: PackedVector2Array = sb.parts[0]["uvs"]
		var ut: PackedVector2Array = st.parts[0]["uvs"]
		TestHooks.check(ub.size() == 8 and ut.size() == 8 and is_equal_approx(ub[0].y, 1.0 - ut[0].y)
			and is_equal_approx(ub[0].x, ut[0].x), "solid_uv_v_by_format", "%s %s" % [ub, ut])
	# normals the exporter left out: their faces' (outward)
	var tri_v := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)])
	var tri_n := PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.UP])
	TmCarPack._repair_normals(tri_v, tri_n, PackedInt32Array([0, 1, 2]))
	TestHooks.check(tri_n[0].is_equal_approx(Vector3.UP) and tri_n[1].is_equal_approx(Vector3.UP), "pack_missing_normals_rebuilt",
		str(tri_n))
	var zip := ProjectSettings.globalize_path("user://test_car_pack.zip")
	writer.zip(zip, bin)
	var pack := TmCarPack.load_zip(zip)
	TestHooks.check(pack.ok(), "pack_loads", pack.error)
	if not pack.ok():
		TestHooks.finish()
		return
	TestHooks.check(pack.textures.has("diffuse"), "pack_dds_with_quirks_decodes", str(pack.textures.keys()))
	TestHooks.check(pack.textures.has("details"), "pack_png_decodes", str(pack.textures.keys()))
	TestHooks.check(pack.sounds.has("engine_idle"), "pack_engine_sound", str(pack.sounds.keys()))
	var surfaces := []
	for i in pack.body.get_surface_count():
		surfaces.append(pack.body.surface_get_name(i))
	surfaces.sort()
	TestHooks.check(surfaces == ["pack_details", "pack_skin"], "pack_body_by_material", str(surfaces))
	var ok := true
	for i in 4:
		var w: Dictionary = pack.wheels[i]
		var want: Vector3 = TmTuning.WHEELS[i]
		ok = ok and not w.is_empty() and signf((w["centre"] as Vector3).x) == signf(want.x) \
			and signf((w["centre"] as Vector3).z) == signf(want.z) and w["spin"] != null
	TestHooks.check(ok, "pack_wheels_by_place", str(pack.wheels.map(func(w: Dictionary) -> Variant: return w.get("centre"))))
	TestHooks.check(pack.lamps.has(TmTestCar.LAMP[0]), "pack_lamps", str(pack.lamps.keys()))
	pack.textures["illum"] = pack.textures["details"]
	var lit := pack.material("pack_details")
	TestHooks.check(lit.emission_enabled and lit.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY, "pack_lamps_lit_by_illum")
	pack.textures.erase("illum")
	TestHooks.check(TmCarPack.material_of("WheelFLd") == "d" and TmCarPack.material_of("Skin") == "s"
		and TmCarPack.material_of("gBody") == "g" and TmCarPack.material_of("sBody001") == "s"
		and TmCarPack.material_of("ProjShad") == "" and TmCarPack.material_of("LightFL1") == "",
		"pack_part_names", "")
	TestHooks.check(TmCarPack.wheel_of("WheelRRs01") == [3, true] and TmCarPack.wheel_of("dFLHub") == [0, false]
		and TmCarPack.wheel_of("sBody") == [-1, false], "pack_wheel_names", "")
	# a visual drives it
	var holder := Node3D.new()
	add_child(holder)
	var v := TmCarVisual.new()
	v.pack = pack
	v.ghost_speed = 20.0
	v.ghost_steer = 1.0
	holder.add_child(v)
	await get_tree().process_frame
	await get_tree().process_frame
	var spin := (v._wheels[0].get_child(0) as Node3D).rotation.x
	TestHooks.check(v._wheels.size() == 4 and absf(spin) > 0.0, "visual_wheels_spin", "spin %f" % spin)
	TestHooks.check(v._wheels[0].rotation.y > 0.1 and is_zero_approx(v._wheels[2].rotation.y), "visual_front_wheels_steer",
		"%f %f" % [v._wheels[0].rotation.y, v._wheels[2].rotation.y])
	var rest: Vector3 = (pack.wheels[0]["centre"] as Vector3) - TmCarVisual.VIS
	TestHooks.check(v._rest[0].is_equal_approx(rest), "visual_wheel_at_its_centre", str(v._rest[0]))
	# a skin without its model: our car in its colour (the DDS is red)
	var skin := ProjectSettings.globalize_path("user://test_skin_only.zip")
	writer.zip_files(skin, {"Diffuse.dds": "diffuse", "Details.png": "png"})
	var sp := TmCarPack.load_zip(skin)
	TestHooks.check(sp.ok() and sp.skin_only and sp.colour.r > 0.7 and sp.colour.g < 0.3, "pack_skin_only",
		"%s %s %s" % [sp.error, sp.skin_only, sp.colour])
	var sv := TmCarVisual.new()
	sv.pack = sp
	holder.add_child(sv)
	await get_tree().process_frame
	TestHooks.check(not sv._from_pack and sv.paint_colour == sp.colour and sv._wheels.size() == 4, "visual_skin_only_paints_ours")
	DirAccess.remove_absolute(skin)
	# a model that doesn't read, its menu version does
	var high := ProjectSettings.globalize_path("user://test_high_only.zip")
	writer.zip_files(high, {"MainBody.Solid.Gbx": "GBX broken".to_ascii_buffer(), "MainBodyHigh.Solid.Gbx": bin,
		"Diffuse.dds": "diffuse"})
	var hp := TmCarPack.load_zip(high)
	TestHooks.check(hp.ok() and not hp.skin_only and hp.solid.parts.size() == TmTestCar.PARTS.size(), "pack_falls_back_to_high",
		hp.error)
	DirAccess.remove_absolute(high)
	var bad := TmCarPack.load_zip(ProjectSettings.globalize_path("user://no_such_pack.zip"))
	TestHooks.check(not bad.ok(), "pack_missing_file_fails", bad.error)
	DirAccess.remove_absolute(zip)
	TestHooks.finish()
