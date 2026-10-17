class_name TmBot
extends Node
## A driving bot for our own tracks: it follows a track's line (TmChallenge.path, laid by
## TmTrackBuilder), steering at a point some way ahead on it and keeping to the speed the turns
## ahead allow (cornering at `grip`, braking at `braking`); over jumps and up the steep part of a
## loop it holds the wheel straight, and in the air it steers with the car's spin to damp it.
## Into, round and out of loops (LOOP points) it steers for the turn the car makes at its speed:
## TMNF's steering turns the car slowly at loop speeds. It shows that a track can be finished and
## sets the track's medal times (tests/test_tracks). The race scene drives with it when started
## with --bot.

@export var car: TmCar
var path: Array = []
var grip := 14.0                 ## lateral acceleration it takes the turns at (m/s^2)
var braking := 10.0              ## deceleration it plans its braking with (m/s^2)
var index := 0                   ## the next point of the line to pass
var failed := ""                 ## why it gave up ("" while it drives)
var _slow_ticks := 0
var _air_ticks := 0              ## ticks with no wheel on anything
var _floor := -INF               ## below this it has fallen off

const LOOK_MIN := 10.0
const LOOK_MAX := 34.0
const STUCK_TICKS := 400          ## 4 s under 5 km/h: stuck
const OFF_LINE := 70.0            ## this far from the line's next point (steered parts): lost
const AIR_TICKS := 5              ## this long without a wheel on anything: in the air
const LOOP_WN := 2.0              ## loops: how fast the steering pulls the car back onto the line
const LOOP_ZETA := 0.8            ## (rad/s) and how well damped
## Ordinary road over FRAME_KMH: the same road-frame steering, a little softer and better damped,
## with the curvature taken PREVIEW_S ahead (the steering's lag). Its old aim-at-a-point steering
## (gain 2.2) weaved at 250+ km/h, where TMNF's car answers the wheel slowly, so it took off over
## crests with a yaw rate and landed sideways; it still steers below FRAME_KMH, where the yaw rate
## model has no grip on the slow steering ramp.
const ROAD_WN := 1.6
const ROAD_ZETA := 0.95
const FRAME_KMH := 100.0
const PREVIEW_S := 0.25
const CREST_G := TmTuning.GRAVITY * TmTuning.GRAVITY_GROUND   ## what holds the car down over a crest


func _ready() -> void:
	process_physics_priority = -10   # before the race steps the car


## From the start again.
func reset() -> void:
	index = 0
	failed = ""
	_slow_ticks = 0
	_air_ticks = 0
	_floor = INF
	for p: Dictionary in path:
		_floor = minf(_floor, (p["p"] as Vector3).y)
	_floor -= 12.0


func _physics_process(_delta: float) -> void:
	if car == null or path.is_empty():
		return
	if not failed.is_empty():
		car.gas = 0.0
		car.brake = 1.0
		car.steer = 0.0
		return
	var pos := car.global_position
	while index < path.size() and (pos - (path[index]["p"] as Vector3)).dot(path[index]["dir"]) > 0.0:
		index += 1
	if index >= path.size():
		car.gas = 1.0
		car.brake = 0.0
		car.steer = 0.0
		_slow_ticks += 1
		if _slow_ticks > STUCK_TICKS:
			failed = "past the end of the line without finishing (missed a checkpoint?)"
		return
	var pt: Dictionary = path[index]
	var v := car.lin_vel.length()
	var steered := int(pt["mode"]) in [TmTrackBuilder.Drive.STEER, TmTrackBuilder.Drive.LOOP]
	# lost?
	if pos.y < _floor:
		failed = "fell off at point %d" % index
	elif steered and pos.distance_to(pt["p"]) > OFF_LINE:
		failed = "off the line at point %d (%.0f m)" % [index, pos.distance_to(pt["p"])]
	_slow_ticks = _slow_ticks + 1 if v < 5.0 / 3.6 and car.controls_enabled else 0
	if _slow_ticks > STUCK_TICKS:
		failed = "stuck at point %d" % index
	# steer at a point ahead on the line
	var steer := 0.0
	if steered and int(pt["mode"]) == TmTrackBuilder.Drive.LOOP:
		steer = _loop_steer(pos, v)
	elif steered and v * 3.6 > FRAME_KMH:
		steer = _frame_steer(pos, v, ROAD_WN, ROAD_ZETA, _k_ahead(pos, v * PREVIEW_S))
	elif steered:
		var aim := _ahead(pos, clampf(v * 0.4, LOOK_MIN, LOOK_MAX))
		var b := car.global_transform.basis
		var to := aim - pos
		steer = clampf(atan2(to.dot(b.x), to.dot(b.z)) * 2.2, -1.0, 1.0)
	# the speed the turns ahead allow, given the room to brake
	var allowed := INF
	var dist := pos.distance_to(pt["p"])
	for i in range(index, mini(index + 60, path.size())):
		if i > index:
			dist += (path[i]["p"] as Vector3).distance_to(path[i - 1]["p"])
		if dist > 260.0:
			break
		var r := float(path[i]["r"])
		if r > 0.0:
			allowed = minf(allowed, sqrt(grip * r + 2.0 * braking * dist))
		# over a crest no faster than gravity holds the car on the road: flying off one at speed
		# it lands sideways
		var rv := float(path[i].get("rv", 0.0))
		if rv > 0.0:
			allowed = minf(allowed, sqrt(CREST_G * rv + 2.0 * braking * dist))
	# in the air (off a crest as well as a jump): steer with the car's spin, which TMNF damps
	# three times as hard (TmCarModel air control), so the car lands straight
	_air_ticks = 0 if car.wheel_contact.has(true) else _air_ticks + 1
	if _air_ticks >= AIR_TICKS:
		var yaw := (car.global_transform.basis.transposed() * car.ang_vel).y
		steer = 0.0 if absf(yaw) < 0.02 else signf(yaw)
		steered = false
	car.steer = steer
	car.gas = 1.0 if v < allowed or not steered else 0.0
	car.brake = 1.0 if steered and v > allowed + 2.0 else 0.0


