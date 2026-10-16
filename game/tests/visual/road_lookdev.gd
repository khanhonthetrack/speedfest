extends Node3D
## Look-dev for night roads (M7 look pass): a 300 m road strip with the real road shader and city
## environment, emissive window panels and neon signs (optionally with real lights), low chase cam.
## Much faster to render than a full track. Args:
##   --theme=city|arena  --wet=0.42 (road wetness)  --lights=1 (OmniLights at the signs)
##   --tonemap=agx  --quality=N  --aa=SMAA  --frames=24 --shot=/abs/out.png
## Run: tools/run_scene.sh res://tests/visual/road_lookdev.tscn -- --wet=0.42 --frames=24 --shot=$PWD/x.png

const LEN := 300.0
const HW := 8.0
const NEON := [Color(1.0, 0.1, 0.75), Color(0.0, 0.85, 1.0), Color(1.0, 0.55, 0.1), Color(0.55, 0.2, 1.0)]


func _ready() -> void:
	var theme := String(TestHooks.arg("theme", "city"))
	add_child(SceneryKit.build_environment(theme))
	var mat: Material = TrackBuilder.road_material("concrete" if theme == "city" else "neon", false)
	(mat as ShaderMaterial).set_shader_parameter("wetness", float(TestHooks.arg("wet", 0.0)))
	if TestHooks.has_arg("mirror"):     # control: a near-mirror road shows whether SSR works at all
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.02, 0.02, 0.025)
		mm.roughness = float(TestHooks.arg("mirror", 0.02))
		mat = null
		var road0 := MeshInstance3D.new()
		road0.mesh = _strip(mm)
		add_child(road0)
	if mat != null:
		var road := MeshInstance3D.new()
		road.mesh = _strip(mat)
		add_child(road)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lights := int(TestHooks.arg("lights", 1)) == 1
	var win := StandardMaterial3D.new()
	win.albedo_color = Color(0.02, 0.02, 0.03)
	win.emission_enabled = true
	win.emission = Color(1.0, 0.75, 0.45)
	win.emission_energy_multiplier = 1.4
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.05, 0.05, 0.07)
	wall.roughness = 0.7
	for side: float in [-1.0, 1.0]:
		# building walls with lit windows along both sides
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(4.0, 40.0, LEN)
		b.mesh = bm
		b.material_override = wall
		b.position = Vector3(side * (HW + 9.0), 20.0, -LEN * 0.5)
		add_child(b)
		for k in 60:
			var w := MeshInstance3D.new()
			var wm := QuadMesh.new()
			wm.size = Vector2(rng.randf_range(1.5, 3.0), rng.randf_range(1.2, 2.0))
			w.mesh = wm
			w.material_override = win
			w.position = Vector3(side * (HW + 6.95), rng.randf_range(3.0, 30.0), -rng.randf_range(5.0, LEN - 5.0))
			w.rotation.y = -side * PI * 0.5
			add_child(w)
		# neon signs on the walls
		for k in 6:
			var col: Color = NEON[(k + int(side > 0) * 2) % NEON.size()]
			var z := -20.0 - k * 45.0 - (side + 1.0) * 10.0
			var s := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(0.3, 2.5, rng.randf_range(6.0, 12.0))
			s.mesh = sm
			var m2 := StandardMaterial3D.new()
			m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m2.albedo_color = col * 3.0
			s.material_override = m2
			s.position = Vector3(side * (HW + 6.8), rng.randf_range(4.0, 9.0), z)
			add_child(s)
			if lights:
				var ol := OmniLight3D.new()
				ol.position = s.position - Vector3(side * 2.5, 0, 0)
				ol.light_color = col.lightened(0.15)
				ol.light_energy = float(TestHooks.arg("light_energy", 3.0))
				ol.light_specular = 0.8
				ol.omni_range = 18.0
				ol.omni_attenuation = 1.4
				add_child(ol)
	var cam := Camera3D.new()
	cam.position = Vector3(1.5, 2.2, 6.0)
	cam.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	cam.fov = 70.0
	cam.far = 2000.0
	add_child(cam)
	cam.current = true


func _strip(mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 60
	for i in n:
		var z0 := -LEN * float(i) / n + 10.0
		var z1 := -LEN * float(i + 1) / n + 10.0
		var d0 := LEN * float(i) / n
		var d1 := LEN * float(i + 1) / n
		var quad := [[-HW, z0, 0.0, d0], [HW, z0, 2.0 * HW, d0], [HW, z1, 2.0 * HW, d1], [-HW, z1, 0.0, d1]]
		for idx in [0, 2, 1, 0, 3, 2]:
			var q: Array = quad[idx]
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(q[2], q[3]))
			st.set_uv2(Vector2(HW, 0.0))
			st.add_vertex(Vector3(q[0], 0.0, q[1]))
	st.generate_tangents()
	var m := st.commit()
	m.surface_set_material(0, mat)
	return m
