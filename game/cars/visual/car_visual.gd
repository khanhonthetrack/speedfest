class_name CarVisual
extends Node3D
## Procedural car model. API fixed by docs/ARCHITECTURE.md "CarVisual"; additions are documented
## in docs/modules/visuals.md.
##
## Node layout (all built in code):
##   CarVisual (car origin: wheel-center height at rest, ground at y = -wheel_radius)
##     Body (MeshInstance3D, ground space, y = -radius + ride offset): paint/glass/trim/chrome/lights surfaces
##       Plate (Label3D), Flames (nitro), HeadSpots (optional SpotLights)
##     Wheels (MultiMeshInstance3D, 4 instances), Calipers (MultiMeshInstance3D)
##     Glow (ground blob) + GlowLight (OmniLight3D, optional), Nitro particles

const PAINT_SHADER := preload("res://shaders/car_paint.gdshader")
const LIGHTS_SHADER := preload("res://shaders/car_lights.gdshader")
const WHEEL_SHADER := preload("res://shaders/car_wheel.gdshader")
const GLOW_SHADER := preload("res://shaders/car_glow.gdshader")
const FLAME_SHADER := preload("res://shaders/car_flame.gdshader")

const BODY_KEYS: Array[String] = ["hood", "front", "rear", "skirts", "spoiler"]
## Ride height range in meters for style.ride_height -1 .. +1.
const RIDE_LOW := -0.035
const RIDE_HIGH := 0.05

var car_id: String = "kaze"
var style: Dictionary = {}
var shape: CarShape
## When false, the underglow uses only the ground blob (no OmniLight). Set before build().
var underglow_light_allowed := true
## Info produced by the parts builder (exhaust tips, light positions...) in body (ground) space.
var info: Dictionary = {}
## Triangle count of the last build (body + 4 wheels + 4 calipers), for tests.
var triangle_count := 0

var _body: MeshInstance3D
var _wheels_mm: MultiMeshInstance3D
var _calipers_mm: MultiMeshInstance3D
var _glow: MeshInstance3D
var _glow_light: OmniLight3D
var _plate: Label3D
var _flames: MeshInstance3D
var _particles: Node3D
var _head_spots: Array[SpotLight3D] = []
var _paint_mat: ShaderMaterial
var _lights_mat: ShaderMaterial
var _wheel_mat: ShaderMaterial
var _glass_mat: StandardMaterial3D
var _glow_mat: ShaderMaterial
var _flame_mat: ShaderMaterial
var _ghost_mat: StandardMaterial3D
var _wheel_base: Array[Vector3] = []
var _wheel_xf: Array[Transform3D] = [Transform3D(), Transform3D(), Transform3D(), Transform3D()]
var _steer := 0.0
var _spin: Array = [0.0, 0.0, 0.0, 0.0]
var _susp: Array = [0.0, 0.0, 0.0, 0.0]
var _ghost := 1.0
var _underglow_on := true
var _nitro := false
var _braking := false
var _reversing := false
var _headlights_real := false
var _rim_design := -1
var _built_body_key := ""

## Geometry cache shared by all CarVisuals: "car:parts" -> body mesh (+ info), "car:rim" -> wheel meshes.
## Materials are per instance (surface overrides), so cars with the same parts share meshes.
static var _mesh_cache: Dictionary = {}
const CACHE_MAX := 48

static var _trim_mat: StandardMaterial3D
static var _chrome_mat: StandardMaterial3D


func _init() -> void:
	name = "CarVisual"


# --- contract API -------------------------------------------------------------

