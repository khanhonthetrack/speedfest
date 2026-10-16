class_name Car
extends RigidBody3D
## Arcade raycast vehicle (Jolt, 60 Hz). API fixed by docs/ARCHITECTURE.md "Car".
##
## Four suspension rays (mask 1) at CarDefs.wheel_positions(); spring + damper + bump stop +
## anti-roll per axle. Handling (M7, Trackmania feel; docs/research/m7_physics.md): the steering
## sets the yaw rate directly (capped by grip: no spins, no understeer), lateral grip cancels
## sideways velocity in the road plane up to grip * load (the same rule on banks, wall rides and
## loops: the springs' load includes cornering and downforce), a brake-tap/handbrake drift mode
## where the steering sets the slide angle. Engine: constant-power model with a torque-curve
## shape (Tuning.drive_force), 6 gears + reverse, automatic gearbox. Aero downforce, air
## auto-levelling, anti-flip and self-righting. All forces are applied in _integrate_forces.
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
const GROUND_STICK_MAX := 0.6           # m/s away from the road while >= 2 wheels touch it (TM: glued;
                                         # a road that twists or crests can't pop the car off; jump lips still launch)
const LAND_ABSORB := 0.45                # fraction of the touchdown speed into the ground removed (rest: suspension squash)
const MAX_WHEEL_G := 28.0                # cap on a single wheel's suspension force (in corner weights)
const AIR_LEVEL := 3.0                   # air auto-levelling strength (rad/s^2 per rad)
const AIR_DAMP := 1.6                    # air pitch/roll rate damping (1/s)
const AIR_PITCH_FOLLOW := 5.0            # nose follows the flight path (rad/s^2 per rad): dips into landings
const AIR_GRAVITY_EXTRA := 0.35          # extra gravity while airborne (punchier, less floaty arcs)
const AIR_STEER := 1.5                   # air yaw response (1/s)
const AIR_YAW_RATE := 0.3                # max air yaw rate from steering (rad/s): a nudge, not a spin
## Grass/gravel/sand rolling drag fades in with speed (full above this, 15% at a standstill), so a
## car that stops in a sand trap can still crawl out; at racing speed it bogs down as designed.
const LOOSE_DRAG_FULL_SPEED := 15.0      # m/s (~54 km/h)
## Trackmania-feel handling (M7, docs/research/m7_physics.md): the steering sets the yaw rate,
## lateral grip cancels sideways velocity in the road plane up to GRIP_SCALE * grip * load.
const STEER_TAU := 0.04                  # steering smoothing (s, / steer_speed): ~0.09 s to 90%
const YAW_TAU := 0.05                    # yaw-rate controller time constant (s)
const GRIP_SCALE := 1.15                 # lateral grip = grip * GRIP_SCALE * suspension load
const LAT_GAIN := 0.5                    # fraction of sideways velocity removed per tick (within grip)
const TRACTION_SCALE := 1.0
const RWD_TRACTION_SHARE := 0.75         # drive force cap share of the load for RWD (AWD: 1.0)
const COAST_DECEL := 0.9                 # m/s^2 engine braking when off the throttle
## Drift: brake tap / handbrake + steer above DRIFT_MIN_SPEED. The steering then sets the slide
## angle (DRIFT_SLIP_MIN..MAX deg), lateral grip drops to the car's drift grip.
const DRIFT_MIN_SPEED := 16.0            # m/s (~58 km/h)
const DRIFT_ENTER := 0.08                # s
const DRIFT_EXIT := 0.3                  # s for grip to come back
const DRIFT_BRAKE_KEEP := 0.2            # fraction of the brake force kept while drifting
const DRIFT_SLIP_MIN := 12.0
const DRIFT_SLIP_MAX := 28.0
const DRIFT_SLIP_GAIN := 6.0             # 1/s: how hard the body chases the slide angle
## Barrier hits: keep the car on its wheels. Side contacts can't add roll/pitch spin or pop the car up.
const WALL_SPIN_KEEP := 0.15             # fraction of the roll/pitch rate kept on a wall contact
const WALL_YAW_MAX := 2.6                # rad/s yaw-rate cap right after a wall hit
## Barriers (M7, owner: "super annoying"): a glancing hit turns the nose along the wall and keeps
## going; only the speed into the wall is lost, plus a little friction and a small bounce.
const WALL_BOUNCE := 0.12                # fraction of the impact speed bounced back (capped 1.5 m/s)
const WALL_FRICTION := 0.12              # speed lost along the wall per m/s of impact speed
const WALL_ALIGN_TIME := 0.15            # s to turn the nose along the wall
const BOOST_MAX_ACCEL := 60.0            # apply_boost clamps (m/s^2, s)
const BOOST_MAX_TIME := 4.0
const BOOST_FADE_FROM := 100.0           # boost fades from 360 km/h ...
const BOOST_SPEED_CAP := 116.0           # ... to zero at ~420 km/h
const MAX_SPEED := 125.0                 # hard cap, 450 km/h
const BODY_FRICTION := 0.0
const ROOF_DRAG := 9.0                   # m/s^2 deceleration while sliding on the roof or side
const ROLL_DAMP := 8.0                   # roll-rate damping relative to the road's twist (1/s)
const TWIST_SMOOTH := 0.05               # smoothing time of the measured road twist rate (s)
const ROAD_ALIGN := 14.0                  # gentle torque aligning the car with the road normal (twists, wall rides)

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
# wheel pose of the previous tick: _process draws the wheels between ticks, like the interpolated body
var _spin_step := PackedFloat32Array([0, 0, 0, 0])
var _prev_vis_offset := PackedFloat32Array([0, 0, 0, 0])
var _prev_steer_angle := 0.0
var _queries: Array[PhysicsRayQueryParameters3D] = []
var _land_q := PhysicsRayQueryParameters3D.new()

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
## Brake + steer at speed starts a drift (players). Bots switch it off (AutoDriver).
var brake_drift_enabled := true
var _bd_blend := 0.0                     # drift amount 0..1 (= _drift_mode, kept for callers)
var _drift_mode := 0.0                   # 0 grip .. 1 drifting
var _drift_dir := 0.0                    # +1 drifting right, -1 left
var _wall_timer := 0.0
var _hard_comp := 0.15                    # compression where the travel ends (just before the floor box touches)
var _wall_align_w := 0.0                 # yaw rate (about the ground normal) that lines the nose up with the wall
var _wall_align_t := 0.0
var _takeoff_up_y := 1.0                 # world-up component of the last ground normal (jump vs wall ride)
var _prev_slip := 0.0                    # last tick's body slip angle (stability assist)
var _prev_slip_ok := false
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
## Weather surface map (wet asphalt + puddles), set by the race scene. null = dry everywhere.
var surface: TrackSurface = null
## Rail grind: while set, that TrackRail drives the body (grind_step from _integrate_forces).
var grind: TrackRail = null
var _water := PackedFloat32Array([0, 0, 0, 0])
var _ground := PackedInt32Array([0, 0, 0, 0])      # TrackSurface kind under each wheel (0 asphalt)
var _loose_grip := 0.0                               # params "loose_grip": rally tires on grass/gravel/sand
var _water_avg := 0.0


