extends Node3D
## Proof that the circuits can actually be driven: the bot (cars/auto_driver.gd) laps every track
## with a selection of cars, headless, at 100 Hz. A lap that never finishes, a car that leaves the
## road or a bot that has to be rescued is a broken track.
##
## Args: --track=downtown|harbour|all  --car=<id>|all  --max_s=seconds per lap

const DEFAULT_MAX_S := 150.0

var results: Array = []


func _ready() -> void:
	var tracks: Array = TrackDefs.IDS if String(TestHooks.arg("track", "all")) == "all" \
		else [String(TestHooks.arg("track", "downtown"))]
	var cars: Array = ["kaze", "f4", "ridge"] if String(TestHooks.arg("car", "all")) == "all" \
		else [String(TestHooks.arg("car", "kaze"))]
	for t: String in tracks:
		for c: String in cars:
			await _lap(t, c)
	for r: Dictionary in results:
		print("AUTODRIVE %s %s lap=%.2fs top=%.0f km/h rescues=%d" %
			[r["track"], r["car"], r["time"], r["top"], r["rescues"]])
	TestHooks.finish()


func _lap(track_id: String, car_id: String) -> void:
	var builder := TrackBuilder.new()
	var track := builder.build(track_id)
	add_child(track)
	var path := builder.path
	var car := TmCar.new()
	add_child(car)
	var setup := Tuning.default_setup(car_id)
	for slot: String in ["engine", "tyres", "brakes", "suspension"]:
		setup[slot] = 2
	car.configure(car_id, setup)
	var start: Transform3D = builder.info["start"]
	car.place(start)
	var bot := AutoDriver.new()
	bot.car = car
	bot.path = path
	car.add_child(bot)
	bot.reset_to(2.0)
	var rescues := 0
	bot.stuck.connect(func() -> void:
		rescues += 1
		var t := path.sample_transform(fposmod(bot.distance - 6.0, path.length))
		car.place(Transform3D(Basis(-t.basis.x, t.basis.y, -t.basis.z), t.origin))
		bot.reset_to(bot.distance - 6.0))

	var max_s := float(TestHooks.arg("max_s", DEFAULT_MAX_S))
	var ticks := int(max_s * 100.0)
	var top := 0.0
	var off_road := 0
	var done := false
	var t_used := 0
	for i in ticks:
		bot._physics_process(0.01)
		car.step_tick()
		top = maxf(top, absf(car.speed_kmh()))
		if path.edge_clearance(car.global_transform.origin) > 3.0:
			off_road += 1
		if bot.laps >= 1:
			done = true
			t_used = i
			break
		if i % 400 == 399:
			if bool(TestHooks.arg("trace", false)):
				print("  t=%.1fs d=%.0f/%.0f v=%.0f clear=%.1f pos=%s up=%.2f" % [float(i) / 100.0,
					bot.distance, path.length, absf(car.speed_kmh()),
					path.edge_clearance(car.global_transform.origin),
					str(car.global_transform.origin.round()),
					car.global_transform.basis.y.dot(Vector3.UP)])
			await get_tree().process_frame
	var secs := float(t_used) / 100.0
	TestHooks.check(done, "%s/%s completes a lap" % [track_id, car_id],
		"%.0f%% round after %.0f s" % [bot.distance / path.length * 100.0, max_s])
	if done:
		TestHooks.check(secs < max_s, "%s/%s lap time is sane" % [track_id, car_id], "%.1f s" % secs)
		TestHooks.check(top > 120.0, "%s/%s gets up to speed" % [track_id, car_id], "%.0f km/h" % top)
		TestHooks.check(rescues <= 2, "%s/%s needs almost no rescues" % [track_id, car_id], str(rescues))
		TestHooks.check(off_road < 400, "%s/%s stays on the road" % [track_id, car_id],
			"%d ticks wide" % off_road)
	results.append({"track": track_id, "car": car_id, "time": secs, "top": top, "rescues": rescues})
	car.queue_free()
	track.queue_free()
	await get_tree().process_frame
