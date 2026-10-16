class_name CarTm
extends RefCounted
## TMNF handling for SpeedFest's Car: the default since session 9 (owner: "Yes" to porting
## TrackMania Nations Forever's real car model, docs/research/tmnf_physics.md).
##
## The car is moved by TmBody, TMNF's own integrator shared with the Stadium remake (sub-steps,
## ellipsoid wheel and chassis contacts, TMNF's contact impulses, the force model TmCarModel), not
## by Jolt: the Car is a kinematic RigidBody3D (it still triggers checkpoints and pads). TMNF ticks
## at 100 Hz; here each 60 Hz frame runs 2 ticks of 8.3 ms (even motion; the model is stable down
## to ~80 Hz). Contacts use the car's own wheels (positions, radius) and chassis ellipsoids scaled
## to its size; the forces are the Stadium car's, times the per-car multipliers (Tuning "tm_*").
##
## Frames: SpeedFest's car frame is Godot's (+X right, +Y up, -Z forward), origin at the wheel
## centres; TMNF's is +X left, +Y up, +Z forward, origin at the centre of mass.

const T := preload("tm_tuning.gd")
const VIS_STEER := [[0.0, 30.0], [100.0, 10.0]]    ## visual front wheel angle (deg) vs km/h [0x378]
## TrackSurface kinds (asphalt, grass, gravel, sand, dirt, ice, plastic) -> TmTuning surfaces.
## The Stadium car's own surfaces (asphalt, grass, dirt) keep TMNF's values; gravel and sand use
## TMNF's dirt road and sand; ice and plastic (no Stadium equivalent; TMNF's ice has no drive and
## no grip at all) get SpeedFest values: SF_ICE, SF_PLASTIC.
const SF_ICE := 200
const SF_PLASTIC := 201
const SURFACE_OF_KIND: Array[int] = [16, 2, 8, 5, 6, SF_ICE, SF_PLASTIC]
const SF_SURFACES := {SF_ICE: [1.0, 0.45, 0.25, 0.12], SF_PLASTIC: [1.0, 0.9, 0.9, 0.7]}
const MAX_SPEED_HARD := 125.0                     ## m/s: checkpoint triggers are 4 m deep at 60 Hz
const REACTOR_LIFT := 0.8                         ## x TMNF's air gravity, upward
const REACTOR_PUSH := 7.0
const TMNF_DT := 0.01
const NITRO_TOP := 1.08                           ## nitro lifts the top-speed cap by this
const RIGHTING_AFTER := 1.5                       ## s upside down and slow: SpeedFest self-rights

var car: Car
var body := TmBody.new()
var model: TmCarModel:
	get: return body.model
var _com := Vector3.ZERO                          ## centre of mass in the SpeedFest car frame


## Side grip per surface kind (for the AutoDriver's planning).
static func kind_grip(kind: int) -> float:
	var id: int = SURFACE_OF_KIND[clampi(kind, 0, SURFACE_OF_KIND.size() - 1)]
	return float((SF_SURFACES[id] if SF_SURFACES.has(id) else T.surface_vals(id))[3])


func _init(p_car: Car) -> void:
	car = p_car
	body.model.surface_override = SF_SURFACES
	body.model.reverse_brake_min = 0.5        # a light brake (pad trigger) doesn't back up
	body.collision_mask = 1
	body.surface_fn = _surface_for_body
	_com = car.center_of_mass
	var wheels: Array = []
	for wp in car._wheel_pos:
		var w: Vector3 = wp - _com
		wheels.append(Vector3(-w.x, w.y, -w.z))
	var g := CarDefs.geometry(car.car_id)
	var scale := Vector3(float(g["width"]) / 2.04, clampf(float(g["height"]) / 1.18, 0.8, 1.1), float(g["length"]) / 4.1)
	body.setup(wheels, car._radius, T.WHEEL_HALF_WIDTH, T.BODY_ELLIPSOIDS, scale)
	apply_params(car.params)