## The point `look` metres along the line from the car (through the next points).
func _ahead(pos: Vector3, look: float) -> Vector3:
	var from := pos
	var left := look
	for i in range(index, path.size()):
		var p: Vector3 = path[i]["p"]
		if int(path[i]["mode"]) == TmTrackBuilder.Drive.BLIND:
			return from
		var d := from.distance_to(p)
		if d >= left:
			return from.lerp(p, left / d)
		left -= d
		from = p
	return from


## Steering on a LOOP stretch, in the road's own frame (a loop is a cylinder: aiming at a point
## ahead in 3D would read its twist as a turn): the line's curvature (k) plus a pull back onto it
## from the car's offset and heading, as a curvature, then as a share of the yaw rate full lock
## gives at this speed (TMNF's steady yaw rate: steer torque x ramp / yaw damping, tmnf_physics.md
## 3.4: the car turns slowly at loop speeds). The heading, not the velocity: up a loop's steep
## side gravity bends the velocity but not the heading, and the grip brings the two together.
func _loop_steer(pos: Vector3, v: float) -> float:
	return _frame_steer(pos, v, LOOP_WN, LOOP_ZETA, NAN)


## The line's curvature `look` metres ahead of the car (the next points' k).
func _k_ahead(pos: Vector3, look: float) -> float:
	var from := pos
	var left := look
	for i in range(index, path.size()):
		var p: Vector3 = path[i]["p"]
		var d := from.distance_to(p)
		if d >= left:
			return float(path[i].get("k", 0.0))
		left -= d
		from = p
	return 0.0


## Steering in the road's frame (see _loop_steer): the line's curvature k_ff (NAN: the current
## segment's) plus a pull back onto the line (wn rad/s, damping zeta), as a share of the yaw rate
## full lock gives at this speed.
func _frame_steer(pos: Vector3, v: float, wn: float, zeta: float, k_ff: float) -> float:
	var a: Dictionary = path[maxi(index - 1, 0)]
	var c: Dictionary = path[index]
	var pa: Vector3 = a["p"]
	var seg: Vector3 = (c["p"] as Vector3) - pa
	var t := clampf((pos - pa).dot(seg) / maxf(seg.length_squared(), 1e-6), 0.0, 1.0)
	var b := car.global_transform.basis
	var along := (a["dir"] as Vector3).lerp(c["dir"], t)
	var left := b.y.cross(along).normalized()
	var fwd := left.cross(b.y)
	var off := (pos - pa.lerp(c["p"], t)).dot(left)
	var psi := atan2(b.z.dot(left), b.z.dot(fwd))
	var vv := maxf(v, 5.0)
	var k := lerpf(float(a.get("k", 0.0)), float(c.get("k", 0.0)), t) if is_nan(k_ff) else k_ff
	var curv := k - wn * wn / (vv * vv) * off - 2.0 * zeta * wn / vv * psi
	var ramp := 0.0
	if v >= TmTuning.STEER_MIN_SPEED:
		ramp = sin(v / TmTuning.STEER_RAMP_SPEED * PI * 0.5) if v <= TmTuning.STEER_RAMP_SPEED else 1.0
	var yaw_full := TmTuning.lin(TmTuning.STEER_TORQUE, v * 3.6) * ramp / (
		TmTuning.YAW_FROM_GRIP * TmTuning.SIDE_STIFFNESS * 0.5 * TmTuning.WHEELBASE)
	if yaw_full < 1e-3:
		return 0.0
	return clampf(curv * v / yaw_full, -1.0, 1.0)
