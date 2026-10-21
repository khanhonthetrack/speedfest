class_name TmStreetLights
extends RefCounted
## Street lights and traffic lights for the city tracks. The lamps are the owner's (CC0, given 21
## Oct 2026; assets/city/props/lamp_01..06.glb, six designs, converted by blend_to_glb.py): one
## design per track, scaled to LAMP_SCALE, in our paint with lit lenses; without them, our own
## (a tapering pole, an arm over the road, a flat LED head). All of a track's lamps are one
## MultiMesh; at night each carries a spot light pooling on the road below its head (no shadows).
## Traffic lights (the owner's traffic_01..02.glb) stand where the track turns.

const HEIGHT := 9.0
const REACH := 2.6                   ## how far the arm reaches out over the road (m)
const PROPS := "res://assets/city/props"
const LAMP_SCALE := 1.7              ## the owner's lamps are 5 m: street lamps for a road this wide
const LAMPS := 6
const TRAFFIC_SCALE := 1.15

static var _assets := {}             ## design -> [ArrayMesh, head (Vector3, local, scaled)]

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


## The owner's lamp `design` (1..LAMPS) as one mesh in our materials, scaled, its arm turned to
## -z like ours, and where its head is; [] without the file.
static func asset_lamp(design: int) -> Array:
	if _assets.has(design):
		return _assets[design]
	var path := PROPS.path_join("lamp_%02d.glb" % design)
	var out := []
	if ResourceLoader.exists(path):
		var n := (load(path) as PackedScene).instantiate()
		var mis := n.find_children("*", "MeshInstance3D", true, false)
		if not mis.is_empty():
			var src := (mis[0] as MeshInstance3D).mesh
			# the arm reaches along +x in the file: turned a quarter so it reaches along -z
			var xf := Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * LAMP_SCALE), Vector3.ZERO)
			var m := ArrayMesh.new()
			for i in src.get_surface_count():
				var arr := src.surface_get_arrays(i)
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				for k in vs.size():
					vs[k] = xf * vs[k]
					ns[k] = (xf.basis * ns[k]).normalized()
				arr[Mesh.ARRAY_VERTEX] = vs
				arr[Mesh.ARRAY_NORMAL] = ns
				arr[Mesh.ARRAY_TANGENT] = null
				m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				var mat := src.surface_get_material(i)
				if not (mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null):
					var kind := TmCityAssets.kind_of(mat.resource_name if mat != null else "")
					mat = TmCityAssets.material(kind if kind in ["lit", "steel", "dark"] else "paint")
				m.surface_set_material(i, mat)
			var box := m.get_aabb()
			out = [m, Vector3(0.0, box.end.y - 0.25, box.position.z + 0.35)]
		n.free()
	_assets[design] = out
	return out


## Lamps at `feet` (each foot's basis turns its arm towards the road: -z), the owner's `design`
## (0: ours); at night a spot light under each head lights the road (shadowless; `lights`: only
## so many).
static func row(feet: Array, night: bool, design := 0, lights := 120) -> Node3D:
	var root := Node3D.new()
	root.name = "StreetLights"
	var head := Vector3(0.0, HEIGHT - 0.2, -REACH - 0.35)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh()
	var lamp := asset_lamp(design) if design > 0 else []
	if not lamp.is_empty():
		mm.mesh = lamp[0]
		head = lamp[1]
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
			spot.position = xf * head
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


## The owner's traffic lights at `feet` (their signal faces turned to +z, towards the road).
static func traffic(feet: Array, design := 1) -> Node3D:
	var root := Node3D.new()
	root.name = "TrafficLights"
	var path := PROPS.path_join("traffic_%02d.glb" % design)
	if not ResourceLoader.exists(path):
		return root
	var scene := load(path) as PackedScene
	for xf: Transform3D in feet:
		var n := scene.instantiate() as Node3D
		n.transform = xf.scaled_local(Vector3.ONE * TRAFFIC_SCALE)
		TmCityAssets.dress(n, "blue", 1, 3.8, true)
		root.add_child(n)
	return root
