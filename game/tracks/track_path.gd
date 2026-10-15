class_name TrackPath
extends RefCounted
## Centerline of a track with oriented road frames, sampled by distance d (meters from the start).
##
## Frames: origin on the road surface centerline, basis.x = right, basis.y = road normal,
## -basis.z = direction of travel. Frames follow world-up on normal roads and switch to
## parallel transport on steep or inverted sections (loops), so loops orient correctly.
## Banking comes from the Curve3D point tilts (radians, positive rolls the road to the right-down).

const STEP := 0.5

var curve: Curve3D
var length: float = 0.0
var is_circuit: bool = true
## [{from: float, to: float, kind: String}], kinds: loop, jump, tunnel, bridge, boost, no_props
var zones: Array = []

## Vertical loops: [{from: float, to: float, axis: Vector3}]. Inside a loop the road's right
## vector is the loop's fixed lateral axis (projected onto the plane normal to the tangent),
## which keeps the road surface facing the loop center without twist.
var loop_axes: Array = []

var _width_default: float = 14.0
var _width_profile: Array = []         # sorted [[d, w], ...]
var _frames: Array[Transform3D] = []
var _point_offsets: PackedFloat32Array = PackedFloat32Array()


func _init(p_curve: Curve3D, circuit: bool = true, width: float = 14.0) -> void:
	curve = p_curve
	is_circuit = circuit
	_width_default = width
	rebake()


## Set loop axes (see `loop_axes`) and rebuild the frames.
func set_loop_axes(axes: Array) -> void:
	loop_axes = axes.duplicate(true)
	_bake_frames()


func _loop_axis_at(d: float) -> Vector3:
	for l in loop_axes:
		if d >= float(l["from"]) and d <= float(l["to"]):
			return l["axis"]
	return Vector3.ZERO


## Recompute frames (call after editing the curve).
func rebake() -> void:
	length = curve.get_baked_length()
	_point_offsets.resize(curve.point_count)
	for i in curve.point_count:
		_point_offsets[i] = curve.get_closest_offset(curve.get_point_position(i))
	if is_circuit and curve.point_count > 1:
		_point_offsets[curve.point_count - 1] = length
	_bake_frames()


func _tangent_at(d: float) -> Vector3:
	var e := 0.25
	var a := curve.sample_baked(clampf(d - e, 0.0, length), true)
	var b := curve.sample_baked(clampf(d + e, 0.0, length), true)
	var t := b - a
	if t.length_squared() < 1e-8:
		return Vector3.FORWARD
	return t.normalized()


func _tilt_at(d: float) -> float:
	var n := curve.point_count
	if n == 0:
		return 0.0
	if d <= _point_offsets[0]:
		return curve.get_point_tilt(0)
	for i in range(1, n):
		if d <= _point_offsets[i]:
			var span := _point_offsets[i] - _point_offsets[i - 1]
			var f := 0.0 if span <= 0.0001 else (d - _point_offsets[i - 1]) / span
			f = f * f * (3.0 - 2.0 * f)
			return lerpf(curve.get_point_tilt(i - 1), curve.get_point_tilt(i), f)
	return curve.get_point_tilt(n - 1)