func _init() -> void:
	# drawn between physics ticks on high refresh-rate screens (the tree defaults to OFF, see
	# Settings._ready); teleport() resets it so respawns don't smear across the map
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON


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
	_loose_grip = float(params.get("loose_grip", 0.0))
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
	_hard_comp = maxf(float(g["ground_clearance"]) + 0.07 - 0.04, BUMP_START + 0.02)
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
	_land_q.collision_mask = 1
	_land_q.collide_with_areas = false
	_land_q.exclude = [get_rid()]


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
	if _water_avg > 0.2:
		f |= 64
	return f


func get_net_state() -> Dictionary:
	var q := global_transform.basis.get_rotation_quaternion()
	var p := global_position
	var v := linear_velocity
	return {"p": [p.x, p.y, p.z], "q": [q.x, q.y, q.z, q.w], "v": [v.x, v.y, v.z],
		"st": float(controls.get("steer", 0.0)), "rpm": _rpm, "fl": get_flags()}


## How many physics ticks behind the newest simulated state the car is drawn this frame: physics
## interpolation shows lerp(previous tick, last tick, fraction), so 1 - fraction (0 when it's off).
## Ghosts and wheels use it to line up with the drawn body.
func display_tick_lag() -> float:
	return 1.0 - Engine.get_physics_interpolation_fraction() if is_physics_interpolated_and_enabled() else 0.0


