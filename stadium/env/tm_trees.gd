class_name TmTrees
extends RefCounted
## Street trees for the city (in code, with Poly Haven's jacaranda textures, CC0:
## assets/tex/trees): a trunk and limbs in bark, the crown a few hundred cards each showing a
## photographed frond (env/tm_leaves.gdshader: alpha-cut, lit as a volume, light through the leaves,
## a sway in the wind). A planting is one MultiMesh per variant (each tree turned, sized and its own
## green in the instance data).
##
##   var trees := TmTrees.planting([Transform3D(...), ...], rng)   # feet at the transforms

const VARIANTS := 3                 ## tree shapes (each planting draws from them)
const TEX := "res://assets/tex/trees"
## The fronds in the leaf atlas: [u0, v0, u1, v1, the stem at u0 (else at u1)].
const FRONDS := [[0.16, 0.02, 0.99, 0.473, true], [0.0, 0.324, 0.43, 0.695, true], [0.242, 0.59, 1.0, 0.996, false]]

static var _meshes: Array[ArrayMesh] = []
static var _bark: StandardMaterial3D
static var _leaves: ShaderMaterial


## One tree of a variant: its trunk and limbs (surface 0) and leaves (surface 1); about 10 m tall,
## its foot at the origin.
static func mesh(variant := 0) -> ArrayMesh:
	if _meshes.is_empty():
		for k in VARIANTS:
			_meshes.append(_build(k))
	return _meshes[variant % VARIANTS]


static func _build(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7001 + variant * 13
	var wood := TmTower.Builder.new()
	var leaves := TmTower.Builder.new()
	var crown := Vector3(0.0, 6.2 + variant * 0.4, 0.0)
	var top := Vector3(rng.randf_range(-0.2, 0.2), 3.0, rng.randf_range(-0.2, 0.2))
	_limb(wood, Vector3.ZERO, top, 0.2, 0.15)
	_limb(wood, top, Vector3(0.0, 7.0 + variant * 0.5, 0.0), 0.13, 0.04)
	_fronds(leaves, top.lerp(Vector3(0.0, 7.0 + variant * 0.5, 0.0), 0.5), Vector3(0.0, 7.0 + variant * 0.5, 0.0), crown, 6, rng)
	var limbs := 6 + variant
	for k in limbs:
		var az := TAU * k / limbs + rng.randf_range(-0.3, 0.3)
		var el := deg_to_rad(rng.randf_range(30.0, 58.0))
		var dir := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
		var root := top + Vector3(0.0, rng.randf_range(-0.3, 0.5), 0.0)
		var tip := root + dir * rng.randf_range(3.0, 4.2)
		_limb(wood, root, tip, 0.11, 0.035)
		_fronds(leaves, root.lerp(tip, 0.35), tip, crown, 9, rng)
		for j in 2:
			var at := root.lerp(tip, rng.randf_range(0.45, 0.75))
			var az2 := az + rng.randf_range(-0.9, 0.9)
			var d2 := Vector3(cos(az2), rng.randf_range(-0.15, 0.45), sin(az2)).normalized()
			var tip2 := at + d2 * rng.randf_range(1.4, 2.2)
			_limb(wood, at, tip2, 0.05, 0.02)
			_fronds(leaves, at.lerp(tip2, 0.2), tip2, crown, 6, rng)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var m := ArrayMesh.new()
	for b: TmTower.Builder in [wood, leaves]:
		arr[Mesh.ARRAY_VERTEX] = b.v
		arr[Mesh.ARRAY_NORMAL] = b.n
		arr[Mesh.ARRAY_TEX_UV] = b.uv
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _bark_material())
	m.surface_set_material(1, _leaf_material())
	return m


## A tapering eight-sided limb from a to e (bark UV: u around, v along, about a metre a repeat).
static func _limb(b: TmTower.Builder, a: Vector3, e: Vector3, r0: float, r1: float) -> void:
	var axis := (e - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	var up := side.cross(axis)
	var len := a.distance_to(e)
	for i in 8:
		var t0 := TAU * i / 8.0
		var t1 := TAU * (i + 1) / 8.0
		var n0 := side * cos(t0) + up * sin(t0)
		var n1 := side * cos(t1) + up * sin(t1)
		var u0 := i / 8.0
		var u1 := (i + 1) / 8.0
		b.tri3(a + n0 * r0, e + n1 * r1, a + n1 * r0, n0, n1, n1, Vector2(u0, 0.0), Vector2(u1, len), Vector2(u1, 0.0))
		b.tri3(a + n0 * r0, e + n0 * r1, e + n1 * r1, n0, n0, n1, Vector2(u0, 0.0), Vector2(u0, len), Vector2(u1, len))


## Frond cards along a limb from a to e: each a quad showing one frond, its stem on the limb,
## reaching out and drooping; normals out from the crown's middle (a volume's shading).
static func _fronds(b: TmTower.Builder, a: Vector3, e: Vector3, crown: Vector3, count: int, rng: RandomNumberGenerator) -> void:
	var axis := (e - a).normalized()
	for k in count:
		var at := a.lerp(e, (k + rng.randf()) / count)
		var f: Array = FRONDS[rng.randi() % FRONDS.size()]
		var uv0 := Vector2(f[0], f[1])
		var uv1 := Vector2(f[2], f[3])
		var aspect := (uv1.x - uv0.x) / (uv1.y - uv0.y)
		var length := rng.randf_range(1.1, 1.6)
		var width := length / aspect
		# along the limb, turned about it and out, drooping a little
		var out := (at - crown)
		out.y = 0.0
		out = (out.normalized() if out.length() > 0.1 else Vector3.RIGHT)
		var dir := (axis * 0.5 + out * rng.randf_range(0.3, 0.9) + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.45, 0.1), rng.randf_range(-0.5, 0.5))).normalized()
		var side := dir.cross(Vector3.UP).normalized().rotated(dir, rng.randf_range(-1.2, 1.2))
		var p0 := at - side * width * 0.5
		var p1 := at + side * width * 0.5
		var p2 := p1 + dir * length
		var p3 := p0 + dir * length
		var stem_u := uv0.x if bool(f[4]) else uv1.x
		var tip_u := uv1.x if bool(f[4]) else uv0.x
		var n := [(p0 - crown).normalized(), (p1 - crown).normalized(), (p2 - crown).normalized(), (p3 - crown).normalized()]
		var t := [Vector2(stem_u, uv0.y), Vector2(stem_u, uv1.y), Vector2(tip_u, uv1.y), Vector2(tip_u, uv0.y)]
		b.tri3(p0, p1, p2, n[0], n[1], n[2], t[0], t[1], t[2])
		b.tri3(p0, p2, p3, n[0], n[2], n[3], t[0], t[2], t[3])


static func _bark_material() -> StandardMaterial3D:
	if _bark == null:
		_bark = StandardMaterial3D.new()
		_bark.albedo_texture = load(TEX.path_join("jacaranda_bark.jpg"))
		_bark.albedo_color = Color(0.8, 0.78, 0.75)
		_bark.uv1_scale = Vector3(1.0, 1.0, 1.0)
		_bark.roughness = 0.95
		_bark.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _bark


static func _leaf_material() -> ShaderMaterial:
	if _leaves == null:
		_leaves = ShaderMaterial.new()
		_leaves.shader = preload("res://env/tm_leaves.gdshader")
		_leaves.set_shader_parameter("leaves", load(TEX.path_join("jacaranda_leaves.png")))
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
