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
@export var base_fov := 72.0
@export var fast_fov := 84.0          ## at FAST_KMH and over: a wider view for the sense of speed
const FAST_KMH := 350.0

var _dir := Vector3.FORWARD
var _up := Vector3.UP
var frozen := false                   ## after the finish: stays where it is and watches the car


func _ready() -> void:
	# placed every rendered frame from the car's interpolated transform: Godot's physics
	# interpolation on top of that made it trail the car by up to a tick and shake against it,
	# which TAA then smeared (the car looked blurry while driving)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = base_fov
	near = 0.1
	far = 4000.0
	process_priority = 100
	if target:
		_dir = target.global_transform.basis.z
		_up = target.global_transform.basis.y
		_place(1.0)


## Stops following: a cut to a trackside spot (up, back and beside the road, clear of the
## finish arch the chase camera is under at that moment), which then turns to watch the car.
func freeze() -> void:
	frozen = true
	var b := global_basis
	var flat := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	var side := Vector3(b.x.x, 0.0, b.x.z).normalized()
	global_position += Vector3.UP * 6.0 - flat * 14.0 + side * 9.0
	reset_physics_interpolation()


func snap() -> void:
	frozen = false
	if target:
		_dir = target.global_transform.basis.z
		_up = target.global_transform.basis.y
		_place(1.0)
		reset_physics_interpolation()


func _process(delta: float) -> void:
	if target == null:
		return
	if frozen:
		var at := target.get_global_transform_interpolated().origin + Vector3.UP * look_height
		if global_position.distance_to(at) > 1.0:
			var want := global_transform.looking_at(at, Vector3.UP)
			global_transform = Transform3D(global_basis.slerp(want.basis, 1.0 - exp(-6.0 * delta)), global_position)
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
	var fast := clampf((absf(target.speed_kmh()) - 120.0) / (FAST_KMH - 120.0), 0.0, 1.0)
	fov = lerpf(fov, lerpf(base_fov, fast_fov, fast), 1.0 - exp(-2.5 * delta))
	_place(k)


func _place(_k: float) -> void:
	var p := target.get_global_transform_interpolated().origin
	var eye := p - _dir * distance + _up * height
	var look := p + _up * look_height + _dir * 2.0
	global_transform = Transform3D(Basis(), eye).looking_at(look, _up)
