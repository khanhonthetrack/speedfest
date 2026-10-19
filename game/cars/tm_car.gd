class_name TmCar
extends Node3D
## The car in the scene: a Node3D driven by TmBody (core/tm_body.gd: TMNF's integrator, sub-steps,
## ellipsoid contacts and impulses) at 100 Hz.
##
## The node's basis IS the car frame: +X left, +Y up, +Z forward (the car faces the node's +Z).
## The node's origin is the centre of mass.
##
## `configure(car_id, setup)` turns a garage entry (cars/car_defs.gd + cars/tuning.gd) into the
## collision geometry and the force-model multipliers, and sets up the nitrous: a meter that drains
## while `boost_input` is held and refills as you drive (`boost_gain`), pushing the car forward with
## `boost_power` and lifting its top speed by `boost_kmh`.

signal wheel_hit_wall
signal boost_started
signal boost_ended

const T := preload("res://core/tm_tuning.gd")
const DT := 0.01
const WORLD_MASK := 1

var body := TmBody.new()
var controls_enabled := true
var tick_count := 0

## Garage identity. Set through configure(); "stadium" is the bare TMNF car the physics lab uses.
var car_id := "stadium"
var setup: Dictionary = {}
var specs: Dictionary = {}

# --- nitrous ---
var boost_input := false
var boost_meter := 1.0            ## 0..1 of the tank
var boost_power := 0.0            ## m/s^2 while boosting
var boost_tank := 0.0             ## seconds of boost at full
var boost_gain := 0.0             ## tank fraction refilled per second of driving
var boost_kmh := 0.0              ## how much the top speed cap lifts while boosting
var boosting := false

var model: TmCarModel:
	get: return body.model
var lin_vel: Vector3:
	get: return body.lin_vel
	set(v): body.lin_vel = v
var ang_vel: Vector3:
	get: return body.ang_vel
	set(v): body.ang_vel = v
var gas: float:
	get: return body.gas
	set(v): body.gas = v
var brake: float:
	get: return body.brake
	set(v): body.brake = v
var steer: float:
	get: return body.steer
	set(v): body.steer = v
var now_ms: int:
	get: return body.now_ms
var substeps: int:
	get: return body.substeps
var body_contact: bool:
	get: return body.body_contact
var wheel_contact: Array[bool]:
	get: return body.wheel_contact



func _ready() -> void:
	body.collision_mask = WORLD_MASK
	body.xform = transform


## Build this car from the garage: collision geometry, force-model multipliers, nitrous.
func configure(p_car_id: String, p_setup: Dictionary = {}) -> void:
	car_id = p_car_id
	setup = p_setup if not p_setup.is_empty() else Tuning.default_setup(p_car_id)
	specs = Tuning.resolve(car_id, setup)
	var g := CarDefs.geometry(car_id)
	var ride := float(specs.get("ride", 0.0))
	body.setup(CarDefs.wheel_positions(car_id, ride), float(g["wheel_radius"]),
		float(g["wheel_width"]) * 0.5, CarDefs.body_ellipsoids(car_id), Vector3.ONE)
	var m := body.model
	m.accel_mul = float(specs["accel"])
	m.launch_mul = float(specs["launch"])
	m.steer_mul = float(specs["steer"])
	m.grip_mul = float(specs["grip"])
	m.brake_mul = float(specs["brake"])
	m.slide_grip = float(specs["slide_grip"])
	m.max_speed = float(specs["top_kmh"]) / 3.6
	m.surface_override = Tuning.surface_overrides(car_id, setup)
	boost_power = float(specs.get("boost_power", 0.0))
	boost_tank = float(specs.get("boost_tank", 0.0))
	boost_gain = float(specs.get("boost_gain", 0.0))
	boost_kmh = float(specs.get("boost_kmh", 0.0))
	boost_meter = 1.0 if boost_tank > 0.0 else 0.0
	body.reset()


## Top speed in km/h, boost included while it is lit.
func top_speed_kmh() -> float:
	return float(specs.get("top_kmh", T.MAX_SPEED * 3.6)) + (boost_kmh if boosting else 0.0)


## Put the car at rest on the ground at `xf` (origin = where the wheels touch the ground).
func place(xf: Transform3D) -> void:
	transform = Transform3D(xf.basis.orthonormalized(), xf.origin + xf.basis.y.normalized() * body.rest_height())
	body.xform = transform
	body.reset()
	reset_physics_interpolation()


func speed_kmh() -> float:
	return body.lin_vel.dot(global_transform.basis.z) * 3.6


func local_velocity() -> Vector3:
	return body.local_velocity()


func _physics_process(_delta: float) -> void:
	step_tick()


func _step_boost(dt: float) -> void:
	var want := boost_input and controls_enabled and boost_tank > 0.0 and boost_meter > 0.0
	if want != boosting:
		boosting = want
		if want:
			boost_started.emit()
		else:
			boost_ended.emit()
	if boosting:
		boost_meter = maxf(0.0, boost_meter - dt / maxf(boost_tank, 0.001))
		body.extra_accel = global_transform.basis.z * boost_power
		body.model.max_speed = (float(specs["top_kmh"]) + boost_kmh) / 3.6
	else:
		body.extra_accel = Vector3.ZERO
		if boost_tank > 0.0:
			# the tank refills while the car is moving, faster the harder you are driving
			var v := absf(speed_kmh())
			var drive := clampf(v / 120.0, 0.25, 1.4)
			boost_meter = minf(1.0, boost_meter + boost_gain * drive * dt)
		if not specs.is_empty():
			body.model.max_speed = float(specs["top_kmh"]) / 3.6


func step_tick() -> void:
	_step_boost(DT)
	var g := body.gas
	var br := body.brake
	var st := body.steer
	if not controls_enabled:
		body.gas = 0.0
		body.brake = 0.0
		body.steer = 0.0
	body.xform = transform
	body.step(get_world_3d().direct_space_state, DT)
	transform = body.xform
	if not controls_enabled:
		body.gas = g
		body.brake = br
		body.steer = st
	if body.wall_touch:
		wheel_hit_wall.emit()
	tick_count += 1