func teleport(xform: Transform3D, p_linear_velocity: Vector3 = Vector3.ZERO) -> void:
	if grind != null:
		grind.release(self)
		grind = null
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
	# a stronger pad wins; a weaker pad touched during a strong boost doesn't cut it short
	if _boost_time <= 0.0 or accel >= _boost_accel:
		_boost_accel = clampf(accel, 0.0, BOOST_MAX_ACCEL)
	_boost_time = clampf(maxf(_boost_time, duration), 0.0, BOOST_MAX_TIME)


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


## 0..1: how much of the car's tire contact is in a puddle (spray, splash sound, net flag).
func get_water_amount() -> float:
	return _water_avg


## TrackSurface ground kind under the rear wheels (0 asphalt, 1 grass, 2 gravel, 3 sand); the
## highest-numbered one if they differ. For dust / grass spray.
func get_ground_kind() -> int:
	var k := 0
	for i in [2, 3]:
		if _contact[i]:
			k = maxi(k, _ground[i])
	return k


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
	var a_lat := float(params["grip"]) * GRIP_SCALE * CarPhysicsDefs.GRAVITY * (1.0 + float(params["downforce"]) * v * v / (m * CarPhysicsDefs.GRAVITY))
	var ang := atan(_wheelbase * a_lat / (v * v))
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
		_spin_step[i] = 0.0
		_prev_vis_offset[i] = 0.0
	_steer_angle = 0.0
	_prev_steer_angle = 0.0
	_boost_time = 0.0
	_drift = 0.0
	_slip_angle = 0.0
	_air_time = 0.0
	_upside_time = 0.0
	_bd_blend = 0.0
	_drift_mode = 0.0
	_drift_dir = 0.0
	_wall_timer = 0.0
	_wall_align_t = 0.0
	_takeoff_up_y = 1.0
	_prev_slip = 0.0
	_prev_slip_ok = false
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
	for i in 4:
		_prev_vis_offset[i] = _vis_offset[i]
		_spin_step[i] = 0.0
	_prev_steer_angle = _steer_angle
	if _pending_teleport:
		_pending_teleport = false
		state.transform = _pending_xform
		state.linear_velocity = _pending_vel
		state.angular_velocity = Vector3.ZERO
		return
	if grind != null:
		if grind.grind_step(self, state):
			_grounded = 0
			_air_time = 0.0
			_boost_time = 0.0
			return
		grind = null
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
	if _grounded >= 2:
		_takeoff_up_y = _ground_n.dot(Vector3.UP)
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

	# wheels on the road: the car can't spring away from it faster than GROUND_STICK_MAX
	# (a redirect, not a brake: the speed is kept, only its direction follows the road; the
	# triangle normals step every meter, so a plain clamp would bleed speed on every step)
	# measured along the car's own up axis: smooth (the body is rigid), and equal to the road normal
	# while the wheels are on it
	if _grounded >= 2:
		var vn_g := lv.dot(up)
		if vn_g > GROUND_STICK_MAX:
			var sp0 := lv.length()
			lv -= up * (vn_g - GROUND_STICK_MAX)
			if lv.length_squared() > 1e-4:
				lv = lv.normalized() * sp0
			state.linear_velocity = lv

	# end of the suspension travel (hard stop): a fast loop or a compression at the bottom of a drop
	# pulls 20-30 g, more than the springs hold, and the body would hit the road (the floor box
	# catches a triangle edge and the car stops dead). The travel ends before that: no further
	# velocity into the road; it is redirected along the road with its speed kept (TM never
	# grounds the floor in a loop).
	if _grounded >= 2:
		var cmax := -1.0
		for i in 4:
			if _contact[i]:
				cmax = maxf(cmax, _comp[i])
		if cmax > _hard_comp:
			var vn_h := lv.dot(up)
			if vn_h < 0.0:
				var sp1 := lv.length()
				lv -= up * vn_h
				# keep the speed only while rolling on the road (loops, compressions); on a
				# touchdown the vertical speed must not turn into free forward speed
				if was_grounded >= 2 and lv.length_squared() > 1e-4:
					lv = lv.normalized() * sp1
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

	# --- steering: direct, one quick smoothing step; the angle limit follows the grip so full
	# lock sits just inside it (no understeer). A drift opens the lock up. ---
	var v_abs := absf(_fwd_speed)
	var max_angle := max_steer_at(v_abs)
	if _drift_mode > 0.3:
		max_angle = lerpf(max_angle, float(params["steer_max"]), 0.6)
	var target_angle := steer_in * max_angle
	_steer_angle = lerpf(_steer_angle, target_angle, 1.0 - exp(-dt * float(params["steer_speed"]) / STEER_TAU))

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

	# --- handbrake blend (visual wheel lock, drift trigger) ---
	if handbrake:
		_hb_blend = move_toward(_hb_blend, 1.0, dt / 0.08)
	else:
		_hb_blend = move_toward(_hb_blend, 0.0, dt / 0.3)

	# --- drift (Trackmania style): a brake tap or the handbrake while steering at speed breaks the
	# car loose; the slide lasts while you keep steering into it and ends when the wheel is centred
	# (or turned the other way), grip coming back over DRIFT_EXIT seconds ---
	var drift_go := brake_drift_enabled and (brake > 0.5 or handbrake) and absf(steer_in) > 0.3 \
		and v_abs > DRIFT_MIN_SPEED and not _reversing and not frozen_controls and _grounded >= 3
	if drift_go:
		_drift_dir = signf(steer_in)
		_drift_mode = move_toward(_drift_mode, 1.0, dt / DRIFT_ENTER)
	elif _drift_mode > 0.0 and steer_in * _drift_dir > 0.2 and v_abs > DRIFT_MIN_SPEED * 0.6 and _grounded >= 2:
		pass   # holding the slide
	else:
		_drift_mode = move_toward(_drift_mode, 0.0, dt / DRIFT_EXIT)
	_bd_blend = _drift_mode
	_intent = _drift_mode
	# a brake tap that starts a drift shouldn't also kill the speed
	brake_in *= lerpf(1.0, DRIFT_BRAKE_KEEP, _drift_mode)

	# --- ground frame: the road plane under the car (works on banks, walls and loops alike) ---
	var gn := _ground_n
	var f_g := (fwd - gn * fwd.dot(gn))
	f_g = f_g.normalized() if f_g.length_squared() > 1e-6 else fwd
	var r_g := f_g.cross(gn)
	var lv_g := lv - gn * lv.dot(gn)
	var v_long := lv_g.dot(f_g)
	var v_lat := lv_g.dot(r_g)
	var slip := 0.0
	if _grounded >= 2 and lv_g.length() > 3.0:
		slip = atan2(v_lat, absf(v_long))
	_slip_angle = slip
	_drift = move_toward(_drift, clampf((absf(slip) - deg_to_rad(6.0)) / deg_to_rad(18.0), 0.0, 1.0), dt * 4.0)

	# --- surface: weather (wet asphalt, puddles) and ground kind, averaged over the wheels down ---
	var sgrip := 0.0
	var sdrag := 0.0
	var water_sum := 0.0
	var touching := 0
	for i in 4:
		_water[i] = 0.0
		_ground[i] = 0
		if not _contact[i]:
			continue
		touching += 1
		var wg := 1.0
		if surface != null:
			var water := surface.water_at(_hit_pos[i])
			_water[i] = water
			water_sum += water
			wg = surface.grip_for_water(water)
			sdrag += surface.drag_for_water(water)
			if not surface.patches.is_empty():
				_ground[i] = surface.kind_at(_hit_pos[i])
				wg *= lerpf(TrackSurface.KIND_GRIP[_ground[i]], 1.0, _loose_grip)
				if _ground[i] > 0:
					var fade := clampf(v_abs / LOOSE_DRAG_FULL_SPEED, 0.15, 1.0)
					sdrag += TrackSurface.KIND_DRAG[_ground[i]] * (1.0 - 0.6 * _loose_grip) * fade
		sgrip += wg
	_water_avg = water_sum / 4.0
	sgrip = sgrip / float(touching) if touching > 0 else 1.0
	sdrag = sdrag / 4.0

	var spin_total := 0.0
	if _grounded >= 2:
		var share := float(_grounded) / 4.0
		# --- longitudinal: engine, brakes, coast, surface drag, all along the road ---
		var drive_awd := String(params["drive"]) == "awd"
		var drive_cap := float(params["traction"]) * TRACTION_SCALE * total_load * (1.0 if drive_awd else RWD_TRACTION_SHARE) \
			* lerpf(1.0, sgrip, 0.8)
		var f_long := drive_total
		if absf(f_long) > drive_cap:
			spin_total += clampf((absf(f_long) - drive_cap) / maxf(drive_cap, 1.0), 0.0, 1.0)
			f_long = signf(f_long) * drive_cap
		var bf := brake_in * float(params["brake_decel"]) * m * share
		if handbrake:
			bf += 0.35 * CarPhysicsDefs.GRAVITY * m * share
		if throttle < 0.05 and not _reversing and not frozen_controls:
			bf += COAST_DECEL * m * share
		bf += sdrag * m
		bf = minf(bf, absf(v_long) * m / dt * 0.8)
		f_long -= signf(v_long) * bf
		state.apply_central_force(f_g * f_long)

		# --- lateral: cancel sideways velocity in the road plane, up to the grip limit. The force
		# is perpendicular to the heading, so grip turns cost almost no speed. The load comes from the
		# springs, so it includes gravity into the road, cornering (wall rides, loops) and downforce.
		var mu := float(params["grip"]) * GRIP_SCALE * sgrip
		var drift_grip := clampf(float(params["rear_slide"]) * 0.8, 0.42, 0.7)
		var lat_cap := mu * total_load * lerpf(1.0, drift_grip, _drift_mode)
		var f_req := -v_lat * m / dt * LAT_GAIN
		var f_lat := clampf(f_req, -lat_cap, lat_cap)
		state.apply_central_force(r_g * f_lat)
		var sliding := 1.0 - absf(f_lat) / maxf(absf(f_req), 1.0)
		spin_total += clampf(sliding * 2.0, 0.0, 1.0) * clampf(absf(v_lat) / 4.0, 0.0, 1.0)

		# --- yaw: the steering sets the turn rate directly (v * tan(angle) / wheelbase). On grip it
		# is capped at what the tires can follow, so the car never rotates away from its velocity
		# (no spins, no understeer). In a drift the steering sets the slide angle instead.
		var yaw := av.dot(gn)
		var w_cap := (lat_cap / m) / maxf(v_abs, 1.0)
		var w_des := -v_long * tan(_steer_angle) / _wheelbase
		w_des = clampf(w_des, -w_cap * 1.02, w_cap * 1.02)
		if _drift_mode > 0.0 and v_abs > 5.0:
			# slide angle target: 28 deg with the wheel held into the turn, 12 deg when eased,
			# 4 deg on counter-steer; the body turns at the velocity's rate plus a slip correction
			var into := steer_in * _drift_dir
			var target_slip := _drift_dir * deg_to_rad(lerpf(DRIFT_SLIP_MIN, DRIFT_SLIP_MAX, clampf(into, 0.0, 1.0)) if into >= 0.0 else 4.0)
			var w_vel := -(f_lat / m) / maxf(v_abs, 1.0) * signf(v_long)
			# slip > 0: velocity right of the nose; more slip to the right = nose turns left (+yaw)
			var w_drift := w_vel - (target_slip - (-slip)) * DRIFT_SLIP_GAIN * float(params.get("drift_assist", 1.0))
			w_des = lerpf(w_des, w_drift, _drift_mode)
		if _wall_align_t > 0.0:
			# nose into a barrier: turn it along the wall (steering away harder still wins)
			if not (signf(w_des) == signf(_wall_align_w) and absf(w_des) > absf(_wall_align_w)):
				w_des = _wall_align_w
		var torque := (w_des - yaw) / YAW_TAU * inertia.y
		state.apply_torque(gn * torque)
	_wheelspin = move_toward(_wheelspin, clampf(spin_total, 0.0, 1.0), dt * 5.0)

	# wheel spin for visuals
	for i in 4:
		if _contact[i]:
			var sv := _fwd_speed / _radius
			if handbrake and i >= 2:
				sv = 0.0
			_spin_vel[i] = sv
		elif throttle > 0.1 and (i >= 2 or String(params["drive"]) == "awd"):
			_spin_vel[i] = move_toward(_spin_vel[i], 120.0 * throttle, 200.0 * dt)
		else:
			_spin_vel[i] *= 0.995
		_spin_step[i] = _spin_vel[i] * dt
		_spin[i] = fmod(_spin[i] + _spin_step[i], TAU)

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

	# --- nitro & boost ---
	_nitro_active = false
	if want_nitro and _nitro > 0.0 and not _reversing:
		_nitro_active = true
		_nitro = maxf(_nitro - dt / float(params["nitro_time"]), 0.0)
		var nd := fwd
		if _grounded >= 2:
			nd = (fwd - _ground_n * fwd.dot(_ground_n)).normalized()
		state.apply_central_force(nd * m * float(params["nitro_accel"]))
	if _boost_time > 0.0:
		_boost_time -= dt
		var bd := _boost_dir
		if _grounded >= 2:
			# push along the road, never into or off it
			bd = bd - _ground_n * bd.dot(_ground_n)
			bd = bd.normalized() if bd.length_squared() > 1e-4 else fwd
		# fade out approaching the boost speed cap
		var fade := 1.0 - clampf((lv.dot(bd) - BOOST_FADE_FROM) / (BOOST_SPEED_CAP - BOOST_FADE_FROM), 0.0, 1.0)
		state.apply_central_force(bd * m * _boost_accel * fade)
	# hard speed cap (2.1 m per tick at 60 Hz, less than a gate trigger's 4 m depth; walls use CCD)
	var sp2 := state.linear_velocity.length_squared()
	if sp2 > MAX_SPEED * MAX_SPEED:
		state.linear_velocity = state.linear_velocity * (MAX_SPEED / sqrt(sp2))

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
				# the nose partly follows the flight path; close to the ground it lines up with the
				# landing surface instead (downward probe), so landings are wheels-first, not nose-first
				var pitch_v := clampf(asin(clampf(vdir.y, -1.0, 1.0)) * 0.6, deg_to_rad(-18.0), deg_to_rad(15.0))
				var hz := Vector3(fwd.x, 0.0, fwd.z)
				if hz.length_squared() > 1e-4:
					hz = hz.normalized()
					var f_t := (hz * cos(pitch_v) + Vector3.UP * sin(pitch_v)).normalized()
					_land_q.from = com
					_land_q.to = com + Vector3.DOWN * 9.0
					var lh := space.intersect_ray(_land_q)
					if not lh.is_empty():
						var ln: Vector3 = lh["normal"]
						if ln.dot(Vector3.UP) > 0.5:
							var on_plane := (hz - ln * hz.dot(ln)).normalized()
							var near := clampf(1.0 - (com.distance_to(lh["position"]) - 1.5) / 6.0, 0.0, 1.0)
							f_t = f_t.lerp(on_plane, near).normalized()
					state.apply_torque(fwd.cross(f_t) * AIR_PITCH_FOLLOW * inertia.x)
		# punchier jump arcs, but only for jumps: at speed and off ordinary road (a car that lifts off
		# a wall ride or loop for a moment must not be pulled off it harder; spawn drops stay plain)
		if _air_time > 0.1 and _takeoff_up_y > 0.8 and speed > 15.0:
			state.apply_central_force(Vector3.DOWN * m * CarPhysicsDefs.GRAVITY * AIR_GRAVITY_EXTRA)
		# light air steering: drive the yaw rate toward -steer * AIR_YAW_RATE (steer +1 = right =
		# clockwise from above = negative yaw; also damps spins)
		var yaw_rate := av.dot(up)
		state.apply_torque(up * (-steer_in * AIR_YAW_RATE - yaw_rate) * AIR_STEER * inertia.y)
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

	# --- roof/side drag: the body has zero friction (clean wall scrapes), so a car sliding on its
	# roof or side would never stop. Decelerate it so it settles and self-rights (or race respawns).
	if _grounded < 2 and state.get_contact_count() > 0 and up.dot(Vector3.UP) < 0.4 and speed > 0.5:
		var dec := minf(ROOF_DRAG, speed / dt)
		state.apply_central_force(-lv / speed * m * dec)
		state.apply_torque(-av * inertia.z * 2.0)

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

	# --- barrier contacts: deflect along the wall, never roll/flip or pop up (arcade) ---
	_wall_timer = maxf(_wall_timer - dt, 0.0)
	_wall_align_t = maxf(_wall_align_t - dt, 0.0)
	# (not while self-righting: the tilted body resting on the ground is not a wall hit, and the
	# anti-spin below would cancel the righting roll and leave the car stuck on its side)
	if state.get_contact_count() > 0 and up.dot(Vector3.UP) > 0.2 and _righting <= 0.0:
		var ref_up := _ground_n if _grounded >= 2 else up
		var wall := false
		var lv_w := state.linear_velocity
		for ci in state.get_contact_count():
			var cn := state.get_contact_local_normal(ci)
			if absf(cn.dot(ref_up)) > 0.6 or (_grounded < 2 and absf(cn.dot(Vector3.UP)) > 0.7):
				continue    # floor / ramp under the body: not a wall
			var to_car := xf.origin - state.get_contact_local_position(ci)
			if cn.dot(to_car) < 0.0:
				cn = -cn
			cn = (cn - ref_up * cn.dot(ref_up)).normalized()
			var vn := lv_w.dot(cn)
			if vn < 0.0:
				# lose the speed into the wall (small bounce) and a little along it
				var tang := lv_w - cn * vn
				var ts := tang.length()
				if ts > 0.01:
					tang *= maxf(ts - WALL_FRICTION * -vn, 0.0) / ts
				lv_w = tang + cn * minf(-vn * WALL_BOUNCE, 1.5)
				# nose pointing into the wall: line it up with the direction of travel along it
				var f_r := (fwd - ref_up * fwd.dot(ref_up)).normalized()
				var t_dir := tang - ref_up * tang.dot(ref_up)
				if f_r.dot(cn) < -0.02 and t_dir.length() > 2.0:
					var err := f_r.signed_angle_to(t_dir.normalized(), ref_up)
					_wall_align_w = clampf(err / WALL_ALIGN_TIME, -WALL_YAW_MAX, WALL_YAW_MAX)
					_wall_align_t = 0.25
			wall = true
		if wall:
			_wall_timer = 0.35
			state.linear_velocity = lv_w
	if _wall_timer > 0.0 and _righting <= 0.0:
		var ref := _ground_n if _grounded >= 2 else Vector3.UP
		var av_w := state.angular_velocity
		var yaw := ref * clampf(av_w.dot(ref), -WALL_YAW_MAX, WALL_YAW_MAX)
		state.angular_velocity = yaw + (av_w - ref * av_w.dot(ref)) * WALL_SPIN_KEEP
		# the hit must not throw the car upward (off a platform)
		var lvv := state.linear_velocity
		var rise := lvv.dot(ref) - _prev_vel.dot(ref)
		if rise > 0.3 and _grounded > 0:
			state.linear_velocity = lvv - ref * (rise - 0.3)

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
	# the body is drawn between the last two ticks (physics interpolation): draw the wheels there too
	var back := display_tick_lag()
	for i in 4:
		_vis_spin_arr[i] = _spin[i] - _spin_step[i] * back
		_vis_susp_arr[i] = lerpf(_vis_offset[i], _prev_vis_offset[i], back)
	visual.set_wheel_state(-lerpf(_steer_angle, _prev_steer_angle, back), _vis_spin_arr, _vis_susp_arr)
	visual.set_ground_contact(_grounded / 4.0)
	visual.set_lights(_braking, _reversing)
	visual.set_nitro(_nitro_active)
