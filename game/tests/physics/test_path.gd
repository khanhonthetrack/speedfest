class_name PhysicsTestPath
extends TrackPath
## Test-only TrackPath with "right-vector locking" frames on steep/inverted sections (loops).
## The stock TrackPath snaps a parallel-transported up back to world-up in one step on the
## descending side of a laterally shifted loop (~49 deg twist on r=18 / 14 m shift); see
## docs/modules/physics.md "Integration requests". This subclass is the proposed fix.


func _bake_frames() -> void:
	_frames.clear()
	if length <= 0.0:
		_frames.append(Transform3D.IDENTITY)
		return
	var count := int(ceil(length / STEP)) + 1
	var up := Vector3.UP
	var right := Vector3.RIGHT
	var locked := false
	var r0 := Vector3.RIGHT
	for i in count:
		var d := minf(i * STEP, length)
		var pos := curve.sample_baked(d, true)
		var t := _tangent_at(d)
		var steep := absf(t.y) > 0.7 or (i > 0 and up.dot(Vector3.UP) < 0.3)
		if not steep:
			var proj := Vector3.UP - t * Vector3.UP.dot(t)
			up = proj.normalized() if proj.length_squared() > 1e-6 else up
			right = t.cross(up).normalized()
			r0 = right
			locked = false
		else:
			if not locked:
				locked = true
			var rr := r0 - t * r0.dot(t)
			right = rr.normalized() if rr.length_squared() > 1e-6 else right
			up = right.cross(t).normalized()
		var axis := _loop_axis_at(d)
		if axis != Vector3.ZERO:
			# a loop's sideways axis (like TrackPath): the road is the loop's cylinder
			var ra := axis - t * axis.dot(t)
			if ra.length_squared() > 1e-6:
				right = ra.normalized()
				up = right.cross(t).normalized()
		var u := up
		var tilt := _tilt_at(d)
		if absf(tilt) > 1e-5:
			u = u.rotated(t, tilt)
		var r := t.cross(u).normalized()
		u = r.cross(t).normalized()
		_frames.append(Transform3D(Basis(r, u, -t), pos))


## Linear tilt between control points. The stock _tilt_at smoothsteps inside every segment, so
## dense tilt points (wall rides) become a staircase twist: zero roll rate at each point and
## double in between, a washboard the suspension feels at speed.
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
			return lerpf(curve.get_point_tilt(i - 1), curve.get_point_tilt(i), f)
	return curve.get_point_tilt(n - 1)
