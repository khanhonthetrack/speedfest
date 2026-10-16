class_name TmCarModel
extends RefCounted
## One tick of the TMNF Stadium car's handling (force model 6), independent of any physics engine.
## Our implementation of the behaviour described in docs/research/tmnf_physics.md.
##
## The host (TmCar in the remake, Car in SpeedFest) owns the rigid body. Every 10 ms it updates the
## suspension (integrate_suspension), fills 4 WheelInput (FL, FR, RL, RR), calls tick(), then applies
## `force` (central, car frame), `torque` (car frame), each `wheel_force` at its wheel, gravity x
## `gravity_coef` and `linear_damp`; if `air_set_w` is true it first replaces the angular velocity
## by `air_w`. Car frame: +X left, +Y up, +Z forward. Mass 1: forces are accelerations, and torques
## are for TmTuning.INERTIA (a host with another inertia applies torque / INERTIA x its own).
##
## Shared by the Stadium remake (stadium/core, the source) and SpeedFest (game/cars/tm, a copy kept
## identical by tools/sync_tm_core.sh). SpeedFest's cars scale it with the *_mul fields.

const T := preload("tm_tuning.gd")


class WheelInput:
	var contact := false          ## ground contact (touching something within 45 deg of the car's up)
	var side_contact := false     ## touching something steeper (a wall): wall slow-down
	var normal := Vector3.UP      ## contact normal, car frame
	var surface := 16             ## TmTuning.Surface id under the wheel
	var pad_dir := Vector3.ZERO   ## turbo pad forward direction in the car frame (zero if none)
	var pos := Vector3.ZERO       ## wheel position relative to the centre of mass, car frame


# --- per-car scaling (SpeedFest's cars; 1.0 for the Stadium car) ---
var accel_mul := 1.0                          ## engine acceleration curve (and the speedslide value)
var steer_mul := 1.0                          ## steering yaw torque
var grip_mul := 1.0                           ## side friction caps
var brake_mul := 1.0                          ## brake force and caps
var slide_grip := T.SLIDE_GRIP                ## grip of a sliding wheel (drift looseness)
var max_speed := T.MAX_SPEED                  ## m/s: the over-speed push starts here

# --- persistent state ---
var steer := 0.0                              ## current steering (-1..1, + = left), slewed
var sliding: Array[bool] = [false, false, false, false]
var susp_len := PackedFloat32Array([T.SUSP_STATIC, T.SUSP_STATIC, T.SUSP_STATIC, T.SUSP_STATIC])
var susp_vel := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var reverse := false
var wall_until_ms := -1
var turbo_strength := 0.0
var turbo_until_ms := -1
var free_wheeling := false
var air_yaw := 0.0                            ## yaw rate kept from the last contact
var air_pitch := 0.0
var grounded := false

# --- outputs of the last tick ---
var force := Vector3.ZERO                     ## central force, car frame
var torque := Vector3.ZERO                    ## torque, car frame
var wheel_force: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var gravity_coef := T.GRAVITY_GROUND
var linear_damp := 0.0
var air_set_w := false
var air_w := Vector3.ZERO
var any_sliding := false
var drive_now := 0.0                          ## drive acceleration this tick (HUD/debug)
var brake_now := 0.0


func reset() -> void:
	steer = 0.0
	sliding = [false, false, false, false]
	for i in 4:
		susp_len[i] = T.SUSP_STATIC
		susp_vel[i] = 0.0
	reverse = false
	wall_until_ms = -1
	turbo_strength = 0.0
	turbo_until_ms = -1
	free_wheeling = false
	air_yaw = 0.0
	air_pitch = 0.0


## Suspension step for one wheel (TMNF suspension model 2). `penetration` = how deep the wheel at its
## current length is into the ground, along the car's up axis. Returns the new length (0 = bottomed,
## 0.2 = fully extended).
func integrate_suspension(i: int, penetration: float, dt: float) -> float:
	var l: float = susp_len[i]
	var base := l - clampf(penetration, 0.0, l)
	var nl := base + T.SUSP_RELAX * dt * (T.SUSP_REST - base)
	susp_vel[i] = (nl - l) / dt
	susp_len[i] = nl
	return nl


func start_turbo(strength: float, ms: int, now_ms: int) -> void:
	turbo_strength = strength
	turbo_until_ms = now_ms + ms


