extends Node3D
## Physics interpolation setup (M7 PC smoothness): the project draws physics-driven bodies between
## the 60 Hz ticks, so the car doesn't judder on 120-240 Hz screens. Only the Car opts in; nodes
## moved every frame (chase camera, remote cars, ghosts, menu turntables) must stay OFF, or they'd
## be drawn a tick late.
## Drive checks: physics runs at 30 Hz against the forced 60 fps, so every other frame is drawn half a
## tick after the last one. The drawn car must sit at lerp(previous tick, last tick, 1 - lag), a ghost
## of the same run sampled at (tick - lag) must sit on it, and the wheels must turn every frame.
## Run: tools/run_scene.sh res://tests/race/test_interpolation.tscn --headless

const TICKS := 30
const DRIVE_TICKS := 90

var _car: Car
var _k := 0
var _rec := {}                       # tick -> car position seen in _physics_process (= what ghosts record)
var _frames: Array = []              # [tick, lag, drawn position, drawn wheel spin]
var _recorder := GhostRecorder.new()
var _driving := false
var _spray: WaterSpray
var _spray_worst := 0.0              # world-space emitters must sit on the drawn car (InterpAnchor)


func _ready() -> void:
	process_priority = 100           # after the car's _process, which poses the wheels
	process_physics_priority = 100
	await get_tree().process_frame
	TestHooks.check(bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)), "interp_project_setting_on")
	TestHooks.check(float(ProjectSettings.get_setting("physics/common/physics_jitter_fix", 0.5)) == 0.0, "interp_jitter_fix_off")
	TestHooks.check(get_tree().root.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "interp_tree_default_off")
	var car := Car.create(CarDefs.default_config("kaze"))
	add_child(car)
	TestHooks.check(car.is_physics_interpolated(), "interp_car_on")
	TestHooks.check(car.visual.is_physics_interpolated(), "interp_car_visual_inherits")
	var wheels := car.visual.find_child("Wheels", false, false) as MultiMeshInstance3D
	TestHooks.check(wheels != null and not wheels.is_physics_interpolated(), "interp_wheel_multimesh_off",
		"an interpolated MultiMeshInstance3D lerps its instance matrices again (shrinking spinning wheels)")
	car.queue_free()
	var cam := ChaseCamera.new()
	add_child(cam)
	TestHooks.check(not cam.is_physics_interpolated(), "interp_camera_off")
	var rc := RemoteCar.new()
	add_child(rc)
	TestHooks.check(not rc.is_physics_interpolated(), "interp_remote_car_off")
	var gp := GhostPlayer.new()
	add_child(gp)
	TestHooks.check(not gp.is_physics_interpolated(), "interp_ghost_off")
	_start_drive()


func _start_drive() -> void:
	Engine.physics_ticks_per_second = TICKS
	add_child(PhysicsTestGround.flat_pad(60.0, 1200.0, Vector3(0, 0, -560)))
	_car = Car.create(PhysicsTestGround.test_config("kaze"))
	add_child(_car)
	_car.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)), Vector3(0, 0, -20))
	_car.controls["throttle"] = 1.0
	_spray = WaterSpray.create("kaze", true)
	_car.add_child(_spray)
	_recorder.start()
	_driving = true


func _tick_ms() -> float:
	return 1000.0 / TICKS


func _physics_process(_delta: float) -> void:
	if not _driving:
		return
	_k += 1
	_rec[_k] = _car.global_position
	_recorder.tick(int(round(_k * _tick_ms())), _car)


func _process(_delta: float) -> void:
	if not _driving or _k < 10:      # dropped onto the pad: wheels turn once they touch down
		return
	var drawn := _car.get_global_transform_interpolated().origin
	_frames.append([_k, _car.display_tick_lag(), drawn, float(_car._vis_spin_arr[0])])
	_spray_worst = maxf(_spray_worst, _spray.global_position.distance_to(drawn))
	if _k >= DRIVE_TICKS:
		_driving = false
		_check_drive()


func _check_drive() -> void:
	var ghost := _recorder.finish(int(round(_k * _tick_ms())), _car, [], "test", CarDefs.default_config("kaze"))
	var gp := GhostPlayer.new()
	add_child(gp)
	TestHooks.check(gp.load_ghost(ghost), "interp_ghost_loads")
	var worst_body := 0.0
	var worst_ghost := 0.0
	var worst_naive := 0.0
	var subtick := 0
	var still_wheels := 0
	for j in _frames.size():
		var k: int = _frames[j][0]
		var lag: float = _frames[j][1]
		var drawn: Vector3 = _frames[j][2]
		if absf(lag - 0.5) < 0.01:
			subtick += 1
		var want: Vector3 = (_rec[k - 1] as Vector3).lerp(_rec[k], 1.0 - lag)
		worst_body = maxf(worst_body, drawn.distance_to(want))
		worst_ghost = maxf(worst_ghost, gp.sample((k - lag) * _tick_ms()).origin.distance_to(drawn))
		worst_naive = maxf(worst_naive, gp.sample(k * _tick_ms()).origin.distance_to(drawn))
		if j > 0 and is_equal_approx(float(_frames[j][3]), float(_frames[j - 1][3])):
			still_wheels += 1
	TestHooks.check(subtick > _frames.size() / 3, "interp_has_subtick_frames", "%d of %d frames between ticks" % [subtick, _frames.size()])
	TestHooks.check(worst_body < 0.002, "interp_car_drawn_between_ticks", "worst %.4f m off lerp(prev, last, 1 - lag)" % worst_body)
	TestHooks.check(worst_ghost < 0.08 and worst_naive > 0.3, "interp_ghost_on_the_car",
		"ghost of the same run is %.3f m off the drawn car (%.2f m when sampled at the last tick)" % [worst_ghost, worst_naive])
	TestHooks.check(still_wheels == 0, "interp_wheels_turn_every_frame", "%d frames with the wheels standing still" % still_wheels)
	TestHooks.check(_spray.top_level and not _spray.is_physics_interpolated() and _spray_worst < 0.001, "interp_spray_follows_drawn_car",
		"world-space spray %.3f m off the drawn car" % _spray_worst)
	TestHooks.finish()
