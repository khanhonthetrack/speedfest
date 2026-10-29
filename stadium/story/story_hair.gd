class_name StoryHair
## The cast's hair in cutscenes (docs/CINEMATICS.md, third pass): the MakeHuman shells (StoryCast)
## dressed in a strand shader instead of the import's plain material. Their painted textures are dark
## and their tints darker (a few thousandths of white), so all that showed was the gloss of a smooth
## shell: a "plastic helmet". Here the colour is the hair's own (near-black brown, a few per cent),
## the painted texture only its strands' detail; the light runs across the strands (Kajiya-Kay, two
## shifted lobes), shines through them from behind (a rim), the back faces are darker, and the edges
## break up into strands. "wet" (an instance uniform, 0..1): darker, clumped, a sharper shine.
## Two passes: the strands are half see-through (their texture's alpha), and through them the scalp's
## lit skin showed, so near-black hair read as lavender or pink; under them an opaque cap (the same
## shell a hair inwards, wherever the strands are dense) in the hair's own colour, which also
## casts the hair's shadow.

## The hair's colour per cast member (sRGB), where the sidecar's tint isn't it: the looks the owner
## picked (Kit's near-black brown; the passenger's black, soaked).
const COLOUR := {"kit": "#2e2622", "passenger": "#231e1c", "dee": "#2c211b"}

static var _shader: Shader
static var _cap_shader: Shader
static var _mats := {}               ## texture + colour -> material
static var _means := {}              ## texture -> its mean luminance where it covers


## Every hair surface of a cast member's instance in the strand shader.
static func dress(root: Node3D, id: String) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for k in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(k) as StandardMaterial3D
			if src != null and src.resource_name.begins_with("hair__") and src.albedo_texture != null:
				mi.set_surface_override_material(k, material(src, colour(id, src)))


## A hair's colour: the table's, else the material's own tint, kept between a black's 1.8 % and a
## grey's 35 % (linear luminance).
static func colour(id: String, src: StandardMaterial3D) -> Color:
	if COLOUR.has(id):
		return Color(String(COLOUR[id]))
	var c := Color(src.albedo_color.r, src.albedo_color.g, src.albedo_color.b)
	var lin := c.srgb_to_linear()
	var l := lin.r * 0.2126 + lin.g * 0.7152 + lin.b * 0.0722
	if l > 0.0 and (l < 0.018 or l > 0.35):
		lin *= clampf(l, 0.018, 0.35) / l
		c = lin.linear_to_srgb()
	return c


static func material(src: StandardMaterial3D, c: Color) -> ShaderMaterial:
	var key := "%s|%s" % [src.albedo_texture.get_rid(), c.to_html()]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.resource_name = src.resource_name
	m.shader = _shader
	m.set_shader_parameter("strand_tex", src.albedo_texture)
	m.set_shader_parameter("hair_colour", c)
	m.set_shader_parameter("tex_mean_lum", _mean(src.albedo_texture))
	if _cap_shader == null:
		_cap_shader = Shader.new()
		_cap_shader.code = CAP_SHADER
	var cap := ShaderMaterial.new()
	cap.shader = _cap_shader
	cap.set_shader_parameter("strand_tex", src.albedo_texture)
	cap.set_shader_parameter("hair_colour", c)
	m.next_pass = cap
	_mats[key] = m
	return m


## Wets a cast member's hair (0 dry .. 1 soaked).
static func set_wet(root: Node3D, w: float) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for k in mi.mesh.get_surface_count():
			if mi.get_surface_override_material(k) is ShaderMaterial and \
					(mi.get_surface_override_material(k) as ShaderMaterial).shader == _shader:
				mi.set_instance_shader_parameter("wet", w)
				break


## A texture's mean linear luminance where it covers (alpha-weighted), from a 64 x 64 copy.
static func _mean(tex: Texture2D) -> float:
	if _means.has(tex.get_rid()):
		return _means[tex.get_rid()]
	var out := 0.03
	var img := tex.get_image()
	if img != null:
		img = img.duplicate() as Image
		if img.is_compressed():
			img.decompress()
		img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
		var sum := 0.0
		var cover := 0.0
		for y in 64:
			for x in 64:
				var p := img.get_pixel(x, y)
				var l := p.srgb_to_linear()
				sum += (l.r * 0.2126 + l.g * 0.7152 + l.b * 0.0722) * p.a
				cover += p.a
		if cover > 0.0:
			out = maxf(sum / cover, 0.002)
	_means[tex.get_rid()] = out
	return out


