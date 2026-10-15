class_name ChaseCamera
extends Camera3D
## Race camera that follows a Car (or any Node3D with linear_velocity).
##
## Modes (Settings.camera_mode): 0 chase-near, 1 chase-far, 2 bumper, 3 hood.
## - The follow frame is a quaternion that slerps toward the car's orientation, so the up vector
##   follows the car smoothly through loops and banking (no flip at the top of a loop).
## - The camera offset lags in that frame (rotational lag) plus a small velocity-change lag, so
##   the distance doesn't grow with speed the way a plain world-space spring would.
## - FOV widens with speed, with a kick while nitro is active. Shake at very high speed and on
##   hard landings. A collision ray keeps the camera out of walls (layer 1).
## Call snap() after teleports (respawn, restart).

const MODE_NAMES: Array[String] = ["CHASE NEAR", "CHASE FAR", "BUMPER", "HOOD"]
const MODE_COUNT := 4

## Chase presets: [distance behind, height, look-ahead, look height, base fov]
const CHASE_PRESETS := [
	[5.9, 2.15, 7.0, 1.05, 68.0],
	[8.6, 2.9, 8.0, 1.15, 66.0],
]

var target: Node3D
var mode: int = 0
var look_back := false

## Tuning knobs.
var rot_follow := 7.0           # 1/s: how fast the frame turns toward the car's heading
var up_follow := 4.0            # 1/s: how fast the up vector follows (loops/banking)
var air_follow_scale := 0.35    # follow rates are scaled by this while airborne (no camera spin)
var accel_lag := 0.035          # s: positional lag on velocity changes (pull back on boost)
var speed_pullback := 0.012     # m per km/h of extra distance at speed
var fov_speed_gain := 20.0      # extra fov degrees at 300 km/h
var nitro_fov_kick := 7.0
var shake_speed_kmh := 240.0    # shake starts above this speed
var shake_amount := 0.035
var auto_landing_shake := true  # detect landings from is_grounded(); off when the race feeds add_shake()
var collision_mask := 1

var _frame := Quaternion.IDENTITY   # smoothed follow orientation
var _vel_smooth := Vector3.ZERO
var _fov := 70.0
var _nitro_kick := 0.0
var _shake := 0.0                    # landing impulse 0..1, decays
var _was_grounded := true
var _air_time := 0.0
var _noise_t := 0.0
var _col_dist := -1.0                # smoothed collision-limited distance (-1 = free)
var _intro_total := 0.0
var _intro_left := 0.0
var _snap_frames := 2               # frames left to snap (teleports may apply a tick later)


func _ready() -> void:
	mode = clampi(Settings.camera_mode, 0, MODE_COUNT - 1)
	near = 0.05
	far = 4000.0
	current = true


func set_target(node: Node3D) -> void:
	target = node
	snap()


## Instantly place the camera behind the target (after teleports).
func snap() -> void:
	_snap_frames = 2


## Orbit around the car for `seconds`, ending exactly in the chase pose (first countdown).
func start_intro(seconds: float) -> void:
	_intro_total = maxf(seconds, 0.01)
	_intro_left = _intro_total


func stop_intro() -> void:
	_intro_left = 0.0


## Extra shake impulse 0..1 (landings, wall hits). Decays over ~0.4 s.
func add_shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.0)


func cycle_mode() -> int:
	set_mode((mode + 1) % MODE_COUNT)
	Settings.camera_mode = mode
	Settings.save()
	return mode


func set_mode(m: int) -> void:
	mode = clampi(m, 0, MODE_COUNT - 1)
	_col_dist = -1.0
	snap()


func mode_name() -> String:
	return MODE_NAMES[mode]


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	update_camera(delta)


func _target_velocity() -> Vector3:
	if target is RigidBody3D:
		return (target as RigidBody3D).linear_velocity
	return Vector3.ZERO


func _target_bool(method: String, default: bool) -> bool:
	if target.has_method(method):
		return bool(target.call(method))
	return default