## gas, brake: 0..1; steer_target: -1..1 (+ = left). v, w: linear and angular velocity in the car
## frame. up_local: world up in the car frame. wheels: 4 WheelInput. body_contact: the chassis
## touches something this tick.
func tick(dt: float, now_ms: int, gas: float, brake: float, steer_target: float,
		v: Vector3, w: Vector3, up_local: Vector3, wheels: Array, body_contact: bool) -> void:
	force = Vector3.ZERO
	torque = Vector3.ZERO
	for i in 4:
		wheel_force[i] = Vector3.ZERO
	air_set_w = false
	drive_now = 0.0
	brake_now = 0.0

	steer = move_toward(steer, clampf(steer_target, -1.0, 1.0), T.STEER_RATE * dt)

	# contacts, surfaces (averaged over the wheels on the ground; all zero in the air), pads
	var n_ground := 0
	var surf := [0.0, 0.0, 0.0, 0.0]
	var wall := false
	var front_touch := false
	free_wheeling = false
	for i in 4:
		var wi: WheelInput = wheels[i]
		if wi.side_contact:
			wall = true
		if not wi.contact:
			continue
		n_ground += 1
		if i < 2:
			front_touch = true
		var sv: Array = T.surface_vals(wi.surface)
		for k in 4:
			surf[k] += sv[k]
		match wi.surface:
			T.Surface.TURBO:
				start_turbo(T.TURBO_STRENGTH * wi.pad_dir.z, T.TURBO_MS, now_ms)
			T.Surface.TURBO2:
				start_turbo(T.TURBO2_STRENGTH * wi.pad_dir.z, T.TURBO2_MS, now_ms)
			T.Surface.FREE_WHEELING:
				free_wheeling = true
	grounded = n_ground > 0
	if grounded:
		for k in 4:
			surf[k] /= float(n_ground)
	if wall:
		wall_until_ms = now_ms + T.WALL_SLOWDOWN_MS
	if now_ms > turbo_until_ms:
		turbo_strength = 0.0
	gravity_coef = T.GRAVITY_GROUND if grounded else T.GRAVITY_AIR
	linear_damp = 0.0 if grounded else T.AIR_LINEAR_DAMP

	var speed := v.length()
	var kmh := v.z * 3.6

	# coasting drag (also in the air) and the wall slow-down
	var drive_in := brake if reverse else gas
	# (the constant parts never push past a standstill within one step: no chatter at rest)
	if (drive_in < 1e-5 or free_wheeling) and speed > 1e-4:
		force += -v.normalized() * minf(T.COAST_CONST, speed / dt)
		if not free_wheeling:
			force += -v * T.COAST_LIN
	if now_ms < wall_until_ms and speed > 1e-5:
		force += -v.normalized() * minf(T.lin(T.WALL_SLOWDOWN, speed * 3.6), speed / dt)

	# slope adherence: share of gravity along the car's up axis
	var up_share := absf(up_local.y) / maxf(1e-6, up_local.length())
	var side_adh := T.smooth_ramp(up_share, T.SLOPE_SIDE_MIN, T.SLOPE_SIDE_FULL)
	var drive_adh := T.smooth_ramp(up_share, T.SLOPE_DRIVE_MIN, T.SLOPE_DRIVE_FULL)

	var delta := steer * T.steer_angle(v.z)
	var cap_speed := T.lin(T.MAX_SIDE_FRICTION, kmh) * grip_mul

	# 1) per wheel on the ground: suspension force, roll/pitch damping, side grip at the CoM
	var flag_sliding := false
	for i in 4:
		var wi: WheelInput = wheels[i]
		if not wi.contact:
			continue
		wheel_force[i] = Vector3.UP * ((T.SUSP_REST - susp_len[i]) * T.SPRING - T.DAMPER * susp_vel[i])
		var n := wi.normal
		var lat := Vector3(n.y, -n.x, 0.0)
		lat = lat.normalized() if lat.length_squared() > 1e-8 else Vector3(1, 0, 0)
		if i < 2:
			lat = lat * cos(delta) - Vector3(0, 0, 1) * sin(delta)
		if w.length() >= T.RP_DAMP_MIN_W:
			var tr := -(wi.pos.cross(-T.RP_DAMP * w))
			torque += Vector3(T.RP_DAMP_X * tr.x, 0.0, T.RP_DAMP_Z * tr.z)
		var cap: float = T.surface_vals(wi.surface)[3] * side_adh * cap_speed * T.damper_grip(susp_len[i])
		if sliding[i]:
			cap *= slide_grip
			if brake > 0.1:
				cap *= T.SLIDE_BRAKE_GRIP
		var f := -T.SIDE_STIFFNESS * 0.5 * v.dot(lat)
		if absf(f) <= cap:
			sliding[i] = false
		else:
			sliding[i] = true
			f = (1.0 - T.SLIDE_BLEND) * signf(f) * cap + T.SLIDE_BLEND * f
			flag_sliding = true
		force += lat * f
	if n_ground == 4 and v.z > 6.0 and _all_surface(wheels, T.Surface.DIRT):
		_dirt_forces(v, gas, brake)

	if grounded:
		_ground_drive(v, w, gas, brake, speed, kmh, surf, drive_adh, flag_sliding)
	any_sliding = flag_sliding or sliding.has(true)

	_air_control(w, steer_target, brake, front_touch, body_contact, grounded)


