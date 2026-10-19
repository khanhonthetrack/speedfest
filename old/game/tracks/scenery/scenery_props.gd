class_name SceneryProps
extends RefCounted
## Procedural prop meshes shared by the kits (cached, built once per run).

static var _cache: Dictionary = {}


static func _cached(key: String, builder: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


## 1 m cube with its base at y = 0 (buildings; scaled per instance).
static func unit_box() -> Mesh:
	return _cached("unit_box", func() -> Mesh:
		var m := SceneryMesh.new()
		m.add_box(Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), Vector3.ONE, Color.WHITE)
		return m.commit())


## Centred 1 m cube (generic blocks).
static func center_box() -> Mesh:
	return _cached("center_box", func() -> Mesh:
		var m := SceneryMesh.new()
		m.add_box(Transform3D.IDENTITY, Vector3.ONE, Color.WHITE, Vector2.ZERO, false)
		return m.commit())


## Ground quad 1x1 in XZ facing up (light pools, puddles).
static func ground_quad() -> Mesh:
	return _cached("ground_quad", func() -> Mesh:
		var m := SceneryMesh.new()
		m.add_quad(Vector3(-0.5, 0, 0.5), Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Color.WHITE)
		return m.commit())


## Open cone for beams: apex at the origin, opening along -Y, length 1, radius 1 at the end.
## UV.y = 0 at the apex .. 1 at the end.
static func beam_cone(sides := 12) -> Mesh:
	return _cached("beam_cone_%d" % sides, func() -> Mesh:
		var m := SceneryMesh.new()
		for i in sides + 1:
			var a := TAU * float(i) / sides
			var d := Vector3(cos(a), 0, sin(a))
			m._vert(d * 0.04, d, Color.WHITE, Vector2(float(i) / sides, 0.0), Vector2.ZERO)
			m._vert(d + Vector3(0, -1, 0), d, Color.WHITE, Vector2(float(i) / sides, 1.0), Vector2.ZERO)
		for i in sides:
			var k := i * 2
			m.idx.append_array([k, k + 1, k + 3, k, k + 3, k + 2])
		return m.commit())


## Street lamp pole (base at origin, arm reaching towards -X over the road), metal parts.
static func street_lamp_pole() -> Mesh:
	return _cached("lamp_pole", func() -> Mesh:
		var m := SceneryMesh.new()
		var col := Color(0.22, 0.23, 0.25)
		m.add_cylinder(Transform3D.IDENTITY, 0.16, 0.1, 9.0, 8, col)
		m.add_box(Transform3D(Basis.IDENTITY, Vector3(-1.4, 8.9, 0)), Vector3(2.9, 0.14, 0.14), col)
		m.add_box(Transform3D(Basis.IDENTITY, Vector3(-2.75, 8.8, 0)), Vector3(0.9, 0.22, 0.4), col)
		m.add_box(Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)), Vector3(0.45, 0.8, 0.45), col)
		return m.commit())


## Emissive lamp head (pairs with street_lamp_pole), small panel under the arm end.
static func street_lamp_head() -> Mesh:
	return _cached("lamp_head", func() -> Mesh:
		var m := SceneryMesh.new()
		m.add_box(Transform3D(Basis.IDENTITY, Vector3(-2.75, 8.66, 0)), Vector3(0.8, 0.06, 0.32), Color.WHITE, Vector2.ZERO, false)
		return m.commit())


## Thin vertical post with a reflector band (coast delineators). Height 1.1 m.
static func delineator() -> Mesh:
	return _cached("delineator", func() -> Mesh:
		var m := SceneryMesh.new()
		m.add_box(Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), Vector3(0.12, 1.1, 0.16), Color(0.85, 0.85, 0.82))
		m.add_box(Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)), Vector3(0.13, 0.12, 0.17), Color(0.1, 0.1, 0.1))
		return m.commit())


static func delineator_reflector() -> Mesh:
	return _cached("delineator_refl", func() -> Mesh:
		var m := SceneryMesh.new()
		m.add_box(Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)), Vector3(0.14, 0.09, 0.18), Color.WHITE, Vector2.ZERO, false)
		return m.commit())


## Noisy rock (displaced icosphere), radius ~1, vertex-colored grey/brown.
static func rock(variant: int) -> Mesh:
	return _cached("rock_%d" % variant, func() -> Mesh:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7919 * (variant + 1)
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 10
		sm.rings = 6
		var arr := sm.get_mesh_arrays()
		var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var noise := FastNoiseLite.new()
		noise.seed = variant * 31 + 5
		noise.frequency = 0.9
		var flat := rng.randf_range(0.45, 0.8)
		for i in pv.size():
			var p := pv[i]
			var k := 1.0 + noise.get_noise_3dv(p * 1.3) * 0.45
			p *= k
			p.y *= flat
			if p.y < -0.2:
				p.y = -0.2 + (p.y + 0.2) * 0.3
			pv[i] = p
		# flat-shade: de-index and use face normals
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var m := SceneryMesh.new()
		for t in range(0, idx.size(), 3):
			var a := pv[idx[t]]
			var b := pv[idx[t + 1]]
			var c := pv[idx[t + 2]]
			var shade := 0.8 + 0.25 * noise.get_noise_3dv((a + b + c) * 2.0)
			var col := Color(0.42, 0.37, 0.34) * shade
			col.a = 1.0
			m.add_tri(a, b, c, col)
		return m.commit())


