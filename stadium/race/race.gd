extends Node3D
## A Stadium race on a map from the player's files, built from the recreated blocks: the car on
## the start block, the chase camera, the HUD and TmRace's rules. The race steps the car itself
## (after the race clock) and tests each tick's motion against the waypoint triggers (TmTriggers).
## Keys: arrows/WASD drive, Enter = respawn at the last checkpoint, Backspace/Delete = restart,
## 1/2/3 = TMNF's views (TmCamera.view), Escape = pause (TmRaceMenu: resume, restart, menu); after
## the finish: retry, next track, menu. --cam_view=0|1|2 starts in that view (screenshots).
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
var best_ghost: TmGhost            ## the ghost raced against (the record's, or the opponent picked); null if none
var top_bar: TmTopBar              ## TMNF's bar at the top right (volumes, display, clock, window)
var opponent := ""                 ## the opponent picked (gold, silver, bronze, best, none); "" not asked
var run: TmGhost                   ## this run, being recorded
var replay: TmReplay               ## this run as a replay, being recorded
var ghost_car: Node3D              ## the best ghost's car (a translucent TmCarVisual)
var new_record := false            ## the last finish set a new record
var menu: TmRaceMenu               ## pause and finish menus
var audio: TmCarAudio              ## engine, skid, wind and the race's cues
var marks: TmTyreMarks             ## the tyre marks a sliding wheel lays, and its smoke
var _trace: FileAccess             ## --trace: the car's state every 100 ms
var online: TmRaceOnline           ## the online side, in a server (Online)
var bot: TmBot                     ## the driving bot (--bot), else null
var input_script: TmInputScript     ## --inputs=<file>: a script drives the car, else null
var _recorded: Array = []           ## --record_inputs: [time_ms, gas, brake, steer] per tick
var track_id := ""                 ## the campaign track raced ("" for a track file)
var next_id := ""                  ## the campaign track after it ("" if none)

const GHOST_LINGER_MS := 1000      ## the ghost stays this long at its finish, then goes

## Online rounds that start everyone together (Rounds, Team, Laps): the race holds its countdown
## until the server's start; a player who joins after the start (or a spectator) waits.
var sync_start := -1.0             ## the round's start (server ms); -1: start as soon as ready
var waiting := false               ## not racing this round (late, or spectating)

var _triggers: Array = []          ## [{index, kind, xform, trig}]: waypoints with a trigger
var _prev := Vector3.ZERO          ## the car's position at the previous tick
var _cp_states := {}               ## checkpoint index -> the car as it crossed it {xform, lin, ang}
var _result := {}                  ## the finish menu's result (TmRaceMenu.show_finish); {} before
var _tail_ms := 0                  ## recorded so far after the finish (TmReplay.TAIL_MS)


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
			_message(challenge.error + "\n\nPress Escape for the menu")
		return
	TmMaterials.use_mod(TmCommunity.my_mod())   # the texture mod we wear (Community page), if any
	builder = TmMapBuilder.build(challenge)
	add_child(builder.root)
	TmStage.add_environment(self, builder)
	if not builder.has_start:
		var why := "%s has no start block" % challenge.name
		push_error("race: %s" % why)
		if TestHooks.is_testing():
			TestHooks.fail("race_map", why)
			TestHooks.finish()
		else:
			_message(why + "\n\nPress Escape for the menu")
		return
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
	gv.model = TmUi.car_model()
	gv.livery = TmUi.car_livery()
	gv.tuning = TmUi.car_tuning()
	ghost_car.add_child(gv)
	add_child(ghost_car)

	car = TmCar.new()
	add_child(car)
	car.set_physics_process(false)    # stepped by the race (_physics_process); after add_child,
	                                  # which turns it back on
	var look := TmCarVisual.new()
	look.paint_colour = TmUi.car_colour()
	look.model = TmUi.car_model()
	look.livery = TmUi.car_livery()
	look.tuning = TmUi.car_tuning()
	if TestHooks.has_arg("car_pack"):        # a community car pack (.zip) to drive (tests, screenshots)
		look.pack = TmCarPack.load_zip(String(TestHooks.arg("car_pack", "")))
	else:
		look.pack = TmCommunity.my_car_pack()  # the community car we drive (Community page), if any
	car.add_child(look)
	marks = TmTyreMarks.new()          # after the race in the tree: it reads each tick's stepped car
	marks.car = car
	add_child(marks)
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
	if TestHooks.has_arg("cam_view"):
		cam.view = int(TestHooks.arg("cam_view", 0))
	hud = TmRaceHud.new()
	hud.race = race
	hud.car = car
	hud.challenge = challenge
	hud.best = best
	add_child(hud)
	top_bar = TmTopBar.new()           # TMNF's bar: down when the mouse reaches the top edge
	add_child(top_bar)
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
	if look.pack and look.pack.ok():
		audio.use_pack(look.pack)            # its own engine
	if Online.is_online():
		menu.online = true
		menu.has_next = false
		online = TmRaceOnline.new()
		online.scene = self
		add_child(online)
	print("RACE %s: %d checkpoints, %d lap(s), %d triggers, start %s" % [challenge.name, cps, race.laps,
		_triggers.size(), "yes" if builder.has_start else "MISSING"])
	menu.opponent_chosen.connect(set_opponent)
	menu.select_opponent.connect(func() -> void: menu.show_opponents(_opponent_options(), opponent))
	menu.opponents = _offers_opponents()
	# the map's collision is in the physics space from the next physics frame
	await get_tree().physics_frame
	if _asks_opponent():
		TmMedalGhost.bot_run(self)       # the medal opponents' run, while the loading screen is up
	restart(true)
	if TestHooks.has_arg("finish_result"):
		_back_from_replay()
	ready_to_race = true
	if _asks_opponent():
		menu.show_opponents(_opponent_options(), _opponent_focus())
	elif TestHooks.has_arg("opponent"):
		set_opponent(String(TestHooks.arg("opponent", "")))
	if TestHooks.has_arg("pause"):      # screenshots: the race menu over the start
		menu.toggle_pause()


