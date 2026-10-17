class_name TmCar
extends Node3D
## The Stadium car in the scene: a Node3D driven by TmBody (core/tm_body.gd: TMNF's integrator,
## sub-steps, ellipsoid contacts and impulses) at 100 Hz.
##
## The node's basis IS the car frame: +X left, +Y up, +Z forward (the car faces the node's +Z).
## The node's origin is the centre of mass.

signal wheel_hit_wall

const T := preload("res://core/tm_tuning.gd")
const DT := 0.01
const WORLD_MASK := 1

var body := TmBody.new()
var controls_enabled := true
var auto_brake := false             ## with the controls off: brake (after the finish, to stop on the run-off)
var tick_count := 0

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


func step_tick() -> void:
	var g := body.gas
	var br := body.brake
	var st := body.steer
	if not controls_enabled:
		body.gas = 0.0
		body.brake = 1.0 if auto_brake else 0.0
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
