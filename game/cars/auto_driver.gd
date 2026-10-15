class_name AutoDriver
extends Node
## Path-following bot (tests, demos, `--autodrive`). Add as a child of a Car and set `path`;
## it fills car.controls each physics tick.
##
## - Steering: pure pursuit toward a point on the path, look-ahead scaled by speed.
## - Speed: a per-path speed profile from the horizontal curvature (loop/vertical curvature is
##   ignored), with braking distance; full throttle inside and just before "loop" and "jump" zones.
## - Nitro on straights. Stuck recovery (reverse and re-align); after `stuck_timeout` seconds
##   without progress it emits `stuck` and calls `reset_callable` (or resets itself onto the path).

signal stuck

var path: TrackPath
## Speed cap in km/h (<= 0: no cap). Kept from the original stub API.
var target_speed_kmh := 0.0
var enabled := true
var use_nitro := true
## Racing-line offset from the centerline (m, + = right). Bots can vary it.
var lateral_offset := 0.0
## Fraction of the car's lateral grip the bot plans with (lower = more careful).
var grip_margin := 0.72
## True when a test feeds the bot's wishes through CarInput like a keyboard player (keeps brake drift on).
var emulate_player := false
var brake_accel := 9.0
var stuck_timeout := 5.0
## Called (no arguments) instead of the built-in reset when the bot is stuck. Race can respawn.
var reset_callable: Callable

const PROFILE_STEP := 2.0
const ZONE_LEAD := 70.0            # full throttle this many meters before loop/jump zones
const STANLEY_K := 1.6
const WALL_LEAD := 40.0             # Stanley + full throttle this far around wall-ride zones
const STANLEY_JUMP_LEAD := 45.0     # Stanley steering this many meters before a jump (clean takeoff)

var _d := -1.0
var _progress := 0.0
var _best_progress := 0.0
var _no_progress := 0.0
var _slow_time := 0.0
var _reverse_time := 0.0
var _prev_pos := Vector3.ZERO
var _profile := PackedFloat32Array()
var _full := PackedByteArray()
var _kappa := PackedFloat32Array()      # signed horizontal curvature (+ = turning right)
var _stan := PackedByteArray()          # 1 where Stanley steering is used (loops, jump run-ups)
var _profile_path: TrackPath = null


func get_progress() -> float:
	return _progress


func get_distance() -> float:
	return _d


## Alias used by race.gd between runs.
func reset() -> void:
	reset_tracking()


## Forget the tracked position (call after teleporting the car somewhere else).
func reset_tracking() -> void:
	_d = -1.0
	_no_progress = 0.0
	_slow_time = 0.0
	_reverse_time = 0.0


func _wrap(d: float) -> float:
	if path.is_circuit:
		return fposmod(d, path.length)
	return clampf(d, 0.0, path.length)


func _physics_process(dt: float) -> void:
	var car := get_parent() as Car
	if car != null and car.brake_drift_enabled and not emulate_player:
		car.brake_drift_enabled = false   # the bot brakes while steering; it must not drift by accident
	if car == null or path == null:
		return
	if not enabled:
		_zero(car)
		return
	if _profile_path != path:
		_build_profile(car)
	var pos := car.global_position
	_track(pos)
	if car.frozen_controls:
		_zero(car)
		car.controls["throttle"] = 0.0
		_no_progress = 0.0
		_slow_time = 0.0
		return
	var xf := car.global_transform
	var v := car.linear_velocity.dot(-xf.basis.z)
	var speed := absf(v)

	# --- steering: Stanley in loops (surface-intrinsic), pure pursuit elsewhere ---
	var in_loop := _stanley_here()
	var look := clampf(6.0 + speed * 0.42, 8.0, 38.0)
	var tt := path.sample_transform(_wrap(_d + look))
	var target := tt.origin + tt.basis.x * lateral_offset + tt.basis.y * 0.4
	var local := xf.affine_inverse() * target
	var lx := local.x
	var lz := -local.z
	var steer := 0.0
	if not car.is_grounded() and car.get_air_time() > 0.05:
		steer = 0.0   # never steer in the air (air steering yaws the car)
	elif in_loop:
		steer = _stanley(car, speed)
	elif lz < 0.5:
		steer = signf(lx) if absf(lx) > 0.01 else 1.0
	else:
		var l2 := lx * lx + lz * lz
		var kappa := 2.0 * lx / l2
		# kinematic angle + the tire slip angle needed for that lateral acceleration (feed-forward)
		var p := car.params
		var a_max := float(p["grip"]) * Car.GRIP_SCALE * CarPhysicsDefs.GRAVITY * (1.0 + float(p["downforce"]) * speed * speed / (float(p["mass"]) * CarPhysicsDefs.GRAVITY))
		var frac := clampf(speed * speed * kappa / a_max, -1.0, 1.0)
		var ang := atan(kappa * car.get_wheelbase()) + frac * float(p["slip_peak"])
		steer = clampf(ang / maxf(car.max_steer_at(speed), 0.05), -1.0, 1.0)

	# --- speed target ---
	var vt := _target_speed(speed)
	var full := _full_throttle_here()
	var throttle := 0.0
	var brake := 0.0
	if full:
		throttle = 1.0
	elif v < vt - 1.5:
		throttle = 1.0
	elif v > vt + 2.0:
		brake = clampf((v - vt) / 8.0, 0.25, 1.0)
	else:
		throttle = 0.35
	# traction control: ease off when the car starts to slide
	if not full and (car.get_drift_amount() > 0.1 or absf(car.get_slip_angle()) > deg_to_rad(7.0)):
		throttle = minf(throttle, 0.45)
	var nitro := false
	if use_nitro and car.is_grounded() and speed > 22.0 and absf(steer) < 0.3:
		if full or vt > speed + 25.0:
			nitro = true

	# --- stuck handling ---
	if _reverse_time > 0.0:
		_reverse_time -= dt
		throttle = 0.0
		brake = 1.0
		steer = -steer
		nitro = false
	elif throttle > 0.5 and speed < 1.5:
		_slow_time += dt
		if _slow_time > 1.2:
			_slow_time = 0.0
			_reverse_time = 1.4
	else:
		_slow_time = 0.0
	if _progress > _best_progress + 3.0:
		_best_progress = _progress
		_no_progress = 0.0
	else:
		_no_progress += dt
	if _no_progress > stuck_timeout:
		_no_progress = 0.0
		_reverse_time = 0.0
		stuck.emit()
		if reset_callable.is_valid():
			reset_callable.call()
		else:
			_self_reset(car)
		reset_tracking()
		return
	var cap := target_speed_kmh / 3.6
	if cap > 0.0 and v > cap:
		throttle = 0.0
		nitro = false
	car.controls["throttle"] = throttle
	car.controls["brake"] = brake
	car.controls["steer"] = steer
	car.controls["handbrake"] = false
	car.controls["nitro"] = nitro


