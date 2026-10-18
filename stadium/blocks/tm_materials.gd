class_name TmMaterials
extends RefCounted
## Materials of the recreated blocks and the Stadium, by key. With HD graphics on (the default;
## TmUi setting "hd") most keys get our procedural surface shader (blocks/tm_surface.gdshader:
## world-space concrete, grass, dirt, grids, panels, seats, screens... in the Stadium's colours,
## the main ones measured from TMNF's textures locally: road and platform (165, 164, 161) and
## (166, 165, 162), grass (52, 75, 40), dirt (67, 61, 49), parking blue (50, 75, 157)); off, or for
## the keys without one, flat colours: [albedo, roughness, metallic(, emission energy)].
## Unknown keys get a magenta debug material.

static var _cache := {}
static var _noise_fine: NoiseTexture2D
static var _noise_coarse: NoiseTexture2D

const COLORS := {
	"asphalt": [Color8(165, 164, 161), 0.85, 0.0],
	"platform": [Color8(166, 165, 162), 0.8, 0.0],
	"rubber": [Color(0.78, 0.12, 0.10), 0.7, 0.0],
	"rubber_white": [Color(0.92, 0.92, 0.92), 0.7, 0.0],
	"curb_face": [Color(0.14, 0.14, 0.15), 0.75, 0.0],
	"curb_outer": [Color(0.14, 0.14, 0.15), 0.75, 0.0],
	"shoulder": [Color(0.24, 0.52, 0.27), 0.75, 0.0],
	"curb_top": [Color(0.80, 0.80, 0.79), 0.8, 0.0],
	"road_lip": [Color(0.80, 0.80, 0.79), 0.8, 0.0],
	"metal": [Color(0.62, 0.64, 0.68), 0.45, 0.7],
	"grid": [Color(0.42, 0.44, 0.48), 0.5, 0.6],
	"wall": [Color(0.88, 0.89, 0.91), 0.75, 0.0],
	"wall_dark": [Color(0.32, 0.34, 0.38), 0.8, 0.0],
	"logo": [Color(0.12, 0.30, 0.72), 0.6, 0.0],
	"screen": [Color(0.12, 0.22, 0.48), 0.3, 0.0, 0.7],     # lit displays, as in TMNF
	"stands": [Color(0.17, 0.29, 0.58), 0.8, 0.0],                  # seats (pattern 7: sectors, rows)
	"structure": [Color(0.30, 0.31, 0.34), 0.7, 0.3],
	"grass": [Color8(66, 98, 48), 0.95, 0.0],
	"dirt": [Color8(92, 78, 58), 0.95, 0.0],
	"water": [Color(0.06, 0.22, 0.32, 0.86), 0.04, 0.0],
	"glass": [Color(0.70, 0.85, 0.95, 0.35), 0.05, 0.0],
	"turbo": [Color(0.95, 0.65, 0.10), 0.5, 0.0],
	"inflatable": [Color(0.95, 0.85, 0.25), 0.6, 0.0],
	"fabric": [Color(0.93, 0.93, 0.94), 0.8, 0.0],
	"fabric_under": [Color(0.80, 0.82, 0.86), 0.85, 0.0],     # the Fabric roofs' underside, in their shade
	"pipe": [Color(0.82, 0.84, 0.88), 0.35, 0.55],
	"rubber_dark": [Color(0.10, 0.10, 0.11), 0.9, 0.0],
	"lamp": [Color(1.0, 0.96, 0.85), 0.3, 0.0, 2.0],
	"sculpt": [Color(0.84, 0.86, 0.90), 0.55, 0.1],
	# gates (blocks/tm_gate_dress.gd): the painted arch, its lit inner face per kind, the banner
	"gate": [Color(0.86, 0.87, 0.90), 0.35, 0.55],
	"gate_glow_start": [Color(0.30, 1.00, 0.45), 0.4, 0.0, 2.6],
	"gate_glow_finish": [Color(1.00, 0.22, 0.18), 0.4, 0.0, 2.6],
	"gate_glow_cp": [Color(0.25, 0.82, 1.00), 0.4, 0.0, 2.6],
	"gate_glow_lap": [Color(1.00, 0.22, 0.18), 0.4, 0.0, 2.6],
	"gate_lamp_start": [Color(0.30, 1.00, 0.45), 0.4, 0.0, 2.2],
	"gate_lamp_finish": [Color(1.00, 0.22, 0.18), 0.4, 0.0, 2.2],
	"gate_lamp_cp": [Color(0.25, 0.82, 1.00), 0.4, 0.0, 2.2],
	"gate_lamp_lap": [Color(1.00, 0.22, 0.18), 0.4, 0.0, 2.2],
	"banner": [Color(0.03, 0.04, 0.07), 0.4, 0.2],
	"gate_shell": [Color(0.13, 0.135, 0.15), 0.7, 0.1],
	"gate_start": [Color(0.88, 0.90, 0.88), 0.7, 0.0],
	"gate_cp": [Color(0.12, 0.12, 0.14), 0.7, 0.0],
	"gate_finish": [Color(0.88, 0.90, 0.88), 0.7, 0.0],
	"curb_start": [Color(0.88, 0.90, 0.88), 0.7, 0.0],
	"curb_cp": [Color(0.12, 0.12, 0.14), 0.7, 0.0],
	"curb_finish": [Color(0.88, 0.90, 0.88), 0.7, 0.0],
	"gate_lamps": [Color(0.95, 0.93, 0.85), 0.5, 0.0, 3.0],
	# the Stadium around the map (env/tm_stadium_build.gd)
	"concrete": [Color(0.78, 0.78, 0.76), 0.9, 0.0],
	"facade": [Color(0.70, 0.71, 0.72), 0.7, 0.1],
	"roof": [Color(0.93, 0.93, 0.95), 0.6, 0.0],
	"roof_under": [Color(0.80, 0.81, 0.83), 0.7, 0.2],
	"mast": [Color(0.92, 0.92, 0.94), 0.4, 0.4],
	"cable": [Color(0.22, 0.22, 0.24), 0.5, 0.5],
	"led": [Color(0.10, 0.22, 0.50), 0.4, 0.0, 0.6],
	"screen_on": [Color(0.25, 0.45, 0.85), 0.3, 0.0, 1.0],
	"parvis": [Color8(150, 148, 150), 0.95, 0.0],
	"parking": [Color8(50, 75, 157), 0.9, 0.0],
	"road_dark": [Color8(86, 84, 87), 0.9, 0.0],
	"plain": [Color(0.42, 0.47, 0.38), 1.0, 0.0],
	"flag_0": [Color(0.85, 0.12, 0.12), 0.8, 0.0],
	"flag_1": [Color(0.10, 0.30, 0.80), 0.8, 0.0],
	"flag_2": [Color(0.95, 0.80, 0.10), 0.8, 0.0],
	"flag_3": [Color(0.10, 0.60, 0.25), 0.8, 0.0],
	"flag_4": [Color(0.95, 0.95, 0.95), 0.8, 0.0],
	"flag_5": [Color(0.95, 0.45, 0.10), 0.8, 0.0],
}