## Per-car multipliers from Tuning.physics_params.
func apply_params(p: Dictionary) -> void:
	model.accel_mul = float(p.get("tm_accel", 1.0))
	model.steer_mul = float(p.get("tm_steer", 1.0))
	model.grip_mul = float(p.get("tm_grip", 1.0))
	model.brake_mul = float(p.get("tm_brake", 1.0))
	model.slide_grip = float(p.get("tm_slide", T.SLIDE_GRIP))
	model.max_speed = float(p.get("tm_top", T.MAX_SPEED))


## SpeedFest transform (Car) -> the body's pose, and back.
func _to_body(xf: Transform3D) -> Transform3D:
	var b := xf.basis.orthonormalized()
	return Transform3D(Basis(-b.x, b.y, -b.z), xf * _com)


func _from_body() -> Transform3D:
	var tb := body.xform.basis
	var b := Basis(-tb.x, tb.y, -tb.z)
	return Transform3D(b, body.xform.origin - b * _com)


func teleport(xf: Transform3D, v: Vector3) -> void:
	body.reset()
	body.xform = _to_body(xf)
	body.lin_vel = v


func reset() -> void:
	body.reset()


## Steady full-lock yaw rate (rad/s) at speed v (m/s): steering torque K * L (both front wheels at
## L/2) against the axle yaw damping 0.08 * 20 * w * L^2: w = K / (0.08 * 40 * 0.5 * L)
## (docs/research/tmnf_physics.md §3.4). Used by Car.max_steer_at and the AutoDriver.
func max_yaw_rate(v: float) -> float:
	v = absf(v)
	if v < T.STEER_MIN_SPEED:
		return 0.0
	var ramp := sin(v / T.STEER_RAMP_SPEED * PI * 0.5) if v <= T.STEER_RAMP_SPEED else 1.0
	return model.steer_mul * T.lin(T.STEER_TORQUE, v * 3.6) * ramp \
		/ (T.YAW_FROM_GRIP * T.SIDE_STIFFNESS * 0.5 * T.WHEELBASE)


## Highest speed (m/s) for a curve of curvature kappa (1/m) on ground of side grip `grip`: the
## steering's yaw rate (margin) and the 4 wheels' side friction both have to follow it.
func max_speed_for(kappa: float, grip: float = 1.0, margin: float = 0.92) -> float:
	kappa = absf(kappa)
	if kappa < 1e-5:
		return 200.0
	var lo := 3.0
	var hi := 200.0
	for _i in 30:
		var v := (lo + hi) * 0.5
		var a_lat := 4.0 * T.lin(T.MAX_SIDE_FRICTION, v * 3.6) * model.grip_mul * grip
		if v * kappa <= margin * max_yaw_rate(v) and v * v * kappa <= a_lat * margin:
			lo = v
		else:
			hi = v
	return lo


## TMNF's side-grip share for the car's current tilt (0 on walls steeper than ~73 deg, 1 level or
## upside down).
func side_adherence() -> float:
	var up := car.global_transform.basis.y
	return T.smooth_ramp(absf(up.y), T.SLOPE_SIDE_MIN, T.SLOPE_SIDE_FULL)


