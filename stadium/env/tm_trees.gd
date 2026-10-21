class_name TmTrees
extends RefCounted
## Street trees for the city (our own, in code): a tapering trunk, three boughs and a crown of
## lumpy leaf blobs (env/tm_foliage.gdshader: clumps, a silhouette the sky breaks through, light
## through the leaves, a sway in the wind). A planting is one MultiMesh (one draw for its trunks,
## one for its crowns), each tree turned, sized and coloured its own way.
##
##   var trees := TmTrees.planting([Transform3D(...), ...], rng)   # feet at the transforms

const VARIANTS := 3                 ## crown shapes (each planting draws from them)

static var _meshes: Array[ArrayMesh] = []
static var _bark: StandardMaterial3D
static var _leaves: ShaderMaterial


## One tree of a variant: its trunk (surface 0) and crown (surface 1); about 9 m tall, its foot at
## the origin.
static func mesh(variant := 0) -> ArrayMesh:
	if _meshes.is_empty():
		for k in VARIANTS:
			_meshes.append(_build(k))
	return _meshes[variant % VARIANTS]


static func _build(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7001 + variant * 13
	var trunk := TmTower.Builder.new()
	_limb(trunk, Vector3.ZERO, Vector3(0.0, 4.2, 0.0), 0.22, 0.14)
	var crown_at := Vector3(0.0, 5.6, 0.0)
	for k in 3:
		var a := TAU * (k / 3.0 + rng.randf() * 0.2)
		var tip := Vector3(cos(a) * 1.6, 5.8 + rng.randf() * 0.8, sin(a) * 1.6)
		_limb(trunk, Vector3(0.0, 3.6 + k * 0.3, 0.0), tip, 0.12, 0.05)
	var crown := TmTower.Builder.new()
	var blobs := 6 + variant
	for k in blobs:
		var a := TAU * k / blobs + rng.randf() * 0.6
		var r := 1.0 + rng.randf() * 1.0
		var c := crown_at + Vector3(cos(a) * r, rng.randf_range(-0.6, 1.6), sin(a) * r)
		_blob(crown, c, rng.randf_range(1.5, 2.2), rng)
	_blob(crown, crown_at + Vector3(0.0, 1.5, 0.0), 2.0, rng)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var m := ArrayMesh.new()
	for b: TmTower.Builder in [trunk, crown]:
		arr[Mesh.ARRAY_VERTEX] = b.v
		arr[Mesh.ARRAY_NORMAL] = b.n
		arr[Mesh.ARRAY_TEX_UV] = b.uv
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _bark_material())
	m.surface_set_material(1, _leaf_material())
	return m


## A tapering six-sided limb from a to b.
static func _limb(b: TmTower.Builder, a: Vector3, e: Vector3, r0: float, r1: float) -> void:
	var axis := (e - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	var up := side.cross(axis)
	for i in 6:
		var t0 := TAU * i / 6.0
		var t1 := TAU * (i + 1) / 6.0
		var n0 := side * cos(t0) + up * sin(t0)
		var n1 := side * cos(t1) + up * sin(t1)
		var p0 := a + n0 * r0
		var p1 := a + n1 * r0
		var q0 := e + n0 * r1
		var q1 := e + n1 * r1
		b.tri3(p0, q1, p1, n0, n1, n1, Vector2(i, 0), Vector2(i + 1, 1), Vector2(i + 1, 0))
		b.tri3(p0, q0, q1, n0, n0, n1, Vector2(i, 0), Vector2(i, 1), Vector2(i + 1, 1))


## A lumpy ball of leaves: an icosahedron split once, its points pushed in and out.
static func _blob(b: TmTower.Builder, c: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var vs: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var fs := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
		[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for i in vs.size():
		vs[i] = vs[i].normalized()
	# split each face in four (the midpoints shared)
	var mids := {}
	var faces := []
	for f: Array in fs:
		var m := []
		for k in 3:
			var a: int = f[k]
			var e: int = f[(k + 1) % 3]
			var key := Vector2i(mini(a, e), maxi(a, e))
			if not mids.has(key):
				mids[key] = vs.size()
				vs.append(((vs[a] + vs[e]) * 0.5).normalized())
			m.append(mids[key])
		faces.append([f[0], m[0], m[2]])
		faces.append([f[1], m[1], m[0]])
		faces.append([f[2], m[2], m[1]])
		faces.append([m[0], m[1], m[2]])
	var lumps: Array[float] = []
	for i in vs.size():
		lumps.append(r * (0.78 + rng.randf() * 0.4) * (0.8 if vs[i].y < -0.3 else 1.0))
	for f: Array in faces:
		var p := []
		var n := []
		for k: int in [0, 2, 1]:                     # clockwise from outside
			var d: Vector3 = vs[f[k]]
			p.append(c + d * lumps[f[k]])
			n.append(d)
		b.tri3(p[0], p[1], p[2], n[0], n[1], n[2], Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)


static func _bark_material() -> StandardMaterial3D:
	if _bark == null:
		_bark = StandardMaterial3D.new()
		_bark.albedo_color = Color(0.22, 0.18, 0.14)
		_bark.roughness = 0.95
		_bark.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _bark


static func _leaf_material() -> ShaderMaterial:
	if _leaves == null:
		_leaves = ShaderMaterial.new()
		_leaves.shader = preload("res://env/tm_foliage.gdshader")
	return _leaves


## Trees standing at `feet` (transforms of their feet; turned and sized there), one draw per
## variant for trunks and crowns; each its own green (a little yellower or bluer).
static func planting(feet: Array, rng: RandomNumberGenerator, shadows := true, end := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Trees"
	var groups := []
	for k in VARIANTS:
		groups.append([])
	for xf: Transform3D in feet:
		groups[rng.randi() % VARIANTS].append(xf)
	for k in VARIANTS:
		var g: Array = groups[k]
		if g.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh(k)
		mm.instance_count = g.size()
		for i in g.size():
			var xf: Transform3D = g[i]
			var s := rng.randf_range(0.8, 1.25)
			xf.basis = xf.basis * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
			mm.set_instance_transform(i, xf)
			var hue := rng.randf_range(-1.0, 1.0)
			mm.set_instance_custom_data(i, Color(0.55 + 0.1 * hue, 0.62 + 0.05 * rng.randf(), 0.5 - 0.1 * hue, 1.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Trees%d" % k
		mmi.multimesh = mm
		mmi.visibility_range_end = end
		if not shadows:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	return root
