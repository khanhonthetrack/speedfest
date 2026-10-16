extends Node3D
## Headless track tests: layout ranges, closure/continuity, self-intersections, spawn poses
## (raycast), gate spans, stunt geometry, and a probe Car driven along the path that must
## trigger every checkpoint in order and then the finish.
## Args: --track=all|<id>

const RANGES := {
	# Trackmania-style short stunt tracks (30-45 s)
	"downtown": {"len": [1100.0, 1800.0], "cps": [4, 6]},
	"arena": {"len": [1100.0, 1800.0], "cps": [4, 6]},
	"coast": {"len": [1100.0, 1800.0], "cps": [4, 6]},
	# ~10 s sprints on grass / gravel / sand (session 4)
	"infield": {"len": [300.0, 700.0], "cps": [1, 3]},
	"dunes": {"len": [300.0, 700.0], "cps": [1, 3]},
	# start-ledge jump onto a grind rail (session 5)
	"rails": {"len": [200.0, 500.0], "cps": [1, 2]},
	# 10-30 s maps, one idea each (session 6)
	"rooftop": {"len": [600.0, 1200.0], "cps": [2, 3]},
	"cliff": {"len": [600.0, 1200.0], "cps": [2, 3]},
	"twister": {"len": [500.0, 1000.0], "cps": [2, 3]},
	"pipes": {"len": [600.0, 1200.0], "cps": [2, 3]},
	"frost": {"len": [500.0, 1100.0], "cps": [2, 3]},
	"dust": {"len": [500.0, 1100.0], "cps": [2, 3]},
	"blackout": {"len": [500.0, 1100.0], "cps": [2, 3]},
	"glide": {"len": [400.0, 1000.0], "cps": [2, 3]},
	"techlab": {"len": [400.0, 900.0], "cps": [2, 3]},
	"fullsend": {"len": [700.0, 1500.0], "cps": [2, 3]},
	"cruise": {"len": [600.0, 1200.0], "cps": [2, 3]},
	"plastic": {"len": [500.0, 1000.0], "cps": [2, 3]},
	"sausage": {"len": [500.0, 1100.0], "cps": [2, 3]},
	"mixer": {"len": [600.0, 1200.0], "cps": [2, 3]},
	"platform": {"len": [400.0, 1000.0], "cps": [2, 3]},
	"snake": {"len": [500.0, 1100.0], "cps": [2, 3]},
}

var hits: Array = []


func _ready() -> void:
	var which: String = TestHooks.arg("track", "all")
	var ids: Array = TrackDefs.IDS if which == "all" else [which]
	for id in ids:
		await _test_track(id)
	TestHooks.finish()


