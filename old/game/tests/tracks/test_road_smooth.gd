extends Node3D
## Regression test for the "bumpy road" washboard (owner feedback, session 4): the road deck's
## collision must be smooth at wheel scale on ordinary road (no loops, jumps, wall rides, boosts).
## Raycasts the deck every 0.25 m at 3 lateral offsets and compares the short-scale (0.5 m) with
## the long-scale (6 m) vertical curvature. Full-width twisting quads used to fold into a ±12 cm
## ridge every 1.5 m on bank ramps (p95 ~0.45 1/m); the subdivided deck is ~0.02.
## Args: --track=all|<id>

const P95_MAX := 0.06
const P99_MAX := 0.12


func _ready() -> void:
	var which: String = TestHooks.arg("track", "all")
	var ids: Array = TrackDefs.IDS if which == "all" else [which]
	for id in ids:
		var track := Track.build(id, false)
		add_child(track)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var r := _roughness(track)
		print("%s deck roughness samples=%d p50=%.4f p95=%.4f p99=%.4f max=%.4f at d=%.1f" % [id, r["n"], r["p50"], r["p95"], r["p99"], r["max"], r["max_d"]])
		TestHooks.check(r["n"] > 1000, id + "_samples", str(r["n"]))
		TestHooks.check(r["p95"] < P95_MAX, id + "_deck_p95", "%.4f" % r["p95"])
		TestHooks.check(r["p99"] < P99_MAX, id + "_deck_p99", "%.4f" % r["p99"])
		track.queue_free()
		await get_tree().physics_frame
	TestHooks.finish()


static func ordinary(path: TrackPath, d: float) -> bool:
	for z in path.zones:
		var k := String(z.get("kind", ""))
		if k in ["loop", "jump", "wallride", "boost"] and d >= float(z["from"]) - 15.0 and d <= float(z["to"]) + 15.0:
			return false
	return true


func _surface(path: TrackPath, d: float, lateral: float) -> Variant:
	var f := path.sample_transform(d)
	var from := f.origin + f.basis.y * 1.5 + f.basis.x * lateral
	var q := PhysicsRayQueryParameters3D.create(from, from - f.basis.y * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return null if hit.is_empty() else hit["position"]


func _roughness(track: Track) -> Dictionary:
	var path := track.path
	var rough: Array[float] = []
	var worst := 0.0
	var worst_d := 0.0
	var d := 8.0
	while d < path.length - 8.0:
		if ordinary(path, d):
			var up := path.sample_transform(d).basis.y
			# lateral offsets off the deck's vertex columns (a ray exactly on an edge can slip through)
			for lat in [-3.07, 0.13, 3.11]:
				var pts: Array = []
				for off in [0.0, -0.5, 0.5, -6.0, 6.0]:
					pts.append(_surface(path, d + off + 0.037, lat))
				if pts.has(null):
					continue
				var k1: float = ((pts[1] as Vector3) + (pts[2] as Vector3) - 2.0 * (pts[0] as Vector3)).dot(up) / 0.25
				var k6: float = ((pts[3] as Vector3) + (pts[4] as Vector3) - 2.0 * (pts[0] as Vector3)).dot(up) / 36.0
				var r := absf(k1 - k6)
				rough.append(r)
				if r > worst:
					worst = r
					worst_d = d
		d += 0.25
	rough.sort()
	var n := rough.size()
	if n == 0:
		return {"n": 0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0, "max_d": 0.0}
	return {"n": n, "p50": rough[n / 2], "p95": rough[int(n * 0.95)], "p99": rough[int(n * 0.99)], "max": worst, "max_d": worst_d}
