extends Node3D
## A Stadium race on a map from the player's files, built from the recreated blocks: the car on
## the start block, the chase camera, the HUD and TmRace's rules. The race steps the car itself
## (after the race clock) and tests each tick's motion against the waypoint triggers (TmTriggers).
## Keys: arrows/WASD drive, Enter = respawn at the last checkpoint, Backspace/Delete = restart,
## Escape = pause (TmRaceMenu: resume, restart, menu); after the finish: retry, next track, menu.
## Args: --track=SF01 (our own tracks, TmTracks; the first by default), --map=/path/X.Challenge.Gbx
## (any TMNF track file) or --map=/path/X.sftrack (made in our editor), or --track=A01 with a TMNF install (--tmnf=/path/to/TMNF, else its usual
## place); --laps=N overrides the map's lap count; --bot: TmBot drives (our tracks); TmCarInput's
## --auto_* and TestHooks' --shot/--frames for tests. The menu (ui/menu.tscn, the main scene) starts it.
## Best times and ghosts: every run is recorded (TmGhost); a finish that beats the track's record
## is saved (TmRecords) and its ghost races against you from the next attempt on.
## Replays: every run is recorded as a TmReplay too; a new record keeps it as the track's autosave,
## the finish menu watches it (race/replay.tscn) or saves it (Solo > Replays lists them).
## Testing a track from the editor (--back=editor): a finish validates it (sets its medals,
## TmUserTracks.validate_file) and the menu button goes back to the editor.
## Inputs as text (TmInputScript, TMInterface-style): --inputs=<file> drives the car from a script
## (a TMNF run's inputs on the same track: compare the printed INPUTS_RUN times with the game's),
## --record_inputs=<file> writes this run's inputs at the finish.

var challenge: TmChallenge
var builder: TmMapBuilder
var race: TmRace
var car: TmCar
var input: TmCarInput
var cam: TmCamera
var hud: TmRaceHud
var ready_to_race := false
var best := {}                     ## the track's record: {time_ms, splits}; {} if none
var best_ghost: TmGhost            ## the record's ghost, raced against; null if none
var run: TmGhost                   ## this run, being recorded
var replay: TmReplay               ## this run as a replay, being recorded
var ghost_car: Node3D              ## the best ghost's car (a translucent TmCarVisual)
var new_record := false            ## the last finish set a new record
var menu: TmRaceMenu               ## pause and finish menus
var audio: TmCarAudio              ## engine, skid, wind and the race's cues
var online: TmRaceOnline           ## the online side, in a server (Online)
var bot: TmBot                     ## the driving bot (--bot), else null
var input_script: TmInputScript     ## --inputs=<file>: a script drives the car, else null
var _recorded: Array = []           ## --record_inputs: [time_ms, gas, brake, steer] per tick
var track_id := ""                 ## the campaign track raced ("" for a track file)
var next_id := ""                  ## the campaign track after it ("" if none)

const GHOST_LINGER_MS := 1000      ## the ghost stays this long at its finish, then goes

var _triggers: Array = []          ## [{index, kind, xform, trig}]: waypoints with a trigger
var _prev := Vector3.ZERO          ## the car's position at the previous tick
var _cp_states := {}               ## checkpoint index -> the car as it crossed it {xform, lin, ang}