## TMNF's Select Opponent comes up when one of our tracks is loaded from the menu (not on a
## restart, online, in a test drive or back from a replay); --opponent=ask shows it in tests and
## screenshots, --opponent=<kind> picks one.
func _asks_opponent() -> bool:
	var arg := String(TestHooks.arg("opponent", ""))
	if arg != "ask" and (TestHooks.is_testing() or not arg.is_empty()):
		return false
	return _offers_opponents() and not TestHooks.has_arg("finish_result") and opponent.is_empty()


## Our own tracks with medals offer opponents (not online or in a test drive): TMNF's race menu
## lists Select Opponents for them too.
func _offers_opponents() -> bool:
	return TmTracks.has(track_id) and not online and not editing() and challenge.gold_ms > 0


## The opponents: [kind, name, time]: the medals' ghosts, your best run's, none.
func _opponent_options() -> Array:
	var out := [["gold", "Gold Medal", challenge.gold_ms], ["silver", "Silver Medal", challenge.silver_ms],
		["bronze", "Bronze Medal", challenge.bronze_ms]]
	if TmRecords.ghost(challenge) != null:
		out.append(["best", "Personal Best", int(best.get("time_ms", -1))])
	out.append(["none", "None", -1])
	return out


## The row focused first: the next medal to win (bronze when you have none), as TMNF's.
func _opponent_focus() -> String:
	var m := TmRace.medal(int(best.get("time_ms", -1)), challenge)
	match m:
		"bronze":
			return "silver"
		"silver", "gold", "author":
			return "gold"
	return "bronze"


## Races against an opponent: a medal's ghost (TmMedalGhost: our bot's run at that medal's time),
## your best run's, or none. Picked again from the race menu, the race starts over.
func set_opponent(kind: String) -> void:
	var again := not opponent.is_empty() and race != null and race.state != TmRace.State.COUNTDOWN
	opponent = kind
	match kind:
		"gold", "silver", "bronze":
			var ms: int = {"gold": challenge.gold_ms, "silver": challenge.silver_ms, "bronze": challenge.bronze_ms}[kind]
			best_ghost = TmMedalGhost.at_time(TmMedalGhost.bot_run(self), ms)
		"best":
			best_ghost = TmRecords.ghost(challenge)
		"none":
			best_ghost = null
	if again:
		restart()
	_show_ghost()


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
	if not ready_to_race or waiting or TmLoading.covering() or menu.choosing:   # the countdown waits for the track
		return
	if sync_start > 0.0 and race.state == TmRace.State.COUNTDOWN:
		# the countdown follows the server's clock: everyone starts at the round's start
		var left := sync_start - Online.now_ms()
		if left > TmRace.TICK_MS:
			race.countdown_ms = clampi(int(left), TmRace.TICK_MS, TmRace.COUNTDOWN_MS)
			return
		race.countdown_ms = TmRace.TICK_MS     # this tick starts the race
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
			# at the script's resolution (TMInterface's 1/65536), so that replaying it is exact
			car.steer = roundf(car.steer * TmInputScript.FULL) / TmInputScript.FULL
			_recorded.append([race.time_ms, car.gas, car.brake, car.steer])
	car.step_tick()
	var p := car.global_position
	if TestHooks.has_arg("trace") and race.racing() and race.time_ms % 100 == 0:
		_trace_state()
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
	elif race.state == TmRace.State.FINISHED and _tail_ms < TmReplay.TAIL_MS:
		# the car rolling on past the line, for the replay's last moments
		_tail_ms += TmRace.TICK_MS
		replay.record(race.finish_ms + _tail_ms, car)
		if _tail_ms >= TmReplay.TAIL_MS and new_record:
			replay.save(TmReplay.autosave_path(challenge))   # the record's replay, its tail too
	_prev = p


