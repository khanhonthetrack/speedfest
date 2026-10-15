extends Node
## RemoteCar interpolation with synthetic snapshots: a car moving at 50 m/s on a circle, sent at
## 20 Hz with network jitter, a burst of packet loss, then silence.
## Run: tools/run_scene.sh res://tests/race/test_remote_car.tscn --headless -- --frames=100

const SPEED := 50.0
const RADIUS := 120.0

var now_ms := 0.0


func truth(ts: float) -> Vector3:
	var a := SPEED * ts / 1000.0 / RADIUS
	return Vector3(cos(a) * RADIUS, 0.5, sin(a) * RADIUS)


func truth_vel(ts: float) -> Vector3:
	var a := SPEED * ts / 1000.0 / RADIUS
	return Vector3(-sin(a), 0, cos(a)) * SPEED


func snap(ts: float) -> Dictionary:
	var p := truth(ts)
	var v := truth_vel(ts)
	var basis := Basis.looking_at(v.normalized(), Vector3.UP)
	var q := basis.get_rotation_quaternion()
	return {"t": int(ts), "ts": int(ts) + 5000, "p": [p.x, p.y, p.z], "q": [q.x, q.y, q.z, q.w],
		"v": [v.x, v.y, v.z], "st": 0.2, "rpm": 0.6, "fl": 16}


func _ready() -> void:
	var rc := RemoteCar.new()
	add_child(rc)
	rc.setup(7, "Tester", CarDefs.default_config("brute"))
	rc.set_time_source(func() -> float: return now_ms)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Packets sent every 50 ms (sender ts), arriving with 40..110 ms latency (jitter 70 ms).
	var packets: Array = []
	for i in 200:
		var ts := i * 50.0
		if i >= 120 and i < 124:
			continue # 4 lost packets (200 ms gap)
		packets.append([ts + rng.randf_range(40.0, 110.0), ts])
	packets.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var max_err := 0.0
	var sum_err := 0.0
	var n := 0
	var max_jump := 0.0
	var prev := Vector3.INF
	var pi := 0
	var max_err_loss := 0.0
	# Simulate 60 fps rendering for 9.5 s.
	for frame in 570:
		now_ms = frame * 1000.0 / 60.0
		while pi < packets.size() and packets[pi][0] <= now_ms:
			var s := snap(packets[pi][1])
			s["rx_ms"] = int(packets[pi][0])
			rc.push_state(s)
			pi += 1
		if not rc.update_pose():
			continue
		var pos := rc.global_position
		# The car should be shown ~ (min latency + 100 ms) in the past.
		var shown_ts := now_ms - 40.0 - RemoteCar.INTERP_DELAY_MS
		if shown_ts > 500.0:
			var err := pos.distance_to(truth(shown_ts))
			if shown_ts > 6000.0 and shown_ts < 6400.0:
				max_err_loss = maxf(max_err_loss, err)
			else:
				max_err = maxf(max_err, err)
				sum_err += err
				n += 1
		if prev != Vector3.INF:
			max_jump = maxf(max_jump, pos.distance_to(prev))
		prev = pos
	var avg := sum_err / maxi(n, 1)
	# 50 m/s at 60 fps = 0.83 m per frame. Frame steps should be close to that (smooth).
	TestHooks.check(avg < 0.6, "interp_avg_error", "avg %.3f m" % avg)
	TestHooks.check(max_err < 2.5, "interp_max_error", "max %.3f m" % max_err)
	TestHooks.check(max_jump < 1.5, "interp_smooth", "max frame step %.3f m (expected ~0.83)" % max_jump)
	TestHooks.check(max_err_loss < 6.0, "packet_loss_extrapolation", "max %.3f m during loss" % max_err_loss)
	TestHooks.check(rc.visible, "visible_while_receiving")
	# Silence: hidden after 3 s.
	now_ms += 1000.0
	rc.update_pose()
	TestHooks.check(rc.visible, "visible_after_1s_silence")
	now_ms += 2500.0
	rc.update_pose()
	TestHooks.check(not rc.visible, "hidden_after_3s_silence")
	# Teleport (respawn) between snapshots snaps instead of sliding across the map.
	var rc2 := RemoteCar.new()
	add_child(rc2)
	rc2.setup(8, "Jumper", CarDefs.default_config("kaze"))
	rc2.set_time_source(func() -> float: return now_ms)
	var base := now_ms
	rc2.push_state({"ts": 0, "rx_ms": int(base), "p": [0, 0, 0], "q": [0, 0, 0, 1], "v": [0, 0, 0], "fl": 0})
	rc2.push_state({"ts": 50, "rx_ms": int(base + 50), "p": [500, 0, 0], "q": [0, 0, 0, 1], "v": [0, 0, 0], "fl": 0})
	var mid := rc2.sample(20.0)
	var midp: Vector3 = (mid["xf"] as Transform3D).origin
	TestHooks.check(midp.x < 1.0 or midp.x > 499.0, "teleport_snaps", str(midp))
	# Sender without ts (rx_ms only) still works.
	var rc3 := RemoteCar.new()
	add_child(rc3)
	rc3.setup(9, "NoTs", CarDefs.default_config("veloce"))
	rc3.set_time_source(func() -> float: return now_ms)
	for i in 10:
		rc3.push_state({"rx_ms": int(now_ms + i * 50), "p": [i * 2.5, 0, 0], "q": [0, 0, 0, 1], "v": [50, 0, 0], "fl": 0})
	now_ms += 450.0
	rc3.update_pose()
	TestHooks.check(rc3.visible and absf(rc3.global_position.x - 17.5) < 1.5, "rx_only_fallback", str(rc3.global_position))
	# Garbage snapshot is ignored.
	rc3.push_state({"p": "nope"})
	rc3.push_state({"q": [1, 2]})
	TestHooks.ok("garbage_ignored")
	TestHooks.finish()
