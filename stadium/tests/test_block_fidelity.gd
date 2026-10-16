extends Node3D
## Fidelity of the recreated blocks' collision against measurements of the originals.
## The measurements (block-local collision meshes, JSON per shape) come from a local TMNF install
## (tools/research/tmnf/extract_surf.py) and are never committed; without --meas this test skips.
## For each shape: vertical rays every --step m over the footprint (first hit from above) and
## horizontal rays along x and z at several heights; a sample agrees within --tol m.
## Run: stadium/tools/run.sh res://tests/test_block_fidelity.tscn --headless -- --meas=/abs/meas [--only=Circuit/]

const FAR := 400.0

var lib := TmBlockLib.new()
var _jobs: Array = []        # [shape, our body origin, measured body origin, footprint (x, z) m]


func _ready() -> void:
	var dir := String(TestHooks.arg("meas", ""))
	if dir.is_empty():
		print("TEST_SKIP fidelity: pass --meas=/path/to/measurements")
		TestHooks.finish()
		return
	var only := String(TestHooks.arg("only", ""))
	var d := DirAccess.open(dir)
	if d == null:
		TestHooks.fail("fidelity_meas_dir", dir)
		TestHooks.finish()
		return
	var files := d.get_files()
	files.sort()
	var slot := 0
	for f in files:
		if not f.ends_with(".json"):
			continue
		var shape := f.trim_suffix(".json").replace("__", "/")
		if not only.is_empty() and not shape.begins_with(only):
			continue
		var ours := lib.make(shape, {}, shape.contains("Ground"))
		if ours == null:
			continue
		var meas := _measured_body(dir.path_join(f))
		if meas == null:
			continue
		# side by side, far apart, at the same height
		var o1 := Vector3(-float(slot) * 1000.0, 0, 0)
		var o2 := o1 + Vector3(0, 0, 500.0)
		ours.position = o1
		meas.position = o2
		add_child(ours)
		add_child(meas)
		_jobs.append([shape, o1, o2, meas.get_meta("extent")])
		slot += 1
	if _jobs.is_empty():
		print("TEST_SKIP fidelity: no shape both measured and recreated")
		TestHooks.finish()


func _measured_body(path: String) -> StaticBody3D:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var m: Variant = JSON.parse_string(f.get_as_text())
	if not (m is Dictionary) or not m.has("verts"):
		return null
	var verts: Array = m["verts"]
	var faces := PackedVector3Array()
	var ext := Vector2.ZERO
	for t in m["tris"]:
		for k in 3:
			var v: Array = verts[int(t[k])]
			faces.append(Vector3(-float(v[0]), float(v[1]), float(v[2])))
			ext = Vector2(maxf(ext.x, float(v[0])), maxf(ext.y, float(v[2])))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	body.set_meta("extent", Vector2(ceilf(ext.x / 32.0) * 32.0, ceilf(ext.y / 32.0) * 32.0))
	return body


var _frames := 0


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 3 or _jobs.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var step := float(TestHooks.arg("step", 1.0))
	var tol := float(TestHooks.arg("tol", 0.15))
	var min_ok := float(TestHooks.arg("min", 0.97))
	for job in _jobs:
		var shape: String = job[0]
		var o1: Vector3 = job[1]
		var o2: Vector3 = job[2]
		var ext: Vector2 = job[3]
		var n := 0
		var ok := 0
		var worst := 0.0
		var worst_at := Vector3.ZERO
		# vertical rays (Godot x = -TMNF x)
		var x := step * 0.5
		while x < ext.x:
			var z := step * 0.5
			while z < ext.y:
				var p := Vector3(-x, 0, z)
				var h1 := _hit(space, o1 + p + Vector3.UP * 100.0, o1 + p - Vector3.UP * 20.0)
				var h2 := _hit(space, o2 + p + Vector3.UP * 100.0, o2 + p - Vector3.UP * 20.0)
				n += 1
				var e := _err(h1, h2, o1, o2)
				if e <= tol:
					ok += 1
				elif e > worst:
					worst = e
					worst_at = p
				z += step
			x += step
		# horizontal rays along x and z at a few heights through the footprint
		for y in [1.5, 4.0, 9.0, 13.0]:
			var t := step * 2.0
			while t < maxf(ext.x, ext.y):
				for ray in [[Vector3(20, y, t), Vector3(-ext.x - 20, y, t)], [Vector3(-t, y, -20), Vector3(-t, y, ext.y + 20)]]:
					var h1 := _hit(space, o1 + ray[0], o1 + ray[1])
					var h2 := _hit(space, o2 + ray[0], o2 + ray[1])
					n += 1
					var e := _err(h1, h2, o1, o2)
					if e <= tol:
						ok += 1
					elif e > worst:
						worst = e
						worst_at = ray[0]
				t += step * 2.0
		if TestHooks.has_arg("probe"):
			var pv := String(TestHooks.arg("probe", "")).split(",")
			var pp := Vector3(-float(pv[0]), 0, float(pv[1]))
			print("  PROBE %s at TMNF (%s, %s): ours %s measured %s" % [shape, pv[0], pv[1],
				_hit(space, o1 + pp + Vector3.UP * 100.0, o1 + pp - Vector3.UP * 20.0) - o1,
				_hit(space, o2 + pp + Vector3.UP * 100.0, o2 + pp - Vector3.UP * 20.0) - o2])
		var share := float(ok) / maxf(1.0, n)
		print("FIDELITY %-46s %5.1f%% of %d samples within %.2f m (worst %.2f m near %s)" % [shape, share * 100.0, n, tol, worst, worst_at])
		TestHooks.check(share >= min_ok, "fidelity_%s" % shape, "%.1f%%" % (share * 100.0))
	TestHooks.finish()


func _hit(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.hit_back_faces = true
	var r := space.intersect_ray(q)
	return Vector3(INF, INF, INF) if r.is_empty() else (r.position as Vector3)


func _err(h1: Vector3, h2: Vector3, o1: Vector3, o2: Vector3) -> float:
	var m1 := h1.x == INF
	var m2 := h2.x == INF
	if m1 and m2:
		return 0.0
	if m1 != m2:
		# a lone hit on the terrain plane (1 m block-local: ground blocks keep only the terrain
		# they displace; the map's ground is built separately) doesn't count
		var h := (h2 - o2) if m1 else (h1 - o1)
		if absf(h.y - 1.0) < 0.02:
			return 0.0
		return 99.0
	return ((h1 - o1) - (h2 - o2)).length()
