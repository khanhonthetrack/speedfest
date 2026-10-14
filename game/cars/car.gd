class_name Car
extends RigidBody3D
## STUB: the car-physics module replaces this with the arcade raycast vehicle.
## API fixed by docs/ARCHITECTURE.md "Car".

var config: Dictionary = {}
var visual: CarVisual
var controls := {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "handbrake": false, "nitro": false}
var frozen_controls := false


static func create(p_config: Dictionary) -> Car:
	var car := Car.new()
	car.config = CarDefs.sanitize_config(p_config)
	var g := CarDefs.geometry(car.config["car"])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(g["width"], 0.8, g["length"])
	shape.shape = box
	car.add_child(shape)
	car.mass = 1300.0
	car.visual = CarVisual.new()
	car.add_child(car.visual)
	car.visual.build(car.config["car"], car.config["style"])
	return car


func get_speed_kmh() -> float:
	return -linear_velocity.dot(global_transform.basis.z) * 3.6


func get_rpm_ratio() -> float:
	return 0.0


func get_gear() -> int:
	return 1


func get_nitro_amount() -> float:
	return 1.0


func is_nitro_active() -> bool:
	return false


func get_drift_amount() -> float:
	return 0.0


func is_grounded() -> bool:
	return true


func get_flags() -> int:
	return 16


func get_net_state() -> Dictionary:
	var q := global_transform.basis.get_rotation_quaternion()
	var p := global_position
	var v := linear_velocity
	return {"p": [p.x, p.y, p.z], "q": [q.x, q.y, q.z, q.w], "v": [v.x, v.y, v.z],
		"st": float(controls["steer"]), "rpm": get_rpm_ratio(), "fl": get_flags()}


func teleport(xform: Transform3D, p_linear_velocity: Vector3 = Vector3.ZERO) -> void:
	global_transform = xform
	linear_velocity = p_linear_velocity
	angular_velocity = Vector3.ZERO


func refill_nitro() -> void:
	pass


func apply_boost(_direction: Vector3, _accel: float, _duration: float) -> void:
	pass
