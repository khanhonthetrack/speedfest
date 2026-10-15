class_name Car
extends RigidBody3D
## Arcade raycast vehicle (Jolt, 60 Hz). API fixed by docs/ARCHITECTURE.md "Car".
##
## Four suspension rays (mask 1) at CarDefs.wheel_positions(); spring + damper + bump stop +
## anti-roll per axle. Tires: slip-angle lateral grip with a breakaway curve, friction circle,
## drive/brake/handbrake, rolling resistance. Engine: constant-power model with a torque-curve
## shape (Tuning.drive_force), 6 gears + reverse, automatic gearbox. Aero downforce, a "stick"
## force along the road normal on steep/inverted road (loops), air auto-levelling, anti-flip and
## self-righting. All forces are applied in _integrate_forces.
## See docs/modules/physics.md for the model and tuning knobs.

signal landed(impact_speed: float)       # vertical speed (m/s) when touching down after > 0.25 s air
signal wall_hit(strength: float)         # speed (m/s) lost into a wall contact (>= 2 m/s)

const SHIFT_TIME := 0.09
const SHIFT_CUT := 0.35                  # torque fraction during a shift
const SHIFT_HOLD := 0.35                 # minimum time between shifts
const REVERSE_DELAY := 0.12              # brake held this long at a standstill engages reverse
const SUSP_UP := 0.30                    # ray origin above the wheel center
const SUSP_DROOP := 0.20                 # max droop below rest
const DROOP_SOFT := 0.45                 # spring rate factor while extending below rest
const BUMP_START := 0.085                # compression where the bump stop starts
const BUMP_MULT := 6.0                  # bump-stop stiffness relative to the spring
const BUMP_DAMP := 1.0                   # extra compression damping inside the bump-stop zone (x damper)
const LAND_REBOUND_TIME := 0.35          # after a touchdown, cap the rebound speed for this long
const LAND_REBOUND_MAX := 0.6            # m/s away from the ground
const LAND_ABSORB := 0.7                 # fraction of the touchdown speed into the ground removed
const MAX_WHEEL_G := 28.0                # cap on a single wheel's suspension force (in corner weights)
const STICK_ACCEL := 13.0                # extra road-normal pull on steep/inverted road at speed
const STICK_STEEP := 0.6                 # 1 - normal.y where the stick force is at full strength
const AIR_LEVEL := 3.0                   # air auto-levelling strength (rad/s^2 per rad)
const AIR_DAMP := 1.6                    # air pitch/roll rate damping (1/s)
const AIR_STEER := 2.5                   # air yaw response (1/s)
const AIR_YAW_RATE := 1.0                # max air yaw rate from steering (rad/s)
const NITRO_REFILL := 1.0 / 28.0         # tank fraction per second while driving
const DRIFT_MAX_DEG := 38.0              # slip angle where the drift stabilizer starts
const DRIFT_STAB := 10.0                 # stabilizer strength (rad/s^2 per rad over the limit)
const DRIFT_SPEED_KEEP := 0.55           # fraction of drift scrub given back as forward push
const BODY_FRICTION := 0.0
const ROLL_DAMP := 2.5                   # roll-rate damping relative to the road's twist (1/s)
const TWIST_SMOOTH := 0.05               # smoothing time of the measured road twist rate (s)
const ROAD_ALIGN := 6.0                  # gentle torque aligning the car with the road normal (twists, wall rides)
const FRICTION_CIRCLE := 0.5            # how much longitudinal force eats lateral grip (0..1)

var config: Dictionary = {}
var visual: CarVisual
var controls := {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "handbrake": false, "nitro": false}
var frozen_controls := false

## Resolved physics params (Tuning.physics_params). Public for tests/debug.
var params: Dictionary = {}
var car_id: String = "kaze"

var _wheel_pos: Array[Vector3] = []
var _radius := 0.32
var _wheelbase := 2.56
var _preload := PackedFloat32Array([0, 0, 0, 0])
var _k := PackedFloat32Array([0, 0, 0, 0])
var _c := PackedFloat32Array([0, 0, 0, 0])
var _corner_mass := PackedFloat32Array([0, 0, 0, 0])
var _k_arb := PackedFloat32Array([0, 0])