## The cap under the strands: opaque where they cover well (not at the hairline, where the strands
## thin over the skin: a hard edge there read as a headband), the hair's colour a little darker (it
## lies in their shade), little shine of its own (the strands carry it).
const CAP_SHADER := """shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D strand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 hair_colour : source_color = vec3(0.18, 0.15, 0.13);
uniform float tone = 0.9;           // the cap's colour against the strands' (it lies in their shade)
uniform float cover = 0.62;         // the strands' coverage where the cap starts (not at the hairline)
instance uniform float wet = 0.0;
void vertex() { VERTEX -= NORMAL * 0.002; }
void fragment() {
	ALBEDO = hair_colour * tone * mix(1.0, 0.65, wet);
	ROUGHNESS = 0.8;
	SPECULAR = 0.1;
	AO = 0.5;
	ALPHA = texture(strand_tex, UV).a;
	ALPHA_SCISSOR_THRESHOLD = cover;
}
"""

const SHADER := """shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;
uniform sampler2D strand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 hair_colour : source_color = vec3(0.18, 0.15, 0.13);
uniform float tex_mean_lum = 0.03;
uniform float detail = 0.55;        // how much of the painted strands' light and dark shows
uniform float paint = 0.3;          // how much of its broad shading (a parting, roots)
uniform float spec1 = 0.03;         // the primary shine: white, sharp, shifted to the tip
uniform float exp1 = 160.0;
uniform float shift1 = -0.08;
uniform float spec2 = 0.025;        // the secondary: tinted by the hair, broad, shifted to the root
uniform float exp2 = 28.0;
uniform float shift2 = 0.12;
uniform float shift_noise = 0.12;
uniform float wrap = 0.4;
uniform float transmit = 0.12;      // light through the strands from behind: the rim (more: a halo round heads)
uniform float backface = 0.55;
uniform float rim_cut = 0.6;        // the edges broken into strands
instance uniform float wet = 0.0;
varying vec3 v_strand;
varying float v_detail;
varying float v_cov;
varying float v_clump;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
float hash(float x) { return fract(sin(x * 12.9898) * 43758.5453); }

void fragment() {
	vec4 t = texture(strand_tex, UV);
	vec3 low = textureLod(strand_tex, UV, 5.0).rgb;
	float d = clamp(lum(t.rgb) / max(lum(low), 0.002), 0.3, 2.0);
	float clump = hash(floor(UV.x * mix(900.0, 260.0, wet)));
	vec3 col = hair_colour * mix(1.0, d, detail) * mix(1.0, clamp(lum(low) / tex_mean_lum, 0.3, 2.0), paint);
	col *= FRONT_FACING ? 1.0 : backface;
	col *= mix(1.0, 0.55 * (0.6 + 0.4 * clump), wet);
	ALBEDO = col;
	AO = FRONT_FACING ? 0.85 : 0.35;
	ROUGHNESS = mix(0.72, 0.45, wet);
	SPECULAR = mix(0.15, 0.06, wet);     // (wet hair: darker, its sheen in the strands' own lobes, not the sky's)
	float grazing = 1.0 - abs(dot(NORMAL, VIEW));
	float cut = smoothstep(0.5, 0.9, grazing) * rim_cut * mix(1.0, 0.8, wet);      // (wet strands clump: fewer gaps)
	ALPHA = t.a * smoothstep(cut - 0.1, cut + 0.1, 0.6 * d + 0.4 * clump);
	v_strand = normalize(BINORMAL);
	v_detail = d;
	v_cov = t.a;
	v_clump = clump;
}

void light() {
	vec3 H = normalize(LIGHT + VIEW);
	float s = (v_detail - 1.0) * shift_noise;
	vec3 t1 = normalize(v_strand + NORMAL * (shift1 + s));
	vec3 t2 = normalize(v_strand + NORMAL * (shift2 + s));
	vec3 lc = LIGHT_COLOR * ATTENUATION;
	float ndl = dot(NORMAL, LIGHT);
	DIFFUSE_LIGHT += lc * max(0.0, (ndl + wrap) / (1.0 + wrap)) / PI;
	float th1 = dot(t1, H);
	float th2 = dot(t2, H);
	float k1 = smoothstep(-1.0, 0.0, th1) * pow(sqrt(max(1.0 - th1 * th1, 0.0)), mix(exp1, 2.0 * exp1, wet));
	float k2 = smoothstep(-1.0, 0.0, th2) * pow(sqrt(max(1.0 - th2 * th2, 0.0)), exp2);
	vec3 tint = normalize(ALBEDO + vec3(1e-4)) * 1.7;
	vec3 spec = lc * SPECULAR_AMOUNT * smoothstep(-0.2, 0.3, ndl) * (spec1 * k1 * mix(1.0, 0.5 + v_clump, wet) + spec2 * k2 * tint);
	// through the strands from behind: at the silhouette only (thin there), not the whole shell
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	spec += lc * transmit * mix(1.0, 0.4, wet) * pow(clamp(dot(-LIGHT, VIEW), 0.0, 1.0), 4.0) * edge * (1.0 - 0.5 * v_cov) * sqrt(ALBEDO);
	SPECULAR_LIGHT += min(spec, lc * 0.035 / PI);   // (dark hair gives back about 1 % of a light: more, and a
	                                                // light by the lens greys the whole head)
}
"""
