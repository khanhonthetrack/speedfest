extends Node3D
## Diagnostic: how smooth is the road? (owner: "on the road it feels bumpy")
## A) Geometry: raycasts the road collision every 0.25 m along the centerline (ordinary road
##    only: no loops, gaps, jumps) and reports the high-frequency vertical roughness: the
##    difference between the surface's short-scale (0.5 m) and long-scale (6 m) vertical curvature.
## B) Dynamics: the AutoDriver drives; reports the high-pass RMS of suspension compression and
##    body pitch/roll rate on ordinary road, versus a flat plane (--track=flat).
## Run: tools/run_scene.sh res://tests/physics/probe_road_bumps.tscn --headless -- --track=arena

var track: Track
var car: Car
var ai: AutoDriver
var track_id := "arena"
var tick := 0
var comp_hist: Array = []      # per tick: [c0, c1, c2, c3]
var rate_hist: Array = []      # per tick: Vector2(pitch rate, roll rate) in car space
var ok_hist: Array = []        # per tick: on ordinary road and grounded
var speed_hist: Array = []
const TICKS := 1500


func _ready() -> void:
	track_id = String(TestHooks.arg("track", "arena"))
	if track_id == "flat":
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(400, 1, 4000)
		cs.shape = box
		cs.position = Vector3(0, -0.5, -1900)
		sb.add_child(cs)
		add_child(sb)
		car = Car.create(CarDefs.default_config(String(TestHooks.arg("car", "kaze"))))
		add_child(car)
		car.teleport(Transform3D(Basis(), Vector3(0, 0.4, 0)))
		return
	track = Track.build(track_id)
	add_child(track)
	car = Car.create(CarDefs.default_config(String(TestHooks.arg("car", "kaze"))))
	track.apply_weather("dry")
	car.surface = track.surface
	add_child(car)
	ai = AutoDriver.new()
	ai.path = track.path
	car.add_child(ai)
	car.teleport(track.get_start_transform())
	ai.reset_tracking()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_geometry_report()


func _ordinary(d: float) -> bool:
	for z in track.path.zones:
		var k := String(z.get("kind", ""))
		if k in ["loop", "jump", "wallride", "boost"] and d >= float(z["from"]) - 15.0 and d <= float(z["to"]) + 15.0:
			return false
	return true


func _surface_point(d: float, lateral: float) -> Variant:
	var f := track.path.sample_transform(d)
	var from := f.origin + f.basis.y * 1.5 + f.basis.x * lateral
	var q := PhysicsRayQueryParameters3D.create(from, from - f.basis.y * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	return hit["position"]


func _geometry_report() -> void:
	var L := track.path.length
	var rough: Array[float] = []
	var worst := 0.0
	var worst_d := 0.0
	var d := 8.0
	while d < L - 8.0:
		if _ordinary(d):
			for lat in [-3.0, 0.0, 3.0]:
				var f := track.path.sample_transform(d)
				var up := f.basis.y
				var p0: Variant = _surface_point(d, lat)
				var a1: Variant = _surface_point(d - 0.5, lat)
				var b1: Variant = _surface_point(d + 0.5, lat)
				var a6: Variant = _surface_point(d - 6.0, lat)
				var b6: Variant = _surface_point(d + 6.0, lat)
				if p0 == null or a1 == null or b1 == null or a6 == null or b6 == null:
					continue
				var k1: float = ((a1 as Vector3) + (b1 as Vector3) - 2.0 * (p0 as Vector3)).dot(up) / 0.25
				var k6: float = ((a6 as Vector3) + (b6 as Vector3) - 2.0 * (p0 as Vector3)).dot(up) / 36.0
				var r := absf(k1 - k6)
				rough.append(r)
				if r > worst:
					worst = r
					worst_d = d
		d += 0.25
	rough.sort()
	if rough.is_empty():
		print("GEOM %s: no samples" % track_id)
		return
	if TestHooks.has_arg("detail"):
		var dd := float(TestHooks.arg("detail", worst_d))
		var x := dd - 6.0
		while x <= dd + 6.0:
			var f := track.path.sample_transform(x)
			var pc: Variant = _surface_point(x, 0.0)
			var h := 0.0 if pc == null else ((pc as Vector3) - f.origin).dot(f.basis.y)
			print("  d=%.2f surf_minus_frame=%.4f frame_y=%.3f up=%s" % [x, h, f.origin.y, str(f.basis.y)])
			x += 0.25
	print("GEOM %s samples=%d p50=%.4f p95=%.4f p99=%.4f max=%.4f at d=%.1f (1/m)" % [
		track_id, rough.size(), rough[rough.size() / 2], rough[int(rough.size() * 0.95)],
		rough[int(rough.size() * 0.99)], worst, worst_d])


func _physics_process(_delta: float) -> void:
	tick += 1
	if track_id == "flat":
		car.controls["throttle"] = 1.0 if car.get_speed_kmh() < 160.0 else 0.0
		car.controls["steer"] = 0.0
	var comp: PackedFloat32Array = car.get("_comp")
	comp_hist.append([comp[0], comp[1], comp[2], comp[3]])
	var w := car.global_transform.basis.inverse() * car.angular_velocity
	rate_hist.append(Vector2(w.x, w.z))
	speed_hist.append(car.get_speed_kmh())
	var ok := car.is_grounded() and car.get_speed_kmh() > 60.0
	if ok and track:
		ok = _ordinary(track.path.closest_distance(car.global_position))
	ok_hist.append(ok)
	if TestHooks.has_arg("trace"):
		var dd := track.path.closest_distance(car.global_position) if track else 0.0
		var sid := 0.0
		for i in 4:
			sid += float(car.get("_hit_n")[i].dot(car.global_transform.basis.y))
		print("TRACE %d %.2f %.1f %.4f %.4f %.4f %.4f %d %.3f %.3f" % [tick, dd, car.get_speed_kmh(), comp[0], comp[1], comp[2], comp[3], 1 if ok else 0, w.x, w.z])
	if tick >= TICKS:
		_dynamics_report()
		TestHooks.finish()


func _dynamics_report() -> void:
	var n := comp_hist.size()
	var win := 12
	var sum_c := 0.0
	var sum_r := 0.0
	var cnt := 0
	var max_c := 0.0
	var sp := 0.0
	for i in range(win, n - win):
		if not (ok_hist[i] and ok_hist[i - win] and ok_hist[i + win]):
			continue
		for wi in 4:
			var avg := 0.0
			for j in range(i - win, i + win + 1):
				avg += float(comp_hist[j][wi])
			avg /= float(2 * win + 1)
			var hp := float(comp_hist[i][wi]) - avg
			sum_c += hp * hp
			max_c = maxf(max_c, absf(hp))
		var ravg := Vector2.ZERO
		for j in range(i - win, i + win + 1):
			ravg += rate_hist[j]
		ravg /= float(2 * win + 1)
		var rhp: Vector2 = rate_hist[i] - ravg
		sum_r += rhp.length_squared()
		sp += float(speed_hist[i])
		cnt += 1
	if cnt == 0:
		print("DYN %s: no samples" % track_id)
		return
	print("DYN %s ticks=%d avg_kmh=%.0f comp_hp_rms=%.2f mm comp_hp_max=%.2f mm rate_hp_rms=%.3f rad/s" % [
		track_id, cnt, sp / cnt, sqrt(sum_c / (cnt * 4)) * 1000.0, max_c * 1000.0, sqrt(sum_r / cnt)])
