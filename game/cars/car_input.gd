class_name CarInput
extends Node
## Fills the parent Car's `controls` from the InputMap each physics tick (local player).
## The car-physics module may refine smoothing (keyboard steering ramp etc.).

var enabled := true


func _physics_process(_delta: float) -> void:
	var car := get_parent() as Car
	if car == null:
		return
	if not enabled:
		car.controls["throttle"] = 0.0
		car.controls["brake"] = 0.0
		car.controls["steer"] = 0.0
		car.controls["handbrake"] = false
		car.controls["nitro"] = false
		return
	car.controls["throttle"] = Input.get_action_strength("accelerate")
	car.controls["brake"] = Input.get_action_strength("brake")
	car.controls["steer"] = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	car.controls["handbrake"] = Input.is_action_pressed("handbrake")
	car.controls["nitro"] = Input.is_action_pressed("nitro")
