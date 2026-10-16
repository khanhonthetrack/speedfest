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
// M7 look plan step 3: recessed windows with interior-mapped rooms and metal frames (Forward+ from
// Medium, web from High). 0 = the flat facade.
uniform float relief = 0.0;

varying flat vec4 cus;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// window opening inside a facade cell (0..1): x0, x1, y0, y1
vec4 win_box(float style, bool shop) {
	if (shop) return vec4(0.08, 0.92, 0.08, 0.75);
	if (style < 0.2) return vec4(0.18, 0.82, 0.28, 0.86);    // punched windows
	if (style < 0.5) return vec4(0.05, 0.95, 0.1, 0.94);     // curtain wall
	if (style < 0.85) return vec4(0.03, 0.97, 0.35, 0.85);   // ribbon windows
	return vec4(0.3, 0.7, 0.35, 0.8);                          // small houses
}

float in_box(vec2 f, vec4 b) {
	return step(b.x, f.x) * step(f.x, b.y) * step(b.z, f.y) * step(f.y, b.w);
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
		bool xface = abs(ln.x) > 0.5;
		float u = xface ? lp.z * sign(ln.x) : -lp.x * sign(ln.z);
		float face = xface ? (ln.x > 0.0 ? 1.0 : 2.0) : (ln.z > 0.0 ? 3.0 : 4.0);
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
		if (style > 0.85) {
			lit = r < lit_frac;
		}
		// shop fronts on the ground floor
		bool shop = v < fh && style < 0.85;
		if (shop) {
			lit = r < 0.7;
			dim = 0.8;
			lc = mix(lc, vec3(1.0, 0.85, 0.7), 0.5);
		}
		vec4 box = win_box(style, shop);
		float win = in_box(f, box);
		// anti-alias: far away, blend to the average facade brightness
		vec2 fw = fwidth(g);
		float aa = clamp(1.0 - (max(fw.x, fw.y) - 0.12) * 4.0, 0.0, 1.0);
		float avg_win = style < 0.2 ? 0.37 : (style < 0.5 ? 0.75 : 0.45);
		float blinds_on = step(0.7, h21(cell + 5.5 + seed));
		vec3 lit_col = lc * dim * window_energy * (1.0 - daylight * 0.6);
		vec3 e_near;
		float frame = 0.0;
		float jamb = 0.0;
		if (relief > 0.5 && aa > 0.02) {
			// view ray in facade space: x along u, y up, z into the wall
			vec3 vw = normalize(wp - CAMERA_POSITION_WORLD);
			vec3 vl = vec3(dot(vw, ax), dot(vw, ay), dot(vw, az));
			vec3 tv = xface ? vec3(0.0, 0.0, sign(ln.x)) : vec3(-sign(ln.z), 0.0, 0.0);
			vec3 nv = xface ? vec3(sign(ln.x), 0.0, 0.0) : vec3(0.0, 0.0, sign(ln.z));
			vec3 rd = vec3(dot(vl, tv), vl.y, max(-dot(vl, nv), 0.08));
			float depth = style < 0.2 ? 0.25 : (style < 0.5 ? 0.06 : (style < 0.85 ? 0.15 : 0.2));
			if (shop) depth = 0.12;
			// the glass sits `depth` behind the facade: where the reveal hides it, we see the jamb
			vec2 fg = f + vec2(rd.x / cw, rd.y / fh) * depth / rd.z;
			float wg = in_box(fg, box);
			jamb = win * (1.0 - wg);
			// thin metal frame around the glass, a mullion on wide windows
			vec2 bw = vec2(0.04 / cw, 0.04 / fh);
			float inner_box = in_box(fg, box + vec4(bw.x, -bw.x, bw.y, -bw.y));
			frame = wg * (1.0 - inner_box);
			if (cw > 3.4 && !shop) frame = max(frame, wg * (1.0 - step(bw.x, abs(fg.x - 0.5))));
			// room behind the glass (interior mapping): box cw x fh x room_d, entered at the glass
			float room_d = 0.9 * cw;
			vec3 p0 = vec3(clamp(fg.x, 0.0, 1.0) * cw, clamp(fg.y, 0.0, 1.0) * fh, 0.0);
			vec3 rs = vec3(abs(rd.x) < 1e-4 ? 1e-4 : rd.x, abs(rd.y) < 1e-4 ? 1e-4 : rd.y, rd.z);
			vec3 tb = (step(0.0, rs) * vec3(cw, fh, room_d) - p0) / rs;
			float t = min(tb.x, min(tb.y, tb.z));
			vec3 ph = p0 + rs * t;
			vec3 room;
			if (t == tb.z) {
				// back wall, with a furniture silhouette and a per-room tint
				float blob = smoothstep(0.25, 0.0, length((vec2(ph.x / cw, ph.y / fh) - vec2(0.3 + 0.4 * h21(cell + 8.0), 0.3)) * vec2(1.0, 1.4)));
				room = lit_col * 0.75 * (0.85 + 0.3 * h21(cell + 4.4)) * (1.0 - blob * 0.55 * step(0.4, h21(cell + 2.2)));
			} else if (t == tb.y) {
				if (rs.y > 0.0) {
					// ceiling with a light panel in the middle
					float panel = smoothstep(0.3, 0.1, length(vec2(ph.x / cw - 0.5, ph.z / room_d - 0.55) * vec2(1.0, 1.6)));
					room = lit_col * (0.9 + 1.4 * panel);
				} else {
					room = lit_col * 0.3;            // floor
				}
			} else {
				room = lit_col * 0.5;                // side walls
			}
			if (!lit) room = lit_col * 0.02;
			room *= mix(1.0, 0.65 + 0.35 * step(0.5, fract(fg.y * 9.0)), blinds_on);
			e_near = room * wg * (1.0 - frame);
		} else {
			// flat facade: ceiling-lit gradient, blinds on some windows, a darker "room" blob
			float inner = 0.75 + 0.35 * f.y;
			inner *= mix(1.0, 0.65 + 0.35 * step(0.5, fract(f.y * 9.0)), blinds_on);
			float blob = smoothstep(0.2, 0.0, length((f - vec2(0.3 + 0.4 * h21(cell + 8.0), 0.45)) * vec2(1.0, 1.6)));
			inner *= 1.0 - blob * 0.45 * step(0.4, h21(cell + 2.2));
			e_near = (lit ? lit_col * inner : vec3(0.0)) * win;
		}
		vec3 e_far = mix(warm_light, cool_light, tint) * window_energy * avg_win * lit_frac * 0.55 * (1.0 - daylight * 0.6);
		emit = mix(e_far, e_near, aa);
		float wmix = mix(avg_win, win, aa);
		albedo = mix(wall, glass_color, wmix);
		rough = mix(rough, 0.08, wmix);
		metal = mix(0.0, 0.5, wmix);
		// window reveals and frames (near only)
		albedo = mix(albedo, wall * 0.45, jamb * aa);
		rough = mix(rough, 0.6, jamb * aa);
		metal = mix(metal, 0.0, jamb * aa);
		albedo = mix(albedo, vec3(0.08), frame * aa);
		metal = mix(metal, 0.6, frame * aa);
		rough = mix(rough, 0.3, frame * aa);
		// subtle floor slab lines
		float slab = smoothstep(0.0, 0.04, f.y) * smoothstep(0.0, 0.04, 1.0 - f.y);
		albedo *= mix(0.75, 1.0, mix(1.0, slab, aa));
		if (relief > 0.5) {
			// rain streaks running down the walls
			albedo *= 1.0 - 0.3 * wetness * vnoise(vec2(u * 2.5, v * 0.12)) * (1.0 - wmix);
		}
		// darker base, roof parapet glow line for tall towers
		albedo *= 0.75 + 0.25 * smoothstep(0.0, 8.0, v);
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
	EMISSION = emit;
}