## Textured keys (HD): our own generated maps in assets/tex (stadium/tools/texgen: <name>_albedo,
## _normal, _orm): [texture name, metres one texture covers (u along the sweep, v across it),
## world: planar world mapping (no stretching on curves, for surfaces without a direction)].
const TEXTURED := {
	"asphalt": ["road_concrete", Vector2(16.0, 16.0), true],
	"curb_face": ["road_curb_face", Vector2(8.0, 1.25), false],
	"curb_outer": ["road_curb_face", Vector2(8.0, 1.25), false],
	"shoulder": ["road_shoulder", Vector2(8.0, 2.0), false],
	"curb_top": ["road_curb_top", Vector2(8.0, 1.5), false],
	"road_lip": ["road_curb_top", Vector2(8.0, 1.5), false],
	# gates (road.gd _gate): the arch's faces, the gate block's curb faces, the light rigs
	"gate_start": ["gate_start", Vector2(8.0, 1.25), false],
	"gate_cp": ["gate_cp", Vector2(8.0, 1.25), false],
	"gate_finish": ["gate_finish", Vector2(8.0, 1.25), false],
	"curb_start": ["curb_start", Vector2(8.0, 1.25), false],
	"curb_cp": ["curb_cp", Vector2(8.0, 1.25), false],
	"curb_finish": ["curb_finish", Vector2(8.0, 1.25), false],
	"gate_lamps": ["gate_lamps", Vector2(2.0, 1.0), false],
	# the grandstands' wave roofs (fabric.gd), the platforms' skirts
	"fabric": ["fabric_top", Vector2(8.0, 8.0), false],
	"fabric_under": ["fabric_under", Vector2(8.0, 8.0), false],
	# the Stadium around the field (env/tm_stadium_build.gd): world-mapped
	"facade": ["stadium_facade", Vector2(16.0, 16.0), true],
	"concrete": ["stadium_concrete", Vector2(16.0, 16.0), true],
	"roof": ["fabric_top", Vector2(16.0, 16.0), true],
	# inflatable cushion walls (8 m pillows on the 8 m grid), the tube network's pillars and pipes
	"inflatable": ["inflatable_vinyl", Vector2(8.0, 8.0), true],
	"pipe": ["pillar_steel", Vector2(8.0, 8.0), true],
}