func _ground_drive(v: Vector3, w: Vector3, gas: float, brake: float, speed: float, kmh: float,
		surf: Array, drive_adh: float, flag_sliding: bool) -> void:
	# reverse gear: brake near a standstill backs up; gas or moving forward ends it
	if brake > 0.1 and v.z < 0.5 and absf(v.x) < 2.0:
		reverse = true
	if gas > 0.1 and (v.z > 0.0 or absf(v.x) > 2.0):
		reverse = false
	if gas < 0.1 and brake < 0.1:
		reverse = not (v.z > 0.0 or absf(v.z) < T.REVERSE_SWITCH_SPEED)
	if v.z > 0.0 and turbo_strength > 0.0:
		reverse = false

	# roll torque from side speed
	var roll := T.lin(T.ROLLOVER, v.x * v.x / (absf(v.z) + 1.0))
	torque += Vector3(0.0, 0.0, roll * (-1.0 if v.x > 0.0 else 1.0))

	# yaw: per-axle side forces (never capped) + steering torque on the front axle
	var over := 0.0
	var caps := 0.0
	var ramp := 0.0
	if speed >= T.STEER_MIN_SPEED:
		ramp = sin(speed / T.STEER_RAMP_SPEED * PI * 0.5) if speed <= T.STEER_RAMP_SPEED else 1.0
	var cap_axle: float = T.lin(T.MAX_SIDE_FRICTION, kmh) * surf[3] * grip_mul
	var dir := -1.0 if reverse else 1.0
	for i in 4:
		var lever := T.WHEELBASE * 0.5 if i < 2 else -T.WHEELBASE * 0.5
		var f := -T.SIDE_STIFFNESS * 0.5 * (v.x + w.y * lever)
		if absf(f) > cap_axle:
			over += absf(f)
			caps += cap_axle
			f = signf(f) * (cap_axle * (1.0 - T.YAW_SLIDE_BLEND) + absf(f) * T.YAW_SLIDE_BLEND)
		var t := T.YAW_FROM_GRIP * f
		if i < 2:
			var k := T.STEER_TORQUE_SLIDING if sliding[i] else 1.0
			t += dir * ramp * steer * T.lin(T.STEER_TORQUE, kmh) * k * steer_mul
		torque += Vector3(0.0, t * lever, 0.0)

	# drive: speed staircase, blended toward the slipping value while the axles exceed their grip
	var slip_blend := 1.0
	if caps > 1e-5:
		slip_blend = 1.0 - clampf((over - caps) / caps / T.SLIP_BLEND_SCALE, 0.0, 1.0)
	var curve_accel := (T.lin(T.REVERSE_ACCEL, kmh) if reverse else T.step(T.ACCEL, kmh)) * accel_mul
	var accel := (1.0 - slip_blend) * T.SLIP_ACCEL * accel_mul + slip_blend * curve_accel
	var rev := -1.0 if reverse else 0.0
	var f_long: float = curve_accel * turbo_strength + (gas * surf[1] + rev * surf[1] * brake) * accel
	f_long -= T.STEER_SLOWDOWN_SCALE * absf(steer) * T.lin(T.STEER_SLOWDOWN, kmh) * dir
	if free_wheeling:
		f_long = curve_accel * turbo_strength
	drive_now = f_long

	# brake; hitting the cap locks every wheel into the sliding state (TM's brake drift)
	var fb := 0.0
	var halving := 1.0
	for i in 4:
		if sliding[i]:
			halving *= T.BRAKE_PER_SLIDING_WHEEL
	if v.z > 0.0:
		fb = (T.BRAKE_A + T.BRAKE_B * v.z) * brake * halving * brake_mul
		var cap_b: float = surf[2] * (T.BRAKE_CAP_SLIDING if flag_sliding else T.BRAKE_CAP) * brake_mul
		if fb > cap_b:
			fb = cap_b
			sliding = [true, true, true, true]
	elif v.z < 0.0 and gas > 0.1:
		fb = (T.BRAKE_A - T.BRAKE_B * v.z) * gas * halving * brake_mul
		var cap_r: float = surf[2] * (T.REVERSE_BRAKE_CAP_SLIDING if flag_sliding else T.REVERSE_BRAKE_CAP) * brake_mul
		if fb > cap_r:
			fb = cap_r
			sliding = [true, true, true, true]
	brake_now = fb
	var total := f_long - signf(v.z) * fb
	if v.z > max_speed * surf[0]:
		total = -T.OVERSPEED_PUSH if total >= 0.0 else total - T.OVERSPEED_PUSH
	if v.z < -T.MAX_REVERSE_SPEED * surf[0]:
		total = T.OVERSPEED_PUSH if total <= 0.0 else total + T.OVERSPEED_PUSH
	force += Vector3(0.0, 0.0, total * drive_adh)


