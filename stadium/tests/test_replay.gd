extends Node
## Replays: the bot races our first track in the race scene; the run is recorded (a sample every
## 20 ms with the car's state), kept as the track's autosave (a new record), saved from the finish
## menu, listed, and loaded back unchanged; the viewer (race/replay.tscn) plays it on a puppet car
## that sits where the run was, passes the checkpoints and the finish in the HUD, seeks, changes
## speed and camera; the menu's Replays page lists it and Watch hands it over. Also: the car's
## roll after the finish is recorded, a turbo is one event, the race's laps are kept and a lap race
## shows its laps, the keys work whatever bar control has focus, a paused car stands still, any
## file name is listed, and watching from the finish comes back to the finish (SAVE still there).
## Records and replays go to test folders.

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
	TestHooks.check(rp.laps == race.laps and rp.checkpoints == race.checkpoint_count, "replay_keeps_the_laps",
		"%d laps of %d checkpoints" % [rp.laps, rp.checkpoints])
	TestHooks.check(FileAccess.file_exists(TmReplay.autosave_path(scene.challenge)), "replay_autosaved_on_record")
	# the car rolls on past the line for TAIL_MS, recorded; the record's autosave gets it too
	var at_finish := rp.count()
	for i in TmReplay.TAIL_MS / TmRace.TICK_MS + 3:
		await get_tree().physics_frame
	var v_fin := (rp.state(fin)["vel"] as Vector3).length()
	var v_end := (rp.state(fin + TmReplay.TAIL_MS)["vel"] as Vector3).length()
	var auto := TmReplay.load_file(TmReplay.autosave_path(scene.challenge))
	TestHooks.check(rp.count() >= (fin + TmReplay.TAIL_MS) / TmReplay.INTERVAL_MS and rp.length_ms() == fin and v_end < v_fin - 1.0
		and auto != null and auto.count() == rp.count(), "replay_records_the_tail", "%d -> %d samples, %.1f -> %.1f m/s, autosave %d" % [at_finish,
		rp.count(), v_fin, v_end, auto.count() if auto else -1])
	# a turbo pad renews the turbo every tick: only its start is an event
	var turbos := 0
	var held := 0
	for i in rp.count():
		if rp.flags_at(i) & TmReplay.F_TURBO:
			turbos += 1
			if i > 0 and rp.flags_at(i - 1) & TmReplay.F_TURBO:
				held += 1
	TestHooks.check(turbos > 0 and held == 0, "replay_turbo_once", "%d turbos, %d samples held on" % [turbos, held])
	var saved: String = scene.save_replay()
	TestHooks.check(not saved.is_empty() and FileAccess.file_exists(saved), "replay_saved_from_finish", saved)
	var back := TmReplay.load_file(saved)
	TestHooks.check(back != null and back.samples == rp.samples and back.finish_ms == fin and back.track == id
		and back.splits == rp.splits and back.player == rp.player and back.track_name == rp.track_name and back.laps == rp.laps
		and back.checkpoints == rp.checkpoints, "replay_file_roundtrip")
	var all := TmReplay.list()
	TestHooks.check(all.size() == 2 and all.filter(func(e: Dictionary) -> bool: return e["autosave"]).size() == 1, "replay_list",
		str(all.map(func(e: Dictionary) -> String: return String(e["path"]))))
	var gg := rp.to_ghost()
	TestHooks.check(gg.count() == rp.count() and gg.finish_ms == fin, "replay_to_ghost")
	# names: $-codes go, a leading '_' too; any saved file but the last run's is listed
	var named := TmReplay.new()
	named.track_name = "$o$f00Speed"
	var named2 := TmReplay.new()
	named2.track_name = "(test)"
	var odd := TmReplay.dir().path_join("_odd.replay")
	rp.save(odd)
	rp.path = saved
	var listed := TmReplay.list().map(func(e: Dictionary) -> String: return String(e["path"]))
	TestHooks.check(named.file_name().begins_with("Speed ") and not named2.file_name().begins_with("_") and listed.has(odd),
		"replay_names_listed", "%s | %s | %s" % [named.file_name(), named2.file_name(), str(listed)])
	DirAccess.remove_absolute(odd)
	# watching from the finish comes back to the finish, the replay still to save (here: saved)
	scene.watch_replay()
	TestHooks.check(TestHooks.has_arg("finish_result") and FileAccess.file_exists(TmReplay.last_path())
		and TmReplay.list().size() == 2, "replay_watch_from_finish")
	scene.queue_free()
	await get_tree().physics_frame
	TestHooks.args.erase("bot")
	var again: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(again)
	while not again.ready_to_race:
		await get_tree().physics_frame
	await get_tree().process_frame
	var texts := []
	for b in (again.menu as TmRaceMenu)._box.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion():
			texts.append((b as Button).text)
	TestHooks.check(again.race.state == TmRace.State.FINISHED and again.race.finish_ms == fin and again.replay.count() == rp.count()
		and texts.has("SAVED") and texts.has("REPLAY") and not TestHooks.has_arg("finish_result"), "replay_back_to_the_finish",
		"%s, %d ms, %s" % [again.race.state, again.race.finish_ms, str(texts)])
	again.queue_free()
	await get_tree().physics_frame
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
	TestHooks.check(String(view.error).is_empty() and view.car != null and view.race.state == TmRace.State.COUNTDOWN
		and view.audio.race == view.race, "replay_view_opens", String(view.error))
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
	TestHooks.check(view.t_ms == t0 and not view.playing and view.car.speed_kmh() == 0.0 and view.car.gas == 0.0, "replay_pause",
		"%.0f km/h, gas %.2f" % [view.car.speed_kmh(), view.car.gas])
	# the keys work whatever bar control the mouse left focused
	var row: Node = (view._play_btn as Button).get_parent()
	(row.get_child(3) as Button).grab_focus()           # "+"
	var sp: int = view.speed_index
	_key(KEY_SPACE)
	var on_space: bool = view.playing
	(view._slider as HSlider).grab_focus()
	var t1: float = view.t_ms
	_key(KEY_RIGHT)
	TestHooks.check(on_space and view.speed_index == sp and absf(view.t_ms - t1 - 5000.0) < 1.0, "replay_keys_over_focus",
		"playing %s, speed %d -> %d, %.0f -> %.0f ms" % [on_space, sp, view.speed_index, t1, view.t_ms])
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
	await _laps(path)


