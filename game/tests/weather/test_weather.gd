extends Node3D
## Weather tests (headless): rules, TrackSurface math, per-track puddles per mode, and that a car
## really loses grip in a puddle (same steering input turns less, slides more).


func _ready() -> void:
	_rules()
	_surface()
	_tracks()
	await _grip()
	_fx()
	TestHooks.finish()


func _rules() -> void:
	TestHooks.check(Weather.sanitize("STORM") == "storm" and Weather.sanitize("hail") == "dry" and Weather.sanitize(3) == "dry", "sanitize")
	TestHooks.check(Weather.default_for("downtown") == "rain" and Weather.default_for("arena") == "dry", "stage_defaults")
	TestHooks.check(Weather.pb_key("arena", "rain") == "arena@rain", "pb_key")
	TestHooks.check(Weather.next_mode("storm") == "dry", "next_mode")
	TestHooks.check(Weather.puddle_grip("storm") < Weather.puddle_grip("rain") and Weather.puddle_grip("rain") < 1.0, "puddle_grip_order")


func _surface() -> void:
	var s := TrackSurface.new()
	s.add_puddle(Transform3D.IDENTITY, 4.0, 10.0, false)
	s.add_puddle(Transform3D(Basis.IDENTITY, Vector3(0, 0, -100)), 4.0, 10.0, true)
	s.set_mode("dry")
	TestHooks.check(s.water_at(Vector3.ZERO) == 0.0 and s.grip_at(Vector3.ZERO) == 1.0, "dry_no_water")
	s.set_mode("rain")
	TestHooks.check(is_equal_approx(s.water_at(Vector3.ZERO), 1.0), "rain_center_wet")
	TestHooks.check(s.water_at(Vector3(3.6, 0, 0)) == 0.0, "rain_puddle_smaller")
	TestHooks.check(s.water_at(Vector3(0, 0, -100)) == 0.0, "storm_only_dry_in_rain")
	TestHooks.check(s.water_at(Vector3(0, 3, 0)) == 0.0, "above_surface_dry")
	TestHooks.check(absf(s.grip_at(Vector3.ZERO) - Weather.road_grip("rain") * Weather.puddle_grip("rain")) < 1e-4, "rain_center_grip")
	TestHooks.check(absf(s.grip_at(Vector3(20, 0, 0)) - Weather.road_grip("rain")) < 1e-4, "wet_asphalt_grip")
	s.set_mode("storm")
	TestHooks.check(s.water_at(Vector3(3.0, 0, 0)) > 0.0, "storm_puddle_bigger")
	TestHooks.check(s.water_at(Vector3(0, 0, -100)) > 0.9, "storm_only_wet_in_storm")
	TestHooks.check(s.active_count() == 2, "storm_active_count")


func _tracks() -> void:
	for id in TrackDefs.IDS:
		var t := Track.build(id, false)
		add_child(t)
		var counts := {}
		for m in Weather.MODES:
			t.apply_weather(m)
			counts[m] = t.surface.active_count()
			var vis := 0
			for c in t.find_children("Puddle*", "MeshInstance3D", true, false):
				if (c as MeshInstance3D).visible:
					vis += 1
			TestHooks.check(vis == counts[m], "%s_%s_visible_matches" % [id, m], "%d visible vs %d active" % [vis, counts[m]])
		TestHooks.check(counts["dry"] == 0 and counts["rain"] >= 2 and counts["storm"] > counts["rain"], "%s_puddle_counts" % id, str(counts))
		# no puddle may sit on a jump, loop, wall ride or boost pad
		var bad := []
		for pd in t.data["puddles"]:
			for z in t.path.zones:
				if z["kind"] in ["loop", "jump", "wallride", "boost"] and float(pd["d"]) + float(pd["len"]) > float(z["from"]) and float(pd["d"]) < float(z["to"]):
					bad.append("%d in %s" % [int(pd["d"]), z["kind"]])
		TestHooks.check(bad.is_empty(), "%s_puddles_clear_of_stunts" % id, str(bad))
		t.queue_free()


## Same car, same input, flat ground: once dry, once with the whole floor a storm puddle.
func _grip() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000, 2, 4000)
	cs.shape = box
	cs.position.y = -1.0
	floor_body.add_child(cs)
	add_child(floor_body)
	var yaw := {}
	var water_seen := 0.0
	for mode in ["dry", "storm"]:
		var car := Car.create(CarDefs.default_config("kaze"))
		add_child(car)
		for c in car.get_children():
			if c is CarInput:
				(c as CarInput).enabled = false
		var surf := TrackSurface.new()
		surf.add_puddle(Transform3D.IDENTITY, 3000.0, 3000.0, false)
		surf.set_mode(mode)
		car.surface = surf
		car.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), Vector3(0, 0, -33.0))
		for i in 20:
			await get_tree().physics_frame
		var yaw0 := car.global_transform.basis.get_euler().y
		for i in 45:
			car.controls = {"throttle": 0.3, "brake": 0.0, "steer": 1.0, "handbrake": false, "nitro": false}
			await get_tree().physics_frame
		yaw[mode] = absf(wrapf(car.global_transform.basis.get_euler().y - yaw0, -PI, PI))
		if mode == "storm":
			water_seen = car.get_water_amount()
			TestHooks.check(car.get_flags() & 64 != 0, "puddle_net_flag")
		car.queue_free()
		await get_tree().physics_frame
	TestHooks.check(water_seen > 0.9, "car_reports_water", str(water_seen))
	TestHooks.check(float(yaw["storm"]) < float(yaw["dry"]) * 0.85, "puddle_cuts_grip",
		"yaw dry %.3f vs puddle %.3f rad" % [yaw["dry"], yaw["storm"]])
	floor_body.queue_free()


func _fx() -> void:
	var t := Track.build("arena", true)
	add_child(t)
	t.apply_weather("storm")
	var cam := Camera3D.new()
	add_child(cam)
	var fx := WeatherFX.create(t, "storm", cam)
	add_child(fx)
	TestHooks.check(fx.rain != null and fx.rain.get_parent() == cam, "storm_rain_on_camera")
	fx._strike()
	fx._process(0.05)
	TestHooks.check(fx.is_flashing(), "lightning_flash")
	var dry := WeatherFX.create(t, "dry", cam)
	add_child(dry)
	TestHooks.check(dry.rain == null, "dry_no_rain")
	var sp := WaterSpray.create("brute", true)
	add_child(sp)
	sp.update_spray(1.0, 120.0)
	TestHooks.check(sp.splash[0].emitting and sp.mist[0].emitting, "spray_emits")
	sp.update_spray(0.0, 10.0)
	TestHooks.check(not sp.splash[0].emitting and not sp.mist[0].emitting, "spray_stops")