func _all_surface(wheels: Array, id: int) -> bool:
	for wi in wheels:
		if (wi as WheelInput).surface != id:
			return false
	return true


## Dirt (all four wheels): braking drags, sliding with gas pushes the car on (power slides).
func _dirt_forces(v: Vector3, gas: float, brake: float) -> void:
	var lat_share := v.x / maxf(1e-5, v.length())
	if brake > 0.1:
		force += -v * 0.1
	if not free_wheeling and gas > 0.1 and brake < 0.1:
		var a := absf(lat_share)
		var k := a * 20.0 + 1.0
		var vz2 := (absf(v.z) + 1.0) * (absf(v.z) + 1.0)
		var side := T.DIRT_SIDE * lat_share / (T.DIRT_SIDE_GAS * gas + 1.0)
		var push := T.DIRT_PUSH_GAS * gas * a * k * T.DIRT_PUSH / vz2
		for i in 4:
			if not sliding[i]:
				continue
			if i < 2:
				wheel_force[i] += Vector3(side, 0.0, push * 1.5)
			else:
				wheel_force[i] += Vector3(-side, 0.0, push)


## In the air: no steering. Counter-steering against the take-off spin holds the yaw rate, steering
## with it triples the angular drag, brake cancels a nose-down pitch rotation; angular drag
## 0.4|w| + 0.2|w|^2 against the spin.
func _air_control(w: Vector3, steer_target: float, brake: float, front_touch: bool,
		body_contact: bool, on_ground: bool) -> void:
	if front_touch or body_contact:
		air_yaw = w.y
		air_pitch = w.x
		return
	var damp := -w
	var yaw := w.y
	if (steer_target > 1e-5 and air_yaw < 0.0) or (steer_target < -1e-5 and air_yaw > 0.0):
		if absf(w.y) > T.AIR_YAW_FLIP:
			damp *= 3.0
			air_yaw = w.y
		else:
			yaw = air_yaw
	else:
		if (steer_target > 1e-5 and air_yaw > 0.0) or (steer_target < -1e-5 and air_yaw < 0.0):
			damp *= 3.0
		air_yaw = w.y
	if brake > 1e-5 and air_pitch > 0.0:
		air_pitch = 0.0
	else:
		air_pitch = w.x
	air_set_w = true
	air_w = Vector3(air_pitch, yaw, w.z)
	if not on_ground:
		var m := damp.length()
		if m > 1e-5:
			torque += damp / m * (T.AIR_ANG_DAMP_LIN * m + T.AIR_ANG_DAMP_QUAD * m * m)
