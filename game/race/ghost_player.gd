class_name GhostPlayer
extends Node3D
## Plays back a ghost recorded by GhostRecorder as a translucent CarVisual.
## The race calls set_time(run_ms) every frame while a run is going, and hide_ghost() otherwise.

const ALPHA := 0.35
const MAX_STEER_RAD := 0.55
const TELEPORT_DIST := 25.0          # m between 20 Hz samples (~1800 km/h): a respawn, not driving

var ghost: Dictionary = {}
var visual: CarVisual
var duration_ms := 0

var _times := PackedFloat64Array()
var _pos := PackedVector3Array()
var _rot: Array[Quaternion] = []
var _steer := PackedFloat32Array()
var _flags := PackedInt32Array()
var _spin := 0.0
var _last_ms := -1.0
var _wheel_radius := 0.33
var _cursor := 0


## Returns false if the ghost has no usable samples.
func load_ghost(g: Dictionary) -> bool:
	if not GhostRecorder.is_valid_ghost(g):
		return false
	ghost = g
	_times.clear()
	_pos.clear()
	_rot.clear()
	_steer.clear()
	_flags.clear()
	for e in g["samples"]:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var p: Array = e.get("p", [])
		var q: Array = e.get("q", [])
		if p.size() < 3 or q.size() < 4:
			continue
		var t := float(e.get("t", 0))
		if not _times.is_empty() and t <= _times[-1]:
			continue
		_times.append(t)
		_pos.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
		var quat := Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3]))
		_rot.append(quat.normalized() if quat.length_squared() > 0.0001 else Quaternion.IDENTITY)
		_steer.append(float(e.get("st", 0.0)))
		_flags.append(int(e.get("fl", 0)))
	if _times.size() < 2:
		return false
	duration_ms = int(_times[-1])
	var cfg := CarDefs.sanitize_config(g.get("car", {}))
	_wheel_radius = float(CarDefs.geometry(cfg["car"])["wheel_radius"])
	if visual == null:
		visual = CarVisual.new()
		add_child(visual)
	visual.build(cfg["car"], cfg["style"])
	visual.set_underglow_enabled(false)
	visual.set_ghost(ALPHA)
	visible = false
	return true


func has_ghost() -> bool:
	return _times.size() >= 2


func hide_ghost() -> void:
	visible = false
	_last_ms = -1.0


## Pose the ghost at run time ms. Past the end the ghost stays parked on the finish for a moment.
func set_time(ms: float) -> void:
	if not has_ghost():
		visible = false
		return
	if ms > _times[-1] + 1500.0 or ms < 0.0:
		visible = false
		return
	visible = true
	var xf := sample(ms)
	global_transform = xf
	var i := _cursor
	var speed := 0.0
	if i + 1 < _times.size():
		var dt := (_times[i + 1] - _times[i]) / 1000.0
		if dt > 0.0:
			speed = _pos[i].distance_to(_pos[i + 1]) / dt
	if _last_ms >= 0.0 and ms > _last_ms:
		_spin = fmod(_spin + speed * (ms - _last_ms) / 1000.0 / _wheel_radius, TAU)
	_last_ms = ms
	if visual:
		var st := _steer[i] * MAX_STEER_RAD
		visual.set_wheel_state(st, [_spin, _spin, _spin, _spin], [0.0, 0.0, 0.0, 0.0])
		var fl := _flags[i]
		visual.set_lights(fl & 1 != 0, fl & 8 != 0)
		visual.set_nitro(fl & 2 != 0)


## Interpolated transform at time ms (cubic position, slerped rotation).
func sample(ms: float) -> Transform3D:
	var n := _times.size()
	if ms <= _times[0]:
		_cursor = 0
		return Transform3D(Basis(_rot[0]), _pos[0])
	if ms >= _times[n - 1]:
		_cursor = n - 1
		return Transform3D(Basis(_rot[n - 1]), _pos[n - 1])
	# Usually time moves forward by a little: walk from the cursor, else binary search.
	var i := clampi(_cursor, 0, n - 2)
	if _times[i] > ms or (i + 1 < n and _times[i + 1] < ms - 1000.0):
		i = maxi(0, _times.bsearch(ms, true) - 1)
	while i < n - 2 and _times[i + 1] < ms:
		i += 1
	_cursor = i
	var t0 := _times[i]
	var t1 := _times[i + 1]
	var f := clampf((ms - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)
	# Catmull-Rom through neighbours for smooth curves at 20 Hz.
	var p0 := _pos[maxi(i - 1, 0)]
	var p1 := _pos[i]
	var p2 := _pos[i + 1]
	var p3 := _pos[mini(i + 2, n - 1)]
	# Respawn teleports: don't smooth across jumps.
	if p1.distance_to(p2) > TELEPORT_DIST:
		var k := 0 if f < 0.5 else 1
		return Transform3D(Basis(_rot[i + k]), _pos[i + k])
	if p0.distance_to(p1) > TELEPORT_DIST:
		p0 = p1
	if p3.distance_to(p2) > TELEPORT_DIST:
		p3 = p2
	var pos := _catmull(p0, p1, p2, p3, f)
	var rot := _rot[i].slerp(_rot[i + 1], f)
	return Transform3D(Basis(rot), pos)


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