func update_camera(delta: float) -> void:
	delta = minf(delta, 0.1)
	var xf := target.get_global_transform_interpolated()
	var car_q := xf.basis.get_rotation_quaternion()
	var vel := _target_velocity()
	var speed_kmh := vel.length() * 3.6
	var grounded := _target_bool("is_grounded", true)
	var nitro := _target_bool("is_nitro_active", false)

	if _snap_frames > 0:
		_snap_frames -= 1
		_frame = car_q
		_vel_smooth = vel
		_col_dist = -1.0
		_shake = 0.0
		_air_time = 0.0
		_was_grounded = grounded

	# Landing shake: impulse scaled by airtime.
	if grounded:
		if not _was_grounded and _air_time > 0.35 and auto_landing_shake:
			_shake = maxf(_shake, clampf(_air_time * 0.6, 0.2, 1.0))
		_air_time = 0.0
	else:
		_air_time += delta
	_was_grounded = grounded
	_shake = maxf(0.0, _shake - delta * 2.5)

	var first_person := mode >= 2
	# Smoothed follow frame. Heading and up follow at different rates: split into yaw (around the
	# current up) and the remaining tilt by slerping with two factors and recombining.
	var air_k := 1.0 if grounded else air_follow_scale
	if first_person:
		_frame = _frame.slerp(car_q, 1.0 - exp(-delta * 25.0)).normalized()
	else:
		var k_rot := 1.0 - exp(-delta * rot_follow * air_k)
		var k_up := 1.0 - exp(-delta * up_follow * air_k)
		var fwd_target := car_q * Vector3.FORWARD
		var up_target := car_q * Vector3.UP
		var cur_fwd := _frame * Vector3.FORWARD
		var cur_up := _frame * Vector3.UP
		var new_up := _slerp_dir(cur_up, up_target, k_up)
		var new_fwd := _slerp_dir(cur_fwd, fwd_target, k_rot)
		# Orthonormalize (forward wins: heading matters most for a chase cam).
		var right := new_fwd.cross(new_up)
		if right.length_squared() < 1e-6:
			right = _frame * Vector3.RIGHT
		right = right.normalized()
		new_up = right.cross(new_fwd).normalized()
		_frame = Basis(right, new_up, -new_fwd).get_rotation_quaternion().normalized()
	_vel_smooth = _vel_smooth.lerp(vel, 1.0 - exp(-delta / maxf(accel_lag, 0.001)))

	var frame_basis := Basis(_frame)
	var cam_pos: Vector3
	var look_at_pos: Vector3
	var up_vec := frame_basis.y
	var base_fov := 70.0
	var g := _geometry()
	if first_person:
		var car_basis := xf.basis
		var dir := -1.0 if look_back else 1.0
		if mode == 2: # bumper
			cam_pos = xf.origin + car_basis * Vector3(0, -float(g["wheel_radius"]) + 0.55, -float(g["length"]) * 0.5 * dir)
		else: # hood
			cam_pos = xf.origin + car_basis * Vector3(0, float(g["height"]) - float(g["wheel_radius"]) + 0.05, -float(g["length"]) * 0.12)
		look_at_pos = cam_pos + frame_basis * Vector3(0, -0.02, -10.0 * dir)
		base_fov = 74.0
	else:
		var preset: Array = CHASE_PRESETS[mode]
		var dist: float = preset[0] + speed_pullback * clampf(speed_kmh, 0.0, 350.0)
		var height: float = preset[1]
		var ahead: float = preset[2]
		var look_h: float = preset[3]
		base_fov = preset[4]
		var dir := -1.0 if look_back else 1.0
		var pivot := xf.origin + frame_basis.y * look_h
		var offset := frame_basis * Vector3(0, height - look_h, dist * dir)
		# Velocity-change lag: when the car accelerates the camera falls back a little.
		offset -= (vel - _vel_smooth) * accel_lag * 2.0
		offset = _collide(pivot, offset)
		cam_pos = pivot + offset
		look_at_pos = xf.origin + frame_basis * Vector3(0, look_h, -ahead * dir)

	# FOV: widen with speed, nitro kick.
	_nitro_kick = lerpf(_nitro_kick, nitro_fov_kick if nitro else 0.0, 1.0 - exp(-delta * (6.0 if nitro else 2.5)))
	var want_fov := base_fov + fov_speed_gain * clampf(speed_kmh / 300.0, 0.0, 1.2) + _nitro_kick
	_fov = lerpf(_fov, want_fov, 1.0 - exp(-delta * 4.0))
	fov = _fov

	# Shake: smooth pseudo-noise, stronger at very high speed and on landings.
	_noise_t += delta
	var shake := _shake * 0.12
	if speed_kmh > shake_speed_kmh:
		shake += shake_amount * clampf((speed_kmh - shake_speed_kmh) / 120.0, 0.0, 1.0)
	if first_person:
		shake *= 0.4
	if shake > 0.0001:
		var n := Vector3(
			sin(_noise_t * 37.0) + sin(_noise_t * 23.3 + 1.7) * 0.6,
			sin(_noise_t * 41.0 + 0.6) + sin(_noise_t * 29.1 + 2.3) * 0.6,
			0.0) * 0.5
		cam_pos += frame_basis * (n * shake)

	if _intro_left > 0.0:
		_intro_left = maxf(0.0, _intro_left - delta)
		var prog := 1.0 - _intro_left / _intro_total
		var a := lerpf(PI * 1.15, 0.0, 1.0 - pow(1.0 - prog, 2.0))
		var cb := xf.basis.orthonormalized()
		var r := lerpf(6.5, 6.0, prog)
		var orbit := xf.origin + cb * Vector3(sin(a) * r, lerpf(1.2, 2.0, prog), cos(a) * r)
		var w := smoothstep(0.55, 1.0, prog)
		cam_pos = orbit.lerp(cam_pos, w)
		look_at_pos = (xf.origin + cb.y * 0.5).lerp(look_at_pos, w)
		up_vec = cb.y.lerp(up_vec, w).normalized()

	if cam_pos.is_equal_approx(look_at_pos):
		return
	global_position = cam_pos
	var fwd := (look_at_pos - cam_pos).normalized()
	if absf(fwd.dot(up_vec)) > 0.999:
		up_vec = frame_basis.z
	look_at(look_at_pos, up_vec)