## Palm tree: curved trunk + drooping fronds, vertex colors. Height ~ 9-12 m.
static func palm(variant: int) -> Mesh:
	return _cached("palm_%d" % variant, func() -> Mesh:
		var rng := RandomNumberGenerator.new()
		rng.seed = 104729 * (variant + 3)
		var m := SceneryMesh.new()
		var h := rng.randf_range(8.5, 12.0)
		var lean := rng.randf_range(0.8, 2.6)
		var segs := 7
		var trunk := Color(0.36, 0.28, 0.2)
		var prev := Vector3.ZERO
		var top := Vector3.ZERO
		for s in segs:
			var t0 := float(s) / segs
			var t1 := float(s + 1) / segs
			var p0 := Vector3(lean * t0 * t0, h * t0, 0)
			var p1 := Vector3(lean * t1 * t1, h * t1, 0)
			var dir := (p1 - p0).normalized()
			var b := Basis(dir.cross(Vector3.BACK).normalized(), dir, Vector3.BACK)
			b = Basis(b.x, b.y, b.x.cross(b.y).normalized())
			var r0 := lerpf(0.26, 0.17, t0)
			var r1 := lerpf(0.26, 0.17, t1)
			var shade := 0.85 + 0.3 * float(s % 2)
			m.add_cylinder(Transform3D(b, p0), r0, r1, (p1 - p0).length() * 1.04, 6, trunk * shade, Vector2(0, t0), false)
			prev = p1
			top = p1
		# coconuts / crown
		m.add_box(Transform3D(Basis.IDENTITY, top + Vector3(0, -0.15, 0)), Vector3(0.6, 0.45, 0.6), Color(0.25, 0.2, 0.08), Vector2(0, 1))
		var fronds := rng.randi_range(8, 11)
		for f in fronds:
			var ang := TAU * float(f) / fronds + rng.randf_range(-0.2, 0.2)
			var dir := Vector3(cos(ang), 0, sin(ang))
			var side := dir.cross(Vector3.UP).normalized()
			var flen := rng.randf_range(3.6, 5.0)
			var lift := rng.randf_range(0.5, 1.4)
			var green := Color(0.16, 0.3, 0.09).lerp(Color(0.32, 0.38, 0.12), rng.randf())
			var steps := 6
			for k in steps:
				var a0 := float(k) / steps
				var a1 := float(k + 1) / steps
				var q0 := top + dir * flen * a0 + Vector3.UP * (lift * a0 - 2.4 * a0 * a0)
				var q1 := top + dir * flen * a1 + Vector3.UP * (lift * a1 - 2.4 * a1 * a1)
				var w0 := sin(PI * minf(a0 * 1.15, 1.0)) * 0.75 + 0.05
				var w1 := sin(PI * minf(a1 * 1.15, 1.0)) * 0.75 + 0.05
				var droop0 := Vector3.DOWN * w0 * 0.35
				var droop1 := Vector3.DOWN * w1 * 0.35
				var sway := Vector2(0, 0.6 + 0.4 * a1)
				# two halves (V-shaped leaf) so it reads from above and below
				m.add_quad(q0 + side * w0 + droop0, q0, q1, q1 + side * w1 + droop1, green, sway)
				m.add_quad(q0, q0 - side * w0 + droop0, q1 - side * w1 + droop1, q1, green * 0.85, sway)
		return m.commit())


## Floodlight tower: lattice-ish mast with a lamp bank frame at the top (lamps separate).
static func flood_tower(height: float) -> Mesh:
	return _cached("flood_tower_%d" % int(height), func() -> Mesh:
		var m := SceneryMesh.new()
		var col := Color(0.16, 0.16, 0.2)
		m.add_cylinder(Transform3D.IDENTITY, 1.2, 0.6, height, 8, col)
		for i in 6:
			var y := height * (0.15 + 0.14 * i)
			m.add_box(Transform3D(Basis.IDENTITY, Vector3(0, y, 0)), Vector3(2.6 - i * 0.2, 0.3, 2.6 - i * 0.2), col * 0.8)
		m.add_box(Transform3D(Basis.IDENTITY, Vector3(0, height + 2.5, -0.5)), Vector3(12.0, 6.0, 0.8), col * 0.7)
		return m.commit())


## Lamp bank (emissive) matching flood_tower(): grid of lamp boxes on the -Z face... facing +Z.
static func flood_lamps(height: float) -> Mesh:
	return _cached("flood_lamps_%d" % int(height), func() -> Mesh:
		var m := SceneryMesh.new()
		for ix in 6:
			for iy in 3:
				var p := Vector3(-5.0 + ix * 2.0, height + 0.8 + iy * 1.7, 0.0)
				m.add_box(Transform3D(Basis.IDENTITY, p), Vector3(1.6, 1.3, 0.25), Color.WHITE)
		return m.commit())