## --trace=<file>: the car every 100 ms of the race (TMNF's ghost sample period) as JSON lines,
## {t, pos, quat, vel, angvel, wheels: [[contact, surface, sliding] x4]}, to set beside a TMNF
## ghost's samples (tools/research/tmnf/ghost_dump.py, ghost_compare.py). Written as it goes.
func _trace_state() -> void:
	if _trace == null:
		_trace = FileAccess.open(String(TestHooks.arg("trace", "")), FileAccess.WRITE)
		if _trace == null:
			return
	var xf := car.global_transform
	var q := xf.basis.orthonormalized().get_rotation_quaternion()
	var wheels := []
	for i in 4:
		wheels.append([car.body.wheel_contact[i], car.body.wheel_surface[i], car.model.sliding[i]])
	_trace.store_line(JSON.stringify({"t": race.time_ms, "pos": [xf.origin.x, xf.origin.y, xf.origin.z],
		"quat": [q.x, q.y, q.z, q.w], "vel": [car.lin_vel.x, car.lin_vel.y, car.lin_vel.z],
		"angvel": [car.ang_vel.x, car.ang_vel.y, car.ang_vel.z], "wheels": wheels,
		"gas": car.gas, "brake": car.brake, "steer": car.steer}))
	_trace.flush()


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
		hud.best = best              # redraws the medal table with the new times
	hud.show_finish(time_ms, best, new_record)
	var result := {"name": challenge.name, "time_ms": time_ms, "prev_ms": int(best.get("time_ms", -1)), "record": new_record,
		"medals": {"author": challenge.author_ms, "gold": challenge.gold_ms, "silver": challenge.silver_ms, "bronze": challenge.bronze_ms},
		"validated": _validated_ms == time_ms}
	_result = result
	# the crowd cheers by medal, as TMNF's: big for gold and author, smaller for silver and bronze
	var medal := TmRace.medal(time_ms, challenge)
	if medal in ["author", "gold"]:
		audio.cue("cheer_big")
	elif medal in ["silver", "bronze"]:
		audio.cue("cheer")
	if not online and Master.logged_in() and not TestHooks.has_arg("records"):
		Master.submit_record(challenge.uid, time_ms)     # the online records (a server's finishes go through the server)
	if online:
		online.on_finish(time_ms)
	if new_record:
		best = TmRecords.best(challenge)
		if opponent in ["", "best"]:      # a medal opponent stays
			best_ghost = run if TmUi.setting("ghost") or opponent == "best" else null
		hud.best = best
	var this_run := run
	get_tree().create_timer(TmRaceHud.FINISH_FLASH).timeout.connect(func() -> void:
		if run == this_run and race.state == TmRace.State.FINISHED:
			menu.show_finish(result))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if race == null:             # the track didn't load: only the way back
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_to_menu()
		return
	match (event as InputEventKey).keycode:
		KEY_ENTER, KEY_KP_ENTER:
			respawn()
		KEY_BACKSPACE, KEY_DELETE:
			restart()
		KEY_1, KEY_2, KEY_3:            # TMNF's views: close behind, far behind, the cockpit
			cam.view = (event as InputEventKey).keycode - KEY_1
		KEY_ESCAPE:
			menu.toggle_pause()


## Where the raced track sits in its campaign (track_id, next_id): ours (TmTracks) or TMNF's.
func _campaign_place() -> void:
	if TestHooks.has_arg("map"):
		# a server's uploaded track: the round's id for it (the server's rounds compare it)
		track_id = String(TestHooks.arg("online_track", "")) if Online.is_online() else ""
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
	TestHooks.args.erase("online_track")
	pending_track = track
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


