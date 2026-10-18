extends Node
## Sounds (no TMNF install needed): every stream (the recordings in audio/sfx) exists and isn't
## silent, the loops loop, the virtual rpm climbs through each gear and drops at the shifts, the engine
## follows the throttle and the speed, and the countdown beeps then says go.


func _ready() -> void:
	_streams()
	_rpm()
	await _engine()
	await _countdown()
	TestHooks.finish()


static func _rms(w: AudioStreamWAV) -> float:
	var d := w.data
	var n := d.size() / 2
	var s := 0.0
	for i in range(0, n, 7):
		var v := d.decode_s16(i * 2) / 32768.0
		s += v * v
	return sqrt(s / (n / 7.0))


func _streams() -> void:
	var t0 := Time.get_ticks_msec()
	var bad := []
	for name: String in TmSounds.NAMES:
		var w := TmSounds.get_stream(name)
		if w == null or w.get_length() <= 0.0 or (w is AudioStreamWAV and _rms(w as AudioStreamWAV) < 0.01):
			bad.append(name)
	TestHooks.check(bad.is_empty(), "sound_streams_not_silent", str(bad))
	TestHooks.check(Time.get_ticks_msec() - t0 < 4000, "sound_loading_quick", "%d ms" % (Time.get_ticks_msec() - t0))
	var loops_ok := true
	for name: String in TmSounds.LOOPS:
		var w := TmSounds.get_stream(name)
		if w is AudioStreamWAV:
			loops_ok = loops_ok and (w as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD and (w as AudioStreamWAV).loop_end > 0
		elif w is AudioStreamOggVorbis:
			loops_ok = loops_ok and (w as AudioStreamOggVorbis).loop
	TestHooks.check(loops_ok, "sound_loops_loop")
	var recorded := TmSounds.FILES.keys().all(func(k: String) -> bool: return ResourceLoader.exists("res://audio/sfx/" + String(TmSounds.FILES[k])))
	TestHooks.check(recorded and TmSounds.get_stream("engine_mid").resource_path.ends_with("engine_mid.wav"), "sound_recordings_used")


func _rpm() -> void:
	TestHooks.check(is_equal_approx(TmSounds.rpm(0.0), TmSounds.RPM_IDLE), "rpm_idle")
	TestHooks.check(TmSounds.rpm(20.0) < TmSounds.rpm(40.0) and TmSounds.rpm(120.0) < TmSounds.rpm(150.0), "rpm_climbs_in_gear")
	# TMNF's shift points: 0.95 x 85, 0.9 x 110, 0.95 x 160, 0.95 x 220, 1.0 x 370 km/h
	TestHooks.check(TmSounds.rpm(80.0) > TmSounds.rpm(82.0) and TmSounds.rpm(208.0) > TmSounds.rpm(210.0), "rpm_drops_at_shifts")
	TestHooks.check(TmSounds.gear_for(30.0) == 1 and TmSounds.gear_for(180.0) == 4 and TmSounds.gear_for(500.0) == 6
		and is_equal_approx(TmSounds.rpm(500.0), TmSounds.RPM_MAX), "rpm_gears")
	TestHooks.check(TmSounds.rpm(900.0) <= TmSounds.RPM_MAX and TmSounds.rpm(-80.0) == TmSounds.rpm(80.0), "rpm_bounds")


func _engine() -> void:
	var car := TmCar.new()
	add_child(car)
	car.set_physics_process(false)
	var audio := TmCarAudio.new()
	audio.car = car
	add_child(audio)
	car.gas = 1.0
	for i in 40:
		await get_tree().process_frame
	TestHooks.check(audio.engine_mix > 0.9, "engine_follows_throttle", "%.2f" % audio.engine_mix)
	# off the throttle (the test car floats: with gas the engine would rev freely as in the air)
	car.gas = 0.0
	car.lin_vel = car.global_transform.basis.z * 50.0
	for i in 30:
		await get_tree().process_frame
	car.lin_vel = car.global_transform.basis.z * 50.0
	await get_tree().process_frame
	var want := TmSounds.rpm(car.speed_kmh())
	TestHooks.check(absf(audio.engine_rpm - want) < want * 0.03 and audio.engine_gear == TmSounds.gear_for(car.speed_kmh())
		and car.speed_kmh() > 170.0, "engine_rpm_follows_speed",
		"%.0f vs %.0f rpm, gear %d at %.0f km/h" % [audio.engine_rpm, want, audio.engine_gear, car.speed_kmh()])
	for i in 40:
		await get_tree().process_frame
	TestHooks.check(audio.engine_mix < 0.1, "engine_coasts_off_throttle", "%.2f" % audio.engine_mix)
	audio.queue_free()
	car.queue_free()


func _countdown() -> void:
	var car := TmCar.new()
	add_child(car)
	car.set_physics_process(false)
	var race := TmRace.new(0, 1)
	var audio := TmCarAudio.new()
	audio.car = car
	audio.race = race
	add_child(audio)
	race.restart()
	var heard := []
	while race.state == TmRace.State.COUNTDOWN or heard.size() < 4:
		race.tick()
		await get_tree().process_frame
		for v in audio.get_children():
			if v is AudioStreamPlayer and (v as AudioStreamPlayer).playing and (v as AudioStreamPlayer).stream in [TmSounds.get_stream("beep"), TmSounds.get_stream("go")]:
				var key := "go" if (v as AudioStreamPlayer).pitch_scale > 1.2 else "beep%d" % v.get_index()
				if not heard.has(key):
					heard.append(key)
		if race.time_ms > 500:
			break
	TestHooks.check(heard.has("go") and heard.size() >= 3, "countdown_beeps_then_go", str(heard))
	audio.queue_free()
	car.queue_free()
