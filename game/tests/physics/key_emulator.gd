extends Node
## Test helper: turns the AutoDriver's analog wishes (already written to car.controls) into
## digital key presses, like a keyboard player tapping keys. CarInput (a later sibling) then
## reads the InputMap and overwrites car.controls through its steering ramp.

var car: Car
var inp: CarInput


func _physics_process(_delta: float) -> void:
	if car == null or inp == null:
		return
	var want := float(car.controls["steer"])
	var cur := inp.steer_value
	var right := false
	var left := false
	# tap toward the wanted value (a player correcting by feel)
	if want - cur > 0.12:
		right = true
	elif cur - want > 0.12:
		left = true
	elif absf(want) > 0.5:
		right = want > 0.0
		left = want < 0.0
	_key("steer_right", right)
	_key("steer_left", left)
	_key("accelerate", float(car.controls["throttle"]) > 0.4)
	_key("brake", float(car.controls["brake"]) > 0.2)
	_key("nitro", bool(car.controls["nitro"]))
	_key("handbrake", bool(car.controls["handbrake"]))


func _key(action: String, on: bool) -> void:
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)