## One 60 Hz frame (Car._physics_process).
func frame(dt: float) -> void:
	var space := car.get_world_3d().direct_space_state
	var m_ticks := maxi(1, ceili(dt / TMNF_DT - 1e-6))
	var h := dt / float(m_ticks)
	var was_grounded := car._grounded
	var prev_vel := body.lin_vel

	# --- controls and special pads ---
	var gas := clampf(float(car.controls.get("throttle", 0.0)), 0.0, 1.0)
	var brake := clampf(float(car.controls.get("brake", 0.0)), 0.0, 1.0)
	var steer_in := clampf(float(car.controls.get("steer", 0.0)), -1.0, 1.0)
	if bool(car.controls.get("handbrake", false)):
		brake = 1.0                          # TMNF has no handbrake: the brake is the drift button
	var want_nitro := bool(car.controls.get("nitro", false))
	if car.frozen_controls:
		gas = 0.0
		brake = 0.0
		steer_in = 0.0
		want_nitro = false
	for k in car._fx:
		if float(car._fx[k]) > 0.0:
			car._fx[k] = maxf(float(car._fx[k]) - dt, 0.0)
	if float(car._fx["engine_off"]) > 0.0:
		gas = 0.0
		want_nitro = false
	if float(car._fx["no_steer"]) > 0.0:
		steer_in = 0.0
	var cruising := float(car._fx["cruise"]) > 0.0
	if cruising:
		gas = 1e-4                           # "on the throttle" (no coasting drag), no drive
		brake = 0.0
	body.gas = gas
	body.brake = brake
	body.steer = -steer_in                   # TMNF: + = left

	# --- grinding a rail: the rail drives the car ---
	if car.grind != null:
		_grind_frame(dt)
		return

	# --- SpeedFest extras as accelerations over the frame: nitro, boost pads, cruise, reactor ---
	var b0 := car.global_transform.basis
	var fwd0 := -b0.z
	var gn := car._ground_n
	var fwd_g := fwd0
	if car._grounded >= 2:
		fwd_g = fwd0 - gn * fwd0.dot(gn)
		fwd_g = fwd_g.normalized() if fwd_g.length_squared() > 1e-6 else fwd0
	var extra := Vector3.ZERO
	car._nitro_active = false
	if want_nitro and car._nitro > 0.0 and not model.reverse:
		car._nitro_active = true
		car._nitro = maxf(car._nitro - dt / float(car.params["nitro_time"]), 0.0)
		extra += fwd_g * float(car.params["nitro_accel"])
	if car._boost_time > 0.0:
		car._boost_time -= dt
		var bd := car._boost_dir
		if car._grounded >= 2:
			bd = bd - gn * bd.dot(gn)
			bd = bd.normalized() if bd.length_squared() > 1e-4 else fwd0
		var fade := 1.0 - clampf((body.lin_vel.dot(bd) - Car.BOOST_FADE_FROM) / (Car.BOOST_SPEED_CAP - Car.BOOST_FADE_FROM), 0.0, 1.0)
		extra += bd * car._boost_accel * fade
	if cruising and car._grounded >= 2:
		extra += fwd_g * clampf((car._cruise_speed - car._fwd_speed) / 0.3, -15.0, 15.0)
	if float(car._fx["reactor"]) > 0.0:
		if car._grounded == 0:
			extra += Vector3.UP * T.GRAVITY * T.GRAVITY_AIR * REACTOR_LIFT + fwd0 * REACTOR_PUSH
		else:
			extra += fwd_g * REACTOR_PUSH
	model.max_speed = float(car.params.get("tm_top", T.MAX_SPEED)) * (NITRO_TOP if car._nitro_active else 1.0)
	# --- SpeedFest's roof drag: a car sliding on its roof or side settles (then self-rights) ---
	var spd := body.lin_vel.length()
	if body.body_contact and car._grounded < 2 and b0.y.dot(Vector3.UP) < 0.4 and spd > 0.5:
		extra -= body.lin_vel / spd * minf(Car.ROOF_DRAG, spd / dt)
	# --- SpeedFest's self-righting (TMNF has none: you respawn): upside down or on the side and
	# slow for 1.5 s, the car rolls back onto its wheels ---
	var up0 := b0.y
	if up0.dot(Vector3.UP) < 0.3 and car._grounded < 2 and body.lin_vel.length() < 3.0:
		car._upside_time += dt
	else:
		car._upside_time = 0.0
	if car._upside_time > RIGHTING_AFTER and car._righting <= 0.0:
		car._righting = 1.0
	if car._righting > 0.0:
		car._righting -= dt
		if up0.dot(Vector3.UP) > 0.92:
			car._righting = 0.0
		else:
			if up0.dot(Vector3.UP) < 0.5 and car._righting > 0.4:
				extra += Vector3.UP * T.GRAVITY * model.gravity_coef * 1.2
			var axis := up0.cross(Vector3.UP)
			if axis.length_squared() < 1e-4:
				axis = fwd0
			body.ang_vel = axis.normalized() * 3.0
	body.extra_accel = extra

	# --- TMNF ---
	body.xform = _to_body(car.global_transform)
	var walls: Array[Vector3] = []
	for k in m_ticks:
		body.step(space, h)
		walls.append_array(body.wall_normals)
	var sp2 := body.lin_vel.length_squared()
	if sp2 > MAX_SPEED_HARD * MAX_SPEED_HARD:
		body.lin_vel *= MAX_SPEED_HARD / sqrt(sp2)
	if car.frozen_controls and body.wheel_contact.count(true) >= 2:
		body.lin_vel = Vector3.ZERO           # held on the start line
		body.ang_vel = Vector3.ZERO
	car.global_transform = _from_body()
	car.linear_velocity = body.lin_vel
	car.angular_velocity = body.ang_vel
	var rev_gas := clampf(float(car.controls.get("throttle", 0.0)), 0.0, 1.0) if car.frozen_controls else gas
	_update_car_state(dt, rev_gas, was_grounded, prev_vel, walls)


