extends Node
## Audio test: every generated stream loads with the right loop flag and length, EngineAudio
## behaves through an rpm sweep (local and remote, every car), and every Audio call works.
## Run: tools/run_scene.sh res://tests/audio/test_audio.tscn --headless -- --frames=2000

const Layers = preload("res://audio/engine_layers.gd")
const GEN := "res://audio/generated/"

var _audio: Node


func _ready() -> void:
	_audio = get_node("/root/Audio")
	_test_streams()
	await _test_engines()
	await _test_audio_api()
	TestHooks.finish()


# --------------------------------------------------------------------------- streams

func _test_streams() -> void:
	var loops: Array[String] = ["car_turbo", "car_nitro", "car_squeal", "car_wind"]
	for car in Layers.CARS:
		for l in ["idle", "mid", "high", "off"]:
			loops.append("eng_%s_%s" % [car, l])
	var musics: Array[String] = []
	for k in _audio.MUSIC:
		musics.append(String(_audio.MUSIC[k][0]))
	var oneshots: Array[String] = []
	for k in _audio.UI:
		oneshots.append(String(_audio.UI[k][0]))
	for k in _audio.SFX:
		var f := String(_audio.SFX[k][0])
		if not oneshots.has(f):
			oneshots.append(f)
	var bad := 0
	for f in loops:
		bad += _check_stream(f, true, 0.8, 4.5)
	for f in musics:
		bad += _check_stream(f, true, 50.0, 100.0)
	for f in oneshots:
		# thunder is a long one-shot (crack + rolling rumble)
		bad += _check_stream(f, false, 0.03, 6.0 if f == "sfx_thunder" else 3.0)
	for k in _audio.AMBIENCE:
		bad += _check_stream(String(_audio.AMBIENCE[k][0]), true, 2.0, 8.0)
	TestHooks.check(bad == 0, "streams_all_ok", "%d bad" % bad)
	# engine layer table is sane
	for car in Layers.CARS:
		var d: Dictionary = Layers.CARS[car]
		var ls: Dictionary = d["layers"]
		TestHooks.check(float(ls["idle"]) < float(ls["mid"]) and float(ls["mid"]) < float(ls["high"]) and float(d["idle_rpm"]) < float(d["redline"]), "layers_ordered_" + car)


func _check_stream(file: String, want_loop: bool, min_len: float, max_len: float) -> int:
	var path := GEN + file + ".ogg"
	if not ResourceLoader.exists(path):
		TestHooks.fail("stream_" + file, "missing " + path)
		return 1
	# CACHE_MODE_IGNORE: see the imported flags, not ones set at runtime
	var s := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamOggVorbis
	if s == null:
		TestHooks.fail("stream_" + file, "not an AudioStreamOggVorbis")
		return 1
	var length := s.get_length()
	if length < min_len or length > max_len:
		TestHooks.fail("stream_" + file, "length %.2f not in [%.2f, %.2f]" % [length, min_len, max_len])
		return 1
	if s.loop != want_loop:
		TestHooks.fail("stream_" + file, "loop=%s, want %s" % [s.loop, want_loop])
		return 1
	return 0


# --------------------------------------------------------------------------- EngineAudio

func _test_engines() -> void:
	for car in Layers.CARS:
		await _engine_local(String(car))
		await _engine_remote(String(car))
	# eight engines at once (1 local + 7 remote) stay cheap: count players
	var holder := Node3D.new()
	add_child(holder)
	var total := 0
	for i in 8:
		var e := EngineAudio.new()
		holder.add_child(e)
		e.setup(Layers.CARS.keys()[i % 3], i == 0)
		total += e.get_player_count()
	TestHooks.check(total <= 11 + 7 * 2, "eight_cars_player_budget", "%d players" % total)
	for i in 30:
		for e in holder.get_children():
			(e as EngineAudio).set_params(0.5 + 0.4 * sin(i * 0.2), 1.0, 150.0, 0.0, false, true)
		await get_tree().process_frame
	holder.queue_free()
	# unknown car falls back instead of crashing; set_params before setup is ignored
	var e2 := EngineAudio.new()
	e2.set_params(0.5, 1.0, 100.0, 0.0, false, true)
	add_child(e2)
	e2.setup("nope", true)
	TestHooks.check(e2.car_id == "kaze", "engine_unknown_car_fallback")
	e2.queue_free()