## Races a track file a server's admins uploaded (downloaded to `path`), the round's `track` id.
func load_map(path: String, track: String) -> void:
	TestHooks.args.erase("track")
	TestHooks.args["map"] = path
	TestHooks.args["online_track"] = track
	pending_track = track
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


func _next_track() -> void:
	TestHooks.args["track"] = next_id
	if get_tree().current_scene == self:
		TmLoading.change_scene(get_tree(), "res://race/race.tscn")


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
	TestHooks.args["page"] = String(TestHooks.arg("return_page", "")) if TestHooks.has_arg("return_page") \
		else ("campaign" if not track_id.is_empty() else ("editors" if map.ends_with(TmUserTracks.EXT) else "main"))
	if not track_id.is_empty():
		TestHooks.args["track"] = track_id
	get_tree().change_scene_to_file("res://ui/menu.tscn")


## Watches the last run (race/replay.tscn); Esc there comes back to this finish (_back_from_replay).
func watch_replay() -> void:
	if replay == null or replay.count() == 0 or not replay.save(TmReplay.last_path()):
		return
	TestHooks.args["replay"] = TmReplay.last_path()
	TestHooks.args["replay_back"] = "race"
	TestHooks.args.erase("replay_at")
	if not _result.is_empty():
		var r := _result.duplicate()
		r["saved"] = menu.replay_saved()
		TestHooks.args["finish_result"] = JSON.stringify(r)
	if get_tree().current_scene == self:
		TmLoading.change_scene(get_tree(), "res://race/replay.tscn")


## Back from watching the run (watch_replay): the car past the line, the finish menu as it was
## (SAVE REPLAY still there), the run kept to watch or save again.
func _back_from_replay() -> void:
	var parsed: Variant = JSON.parse_string(String(TestHooks.arg("finish_result", "")))
	TestHooks.args.erase("finish_result")
	var r := TmReplay.load_file(TmReplay.last_path())
	if not parsed is Dictionary or r == null or r.finish_ms < 0 or r.uid != challenge.uid:
		return
	replay = r
	_tail_ms = TmReplay.TAIL_MS
	race.state = TmRace.State.FINISHED
	race.countdown_ms = 0
	race.time_ms = r.finish_ms
	race.finish_ms = r.finish_ms
	race.splits.assign(r.splits)
	var xf: Transform3D = r.state(float(r.count() * TmReplay.INTERVAL_MS))["xform"]   # where it last was
	car.place(Transform3D(xf.basis, xf.origin - xf.basis.y.normalized() * car.body.rest_height()))
	car.controls_enabled = false
	car.auto_brake = true
	_prev = car.global_position
	cam.snap()
	cam.freeze()
	_result = parsed
	menu.show_finish(_result)
	if bool(_result.get("saved", false)):
		menu.mark_saved()


## Keeps the last run among the replays (Solo > Replays). Returns the file, "" if it failed.
func save_replay() -> String:
	if replay == null or replay.count() == 0:
		return ""
	var to := TmReplay.dir().path_join(replay.file_name())
	if not replay.save(to):
		return ""
	menu.mark_saved()
	return to


## A synced online round (Rounds, Team, Laps): no restarting until the server's next round.
func synced_round() -> bool:
	return online != null and Online.synced()


## Back to the start: the countdown again, the clock at zero (in a synced online round only when
## the server starts the next round: force).
func restart(force := false) -> void:
	if not force and synced_round():
		return
	menu.hide_all()
	race.restart()
	marks.clear()
	run = TmGhost.new()
	replay = TmReplay.start(challenge, track_id, String(TestHooks.arg("map", "")), race.laps, race.checkpoint_count)
	new_record = false
	_result = {}
	_tail_ms = 0
	_cp_states.clear()
	hud.reset()
	TmGateScreen.reset_all(get_tree())
	_recorded.clear()
	if input_script:
		input_script = TmInputScript.load_file(String(TestHooks.arg("inputs", "")))
	if bot:
		bot.reset()
	place_car(builder.start if builder.has_start else Transform3D())
	sync_start = -1.0
	waiting = false
	if synced_round() and String(Online.round.get("state", "")) == "race":
		var start := float(Online.round.get("start", 0))
		if Online.now_ms() > start + 300.0:
			waiting = true                 # this round started without us
		else:
			sync_start = start
	if online != null and Online.is_spectator():
		waiting = true
	car.visible = not waiting
	car.controls_enabled = not waiting


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
	if waiting:
		return
	if race.state == TmRace.State.RACING and race.respawn_index < 0 and synced_round():
		place_car(builder.start if builder.has_start else Transform3D())   # the clock runs on
		return
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