func build(p_car_id: String, p_style: Dictionary) -> void:
	car_id = p_car_id if p_car_id in CarDefs.IDS else "kaze"
	style = CarDefs.sanitize_config({"car": car_id, "style": p_style})["style"]
	shape = CarShape.new(car_id)
	for c in get_children():
		remove_child(c)
		c.queue_free()
	# The old nodes are freed: forget them so every builder makes fresh ones (a second build()
	# used to leave the car without wheels, e.g. the PB ghost after a new PB).
	_body = null
	_wheels_mm = null
	_calipers_mm = null
	_glow = null
	_glow_light = null
	_plate = null
	_flames = null
	_particles = null
	_head_spots.clear()
	_built_body_key = ""
	_rim_design = -1
	_make_materials()
	_body = MeshInstance3D.new()
	_body.name = "Body"
	add_child(_body)
	_plate = Label3D.new()
	_plate.name = "Plate"
	_plate.modulate = Color(0.04, 0.04, 0.06)
	_plate.outline_size = 0
	_plate.font_size = 40
	_plate.pixel_size = 0.0021
	_plate.shaded = false
	_plate.double_sided = false
	_plate.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	var f: Variant = load("res://assets/fonts/orbitron-latin-700-normal.woff2")
	if f is Font:
		_plate.font = f
	_body.add_child(_plate)
	_build_body()
	_build_wheels()
	_build_glow()
	_build_nitro()
	_apply_materials()
	_apply_ride()
	set_wheel_state(_steer, _spin, _susp)
	set_lights(_braking, _reversing)
	set_underglow_enabled(_underglow_on)
	set_nitro(_nitro)
	if _headlights_real:
		set_headlights_real(true)
	if _ghost < 1.0:
		set_ghost(_ghost)


func apply_style(p_style: Dictionary) -> void:
	if shape == null:
		build(car_id, p_style)
		return
	style = CarDefs.sanitize_config({"car": car_id, "style": p_style})["style"]
	if _body_key() != _built_body_key:
		_build_body()
		set_nitro(_nitro)
		if _headlights_real:
			set_headlights_real(true)
	if int(style["rims"]) != _rim_design:
		_build_wheels()
	_apply_materials()
	_apply_ride()
	_update_glow_mode()
	set_underglow_enabled(_underglow_on)
	if _ghost < 1.0:
		set_ghost(_ghost)


func set_wheel_state(steer_angle_rad: float, spin_rad: Array, susp_offsets: Array) -> void:
	_steer = steer_angle_rad
	_spin = spin_rad
	_susp = susp_offsets
	if _wheels_mm == null or _wheels_mm.multimesh == null:
		return
	var mm := _wheels_mm.multimesh
	var cm := _calipers_mm.multimesh
	var g := shape.g
	var dx := CarWheels.disc_x(g["wheel_width"], _rim_design)
	for i in 4:
		var pos := _wheel_base[i]
		if i < susp_offsets.size():
			pos.y += float(susp_offsets[i])
		var steer := steer_angle_rad if i < 2 else 0.0
		var spin := float(spin_rad[i]) if i < spin_rad.size() else 0.0
		var side := -1.0 if i % 2 == 0 else 1.0
		var hub := Basis(Vector3.UP, steer)
		var wb := hub * Basis(Vector3.RIGHT, -spin)
		if side < 0.0:
			wb = wb * Basis(Vector3.UP, PI)
		_wheel_xf[i] = Transform3D(wb, pos)
		mm.set_instance_transform(i, _wheel_xf[i])
		var cal_off := hub * Vector3(side * dx, 0, 0)
		var cal_b := hub
		if i >= 2:
			cal_b = hub * Basis(Vector3.RIGHT, 0.0)
		else:
			cal_b = hub * Basis(Vector3.RIGHT, -1.25)   # front calipers sit at the back of the disc
		cm.set_instance_transform(i, Transform3D(cal_b, pos + cal_off))


func set_lights(braking: bool, reversing: bool) -> void:
	_braking = braking
	_reversing = reversing
	if _lights_mat:
		_lights_mat.set_shader_parameter("brake", 1.0 if braking else 0.0)
		_lights_mat.set_shader_parameter("reverse", 1.0 if reversing else 0.0)


func set_nitro(active: bool) -> void:
	_nitro = active
	if _flames:
		_flames.visible = active and _ghost > 0.5
	if _particles:
		if _particles is GPUParticles3D:
			(_particles as GPUParticles3D).emitting = active and _ghost > 0.5
		elif _particles is CPUParticles3D:
			(_particles as CPUParticles3D).emitting = active and _ghost > 0.5


