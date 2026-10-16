class_name CarTm
extends RefCounted
## TMNF handling for SpeedFest's Car: the default since session 9 (owner: "Yes" to porting
## TrackMania Nations Forever's real car model, docs/research/tmnf_physics.md).
##
## The Car keeps its RigidBody3D (Jolt resolves the chassis contacts, friction 0.3 like TMNF) and its
## raycast wheels. Every physics tick this class runs TmCarModel (the Stadium car's force model 6,
## shared with the Stadium remake) and applies its accelerations times the car's mass and its
## angular accelerations (torque / TmTuning.INERTIA) times the car's inertia, so every SpeedFest car
## steers, accelerates and brakes like the Stadium car, scaled by a few per-car multipliers
## (Tuning.physics_params "tm_*"). Gravity is TMNF's: 30 m/s^2 with a wheel down, 25 in the air.
##
## Frames: SpeedFest's car frame is Godot's (+X right, +Y up, -Z forward); TMNF's is +X left,
## +Y up, +Z forward, i.e. the same frame turned 180 degrees about Y.
##
## Suspension (TMNF model 2): the length relaxes toward full extension at 5/s and the road pushes it
## back in. With rays at 60 Hz the order is "relax, then clamp to the road" (TMNF absorbs first and
## relaxes after; at 60 Hz one relax step, 1.6 cm, would exceed the 1.25 cm static length and the
## springs could never hold 3 g). Same statics (0.0125 m at rest), same lag over crests. When the
## travel runs out (a fast loop, a hard landing) the wheel hits the road like in TMNF: an impulse
## keeps 80% of the approach speed per 10 ms-equivalent step and the car is pushed out of the road.

const T := preload("tm_tuning.gd")
const G := 10.0                                   ## TMNF's gravity field (x gravity_coef)
const VIS_STEER := [[0.0, 30.0], [100.0, 10.0]]    ## visual front wheel angle (deg) vs km/h [0x378]
## TrackSurface kinds (asphalt, grass, gravel, sand, dirt, ice, plastic) -> TmTuning surfaces
const SURFACE_OF_KIND: Array[int] = [16, 2, 8, 5, 6, 3, 0]
const RAY_UP := 0.35                              ## ray origin above the top mount
const MAX_SPEED_HARD := 125.0                     ## m/s: checkpoint triggers are 4 m deep at 60 Hz
const REACTOR_LIFT := 0.55
const REACTOR_PUSH := 7.0

var car: Car
var model := TmCarModel.new()
var wheels: Array = []
var _queries: Array[PhysicsRayQueryParameters3D] = []
var _now_ms := 0.0
var debug_print := false


func _init(p_car: Car) -> void:
	car = p_car
	for i in 4:
		var wi := TmCarModel.WheelInput.new()
		wi.pos = T.WHEELS[i]
		wheels.append(wi)
		var q := PhysicsRayQueryParameters3D.new()
		q.collision_mask = 1
		q.collide_with_areas = false
		q.hit_back_faces = false
		_queries.append(q)
	apply_params(car.params)


## Per-car multipliers from Tuning.physics_params.
func apply_params(p: Dictionary) -> void:
	model.accel_mul = float(p.get("tm_accel", 1.0))
	model.steer_mul = float(p.get("tm_steer", 1.0))
	model.grip_mul = float(p.get("tm_grip", 1.0))
	model.brake_mul = float(p.get("tm_brake", 1.0))
	model.slide_grip = float(p.get("tm_slide", T.SLIDE_GRIP))
	model.max_speed = float(p.get("tm_top", T.MAX_SPEED))


func set_exclude(rid: RID) -> void:
	for q in _queries:
		q.exclude = [rid]


func reset() -> void:
	model.reset()
	for wi in wheels:
		(wi as TmCarModel.WheelInput).contact = false
		(wi as TmCarModel.WheelInput).side_contact = false