func _ready() -> void:
	TmUi.apply()
	Music.play_list("race")
	Music.toast(self)
	challenge = TmStage.load_from_args()
	if not challenge.ok():
		push_error("race: %s" % challenge.error)
		if TestHooks.is_testing():
			TestHooks.fail("race_map", challenge.error)
			TestHooks.finish()
		else:
			_message(challenge.error)
		return
	builder = TmMapBuilder.build(challenge)
	add_child(builder.root)
	TmStage.add_environment(self, builder)
	var cps := 0
	for i in builder.waypoints.size():
		var wp: Dictionary = builder.waypoints[i]
		if int(wp["kind"]) == TmBlockCatalogue.Waypoint.CHECKPOINT:
			cps += 1
		var trig := TmTriggers.of(String(wp["block"]))
		if not trig.is_empty():
			_triggers.append({"index": i, "kind": int(wp["kind"]), "xform": wp["xform"], "trig": trig})
	var laps: int = TestHooks.arg("laps", challenge.nb_laps if challenge.lap_race else 1)
	race = TmRace.new(cps, laps)
	race.finished.connect(_on_finished)
	race.checkpoint_taken.connect(func(_count: int, time_ms: int) -> void: _gate_time(time_ms))
	race.lap_done.connect(func(_lap: int, time_ms: int) -> void: _gate_time(time_ms))
	best = TmRecords.best(challenge)
	best_ghost = TmRecords.ghost(challenge) if TmUi.setting("ghost") else null
	ghost_car = Node3D.new()
	ghost_car.name = "Ghost"
	var gv := TmCarVisual.new()
	gv.ghost = true
	ghost_car.add_child(gv)
	add_child(ghost_car)

	car = TmCar.new()
	add_child(car)
	car.set_physics_process(false)    # stepped by the race (_physics_process); after add_child,
	                                  # which turns it back on
	var look := TmCarVisual.new()
	look.paint_colour = TmUi.car_colour()
	car.add_child(look)
	input = TmCarInput.new()
	input.car = car
	add_child(input)
	if TestHooks.has_arg("inputs"):
		input_script = TmInputScript.load_file(String(TestHooks.arg("inputs", "")))
		if not input_script.error.is_empty():
			push_warning("inputs: " + input_script.error)
		input.car = null
	elif TestHooks.has_arg("bot") and not challenge.path.is_empty():
		bot = TmBot.new()
		bot.car = car
		bot.path = challenge.path
		bot.grip = float(TmTracks.spec(String(TestHooks.arg("track", ""))).get("bot_grip", bot.grip))
		add_child(bot)
		input.car = null
	cam = TmCamera.new()
	cam.target = car
	add_child(cam)
	cam.current = true
	hud = TmRaceHud.new()
	hud.race = race
	hud.car = car
	hud.challenge = challenge
	hud.best = best
	add_child(hud)
	menu = TmRaceMenu.new()
	menu.editing = editing()
	add_child(menu)
	_campaign_place()
	menu.has_next = not next_id.is_empty()
	menu.restarted.connect(restart)
	menu.next_track.connect(_next_track)
	menu.to_menu.connect(_to_menu)
	menu.watch_replay.connect(watch_replay)
	menu.save_replay.connect(save_replay)
	audio = TmCarAudio.new()
	audio.car = car
	audio.race = race
	add_child(audio)
	if Online.is_online():
		menu.online = true
		menu.has_next = false
		online = TmRaceOnline.new()
		online.scene = self
		add_child(online)
	print("RACE %s: %d checkpoints, %d lap(s), %d triggers, start %s" % [challenge.name, cps, race.laps,
		_triggers.size(), "yes" if builder.has_start else "MISSING"])
	# the map's collision is in the physics space from the next physics frame
	await get_tree().physics_frame
	restart()
	ready_to_race = true


## A full-screen message (no map to race), e.g. when TMNF isn't installed.
func _message(text: String) -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(l)


func _physics_process(_delta: float) -> void:
	if not ready_to_race:
		return
	race.tick()
	_show_ghost()
	if race.state == TmRace.State.COUNTDOWN:
		return
	if race.racing():
		if input_script:
			var v := input_script.at(race.time_ms)
			car.gas = v[0]
			car.brake = v[1]
			car.steer = v[2]
		if TestHooks.has_arg("record_inputs"):
			_recorded.append([race.time_ms, car.gas, car.brake, car.steer])
	car.step_tick()
	var p := car.global_position
	if race.racing():
		run.record(race.time_ms, car.global_transform, car.model.steer, car.local_velocity().z)
		replay.record(race.time_ms, car)
		for t: Dictionary in _triggers:
			if TmTriggers.crossed(t["trig"], t["xform"], _prev, p) >= 0.0:
				var index := int(t["index"])
				var before := race.respawn_index
				race.cross(index, int(t["kind"]))
				if race.respawn_index == index and before != index:
					# TMNF respawns you at the checkpoint as you crossed it: speed and heading kept
					_cp_states[index] = {"xform": car.global_transform, "lin": car.lin_vel, "ang": car.ang_vel}
	_prev = p