## The rail moves the car (TrackRail.grind_step works on a state-like object).
func _grind_frame(dt: float) -> void:
	var gs := GrindState.new()
	gs.step = dt
	gs.transform = car.global_transform
	gs.linear_velocity = body.lin_vel
	gs.angular_velocity = body.ang_vel
	if car.grind.grind_step(car, gs):
		car._grounded = 0
		car._air_time = 0.0
		car._boost_time = 0.0
	else:
		car.grind = null
	car.global_transform = gs.transform
	body.xform = _to_body(gs.transform)
	body.lin_vel = gs.linear_velocity
	body.ang_vel = gs.angular_velocity
	car.linear_velocity = body.lin_vel
	car.angular_velocity = body.ang_vel


class GrindState:
	var step := 0.016
	var transform := Transform3D()
	var linear_velocity := Vector3.ZERO
	var angular_velocity := Vector3.ZERO


## Fill the Car's state for the HUD, sound, visuals, net, signals and the AutoDriver.
func _update_car_state(dt: float, gas: float, was_grounded: int, prev_vel: Vector3, walls: Array[Vector3]) -> void:
	var xf := car.global_transform
	var b := xf.basis
	var up := b.y
	var fwd := -b.z
	var lv := body.lin_vel
	car._fwd_speed = lv.dot(fwd)
	car._grounded = 0
	var n_sum := Vector3.ZERO
	var water_sum := 0.0
	for i in 4:
		var c: bool = body.wheel_contact[i]
		car._contact[i] = c
		var off := T.SUSP_STATIC - float(model.susp_len[i])
		car._comp[i] = off
		car._vis_offset[i] = off
		car._load[i] = (T.SUSP_REST - float(model.susp_len[i])) * T.SPRING * car.mass if c else 0.0
		car._ground[i] = 0
		car._water[i] = 0.0
		if c:
			car._grounded += 1
			car._hit_pos[i] = body.wheel_hit_pos[i]
			car._hit_n[i] = body.wheel_hit_n[i]
			n_sum += body.wheel_hit_n[i]
			if car.surface != null:
				car._water[i] = car.surface.water_at(body.wheel_hit_pos[i])
				water_sum += car._water[i]
				if not car.surface.patches.is_empty():
					car._ground[i] = car.surface.kind_at(body.wheel_hit_pos[i])
	car._water_avg = water_sum / 4.0
	car._prev_ground_n = car._ground_n
	car._ground_n = n_sum.normalized() if car._grounded > 0 else up
	var v_abs := absf(car._fwd_speed)
	car._reversing = model.reverse and car._fwd_speed < 0.5
	car._braking = (body.brake > 0.1 and v_abs > 0.5 and not model.reverse) or model.brake_now > 0.5
	car._steer_angle = -model.steer * deg_to_rad(T.lin(VIS_STEER, v_abs * 3.6))
	var lv_g := lv - car._ground_n * lv.dot(car._ground_n)
	var slip := 0.0
	if car._grounded >= 2 and lv_g.length() > 3.0:
		var fg := (fwd - car._ground_n * fwd.dot(car._ground_n)).normalized()
		slip = atan2(lv_g.dot(b.x), absf(lv_g.dot(fg)))
	car._slip_angle = slip
	var slide := 1.0 if model.any_sliding and car._grounded >= 2 and v_abs > 8.0 else 0.0
	car._drift = move_toward(car._drift, maxf(slide * 0.6, clampf((absf(slip) - deg_to_rad(4.0)) / deg_to_rad(12.0), 0.0, 1.0)), dt * 4.0)
	car._wheelspin = move_toward(car._wheelspin, slide, dt * 5.0)
	_gears_and_sound(dt, gas, v_abs)
	for i in 4:
		var sv := car._fwd_speed / car._radius
		if not car._contact[i] and gas > 0.1:
			sv = move_toward(car._spin_vel[i], 120.0 * gas, 200.0 * dt)
		car._spin_vel[i] = sv
		car._spin[i] = fmod(car._spin[i] + sv * dt, TAU)
	# landings and wall hits
	if car._grounded == 0:
		car._air_time += dt
	else:
		if was_grounded == 0 and car._air_time > 0.25:
			car.landed.emit(absf(prev_vel.dot(car._ground_n)))
		car._air_time = 0.0
	var lost := (prev_vel - lv).length()
	if lost > 2.0:
		for n in walls:
			if absf(n.dot(car._ground_n)) < 0.5:
				car.wall_hit.emit(lost)
				break
	car._prev_vel = lv


