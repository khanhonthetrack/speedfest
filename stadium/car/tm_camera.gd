class_name TmCamera
extends Camera3D
## Chase camera in the spirit of TMNF's default view: behind and above the car, following its
## heading with a short lag, looking a little ahead of the car. Works upside down (loops) by
## following the car's up axis while it touches the ground and the world's up in the air.

@export var target: TmCar
@export var distance := 6.2
@export var height := 2.0
@export var look_height := 0.9
@export var follow_rate := 8.0        ## 1/s, how fast the view direction follows the car
@export var up_rate := 4.0

var _dir := Vector3.FORWARD
var _up := Vector3.UP


func _ready() -> void:
	fov = 72.0
	near = 0.1
	far = 4000.0
	process_priority = 100
	if target:
		_dir = target.global_transform.basis.z
		_up = target.global_transform.basis.y
		_place(1.0)


func snap() -> void:
	if target:
		_dir = target.global_transform.basis.z
		_up = target.global_transform.basis.y
		_place(1.0)
		reset_physics_interpolation()


func _process(delta: float) -> void:
	if target == null:
		return
	var k := 1.0 - exp(-follow_rate * delta)
	var fwd := target.get_global_transform_interpolated().basis.z
	var vel := target.lin_vel
	# in the air, follow the flight path a little so jumps read well
	var want := fwd
	if not target.wheel_contact.has(true) and vel.length() > 5.0:
		want = (fwd + vel.normalized()).normalized()
	_dir = _dir.slerp(want, k).normalized() if _dir.dot(want) > -0.99 else want
	var up_want := target.get_global_transform_interpolated().basis.y if target.wheel_contact.has(true) else Vector3.UP
	_up = _up.slerp(up_want, 1.0 - exp(-up_rate * delta)).normalized()
	_place(k)


func _place(_k: float) -> void:
	var p := target.get_global_transform_interpolated().origin
	var eye := p - _dir * distance + _up * height
	var look := p + _up * look_height + _dir * 2.0
	global_transform = Transform3D(Basis(), eye).looking_at(look, _up)