## The surface shader per key: [pattern, second colour, pattern size (m), variation, bump].
## Patterns: see blocks/tm_surface.gdshader.
const SURFACES := {
	"asphalt": [1, Color(0.3, 0.3, 0.3), 0.0, 0.10, 0.015],
	"platform": [1, Color(0.3, 0.3, 0.3), 8.0, 0.08, 0.015],
	"sculpt": [1, Color(0.3, 0.3, 0.3), 4.0, 0.06, 0.012],
	"concrete": [1, Color(0.3, 0.3, 0.3), 6.0, 0.08, 0.015],
	"grass": [2, Color8(98, 112, 58), 8.0, 0.14, 0.02],
	"plain": [2, Color8(98, 112, 58), 24.0, 0.10, 0.0],
	"dirt": [3, Color8(150, 138, 118), 1.0, 0.12, 0.03],
	"grid": [4, Color(0.05, 0.05, 0.06), 0.12, 0.05, 0.01],
	"metal": [5, Color(0.3, 0.3, 0.3), 4.0, 0.06, 0.01],
	"structure": [5, Color(0.3, 0.3, 0.3), 2.0, 0.06, 0.01],
	"gate": [5, Color(0.3, 0.3, 0.3), 3.0, 0.04, 0.005],
	"pipe": [5, Color(0.3, 0.3, 0.3), 3.0, 0.05, 0.0],
	"mast": [5, Color(0.3, 0.3, 0.3), 6.0, 0.04, 0.0],
	"turbo": [6, Color(0.08, 0.08, 0.09), 1.2, 0.05, 0.0],
	"stands": [7, Color(0.24, 0.40, 0.74), 20.0, 0.06, 0.02],
	"screen": [8, Color(0.03, 0.06, 0.16), 1.0, 0.0, 0.0],
	"led": [8, Color(0.02, 0.05, 0.14), 1.0, 0.0, 0.0],
	"screen_on": [8, Color(0.05, 0.10, 0.30), 1.0, 0.0, 0.0],
	"fabric": [9, Color(0.3, 0.3, 0.3), 8.0, 0.05, 0.01],
	"fabric_under": [9, Color(0.3, 0.3, 0.3), 8.0, 0.05, 0.01],
	"roof": [9, Color(0.3, 0.3, 0.3), 15.0, 0.05, 0.01],
	"roof_under": [10, Color(0.30, 0.32, 0.36), 0.6, 0.0, 0.01],
	"wall": [11, Color(0.3, 0.3, 0.3), 4.0, 0.06, 0.01],
	"wall_dark": [11, Color(0.3, 0.3, 0.3), 4.0, 0.06, 0.01],
	"logo": [11, Color(0.3, 0.3, 0.3), 8.0, 0.05, 0.01],
	"parvis": [12, Color(0.3, 0.3, 0.3), 2.0, 0.08, 0.012],
	"parking": [12, Color(0.3, 0.3, 0.3), 5.0, 0.06, 0.0],
	"road_dark": [1, Color(0.3, 0.3, 0.3), 0.0, 0.10, 0.01],
	"rubber": [0, Color(0.3, 0.3, 0.3), 0.0, 0.05, 0.005],
	"rubber_white": [0, Color(0.3, 0.3, 0.3), 0.0, 0.05, 0.005],
	"rubber_dark": [0, Color(0.3, 0.3, 0.3), 0.0, 0.05, 0.005],
	"inflatable": [14, Color(0.95, 0.95, 0.95), 2.4, 0.04, 0.03],
	"lamp": [13, Color(0.10, 0.10, 0.12), 4.0, 0.0, 0.0],
}


## HD graphics: the surface shader (TmUi setting "hd"; --hd=0 turns it off for a run).
static func hd() -> bool:
	# not under the RTX fork's path tracing, which draws custom shaders wrongly (the car vanished;
	# tested on an RTX 2060): there the standard materials, which it traces fully
	return bool(TmUi.setting("hd")) and String(TestHooks.arg("hd", "1")) != "0" and not TmRtx.path_tracing_active()


## Forgets the made materials (after the HD setting changes; the next scene makes them anew).
static func clear_cache() -> void:
	_cache.clear()