## The best run's ghost at the race clock: at its start through the countdown, gone a moment
## after its finish.
func _show_ghost() -> void:
	var on := best_ghost != null and race.time_ms <= best_ghost.length_ms() + GHOST_LINGER_MS
	ghost_car.visible = on
	if not on:
		return
	var s := best_ghost.sample(race.time_ms)
	ghost_car.global_transform = s["xform"]
	var gv := ghost_car.get_child(0) as TmCarVisual
	gv.ghost_speed = float(s["speed"])
	gv.ghost_steer = float(s["steer"])


func _on_finished(time_ms: int) -> void:
	_gate_time(time_ms)
	if input_script or TestHooks.has_arg("record_inputs"):
		print("INPUTS_RUN splits=%s finish=%d" % [str(race.splits), time_ms])
	if TestHooks.has_arg("record_inputs"):
		var f := FileAccess.open(String(TestHooks.arg("record_inputs", "")), FileAccess.WRITE)
		if f:
			f.store_string(TmInputScript.write(_recorded))
	car.controls_enabled = false
	car.auto_brake = true
	cam.freeze()
	run.record(time_ms, car.global_transform, car.model.steer, car.local_velocity().z)
	run.finish_ms = time_ms
	replay.record(time_ms, car)
	replay.finish_ms = time_ms
	replay.splits = race.splits.map(func(v: int) -> int: return v)
	new_record = TmRecords.submit(challenge, time_ms, race.splits, run)
	if new_record:
		replay.save(TmReplay.autosave_path(challenge))
	if editing() and TmUserTracks.validate_file(String(TestHooks.arg("map", "")), time_ms):
		# the track's medals now come from this finish
		_validated_ms = time_ms
		var m: Dictionary = TmUserTracks.load_file(String(TestHooks.arg("map", ""))).get("medals", {})
		challenge.author_ms = int(m.get("author", -1))
		challenge.gold_ms = int(m.get("gold", -1))
		challenge.silver_ms = int(m.get("silver", -1))
		challenge.bronze_ms = int(m.get("bronze", -1))
		hud.challenge = challenge
	hud.show_finish(time_ms, best, new_record)
	var result := {"name": challenge.name, "time_ms": time_ms, "prev_ms": int(best.get("time_ms", -1)), "record": new_record,
		"medals": {"author": challenge.author_ms, "gold": challenge.gold_ms, "silver": challenge.silver_ms, "bronze": challenge.bronze_ms},
		"validated": _validated_ms == time_ms}
	audio.cue("record" if new_record else "finish")
	if online:
		online.on_finish(time_ms)
	if new_record:
		best = TmRecords.best(challenge)
		best_ghost = run if TmUi.setting("ghost") else null
		hud.best = best
	var this_run := run
	get_tree().create_timer(TmRaceHud.FINISH_FLASH).timeout.connect(func() -> void:
		if run == this_run and race.state == TmRace.State.FINISHED:
			menu.show_finish(result))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_ENTER, KEY_KP_ENTER:
			respawn()
		KEY_BACKSPACE, KEY_DELETE:
			restart()
		KEY_ESCAPE:
			menu.toggle_pause()


## Where the raced track sits in its campaign (track_id, next_id): ours (TmTracks) or TMNF's.
func _campaign_place() -> void:
	if TestHooks.has_arg("map"):
		return
	track_id = String(TestHooks.arg("track", ""))
	if track_id.is_empty() or TmTracks.has(track_id):
		if track_id.is_empty() and not TmTracks.ids().is_empty():
			track_id = TmTracks.ids()[0]
		next_id = TmTracks.next(track_id)
		return
	var all := TmStage.campaign_tracks(TmStage.find_tmnf())
	var i := all.find(track_id)
	if i >= 0 and i + 1 < all.size():
		next_id = all[i + 1]


## Races another track: reloads this scene (in tests, where the race isn't the current scene,
## only notes it in pending_track).
var pending_track := ""


func load_track(track: String) -> void:
	TestHooks.args["track"] = track
	TestHooks.args.erase("map")
	pending_track = track
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


func _next_track() -> void:
	TestHooks.args["track"] = next_id
	get_tree().reload_current_scene()


## Testing a track from the editor (--back=editor with an .sftrack map).
func editing() -> bool:
	return String(TestHooks.arg("back", "")) == "editor" and String(TestHooks.arg("map", "")).ends_with(TmUserTracks.EXT)


var _validated_ms := -1             ## a test drive's finish that validated the track (editing)