## A two-lap run (this one's splits spread over two laps): the lap line counts as a lap, not a
## checkpoint, and each lap counts its own checkpoints.
func _laps(path: String) -> void:
	var lr := TmReplay.load_file(path)
	var c := lr.splits.size() - 1
	lr.laps = 2
	lr.checkpoints = c
	lr.splits = []
	for k in 2 * c + 2:
		lr.splits.append(lr.finish_ms * (k + 1) / (2 * c + 2))
	var lap_path := TmReplay.dir().path_join("laps.replay")
	lr.save(lap_path)
	TestHooks.args["replay"] = lap_path
	var view: Node = (load("res://race/replay.tscn") as PackedScene).instantiate()
	add_child(view)
	await get_tree().process_frame
	var race: TmRace = view.race
	var laps := []
	race.lap_done.connect(func(l: int, _t: int) -> void: laps.append(l))
	var line := int(lr.splits[c])
	view.seek(line - 100.0)
	var before := [race.lap, race.taken.size()]
	while view.t_ms < line + 30.0:
		await get_tree().physics_frame
	var after := [race.lap, race.taken.size()]
	view.seek(int(lr.splits[c + 1]) + 10.0)
	var next := [race.lap, race.taken.size()]
	TestHooks.check(race.laps == 2 and before == [0, c] and laps == [1] and after == [1, 0] and next == [1, 1], "replay_lap_splits",
		"before %s, laps %s, after %s, next %s" % [before, laps, after, next])
	view.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(lap_path)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		get_viewport().push_input(ev)


func _menu(path: String) -> void:
	TestHooks.args["menu_dry"] = "true"
	var menu: TmMenu = (load("res://ui/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu.show_page("replays")
	await get_tree().process_frame
	TestHooks.check(menu.replay_rows.size() == 2 and menu.replay_rows.has(path), "replay_menu_lists", str(menu.replay_rows.keys()))
	# selection follows presses only: hovering (focus) another row leaves DELETE on the picked one
	var paths: Array = menu.replay_rows.keys()
	var other := String(paths[0]) if String(paths[0]) != path else String(paths[1])
	(menu.replay_rows[path] as Button).pressed.emit()
	if menu.replay_selected != path:
		(menu.replay_rows[path] as Button).pressed.emit()   # it was preselected: a press watched it; pick again
	menu.replay_selected = path
	(menu.replay_rows[other] as Button).grab_focus()
	(menu.replay_rows[other] as Button).focus_entered.emit()
	var del: Button = menu._del_btn
	del.pressed.emit()
	TestHooks.check(menu.replay_selected == path and del.text.begins_with("DELETE ") and del.text.ends_with("?")
		and FileAccess.file_exists(path), "replay_menu_delete_asks", "%s %s" % [menu.replay_selected, del.text])
	del.pressed.emit()
	await get_tree().process_frame
	TestHooks.check(not FileAccess.file_exists(path) and FileAccess.file_exists(other), "replay_menu_deletes_the_picked_one")
	var got := []
	menu.watched.connect(func(p: String) -> void: got.append(p))
	menu.watch(path)
	TestHooks.check(got == [path] and String(TestHooks.arg("replay", "")) == path and String(TestHooks.arg("replay_back", "")) == "menu", "replay_menu_watch")
	menu.queue_free()
	TestHooks.args.erase("menu_dry")
