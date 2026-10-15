class_name CarInput
extends Node
## Fills the parent Car's `controls` from the InputMap each physics tick (local player).
## Keyboard steering (M7, Trackmania feel): one quick ramp, ~0.08 s to full lock and faster back to
## centre; no extra limit at speed, the car itself keeps full lock inside the grip
## (Car.max_steer_at). Analog sticks pass through (with a light response curve).

var enabled := true
## Current smoothed steering value (-1..1).
var steer_value := 0.0

const STICK_DEADZONE := 0.12
const KEY_RAMP := 12.0      # steering units per second toward full lock (~0.08 s)
const KEY_CENTER := 16.0    # back to centre when released


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
		var target := raw
		var rate := KEY_RAMP
		if absf(target) < 0.01:
			rate = KEY_CENTER
		elif steer_value != 0.0 and signf(target) != signf(steer_value):
			rate = KEY_CENTER + KEY_RAMP
		steer_value = move_toward(steer_value, target, rate * dt)
	car.controls["steer"] = steer_value


func _stick_active() -> bool:
	for dev in Input.get_connected_joypads():
		if absf(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)) > STICK_DEADZONE:
			return true
	return false
