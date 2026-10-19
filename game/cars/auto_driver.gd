class_name AutoDriver
extends Node
## A path-following driver for a TmCar: used by the tests to prove every circuit can be lapped,
## and available as a demo driver. Add it as a child of the car, give it a TrackPath, and it fills
## the car's controls every physics tick.
##
## - Steering is pure pursuit: aim at a point on the path a look-ahead distance in front, scaled
##   with speed, and turn toward it.
## - Speed comes from a profile baked from the path's horizontal curvature (how fast a corner can
##   be taken with `grip_margin` of the car's cornering force), run backwards so the car brakes in
##   time for what is coming.
## - The nitrous goes down on straights once the car is already moving.
## - If it stops making progress for `stuck_timeout` seconds it emits `stuck`, so the race (or a
##   test) can respawn it.

signal stuck

const PROFILE_STEP := 4.0          ## metres between speed-profile samples
const MIN_SPEED := 14.0            ## m/s the profile never goes below
const LOOK_MIN := 9.0
const LOOK_MAX := 55.0

var car: TmCar
var path: TrackPath
var enabled := true
var use_boost := true
## Fraction of the car's cornering force the bot plans with (lower = slower and safer).
var grip_margin := 0.70
## Racing-line offset from the centreline, metres, + = right of travel.
var lateral_offset := 0.0
var stuck_timeout := 4.0

var distance := 0.0                ## where the bot thinks it is along the lap
var laps := 0

var _profile := PackedFloat32Array()
var _kappa := PackedFloat32Array()
var _profile_path: TrackPath = null
var _no_progress := 0.0
var _last_d := 0.0
var _started := false


func _ready() -> void:
	process_physics_priority = -20       # before the car's own tick
	if car == null:
		car = get_parent() as TmCar


## Re-bake the speed profile (after a path or car change).
func prepare() -> void:
	if path == null or car == null:
		return
	var n := maxi(8, int(path.length / PROFILE_STEP))
	_profile.resize(n)
	_kappa.resize(n)
	var step := path.length / float(n)
	# cornering force the car can actually use, from its tuned grip
	var lat := 16.0 * float(car.specs.get("grip", 1.0)) * grip_margin
	var top := float(car.specs.get("top_kmh", 280.0)) / 3.6
	for i in n:
		var d := float(i) * step
		var a := path.sample_position(fposmod(d - 14.0, path.length))
		var b := path.sample_position(d)
		var c := path.sample_position(fposmod(d + 14.0, path.length))
		var v1 := b - a
		var v2 := c - b
		v1.y = 0.0
		v2.y = 0.0
		var k := 0.0
		if v1.length() > 0.05 and v2.length() > 0.05:
			var ang := v1.normalized().angle_to(v2.normalized())
			k = absf(ang) / maxf((v1.length() + v2.length()) * 0.5, 0.1)
		_kappa[i] = k
		_profile[i] = clampf(sqrt(lat / maxf(k, 0.0001)), MIN_SPEED, top)
	# backward pass: arrive at every corner slow enough, braking at ~9 m/s^2
	var brake := 9.0 * float(car.specs.get("brake", 1.0))
	for pass_i in 3:
		for j in range(n * 2, -1, -1):
			var i2 := j % n
			var nxt := (i2 + 1) % n
			var limit := sqrt(_profile[nxt] * _profile[nxt] + 2.0 * brake * step)
			if _profile[i2] > limit:
				_profile[i2] = limit
	_profile_path = path


func speed_limit_at(d: float) -> float:
	if _profile.is_empty():
		return 30.0
	var i := int(fposmod(d, path.length) / path.length * float(_profile.size()))
	return _profile[clampi(i, 0, _profile.size() - 1)]


func reset_to(d: float) -> void:
	distance = fposmod(d, path.length if path else 1.0)
	_last_d = distance
	_no_progress = 0.0


func _physics_process(delta: float) -> void:
	if not enabled or car == null or path == null:
		return
	if _profile_path != path or _profile.is_empty():
		prepare()
	var pos := car.global_transform.origin
	# follow the path from where we were, so a loop never jumps a lap
	distance = _advance(pos)
	var v := car.lin_vel
	var speed := v.length()
	var look := clampf(LOOK_MIN + speed * 0.65, LOOK_MIN, LOOK_MAX)
	var t := path.sample_transform(fposmod(distance + look, path.length))
	var target := t.origin + t.basis.x * lateral_offset
	var local := car.global_transform.affine_inverse() * target
	# the car frame is +X left, +Z forward: a target to the left wants positive steer
	var steer := clampf(atan2(local.x, maxf(local.z, 1.0)) * 2.4, -1.0, 1.0)

	var want := speed_limit_at(distance + maxf(speed * 0.9, 12.0))
	var gas := 0.0
	var brake := 0.0
	if speed < want - 0.5:
		gas = 1.0
	elif speed > want + 2.5:
		brake = clampf((speed - want) / 12.0, 0.2, 1.0)
	else:
		gas = 0.35
	# hard limit on the current corner, not just the one ahead
	var here := speed_limit_at(distance)
	if speed > here + 4.0:
		brake = maxf(brake, 0.6)
		gas = 0.0
	car.gas = gas
	car.brake = brake
	car.steer = steer
	car.boost_input = use_boost and gas > 0.9 and absf(steer) < 0.25 and speed > 18.0 \
		and car.boost_meter > 0.25

	# stuck?
	var moved := speed > 2.0
	if moved:
		_no_progress = 0.0
	else:
		_no_progress += delta
		if _no_progress > stuck_timeout:
			_no_progress = 0.0
			stuck.emit()


## Walk the path forward from the last position so the lap counter is monotonic.
func _advance(pos: Vector3) -> float:
	var best := _last_d
	var best_dist := INF
	var window := 90.0
	var step := 2.0
	var d := _last_d - 12.0
	while d < _last_d + window:
		var p := path.sample_position(fposmod(d, path.length))
		var dist := p.distance_squared_to(pos)
		if dist < best_dist:
			best_dist = dist
			best = d
		d += step
	if best > _last_d:
		_started = true
	if best >= path.length:
		laps += 1
		best -= path.length
	_last_d = best
	return fposmod(best, path.length)
