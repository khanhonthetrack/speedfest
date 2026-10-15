extends Node3D
## Physics interpolation setup (M7 PC smoothness): the project draws physics-driven bodies between
## the 60 Hz ticks, so the car doesn't judder on 120-240 Hz screens. Only the Car opts in; nodes
## moved every frame (chase camera, remote cars, ghosts, menu turntables) must stay OFF, or they'd
## be drawn a tick late.
## Run: tools/run_scene.sh res://tests/race/test_interpolation.tscn --headless


func _ready() -> void:
	await get_tree().process_frame
	TestHooks.check(bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)), "interp_project_setting_on")
	TestHooks.check(float(ProjectSettings.get_setting("physics/common/physics_jitter_fix", 0.5)) == 0.0, "interp_jitter_fix_off")
	TestHooks.check(get_tree().root.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "interp_tree_default_off")
	var car := Car.create(CarDefs.default_config("kaze"))
	add_child(car)
	TestHooks.check(car.is_physics_interpolated(), "interp_car_on")
	TestHooks.check(car.visual.is_physics_interpolated(), "interp_car_visual_inherits")
	var cam := ChaseCamera.new()
	add_child(cam)
	TestHooks.check(not cam.is_physics_interpolated(), "interp_camera_off")
	var rc := RemoteCar.new()
	add_child(rc)
	TestHooks.check(not rc.is_physics_interpolated(), "interp_remote_car_off")
	var gp := GhostPlayer.new()
	add_child(gp)
	TestHooks.check(not gp.is_physics_interpolated(), "interp_ghost_off")
	TestHooks.finish()