## Stanley controller on the road surface: heading error + lateral error, both measured in the
## path frame at the front axle (works upside down in loops).
func _stanley(car: Car, speed: float) -> float:
	var xf := car.global_transform
	var front := xf.origin - xf.basis.z * car.get_wheelbase() * 0.5
	var tf := path.sample_transform(_wrap(_d + car.get_wheelbase() * 0.5))
	var e := (front - tf.origin).dot(tf.basis.x) - lateral_offset
	var pf := -tf.basis.z
	var car_f := -xf.basis.z
	var psi := atan2(pf.dot(xf.basis.x), pf.dot(car_f))
	var delta := psi + atan2(-STANLEY_K * e, speed + 2.0)
	return clampf(delta / maxf(car.max_steer_at(speed), 0.05), -1.0, 1.0)


func _zero(car: Car) -> void:
	car.controls["throttle"] = 0.0
	car.controls["brake"] = 0.0
	car.controls["steer"] = 0.0
	car.controls["handbrake"] = false
	car.controls["nitro"] = false


func _self_reset(car: Car) -> void:
	var d := _d
	# back off before a loop/jump so the car gets a run-up
	for z in path.zones:
		if String(z.get("kind", "")) in ["loop", "jump"] and d >= float(z["from"]) - 5.0 and d <= float(z["to"]):
			d = float(z["from"]) - 60.0
	d = _wrap(d)
	var t := path.sample_transform(d)
	t.origin += t.basis.y * 0.6 + t.basis.x * lateral_offset
	var fwd := -t.basis.z
	car.teleport(t, fwd * 15.0)


## Local search around the last distance (robust on loops and crossings).
func _track(pos: Vector3) -> void:
	var jumped := _d >= 0.0 and pos.distance_to(_prev_pos) > 15.0
	_prev_pos = pos
	if _d < 0.0 or jumped:
		_d = path.closest_distance(pos)
		_best_progress = _progress
		return
	var best := _d
	var best_d2 := INF
	var k := -8.0
	while k <= 30.0:
		var dd := _d + k
		if path.is_circuit or (dd >= 0.0 and dd <= path.length):
			var d2 := path.sample_position(_wrap(dd)).distance_squared_to(pos)
			if d2 < best_d2:
				best_d2 = d2
				best = dd
		k += 1.0
	var lo := best - 1.0
	k = 0.0
	while k <= 2.0:
		var dd := lo + k
		var d2 := path.sample_position(_wrap(dd)).distance_squared_to(pos)
		if d2 < best_d2:
			best_d2 = d2
			best = dd
		k += 0.25
	if best_d2 > 30.0 * 30.0:
		_d = path.closest_distance(pos)
		return
	_progress += best - _d
	_d = _wrap(best)