var _contact: Array[bool] = [false, false, false, false]
var _comp := PackedFloat32Array([0, 0, 0, 0])          # +up compression (m), = visual offset
var _vis_offset := PackedFloat32Array([0, 0, 0, 0])
var _load := PackedFloat32Array([0, 0, 0, 0])
var _hit_pos: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _hit_n: Array[Vector3] = [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
var _spin := PackedFloat32Array([0, 0, 0, 0])
var _spin_vel := PackedFloat32Array([0, 0, 0, 0])
var _queries: Array[PhysicsRayQueryParameters3D] = []

var _gear := 1
var _shift_timer := 0.0
var _shift_hold := 0.0
var _rpm := 0.0
var _steer_angle := 0.0
var _nitro := 1.0
var _nitro_active := false
var _boost_dir := Vector3.ZERO
var _boost_accel := 0.0
var _boost_time := 0.0
var _drift := 0.0
var _slip_angle := 0.0
var _grounded := 0
var _air_time := 0.0
var _upside_time := 0.0
var _righting := 0.0
var _hb_blend := 0.0
var _reversing := false
var _braking := false
var _fwd_speed := 0.0
var _wheelspin := 0.0
var _pending_teleport := false
var _pending_xform := Transform3D.IDENTITY
var _pending_vel := Vector3.ZERO
var _prev_vel := Vector3.ZERO
var _ground_n := Vector3.UP
var _land_timer := 0.0
var _prev_ground_n := Vector3.UP
var _ground_roll_rate := 0.0
var _intent := 0.0
var _rev_timer := 0.0
var _force := PackedFloat32Array([0, 0, 0, 0])
var _vis_spin_arr: Array = [0.0, 0.0, 0.0, 0.0]
var _vis_susp_arr: Array = [0.0, 0.0, 0.0, 0.0]


static func create(p_config: Dictionary) -> Car:
	var car := Car.new()
	car.config = CarDefs.sanitize_config(p_config)
	car._setup()
	car.visual = CarVisual.new()
	car.visual.name = "Visual"
	car.add_child(car.visual)
	car.visual.build(car.car_id, car.config["style"])
	return car


func _setup() -> void:
	car_id = String(config["car"])
	params = Tuning.physics_params(car_id, config["tuning"])
	var g := CarDefs.geometry(car_id)
	_radius = g["wheel_radius"]
	_wheelbase = g["wheelbase"]
	_wheel_pos = CarDefs.wheel_positions(car_id)
	var m: float = params["mass"]
	mass = m
	collision_layer = 2
	collision_mask = 1
	continuous_cd = true
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.4
	var mat := PhysicsMaterial.new()
	mat.friction = BODY_FRICTION
	mat.bounce = 0.0
	physics_material_override = mat
	var wf: float = params["weight_front"]
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, float(params["cg_height"]), _wheelbase * (0.5 - wf))
	var length: float = g["length"]
	var width: float = g["width"]
	var height: float = g["height"]
	inertia = Vector3(m * (1.0 + length * length) / 12.0 * 1.1,
		m * (width * width + length * length) / 12.0 * 1.15,
		m * (width * width + 1.0) / 12.0 * 1.2)
	# collision: a floor box over the wheelbase, raised nose/tail boxes (approach/departure angles,
	# so overhangs don't scrape in loops or on ramps) and a cabin. All above the contact patches.
	var y0: float = -_radius + float(g["ground_clearance"]) + 0.07
	var y_belt: float = y0 + (height - float(g["ground_clearance"])) * 0.5
	var y1: float = -_radius + height
	var core_len := _wheelbase + 0.5
	var over_len := maxf((length * 0.97 - core_len) * 0.5, 0.05)
	var y_over := y0 + 0.2
	_add_box(Vector3(width * 0.94, y_belt - y0, core_len), Vector3(0, (y0 + y_belt) * 0.5, 0))
	for sgn in [-1.0, 1.0]:
		_add_box(Vector3(width * 0.9, y_belt - y_over + 0.1, over_len),
			Vector3(0, (y_over + y_belt + 0.1) * 0.5, sgn * (core_len + over_len) * 0.5))
	_add_box(Vector3(width * 0.78, y1 - y_belt, length * 0.5), Vector3(0, (y_belt + y1) * 0.5, length * 0.03))
	# suspension constants
	var omega := TAU * float(params["spring_hz"])
	for i in 4:
		var share := wf if i < 2 else 1.0 - wf
		var cm := m * share * 0.5
		_corner_mass[i] = cm
		_preload[i] = cm * CarPhysicsDefs.GRAVITY
		_k[i] = cm * omega * omega
		_c[i] = 2.0 * float(params["damping"]) * cm * omega
	_k_arb[0] = _k[0] * float(params["anti_roll"])
	_k_arb[1] = _k[2] * float(params["anti_roll"])
	_queries.clear()
	for i in 4:
		var q := PhysicsRayQueryParameters3D.new()
		q.collision_mask = 1
		q.collide_with_areas = false
		q.collide_with_bodies = true
		q.hit_back_faces = false
		_queries.append(q)


