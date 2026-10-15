shader_type spatial;
render_mode cull_back;
// Procedural facades for MultiMesh unit boxes (base at y = 0, 1 m cube scaled per instance).
// INSTANCE_CUSTOM: r = seed, g = style (0 windows, 0.33 curtain glass, 0.66 bands, 1 small houses),
// b = lit fraction, a = tint (0 warm .. 1 cool).

uniform vec3 wall_color : source_color = vec3(0.07, 0.07, 0.09);
uniform vec3 wall_color2 : source_color = vec3(0.12, 0.11, 0.12);
uniform vec3 glass_color : source_color = vec3(0.02, 0.025, 0.04);
uniform vec3 warm_light : source_color = vec3(1.0, 0.72, 0.42);
uniform vec3 cool_light : source_color = vec3(0.72, 0.85, 1.0);
uniform vec3 accent_light : source_color = vec3(0.2, 0.9, 1.0);
uniform vec3 accent_light2 : source_color = vec3(1.0, 0.25, 0.8);
uniform float window_energy = 2.2;
uniform float wetness = 0.6;
uniform float daylight = 0.0;   // coast dusk: windows less dominant

varying flat vec4 cus;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	cus = INSTANCE_CUSTOM;
}

void fragment() {
	// local (scaled, metres) position and local normal, computed per pixel: keeping vertex()
	// trivial avoids depth-prepass/colour-pass mismatches (speckled z-fighting) on some drivers.
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 ax = normalize(MODEL_MATRIX[0].xyz);
	vec3 ay = normalize(MODEL_MATRIX[1].xyz);
	vec3 az = normalize(MODEL_MATRIX[2].xyz);
	vec3 rel = wp - MODEL_MATRIX[3].xyz;
	vec3 lp = vec3(dot(rel, ax), dot(rel, ay), dot(rel, az));
	vec3 ln = vec3(dot(wn, ax), dot(wn, ay), dot(wn, az));
	float seed = cus.r * 97.0;
	float style = cus.g;
	float lit_frac = cus.b;
	vec3 wall = mix(wall_color, wall_color2, h21(vec2(seed, 3.1)));
	vec3 albedo = wall;
	float rough = 0.85 - wetness * 0.35;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	if (abs(ln.y) > 0.5) {
		// roof: dark gravel with a faint edge
		albedo = wall * 0.6;
		rough = 0.9;
	} else {
		float u = abs(ln.x) > 0.5 ? lp.z * sign(ln.x) : -lp.x * sign(ln.z);
		float face = abs(ln.x) > 0.5 ? (ln.x > 0.0 ? 1.0 : 2.0) : (ln.z > 0.0 ? 3.0 : 4.0);
		float v = lp.y;
		float fh = style > 0.85 ? 3.0 : mix(3.3, 4.2, h21(vec2(seed, 1.7)));
		float cw = style > 0.85 ? 2.6 : mix(2.4, 4.6, h21(vec2(seed, 2.9)));
		vec2 g = vec2(u / cw, v / fh);
		vec2 cell = floor(g);
		vec2 f = fract(g);
		float r = h21(cell + vec2(seed * 3.0 + face * 17.0, seed));
		float rf = h21(vec2(cell.y + seed * 5.0, face));   // per-floor variation
		bool lit = r < lit_frac * (0.6 + rf * 0.8);
		float tint = cus.a;
		float pick = h21(cell * 1.3 + seed);
		vec3 lc = mix(warm_light, cool_light, step(pick, tint));
		if (pick > 0.985) lc = accent_light;
		else if (pick > 0.975) lc = accent_light2;
		float dim = 0.35 + 0.65 * h21(cell + 11.0 + seed);
		float win;
		if (style < 0.2) {
			// punched windows
			win = step(0.18, f.x) * step(f.x, 0.82) * step(0.28, f.y) * step(f.y, 0.86);
		} else if (style < 0.5) {
			// curtain wall: glass everywhere, thin mullions
			win = step(0.05, f.x) * step(f.x, 0.95) * step(0.1, f.y) * step(f.y, 0.94);
		} else if (style < 0.85) {
			// horizontal ribbon windows
			win = step(0.35, f.y) * step(f.y, 0.85) * step(0.03, f.x) * step(f.x, 0.97);
		} else {
			// small houses: sparse windows
			win = step(0.3, f.x) * step(f.x, 0.7) * step(0.35, f.y) * step(f.y, 0.8);
			lit = r < lit_frac;
		}
		// shop fronts on the ground floor
		if (v < fh && style < 0.85) {
			win = step(0.08, f.x) * step(f.x, 0.92) * step(0.08, f.y) * step(f.y, 0.75);
			lit = r < 0.7;
			dim = 0.8;
			lc = mix(lc, vec3(1.0, 0.85, 0.7), 0.5);
		}
		// anti-alias: far away, blend to the average facade brightness
		vec2 fw = fwidth(g);
		float aa = clamp(1.0 - (max(fw.x, fw.y) - 0.12) * 4.0, 0.0, 1.0);
		float avg_win = style < 0.2 ? 0.37 : (style < 0.5 ? 0.75 : 0.45);
		// interior detail: ceiling-lit gradient, blinds on some windows, a darker "room" blob
		float inner = 0.75 + 0.35 * f.y;
		float blinds_on = step(0.7, h21(cell + 5.5 + seed));
		inner *= mix(1.0, 0.65 + 0.35 * step(0.5, fract(f.y * 9.0)), blinds_on);
		float blob = smoothstep(0.2, 0.0, length((f - vec2(0.3 + 0.4 * h21(cell + 8.0), 0.45)) * vec2(1.0, 1.6)));
		inner *= 1.0 - blob * 0.45 * step(0.4, h21(cell + 2.2));
		vec3 lit_col = lc * dim * inner * window_energy * (1.0 - daylight * 0.6);
		vec3 e_near = (lit ? lit_col : vec3(0.0)) * win;
		vec3 e_far = mix(warm_light, cool_light, tint) * window_energy * avg_win * lit_frac * 0.55 * (1.0 - daylight * 0.6);
		emit = mix(e_far, e_near, aa);
		float wmix = mix(avg_win, win, aa);
		albedo = mix(wall, glass_color, wmix);
		rough = mix(rough, 0.08, wmix);
		metal = mix(0.0, 0.5, wmix);
		// subtle floor slab lines
		float slab = smoothstep(0.0, 0.04, f.y) * smoothstep(0.0, 0.04, 1.0 - f.y);
		albedo *= mix(0.75, 1.0, mix(1.0, slab, aa));
		// darker base, roof parapet glow line for tall towers
		albedo *= 0.75 + 0.25 * smoothstep(0.0, 8.0, v);
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
	EMISSION = emit;
}