func _bake_frames() -> void:
	_frames.clear()
	if length <= 0.0:
		_frames.append(Transform3D.IDENTITY)
		return
	var count := int(ceil(length / STEP)) + 1
	var prev_pos := curve.sample_baked(0.0, true)
	var prev_t := _tangent_at(0.0)
	var up := (Vector3.UP - prev_t * Vector3.UP.dot(prev_t))
	up = up.normalized() if up.length_squared() > 1e-6 else Vector3.BACK
	var ups: Array[Vector3] = []
	var poss: Array[Vector3] = []
	var tans: Array[Vector3] = []
	for i in count:
		var d := minf(i * STEP, length)
		var pos := curve.sample_baked(d, true)
		var t := _tangent_at(d)
		if i > 0:
			# Double-reflection parallel transport of `up` from (prev_pos, prev_t) to (pos, t).
			var v1 := pos - prev_pos
			var c1 := v1.dot(v1)
			if c1 > 1e-10:
				var r_l := up - (2.0 / c1) * v1.dot(up) * v1
				var t_l := prev_t - (2.0 / c1) * v1.dot(prev_t) * v1
				var v2 := t - t_l
				var c2 := v2.dot(v2)
				up = r_l - (2.0 / c2) * v2.dot(r_l) * v2 if c2 > 1e-10 else r_l
			# On ordinary (not steep, not inverted) road, snap back to world-up to remove twist.
			if absf(t.y) < 0.7 and up.dot(Vector3.UP) > 0.3:
				var proj := Vector3.UP - t * Vector3.UP.dot(t)
				if proj.length_squared() > 1e-6:
					up = proj.normalized()
		up = (up - t * up.dot(t)).normalized()
		var axis := _loop_axis_at(d)
		if axis != Vector3.ZERO:
			var rr := axis - t * axis.dot(t)
			if rr.length_squared() > 1e-6:
				up = (-t).cross(rr.normalized()).normalized()
		ups.append(up)
		poss.append(pos)
		tans.append(t)
		prev_pos = pos
		prev_t = t
	for i in count:
		var d := minf(i * STEP, length)
		var t: Vector3 = tans[i]
		var u: Vector3 = ups[i]
		var tilt := _tilt_at(d)
		if absf(tilt) > 1e-5:
			u = u.rotated(t, tilt)
		var r := t.cross(u).normalized()
		u = r.cross(t).normalized()
		_frames.append(Transform3D(Basis(r, u, -t), poss[i]))


func _wrap(d: float) -> float:
	if is_circuit and length > 0.0:
		return fposmod(d, length)
	return clampf(d, 0.0, length)


func sample_transform(d: float) -> Transform3D:
	d = _wrap(d)
	var fi := d / STEP
	var i := int(floor(fi))
	if i >= _frames.size() - 1:
		return _frames[_frames.size() - 1]
	var f := fi - i
	var a := _frames[i]
	var b := _frames[i + 1]
	var q := a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), f)
	return Transform3D(Basis(q), a.origin.lerp(b.origin, f))


func sample_position(d: float) -> Vector3:
	return curve.sample_baked(_wrap(d), true)


func set_width_profile(points: Array) -> void:
	_width_profile = points.duplicate()
	_width_profile.sort_custom(func(a, b): return a[0] < b[0])


func width_at(d: float) -> float:
	if _width_profile.is_empty():
		return _width_default
	d = _wrap(d)
	if d <= _width_profile[0][0]:
		return _width_profile[0][1]
	for i in range(1, _width_profile.size()):
		if d <= _width_profile[i][0]:
			var a: Array = _width_profile[i - 1]
			var b: Array = _width_profile[i]
			var a0: float = a[0]
			var span: float = float(b[0]) - a0
			var f: float = 0.0 if span <= 0.0001 else (d - a0) / span
			return lerpf(float(a[1]), float(b[1]), f)
	return _width_profile[_width_profile.size() - 1][1]


func closest_distance(p: Vector3) -> float:
	return curve.get_closest_offset(p)


func lateral_offset(p: Vector3) -> float:
	var t := sample_transform(closest_distance(p))
	return (p - t.origin).dot(t.basis.x)


## Meters outside the road edge (negative = over the road). Points far above/below the
## road surface (> 6 m) count as clear, so props can sit under bridges.
func edge_clearance(p: Vector3) -> float:
	var d := closest_distance(p)
	var t := sample_transform(d)
	var local := t.affine_inverse() * p
	return maxf(absf(local.x) - width_at(d) * 0.5, absf(local.y) - 6.0)


func in_zone(d: float, kind: String) -> bool:
	for z in zones:
		if z.get("kind", "") == kind and d >= float(z["from"]) and d <= float(z["to"]):
			return true
	return false
