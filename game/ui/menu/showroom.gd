class_name Showroom
extends Node3D
## A small 3D stage for menus: dark glossy floor, a neon turntable, light strips that the paint
## reflects, key + rim lights, and an orbit camera. Shows one CarVisual.
## Used by the main menu (auto-rotating backdrop) and the garage (drag to orbit).

var car_visual: CarVisual
var camera: Camera3D
var turntable: Node3D
var car_id := ""

## Orbit camera state (radians / meters). The garage changes these through orbit_drag()/zoom().
var yaw := 0.6
var pitch := 0.18
var distance := 7.2
var target := Vector3(0, 0.55, 0)
var auto_rotate := 0.12        # rad/s applied to the turntable
var min_distance := 4.2
var max_distance := 11.0
## Shifts the car sideways on screen (camera h_offset in meters; negative = car to the right).
var screen_offset := 0.0

var _ring_mat: StandardMaterial3D
var _env: Environment
var _accent := UITheme.MAGENTA
var _t := 0.0


func _ready() -> void:
	_build_stage()
	Settings.changed.connect(_on_settings_changed)


func _process(delta: float) -> void:
	_t += delta
	if turntable:
		turntable.rotation.y += auto_rotate * delta
	if _ring_mat:
		_ring_mat.emission_energy_multiplier = 2.2 + sin(_t * 1.6) * 0.5
	_update_camera()


## Shows `car` with `style` (rebuilds only when the car changes; style updates use apply_style).
func show_car(p_car_id: String, style: Dictionary) -> void:
	if car_visual == null or p_car_id != car_id:
		if car_visual:
			car_visual.queue_free()
		car_visual = CarVisual.new()
		turntable.add_child(car_visual)
		car_id = p_car_id
		car_visual.build(car_id, style)
		var g := CarDefs.geometry(car_id)
		car_visual.position = Vector3(0, float(g["wheel_radius"]) + 0.08, 0)
		if car_visual.has_method("set_headlights_real"):
			car_visual.call("set_headlights_real", false)
	else:
		car_visual.apply_style(style)
	car_visual.set_underglow_enabled(true)


func set_accent(c: Color) -> void:
	_accent = c
	if _ring_mat:
		_ring_mat.emission = c


func orbit_drag(rel: Vector2) -> void:
	yaw -= rel.x * 0.008
	pitch = clampf(pitch + rel.y * 0.005, -0.05, 0.75)


func zoom(step: float) -> void:
	distance = clampf(distance * (1.0 + step), min_distance, max_distance)


func _update_camera() -> void:
	if camera == null:
		return
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	camera.position = target + dir * distance
	camera.h_offset = screen_offset * distance / 7.0
	camera.look_at(target, Vector3.UP)


func _on_settings_changed() -> void:
	if _env:
		Settings.tune_environment(_env)


func _build_stage() -> void:
	var compat := Settings.is_compat()
	# Environment
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.012, 0.018, 0.045)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.22, 0.26, 0.42)
	_env.ambient_light_energy = 0.55
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.05
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_bloom = 0.08
	_env.glow_hdr_threshold = 1.0
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.09, 0.05, 0.2)
	_env.fog_density = 0.018
	_env.fog_sky_affect = 0.0
	_env.ssr_enabled = true
	_env.ssao_enabled = true
	Settings.tune_environment(_env)
	we.environment = _env
	add_child(we)

	# Lights: key + two colored rims (3 lights fits every budget).
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, 35, 0)
	key.light_color = Color(1.0, 0.95, 0.9)
	key.light_energy = 1.25
	Settings.tune_sun(key)
	add_child(key)
	var rim1 := OmniLight3D.new()
	rim1.position = Vector3(-4.5, 2.6, -3.5)
	rim1.light_color = UITheme.CYAN
	rim1.light_energy = 3.0
	rim1.omni_range = 11.0
	add_child(rim1)
	var rim2 := OmniLight3D.new()
	rim2.position = Vector3(4.5, 2.2, 3.0)
	rim2.light_color = UITheme.MAGENTA
	rim2.light_energy = 2.4
	rim2.omni_range = 10.0
	add_child(rim2)

	# Floor: dark, glossy (SSR on Forward+ high quality; specular highlights everywhere).
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.03, 0.035, 0.06)
	fm.metallic = 0.5
	fm.roughness = 0.22 if not compat else 0.35
	floor_mi.material_override = fm
	add_child(floor_mi)

	# Turntable
	turntable = Node3D.new()
	add_child(turntable)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 3.4
	cm.bottom_radius = 3.5
	cm.height = 0.08
	cm.radial_segments = 64
	disc.mesh = cm
	disc.position.y = 0.04
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.05, 0.055, 0.08)
	dm.metallic = 0.7
	dm.roughness = 0.3
	disc.material_override = dm
	turntable.add_child(disc)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.42
	tm.outer_radius = 3.56
	tm.rings = 96
	tm.ring_segments = 8
	ring.mesh = tm
	ring.position.y = 0.06
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = _accent
	_ring_mat.emission_enabled = true
	_ring_mat.emission = _accent
	_ring_mat.emission_energy_multiplier = 2.5
	ring.material_override = _ring_mat
	add_child(ring)
	# Inner thin cyan line on the disc
	var ring2 := MeshInstance3D.new()
	var tm2 := TorusMesh.new()
	tm2.inner_radius = 2.9
	tm2.outer_radius = 2.95
	tm2.rings = 96
	tm2.ring_segments = 6
	ring2.mesh = tm2
	ring2.position.y = 0.08
	var r2m := StandardMaterial3D.new()
	r2m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r2m.albedo_color = Color(UITheme.CYAN, 1.0) * 1.6
	ring2.material_override = r2m
	turntable.add_child(ring2)

	# Light strips in an arc behind/around: they show up as reflections on the paint and floor.
	var strip_mat := StandardMaterial3D.new()
	strip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	strip_mat.albedo_color = Color(0.85, 0.95, 1.0) * 2.2
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(0.12, 4.5, 0.12)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = strip_mesh
	var n := 14
	mm.instance_count = n
	for i in n:
		var a := lerpf(-2.4, 2.4, float(i) / float(n - 1)) + PI
		var p := Vector3(sin(a) * 13.0, 3.2, cos(a) * 13.0)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, a), p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = strip_mat
	add_child(mmi)
	# Overhead light panel (reflects on the roof/hood)
	var panel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(5.5, 0.05, 2.0)
	panel.mesh = bm
	panel.position = Vector3(0, 6.5, 0)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(0.9, 0.95, 1.0) * 1.4
	panel.material_override = pmat
	add_child(panel)

	camera = Camera3D.new()
	camera.fov = 40.0
	camera.current = true
	add_child(camera)
	_update_camera()
