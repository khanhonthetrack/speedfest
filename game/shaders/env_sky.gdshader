shader_type sky;
render_mode use_debanding;
// SpeedFest procedural sky shared by all themes (city night, arena night, coast dusk).
// Static (no TIME) so the radiance map is only computed once.

uniform vec3 zenith_color : source_color = vec3(0.02, 0.02, 0.06);
uniform vec3 sky_color : source_color = vec3(0.05, 0.04, 0.12);
uniform vec3 horizon_color : source_color = vec3(0.25, 0.12, 0.25);
uniform vec3 ground_color : source_color = vec3(0.02, 0.02, 0.03);
uniform float horizon_falloff = 5.0;
uniform float zenith_falloff = 1.5;

// Low glow band on the horizon (city light pollution, sunset afterglow).
uniform vec3 glow_color : source_color = vec3(0.9, 0.35, 0.5);
uniform float glow_strength = 0.6;
uniform float glow_height = 0.15;
uniform vec3 glow_dir = vec3(0.0, 0.0, -1.0);   // where the glow is strongest
uniform float glow_dir_amount = 0.0;            // 0 = all around, 1 = only towards glow_dir

// Sun / moon disk.
uniform vec3 sun_dir = vec3(0.0, 0.1, -1.0);    // direction TO the sun
uniform vec3 sun_color : source_color = vec3(1.0, 0.6, 0.3);
uniform float sun_size = 0.03;
uniform float sun_strength = 0.0;
uniform float halo_strength = 0.0;
uniform float halo_size = 4.0;

// Clouds (fbm on a plane).
uniform float cloud_cover = 0.5;
uniform float cloud_sharpness = 3.0;
uniform float cloud_scale = 0.6;
uniform vec2 cloud_offset = vec2(0.0);
uniform vec3 cloud_dark : source_color = vec3(0.04, 0.03, 0.08);
uniform vec3 cloud_lit : source_color = vec3(0.5, 0.2, 0.35);
uniform float cloud_lit_from_below = 1.0;   // city: lit by the street glow
uniform float cloud_sun_lit = 0.0;          // coast: rims lit by the sun
uniform float cloud_streak = 1.0;           // >1 stretches clouds horizontally (cirrus)

uniform float star_amount = 0.0;
uniform float energy = 1.0;

