extends Node
## Core test: TrackPath frames on a flat circle, a banked turn and a vertical loop.


func _ready() -> void:
	# Straight along -Z: forward must be -Z, right +X, up +Y.
	var c := Curve3D.new()
	c.add_point(Vector3.ZERO)
	c.add_point(Vector3(0, 0, -100))
	var p := TrackPath.new(c, false, 14.0)
	var t := p.sample_transform(50.0)
	TestHooks.check((-t.basis.z).distance_to(Vector3(0, 0, -1)) < 0.01, "straight_forward", str(-t.basis.z))
	TestHooks.check(t.basis.x.distance_to(Vector3.RIGHT) < 0.01, "straight_right", str(t.basis.x))
	TestHooks.check(t.basis.y.distance_to(Vector3.UP) < 0.01, "straight_up", str(t.basis.y))
	TestHooks.check(absf(p.lateral_offset(Vector3(3, 0, -40)) - 3.0) < 0.05, "lateral_offset", str(p.lateral_offset(Vector3(3, 0, -40))))
	TestHooks.check(absf(p.edge_clearance(Vector3(10, 0, -40)) - 3.0) < 0.05, "edge_clearance", str(p.edge_clearance(Vector3(10, 0, -40))))

	# Positive tilt: right edge lower (road normal leans to the right).
	var cb := Curve3D.new()
	cb.add_point(Vector3.ZERO)
	cb.add_point(Vector3(0, 0, -100))
	cb.set_point_tilt(0, 0.3)
	cb.set_point_tilt(1, 0.3)
	var pb := TrackPath.new(cb, false, 14.0)
	var tb := pb.sample_transform(50.0)
	TestHooks.check(tb.basis.y.x > 0.2, "tilt_positive_leans_right", str(tb.basis.y))

	# Vertical loop of radius 20 in the YZ plane with a lateral shift, entered along -Z.
	var cl := Curve3D.new()
	var r := 20.0
	var n := 24
	cl.add_point(Vector3(0, 0, 40))
	for i in n + 1:
		var a := TAU * i / n
		cl.add_point(Vector3(8.0 * i / n, r - r * cos(a), -r * sin(a)))
	cl.add_point(Vector3(8, 0, -40))
	var pl := TrackPath.new(cl, false, 12.0)
	# Find the top of the loop (max y) and check the road normal points down there.
	var best_d := 0.0
	var best_y := -1e9
	var d := 0.0
	while d < pl.length:
		var y := pl.sample_position(d).y
		if y > best_y:
			best_y = y
			best_d = d
		d += 0.5
	var top := pl.sample_transform(best_d)
	TestHooks.check(top.basis.y.y < -0.9, "loop_top_inverted", "up at top = %s" % top.basis.y)
	var exit_t := pl.sample_transform(pl.length - 5.0)
	TestHooks.check(exit_t.basis.y.y > 0.95, "loop_exit_upright", str(exit_t.basis.y))
	TestHooks.finish()
