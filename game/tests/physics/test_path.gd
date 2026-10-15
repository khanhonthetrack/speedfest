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
		var u := up
		var tilt := _tilt_at(d)
		if absf(tilt) > 1e-5:
			u = u.rotated(t, tilt)
		var r := t.cross(u).normalized()
		u = r.cross(t).normalized()
		_frames.append(Transform3D(Basis(r, u, -t), pos))
