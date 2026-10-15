class_name CarInput
extends Node
## Fills the parent Car's `controls` from the InputMap each physics tick (local player).
## Keyboard steering is ramped: slower and smaller at high speed, quick self-centering and
## counter-steer. Analog sticks pass through (with a light response curve).

var enabled := true
## Current smoothed steering value (-1..1).
var steer_value := 0.0

const STICK_DEADZONE := 0.12


func _physics_process(dt: float) -> void:
	var car := get_parent() as Car
	if car == null:
		return
	if not enabled:
		steer_value = 0.0
		car.controls["throttle"] = 0.0
		car.controls["brake"] = 0.0
		car.controls["steer"] = 0.0
		car.controls["handbrake"] = false
		car.controls["nitro"] = false
		return
	car.controls["throttle"] = Input.get_action_strength("accelerate")
	car.controls["brake"] = Input.get_action_strength("brake")
	var handbrake := Input.is_action_pressed("handbrake")
	car.controls["handbrake"] = handbrake
	car.controls["nitro"] = Input.is_action_pressed("nitro")
	var raw := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	if _stick_active():
		# analog: passthrough with a mild curve for precision near center
		steer_value = signf(raw) * pow(absf(raw), 1.25)
	else:
		var sf := clampf(absf(car.get_speed_kmh()) / 240.0, 0.0, 1.0)
		var limit := 1.0 if handbrake or car.get_drift_amount() > 0.3 else lerpf(1.0, 0.72, sf)
		var target := raw * limit
		var ramp := lerpf(5.5, 2.4, sf)
		var center := lerpf(8.0, 5.5, sf)
		var rate := ramp
		if absf(target) < 0.01:
			rate = center
		elif steer_value != 0.0 and signf(target) != signf(steer_value):
			rate = center + ramp
		steer_value = move_toward(steer_value, target, rate * dt)
	car.controls["steer"] = steer_value


func _stick_active() -> bool:
	for dev in Input.get_connected_joypads():
		if absf(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)) > STICK_DEADZONE:
			return true
	return false