func set_ghost(alpha: float) -> void:
	_ghost = clampf(alpha, 0.0, 1.0)
	var ghosted := _ghost < 0.999
	if ghosted:
		if _ghost_mat == null:
			_ghost_mat = StandardMaterial3D.new()
			_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_ghost_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
			_ghost_mat.roughness = 0.25
			_ghost_mat.metallic = 0.3
			_ghost_mat.emission_enabled = true
		var pc := Color(String(style.get("paint", "#ffffff")))
		_ghost_mat.albedo_color = Color(pc.r, pc.g, pc.b, _ghost * 0.85)
		_ghost_mat.emission = pc * 0.25
	for gi in [_body, _wheels_mm, _calipers_mm]:
		if gi:
			(gi as GeometryInstance3D).material_override = _ghost_mat if ghosted else (_wheel_mat if gi != _body else null)
			(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if ghosted else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if _plate:
		_plate.visible = not ghosted or _ghost > 0.7
	visible = _ghost > 0.01
	set_underglow_enabled(_underglow_on)
	set_nitro(_nitro)


func set_underglow_enabled(on: bool) -> void:
	_underglow_on = on
	var mode := String(style.get("underglow_mode", "off"))
	var show := on and mode != "off"
	if _glow:
		_glow.visible = show
		_glow_mat.set_shader_parameter("enabled", _ghost)
	if _glow_light:
		_glow_light.visible = show and _ghost > 0.6


# --- additions ----------------------------------------------------------------

## Real SpotLights for the headlights (local car only). Respects Settings.light_budget().
func set_headlights_real(on: bool) -> void:
	_headlights_real = on
	for sp in _head_spots:
		sp.queue_free()
	_head_spots.clear()
	if not on or _body == null:
		return
	var heads: Array = info.get("headlights", [])
	if heads.is_empty():
		return
	var count := 1 if Settings.is_compat() else 2
	var hc := Color(String(style["headlight"]))
	var targets: Array[Vector3] = []
	if count == 1:
		var c := Vector3.ZERO
		for h in heads:
			c += h
		targets.append(c / float(heads.size()))
	else:
		targets.append(heads[0])
		targets.append(heads[heads.size() - 1])
	for p in targets:
		var sp := SpotLight3D.new()
		sp.light_color = hc
		sp.light_energy = 6.0 if count == 1 else 4.0
		sp.spot_range = 45.0
		sp.spot_angle = 32.0 if count == 1 else 26.0
		sp.spot_attenuation = 0.8
		sp.shadow_enabled = false
		sp.position = p + Vector3(0, 0, -0.05)
		sp.rotation.x = -0.06
		_body.add_child(sp)
		_head_spots.append(sp)


## Current transform of wheel i (FL, FR, RL, RR) in CarVisual space.
func get_wheel_transform(i: int) -> Transform3D:
	return _wheel_xf[clampi(i, 0, 3)]


func get_triangle_count() -> int:
	return triangle_count


## Exhaust tip positions in CarVisual space (for effects owned by other modules).
func get_exhaust_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for e in info.get("exhausts", []):
		out.append(_body.transform * (e as Vector3))
	return out


# --- building -----------------------------------------------------------------

func _body_key() -> String:
	var parts: Array = []
	for k in BODY_KEYS:
		parts.append(str(int(style[k])))
	return ",".join(parts)


func _build_body() -> void:
	var key := car_id + ":" + _body_key()
	var entry: Dictionary = _mesh_cache.get(key, {})
	if entry.is_empty():
		var kit := MeshKit.new()
		CarBody.build_shell(shape, kit)
		CarBody.build_greenhouse(shape, kit)
		var inf := CarParts.build(shape, kit, style)
		entry = {"mesh": kit.commit({}), "info": inf, "tris": kit.tri_count()}
		if _mesh_cache.size() >= CACHE_MAX:
			_mesh_cache.clear()
		_mesh_cache[key] = entry
	info = (entry["info"] as Dictionary).duplicate(true)
	var mesh: ArrayMesh = entry["mesh"]
	_body.mesh = mesh
	var mats := {"paint": _paint_mat, "glass": _glass_mat, "trim": _trim_mat, "chrome": _chrome_mat, "lights": _lights_mat}
	for i in mesh.get_surface_count():
		_body.set_surface_override_material(i, mats.get(mesh.surface_get_name(i)))
	_built_body_key = _body_key()
	_body_tris = int(entry["tris"])
	triangle_count = _body_tris + _wheel_tris
	# license plate
	_plate.text = String(style["plate"])
	if info.has("plate"):
		_plate.transform = info["plate"]
	_build_flames()


var _body_tris := 0
var _wheel_tris := 0


func _build_wheels() -> void:
	_rim_design = int(style["rims"])
	var g := shape.g
	var wkey := car_id + ":" + str(_rim_design)
	if not _mesh_cache.has(wkey):
		_mesh_cache[wkey] = {"wheel": CarWheels.build_wheel(g["wheel_radius"], g["wheel_width"], _rim_design),
			"cal": CarWheels.build_caliper(g["wheel_radius"])}
	var wheel: ArrayMesh = _mesh_cache[wkey]["wheel"]
	var cal: ArrayMesh = _mesh_cache[wkey]["cal"]
	if _wheels_mm == null:
		_wheels_mm = MultiMeshInstance3D.new()
		_wheels_mm.name = "Wheels"
		add_child(_wheels_mm)
		_calipers_mm = MultiMeshInstance3D.new()
		_calipers_mm.name = "Calipers"
		add_child(_calipers_mm)
	for pair in [[_wheels_mm, wheel], [_calipers_mm, cal]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pair[1]
		mm.instance_count = 4
		(pair[0] as MultiMeshInstance3D).multimesh = mm
		(pair[0] as MultiMeshInstance3D).material_override = _wheel_mat
	_wheel_base = CarDefs.wheel_positions(car_id)
	var tw := 0
	for m in [wheel, cal]:
		var arr: Array = (m as ArrayMesh).surface_get_arrays(0)
		tw += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_wheel_tris = tw * 4
	triangle_count = _body_tris + _wheel_tris
	set_wheel_state(_steer, _spin, _susp)


func _build_glow() -> void:
	var g := shape.g
	_glow = MeshInstance3D.new()
	_glow.name = "Glow"
	var pm := PlaneMesh.new()
	pm.size = Vector2(float(g["width"]) + 1.0, float(g["length"]) + 0.9)
	_glow.mesh = pm
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.position = Vector3(0, -float(g["wheel_radius"]) + 0.015, 0)
	add_child(_glow)
	var use_light := underglow_light_allowed and (not Settings.is_compat() or Settings.quality >= 2)
	if use_light:
		_glow_light = OmniLight3D.new()
		_glow_light.name = "GlowLight"
		_glow_light.position = Vector3(0, -float(g["wheel_radius"]) + 0.12, 0)
		_glow_light.omni_range = 2.6
		_glow_light.omni_attenuation = 1.2
		_glow_light.light_energy = 2.0
		_glow_light.shadow_enabled = false
		_glow_light.light_specular = 0.05
		add_child(_glow_light)
	_update_glow_mode()


func _build_nitro() -> void:
	if Settings.is_compat():
		var cp := CPUParticles3D.new()
		cp.amount = 56
		cp.lifetime = 0.35
		cp.local_coords = false
		cp.direction = Vector3(0, 0, 1)
		cp.spread = 8.0
		cp.initial_velocity_min = 7.0
		cp.initial_velocity_max = 11.0
		cp.gravity = Vector3.ZERO
		cp.scale_amount_min = 0.6
		cp.scale_amount_max = 1.0
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0.1))
		cp.scale_amount_curve = curve
		cp.mesh = _particle_mesh()
		cp.emitting = false
		_particles = cp
	else:
		var gp := GPUParticles3D.new()
		gp.amount = 80
		gp.lifetime = 0.4
		gp.local_coords = false
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 0, 1)
		pm.spread = 8.0
		pm.initial_velocity_min = 7.0
		pm.initial_velocity_max = 11.0
		pm.gravity = Vector3.ZERO
		pm.scale_min = 0.6
		pm.scale_max = 1.0
		var ct := CurveTexture.new()
		var curve2 := Curve.new()
		curve2.add_point(Vector2(0, 1))
		curve2.add_point(Vector2(1, 0.1))
		ct.curve = curve2
		pm.scale_curve = ct
		gp.process_material = pm
		gp.draw_pass_1 = _particle_mesh()
		gp.emitting = false
		_particles = gp
	_particles.name = "NitroParticles"
	add_child(_particles)
	_place_particles()


