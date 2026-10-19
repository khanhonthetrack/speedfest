class_name CarRig
extends Node3D
## Puts a procedural car model (cars/visual/car_visual.gd) on a TmCar and keeps it in step with the
## physics: wheel steering, spin and suspension travel, brake and reverse lamps, nitrous flames,
## headlights and underglow.
##
## The model is authored in MODEL space (facing -Z, left -X, ground at y = 0, Godot's own
## convention), the physics in the TMNF car frame (+Z forward, +X left, origin at the centre of
## mass). The rig bridges both: a flip node rotated by PI around Y, lifted so the wheels touch
## the ground.

const T := preload("res://core/tm_tuning.gd")

var car: TmCar
var visual: CarVisual
## The local car gets real headlight spots and an underglow light; ghosts and rivals do not.
var is_local := true

var _flip: Node3D
var _spin: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _wheel_radius := 0.33


func _init(p_car: TmCar = null, p_local: bool = true) -> void:
	car = p_car
	is_local = p_local


func _ready() -> void:
	process_priority = 50
	_flip = Node3D.new()
	_flip.name = "ModelSpace"
	_flip.rotation = Vector3(0.0, PI, 0.0)
	add_child(_flip)
	visual = CarVisual.new()
	visual.name = "CarVisual"
	visual.underglow_light_allowed = is_local
	_flip.add_child(visual)
	rebuild()


## Rebuild the model from the car's garage setup (after a tuning change).
func rebuild() -> void:
	if car == null or visual == null:
		return
	var id := car.car_id if CarDefs.has(car.car_id) else "kaze"
	_wheel_radius = float(CarDefs.geometry(id)["wheel_radius"])
	visual.build(id, CarDefs.style_from_setup(id, car.setup))
	# CarVisual's origin is the wheel-centre height; TmCar's is the centre of mass, which sits
	# `rest_height` above the road, so the model hangs that far below the physics origin.
	_flip.position = Vector3(0.0, _wheel_radius - car.body.rest_height(), 0.0)
	if is_local:
		visual.set_headlights_real(true)


func _process(delta: float) -> void:
	if car == null or visual == null:
		return
	var m := car.model
	var v := car.local_velocity()
	var susp: Array[float] = []
	var contacts := 0
	for i in 4:
		_spin[i] += v.z / maxf(_wheel_radius, 0.05) * delta
		susp.append(T.SUSP_STATIC - m.susp_len[i])
		if car.wheel_contact[i]:
			contacts += 1
	# the model's steering is the input; the visible angle is TMNF's speed-dependent lock
	var lock := deg_to_rad(T.lin([[0.0, 32.0], [120.0, 9.0]], absf(v.z) * 3.6))
	visual.set_wheel_state(lock * m.steer, _spin, susp)
	visual.set_lights(m.brake_now > 0.5 and v.z > 0.5, m.reverse and v.z < -0.2)
	visual.set_ground_contact(float(contacts) / 4.0)
	visual.set_nitro(car.boosting)
