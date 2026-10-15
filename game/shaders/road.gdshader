shader_type spatial;
// SpeedFest road surface. Works on Forward+ and Compatibility.
// UV.x = meters from the left road edge, UV.y = meters along the track.
// UV2.x = half width (m), UV2.y = curb amount (0..1, from track curvature).

uniform vec4 asphalt_color : source_color = vec4(0.11, 0.11, 0.12, 1.0);
uniform vec4 edge_color : source_color = vec4(0.92, 0.92, 0.9, 1.0);
uniform float edge_emission = 0.0;
uniform vec4 curb_a : source_color = vec4(0.85, 0.08, 0.08, 1.0);
uniform vec4 curb_b : source_color = vec4(0.92, 0.92, 0.92, 1.0);
uniform int center_mode = 1;      // 0 none, 1 dashed white lanes, 2 double yellow
uniform int lane_count = 3;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float tech_panels = 0.0;   // arena: panel seams and a glowing center guide
uniform float paint_glow = 0.1;    // retro-reflective paint: stays readable in the dark
uniform vec4 tunnel_light : source_color = vec4(1.0, 0.62, 0.3, 1.0);
uniform float tunnel_fake = 0.25;  // fake sodium bounce inside tunnels (UV2.y >= 2 marks tunnels)
// PBR asphalt (tools/textures/gen_textures.py, 2 m tile). tex_amount 0 = procedural grain only.
uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_amount = 0.0;
uniform float tex_scale = 0.5;      // tiles per meter
uniform float normal_depth = 1.0;

varying vec2 v_world;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float band(float x, float a, float b, float aa) {
	return smoothstep(a - aa, a + aa, x) * (1.0 - smoothstep(b - aa, b + aa, x));
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float hw = UV2.x;
	float in_tunnel = step(1.5, UV2.y);
	float curb_amt = UV2.y - 2.0 * in_tunnel;
	float x = UV.x - hw;            // lateral, + right
	float ax = abs(x);
	float d = UV.y;
	float aa = max(fwidth(UV.x), 0.01) * 0.75;
	float aay = max(fwidth(UV.y), 0.01) * 0.75;

	// asphalt: grain + large patches + tyre-worn racing lanes
	// fade fine grain out with distance (it aliases into streaks otherwise)
	float lod = clamp(max(fwidth(UV.x), fwidth(UV.y)) * 6.0, 0.0, 1.0);
	float grain = vnoise(UV * vec2(9.0, 9.0)) * 0.5 + mix(vnoise(UV * vec2(31.0, 29.0)), 0.5, lod) * 0.5;
	grain = mix(grain, 0.5, lod * 0.7);
	float patches = vnoise(v_world * 0.045) * 0.6 + vnoise(v_world * 0.13) * 0.4;
	vec3 col = asphalt_color.rgb * (0.82 + 0.22 * grain) * (0.85 + 0.3 * patches);
	float worn = exp(-pow((ax - hw * 0.4) / (hw * 0.18), 2.0));
	col *= 1.0 - 0.12 * worn;
	float rough = 0.82 - 0.1 * worn;
	vec3 tex_n = vec3(0.5, 0.5, 1.0);
	if (tex_amount > 0.0) {
		vec2 tuv = UV * tex_scale;
		// detail relative to the texture's own average (its 1x1 mip), so asphalt_color stays the
		// tint and the result doesn't depend on how a driver decodes sRGB (compat/WebGL differ)
		vec3 ta = texture(tex_albedo, tuv).rgb / max(textureLod(tex_albedo, vec2(0.5), 12.0).rgb, vec3(0.005));
		vec3 tcol = asphalt_color.rgb * ta * (0.85 + 0.3 * patches) * (1.0 - 0.12 * worn);
		col = mix(col, tcol, tex_amount);
		// polished wheel tracks: smoother aggregate on the racing lanes
		rough = mix(rough, texture(tex_rough, tuv).r * (1.0 - 0.12 * worn), tex_amount);
		tex_n = mix(tex_n, texture(tex_normal, tuv).rgb, tex_amount);
	}

	vec3 paint = vec3(0.0);
	float paint_a = 0.0;
	// edge lines
	float e_in = hw - 0.95;
	float edge = band(ax, e_in, e_in + 0.28, aa);
	paint_a = max(paint_a, edge);
	paint = edge_color.rgb;
	// lane separators
	if (center_mode == 1) {
		for (int i = 1; i < 4; i++) {
			if (i >= lane_count) break;
			float lx = -hw + 2.0 * hw * float(i) / float(lane_count);
			float dash = band(fract(d / 9.0), 0.0, 0.45, aay / 9.0);
			float l = band(x, lx - 0.12, lx + 0.12, aa) * dash;
			if (l > paint_a) { paint = vec3(0.92); }
			paint_a = max(paint_a, l);
		}
	} else if (center_mode == 2) {
		float l = band(ax, 0.12, 0.27, aa);
		if (l > 0.01) { paint = vec3(0.95, 0.72, 0.1); }
		paint_a = max(paint_a, l);
	}
	// worn paint
	paint_a *= 0.75 + 0.25 * vnoise(UV * vec2(3.0, 0.7));

	// curbs on corners (outermost 0.75 m)
	float curb_zone = smoothstep(hw - 0.78 - aa, hw - 0.74 + aa, ax) * step(0.05, curb_amt);
	float stripe = step(0.5, fract(d / 2.4));
	vec3 curb_col = mix(curb_a.rgb, curb_b.rgb, stripe);
	col = mix(col, paint, paint_a);
	col = mix(col, curb_col, curb_zone * smoothstep(0.05, 0.4, curb_amt));
	rough = mix(rough, 0.5, paint_a);
	rough = mix(rough, 0.45, curb_zone);

	// arena tech panels: seams every 6 m across and at lane thirds, faint glowing center dashes
	vec3 tech_glow = vec3(0.0);
	if (tech_panels > 0.5) {
		float seam = band(fract(d / 6.0), 0.0, 0.012, aay / 6.0) + band(ax, hw * 0.33 - 0.03, hw * 0.33 + 0.03, aa);
		col *= 1.0 - 0.45 * clamp(seam, 0.0, 1.0) * (1.0 - curb_zone);
		float cdash = band(ax, 0.0, 0.1, aa) * band(fract(d / 12.0), 0.0, 0.3, aay / 12.0);
		tech_glow = edge_color.rgb * cdash * 0.8;
		col += tech_glow * 0.2;
	}

	// wet: darker, glossy, puddles
	float puddle = smoothstep(0.55, 0.72, vnoise(v_world * 0.09) * 0.7 + vnoise(v_world * 0.31) * 0.3);
	float wet = wetness * (0.65 + 0.35 * puddle);
	col *= 1.0 - 0.35 * wet;
	rough = mix(rough, 0.06, wet);
	// water fills the texture: flatter normals where it's wet, flattest in the puddles
	tex_n = mix(tex_n, vec3(0.5, 0.5, 1.0), wet * 0.75);

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.5 + 0.3 * wet;
	NORMAL_MAP = tex_n;
	NORMAL_MAP_DEPTH = normal_depth;
	EMISSION = edge_color.rgb * edge * edge_emission * (1.0 - curb_zone) + tech_glow * edge_emission * 0.5;
	EMISSION += paint * paint_a * paint_glow;
	EMISSION += tunnel_light.rgb * (0.16 + 0.6 * col) * tunnel_fake * in_tunnel * (1.0 - 0.4 * smoothstep(0.0, hw, ax));
}