## SpeedFest surfaces under a contact (TmBody.surface_fn): the track's ground patches and the
## weather's puddles. Rally tyres (Car.params "loose_grip") keep asphalt-like values on loose ground.
func _surface_for_body(p: Vector3, _n: Vector3) -> Array:
	var s := car.surface
	if s == null:
		return [T.Surface.ASPHALT, Vector3.ZERO]
	var kind := 0
	if not s.patches.is_empty():
		kind = s.kind_at(p)
	if kind > 0 and car._loose_grip > 0.5 and TrackSurface.KIND_LOOSE[kind]:
		return [T.Surface.DIRT_ROAD, Vector3.ZERO]
	if kind == 0 and s.water_at(p) > 0.35:
		return [T.Surface.WET_PAVEMENT, Vector3.ZERO]
	return [SURFACE_OF_KIND[clampi(kind, 0, SURFACE_OF_KIND.size() - 1)], Vector3.ZERO]


## Gears and rpm only drive the engine sound and the HUD (TMNF's gearbox doesn't change the drive).
func _gears_and_sound(dt: float, gas: float, v_abs: float) -> void:
	car._shift_timer = maxf(car._shift_timer - dt, 0.0)
	car._shift_hold = maxf(car._shift_hold - dt, 0.0)
	if not car._reversing and car._shift_hold <= 0.0:
		var ng := Tuning.best_gear(car.params, maxf(car._fwd_speed, 0.0), car._gear)
		if ng != car._gear:
			if ng > car._gear:
				car._shift_timer = Car.SHIFT_TIME
			car._gear = ng
			car._shift_hold = Car.SHIFT_HOLD
	var target := 0.0
	if car.frozen_controls or (v_abs < 1.0 and not car._reversing):
		target = 0.12 + gas * 0.8
	else:
		target = maxf(Tuning.rpm_ratio(car.params, -1 if car._reversing else car._gear, car._fwd_speed), 0.12)
		if car._grounded == 0 and gas > 0.1:
			target = maxf(target, 0.85 * gas)
		target = minf(target + car._wheelspin * 0.25, 1.0)
		if car._shift_timer > 0.0:
			target *= 0.82
	car._rpm = move_toward(car._rpm, target, dt * (3.0 if car._shift_timer > 0.0 else 6.0))