func _engine_local(car: String) -> void:
	var e := EngineAudio.new()
	e.setup(car, true)   # before entering the tree: players are built in _ready
	add_child(e)
	TestHooks.check(e.get_player_count() == 11, "engine_local_players_" + car, str(e.get_player_count()))
	# idle
	await _drive(e, 30, 0.0, 0.0, 0.0, 0.0, false, true)
	var d := e.get_debug()
	TestHooks.check(_g(d, "idle") > _g(d, "high") and _g(d, "idle") > 0.1, "engine_idle_dominant_" + car, _fmt(d))
	# rpm sweep on full throttle: gains finite, pitch within bounds, power roughly constant
	var ok_sweep := true
	var why := ""
	var prev_dom := "idle"
	var order: Array[String] = ["idle", "mid", "high"]
	for i in 121:
		var r := i / 120.0
		await _drive(e, 1, r, 1.0, 40.0 + 260.0 * r, 0.0, false, true)
		d = e.get_debug()
		var pw := 0.0
		var dom := "idle"
		for k in order:
			var g := _g(d, k)
			pw += g * g
			if g > _g(d, dom):
				dom = k
			if is_nan(g) or g < 0.0 or g > 1.5:
				ok_sweep = false
				why = "bad gain %s=%f" % [k, g]
			if _g(d, k) > 0.01:
				var p := float(d[k]["pitch"])
				if p < 0.25 or p > 3.5:
					ok_sweep = false
					why = "pitch %s=%f at r=%.2f" % [k, p, r]
		if order.find(dom) < order.find(prev_dom):
			ok_sweep = false
			why = "dominant layer went back from %s to %s" % [prev_dom, dom]
		prev_dom = dom
		if pw < 0.05:
			ok_sweep = false
			why = "engine almost silent at r=%.2f (%f)" % [r, pw]
	TestHooks.check(ok_sweep, "engine_sweep_" + car, why)
	await _drive(e, 20, 1.0, 1.0, 300.0, 0.0, false, true)
	d = e.get_debug()
	TestHooks.check(_g(d, "high") > _g(d, "mid") and _g(d, "high") > _g(d, "idle"), "engine_high_dominant_" + car, _fmt(d))
	TestHooks.check(_g(d, "wind") > 0.2, "engine_wind_at_speed_" + car, _fmt(d))
	TestHooks.check(float(d.get("boost", 0.0)) > 0.3, "engine_boost_builds_" + car, str(d.get("boost")))
	# lift off: off layer comes in, turbo collapses, blow-off for turbo cars
	await _drive(e, 25, 0.8, 0.0, 280.0, 0.0, false, true)
	d = e.get_debug()
	TestHooks.check(_g(d, "off") > 0.1, "engine_off_layer_" + car, _fmt(d))
	TestHooks.check(_g(d, "turbo") < 0.05, "engine_turbo_collapses_" + car, _fmt(d))
	if float(Layers.CARS[car]["turbo"]) > 0.2:
		TestHooks.check(d.get("last_oneshot", "") == "car_blowoff", "engine_blowoff_" + car, str(d.get("last_oneshot", "")))
	# nitro, drift, airtime + landing
	await _drive(e, 20, 0.9, 1.0, 200.0, 0.8, true, true)
	d = e.get_debug()
	TestHooks.check(_g(d, "nitro") > 0.3, "engine_nitro_" + car, _fmt(d))
	TestHooks.check(_g(d, "squeal") > 0.2, "engine_squeal_" + car, _fmt(d))
	await _drive(e, 50, 0.9, 1.0, 200.0, 0.8, false, false)
	d = e.get_debug()
	TestHooks.check(_g(d, "squeal") < 0.05, "engine_no_squeal_in_air_" + car, _fmt(d))
	await _drive(e, 3, 0.9, 1.0, 200.0, 0.0, false, true)
	TestHooks.check(e.get_debug().get("last_oneshot", "") == "car_land", "engine_landing_" + car, str(e.get_debug().get("last_oneshot", "")))
	# silence everything optional at rest
	await _drive(e, 60, 0.0, 0.0, 0.0, 0.0, false, true)
	d = e.get_debug()
	TestHooks.check(not d["squeal"]["playing"] and not d["nitro"]["playing"] and not d["wind"]["playing"], "engine_extras_paused_at_rest_" + car, _fmt(d))
	e.queue_free()
	await get_tree().process_frame