func _particle_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.35, 0.55, 1.0, 0.8)
	m.albedo_texture = _soft_dot()
	m.vertex_color_use_as_albedo = true
	q.material = m
	return q


static var _dot_tex: ImageTexture


static func _soft_dot() -> ImageTexture:
	if _dot_tex:
		return _dot_tex
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex


func _place_particles() -> void:
	if _particles == null:
		return
	var ex: Array[Vector3] = get_exhaust_points()
	var c := Vector3(0, -0.1, shape.length * 0.5)
	if not ex.is_empty():
		c = Vector3.ZERO
		for e in ex:
			c += e
		c /= float(ex.size())
	_particles.position = c + Vector3(0, 0, 0.1)
	if _particles is CPUParticles3D:
		var cp := _particles as CPUParticles3D
		cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		cp.emission_box_extents = Vector3(_exhaust_spread(ex), 0.03, 0.03)
	elif _particles is GPUParticles3D:
		var pm := (_particles as GPUParticles3D).process_material as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(_exhaust_spread(ex), 0.03, 0.03)


func _exhaust_spread(ex: Array[Vector3]) -> float:
	var m := 0.02
	for e in ex:
		m = maxf(m, absf(e.x))
	return m


func _build_flames() -> void:
	if _flames:
		_flames.queue_free()
	_flames = MeshInstance3D.new()
	_flames.name = "Flames"
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 10
	for e in info.get("exhausts", []):
		var base: Vector3 = e
		var r: float = info.get("exhaust_r", 0.04)
		var flen := 0.75
		var rings := [[0.0, r * 0.9], [0.15, r * 1.25], [0.5, r * 0.9], [1.0, 0.0]]
		for k in rings.size() - 1:
			var a: Array = rings[k]
			var b: Array = rings[k + 1]
			for i in segs:
				var a0 := TAU * float(i) / float(segs)
				var a1 := TAU * float(i + 1) / float(segs)
				var d0 := Vector3(cos(a0), sin(a0), 0)
				var d1 := Vector3(cos(a1), sin(a1), 0)
				var p00 := base + d0 * float(a[1]) + Vector3(0, 0, float(a[0]) * flen)
				var p01 := base + d1 * float(a[1]) + Vector3(0, 0, float(a[0]) * flen)
				var p10 := base + d0 * float(b[1]) + Vector3(0, 0, float(b[0]) * flen)
				var p11 := base + d1 * float(b[1]) + Vector3(0, 0, float(b[0]) * flen)
				for v in [[p00, d0, a[0]], [p10, d0, b[0]], [p11, d1, b[0]], [p00, d0, a[0]], [p11, d1, b[0]], [p01, d1, a[0]]]:
					st.set_normal(v[1])
					st.set_uv(Vector2(0, float(v[2])))
					st.add_vertex(v[0])
	_flames.mesh = st.commit()
	_flames.material_override = _flame_mat
	_flames.visible = false
	_body.add_child(_flames)
	_place_particles()