func _to_menu() -> void:
	if editing():
		TestHooks.args["edit"] = String(TestHooks.arg("map", ""))
		if get_tree().current_scene == self:
			get_tree().change_scene_to_file("res://editor/editor.tscn")
		return
	if Online.is_online() or online:
		Online.leave()
		TestHooks.args["page"] = "online"
		get_tree().change_scene_to_file("res://ui/menu.tscn")
		return
	var map := String(TestHooks.arg("map", ""))
	TestHooks.args["page"] = "campaign" if not track_id.is_empty() else ("editors" if map.ends_with(TmUserTracks.EXT) else "main")
	if not track_id.is_empty():
		TestHooks.args["track"] = track_id
	get_tree().change_scene_to_file("res://ui/menu.tscn")


## Watches the last run (race/replay.tscn); Esc there comes back to a new attempt here.
func watch_replay() -> void:
	if replay == null or replay.count() == 0 or not replay.save(TmReplay.last_path()):
		return
	TestHooks.args["replay"] = TmReplay.last_path()
	TestHooks.args["replay_back"] = "race"
	TestHooks.args.erase("replay_at")
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://race/replay.tscn")


## Keeps the last run among the replays (Solo > Replays). Returns the file, "" if it failed.
func save_replay() -> String:
	if replay == null or replay.count() == 0:
		return ""
	var to := TmReplay.dir().path_join(replay.file_name())
	if not replay.save(to):
		return ""
	menu.mark_saved()
	return to


## Back to the start: the countdown again, the clock at zero.
func restart() -> void:
	menu.hide_all()
	race.restart()
	run = TmGhost.new()
	replay = TmReplay.start(challenge, track_id, String(TestHooks.arg("map", "")))
	new_record = false
	_cp_states.clear()
	hud.reset()
	TmGateScreen.reset_all(get_tree())
	_recorded.clear()
	if input_script:
		input_script = TmInputScript.load_file(String(TestHooks.arg("inputs", "")))
	if bot:
		bot.reset()
	place_car(builder.start if builder.has_start else Transform3D())


## The time at the gate just passed on its crown screen, with the difference to the record's
## split there (blue ahead, red behind), like TM2020's checkpoints.
func _gate_time(time_ms: int) -> void:
	var s: Array = best.get("splits", [])
	var n := race.splits.size()
	var b := int(s[n - 1]) if n >= 1 and n <= s.size() else -1
	var delta := TmRaceHud.delta_text(time_ms - b) if b >= 0 else ""
	var colour := TmRaceHud.AHEAD if time_ms - b <= 0 else TmRaceHud.BEHIND
	for screen in TmGateScreen.near(get_tree(), car.global_position):
		screen.show_time(TmRace.time_text(time_ms), delta, colour)


## Back to the last checkpoint (the clock keeps running); before any, or after the finish, a restart.
func respawn() -> void:
	if race.state != TmRace.State.RACING or race.respawn_index < 0:
		restart()
		return
	var st: Dictionary = _cp_states.get(race.respawn_index, {})
	if st.is_empty():
		place_car(builder.waypoints[race.respawn_index]["spawn"])
	else:
		var xf: Transform3D = st["xform"]
		car.place(Transform3D(xf.basis, xf.origin - xf.basis.y.normalized() * car.body.rest_height()))
		car.lin_vel = st["lin"]
		car.ang_vel = st["ang"]
		car.controls_enabled = true
		car.auto_brake = false
		_prev = car.global_position
		cam.snap()
	replay.cut()
	audio.cue("respawn", -6.0)


## The car standing still at a spawn point: on the ground when it lies just below (spawns sit up
## to 2.1 m above the road), else in the air there (a ring checkpoint over a jump). look_up: how far
## above the point to look for the ground (tests start cars off-spawn on slopes).
func place_car(spawn: Transform3D, look_up := 1.5) -> void:
	var xf := spawn.orthonormalized()
	var q := PhysicsRayQueryParameters3D.create(xf.origin + xf.basis.y * look_up, xf.origin - xf.basis.y * 2.5, TmCar.WORLD_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var up: Vector3 = hit["normal"]
		var fwd := (xf.basis.z - up * xf.basis.z.dot(up)).normalized()
		xf = Transform3D(Basis(up.cross(fwd), up, fwd), hit["position"])
	car.place(xf)
	car.controls_enabled = true
	car.auto_brake = false
	_prev = car.global_position
	cam.snap()
