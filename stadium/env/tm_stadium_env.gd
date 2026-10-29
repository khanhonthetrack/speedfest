class_name TmStadiumEnv
extends RefCounted
## The Stadium's light and sky in TMNF's "Day" mood, from our own numbers read off the mood's files
## (Stadium/ConstructionDecorationMood/Day and the Moods/Day colour tables at its day time):
## latitude 48 deg, the day at 0.65 of 24 h with sunrise at 6:00 and sunset at 18:00 (an equinox
## sun: 23 deg up in the south-west); the sun white at intensity 1 with shadows at 0.4; the ambient
## (94, 96, 108); the sky gradient below; clouds between (196, 209, 218) and (250, 251, 251).
## TMNF's north is +z and east +x (Godot: x negated).
## Night (our own numbers, after TMNF's Night mood's look: a dark blue sky, stars, the field under
## the floodlights): a track's mood (`mood` in our track specs, a .Challenge.Gbx's decoration) or
## --mood=night. The moon is the directional light, dim and blue; the Stadium's four floodlight
## heads light the field (TmStage); the global shader value tm_night lights the city (TmTower).

const LATITUDE := 48.0
const DAY_TIME := 0.65             ## of 24 h
const SHADOW := 0.4                ## TMNF's shadow intensity (the sun light's)
const SHADOW_OPACITY := 0.85       ## Godot's: our sky ambient is darker than TMNF's flat one
const AMBIENT := Color8(94, 96, 108)
const CLOUD_LO := Color8(196, 209, 218)
const CLOUD_HI := Color8(250, 251, 251)
## The sky from the zenith (first) to the horizon (last), every 16th row of the mood's sky table.
const SKY := [Color8(62, 105, 159), Color8(65, 112, 171), Color8(69, 121, 181), Color8(74, 128, 191),
	Color8(80, 138, 197), Color8(86, 143, 199), Color8(91, 148, 202), Color8(96, 152, 202),
	Color8(101, 157, 203), Color8(109, 164, 208), Color8(117, 170, 211), Color8(128, 179, 215),
	Color8(143, 189, 220), Color8(162, 200, 225), Color8(182, 212, 230), Color8(201, 222, 235),
	Color8(213, 229, 240)]
## Night: the sky from the zenith to the horizon (the city's glow low down), clouds, ambient, moon.
const SKY_NIGHT := [Color8(3, 5, 12), Color8(4, 6, 14), Color8(4, 7, 16), Color8(5, 8, 18),
	Color8(6, 9, 20), Color8(7, 10, 22), Color8(8, 12, 25), Color8(9, 13, 27), Color8(11, 15, 30),
	Color8(13, 17, 33), Color8(15, 19, 36), Color8(18, 22, 39), Color8(22, 25, 42), Color8(28, 29, 45),
	Color8(36, 34, 48), Color8(46, 40, 50), Color8(58, 47, 52)]
const CLOUD_LO_NIGHT := Color8(10, 11, 16)
const CLOUD_HI_NIGHT := Color8(38, 36, 44)
const AMBIENT_NIGHT := Color8(30, 36, 56)
const MOON := Vector3(0.35, 0.82, -0.45)   ## towards the moon (Godot axes)

static var night := false          ## the mood of the last environment added


## The mood of a map: "night" for night maps (a .Challenge.Gbx's decoration or our spec's mood),
## else "day"; --mood= overrides.
static func mood_of(challenge: TmChallenge) -> String:
	var m := String(TestHooks.arg("mood", ""))
	if m.is_empty() and challenge != null:
		m = "night" if challenge.decoration.to_lower().contains("night") else "day"
	return "night" if m.to_lower() == "night" else "day"


## The direction towards the sun (Godot axes) at the mood's day time: hour angle from noon, an
## equinox declination (sunrise 6:00, sunset 18:00), azimuth from north through east.
static func sun_direction(day_time := DAY_TIME, latitude := LATITUDE) -> Vector3:
	var h := deg_to_rad((day_time * 24.0 - 12.0) * 15.0)
	var lat := deg_to_rad(latitude)
	var el := asin(cos(lat) * cos(h))
	var az := atan2(sin(h), cos(h) * sin(lat)) + PI
	return Vector3(-sin(az) * cos(el), sin(el), cos(az) * cos(el))


