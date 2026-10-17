class_name TmStadiumEnv
extends RefCounted
## The Stadium's light and sky in TMNF's "Day" mood, from our own numbers read off the mood's files
## (Stadium/ConstructionDecorationMood/Day and the Moods/Day colour tables at its day time):
## latitude 48 deg, the day at 0.65 of 24 h with sunrise at 6:00 and sunset at 18:00 (an equinox
## sun: 23 deg up in the south-west); the sun white at intensity 1 with shadows at 0.4; the ambient
## (94, 96, 108); the sky gradient below; clouds between (196, 209, 218) and (250, 251, 251).
## TMNF's north is +z and east +x (Godot: x negated).

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


## The direction towards the sun (Godot axes) at the mood's day time: hour angle from noon, an
## equinox declination (sunrise 6:00, sunset 18:00), azimuth from north through east.
static func sun_direction(day_time := DAY_TIME, latitude := LATITUDE) -> Vector3:
	var h := deg_to_rad((day_time * 24.0 - 12.0) * 15.0)
	var lat := deg_to_rad(latitude)
	var el := asin(cos(lat) * cos(h))
	var az := atan2(sin(h), cos(h) * sin(lat)) + PI
	return Vector3(-sin(az) * cos(el), sin(el), cos(az) * cos(el))


## Sun, sky, ambient light and haze under `parent`; returns the WorldEnvironment.
static func add(parent: Node) -> WorldEnvironment:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var to_sun := sun_direction()
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	sun.light_color = Color.WHITE
	sun.light_energy = 1.1
	sun.shadow_enabled = bool(TmUi.setting("shadows"))
	sun.shadow_opacity = float(TestHooks.arg("shadow", SHADOW_OPACITY))
	sun.directional_shadow_max_distance = 700.0
	sun.directional_shadow_blend_splits = true
	parent.add_child(sun)

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://env/tm_sky.gdshader")
	var stops := PackedVector3Array()
	for c: Color in SKY:
		var l := c.srgb_to_linear()
		stops.append(Vector3(l.r, l.g, l.b))
	sky_mat.set_shader_parameter("stops", stops)
	var lo := CLOUD_LO.srgb_to_linear()
	var hi := CLOUD_HI.srgb_to_linear()
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
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_QUALITY

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = 0.75
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
	env.fog_light_color = (SKY[SKY.size() - 1] as Color)
	env.fog_density = 0.00007
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect = 0.0
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.2
	TmRtx.apply_environment(env, sun)
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	parent.add_child(we)
	return we
