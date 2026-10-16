extends Node3D
## A Stadium race on a map from the player's files, built from the recreated blocks: the car on
## the start block, the chase camera, the HUD and TmRace's rules. The race steps the car itself
## (after the race clock) and tests each tick's motion against the waypoint triggers (TmTriggers).
## Keys: arrows/WASD drive, Enter = respawn at the last checkpoint, Backspace/Delete = restart.
## Args: --map=/path/X.Challenge.Gbx, or --tmnf=/path/to/TMNF --track=A01; --laps=N overrides the
## map's lap count; TmCarInput's --auto_* and TestHooks' --shot/--frames for tests.

var challenge: TmChallenge
var builder: TmMapBuilder
var race: TmRace
var car: TmCar
var input: TmCarInput
var cam: TmCamera
var hud: TmRaceHud
var ready_to_race := false

var _triggers: Array = []          ## [{index, kind, xform, trig}]: waypoints with a trigger
var _prev := Vector3.ZERO          ## the car's position at the previous tick


func _ready() -> void:
	challenge = TmStage.load_from_args()
	if not challenge.ok():
		push_error("race: %s" % challenge.error)
		TestHooks.fail("race_map", challenge.error)
		TestHooks.finish()
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
	race.finished.connect(func(_ms: int) -> void: car.controls_enabled = false)

	car = TmCar.new()
	add_child(car)
	car.set_physics_process(false)    # stepped by the race (_physics_process); after add_child,
	                                  # which turns it back on
	car.add_child(TmCarVisual.new())
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
	add_child(hud)
	print("RACE %s: %d checkpoints, %d lap(s), %d triggers, start %s" % [challenge.name, cps, race.laps,
		_triggers.size(), "yes" if builder.has_start else "MISSING"])
	# the map's collision is in the physics space from the next physics frame
	await get_tree().physics_frame
	restart()
	ready_to_race = true


func _physics_process(_delta: float) -> void:
	if not ready_to_race:
		return
	race.tick()
	if race.state == TmRace.State.COUNTDOWN:
		return
	car.step_tick()
	var p := car.global_position
	if race.racing():
		for t: Dictionary in _triggers:
			if TmTriggers.crossed(t["trig"], t["xform"], _prev, p) >= 0.0:
				race.cross(int(t["index"]), int(t["kind"]))
	_prev = p


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_ENTER, KEY_KP_ENTER:
			respawn()
		KEY_BACKSPACE, KEY_DELETE:
			restart()


## Back to the start: the countdown again, the clock at zero.
func restart() -> void:
	race.restart()
	hud.reset()
	place_car(builder.start if builder.has_start else Transform3D())


## Back to the last checkpoint (the clock keeps running); before any, or after the finish, a restart.
func respawn() -> void:
	if race.state != TmRace.State.RACING or race.respawn_index < 0:
		restart()
		return
	place_car(builder.waypoints[race.respawn_index]["spawn"])


## The car standing still at a spawn point: on the ground when it lies just below (spawns sit up
## to 2.1 m above the road), else in the air there (a ring checkpoint over a jump).
func place_car(spawn: Transform3D) -> void:
	var xf := spawn.orthonormalized()
	var q := PhysicsRayQueryParameters3D.create(xf.origin + xf.basis.y * 1.5, xf.origin - xf.basis.y * 2.5, TmCar.WORLD_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var up: Vector3 = hit["normal"]
		var fwd := (xf.basis.z - up * xf.basis.z.dot(up)).normalized()
		xf = Transform3D(Basis(up.cross(fwd), up, fwd), hit["position"])
	car.place(xf)
	car.controls_enabled = true
	_prev = car.global_position
	cam.snap()