func _build_profile(car: Car) -> void:
	_profile_path = path
	var n := int(ceil(path.length / PROFILE_STEP)) + 1
	_profile.resize(n)
	_full.resize(n)
	_kappa.resize(n)
	_stan.resize(n)
	var p := car.params
	var m: float = p["mass"]
	# wet weather: plan with the wet-asphalt grip (puddles are left to the steering)
	var mu0 := float(p["grip"]) * Car.GRIP_SCALE * grip_margin * (car.surface.grip_for_water(0.0) if car.surface != null else 1.0)
	var g := CarPhysicsDefs.GRAVITY
	var dfm := float(p["downforce"]) / m
	for i in n:
		var d := minf(i * PROFILE_STEP, path.length)
		# grass / gravel / sand on the centreline: plan with that ground's grip
		var mu := mu0 * (car.surface.centerline_grip(d) if car.surface != null else 1.0)
		var t1 := path.sample_transform(d)
		var t2 := path.sample_transform(_wrap(d + 4.0))
		var t0 := path.sample_transform(_wrap(d - 4.0))
		var f0 := -t0.basis.z
		var f2 := -t2.basis.z
		var kappa_s := (f2 - f0).dot(t1.basis.x) / 8.0
		_kappa[i] = kappa_s
		var kappa := absf(kappa_s)
		var vmax := 200.0
		# turning measured in the WORLD horizontal plane, banking = road normal leaning toward the
		# turn's center (wall rides and banked turns), standard banked-curve limit with downforce
		var h0 := Vector3(f0.x, 0.0, f0.z)
		var h2 := Vector3(f2.x, 0.0, f2.z)
		var nrm := t1.basis.y
		if absf(f0.y) < 0.7 and absf(f2.y) < 0.7 and h0.length() > 0.3 and h2.length() > 0.3:
			h0 = h0.normalized()
			h2 = h2.normalized()
			var dh := h2 - h0
			var kh := dh.length() / 8.0
			if kh > 1e-5:
				var c := dh.normalized()                     # horizontal unit toward the turn's center
				var sin_b := nrm.dot(c)
				var cos_b := maxf(nrm.y, 0.0)
				var v2 := 200.0 * 200.0
				for _it in 3:
					var mu_eff := mu * (1.0 + dfm * minf(v2, 120.0 * 120.0) / g)
					var den := cos_b - mu_eff * sin_b
					if den <= 1e-4:
						v2 = 200.0 * 200.0
						break
					v2 = clampf(g / kh * (sin_b + mu_eff * cos_b) / den, 0.0, 200.0 * 200.0)
				vmax = sqrt(v2)
		elif kappa > 1e-5:
			var denom := kappa - mu * dfm
			if denom > 1e-5:
				vmax = sqrt(mu * g / denom)
		_profile[i] = minf(vmax, 200.0)
		var full := 0
		var stan := 0
		for z in path.zones:
			var kind := String(z.get("kind", ""))
			if kind in ["loop", "jump"] and d >= float(z["from"]) - ZONE_LEAD and d <= float(z["to"]) + 5.0:
				full = 1
			if kind == "loop" and d >= float(z["from"]) - 5.0 and d <= float(z["to"]) + 5.0:
				stan = 1
			if kind == "wallride" and d >= float(z["from"]) - WALL_LEAD and d <= float(z["to"]) + WALL_LEAD:
				stan = 1   # speed comes from the banked-curve limit (unlimited once the wall is steep)
			if kind == "jump" and d >= float(z["from"]) - STANLEY_JUMP_LEAD and d <= float(z["to"]) + 5.0:
				stan = 1
		_stan[i] = stan
		_full[i] = full
		if full == 1:
			_profile[i] = 200.0


func _target_speed(speed: float) -> float:
	var scan := speed * speed / (2.0 * brake_accel) + 30.0
	var n := _profile.size()
	var best := 200.0
	var s := 0.0
	while s <= scan:
		var dd := _d + s
		if not path.is_circuit and dd > path.length:
			break
		var i := clampi(int(_wrap(dd) / PROFILE_STEP), 0, n - 1)
		var allowed := sqrt(_profile[i] * _profile[i] + 2.0 * brake_accel * s)
		best = minf(best, allowed)
		s += PROFILE_STEP
	return best


func _stanley_here() -> bool:
	if _stan.is_empty():
		return false
	return _stan[clampi(int(_d / PROFILE_STEP), 0, _stan.size() - 1)] == 1


## Average signed path curvature over [d, d + span].
func _path_kappa(d: float, span: float) -> float:
	var n := _kappa.size()
	if n == 0:
		return 0.0
	var sum := 0.0
	var cnt := 0
	var s := 0.0
	while s <= span:
		sum += _kappa[clampi(int(_wrap(d + s) / PROFILE_STEP), 0, n - 1)]
		cnt += 1
		s += PROFILE_STEP
	return sum / maxf(cnt, 1)


func _full_throttle_here() -> bool:
	if _full.is_empty():
		return false
	var i := clampi(int(_d / PROFILE_STEP), 0, _full.size() - 1)
	return _full[i] == 1