// Photographed sky (session 7: Poly Haven CC0 panoramas, res://assets/sky/, SceneryEnv). The
// procedural sky above stays underneath; pano_amount blends the photo over it. Direction mapping
// (same as tools/textures/fetch_hdri.py): u = fract(atan(d.x, -d.z) / TAU + pano_rotation),
// v = acos(d.y) / PI. The glow band, stars and the sun disk are drawn on top of the photo.
uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
uniform float pano_amount = 0.0;
uniform float pano_exposure = 1.0;          // linear multiplier (already divided by the encode scale)
uniform vec3 pano_tint : source_color = vec3(1.0);
uniform float pano_saturation = 1.0;
uniform float pano_rotation = 0.0;          // turns (0..1)
uniform float pano_glow_keep = 1.0;         // how much of the procedural horizon glow stays on the photo
uniform float pano_star_keep = 0.0;         // procedural stars over the photo (sharper than its pixels)
uniform float pano_ground_keep = 0.0;       // photo below the horizon (0 = the procedural ground)
uniform vec3 pano_top_tint : source_color = vec3(1.0);   // grade toward the zenith (deeper dusk tops)

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += vnoise(p) * a;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p;
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float y = d.y;
	vec3 col;
	if (y >= 0.0) {
		float h = 1.0 - pow(1.0 - y, horizon_falloff);
		col = mix(horizon_color, sky_color, clamp(h, 0.0, 1.0));
		col = mix(col, zenith_color, clamp(pow(y, zenith_falloff), 0.0, 1.0));
	} else {
		col = mix(horizon_color, ground_color, clamp(pow(-y * 4.0, 0.5), 0.0, 1.0));
	}
	// horizon glow
	vec3 gd = normalize(vec3(glow_dir.x, 0.0, glow_dir.z) + vec3(0.0001));
	float toward = dot(normalize(vec3(d.x, 0.0, d.z) + vec3(0.0001)), gd) * 0.5 + 0.5;
	float gmask = mix(1.0, toward * toward, glow_dir_amount);
	float gband = exp(-abs(y) / max(glow_height, 0.001));
	col += glow_color * glow_strength * gband * gmask;

	vec3 sd = normalize(sun_dir);
	float sdot = dot(d, sd);
	// stars
	if (star_amount > 0.0 && y > 0.0) {
		vec3 sp = d * 320.0;
		vec3 ci = floor(sp);
		float s = hash12(ci.xy + ci.z * 7.31);
		float tw = hash12(ci.zx + 3.7);
		float dotm = smoothstep(0.4, 0.05, length(fract(sp) - 0.5));
		float star = step(1.0 - 0.025 * star_amount, s) * dotm * smoothstep(0.0, 0.3, y) * (0.3 + tw);
		col += vec3(0.8, 0.85, 1.0) * star * 1.2;
	}
	// clouds
	if (cloud_cover > 0.0 && y > -0.02) {
		vec2 uv = d.xz / (max(y, 0.0) + 0.08) * cloud_scale;
		uv.y *= 1.0;
		uv.x /= cloud_streak;
		float n = fbm(uv + cloud_offset);
		float n2 = fbm(uv * 2.3 + cloud_offset * 1.7 + 4.0);
		float c = clamp((n * 0.75 + n2 * 0.35 - (1.0 - cloud_cover)) * cloud_sharpness, 0.0, 1.0);
		c *= smoothstep(-0.02, 0.06, y);
		float below = exp(-max(y, 0.0) * 4.0);
		vec3 cc = mix(cloud_dark, cloud_lit, clamp(below * cloud_lit_from_below + (1.0 - n2) * 0.25, 0.0, 1.0));
		float sl = pow(clamp(sdot * 0.5 + 0.5, 0.0, 1.0), 6.0) * cloud_sun_lit;
		cc += sun_color * sl * (1.2 - c * 0.6);
		col = mix(col, cc, c * 0.92);
	}
	// photographed sky over the procedural one (glow band and stars added back on top)
	if (pano_amount > 0.0) {
		float u = fract(atan(d.x, -d.z) / 6.2831853 + pano_rotation);
		float v = acos(clamp(y, -1.0, 1.0)) / 3.1415927;
		vec3 p = textureLod(panorama, vec2(u, v), 0.0).rgb;
		float pl = dot(p, vec3(0.2126, 0.7152, 0.0722));
		p = mix(vec3(pl), p, pano_saturation) * pano_tint * pano_exposure;
		p *= mix(vec3(1.0), pano_top_tint, clamp(pow(max(y, 0.0), 0.7), 0.0, 1.0));
		p += glow_color * glow_strength * gband * gmask * pano_glow_keep;
		if (pano_star_keep > 0.0 && y > 0.0) {
			vec3 sp = d * 320.0;
			vec3 ci = floor(sp);
			float s = hash12(ci.xy + ci.z * 7.31);
			float tw = hash12(ci.zx + 3.7);
			float dotm = smoothstep(0.4, 0.05, length(fract(sp) - 0.5));
			float star = step(1.0 - 0.025 * star_amount, s) * dotm * smoothstep(0.0, 0.3, y) * (0.3 + tw);
			p += vec3(0.8, 0.85, 1.0) * star * 1.2 * pano_star_keep;
		}
		col = mix(col, p, pano_amount * mix(pano_ground_keep, 1.0, smoothstep(-0.08, 0.0, y)));
	}
	// sun disk + halo (in front of thin cloud)
	if (sun_strength > 0.0) {
		float disk = smoothstep(cos(sun_size), cos(sun_size * 0.85), sdot);
		col += sun_color * disk * sun_strength;
	}
	if (halo_strength > 0.0) {
		float halo = pow(clamp(sdot, 0.0, 1.0), halo_size * 30.0) * 0.6 + pow(clamp(sdot, 0.0, 1.0), halo_size) * 0.25;
		col += sun_color * halo * halo_strength;
	}
	COLOR = col * energy;
}
