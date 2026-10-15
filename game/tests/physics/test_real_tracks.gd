extends Node3D
## Integration test (needs the real tracks module): the AutoDriver drives a full run on a real
## track: all checkpoints in order, then the finish. Respawns at the last checkpoint when stuck
## or below kill_y (like race does). Reports run time, respawns and min/max speed.
## Only meaningful once the tracks module is merged (the stub Track is a flat plane).
## Run: tools/run_scene.sh res://tests/physics/test_real_tracks.tscn --headless -- --track=arena --car=kaze [--runs=2]

var track: Track
var car: Car
var ai: AutoDriver
var track_id := "arena"
var car_id := "kaze"
var tick := 0
var start_tick := -1
var next_cp := 0
var cp_ticks: Array[int] = []
var respawns := 0
var finished := false
var max_kmh := 0.0
var last_cp_xf: Transform3D
var last_cp_vel := Vector3.ZERO
var cam: Camera3D
var runs := 1
var keyboard := false
var inp: CarInput
const KeyEmu := preload("res://tests/physics/key_emulator.gd")
var run_times: Array[float] = []


func _ready() -> void:
	track_id = String(TestHooks.arg("track", "arena"))
	car_id = String(TestHooks.arg("car", "kaze"))
	runs = int(TestHooks.arg("runs", 1))
	track = Track.build(track_id)
	add_child(track)
	car = Car.create(CarDefs.default_config(car_id))
	add_child(car)
	ai = AutoDriver.new()
	ai.path = track.path
	ai.reset_callable = _respawn
	car.add_child(ai)
	if bool(TestHooks.arg("keyboard", false)):
		# emulate a keyboard player: the bot's wishes become digital key presses that go through
		# CarInput's steering ramp (tests that keyboard steering can take every corner)
		keyboard = true
		var emu := Node.new()
		emu.set_script(KeyEmu)
		emu.set("car", car)
		car.add_child(emu)
		inp = CarInput.new()
		car.add_child(inp)
		emu.set("inp", inp)
	track.checkpoint_reached.connect(_on_cp)
	track.finish_reached.connect(_on_finish)
	_restart()
	print("track %s length %.0f m, %d checkpoints, kill_y %.1f, zones %s" % [track_id, track.path.length, track.checkpoint_count, track.kill_y, track.path.zones])
	if not DisplayServer.get_name() == "headless":
		cam = Camera3D.new()
		cam.far = 3000
		add_child(cam)


func _restart() -> void:
	last_cp_xf = track.get_start_transform()
	last_cp_vel = Vector3.ZERO
	car.teleport(last_cp_xf)
	car.refill_nitro()
	ai.reset_tracking()
	car.frozen_controls = true
	next_cp = 0
	cp_ticks.clear()
	start_tick = tick + 60


func _respawn() -> void:
	respawns += 1
	print("  respawn #%d at cp %d (pos %s)" % [respawns, next_cp - 1, car.global_position])
	car.teleport(last_cp_xf, last_cp_vel)
	ai.reset_tracking()


func _on_cp(body: Node, index: int) -> void:
	if body != car or index != next_cp:
		return
	next_cp += 1
	cp_ticks.append(tick - start_tick)
	last_cp_xf = track.get_checkpoint_transform(index)
	last_cp_vel = car.linear_velocity
	print("  cp %d at %.2fs %.0f km/h" % [index, (tick - start_tick) / 60.0, car.get_speed_kmh()])


func _on_finish(body: Node) -> void:
	if body != car or next_cp < track.checkpoint_count or start_tick < 0 or tick < start_tick:
		return
	var t := (tick - start_tick) / 60.0
	run_times.append(t)
	print("RESULT real%s %s %s run %d: %.2fs respawns=%d max=%.0f km/h" % ["_kb" if keyboard else "", track_id, car_id, run_times.size(), t, respawns, max_kmh])
	if run_times.size() >= runs:
		finished = true
		TestHooks.check(respawns == 0, "real_%s_%s_no_respawn" % [track_id, car_id], "%d respawns" % respawns)
		TestHooks.ok("real_%s_%s_finished" % [track_id, car_id])
		TestHooks.finish()
	else:
		_restart()


func _physics_process(_delta: float) -> void:
	tick += 1
	if tick == start_tick:
		car.frozen_controls = false
	max_kmh = maxf(max_kmh, car.get_speed_kmh())
	if car.global_position.y < track.kill_y:
		_respawn()
	if TestHooks.has_arg("trace") and tick % 30 == 0:
		print("  t=%.1f d=%.0f v=%.0f pos=%s gnd=%s st=%.2f" % [(tick - start_tick) / 60.0, ai.get_distance(), car.get_speed_kmh(), car.global_position.snapped(Vector3.ONE * 0.1), car.is_grounded(), car.controls["steer"]])
	if tick > 60 * 200 and not finished:
		TestHooks.fail("real_%s_%s_finished" % [track_id, car_id], "next cp %d/%d, respawns %d, d=%.0f" % [next_cp, track.checkpoint_count, respawns, ai.get_distance()])
		TestHooks.finish()


func _process(_delta: float) -> void:
	if cam:
		var b := car.global_transform.basis
		cam.global_position = car.global_position + b.z * 8.0 + b.y * 3.0
		cam.look_at(car.global_position + b.y * 1.0, b.y)