func _test_track(id: String) -> void:
	var t0 := Time.get_ticks_msec()
	var track := Track.build(id, false)
	add_child(track)
	print("%s build_ms=%d length=%.0f cps=%d kill_y=%.1f" % [id, Time.get_ticks_msec() - t0, track.path.length, track.checkpoint_count, track.kill_y])
	var path := track.path
	var r: Dictionary = RANGES[id]
	TestHooks.check(path.length >= r["len"][0] and path.length <= r["len"][1], id + "_length", "%.0f" % path.length)
	TestHooks.check(track.checkpoint_count >= r["cps"][0] and track.checkpoint_count <= r["cps"][1], id + "_cp_count", str(track.checkpoint_count))
	# checkpoints strictly increasing, inside the course, and before the finish
	var ok_order := true
	var prev := track.start_distance
	for d in track.checkpoint_distances:
		if d <= prev + 30.0:
			ok_order = false
		prev = d
	var fin := track.finish_distance + (path.length if track.is_circuit else 0.0)
	TestHooks.check(ok_order and fin > prev + 30.0, id + "_cp_order", str(track.checkpoint_distances))

	# continuity: no jumps in position or heading between consecutive samples
	var worst_angle := 0.0
	var worst_up := 0.0
	var worst_up_d := 0.0
	var worst_step := 0.0
	var d := 0.0
	var pf := path.sample_transform(0.0)
	while d < path.length - 1.0:
		d += 1.0
		var f := path.sample_transform(d)
		worst_step = maxf(worst_step, f.origin.distance_to(pf.origin))
		worst_angle = maxf(worst_angle, rad_to_deg((-pf.basis.z).angle_to(-f.basis.z)))
		var ua := rad_to_deg(pf.basis.y.angle_to(f.basis.y))
		if ua > worst_up:
			worst_up = ua
			worst_up_d = d
		pf = f
	TestHooks.check(worst_step < 1.3 and worst_angle < 4.5, id + "_continuity", "step %.2f angle %.2f" % [worst_step, worst_angle])
	TestHooks.check(worst_up < 4.5, id + "_surface_twist", "up changes %.2f deg/m at d=%.0f" % [worst_up, worst_up_d])
	if track.is_circuit:
		var a := path.sample_transform(path.length - 0.5)
		var b := path.sample_transform(0.5)
		var gap := a.origin.distance_to(b.origin)
		var ang := rad_to_deg((-a.basis.z).angle_to(-b.basis.z))
		TestHooks.check(gap < 1.5 and ang < 3.0, id + "_closure", "gap %.2f angle %.2f" % [gap, ang])

	# self intersections (allowed only on bridges/loops)
	var samples: Array = []
	d = 0.0
	while d < path.length:
		samples.append([d, path.sample_position(d), path.width_at(d)])
		d += 3.0
	var bad := []
	for i in samples.size():
		for j in range(i + 1, samples.size()):
			var di: float = samples[i][0]
			var dj: float = samples[j][0]
			var sep := dj - di
			if track.is_circuit:
				sep = minf(sep, path.length - sep)
			if sep < 45.0:
				continue
			var pi: Vector3 = samples[i][1]
			var pj: Vector3 = samples[j][1]
			if absf(pi.y - pj.y) > 6.5:
				continue
			var lim: float = (samples[i][2] + samples[j][2]) * 0.5 + 1.5
			if Vector2(pi.x - pj.x, pi.z - pj.z).length() < lim:
				if path.in_zone(di, "loop") or path.in_zone(dj, "loop"):
					continue
				bad.append("%.0f/%.0f" % [di, dj])
	TestHooks.check(bad.is_empty(), id + "_no_self_intersection", str(bad.slice(0, 6)))

	# kill_y
	var min_y := 1e9
	for s in samples:
		min_y = minf(min_y, s[1].y)
	TestHooks.check(track.kill_y < min_y - 1.5, id + "_kill_y", "kill %.1f min %.1f" % [track.kill_y, min_y])

	# wait for physics to register bodies
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var poses: Array = [[-1, track.get_start_transform()]]
	for i in track.checkpoint_count:
		poses.append([i, track.get_checkpoint_transform(i)])
	for pz in poses:
		var xf: Transform3D = pz[1]
		var q := PhysicsRayQueryParameters3D.create(xf.origin + xf.basis.y * 0.3, xf.origin - xf.basis.y * 5.0, 1)
		var hit := space.intersect_ray(q)
		var h := -1.0
		if not hit.is_empty():
			h = xf.origin.distance_to(hit["position"])
		TestHooks.check(absf(h - 0.6) < 0.06, "%s_spawn_height_%d" % [id, pz[0]], "h=%.3f" % h)
		TestHooks.check((-xf.basis.z).dot(-path.sample_transform(path.closest_distance(xf.origin)).basis.z) > 0.95, "%s_spawn_forward_%d" % [id, pz[0]], "")
	# gates span the road
	var span_ok := true
	for g in track.gates + [track.finish_gate]:
		var cs: CollisionShape3D = g.get_child(0)
		var gd: float = g.get_meta("distance")
		if (cs.shape as BoxShape3D).size.x < path.width_at(gd) + 1.0 or (cs.shape as BoxShape3D).size.y < 6.0:
			span_ok = false
	TestHooks.check(span_ok, id + "_gates_span_road", "")

	# stunts
	for l in track.data["loops"]:
		TestHooks.check(float(l["radius"]) >= 18.0, id + "_loop_radius", str(l["radius"]))
		var top_y := -1e9
		var base_y := path.sample_position(float(l["from"])).y
		var dl: float = l["from"]
		while dl < l["to"]:
			top_y = maxf(top_y, path.sample_position(dl).y)
			dl += 1.0
		TestHooks.check(absf(top_y - base_y - 2.0 * float(l["radius"])) < 1.5, id + "_loop_shape", "top %.1f above entry" % (top_y - base_y))
	for j in track.data["jumps"]:
		var vmin: float = j["v_min"] * 3.6
		TestHooks.check(vmin < 120.0, id + "_jump_min_speed", "%.0f km/h" % vmin)
		# flight distance at 210 km/h from the lip; road must run straight to there
		var v := float(j.get("check_kmh", 210.0)) / 3.6
		var th: float = j["angle"]
		# far case: flying at check_kmh until it comes down to the end of the landing ramp
		var h0: float = float(j.get("lip_y", j["h"])) - float(j.get("end_y", 0.0))
		var a := G_HALF / (v * v * cos(th) * cos(th))
		var xmax: float = (tan(th) + sqrt(tan(th) * tan(th) + 4.0 * a * h0)) / (2.0 * a)
		var lip_f := path.sample_transform(j["lip"])
		var hd := Vector3(-lip_f.basis.z.x, 0, -lip_f.basis.z.z).normalized()
		var land_f := path.sample_transform(float(j["lip"]) + xmax + 5.0)
		var hd2 := Vector3(-land_f.basis.z.x, 0, -land_f.basis.z.z).normalized()
		if not bool(j.get("finish", false)):   # after the finish arch the run is over
			TestHooks.check(rad_to_deg(hd.angle_to(hd2)) < 6.0, id + "_jump_runout", "xmax %.0f m, turn %.1f deg" % [xmax, rad_to_deg(hd.angle_to(hd2))])
		# at 150 km/h the car reaches the landing start (drop m below the lip)
		var v2 := 150.0 / 3.6
		var drop: float = j.get("drop", 0.0)
		var a2 := G_HALF / (v2 * v2 * cos(th) * cos(th))
		var x2: float = (tan(th) + sqrt(tan(th) * tan(th) + 4.0 * a2 * drop)) / (2.0 * a2)
		TestHooks.check(x2 > float(j["gap"]) + 3.0, id + "_jump_clears_at_150", "lands at %.0f m, gap %.0f" % [x2, j["gap"]])

	# probe run: a frozen Car pushed along the path must hit every checkpoint in order, then finish
	hits = []
	track.checkpoint_reached.connect(_on_cp)
	track.finish_reached.connect(_on_finish)
	var probe := Car.create(CarDefs.default_config("kaze"))
	probe.collision_layer = 2
	probe.collision_mask = 0
	probe.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	probe.freeze = true
	add_child(probe)
	var ds := track.get_start_pose_distance()
	var de := track.finish_distance + (path.length if track.is_circuit else 0.0) + 6.0
	d = ds
	while d < de:
		var f := path.sample_transform(d)
		probe.global_transform = Transform3D(f.basis, f.origin + f.basis.y * 0.8)
		await get_tree().physics_frame
		d += 1.5
	var expect: Array = []
	for i in track.checkpoint_count:
		expect.append(i)
	expect.append("F")
	TestHooks.check(hits == expect, id + "_probe_gates_in_order", "got %s" % str(hits))
	probe.queue_free()
	track.queue_free()
	await get_tree().physics_frame


const G_HALF := 9.81 * 0.5


func _on_cp(_car: Node, index: int) -> void:
	hits.append(index)


func _on_finish(car: Node) -> void:
	hits.append("F")
	if hits.size() == 1:
		print("  first finish at ", (car as Node3D).global_position)
