extends Node3D
## A Stadium race on a map from the player's files, built from the recreated blocks: the car on
## the start block, the chase camera, the HUD and TmRace's rules. The race steps the car itself
## (after the race clock) and tests each tick's motion against the waypoint triggers (TmTriggers).
## Keys: arrows/WASD drive, Enter = respawn at the last checkpoint, Backspace/Delete = restart,
## Escape = pause (TmRaceMenu: resume, restart, menu); after the finish: retry, next track, menu.
## Args: --map=/path/X.Challenge.Gbx, or --tmnf=/path/to/TMNF --track=A01 (without them: the TMNF
## install in its usual place, A01); --laps=N overrides the map's lap count; TmCarInput's --auto_*
## and TestHooks' --shot/--frames for tests. The menu (ui/menu.tscn, the main scene) starts it.
## Best times and ghosts: every run is recorded (TmGhost); a finish that beats the track's record
## is saved (TmRecords) and its ghost races against you from the next attempt on.

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
var ghost_car: Node3D              ## the best ghost's car (a translucent TmCarVisual)
var new_record := false            ## the last finish set a new record
var menu: TmRaceMenu               ## pause and finish menus
var audio: TmCarAudio              ## engine, skid, wind and the race's cues
var online: TmRaceOnline           ## the online side, in a server (Online)
var track_id := ""                 ## the campaign track raced ("" for a track file)
var next_id := ""                  ## the campaign track after it ("" if none)

const GHOST_LINGER_MS := 1000      ## the ghost stays this long at its finish, then goes

var _triggers: Array = []          ## [{index, kind, xform, trig}]: waypoints with a trigger
var _prev := Vector3.ZERO          ## the car's position at the previous tick


func _ready() -> void:
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
	add_child(menu)
	_campaign_place()
	menu.has_next = not next_id.is_empty()
	menu.restarted.connect(restart)
	menu.next_track.connect(_next_track)
	menu.to_menu.connect(_to_menu)
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
	car.step_tick()
	var p := car.global_position
	if race.racing():
		run.record(race.time_ms, car.global_transform, car.model.steer, car.local_velocity().z)
		for t: Dictionary in _triggers:
			if TmTriggers.crossed(t["trig"], t["xform"], _prev, p) >= 0.0:
				race.cross(int(t["index"]), int(t["kind"]))
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
	car.controls_enabled = false
	run.record(time_ms, car.global_transform, car.model.steer, car.local_velocity().z)
	run.finish_ms = time_ms
	new_record = TmRecords.submit(challenge, time_ms, race.splits, run)
	hud.show_finish(time_ms, best, new_record)
	audio.cue("record" if new_record else "finish")
	if online:
		online.on_finish(time_ms)
	if new_record:
		best = TmRecords.best(challenge)
		best_ghost = run if TmUi.setting("ghost") else null
		hud.best = best
	var this_run := run
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if run == this_run and race.state == TmRace.State.FINISHED:
			menu.show_finish())


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


## Where the raced track sits in the campaign (track_id, next_id), when it is a campaign track.
func _campaign_place() -> void:
	if TestHooks.has_arg("map"):
		return
	track_id = String(TestHooks.arg("track", "A01"))
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


func _to_menu() -> void:
	if Online.is_online() or online:
		Online.leave()
		TestHooks.args["page"] = "online"
		get_tree().change_scene_to_file("res://ui/menu.tscn")
		return
	TestHooks.args["page"] = "campaign" if not track_id.is_empty() else "main"
	if not track_id.is_empty():
		TestHooks.args["track"] = track_id
	get_tree().change_scene_to_file("res://ui/menu.tscn")


## Back to the start: the countdown again, the clock at zero.
func restart() -> void:
	menu.hide_all()
	race.restart()
	run = TmGhost.new()
	new_record = false
	hud.reset()
	place_car(builder.start if builder.has_start else Transform3D())


## Back to the last checkpoint (the clock keeps running); before any, or after the finish, a restart.
func respawn() -> void:
	if race.state != TmRace.State.RACING or race.respawn_index < 0:
		restart()
		return
	place_car(builder.waypoints[race.respawn_index]["spawn"])
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
	_prev = car.global_position
	cam.snap()
