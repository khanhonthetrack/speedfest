extends Node
## Headless scenery tests: every theme builds on its sample path, props keep clear of the road
## (TrackPath.edge_clearance > 2 except intentional gantries/arches), lights stay within
## Settings.light_budget(), no duplicate instances (they would z-fight), build time is reasonable.


func _ready() -> void:
	for theme in SceneryKit.THEMES:
		_test_theme(theme, false)
		_test_theme(theme, true)
	TestHooks.check(SceneryKit._norm("downtown") == "city", "theme_from_track_id")
	var rain := SceneryKit.build_rain("city")
	TestHooks.check(rain is SceneryRain, "rain_city")
	rain.free()
	var dry := SceneryKit.build_rain("coast")
	TestHooks.check(not (dry is SceneryRain), "no_rain_coast")
	dry.free()
	TestHooks.finish()


func _test_theme(base_theme: String, raised: bool) -> void:
	var theme := base_theme
	var path := SceneryDemoPaths.for_theme(theme, raised)
	var tag := theme + ("_raised" if raised else "")
	var env := SceneryKit.build_environment(theme)
	add_child(env)
	TestHooks.check(env.find_children("*", "WorldEnvironment", true, false).size() == 1, tag + "_env_world")
	TestHooks.check(env.find_children("*", "DirectionalLight3D", true, false).size() == 1, tag + "_env_key_light")
	var t0 := Time.get_ticks_msec()
	var props := SceneryKit.build_props(theme, path, 1234)
	var ms := Time.get_ticks_msec() - t0
	add_child(props)
	TestHooks.check(ms < 15000, tag + "_build_time", "%d ms" % ms)
	print("BUILD %s %d ms stats=%s" % [theme, ms, str(props.get_meta("stats", {}))])
	# clearance of every recorded footprint
	var fld := SceneryField.new(path, 2.0)
	var bad := 0
	var worst := ""
	for fp in props.get_meta("footprints", []):
		var intentional: bool = fp.size() > 6 and bool(fp[6])
		if intentional:
			continue
		var c: Vector3 = fp[0]
		var hx: float = fp[3]
		var hz: float = fp[4]
		var b: Basis = fp[5]
		for sx: float in [-1.0, 0.0, 1.0]:
			for sz: float in [-1.0, 0.0, 1.0]:
				var p := c + b.x.normalized() * hx * sx + b.z.normalized() * hz * sz + Vector3(0, 1.0, 0)
				var ec := path.edge_clearance(p)
				# XZ clearance covers the whole vertical volume: nothing above, below or into a deck
				var xz := fld.query(p, 20.0)
				if ec <= 2.0 or xz <= 1.5:
					bad += 1
					worst = "%s at %s clearance %.2f" % [fp[2], str(p), ec]
	TestHooks.check(bad == 0, tag + "_props_clear_of_road", "%d violations, e.g. %s" % [bad, worst])
	var lights := 0
	for n in props.find_children("*", "Light3D", true, false):
		if not (n is DirectionalLight3D):
			lights += 1
	TestHooks.check(lights <= Settings.light_budget(), tag + "_light_budget", "%d > %d" % [lights, Settings.light_budget()])
	# (MultiMesh transforms can't be read back headless; kits count duplicates while building)
	var dups: int = props.get_meta("stats", {}).get("duplicates", 0)
	TestHooks.check(dups == 0, tag + "_no_duplicate_instances", "%d duplicates" % dups)
	TestHooks.check(props.get_child_count() > 3, tag + "_has_props")
	props.queue_free()
	env.queue_free()
