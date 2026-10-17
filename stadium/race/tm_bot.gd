class_name TmBot
extends Node
## A driving bot for our own tracks: it follows a track's line (TmChallenge.path, laid by
## TmTrackBuilder), steering at a point some way ahead on it and keeping to the speed the turns
## ahead allow (cornering at `grip`, braking at `braking`); through loops and over jumps it holds
## the wheel straight. It shows that a track can be finished and sets the track's medal times
## (tests/test_tracks). The race scene drives with it when started with --bot.

@export var car: TmCar
var path: Array = []
var grip := 14.0                 ## lateral acceleration it takes the turns at (m/s^2)
var braking := 10.0              ## deceleration it plans its braking with (m/s^2)
var index := 0                   ## the next point of the line to pass
var failed := ""                 ## why it gave up ("" while it drives)
var _slow_ticks := 0
var _floor := -INF               ## below this it has fallen off

const LOOK_MIN := 10.0
const LOOK_MAX := 34.0
const STUCK_TICKS := 400          ## 4 s under 5 km/h: stuck
const OFF_LINE := 70.0            ## this far from the line's next point (steered parts): lost


func _ready() -> void:
	process_physics_priority = -10   # before the race steps the car


## From the start again.
func reset() -> void:
	index = 0
	failed = ""
	_slow_ticks = 0
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
	var steered := int(pt["mode"]) == TmTrackBuilder.Drive.STEER
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
	if steered:
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
	car.steer = steer
	car.gas = 1.0 if v < allowed or not steered else 0.0
	car.brake = 1.0 if steered and v > allowed + 2.0 else 0.0


## The point `look` metres along the line from the car (through the next points).
func _ahead(pos: Vector3, look: float) -> Vector3:
	var from := pos
	var left := look
	for i in range(index, path.size()):
		var p: Vector3 = path[i]["p"]
		if int(path[i]["mode"]) != TmTrackBuilder.Drive.STEER:
			return from
		var d := from.distance_to(p)
		if d >= left:
			return from.lerp(p, left / d)
		left -= d
		from = p
	return from