# --- materials ----------------------------------------------------------------

func _make_materials() -> void:
	if _trim_mat == null:
		_trim_mat = StandardMaterial3D.new()
		_trim_mat.vertex_color_use_as_albedo = true
		_trim_mat.roughness = 0.55
		_trim_mat.metallic = 0.1
		_chrome_mat = StandardMaterial3D.new()
		_chrome_mat.vertex_color_use_as_albedo = true
		_chrome_mat.metallic = 1.0
		_chrome_mat.roughness = 0.12
	_paint_mat = ShaderMaterial.new()
	_paint_mat.shader = PAINT_SHADER
	_lights_mat = ShaderMaterial.new()
	_lights_mat.shader = LIGHTS_SHADER
	_wheel_mat = ShaderMaterial.new()
	_wheel_mat.shader = WHEEL_SHADER
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.roughness = 0.03
	_glass_mat.metallic = 0.2
	_glass_mat.metallic_specular = 0.9
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = GLOW_SHADER
	_glow_mat.set_shader_parameter("phase", randf() * 10.0)
	_flame_mat = ShaderMaterial.new()
	_flame_mat.shader = FLAME_SHADER


func _apply_materials() -> void:
	var g := shape.g
	_paint_mat.set_shader_parameter("paint_color", Color(String(style["paint"])))
	_paint_mat.set_shader_parameter("accent_color", Color(String(style["accent"])))
	_paint_mat.set_shader_parameter("finish", maxi(CarDefs.FINISHES.find(String(style["finish"])), 0))
	_paint_mat.set_shader_parameter("livery", maxi(CarDefs.LIVERIES.find(String(style["livery"])), 0))
	_paint_mat.set_shader_parameter("carbon", bool(style["hood_carbon"]))
	_paint_mat.set_shader_parameter("half_length", float(g["length"]) * 0.5)
	_paint_mat.set_shader_parameter("half_width", float(g["width"]) * 0.5)
	_paint_mat.set_shader_parameter("belt_y", shape.belt(0.5))
	_paint_mat.set_shader_parameter("sill_y", shape.bot(0.5))
	var tint := float(style["tint"])
	_glass_mat.albedo_color = Color(0.03, 0.04, 0.05, lerpf(0.45, 0.94, tint))
	_lights_mat.set_shader_parameter("head_color", Color(String(style["headlight"])))
	_wheel_mat.set_shader_parameter("rim_color", Color(String(style["rim_color"])))
	_wheel_mat.set_shader_parameter("caliper_color", Color(String(style["caliper"])))
	var uc := Color(String(style["underglow"]))
	_glow_mat.set_shader_parameter("glow_color", uc)
	if _glow_light:
		_glow_light.light_color = uc
	for sp in _head_spots:
		sp.light_color = Color(String(style["headlight"]))
	if _plate:
		_plate.text = String(style["plate"])


