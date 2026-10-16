extends Node
## Ghosts and best times (no TMNF install needed): TmGhost records a run and plays it back between
## its samples, and saves and loads it; TmRecords keeps the best run per track (in a test folder);
## the HUD's split differences.


func _ready() -> void:
	TestHooks.args["records"] = "user://test_records"
	TmRecords.clear()
	_ghost()
	_records()
	_deltas()
	TmRecords.clear()
	TestHooks.finish()


## 1 s of 10 ms ticks: a car going 20 m/s along +z while turning 1 rad/s.
static func _run() -> TmGhost:
	var g := TmGhost.new()
	for t in range(0, 1001, 10):
		g.record(t, Transform3D(Basis(Vector3.UP, t * 0.001), Vector3(0, 1, t * 0.02)), 0.5, 20.0)
	return g


func _ghost() -> void:
	var g := _run()
	TestHooks.check(g.count() == 1000 / TmGhost.INTERVAL_MS + 1, "ghost_samples_every_interval", "%d" % g.count())
	var s := g.sample(510.0)
	var xf: Transform3D = s["xform"]
	TestHooks.check(absf(xf.origin.z - 10.2) < 1e-3 and absf(xf.origin.y - 1.0) < 1e-4, "ghost_position_between_samples",
		"%s" % xf.origin)
	var yaw := xf.basis.get_euler().y
	TestHooks.check(absf(yaw - 0.51) < 1e-3, "ghost_rotation_between_samples", "%.4f" % yaw)
	TestHooks.check(absf(float(s["speed"]) - 20.0) < 1e-4 and absf(float(s["steer"]) - 0.5) < 1e-4, "ghost_speed_steer")
	var end: Transform3D = g.sample(5000.0)["xform"]
	TestHooks.check(absf(end.origin.z - 20.0) < 1e-3, "ghost_holds_its_last_pose", "%s" % end.origin)
	g.finish_ms = 1000
	DirAccess.make_dir_recursive_absolute(TmRecords.dir())
	var path := TmRecords.dir().path_join("roundtrip.ghost")
	TestHooks.check(g.save(path), "ghost_saves")
	var back := TmGhost.load_file(path)
	TestHooks.check(back != null and back.count() == g.count() and back.finish_ms == 1000 and back.length_ms() == 1000,
		"ghost_loads", "%s" % ("null" if back == null else "%d samples, finish %d" % [back.count(), back.finish_ms]))
	if back != null:
		var a: Transform3D = g.sample(737.0)["xform"]
		var b: Transform3D = back.sample(737.0)["xform"]
		TestHooks.check(a.origin.distance_to(b.origin) < 1e-4 and a.basis.z.distance_to(b.basis.z) < 1e-4, "ghost_roundtrip_same")
	TestHooks.check(TmGhost.load_file(TmRecords.dir().path_join("missing.ghost")) == null, "ghost_missing_file")


func _records() -> void:
	var ch := TmChallenge.new()
	ch.uid = "TestTrack_1"
	ch.name = "Test track"
	TestHooks.check(TmRecords.best(ch).is_empty() and TmRecords.ghost(ch) == null, "records_none_yet")
	var g := _run()
	g.finish_ms = 30000
	TestHooks.check(TmRecords.submit(ch, 30000, [10000, 30000], g), "records_first_run_is_a_record")
	var b := TmRecords.best(ch)
	var splits: Array = b.get("splits", [])
	TestHooks.check(int(b.get("time_ms", -1)) == 30000 and splits.size() == 2 and int(splits[0]) == 10000,
		"records_best_saved", "%s" % b)
	TestHooks.check(not TmRecords.submit(ch, 31000, [11000, 31000], g), "records_slower_run_kept_out")
	TestHooks.check(not TmRecords.submit(ch, 30000, [9000, 30000], g), "records_tie_kept_out")
	g.finish_ms = 29000
	TestHooks.check(TmRecords.submit(ch, 29000, [9500, 29000], g), "records_faster_run_replaces")
	var gh := TmRecords.ghost(ch)
	TestHooks.check(int(TmRecords.best(ch).get("time_ms", -1)) == 29000 and gh != null and gh.finish_ms == 29000,
		"records_ghost_follows_the_record")
	var ch2 := TmChallenge.new()
	ch2.uid = "a/b:c d"
	TestHooks.check(TmRecords.key(ch2) == "a_b_c_d", "records_key_file_safe", TmRecords.key(ch2))
	TestHooks.check(not TmRecords.submit(ch2, 0, [], null), "records_no_time_no_record")


func _deltas() -> void:
	TestHooks.check(TmRaceHud.delta_text(-120) == "-0.12" and TmRaceHud.delta_text(1050) == "+1.05"
		and TmRaceHud.delta_text(0) == "-0.00" and TmRaceHud.delta_text(61234) == "+61.23", "hud_split_deltas",
		"%s %s %s" % [TmRaceHud.delta_text(-120), TmRaceHud.delta_text(1050), TmRaceHud.delta_text(61234)])