func _add_box(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	add_child(cs)


func _ready() -> void:
	if params.is_empty():
		# created without Car.create() (e.g. instanced directly)
		config = CarDefs.sanitize_config(config)
		_setup()
	for q in _queries:
		q.exclude = [get_rid()]


# --- public API -----------------------------------------------------------------------------

func get_speed_kmh() -> float:
	return linear_velocity.dot(-global_transform.basis.z) * 3.6


func get_rpm_ratio() -> float:
	return _rpm


func get_gear() -> int:
	if _reversing:
		return -1
	if frozen_controls or (absf(_fwd_speed) < 0.3 and float(controls.get("throttle", 0.0)) < 0.05):
		return 0
	return _gear


func get_nitro_amount() -> float:
	return _nitro


func is_nitro_active() -> bool:
	return _nitro_active


func get_drift_amount() -> float:
	return _drift


func is_grounded() -> bool:
	return _grounded >= 2


func get_flags() -> int:
	var f := 0
	if _braking:
		f |= 1
	if _nitro_active:
		f |= 2
	if _drift > 0.35:
		f |= 4
	if _reversing:
		f |= 8
	if is_grounded():
		f |= 16
	return f


func get_net_state() -> Dictionary:
	var q := global_transform.basis.get_rotation_quaternion()
	var p := global_position
	var v := linear_velocity
	return {"p": [p.x, p.y, p.z], "q": [q.x, q.y, q.z, q.w], "v": [v.x, v.y, v.z],
		"st": float(controls.get("steer", 0.0)), "rpm": _rpm, "fl": get_flags()}


func teleport(xform: Transform3D, p_linear_velocity: Vector3 = Vector3.ZERO) -> void:
	_pending_teleport = true
	_pending_xform = xform.orthonormalized()
	_pending_vel = p_linear_velocity
	if is_inside_tree():
		global_transform = _pending_xform
	else:
		transform = _pending_xform
	linear_velocity = p_linear_velocity
	angular_velocity = Vector3.ZERO
	_reset_dynamics(p_linear_velocity)
	if is_inside_tree():
		reset_physics_interpolation()


func refill_nitro() -> void:
	_nitro = 1.0


func apply_boost(direction: Vector3, accel: float, duration: float) -> void:
	if direction.length_squared() < 1e-6:
		return
	_boost_dir = direction.normalized()
	_boost_accel = maxf(accel, 0.0)
	_boost_time = maxf(_boost_time, duration)


# --- extra API (documented in docs/modules/physics.md) --------------------------------------

## Steering wheel angle actually applied (rad, + = right turn).
func get_steer_angle() -> float:
	return _steer_angle


func get_air_time() -> float:
	return _air_time


func get_wheel_contact(i: int) -> bool:
	return _contact[i]


## Wheelspin / tire-slip intensity 0..1 (for smoke, squeal).
func get_wheelspin() -> float:
	return _wheelspin


func get_slip_angle() -> float:
	return _slip_angle


func is_boosting() -> bool:
	return _boost_time > 0.0


## Max steering angle (rad) the car allows at speed v (m/s). Used by AutoDriver.
func max_steer_at(v: float) -> float:
	var smax: float = params["steer_max"]
	v = absf(v)
	if v < 4.0:
		return smax
	var m: float = params["mass"]
	var a_lat := float(params["grip"]) * CarPhysicsDefs.GRAVITY * (1.0 + float(params["downforce"]) * v * v / (m * CarPhysicsDefs.GRAVITY))
	var ang := atan(_wheelbase * a_lat / (v * v)) + float(params["slip_peak"]) * 1.1
	return clampf(ang, deg_to_rad(4.0), smax)


func drive_awd_flag() -> bool:
	return String(params.get("drive", "rwd")) == "awd"


func get_wheelbase() -> float:
	return _wheelbase


# --- simulation -----------------------------------------------------------------------------

func _reset_dynamics(v: Vector3) -> void:
	for i in 4:
		_contact[i] = false
		_comp[i] = 0.0
		_vis_offset[i] = 0.0
		_load[i] = 0.0
		_spin_vel[i] = 0.0
	_steer_angle = 0.0
	_boost_time = 0.0
	_drift = 0.0
	_slip_angle = 0.0
	_air_time = 0.0
	_upside_time = 0.0
	_land_timer = 0.0
	_righting = 0.0
	_hb_blend = 0.0
	_intent = 0.0
	_reversing = false
	_rev_timer = 0.0
	_braking = false
	_shift_timer = 0.0
	_shift_hold = 0.0
	_nitro_active = false
	_wheelspin = 0.0
	_prev_vel = v
	_fwd_speed = v.dot(-_pending_xform.basis.z)
	_gear = Tuning.best_gear(params, absf(_fwd_speed), 1) if not params.is_empty() else 1
	_rpm = Tuning.rpm_ratio(params, _gear, _fwd_speed) if not params.is_empty() else 0.0


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_teleport:
		_pending_teleport = false
		state.transform = _pending_xform
		state.linear_velocity = _pending_vel
		state.angular_velocity = Vector3.ZERO
		return
	var dt := state.step
	var xf := state.transform
	var b := xf.basis
	var up := b.y
	var fwd := -b.z
	var right := b.x
	var lv := state.linear_velocity
	var av := state.angular_velocity
	var m: float = params["mass"]
	var com := xf.origin + state.center_of_mass
	var speed := lv.length()
	_fwd_speed = lv.dot(fwd)
	var throttle := clampf(float(controls.get("throttle", 0.0)), 0.0, 1.0)
	var brake := clampf(float(controls.get("brake", 0.0)), 0.0, 1.0)
	var steer_in := clampf(float(controls.get("steer", 0.0)), -1.0, 1.0)
	var handbrake := bool(controls.get("handbrake", false))
	var want_nitro := bool(controls.get("nitro", false))
	if frozen_controls:
		steer_in = 0.0
		handbrake = false
		want_nitro = false

	# --- suspension rays ---
	var space := state.get_space_state()
	var ray_len := SUSP_UP + SUSP_DROOP + _radius
	var was_grounded := _grounded
	_grounded = 0
	var n_sum := Vector3.ZERO
	for i in 4:
		var origin := xf * (_wheel_pos[i] + Vector3(0.0, SUSP_UP, 0.0))
		var q := _queries[i]
		q.from = origin
		q.to = origin - up * ray_len
		var hit := space.intersect_ray(q)
		_contact[i] = false
		if not hit.is_empty():
			var n: Vector3 = hit["normal"]
			if n.dot(up) > 0.35:
				var dist := origin.distance_to(hit["position"])
				_comp[i] = SUSP_UP - (dist - _radius)
				_hit_pos[i] = hit["position"]
				_hit_n[i] = n
				_contact[i] = true
				_grounded += 1
				n_sum += n
		if not _contact[i]:
			_comp[i] = -SUSP_DROOP
	_prev_ground_n = _ground_n
	_ground_n = n_sum.normalized() if _grounded > 0 else up
	# touchdown after real air time: soak up most of the impact (arcade, no bounce)
	if _grounded > 0 and was_grounded == 0 and _air_time > 0.2:
		var vn := lv.dot(_ground_n)
		if vn < -2.0:
			lv -= _ground_n * (vn + 2.0) * LAND_ABSORB
			var pr0 := av - up * av.dot(up)
			av -= pr0 * 0.6
			state.linear_velocity = lv
			state.angular_velocity = av
			_land_timer = LAND_REBOUND_TIME
	if _land_timer > 0.0:
		_land_timer -= dt
		if _grounded > 0:
			var vn2 := lv.dot(_ground_n)
			if vn2 > LAND_REBOUND_MAX:
				lv -= _ground_n * (vn2 - LAND_REBOUND_MAX)
				state.linear_velocity = lv

	# suspension forces (+ anti-roll)
	var force := _force
	for i in 4:
		force[i] = 0.0
	for i in 4:
		if not _contact[i]:
			continue
		var rel := _hit_pos[i] - com
		var vp := lv + av.cross(rel)
		var comp_vel := -vp.dot(up)
		var c := _comp[i]
		# droop-soft spring: extending side has a lower rate, so the wheel follows twisted road
		# (wall-ride entries/exits) further before unloading. Static height is unchanged.
		var f := _preload[i] + _k[i] * (c if c >= 0.0 else c * DROOP_SOFT) + _c[i] * comp_vel
		if c > BUMP_START:
			var over := c - BUMP_START
			f += _k[i] * BUMP_MULT * over + _c[i] * BUMP_DAMP * maxf(comp_vel, 0.0)
		force[i] = f
	# anti-roll bars react to the AVERAGE roll of both axles: they resist body roll but not warp
	# (front and rear rolled opposite ways on a twisting road), so diagonals stay loaded
	var roll_f := _comp[0] - _comp[1]
	var roll_r := _comp[2] - _comp[3]
	var roll_avg := (roll_f + roll_r) * 0.5 if (_contact[0] or _contact[1]) and (_contact[2] or _contact[3]) else (roll_f if _contact[0] or _contact[1] else roll_r)
	for axle in 2:
		var l := axle * 2
		var r := l + 1
		if _contact[l] or _contact[r]:
			force[l] += _k_arb[axle] * roll_avg
			force[r] -= _k_arb[axle] * roll_avg
	var total_load := 0.0
	for i in 4:
		if not _contact[i]:
			_load[i] = 0.0
			continue
		var f := clampf(force[i], 0.0, _preload[i] * MAX_WHEEL_G)
		_load[i] = f
		total_load += f
		state.apply_force(up * f, _hit_pos[i] - xf.origin)

	# --- steering ---
	var v_abs := absf(_fwd_speed)
	var max_angle := max_steer_at(v_abs)
	if handbrake or _drift > 0.3:
		max_angle = lerpf(max_angle, float(params["steer_max"]), 0.75)
	var target_angle := steer_in * max_angle
	var rate := 5.0 * float(params["steer_speed"])
	_steer_angle = move_toward(_steer_angle, target_angle, rate * dt)

	# --- gearbox / engine ---
	_shift_timer = maxf(_shift_timer - dt, 0.0)
	_shift_hold = maxf(_shift_hold - dt, 0.0)
	if frozen_controls:
		_reversing = false
	elif _reversing:
		if throttle > 0.1 and _fwd_speed > -1.0:
			_reversing = false
	elif brake > 0.5 and throttle < 0.1 and _fwd_speed < 1.0 and _grounded >= 2:
		# a deliberate brake hold at (near) standstill engages reverse
		_rev_timer += dt
		if _rev_timer >= REVERSE_DELAY:
			_reversing = true
	else:
		_rev_timer = 0.0
	if not _reversing and _shift_hold <= 0.0:
		var ng := Tuning.best_gear(params, maxf(_fwd_speed, 0.0), _gear)
		if ng != _gear:
			if ng > _gear:
				_shift_timer = SHIFT_TIME
			_gear = ng
			_shift_hold = SHIFT_HOLD
	var drive_total := 0.0
	var brake_in := brake
	if frozen_controls:
		brake_in = 0.0
	elif _reversing:
		drive_total = -brake * m * 6.5 * (1.0 - clampf(-_fwd_speed / float(params["reverse_top"]), 0.0, 1.0))
		brake_in = throttle
	else:
		drive_total = throttle * Tuning.drive_force(params, _gear, maxf(_fwd_speed, 0.0))
		if _shift_timer > 0.0:
			drive_total *= SHIFT_CUT
		if _fwd_speed < -1.0 and throttle > 0.1:
			# rolling backwards while asking for forward: brake first
			brake_in = maxf(brake_in, throttle)
			drive_total = 0.0
	_braking = (brake_in > 0.1 and absf(_fwd_speed) > 0.5) or (handbrake and v_abs > 1.0)

	# --- handbrake blend ---
	if handbrake:
		_hb_blend = move_toward(_hb_blend, 1.0, dt / 0.08)
	else:
		_hb_blend = move_toward(_hb_blend, 0.0, dt / 0.45)

	# --- drift intent: handbrake, or heavy throttle (RWD power oversteer). Without intent the
	# rear's sliding grip rises above the front's so a slide straightens itself out.
	var intent_t := _hb_blend
	if not drive_awd_flag():
		intent_t = maxf(intent_t, clampf((throttle - 0.55) * 2.5, 0.0, 1.0) * clampf(_drift * 2.0, 0.0, 1.0))
	else:
		intent_t = maxf(intent_t, clampf((throttle - 0.7) * 2.0, 0.0, 1.0) * clampf(_drift * 2.0, 0.0, 1.0) * 0.6)
	_intent = move_toward(_intent, intent_t, dt * (6.0 if intent_t > _intent else 1.5))

	# --- body slip angle / drift ---
	var lv_g := lv - _ground_n * lv.dot(_ground_n)
	var slip := 0.0
	if _grounded >= 2 and lv_g.length() > 6.0:
		var fwd_g := (fwd - _ground_n * fwd.dot(_ground_n)).normalized()
		var right_g := fwd_g.cross(_ground_n)
		slip = atan2(lv_g.dot(right_g), absf(lv_g.dot(fwd_g)))
	_slip_angle = slip
	var drift_target := 0.0
	if _grounded >= 2 and speed > 8.0:
		drift_target = clampf((absf(slip) - deg_to_rad(7.0)) / deg_to_rad(22.0), 0.0, 1.0)
	_drift = move_toward(_drift, drift_target, dt * 4.0)

	# --- tires ---
	var drive_awd := String(params["drive"]) == "awd"
	var driven_n := 0
	for i in 4:
		if _contact[i] and (i >= 2 or drive_awd):
			driven_n += 1
	var grip: float = params["grip"]
	var grip_long: float = params["grip_long"]
	var traction: float = params["traction"]
	var peak: float = params["slip_peak"]
	var spin_assist := clampf((absf(slip) - deg_to_rad(50.0)) / deg_to_rad(30.0), 0.0, 1.0)
	var scrub := 0.0
	var spin_total := 0.0
	for i in 4:
		if not _contact[i]:
			continue
		var front := i < 2
		var n := _hit_n[i]
		var wf := fwd
		if front:
			wf = fwd.rotated(up, -_steer_angle)
		wf = (wf - n * wf.dot(n)).normalized()
		var ws := wf.cross(n)
		var rel := _hit_pos[i] - com
		var vp := lv + av.cross(rel)
		var v_long := vp.dot(wf)
		var v_lat := vp.dot(ws)
		var nload := _load[i]
		var cm := _corner_mass[i]
		# longitudinal
		var f_long := 0.0
		if i >= 2 or drive_awd:
			if driven_n > 0:
				var share := 1.0 / driven_n
				if drive_awd:
					var fronts := int(_contact[0]) + int(_contact[1])
					var rears := int(_contact[2]) + int(_contact[3])
					if fronts > 0 and rears > 0:
						share = (0.4 / fronts) if front else (0.6 / rears)
				f_long += drive_total * share
		var long_cap := grip_long * nload
		var drive_cap := traction * nload
		var spin_excess := 0.0
		if absf(f_long) > drive_cap:
			spin_excess = (absf(f_long) - drive_cap) / maxf(drive_cap, 1.0)
			f_long = signf(f_long) * drive_cap
		var bf := 0.0
		if brake_in > 0.0:
			bf += brake_in * float(params["brake_decel"]) * m * (nload / maxf(total_load, 1.0))
		if handbrake and not front:
			bf += 0.55 * CarPhysicsDefs.GRAVITY * cm * 2.0
		if throttle < 0.05 and not _reversing and not frozen_controls:
			bf += 0.9 * cm  # engine braking / coast drag
		if bf > 0.0:
			bf = minf(minf(bf, long_cap), absf(v_long) * cm / dt * 0.8)
			f_long -= signf(v_long) * bf
		# lateral (slip-angle curve)
		var mu := grip
		var slide: float = params["front_slide"]
		if not front:
			mu *= float(params["rear_grip_bias"])
			slide = lerpf(minf(float(params["front_slide"]) + 0.14, 1.0), float(params["rear_slide"]), _intent)
			mu *= lerpf(1.0, 0.42, _hb_blend)
			mu *= 1.0 + spin_assist * 0.6
			if _drift > 0.2 and throttle > 0.3 and not handbrake:
				mu *= lerpf(1.0, 0.92, float(params["drift_assist"]) * _drift)
		var alpha := atan2(v_lat, maxf(absf(v_long), 2.5))
		var s := absf(alpha) / peak
		var ratio := s if s < 1.0 else lerpf(1.0, slide, clampf((s - 1.0) / 2.5, 0.0, 1.0))
		var lat_cap := mu * nload
		var lr := f_long / maxf(long_cap, 1.0)
		lat_cap *= sqrt(maxf(1.0 - FRICTION_CIRCLE * lr * lr, 0.05))
		var f_lat := -signf(v_lat) * ratio * lat_cap
		var cancel := absf(v_lat) * cm / dt * 0.9
		if absf(f_lat) > cancel:
			f_lat = signf(f_lat) * cancel
		if s > 1.0:
			scrub += absf(f_lat) * (1.0 - 1.0 / s)
		var app := _hit_pos[i] + up * (_radius * 0.75) - xf.origin
		state.apply_force(wf * f_long + ws * f_lat, app)
		# wheel spin for visuals
		var sv := v_long / _radius
		if handbrake and not front:
			sv = 0.0
		elif spin_excess > 0.0:
			sv += signf(f_long) * minf(spin_excess, 2.0) * 25.0
		_spin_vel[i] = sv
		spin_total += clampf(spin_excess, 0.0, 1.0) + clampf(s - 1.0, 0.0, 2.0) * 0.5
	_wheelspin = move_toward(_wheelspin, clampf(spin_total / 4.0, 0.0, 1.0), dt * 5.0)
	for i in 4:
		if not _contact[i]:
			if (i >= 2 or drive_awd) and throttle > 0.1:
				_spin_vel[i] = move_toward(_spin_vel[i], 120.0 * throttle, 200.0 * dt)
			else:
				_spin_vel[i] *= 0.995
		_spin[i] = fmod(_spin[i] + _spin_vel[i] * dt, TAU)

	# --- drift speed keeping: give back part of the scrub as forward push ---
	if _drift > 0.15 and throttle > 0.3 and _grounded >= 3 and lv_g.length() > 8.0:
		var keep := minf(scrub * DRIFT_SPEED_KEEP * _drift * float(params["drift_assist"]), m * 6.0)
		state.apply_central_force(lv_g.normalized() * keep)

	# --- drift stabilizer: bound the body slip angle (no endless spins) ---
	if _grounded >= 2 and lv_g.length() > 6.0 and not _reversing:
		var fwd_s := (fwd - _ground_n * fwd.dot(_ground_n)).normalized()
		var right_s := fwd_s.cross(_ground_n)
		var full := atan2(lv_g.dot(right_s), lv_g.dot(fwd_s))
		var a := absf(full)
		var lim := deg_to_rad(DRIFT_MAX_DEG)
		if a > lim and a < deg_to_rad(150.0):
			var sgn := signf(full)
			var yaw := av.dot(up)
			# slip > 0: velocity right of the nose -> turn the nose right (negative yaw)
			var t_yaw := -sgn * (a - lim) * DRIFT_STAB * (0.5 if handbrake else 1.0)
			if yaw * sgn > 0.0:
				t_yaw -= yaw * 5.0
			state.apply_torque(up * t_yaw * inertia.y)

	# --- aero, drag, rolling ---
	if speed > 0.1:
		var drag := float(params["drag"]) * speed * speed
		state.apply_central_force(-lv / speed * drag)
	if _grounded > 0:
		var rr := minf(float(params["rolling"]), v_abs * m / dt * 0.2)
		var fwd_g2 := (fwd - _ground_n * fwd.dot(_ground_n)).normalized()
		state.apply_central_force(-fwd_g2 * signf(_fwd_speed) * rr)
		var df := float(params["downforce"]) * _fwd_speed * _fwd_speed * (float(_grounded) / 4.0)
		state.apply_central_force(-up * df)
		# stick: pull along the road normal on steep or inverted road at speed (loops, walls)
		if _grounded >= 2:
			var steep := clampf((1.0 - _ground_n.dot(Vector3.UP)) / STICK_STEEP, 0.0, 1.0)
			var spd := clampf((speed - 12.0) / 15.0, 0.0, 1.0)
			if steep > 0.0 and spd > 0.0:
				state.apply_central_force(-_ground_n * m * STICK_ACCEL * steep * spd)

	# --- nitro & boost ---
	_nitro_active = false
	if want_nitro and _nitro > 0.0 and not _reversing:
		_nitro_active = true
		_nitro = maxf(_nitro - dt / float(params["nitro_time"]), 0.0)
		var nd := fwd
		if _grounded >= 2:
			nd = (fwd - _ground_n * fwd.dot(_ground_n)).normalized()
		state.apply_central_force(nd * m * float(params["nitro_accel"]))
	elif _grounded >= 2 and speed > 8.0 and not frozen_controls:
		_nitro = minf(_nitro + dt * NITRO_REFILL, 1.0)
	if _boost_time > 0.0:
		_boost_time -= dt
		state.apply_central_force(_boost_dir * m * _boost_accel)

	# --- air control & stability ---
	if _grounded == 0:
		_air_time += dt
		var pr := av - up * av.dot(up)
		state.apply_torque(-pr * AIR_DAMP * inertia.x)
		if _air_time > 0.2:
			# roll toward upright, pitch toward the flight direction (clamped)
			var up_t := Vector3.UP - fwd * Vector3.UP.dot(fwd)
			if up_t.length_squared() > 1e-4:
				state.apply_torque(up.cross(up_t.normalized()) * AIR_LEVEL * inertia.z)
			if speed > 8.0:
				var vdir := lv / speed
				var pitch_v := clampf(asin(clampf(vdir.y, -1.0, 1.0)), deg_to_rad(-30.0), deg_to_rad(25.0))
				var hz := Vector3(fwd.x, 0.0, fwd.z)
				if hz.length_squared() > 1e-4:
					hz = hz.normalized()
					var f_t := (hz * cos(pitch_v) + Vector3.UP * sin(pitch_v)).normalized()
					state.apply_torque(fwd.cross(f_t) * AIR_LEVEL * 0.7 * inertia.x)
		# light air steering: drive the yaw rate toward steer * AIR_YAW_RATE (also damps spins)
		var yaw_rate := av.dot(up)
		state.apply_torque(up * (steer_in * AIR_YAW_RATE - yaw_rate) * AIR_STEER * inertia.y)
	else:
		if was_grounded == 0 and _air_time > 0.25:
			landed.emit(absf(_prev_vel.dot(_ground_n)))
		_air_time = 0.0
		# anti-flip: damp the roll rate RELATIVE to the road's own twist (so the car follows wall-ride
		# entries/exits), gently align with the road, and push back hard when rolled far off it
		var gr := 0.0
		if was_grounded > 0 and _grounded >= 2:
			gr = _prev_ground_n.cross(_ground_n).dot(fwd) / dt
		# triangle normals step every meter: smooth the road's twist rate before using it
		_ground_roll_rate = lerpf(_ground_roll_rate, gr, clampf(dt / TWIST_SMOOTH, 0.0, 1.0))
		var roll_rate := av.dot(fwd) - _ground_roll_rate
		state.apply_torque(-fwd * roll_rate * inertia.z * ROLL_DAMP)
		var tilt := up.cross(_ground_n)
		if _grounded >= 2:
			state.apply_torque(tilt * inertia.z * ROAD_ALIGN)
		if up.dot(_ground_n) < cos(deg_to_rad(25.0)):
			state.apply_torque(tilt * inertia.z * 9.0)
		if frozen_controls:
			var lv_f := up * lv.dot(up)
			state.linear_velocity = lv_f
			state.angular_velocity = up * 0.0 + (av - up * av.dot(up)) * 0.6

	# --- self-righting when resting upside down / on the side ---
	if up.dot(Vector3.UP) < 0.3 and _grounded < 2 and speed < 3.0:
		_upside_time += dt
	else:
		_upside_time = 0.0
	if _upside_time > 1.5 and _righting <= 0.0:
		_righting = 1.0
	if _righting > 0.0:
		_righting -= dt
		if up.dot(Vector3.UP) > 0.92:
			_righting = 0.0
		else:
			if up.dot(Vector3.UP) < 0.5 and _righting > 0.4:
				state.apply_central_force(Vector3.UP * m * CarPhysicsDefs.GRAVITY * 1.2)
			var axis := up.cross(Vector3.UP)
			if axis.length_squared() < 1e-4:
				axis = fwd
			state.apply_torque(axis.normalized() * inertia.z * 12.0 - av * inertia.z * 4.0)

	# --- wall hits ---
	var lost := (_prev_vel - lv).length()
	if state.get_contact_count() > 0 and lost > 2.0 and _grounded > 0:
		for ci in state.get_contact_count():
			var cn := state.get_contact_local_normal(ci)
			if absf(cn.dot(_ground_n)) < 0.5:
				wall_hit.emit(lost)
				break
	_prev_vel = state.linear_velocity

	# --- rpm ---
	var rpm_target := 0.0
	if frozen_controls or (v_abs < 1.0 and not _reversing):
		rpm_target = 0.12 + throttle * 0.8
	else:
		rpm_target = maxf(Tuning.rpm_ratio(params, -1 if _reversing else _gear, _fwd_speed), 0.12)
		if _grounded == 0 and throttle > 0.1:
			rpm_target = maxf(rpm_target, 0.85 * throttle)
		rpm_target = minf(rpm_target + _wheelspin * 0.25, 1.0)
		if _shift_timer > 0.0:
			rpm_target *= 0.82
	_rpm = move_toward(_rpm, rpm_target, dt * (3.0 if _shift_timer > 0.0 else 6.0))

	# suspension offsets for the visual (ease droop so wheels don't snap)
	for i in 4:
		var target := clampf(_comp[i], -SUSP_DROOP, 0.2) if _contact[i] else -SUSP_DROOP * 0.6
		_vis_offset[i] = target if _contact[i] else move_toward(_vis_offset[i], target, dt * 1.5)


func _process(_delta: float) -> void:
	if visual == null:
		return
	for i in 4:
		_vis_spin_arr[i] = _spin[i]
		_vis_susp_arr[i] = _vis_offset[i]
	visual.set_wheel_state(-_steer_angle, _vis_spin_arr, _vis_susp_arr)
	visual.set_lights(_braking, _reversing)
	visual.set_nitro(_nitro_active)
