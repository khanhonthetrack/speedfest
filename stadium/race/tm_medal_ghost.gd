class_name TmMedalGhost
extends RefCounted
## TMNF's medal opponents (its "Select Opponent": Gold, Silver, Bronze): TMNF races you against
## ghosts recorded at each medal's pace. Ours: our bot (TmBot) drives the track once, unseen and
## faster than real time, on a car of its own in the race's world; its run, slowed to a medal's
## time, is that medal's ghost (the same line, arriving on the medal's time). Runs are kept per
## track for the session (static), so a restart or a return to the track doesn't drive again.

const MAX_S := 400.0               ## gives up on a run longer than this (s)

static var _runs := {}             ## track uid -> the bot's run (TmGhost, finished) or null


## The bot's run on the scene's track (race/race.gd: its challenge, start, triggers and laps), or
## null if the track has no line for it or it didn't finish. Must run while the physics space can
## be queried (in or after a physics frame).
static func bot_run(scene: Node) -> TmGhost:
	var ch: TmChallenge = scene.challenge
	if _runs.has(ch.uid):
		return _runs[ch.uid]
	var run: TmGhost = null
	if not ch.path.is_empty() and scene.builder.has_start:
		run = _drive(scene, ch)
	_runs[ch.uid] = run
	return run


static func _drive(scene: Node, ch: TmChallenge) -> TmGhost:
	var car := TmCar.new()
	car.visible = false
	scene.add_child(car)
	car.set_physics_process(false)
	var bot := TmBot.new()
	bot.car = car
	bot.path = ch.path
	bot.grip = float(TmTracks.spec(String(scene.track_id)).get("bot_grip", bot.grip))
	scene.add_child(bot)
	bot.set_physics_process(false)
	bot.reset()
	# on the start, as the race places the player's car (race.gd place_car)
	var xf: Transform3D = scene.builder.start.orthonormalized()
	var q := PhysicsRayQueryParameters3D.create(xf.origin + xf.basis.y * 1.5, xf.origin - xf.basis.y * 2.5, TmCar.WORLD_MASK)
	var hit := (scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var up: Vector3 = hit["normal"]
		var fwd := (xf.basis.z - up * xf.basis.z.dot(up)).normalized()
		xf = Transform3D(Basis(up.cross(fwd), up, fwd), hit["position"])
	car.place(xf)
	car.controls_enabled = true
	var race := TmRace.new(scene.race.checkpoint_count, scene.race.laps)
	race.restart()
	race.countdown_ms = TmRace.TICK_MS          # no countdown: it starts on the first tick
	var run := TmGhost.new()
	var prev := car.global_position
	var ticks := int(MAX_S * 1000.0 / TmRace.TICK_MS)
	for i in ticks:
		race.tick()
		if race.racing():
			bot._physics_process(TmRace.TICK_MS / 1000.0)
		car.step_tick()
		var p := car.global_position
		if race.racing():
			run.record(race.time_ms, car.global_transform, car.model.steer, car.local_velocity().z)
			for t: Dictionary in scene._triggers:
				if TmTriggers.crossed(t["trig"], t["xform"], prev, p) >= 0.0:
					race.cross(int(t["index"]), int(t["kind"]))
		prev = p
		if race.state == TmRace.State.FINISHED or not bot.failed.is_empty():
			break
	bot.queue_free()
	car.queue_free()
	if race.state != TmRace.State.FINISHED:
		return null
	run.finish_ms = race.finish_ms
	return run


## A run slowed (or sped up) to finish on finish_ms: the same line, every pose at its time
## stretched by finish_ms / the run's finish; its speeds scaled to match (the wheels' spin).
static func at_time(run: TmGhost, finish_ms: int) -> TmGhost:
	var out := TmGhost.new()
	if run == null or run.finish_ms <= 0 or finish_ms <= 0:
		return null
	var k := float(run.finish_ms) / finish_ms
	var t := 0
	while t <= finish_ms:
		var s := run.sample(t * k)
		out.record(t, s["xform"], float(s["steer"]), float(s["speed"]) * k)
		t += TmGhost.INTERVAL_MS
	out.finish_ms = finish_ms
	return out
