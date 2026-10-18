extends Node
## Replays: the bot races our first track in the race scene; the run is recorded (a sample every
## 20 ms with the car's state), kept as the track's autosave (a new record), saved from the finish
## menu, listed, and loaded back unchanged; the viewer (race/replay.tscn) plays it on a puppet car
## that sits where the run was, passes the checkpoints and the finish in the HUD, seeks, changes
## speed and camera; the menu's Replays page lists it and Watch hands it over. Records and replays
## go to test folders.

const LIMIT_MS := 240000


func _ready() -> void:
	TestHooks.args["records"] = "user://test_records"
	TestHooks.args["replays"] = "user://test_replays"
	TestHooks.args.erase("map")
	TmRecords.clear()
	TmReplay.clear()
	var id: String = TmTracks.ids()[0]
	TestHooks.args["track"] = id
	TestHooks.args["bot"] = true
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	while not scene.ready_to_race:
		await get_tree().physics_frame
	var race: TmRace = scene.race
	while race.state != TmRace.State.FINISHED and scene.bot.failed.is_empty() and race.time_ms < LIMIT_MS:
		await get_tree().physics_frame
	var fin := race.finish_ms
	TestHooks.check(race.state == TmRace.State.FINISHED, "replay_bot_finishes", scene.bot.failed)
	if fin < 0:
		TestHooks.finish()
		return
	var rp: TmReplay = scene.replay
	TestHooks.check(rp.count() >= fin / TmReplay.INTERVAL_MS and rp.count() <= fin / TmReplay.INTERVAL_MS + 2 and rp.finish_ms == fin
		and str(rp.splits) == str(race.splits) and rp.track == id and rp.uid == scene.challenge.uid, "replay_recorded",
		"%d samples for %d ms, splits %s / %s" % [rp.count(), fin, rp.splits, race.splits])
	# the replay's poses are the run's (the ghost records the same ticks)
	var g: TmGhost = scene.run
	var worst := 0.0
	for t in range(0, fin, 1370):
		worst = maxf(worst, ((rp.state(t)["xform"] as Transform3D).origin - (g.sample(t)["xform"] as Transform3D).origin).length())
	TestHooks.check(worst < 0.01, "replay_matches_the_run", "%.4f m apart at worst" % worst)
	var gas_seen := false
	for i in rp.count():
		if rp.samples[i * TmReplay.STRIDE + 11] > 0.5:
			gas_seen = true
			break
	TestHooks.check(gas_seen, "replay_has_inputs")
	TestHooks.check(FileAccess.file_exists(TmReplay.autosave_path(scene.challenge)), "replay_autosaved_on_record")
	var saved: String = scene.save_replay()
	TestHooks.check(not saved.is_empty() and FileAccess.file_exists(saved), "replay_saved_from_finish", saved)
	var back := TmReplay.load_file(saved)
	TestHooks.check(back != null and back.samples == rp.samples and back.finish_ms == fin and back.track == id
		and back.splits == rp.splits and back.player == rp.player and back.track_name == rp.track_name, "replay_file_roundtrip")
	var all := TmReplay.list()
	TestHooks.check(all.size() == 2 and all.filter(func(e: Dictionary) -> bool: return e["autosave"]).size() == 1, "replay_list",
		str(all.map(func(e: Dictionary) -> String: return String(e["path"]))))
	var gg := rp.to_ghost()
	TestHooks.check(gg.count() == rp.count() and gg.finish_ms == fin, "replay_to_ghost")
	scene.queue_free()
	await get_tree().physics_frame
	TestHooks.args.erase("bot")
	await _viewer(saved, rp)
	await _menu(saved)
	TmRecords.clear()
	TmReplay.clear()
	TestHooks.finish()


func _viewer(path: String, rp: TmReplay) -> void:
	TestHooks.args["replay"] = path
	var view: Node = (load("res://race/replay.tscn") as PackedScene).instantiate()
	add_child(view)
	await get_tree().process_frame
	TestHooks.check(String(view.error).is_empty() and view.car != null and view.race.state == TmRace.State.COUNTDOWN, "replay_view_opens",
		String(view.error))
	if view.car == null:
		view.queue_free()
		return
	while view.t_ms < 3000.0:
		await get_tree().physics_frame
	var car: TmCar = view.car
	var want: Transform3D = rp.state(view.t_ms)["xform"]
	TestHooks.check(car.global_position.distance_to(want.origin) < 0.01 and view.race.state == TmRace.State.RACING
		and absf(car.speed_kmh()) > 10.0, "replay_puppet_follows", "%.3f m off, %.0f km/h" % [car.global_position.distance_to(want.origin), car.speed_kmh()])
	var fin := rp.finish_ms
	var cps: int = rp.splits.size() - 1
	view.seek(fin - 300.0)
	TestHooks.check(view.race.taken.size() == cps, "replay_seek_passes_checkpoints", "%d / %d" % [view.race.taken.size(), cps])
	while view.t_ms < fin + 50.0:
		await get_tree().physics_frame
	TestHooks.check(view.race.state == TmRace.State.FINISHED and view.race.time_ms == fin, "replay_reaches_the_finish")
	view.seek(1000.0)
	TestHooks.check(view.race.taken.is_empty() and view.race.state == TmRace.State.RACING, "replay_seek_back")
	view.set_speed(TmReplayView.SPEEDS.size() - 1)
	var t0: float = view.t_ms
	for i in 10:
		await get_tree().physics_frame
	TestHooks.check(absf(view.t_ms - t0 - 10 * TmRace.TICK_MS * 4.0) < 1.0, "replay_speed", "%.0f ms in 10 ticks" % (view.t_ms - t0))
	view.toggle_play()
	t0 = view.t_ms
	for i in 5:
		await get_tree().physics_frame
	TestHooks.check(view.t_ms == t0 and not view.playing, "replay_pause")
	var cams := []
	for i in TmReplayView.CAMS.size():
		view.set_camera(i)
		await get_tree().process_frame
		cams.append(get_viewport().get_camera_3d())
	var distinct := {}
	for c: Variant in cams:
		distinct[c] = true
	TestHooks.check(distinct.size() == TmReplayView.CAMS.size(), "replay_cameras", "%d distinct" % distinct.size())
	view.queue_free()
	await get_tree().process_frame


func _menu(path: String) -> void:
	TestHooks.args["menu_dry"] = "true"
	var menu: TmMenu = (load("res://ui/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu.show_page("replays")
	await get_tree().process_frame
	TestHooks.check(menu.replay_rows.size() == 2 and menu.replay_rows.has(path), "replay_menu_lists", str(menu.replay_rows.keys()))
	var got := []
	menu.watched.connect(func(p: String) -> void: got.append(p))
	menu.watch(path)
	TestHooks.check(got == [path] and String(TestHooks.arg("replay", "")) == path and String(TestHooks.arg("back", "")) == "menu", "replay_menu_watch")
	menu.queue_free()
	TestHooks.args.erase("menu_dry")