## Keep the camera from clipping into walls: ray from the pivot to the desired position.
func _collide(pivot: Vector3, offset: Vector3) -> Vector3:
	var world := get_world_3d()
	if world == null:
		return offset
	var space := world.direct_space_state
	if space == null:
		return offset
	var want := offset.length()
	if want < 0.01:
		return offset
	var q := PhysicsRayQueryParameters3D.create(pivot, pivot + offset * 1.08, collision_mask)
	q.collide_with_areas = false
	q.hit_back_faces = false
	var hit := space.intersect_ray(q)
	var allowed := want
	if not hit.is_empty():
		allowed = maxf(1.2, pivot.distance_to(hit["position"]) / 1.08 - 0.25)
	# Snap in fast, ease out slowly (avoids popping).
	if _col_dist < 0.0:
		_col_dist = allowed
	elif allowed < _col_dist:
		_col_dist = allowed
	else:
		_col_dist = lerpf(_col_dist, allowed, 0.08)
	if _col_dist >= want - 0.001:
		return offset
	return offset.normalized() * _col_dist


func _geometry() -> Dictionary:
	if target is Car:
		var cfg: Dictionary = (target as Car).config
		return CarDefs.geometry(String(cfg.get("car", "kaze")))
	return CarDefs.geometry("kaze")


static func _slerp_dir(a: Vector3, b: Vector3, t: float) -> Vector3:
	var d := clampf(a.dot(b), -1.0, 1.0)
	if d > 0.99999:
		return b
	if d < -0.9999:
		# Opposite directions: rotate around any perpendicular axis.
		var axis := a.cross(Vector3.RIGHT)
		if axis.length_squared() < 1e-6:
			axis = a.cross(Vector3.UP)
		return a.rotated(axis.normalized(), PI * t)
	var axis2 := a.cross(b).normalized()
	return a.rotated(axis2, acos(d) * t).normalized()