## Sun, sky, ambient light and haze under `parent` (mood "day" or "night"; "": --mood=, else day);
## returns the WorldEnvironment.
static func add(parent: Node, mood := "") -> WorldEnvironment:
	if mood.is_empty():
		mood = mood_of(null)
	night = mood == "night"
	RenderingServer.global_shader_parameter_set(&"tm_night", 1.0 if night else 0.0)
	# a City map switches these on after (TmNeon.setup, TmStadiumEnv.city): off everywhere else
	RenderingServer.global_shader_parameter_set(&"tm_neon", 0.0)
	RenderingServer.global_shader_parameter_set(&"tm_city_led", 1.0)     # (a story's set may have changed them)
	RenderingServer.global_shader_parameter_set(&"tm_city_lit", 0.3)
	RenderingServer.global_shader_parameter_set(&"tm_wet", 0.0)
	var sun := DirectionalLight3D.new()
	sun.name = "Moon" if night else "Sun"
	var to_sun := MOON.normalized() if night else sun_direction()
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	sun.light_color = Color(0.62, 0.72, 1.0) if night else Color.WHITE
	sun.light_energy = 0.22 if night else 1.1
	sun.shadow_enabled = bool(TmUi.setting("shadows"))
	sun.shadow_opacity = float(TestHooks.arg("shadow", SHADOW_OPACITY))
	sun.directional_shadow_max_distance = 700.0
	sun.directional_shadow_blend_splits = true
	parent.add_child(sun)

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://env/tm_sky.gdshader")
	var stops := PackedVector3Array()
	for c: Color in (SKY_NIGHT if night else SKY):
		var l := c.srgb_to_linear()
		stops.append(Vector3(l.r, l.g, l.b))
	sky_mat.set_shader_parameter("stops", stops)
	var lo := (CLOUD_LO_NIGHT if night else CLOUD_LO).srgb_to_linear()
	var hi := (CLOUD_HI_NIGHT if night else CLOUD_HI).srgb_to_linear()
	sky_mat.set_shader_parameter("cloud_lo", Vector3(lo.r, lo.g, lo.b))
	sky_mat.set_shader_parameter("cloud_hi", Vector3(hi.r, hi.g, hi.b))
	var cn := FastNoiseLite.new()
	cn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cn.frequency = 0.012
	cn.fractal_octaves = 5
	cn.seed = 17
	var ct := NoiseTexture2D.new()
	ct.width = 512
	ct.height = 512
	ct.seamless = true
	ct.generate_mipmaps = true
	ct.noise = cn
	sky_mat.set_shader_parameter("cloud_noise", ct)
	if night:
		sky_mat.set_shader_parameter("stars", 1.0)
		sky_mat.set_shader_parameter("sun_size", 0.99993)
		sky_mat.set_shader_parameter("sun_glow", 0.06)
		sky_mat.set_shader_parameter("disc_energy", 9.0)
	# a worn texture mod's own cloud layer (TMNF's Moods/StadiumFXClouds: a tiling grey pattern)
	var clouds: Texture2D = TmMaterials.mod.texture("StadiumFXClouds") if TmMaterials.mod != null else null
	if clouds != null:
		sky_mat.set_shader_parameter("cloud_noise", clouds)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_QUALITY

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = AMBIENT_NIGHT if night else AMBIENT
	env.ambient_light_energy = 0.5 if night else 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.85
	# graded for contrast and colour (the independent review: the image was washed out, pale
	# grey-blue; filmic and AgX tonemapping made it worse)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.12
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = ((SKY_NIGHT if night else SKY)[SKY.size() - 1] as Color)
	env.fog_density = 0.0001 if night else 0.00007
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect = 0.0
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.45 if night else 0.25
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 0.9 if night else 1.2
	TmRtx.apply_environment(env, sun)
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	parent.add_child(we)
	return we


## The surfaces that get wet on a wet map (TmMaterials keys -> how much: blocks/tm_textured.gdshader).
const WET := {"asphalt": 1.0, "platform": 1.0, "shoulder": 0.9, "road_grid": 0.8, "border_panel": 0.6,
	"border_ribs": 0.6, "border_black": 0.6, "curb_face": 0.6, "road_metal": 0.5}


## A City map's look (M14, owner: "Improve it for RTX ... I want to see the ray tracing"; then
## "Logically, what's the source of light?"): at night the light comes from what is there: the
## street lights, the neon, the lit windows, a faint moon. So the moon is down to a glimmer that
## shows the towers' outlines, the ambient a near-black blue (not the sky's), SDFGI (Ultra) bounces
## only the lights and emitters (not the sky); the roads wet (tm_wet: SSR mirrors the neon and the
## towers in them on Ultra); AgX tonemapping (neon cores burn white, their halos keep the colour), a
## wider glow, a dark haze, on Ultra thin volumetric fog the lights glow in, longer reflection
## traces. Measured (light_diag, F02): the moon, the Stadium's floodlights and SDFGI's sky light
## had the far towers at a flat blue-grey. By day: as any map, dry.
static func city(we: WorldEnvironment, night_city: bool) -> void:
	for key: String in WET:
		var m := TmMaterials.get_material(key) as ShaderMaterial
		if m != null and m.shader != null and String(m.shader.resource_path).ends_with("tm_textured.gdshader"):
			m.set_shader_parameter("wet_affect", float(WET[key]))
	if not night_city:
		return
	RenderingServer.global_shader_parameter_set(&"tm_wet", 1.0)
	var env := we.environment
	var moon := we.get_parent().get_node_or_null("Moon") as DirectionalLight3D
	if moon != null:
		moon.light_energy = 0.04
		moon.shadow_enabled = false
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.03, 0.035, 0.055)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.95
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.08
	env.glow_enabled = int(TmUi.setting("quality")) > 0
	env.glow_intensity = 0.5
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.3
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		env.set_glow_level(i, [0.0, 0.6, 1.0, 1.0, 0.8, 0.6, 0.3][i])
	# a dark haze (a light one lifted the far towers to a flat lavender grey): they stay dark,
	# their lit floors and neon show through it
	env.fog_light_color = Color(0.028, 0.022, 0.05)
	env.fog_density = 0.00022
	env.fog_aerial_perspective = 0.15
	if env.volumetric_fog_enabled:
		env.volumetric_fog_density = 0.0022
		env.volumetric_fog_albedo = Color(0.7, 0.74, 0.85)
		env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
		env.volumetric_fog_emission_energy = 0.0
		env.volumetric_fog_anisotropy = 0.45
		env.volumetric_fog_length = 260.0
		env.volumetric_fog_detail_spread = 1.6
		env.volumetric_fog_ambient_inject = 0.0
	if env.sdfgi_enabled:
		env.sdfgi_read_sky_light = false
		env.sdfgi_energy = 1.2
		env.sdfgi_bounce_feedback = 0.55
	if env.ssr_enabled:
		env.ssr_max_steps = 160
		env.ssr_depth_tolerance = 0.4
		env.ssr_fade_out = 2.0

