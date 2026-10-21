class_name TmStreetLights
extends RefCounted
## Street lights for the city tracks (our own, in code): a tapering steel pole 9 m tall, an arm
## curving out over the road and a flat LED head, its underside lit. All of a track's lamps are one
## MultiMesh; at night each carries a spot light pooling on the road below it (no shadows), and the
## heads glow (the global tm_night).

const HEIGHT := 9.0
const REACH := 2.6                   ## how far the arm reaches out over the road (m)

static var _mesh: ArrayMesh
static var _steel: StandardMaterial3D
static var _lamp: ShaderMaterial


## One lamp post, its foot at the origin, the arm reaching along -z (towards the road).
static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var pole := TmTower.Builder.new()
	_tube(pole, Vector3.ZERO, Vector3(0.0, HEIGHT - 0.6, 0.0), 0.11, 0.07)
	# the arm: a quarter bend, then out level to the head
	var prev := Vector3(0.0, HEIGHT - 0.6, 0.0)
	for k in range(1, 7):
		var a := k / 6.0 * PI * 0.5
		var p := Vector3(0.0, HEIGHT - 0.6 + sin(a) * 0.6, -(1.0 - cos(a)) * 0.6)
		_tube(pole, prev, p, 0.07, 0.065)
		prev = p
	_tube(pole, prev, Vector3(0.0, HEIGHT, -REACH), 0.065, 0.06)
	var head := TmTower.Builder.new()
	var hc := Vector2(0.0, -REACH - 0.35)
	var box := TmTower.footprint("rect", 0.32, 0.8)
	for i in box.size():
		box[i] += hc
	TmTower.walls(pole, box, HEIGHT - 0.08, HEIGHT + 0.06)
	TmTower.cap(pole, box, HEIGHT + 0.06)
	# the head's lit underside (its own surface)
	var lens := TmTower.footprint("rect", 0.26, 0.7)
	for i in lens.size():
		lens[i] += hc
	var dn := Vector3.DOWN
	for i in lens.size():
		var a := lens[i]
		var e := lens[(i + 1) % lens.size()]
		head.tri3(Vector3(hc.x, HEIGHT - 0.085, hc.y), Vector3(e.x, HEIGHT - 0.085, e.y), Vector3(a.x, HEIGHT - 0.085, a.y),
			dn, dn, dn, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	_mesh = ArrayMesh.new()
	for b: TmTower.Builder in [pole, head]:
		arr[Mesh.ARRAY_VERTEX] = b.v
		arr[Mesh.ARRAY_NORMAL] = b.n
		arr[Mesh.ARRAY_TEX_UV] = b.uv
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mesh.surface_set_material(0, _steel_material())
	_mesh.surface_set_material(1, _lamp_material())
	return _mesh


static func _tube(b: TmTower.Builder, a: Vector3, e: Vector3, r0: float, r1: float) -> void:
	var axis := (e - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	var up := side.cross(axis)
	for i in 8:
		var t0 := TAU * i / 8.0
		var t1 := TAU * (i + 1) / 8.0
		var n0 := side * cos(t0) + up * sin(t0)
		var n1 := side * cos(t1) + up * sin(t1)
		b.tri3(a + n0 * r0, e + n1 * r1, a + n1 * r0, n0, n1, n1, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		b.tri3(a + n0 * r0, e + n0 * r1, e + n1 * r1, n0, n0, n1, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)


static func _steel_material() -> StandardMaterial3D:
	if _steel == null:
		_steel = StandardMaterial3D.new()
		_steel.albedo_color = Color(0.30, 0.32, 0.34)
		_steel.metallic = 0.8
		_steel.roughness = 0.42
		_steel.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _steel


static func _lamp_material() -> ShaderMaterial:
	if _lamp == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode cull_disabled;
// A street light's LED lens: pale by day, bright warm white at night (TmStreetLights).
global uniform float tm_night;
void fragment() {
	ALBEDO = vec3(0.85, 0.86, 0.84);
	ROUGHNESS = 0.2;
	EMISSION = vec3(1.0, 0.86, 0.66) * mix(0.15, 9.0, tm_night);
}
"""
		_lamp = ShaderMaterial.new()
		_lamp.shader = sh
	return _lamp


## Lamps at `feet` (each foot's basis turns its arm towards the road: -z); at night a spot light
## under each head lights the road (shadowless; `lights`: only so many, the nearest the start first).
static func row(feet: Array, night: bool, lights := 120) -> Node3D:
	var root := Node3D.new()
	root.name = "StreetLights"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh()
	mm.instance_count = feet.size()
	for i in feet.size():
		mm.set_instance_transform(i, feet[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = 1500.0
	root.add_child(mmi)
	if night:
		for i in mini(feet.size(), lights):
			var xf: Transform3D = feet[i]
			var spot := SpotLight3D.new()
			spot.position = xf * Vector3(0.0, HEIGHT - 0.2, -REACH - 0.35)
			spot.rotation = Vector3(-PI * 0.5, 0.0, 0.0)          # straight down
			spot.light_color = Color(1.0, 0.86, 0.66)
			spot.light_energy = 6.0
			spot.spot_range = 22.0
			spot.spot_angle = 62.0
			spot.spot_attenuation = 1.2
			spot.shadow_enabled = false
			spot.distance_fade_enabled = true
			spot.distance_fade_begin = 350.0
			spot.distance_fade_length = 100.0
			root.add_child(spot)
	return root