## Steady full-lock yaw rate (rad/s) at speed v (m/s): steer torque / yaw damping
## (docs/research/tmnf_physics.md §3.4). Used by Car.max_steer_at for the AutoDriver.
func max_yaw_rate(v: float) -> float:
	v = absf(v)
	if v < T.STEER_MIN_SPEED:
		return 0.0
	var ramp := sin(v / T.STEER_RAMP_SPEED * PI * 0.5) if v <= T.STEER_RAMP_SPEED else 1.0
	return model.steer_mul * T.lin(T.STEER_TORQUE, v * 3.6) * ramp \
		/ (2.0 * T.YAW_FROM_GRIP * T.SIDE_STIFFNESS * 0.5 * T.WHEELBASE)


func integrate(state: PhysicsDirectBodyState3D) -> void:
	var dt := state.step
	var xf := state.transform
	var b := xf.basis
	var up := b.y
	var fwd := -b.z
	var tb := Basis(-b.x, b.y, -b.z)       # TMNF car frame: left, up, forward
	var tinv := tb.transposed()
	var lv := state.linear_velocity
	var av := state.angular_velocity
	var m := car.mass
	var com := xf.origin + state.center_of_mass
	var speed := lv.length()
	car._fwd_speed = lv.dot(fwd)

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
		gas = 0.0
		brake = 0.0

	# --- body contacts: walls touching a wheel (TMNF's wheel side contact) or the chassis ---
	var body_hit := false
	var inv_xf := xf.affine_inverse()
	for i in 4:
		(wheels[i] as TmCarModel.WheelInput).side_contact = false
	for ci in state.get_contact_count():
		var cn := state.get_contact_local_normal(ci)
		var c_loc := inv_xf * state.get_contact_local_position(ci)
		var hit_wheel := -1
		if absf(cn.dot(up)) < T.SIDE_CONTACT_SIN:
			for i in 4:
				var w: Vector3 = car._wheel_pos[i]
				if absf(c_loc.z - w.z) < car._radius + 0.25 and signf(c_loc.x) == signf(w.x):
					hit_wheel = i
					break
		if hit_wheel >= 0:
			(wheels[hit_wheel] as TmCarModel.WheelInput).side_contact = true
		else:
			body_hit = true

	# --- wheels: rays from the top mounts, TMNF suspension (penetration absorbed into the length) ---
	var space := state.get_space_state()
	var was_grounded := car._grounded
	car._grounded = 0
	var n_sum := Vector3.ZERO
	var water_sum := 0.0
	var push := 0.0                          # how far the car must be pushed out of the road
	var bottomed: Array[int] = []
	for i in 4:
		var wi: TmCarModel.WheelInput = wheels[i]
		var w_loc: Vector3 = car._wheel_pos[i]
		var top := xf * (w_loc + Vector3(0.0, T.SUSP_STATIC, 0.0))
		var q := _queries[i]
		q.from = top + up * RAY_UP
		q.to = top - up * (T.SUSP_REST + car._radius + 0.05)
		var hit := space.intersect_ray(q)
		var old_len := float(model.susp_len[i])
		var new_len := old_len + T.SUSP_RELAX * dt * (T.SUSP_REST - old_len)
		wi.contact = false
		car._ground[i] = 0
		car._water[i] = 0.0
		if not hit.is_empty():
			var n: Vector3 = hit["normal"]
			var n_tm := tinv * n
			var len_touch := (top - (hit["position"] as Vector3)).dot(up) - car._radius
			if len_touch <= new_len and absf(n_tm.x) < T.SIDE_CONTACT_SIN and n.dot(up) > 0.0:
				wi.contact = true
				wi.normal = n_tm
				car._hit_pos[i] = hit["position"]
				car._hit_n[i] = n
				n_sum += n
				car._grounded += 1
				new_len = maxf(len_touch, 0.0)
				if len_touch < 0.0:
					push = maxf(push, -len_touch)
					bottomed.append(i)
				wi.surface = _surface_at(i, hit["position"])
				water_sum += car._water[i]
		model.susp_len[i] = new_len
		model.susp_vel[i] = (new_len - old_len) / dt
		car._contact[i] = wi.contact
		var off := T.SUSP_STATIC - float(model.susp_len[i])
		car._comp[i] = off
		car._vis_offset[i] = off
		wi.pad_dir = Vector3.ZERO
	car._water_avg = water_sum / 4.0
	car._prev_ground_n = car._ground_n
	car._ground_n = n_sum.normalized() if car._grounded > 0 else up

	# --- the TMNF force model, at TMNF's rate: 100 Hz or faster (2 steps per 60 Hz frame). Its forces
	# and torques change the velocities between the steps (at 60 Hz the side grip, 80 per m/s, would
	# overshoot); gravity, the springs and the collisions go through Jolt once per frame ---
	var n_steps := maxi(1, ceili(dt / 0.01 - 1e-6))
	var h := dt / float(n_steps)
	var v_tm := tinv * lv
	var w_tm := tinv * av
	var up_tm := tinv * Vector3.UP
	for k in n_steps:
		_now_ms += h * 1000.0
		model.tick(h, int(_now_ms), gas, brake, -steer_in, v_tm, w_tm, up_tm, wheels, body_hit)
		if model.air_set_w:
			w_tm = model.air_w
		v_tm += model.force * h
		if model.linear_damp > 0.0:
			v_tm -= v_tm * model.linear_damp * h
		w_tm += model.torque / T.INERTIA * h
	if debug_print:
		print("   lv_in %s v_tm_in %s v_tm_out %s force %s wf0 %s" % [lv, tinv * lv, v_tm, model.force, model.wheel_force[0]])
	state.linear_velocity = tb * v_tm
	state.angular_velocity = tb * w_tm
	lv = state.linear_velocity
	av = state.angular_velocity
	state.apply_central_force(Vector3(0.0, -G * model.gravity_coef, 0.0) * m)
	for i in 4:
		var wf: Vector3 = model.wheel_force[i]
		car._load[i] = 0.0
		if wf == Vector3.ZERO:
			continue
		var at := xf * (car._wheel_pos[i] + Vector3(0.0, car._comp[i], 0.0))
		state.apply_force(tb * wf * m, at - xf.origin)
		car._load[i] = wf.y * m

	# --- end of the suspension travel: TMNF's wheel impulse + push out of the road ---
	if not bottomed.is_empty():
		var steps := (roundf(0.01 * (speed + av.length()) / T.SUBSTEP_DIST) + 1.0) * dt / 0.01
		var keep := pow(T.WHEEL_GROUND_KEEP, steps)
		for i in bottomed:
			var p: Vector3 = car._hit_pos[i]
			var n: Vector3 = car._hit_n[i]
			var r := p - com
			var vrel := state.linear_velocity + state.angular_velocity.cross(r)
			var vn := vrel.dot(n)
			if vn < 0.0:
				var k := state.inverse_mass + n.dot((state.inverse_inertia_tensor * r.cross(n)).cross(r))
				if k > 1e-9:
					state.apply_impulse(n * ((keep - 1.0) * vn / k), p - xf.origin)
		if push > 0.0:
			state.transform = Transform3D(b, xf.origin + up * minf(push, 0.5))

	# --- SpeedFest extras: nitro, boost pads, cruise and reactor pads ---
	var fwd_g := fwd - car._ground_n * fwd.dot(car._ground_n) if car._grounded >= 2 else fwd
	fwd_g = fwd_g.normalized() if fwd_g.length_squared() > 1e-6 else fwd
	car._nitro_active = false
	if want_nitro and car._nitro > 0.0 and not model.reverse:
		car._nitro_active = true
		car._nitro = maxf(car._nitro - dt / float(car.params["nitro_time"]), 0.0)
		state.apply_central_force(fwd_g * m * float(car.params["nitro_accel"]))
	if car._boost_time > 0.0:
		car._boost_time -= dt
		var bd := car._boost_dir
		if car._grounded >= 2:
			bd = bd - car._ground_n * bd.dot(car._ground_n)
			bd = bd.normalized() if bd.length_squared() > 1e-4 else fwd
		var fade := 1.0 - clampf((lv.dot(bd) - Car.BOOST_FADE_FROM) / (Car.BOOST_SPEED_CAP - Car.BOOST_FADE_FROM), 0.0, 1.0)
		state.apply_central_force(bd * m * car._boost_accel * fade)
	if cruising and car._grounded >= 2:
		var fc := clampf((car._cruise_speed - car._fwd_speed) * m / 0.3, -m * 15.0, m * 15.0)
		state.apply_central_force(fwd_g * fc)
	if float(car._fx["reactor"]) > 0.0:
		if car._grounded == 0:
			state.apply_central_force(Vector3.UP * m * G * model.gravity_coef * REACTOR_LIFT + fwd * m * REACTOR_PUSH)
		else:
			state.apply_central_force(fwd_g * m * REACTOR_PUSH)
	var sp2 := state.linear_velocity.length_squared()
	if sp2 > MAX_SPEED_HARD * MAX_SPEED_HARD:
		state.linear_velocity = state.linear_velocity * (MAX_SPEED_HARD / sqrt(sp2))
	if car.frozen_controls and car._grounded >= 2:
		state.linear_velocity = up * state.linear_velocity.dot(up)
		state.angular_velocity = state.angular_velocity * 0.6

	# --- state for the HUD, sound, visuals, net and the AutoDriver ---
	var v_abs := absf(car._fwd_speed)
	car._reversing = model.reverse and car._fwd_speed < 0.5
	car._braking = (brake > 0.1 and v_abs > 0.5 and not model.reverse) or model.brake_now > 0.5
	car._steer_angle = -model.steer * deg_to_rad(T.lin(VIS_STEER, v_abs * 3.6))
	var lv_g := lv - car._ground_n * lv.dot(car._ground_n)
	var slip := 0.0
	if car._grounded >= 2 and lv_g.length() > 3.0:
		slip = atan2(lv_g.dot(b.x), absf(lv_g.dot(fwd_g)))
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

	# --- landings, wall hits, self-righting (SpeedFest's respawn-free recovery when stuck) ---
	if car._grounded == 0:
		car._air_time += dt
	else:
		if was_grounded == 0 and car._air_time > 0.25:
			car.landed.emit(absf(car._prev_vel.dot(car._ground_n)))
		car._air_time = 0.0
	var lost := (car._prev_vel - state.linear_velocity).length()
	if lost > 2.0 and state.get_contact_count() > 0:
		for ci in state.get_contact_count():
			if absf(state.get_contact_local_normal(ci).dot(car._ground_n)) < 0.5:
				car.wall_hit.emit(lost)
				break
	car._prev_vel = state.linear_velocity
	if up.dot(Vector3.UP) < 0.3 and car._grounded < 2 and speed < 3.0:
		car._upside_time += dt
	else:
		car._upside_time = 0.0
	if car._upside_time > 1.5 and car._righting <= 0.0:
		car._righting = 1.0
	if car._righting > 0.0:
		car._righting -= dt
		if up.dot(Vector3.UP) > 0.92:
			car._righting = 0.0
		else:
			if up.dot(Vector3.UP) < 0.5 and car._righting > 0.4:
				state.apply_central_force(Vector3.UP * m * G * model.gravity_coef * 1.2)
			var axis := up.cross(Vector3.UP)
			if axis.length_squared() < 1e-4:
				axis = fwd
			state.apply_torque(axis.normalized() * car.inertia.z * 12.0 - state.angular_velocity * car.inertia.z * 4.0)


## TMNF surface id under wheel i, from the track's ground patches and the weather's puddles. Rally
## tyres (Car.params "loose_grip") keep part of the asphalt values on loose ground.
func _surface_at(i: int, p: Vector3) -> int:
	var s := car.surface
	if s == null:
		return T.Surface.ASPHALT
	var water := s.water_at(p)
	car._water[i] = water
	var kind := 0
	if not s.patches.is_empty():
		kind = s.kind_at(p)
	car._ground[i] = kind
	if kind > 0 and car._loose_grip > 0.5 and TrackSurface.KIND_LOOSE[kind]:
		return T.Surface.DIRT_ROAD
	if kind == 0 and water > 0.35:
		return T.Surface.WET_PAVEMENT
	return SURFACE_OF_KIND[clampi(kind, 0, SURFACE_OF_KIND.size() - 1)]


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