func _update_glow_mode() -> void:
	var mode := maxi(CarDefs.UNDERGLOW_MODES.find(String(style.get("underglow_mode", "off"))), 0)
	if _glow_mat:
		_glow_mat.set_shader_parameter("mode", mode)
	set_process(_glow_light != null and mode >= 2)


func _apply_ride() -> void:
	var rh := float(style.get("ride_height", 0.0))
	var off := lerpf(0.0, RIDE_LOW, -rh) if rh < 0.0 else lerpf(0.0, RIDE_HIGH, rh)
	_body.position = Vector3(0, -float(shape.g["wheel_radius"]) + off, 0)
	_place_particles()


func _process(_delta: float) -> void:
	# animate the underglow light to match the blob shader (pulse/strobe/rainbow)
	if _glow_light == null or not _glow_light.visible:
		return
	var t := float(Time.get_ticks_msec()) / 1000.0 + float(_glow_mat.get_shader_parameter("phase"))
	var mode := int(_glow_mat.get_shader_parameter("mode"))
	var base_e := 2.0
	match mode:
		2:
			_glow_light.light_energy = base_e * (0.35 + 0.65 * (0.5 + 0.5 * sin(t * 3.2)))
		3:
			_glow_light.light_energy = base_e * (0.9 if fposmod(t * 5.0, 1.0) >= 0.45 else 0.1)
		4:
			_glow_light.light_color = Color.from_hsv(fposmod(t * 0.35 + 0.3, 1.0), 1.0, 1.0)
			_glow_light.light_energy = base_e
		_:
			_glow_light.light_energy = base_e
