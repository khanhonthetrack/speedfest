class_name SceneryMat
extends RefCounted
## Shared scenery materials (few materials = few state changes). Shaders live in
## res://shaders/env_*.gdshader.

static var _shaders: Dictionary = {}


static func shader(shader_name: String) -> Shader:
	if not _shaders.has(shader_name):
		_shaders[shader_name] = load("res://shaders/env_%s.gdshader" % shader_name)
	return _shaders[shader_name]


static func shader_mat(shader_name: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(shader_name)
	for k in params:
		m.set_shader_parameter(k, params[k])
	if shader_name == "building" and not params.has("relief"):
		# recessed, interior-mapped windows: Forward+ from Medium, web from High
		var relief := Settings.quality >= 1 if not Settings.is_compat() else Settings.quality >= 2
		m.set_shader_parameter("relief", 1.0 if relief else 0.0)
		if not Settings.is_compat() and not params.has("wall_color"):
			# lighter walls that catch the neon and the lamps (black boxes read as 2005)
			m.set_shader_parameter("wall_color", Color(0.13, 0.13, 0.15))
			m.set_shader_parameter("wall_color2", Color(0.2, 0.18, 0.18))
	if shader_name == "terrain" and TrackBuilder.use_pbr():
		var ra := TrackBuilder.pbr_texture("rock", "albedo")
		if ra != null:
			m.set_shader_parameter("rock_albedo", ra)
			m.set_shader_parameter("rock_rough", TrackBuilder.pbr_texture("rock", "rough"))
			m.set_shader_parameter("asphalt_albedo", TrackBuilder.pbr_texture("asphalt", "albedo"))
			m.set_shader_parameter("tex_amount", 1.0)
	return m


## Neon / LED: vertex color × energy, unshaded (bloom does the glow).
static func neon(energy := 4.0) -> ShaderMaterial:
	if Settings.is_compat():
		energy *= 0.8
	return shader_mat("neon", {"energy": energy})


## Additive fake light: mode 0 = ground pool, 1 = beam.
static func glow(p_mode: int, energy := 1.0, falloff := 2.0, fade := 600.0) -> ShaderMaterial:
	return shader_mat("glow", {"mode": p_mode, "energy": energy, "falloff": falloff, "fade_distance": fade})


## Plain lit material using vertex colors as albedo.
static func vcolor(roughness := 0.8, metallic := 0.0, cull_off := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	m.metallic = metallic
	if cull_off:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func plain(col: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = roughness
	m.metallic = metallic
	return m


## Neon colour with an HDR boost baked into the vertex color.
static func hdr(c: Color, boost := 1.0) -> Color:
	return Color(c.r * boost, c.g * boost, c.b * boost, 1.0)
