class_name TmCitySigns
extends RefCounted
## The modern city's signs along the City tracks (our own, in code): LED billboards on the roofs
## facing the road (a steel frame on two legs, a 14 x 7 m screen cycling the adverts:
## env/tm_led_screen.gdshader) and neon blade signs standing out from the facades beside the road
## (dark boxes with a word in glowing tubes on both faces: env/tm_neon.gdshader; pink, cyan,
## violet, amber, green). Faint by day, bright at night.

const NEON := [Color(1.0, 0.18, 0.62), Color(0.15, 0.85, 1.0), Color(0.62, 0.25, 1.0), Color(1.0, 0.62, 0.12),
	Color(0.3, 1.0, 0.45), Color(1.0, 0.25, 0.2)]
const BOARD := Vector2(14.0, 7.0)

static var _screen: ShaderMaterial
static var _neon: ShaderMaterial
static var _frame: StandardMaterial3D


## Billboards: each [foot (Vector3, on the roof), facing (Vector2: the way its screen looks)].
static func billboards(spots: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "Billboards"
	var k := 0
	for s: Array in spots:
		var foot: Vector3 = s[0]
		var face: Vector2 = s[1]
		var n := Node3D.new()
		n.transform = Transform3D(Basis.looking_at(-Vector3(face.x, 0.0, face.y)), foot)
		var frame := MeshInstance3D.new()
		frame.mesh = _frame_mesh()
		frame.material_override = _frame_material()
		n.add_child(frame)
		var screen := MeshInstance3D.new()
		screen.mesh = _screen_mesh()
		screen.material_override = _screen_material()
		screen.set_instance_shader_parameter("board", fmod(k * 0.618 + 0.13, 1.0))
		n.add_child(screen)
		root.add_child(n)
		k += 1
	return root


## Blade signs: each [foot (Vector3: where it meets the facade, at its top), out (Vector2: from
## the facade), height (m)]; one mesh, each its own colour and word.
static func blades(spots: Array, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "NeonSigns"
	for s: Array in spots:
		var top: Vector3 = s[0]
		var out: Vector2 = s[1]
		var h: float = s[2]
		var mi := MeshInstance3D.new()
		mi.mesh = _blade_mesh(h, NEON[rng.randi() % NEON.size()])
		mi.material_override = _neon_material()
		mi.set_instance_shader_parameter("word", rng.randf() * 1000.0)
		# local: the sign reaches out along +x from the facade, its faces look along +-z, its top at y 0
		mi.transform = Transform3D(Basis.looking_at(Vector3(out.y, 0.0, -out.x)), top)
		root.add_child(mi)
	return root


static func _blade_mesh(h: float, colour: Color) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var col := PackedColorArray()
	var w := 1.2
	var t := 0.18
	# corners: x 0..w out from the facade (0.1 gap), y -h..0, z -t..t
	var faces := [
		[Vector3(0.1, 0, t), Vector3(0.1 + w, 0, t), Vector3(0.1 + w, -h, t), Vector3(0.1, -h, t), Vector3(0, 0, 1), true],
		[Vector3(0.1 + w, 0, -t), Vector3(0.1, 0, -t), Vector3(0.1, -h, -t), Vector3(0.1 + w, -h, -t), Vector3(0, 0, -1), true],
		[Vector3(0.1 + w, 0, t), Vector3(0.1 + w, 0, -t), Vector3(0.1 + w, -h, -t), Vector3(0.1 + w, -h, t), Vector3(1, 0, 0), false],
		[Vector3(0.1, 0, -t), Vector3(0.1 + w, 0, -t), Vector3(0.1 + w, 0, t), Vector3(0.1, 0, t), Vector3(0, 1, 0), false],
		[Vector3(0.1, -h, t), Vector3(0.1 + w, -h, t), Vector3(0.1 + w, -h, -t), Vector3(0.1, -h, -t), Vector3(0, -1, 0), false],
	]
	for f: Array in faces:
		var q := [f[0], f[1], f[2], f[3]]
		var lit: bool = f[5]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, h), Vector2(0, h)]
		for k: int in [0, 1, 2, 0, 2, 3]:       # clockwise seen from outside (Godot's front faces)
			v.append(q[k])
			n.append(f[4])
			uv.append(uvs[k])
			uv2.append(Vector2(h, 0.0))
			col.append(Color(colour, 1.0 if lit else 0.0))
	# two brackets back to the facade
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_COLOR] = col
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static var _frame_cache: ArrayMesh
static var _screen_cache: ArrayMesh


## The billboard's steel: two legs from the roof and a frame round the screen (its foot at the
## origin, its screen looking along +z).
static func _frame_mesh() -> ArrayMesh:
	if _frame_cache != null:
		return _frame_cache
	var b := TmTower.Builder.new()
	for x: float in [-4.5, 4.5]:
		var leg := TmTower.footprint("rect", 0.45, 0.45)
		for i in leg.size():
			leg[i] += Vector2(x, -0.3)
		TmTower.walls(b, leg, 0.0, 3.0)
	var frame := TmTower.footprint("rect", BOARD.x + 0.6, 0.5)
	TmTower.walls(b, frame, 2.6, 3.0 + BOARD.y + 0.4)
	TmTower.cap(b, frame, 3.0 + BOARD.y + 0.4)
	_frame_cache = b.mesh()
	return _frame_cache


static func _screen_mesh() -> ArrayMesh:
	if _screen_cache != null:
		return _screen_cache
	var b := TmTower.Builder.new()
	var y0 := 3.0 + 0.2
	var y1 := y0 + BOARD.y
	var hw := BOARD.x * 0.5
	var z := 0.26
	var nz := Vector3(0, 0, 1)
	var p0 := Vector3(-hw, y1, z)
	var p1 := Vector3(hw, y1, z)
	var p2 := Vector3(hw, y0, z)
	var p3 := Vector3(-hw, y0, z)
	b.tri3(p0, p1, p2, nz, nz, nz, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1))
	b.tri3(p0, p2, p3, nz, nz, nz, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))
	_screen_cache = b.mesh()
	return _screen_cache


static func _frame_material() -> StandardMaterial3D:
	if _frame == null:
		_frame = StandardMaterial3D.new()
		_frame.albedo_color = Color(0.12, 0.12, 0.13)
		_frame.metallic = 0.7
		_frame.roughness = 0.4
	return _frame


static func _screen_material() -> ShaderMaterial:
	if _screen == null:
		_screen = ShaderMaterial.new()
		_screen.shader = preload("res://env/tm_led_screen.gdshader")
		_screen.set_shader_parameter("ads", Adverts.texture())
		_screen.set_shader_parameter("ads_fill", Adverts.fill_texture())
	return _screen


static func _neon_material() -> ShaderMaterial:
	if _neon == null:
		_neon = ShaderMaterial.new()
		_neon.shader = preload("res://env/tm_neon.gdshader")
	return _neon
