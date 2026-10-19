shader_type spatial;
// Ground for all themes. UV = world XZ, UV2.x = distance to the road edge (m).
// mode 0 city: wet asphalt lots + paved sidewalks with puddles.
// mode 1 arena: stadium lawn with mowing stripes and a dark apron along the road (no neon grid:
//        owner, session 4).
// mode 2 coast: grass, dry brush, rock on slopes, sand and surf near sea level.

uniform int mode = 0;
uniform float sea_level = 0.0;
uniform float wetness = 1.0;
uniform vec3 grid_color : source_color = vec3(0.0, 0.9, 1.0);
uniform vec3 grid_color2 : source_color = vec3(1.0, 0.17, 0.84);
uniform float grid_energy = 1.4;
uniform float lawn_brightness = 1.0;    // compat has no volumetric fog lift at night: brighten the lawn
// Generated PBR maps (tools/textures/gen_textures.py): rock on coast slopes and cliffs, asphalt
// on city lots. tex_amount 0 = procedural only (quality 0 / textures missing).
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_amount = 0.0;

// Triplanar rock (6 m tile; strata stay horizontal on the side projections).
vec4 rock_tex(vec3 wp, vec3 wn) {
	vec3 w = pow(abs(wn), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec2 ux = vec2(wp.z, -wp.y) / 6.0;
	vec2 uz = vec2(wp.x, -wp.y) / 6.0;
	vec2 uy = wp.xz / 6.0;
	vec3 c = texture(rock_albedo, ux).rgb * w.x + texture(rock_albedo, uz).rgb * w.z + texture(rock_albedo, uy).rgb * w.y;
	// relative to the texture's average (1x1 mip): sRGB decoding differs between drivers
	c = c / max(textureLod(rock_albedo, vec2(0.5), 12.0).rgb, vec3(0.005)) * vec3(0.39, 0.33, 0.26);
	float r = texture(rock_rough, ux).r * w.x + texture(rock_rough, uz).r * w.z + texture(rock_rough, uy).r * w.y;
	return vec4(c, r);
}


float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += vnoise(p) * a;
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

// Stadium lawn: alternating mowing stripes (12 m), soft patchiness and blade-scale noise that
// fades with distance (no shimmer), and a dark rubber apron within ~4 m of the road edge.
vec3 stadium_lawn(vec2 p, float ed) {
	float n = fbm(p * 0.035);
	float fw = max(fwidth(p.x), fwidth(p.y));
	float sx = fract(p.x / 24.0);
	float stripe = smoothstep(0.48, 0.52, sx) * (1.0 - smoothstep(0.98, 1.0, sx));
	vec3 g1 = vec3(0.055, 0.15, 0.045);
	vec3 g2 = vec3(0.085, 0.2, 0.065);
	vec3 c = mix(g1, g2, stripe) * (0.82 + 0.3 * n);
	float blades = vnoise(p * 6.0) * 0.5 + vnoise(p * 17.0) * 0.5;
	c *= 1.0 + (blades - 0.5) * 0.35 * (1.0 - clamp(fw * 4.0, 0.0, 1.0));
	float apron = 1.0 - smoothstep(1.0, 4.0, ed);
	return mix(c, vec3(0.075, 0.075, 0.085) * (0.85 + 0.3 * n), apron);
}

void fragment() {
	// world position/normal per pixel (no custom vertex(): avoids depth-prepass mismatches)
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wnrm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 p = wpos.xz;
	float ed = UV2.x;
	vec3 alb;
	float rough;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	if (mode == 0) {
		// sidewalk band next to the road, then dark lots
		float n = fbm(p * 0.15);
		float tiles = 0.0;
		vec2 tp = fract(p / 1.5);
		vec2 tw = fwidth(p / 1.5);
		float line = smoothstep(0.0, tw.x * 1.5 + 0.02, tp.x) * smoothstep(0.0, tw.y * 1.5 + 0.02, tp.y);
		float walk = 1.0 - smoothstep(4.0, 5.0, ed);
		vec3 asphalt = vec3(0.035, 0.035, 0.042) * (0.7 + 0.6 * n);
		if (tex_amount > 0.0) {
			vec3 at = texture(asphalt_albedo, p * 0.5).rgb / max(textureLod(asphalt_albedo, vec2(0.5), 12.0).rgb, vec3(0.005));
			asphalt = mix(asphalt, vec3(0.035, 0.035, 0.042) * at * (0.7 + 0.6 * n), tex_amount);
		}
		vec3 paving = vec3(0.09, 0.085, 0.09) * mix(0.55, 1.0, line) * (0.8 + 0.4 * h21(floor(p / 1.5)));
		alb = mix(asphalt, paving, walk);
		// curb line
		float curb = smoothstep(0.0, 0.25, ed) * (1.0 - smoothstep(0.35, 0.6, ed));
		alb = mix(alb, vec3(0.16), curb);
		float puddle = smoothstep(0.52, 0.6, fbm(p * 0.07 + 3.0));
		rough = mix(mix(0.45, 0.3, walk), 0.03, puddle * wetness);
		alb *= mix(1.0, 0.45, puddle);
		metal = 0.0;
	} else if (mode == 1) {
		alb = stadium_lawn(p, ed) * lawn_brightness;
		rough = 0.88;
	} else {
		float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
		float n = fbm(p * 0.02);
		float n2 = fbm(p * 0.13 + 7.0);
		vec3 grass = mix(vec3(0.05, 0.11, 0.035), vec3(0.11, 0.17, 0.05), n);
		vec3 brush = mix(vec3(0.16, 0.14, 0.07), vec3(0.24, 0.2, 0.11), n2);
		vec3 rock = mix(vec3(0.17, 0.14, 0.13), vec3(0.3, 0.26, 0.23), n2) * (0.8 + 0.4 * fbm(wpos.xy * 0.2 + wpos.zy * 0.2));
		vec3 sand = vec3(0.55, 0.46, 0.33) * (0.85 + 0.2 * n2);
		alb = mix(grass, brush, smoothstep(0.45, 0.8, n + n2 * 0.3));
		// darker scrub patches
		alb *= 0.75 + 0.35 * smoothstep(0.3, 0.7, fbm(p * 0.06 + 3.0));
		float rk = smoothstep(0.32, 0.5, slope + (n2 - 0.5) * 0.25);
		float rock_r = 0.75;
		if (tex_amount > 0.0) {
			vec4 rt = rock_tex(wpos, wnrm);
			rock = mix(rock, rt.rgb * 0.75 * (0.8 + 0.4 * n2), tex_amount);
			rock_r = mix(rock_r, rt.a, tex_amount);
		}
		alb = mix(alb, rock, rk);
		rough = mix(0.9, rock_r, rk);
		float hs = wpos.y - sea_level;
		float beach = 1.0 - smoothstep(1.5, 4.5 + n * 3.0, hs);
		alb = mix(alb, mix(sand, rock * 0.8, rk * 0.6), beach);
		// wet band and foam right at the water line
		float wet = 1.0 - smoothstep(0.0, 1.2, hs);
		alb *= mix(1.0, 0.55, wet);
		rough = mix(rough, 0.25, wet);
		float foam = (1.0 - smoothstep(0.0, 0.5, abs(hs - 0.25 - 0.25 * sin(TIME * 0.8 + p.x * 0.05 + p.y * 0.03)))) * step(-1.0, hs);
		alb = mix(alb, vec3(0.85, 0.85, 0.82), foam * 0.7);
		// gravel shoulder next to the road
		float shoulder = 1.0 - smoothstep(1.0, 3.5, ed);
		alb = mix(alb, vec3(0.2, 0.18, 0.17) * (0.8 + 0.4 * n2), shoulder);
	}
	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