func _engine_remote(car: String) -> void:
	var holder := Node3D.new()
	add_child(holder)
	var e := EngineAudio.new()
	holder.add_child(e)
	e.setup(car, false)
	TestHooks.check(e.get_player_count() == 2, "engine_remote_players_" + car, str(e.get_player_count()))
	var all3d := true
	for c in e.get_children():
		if not (c is AudioStreamPlayer3D):
			all3d = false
	TestHooks.check(all3d, "engine_remote_positional_" + car)
	var ok := true
	for i in 61:
		await _drive(e, 1, i / 60.0, 1.0, i * 5.0, 0.0, false, true)
		var d := e.get_debug()
		var pw := _g(d, "mid") ** 2 + _g(d, "high") ** 2
		if pw < 0.05 or is_nan(pw):
			ok = false
	TestHooks.check(ok, "engine_remote_sweep_" + car)
	holder.queue_free()
	await get_tree().process_frame


func _drive(e: EngineAudio, frames: int, rpm: float, thr: float, speed: float, drift: float, nitro: bool, grounded: bool) -> void:
	for i in frames:
		e.set_params(rpm, thr, speed, drift, nitro, grounded)
		await get_tree().process_frame


func _g(d: Dictionary, k: String) -> float:
	if not d.has(k):
		return 0.0
	return float(d[k]["gain"])


func _fmt(d: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in d:
		if d[k] is Dictionary:
			parts.append("%s=%.2f@%.2f" % [k, d[k]["gain"], d[k]["pitch"]])
		else:
			parts.append("%s=%s" % [k, str(d[k])])
	return ", ".join(parts)


# --------------------------------------------------------------------------- Audio autoload

func _test_audio_api() -> void:
	var n0: int = _audio.get_player_count()
	for k in _audio.UI:
		_audio.play_ui(k)
	for k in _audio.SFX:
		_audio.play_sfx(k)
	_audio.play_sfx("checkpoint", -6.0, 1.2)
	for i in 40:   # spam: pools must not grow
		_audio.play_ui("hover")
		_audio.play_sfx("wall_hit", -3.0, randf_range(0.9, 1.1))
	_audio.play_ui("does_not_exist")
	_audio.play_sfx("does_not_exist")
	await get_tree().process_frame
	TestHooks.check(_audio.get_player_count() == n0, "audio_pools_fixed", "%d -> %d" % [n0, _audio.get_player_count()])
	_audio.play_music("menu")
	await _frames(10)
	TestHooks.check(_audio.current_music() == "menu" and _audio.is_music_playing(), "music_menu_plays")
	_audio.play_music("menu")   # same track: no restart
	_audio.play_music("race")
	await _frames(5)
	_audio.play_music("menu")   # rapid switching
	_audio.play_music("race")
	await _frames(150)
	TestHooks.check(_audio.current_music() == "race" and _audio.is_music_playing(), "music_crossfade_to_race")
	var playing := 0
	for c in _audio.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).bus == Settings.BUS_MUSIC and (c as AudioStreamPlayer).playing:
			playing += 1
	TestHooks.check(playing == 1, "music_old_track_stopped", "%d music players playing" % playing)
	_audio.play_music("")
	await _frames(120)
	TestHooks.check(_audio.current_music() == "" and not _audio.is_music_playing(), "music_stop_via_empty")
	_audio.play_music("race")
	_audio.stop_music()
	await _frames(120)
	var any := false
	for c in _audio.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).bus == Settings.BUS_MUSIC and (c as AudioStreamPlayer).playing:
			any = true
	TestHooks.check(not any, "music_stop_music")
	_audio.play_music("nope")
	TestHooks.ok("audio_api_no_crash")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