## A material made elsewhere, under a key (the stadium's ground with its own class map).
static func register(key: String, m: Material) -> void:
	_cache[key] = m


## The shared noise textures (fine, coarse) the procedural shaders read.
static func noise_textures() -> Array:
	if _noise_fine == null:
		_noise_fine = _noise(0.02, 3, 5)
		_noise_coarse = _noise(0.008, 9, 4)
	return [_noise_fine, _noise_coarse]


static func _noise(freq: float, seed_value: int, octaves: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.seed = seed_value
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.generate_mipmaps = true
	t.noise = n
	return t


static func get_material(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var spec: Array = COLORS.get(key, [Color(1, 0, 1), 0.5, 0.0])
	var m: Material
	if hd() and TEXTURED.has(key):
		m = _textured(TEXTURED[key])
	elif hd() and SURFACES.has(key):
		m = _surface(key, spec)
	elif hd() and key == "water":
		m = _water(spec)
	else:
		m = _flat(spec)
	_cache[key] = m
	return m


static func _flat(spec: Array) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = spec[0]
	m.roughness = spec[1]
	m.metallic = spec[2]
	if spec.size() > 3:
		m.emission_enabled = true
		m.emission = spec[0]
		m.emission_energy_multiplier = spec[3]
	if (spec[0] as Color).a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A textured material (HD): albedo, normal and ORM maps from assets/tex (blocks/tm_textured.gdshader:
## what ORMMaterial3D did, with the map's sky occlusion).
static func _textured(spec: Array) -> ShaderMaterial:
	var metres: Vector2 = spec[1]
	return textured(String(spec[0]), Vector2(1.0 / metres.x, 1.0 / metres.y), bool(spec[2]), 1.0 / metres.x)


## A tm_textured material for texture set `name`: on the mesh UVs times `uv_scale`, or (world) on
## three world planes, `world_scale` textures per metre. Null when the set has no albedo map.
static func textured(name: String, uv_scale := Vector2.ONE, world := false, world_scale := 1.0) -> ShaderMaterial:
	var albedo := _tex(name, "albedo")
	if albedo == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = preload("res://blocks/tm_textured.gdshader")
	m.set_shader_parameter("albedo_tex", albedo)
	m.set_shader_parameter("normal_tex", _tex(name, "normal"))
	m.set_shader_parameter("orm_tex", _tex(name, "orm"))
	var em := _tex(name, "emission")
	m.set_shader_parameter("has_emission", em != null)
	if em != null:
		m.set_shader_parameter("emission_tex", em)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("world", world)
	m.set_shader_parameter("world_scale", world_scale)
	return m


static func _tex(name: String, map: String) -> Texture2D:
	for ext in [".jpg", ".png"]:
		var path := "res://assets/tex/%s_%s%s" % [name, map, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null


## Water (HD): glossy, deep teal, ripples from a noise normal map projected in world space.
static func _water(spec: Array) -> StandardMaterial3D:
	var m := _flat(spec)
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.03
	n.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 4.0
	t.noise = n
	m.normal_enabled = true
	m.normal_texture = t
	m.normal_scale = 0.6
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.12, 0.12, 0.12)
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return m


static func _surface(key: String, spec: Array) -> ShaderMaterial:
	noise_textures()
	var s: Array = SURFACES[key]
	var c: Color = spec[0]
	var m := ShaderMaterial.new()
	m.shader = preload("res://blocks/tm_surface.gdshader")
	m.set_shader_parameter("pattern", int(s[0]))
	m.set_shader_parameter("albedo", Color(c.r, c.g, c.b))   # source_color: sRGB, made linear
	m.set_shader_parameter("albedo2", s[1])
	m.set_shader_parameter("roughness", float(spec[1]))
	m.set_shader_parameter("metallic", float(spec[2]))
	var energy := float(spec[3]) if spec.size() > 3 else 0.0
	if int(s[0]) == 6:
		energy = maxf(energy, 1.0)
	m.set_shader_parameter("emission_energy", energy)
	m.set_shader_parameter("scale", float(s[2]))
	m.set_shader_parameter("variation", float(s[3]))
	m.set_shader_parameter("bump", float(s[4]))
	m.set_shader_parameter("noise_fine", _noise_fine)
	m.set_shader_parameter("noise_coarse", _noise_coarse)
	if int(s[0]) == 8:
		var ads: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Adverts")
		if ads:
			m.set_shader_parameter("advert_tex", ads.call("texture"))
			m.set_shader_parameter("has_advert", true)
			m.set_shader_parameter("ad_scale", 3.0 if key == "screen_on" else 1.0)
	return m
