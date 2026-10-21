shader_type spatial;
#include "res://env/rt.gdshaderinc"
#include "res://env/tm_occlusion.gdshaderinc"
// Our car's surfaces, in the parts' own space (they move with the car and the wheels):
// mode 0 paint (metallic flakes under a clearcoat, a white stripe along the top), 1 carbon fibre
// (a 2x2 twill weave that catches the light by direction), 2 tyre (tread grooves and sipes, a
// lettering band on the sidewall), 3 the hypercar's paint and livery (its parts in visual
// coordinates: x to the left, y up from the ground, z forward), 4 a road car's paint and livery
// (visual coordinates; the body's lines along the car in the an_* arrays, from its manifest:
// TmRoadCars), 5 a grille's mesh, 6 a number plate. Fine detail fades out with distance.

uniform int mode = 0;
uniform vec3 colour : source_color = vec3(0.85, 0.08, 0.06);
uniform vec3 stripe_colour : source_color = vec3(0.95);
uniform float stripe_half = 0.07;    // the stripe's half width (m); 0 = none
uniform float flakes = 1.0;          // metallic flakes in the paint (0: plain, the white parts)
uniform float tyre_radius = 0.364;
uniform float tyre_half_width = 0.182;
uniform float ground_y = -0.441;     // the road under the body, in the parts' space (TmCarVisual.VIS)
// mode 4: the livery (TmRoadCars.PATTERNS), its colours and parameters, the paint's finish
// (metallic, roughness, clearcoat, pearl), and the body's lines at 24 stations nose to tail
uniform int livery = 0;
uniform vec3 liv_a : source_color = vec3(0.9, 0.2, 0.05);
uniform vec3 liv_b : source_color = vec3(0.05);
uniform vec3 liv_c : source_color = vec3(1.0, 0.8, 0.1);
uniform vec4 liv_p = vec4(0.0);
uniform vec4 finish = vec4(0.12, 0.30, 1.0, 0.0);
uniform int liv_hood = 0;            // 0 paint, 1 carbon, 2 gloss black
uniform int liv_roof = 0;            // 0 paint, 1 gloss black
uniform vec2 cabin = vec2(1.5, 3.5); // the greenhouse's d range (from the nose)
uniform float z_nose = 2.5;
uniform float z_tail = -2.0;
uniform float an_top[24];
uniform float an_belt[24];
uniform float an_mid[24];
uniform float an_sill[24];
uniform float an_hw[24];

varying vec3 opos;
varying vec3 onrm;
varying vec3 cwpos;
varying vec3 cwnrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
	cwpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	cwnrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// 1 between lo and hi (antialiased over fw)
float band(float v, float lo, float hi, float fw) {
	return smoothstep(lo - fw, lo + fw, v) * (1.0 - smoothstep(hi - fw, hi + fw, v));
}

// The hypercar's livery: the paint; gloss black below a sill line that rises towards the tail
// (the chin, the sills, the tail under its light bar) and on the canopy round its glass; a white
// pinstripe over the sill; two white stripes along the top, nose to tail.
vec3 hyper_livery(vec3 paint, vec3 p, vec3 n) {
	vec3 black = vec3(0.012, 0.012, 0.014);
	vec3 white = vec3(0.93, 0.93, 0.94);
	vec3 fw = fwidth(p) + 1e-4;
	float sill = 0.21 + 0.05 * smoothstep(2.6, 1.6, p.z) + 0.06 * smoothstep(0.8, -1.0, p.z) + 0.12 * smoothstep(-1.4, -2.2, p.z);
	float low = 1.0 - smoothstep(sill - fw.y, sill + fw.y, p.y);
	float pin = band(p.y, sill + 0.010, sill + 0.024, fw.y);
	float ax = abs(p.x);
	// the canopy: over its glass's lower edge, inside its shoulders, from the windscreen's foot to a
	// line sweeping back down its flanks (the fin stays painted)
	float zrear = -0.36 - (1.06 - p.y) * 1.6;
	float canopy = smoothstep(0.70 - fw.y, 0.70 + fw.y, p.y) * (1.0 - smoothstep(0.50 - fw.x, 0.50 + fw.x, ax))
		* (1.0 - smoothstep(0.97 - fw.z, 0.97 + fw.z, p.z)) * smoothstep(zrear - fw.z, zrear + fw.z, p.z)
		* smoothstep(0.010, 0.016, ax);
	float stripes = (band(ax, 0.035, 0.105, fw.x)) * smoothstep(0.2, 0.4, n.y);
	vec3 col = mix(paint, black, max(low, canopy));
	col = mix(col, white, max(pin, stripes));
	return col;
}


float hash1(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0)), f.x), f.y);
}

// a filled region from a signed distance (negative inside), antialiased
float fill(float sd) {
	float w = fwidth(sd) + 1e-4;
	return 1.0 - smoothstep(-w, w, sd);
}

// a line along a signed distance's zero, half width hw
float edge_line(float sd, float hw) {
	return fill(abs(sd) - hw);
}

// The body's frame at a point: d back from the nose, the stations' lines there (belt, sill, top,
// widest point's height, half width).
struct Frame {
	float d;
	float s;
	float belt;
	float sill;
	float top;
	float mid;
	float hw;
};

Frame frame_at(vec3 p) {
	Frame f;
	float L = max(z_nose - z_tail, 1.0);
	f.d = z_nose - p.z;
	f.s = clamp(f.d / L, 0.0, 1.0);
	float k = clamp(f.s * 24.0 - 0.5, 0.0, 23.0);
	int i0 = int(floor(k));
	int i1 = min(i0 + 1, 23);
	float t = k - float(i0);
	f.belt = mix(an_belt[i0], an_belt[i1], t);
	f.sill = mix(an_sill[i0], an_sill[i1], t);
	f.top = mix(an_top[i0], an_top[i1], t);
	f.mid = mix(an_mid[i0], an_mid[i1], t);
	f.hw = max(mix(an_hw[i0], an_hw[i1], t), 0.2);
	return f;
}

// flames licking back from the nose: u along the car (m from the nose), w across the tongues
// (height on the flanks, |x| on the top), env 0..1 (tongues longest where it is 1)
vec4 flames(float u, float w, float env, float reach, float amp, float period, float sharp) {
	float ph = (w + 0.05 * sin(u * 4.0)) / period;
	float k = floor(ph);
	float tri = 1.0 - abs(fract(ph) * 2.0 - 1.0);
	float tongue = pow(tri, sharp) * (0.55 + 0.45 * hash1(k + 3.0));
	float R = reach * (0.45 + 0.55 * env) + amp * tongue * (0.3 + 0.7 * env);
	float ue = u + 0.05 * sin(w * 22.0 + u * 2.0);
	float sd = ue - R;
	float inside = fill(sd);
	float outline = edge_line(sd + 0.004, 0.008);
	// yellow at the nose to the tips' red
	vec3 col = mix(liv_c, liv_a, smoothstep(0.1, max(R, 0.2), ue));
	return vec4(mix(col, liv_b, outline), max(inside, outline));
}

// a tapered blade around a curve: u range, centre line v0 + a sin, thickness, in metres
float blade(float u, float v, float u0, float u1, float v0, float a, float f, float ph, float th) {
	float t = (u - u0) / (u1 - u0);
	if (t <= 0.0 || t >= 1.0) {
		return 1.0;
	}
	float vc = v0 + a * sin(t * 3.14159 * f + ph);
	float h = th * pow(sin(3.14159 * t), 0.8) * (1.0 - 0.55 * t);
	return abs(v - vc) - h;
}

vec4 road_livery(vec3 p, vec3 n, out float carbon, out float black) {
	Frame f = frame_at(p);
	carbon = 0.0;
	black = 0.0;
	float ax = abs(p.x);
	float side = smoothstep(0.3, 0.65, abs(n.x));
	float topw = 1.0 - side;
	float H = max(f.belt - f.sill, 0.15);
	float v = (p.y - f.sill) / H;           // 0 on the sill, 1 on the belt
	float L = z_nose - z_tail;
	vec4 o = vec4(0.0);
	if (livery == 1) {
		// stripes: twin stripes nose to tail over the top, a stripe along each sill
		float w = liv_p.x;
		float g = liv_p.y;
		float ol = liv_p.z;
		float sd = abs(ax - g - w * 0.5) - w * 0.5;
		float st = fill(sd) * topw;
		float line = edge_line(abs(sd) - ol * 0.5 - 0.002, ol * 0.5) * topw;
		float rock = 0.0;
		float rline = 0.0;
		if (liv_p.w > 0.5) {
			float vs = (abs(v - 0.16) - 0.075) * H;
			float ends = smoothstep(0.05, 0.12, f.s) * (1.0 - smoothstep(0.9, 0.96, f.s));
			rock = fill(vs) * side * ends;
			rline = edge_line(abs(vs) - 0.008, 0.004) * side * ends;
		}
		o = vec4(liv_a, max(st, rock));
		o = mix(o, vec4(liv_b, 1.0), max(line, rline));
	} else if (livery == 2) {
		// flames from the nose: along the flanks and over the hood
		float yy = clamp((p.y - (f.sill + f.belt) * 0.5) / H, -0.7, 0.7);
		vec4 sf = flames(f.d, p.y, clamp(1.0 - yy * yy * 3.0, 0.0, 1.0), liv_p.x, liv_p.y, liv_p.z, liv_p.w);
		vec4 tf = flames(f.d, ax, clamp(1.0 - pow(ax / f.hw, 2.0), 0.0, 1.0), liv_p.x * 0.75, liv_p.y * 0.8, liv_p.z * 1.1, liv_p.w);
		o = mix(tf, sf, side);
	} else if (livery == 3) {
		// tribal: sharp curved blades sweeping back from the front wheel and over the hood
		float sc = max(liv_p.x, 0.5);
		float u = f.d / sc;
		float vm = (p.y - f.sill);
		float sd = blade(u, vm, 0.35, 2.6, H * 0.55, H * 0.25, 1.3, 0.3, H * 0.22);
		sd = min(sd, blade(u, vm, 1.1, 3.4, H * 0.3, -H * 0.22, 1.1, 0.9, H * 0.15));
		sd = min(sd, blade(u, vm, 2.0, 4.1, H * 0.72, H * 0.18, 1.6, 2.2, H * 0.11));
		sd = min(sd, blade(u, vm, 2.9, 4.4, H * 0.12, H * 0.12, 1.0, 0.0, H * 0.08));
		float td = blade(u, ax, 0.1, 1.5, f.hw * 0.55, -f.hw * 0.3, 1.0, 0.4, f.hw * 0.12);
		td = min(td, blade(u, ax, 0.5, 2.2, f.hw * 0.25, f.hw * 0.15, 1.4, 1.0, f.hw * 0.07));
		float d = mix(td, sd, side);
		o = vec4(liv_a, fill(d));
		o = mix(o, vec4(liv_b, 1.0), edge_line(d + 0.006, 0.006));
	} else if (livery == 4) {
		// tiger stripes down from the belt and up from the sill, in from the hood's edges
		float fr = liv_p.x;
		float q = f.d * fr + 0.30 * sin(p.y * 9.0 + f.d * 1.7) + 0.12 * sin(p.y * 23.0 + f.d * 5.0);
		float k = floor(q);
		float fq = fract(q);
		float db = f.belt + 0.06 - p.y;
		float len1 = (0.25 + 0.5 * hash1(k)) * H;
		float w1 = 0.42 * clamp(1.0 - db / len1, 0.0, 1.0);
		float s1 = fill(abs(fq - 0.5) - w1 * 0.5) * step(-0.08, db);
		float q2 = q + 0.5;
		float k2 = floor(q2);
		float fq2 = fract(q2);
		float du = p.y - f.sill + 0.03;
		float len2 = (0.15 + 0.3 * hash1(k2 + 11.0)) * H;
		float w2 = 0.36 * clamp(1.0 - du / len2, 0.0, 1.0);
		float s2 = fill(abs(fq2 - 0.5) - w2 * 0.5);
		float sides = max(s1, s2);
		float de = f.hw - ax;
		float qt = f.d * fr + 0.3 * sin(ax * 9.0 + f.d * 2.1);
		float kt = floor(qt);
		float lent = (0.15 + 0.35 * hash1(kt + 5.0)) * f.hw;
		float wt = 0.4 * clamp(1.0 - de / lent, 0.0, 1.0);
		float tops = fill(abs(fract(qt) - 0.5) - wt * 0.5);
		o = vec4(liv_a, mix(tops, sides, side));
	} else if (livery == 5) {
		// shards: a field of triangles, denser towards the tail, gaps between them
		float c = liv_p.x;
		vec2 q = vec2(f.d, mix(ax * 1.3, p.y, side)) / c;
		q.x += q.y * 0.5;
		vec2 cell = floor(q);
		vec2 fq = fract(q);
		float upper = step(fq.y, fq.x);
		float id = cell.x * 7.0 + cell.y * 131.0 + upper * 0.5;
		// distance to the triangle's edges (in cell units)
		float e = upper > 0.5 ? min(min(fq.x - fq.y, 1.0 - fq.x), fq.y) : min(min(fq.y - fq.x, 1.0 - fq.y), fq.x);
		float g = f.s + liv_p.y * (v - 0.5) + 0.25 * (hash1(id) - 0.5);
		float dens = smoothstep(liv_p.z - 0.6, liv_p.z, g);
		float on = step(hash1(id + 17.0), dens) * fill(liv_p.w / c - e);
		vec3 col = hash1(id + 5.0) > 0.5 ? liv_a : mix(liv_a, liv_b, 0.65);
		o = vec4(col, on);
	} else if (livery == 6) {
		// halftone: solid at the tail, dots shrinking towards the nose
		float sp = liv_p.x;
		vec2 q = vec2(f.d, mix(ax, p.y, side)) / sp;
		float row = floor(q.y);
		q.x += mod(row, 2.0) * 0.5;
		vec2 cq = fract(q) - 0.5;
		float g = smoothstep(liv_p.y, liv_p.z, f.s + 0.15 * (v - 0.5));
		float r = 0.62 * g;
		float dot = fill(length(cq) - r);
		float solid = smoothstep(0.92, 0.98, g);
		o = vec4(mix(liv_a, liv_b, smoothstep(0.85, 1.0, f.s) * 0.0), max(dot, solid));
	} else if (livery == 7) {
		// sweep: a broad band rising from the front's foot over the rear wheel to the deck, a
		// thin one above it
		float rise = smoothstep(0.05, 0.9, f.s);
		float yc = f.sill + H * (0.12 + 0.95 * rise * rise);
		float th = H * (0.10 + 0.22 * smoothstep(0.0, 0.5, f.s));
		float b1 = (abs(p.y - yc) - th) ;
		float b2 = abs(p.y - (yc + th + H * 0.12)) - H * 0.035 * smoothstep(0.15, 0.6, f.s);
		float tb = abs(ax - f.hw * 0.55 * (1.0 - f.s)) - 0.06 - 0.25 * f.s;
		float s1 = fill(b1) * side;
		float s2 = fill(b2) * side;
		float t1 = fill(tb) * topw * smoothstep(0.55, 0.75, f.s);
		o = vec4(liv_a, max(s1, t1));
		o = mix(o, vec4(liv_b, 1.0), s2);
	} else if (livery == 8) {
		// checker: chequers over the rear half, their squares shrinking towards the front
		float c = liv_p.x;
		vec2 q = vec2(f.d, mix(ax, p.y, side)) / c;
		vec2 cell = floor(q);
		vec2 cq = fract(q) - 0.5;
		float g = smoothstep(liv_p.y, liv_p.z, f.s);
		float sq = max(abs(cq.x), abs(cq.y)) - 0.5 * g;
		float par = mod(cell.x + cell.y, 2.0);
		o = vec4(par > 0.5 ? liv_a : liv_b, fill(sq) * step(0.02, g));
	} else if (livery == 9) {
		// digital camouflage in three colours on a pixel grid
		float c = liv_p.x;
		vec2 q = vec2(f.d, mix(p.x, p.y, side) + 3.0 * step(0.0, p.x) * side);
		vec2 px = floor(q / c) * c;
		float n1 = vnoise(px * 2.2);
		float n2 = vnoise(px * 4.1 + 7.3);
		float n3 = vnoise(px * 7.7 + 1.9);
		vec3 col = liv_a;
		float on = 0.0;
		if (n1 > 0.58) { col = liv_a; on = 1.0; }
		else if (n2 > 0.62) { col = liv_b; on = 1.0; }
		else if (n3 > 0.7) { col = liv_c; on = 1.0; }
		o = vec4(col, on);
	} else if (livery == 10) {
		// two-tone: the top above the belt in colour a, a pinstripe along the belt, a spear on
		// the flank
		float up = fill(f.belt - 0.012 - p.y) * step(0.45, n.y + side);
		float pin = edge_line(p.y - (f.belt - 0.035), 0.005) * side;
		float t = (f.s - 0.12) / 0.75;
		float spear = (t > 0.0 && t < 1.0) ? fill(abs(v - 0.55) * H - 0.035 * (1.0 - t) * smoothstep(0.0, 0.08, t)) * side : 0.0;
		o = vec4(liv_a, up);
		o = mix(o, vec4(liv_b, 1.0), max(pin, spear));
	} else if (livery == 11) {
		// a lightning bolt along each flank, zigzagging back, outlined
		float per = liv_p.x;
		float t = f.d / per;
		float zz = abs(fract(t) - 0.5) * 2.0;
		float yc = f.sill + H * (0.42 + 0.3 * (zz - 0.5));
		float fade = smoothstep(0.08, 0.15, f.s) * (1.0 - smoothstep(0.85, 0.95, f.s));
		float th = H * 0.09 * (1.3 - f.s);
		float sd = abs(p.y - yc) - th;
		o = vec4(liv_a, fill(sd) * side * fade);
		o = mix(o, vec4(liv_b, 1.0), edge_line(abs(sd) - 0.006, 0.004) * side * fade);
	} else if (livery == 12) {
		// a fade from colour a at the nose to the paint at the tail, a ragged edge
		float e = f.s + 0.06 * (vnoise(vec2(f.d * 6.0, p.y * 6.0 + p.x * 3.0)) - 0.5);
		float g = 1.0 - smoothstep(liv_p.x, liv_p.y, e);
		o = vec4(mix(liv_a, liv_b, smoothstep(0.0, liv_p.x, e) * 0.4), g);
	} else if (livery == 13) {
		// claws: three slashes across each door, a shadow behind them
		float dc = L * liv_p.x;
		float t = (f.d - dc) * 0.94 + (p.y - f.sill - H * 0.5) * 0.45;
		float sl = 1.0;
		float sh = 1.0;
		for (int i = 0; i < 3; i++) {
			float off = (float(i) - 1.0) * 0.16;
			float along = (p.y - f.sill) / H;
			float taper = 0.035 * clamp(sin(3.14159 * clamp((along - 0.08 - float(i) * 0.04) / 0.85, 0.0, 1.0)), 0.0, 1.0);
			float jag = 0.006 * sin(p.y * 90.0 + float(i) * 3.0);
			sl = min(sl, abs(t - off + jag) - taper);
			sh = min(sh, abs(t - off - 0.02 + jag) - taper);
		}
		float a1 = fill(sl) * side;
		float a2 = fill(sh) * side;
		o = vec4(liv_b, a2 * 0.8);
		o = mix(o, vec4(liv_a, 1.0), a1);
	}
	// the hood and roof
	if (liv_hood > 0 && f.d < cabin.x - 0.03 && n.y > 0.45 && ax < f.hw * 0.78 && p.y > f.belt - 0.08) {
		if (liv_hood == 1) {
			carbon = 1.0;
		} else {
			black = 1.0;
		}
	}
	if (liv_roof > 0 && f.d > cabin.x && f.d < cabin.y && p.y > f.belt + 0.05 && n.y > 0.2) {
		black = 1.0;
	}
	return o;
}

void fragment() {
	// darker under bridges, roofs and gates (the map's sky occlusion); the body (paint, carbon) also
	// darker low down and on surfaces facing the road, which blocks their sky
	AO = tm_sky_visibility(cwpos, normalize(cwnrm));
	if (mode != 2) {
		float h = opos.y - ground_y;
		float facing = clamp(normalize(onrm).y * 0.5 + 0.5, 0.0, 1.0);
		AO *= mix(0.45, 1.0, smoothstep(0.1, 0.55, h)) * mix(0.55, 1.0, facing);
	}
	AO_LIGHT_AFFECT = 0.0;
	float dist = length(VERTEX);
	if (mode == 4) {
		vec3 n = normalize(onrm);
		float carbon;
		float blk;
		vec4 lv = road_livery(opos, n, carbon, blk);
		vec3 col = mix(colour, lv.rgb, clamp(lv.a, 0.0, 1.0));
		float flake = hash3(floor(opos * 900.0));
		float fpx = length(fwidth(opos)) * 900.0;
		float fade = (1.0 - smoothstep(0.35, 1.0, fpx)) * flakes;
		// pearl: the colour shifts towards accent c at grazing angles
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		col = mix(col, liv_c * 0.9 + col * 0.3, finish.w * fres * (1.0 - lv.a * 0.6));
		float metal = finish.x;
		float rough = finish.y;
		if (blk > 0.5) {
			col = vec3(0.012, 0.012, 0.014);
			metal = 0.1;
			rough = 0.18;
		}
		ALBEDO = col;
		METALLIC = clamp(metal + (flake - 0.5) * 0.2 * fade * step(0.05, metal), 0.0, 1.0);
		ROUGHNESS = clamp(rough + (flake - 0.5) * 0.12 * fade, 0.02, 1.0);
		if (carbon > 0.5) {
			vec3 a = abs(onrm);
			vec2 uv = opos.xz * 110.0;
			vec2 cell = floor(uv);
			vec2 fc = fract(uv);
			bool along = mod(cell.x + floor(cell.y * 0.5) * 2.0 + cell.y, 4.0) < 2.0;
			float tow = along ? fc.y : fc.x;
			float ridge = 1.0 - pow(abs(tow - 0.5) * 2.0, 2.0);
			float cf = 1.0 - smoothstep(0.0, 0.35, fwidth(uv.x));
			float sheen = mix(0.5, (along ? 0.58 : 0.42) * (0.7 + 0.3 * ridge), cf);
			ALBEDO = vec3(0.025, 0.026, 0.03) + vec3(0.04) * sheen;
			METALLIC = 0.35;
			ROUGHNESS = mix(0.4, 0.25 + 0.2 * (1.0 - ridge), cf);
		}
#if !defined(RT)
		CLEARCOAT = finish.z;
		CLEARCOAT_ROUGHNESS = 0.04;
#endif
	} else if (mode == 5) {
		// a grille: a honeycomb of dark plastic, its cells' holes black (in the plane the face
		// looks along)
		vec3 a = abs(onrm);
		vec2 uv = a.z > a.x && a.z > a.y ? opos.xy : (a.x > a.y ? opos.zy : opos.xz);
		uv *= 55.0;
		vec2 r = vec2(1.0, 1.732);
		vec2 h = r * 0.5;
		vec2 g1 = mod(uv, r) - h;
		vec2 g2 = mod(uv - h, r) - h;
		vec2 g = dot(g1, g1) < dot(g2, g2) ? g1 : g2;
		float hex = max(abs(g.x), dot(abs(g), normalize(vec2(1.0, 1.732))));
		float web = smoothstep(0.36, 0.42, hex);
		float far = smoothstep(0.0, 0.3, fwidth(uv.x));
		web = mix(web, 0.35, far);
		ALBEDO = mix(vec3(0.003), vec3(0.05, 0.05, 0.055), web);
		METALLIC = 0.3 * web;
		ROUGHNESS = mix(0.9, 0.35, web);
	} else if (mode == 6) {
		// a number plate: white, a thin dark border, a row of characters (blocks) across it
		vec3 a = abs(onrm);
		vec2 uv = opos.xy;
		ALBEDO = vec3(0.9, 0.9, 0.88);
		ROUGHNESS = 0.4;
	} else if (mode == 0 || mode == 3) {
		vec3 col = colour;
		if (mode == 3) {
			col = hyper_livery(colour, opos, normalize(onrm));
		} else if (stripe_half > 0.0 && onrm.y > 0.35) {
			float fw = fwidth(opos.x) + 1e-4;
			float s = 1.0 - smoothstep(stripe_half - fw, stripe_half + fw, abs(opos.x));
			float edge = 1.0 - smoothstep(0.012 - fw, 0.012 + fw, abs(abs(opos.x) - stripe_half - 0.02));
			col = mix(col, stripe_colour, s);
			col = mix(col, vec3(0.05), edge * (1.0 - s));
		}
		float flake = hash3(floor(opos * 900.0));
		// flakes only where one covers a pixel or more (smaller ones sparkled like frost)
		float fpx = length(fwidth(opos)) * 900.0;
		float fade = (1.0 - smoothstep(0.35, 1.0, fpx)) * flakes;
		ALBEDO = col;
		// painted, not chrome: a high metallic under a full clearcoat mirrored the horizon all
		// round the body (a "jelly" look)
		METALLIC = 0.12 + (flake - 0.5) * 0.2 * fade;
		ROUGHNESS = 0.36 + (flake - 0.5) * 0.15 * fade;
#if !defined(RT)
		CLEARCOAT = 0.85;             // (the RTX fork's hit shaders have no clearcoat)
		CLEARCOAT_ROUGHNESS = 0.06;
#endif
	} else if (mode == 1) {
		vec3 a = abs(onrm);
		vec2 uv = a.y > a.x && a.y > a.z ? opos.xz : (a.x > a.z ? opos.zy : opos.xy);
		uv *= 110.0;                           // 9 mm tows
		vec2 cell = floor(uv);
		vec2 f = fract(uv);
		bool along = mod(cell.x + floor(cell.y * 0.5) * 2.0 + cell.y, 4.0) < 2.0;
		float tow = along ? f.y : f.x;
		float ridge = 1.0 - pow(abs(tow - 0.5) * 2.0, 2.0);
		float fade = 1.0 - smoothstep(0.0, 0.35, fwidth(uv.x));
		// a faint weave (strong, it read as bricks or a maze)
		float sheen = mix(0.5, (along ? 0.58 : 0.42) * (0.7 + 0.3 * ridge), fade);
		ALBEDO = vec3(0.025, 0.026, 0.03) + vec3(0.04) * sheen;
		METALLIC = 0.35;
		ROUGHNESS = mix(0.4, 0.25 + 0.2 * (1.0 - ridge), fade);
#if !defined(RT)
		CLEARCOAT = 0.8;
		CLEARCOAT_ROUGHNESS = 0.1;
#endif
	} else {
		float r = length(opos.yz);
		float ang = atan(opos.z, opos.y);
		vec3 col = vec3(0.035, 0.035, 0.04);
		float rough = 0.9;
		float fade = 1.0 - smoothstep(3.0, 14.0, dist);
		if (r > tyre_radius * 0.9 && abs(opos.x) < tyre_half_width * 0.85) {
			// the tread: two circumferential grooves and sipes across
			float g = abs(abs(opos.x) - tyre_half_width * 0.35);
			float groove = 1.0 - smoothstep(0.008, 0.014, g);
			float sipe = step(0.85, fract(ang * 18.0 / 3.14159 + abs(opos.x) * 6.0));
			col *= 1.0 - (groove * 0.6 + sipe * 0.35) * fade;
			rough = 0.95;
		} else if (r > tyre_radius * 0.74 && r < tyre_radius * 0.84) {
			// the sidewall's lettering: two words a side, each a row of letter-like blocks of
			// varying width, in a dull grey (moulded rubber, not paint)
			float u = ang / 6.28318 + 0.5;
			float word = fract(u * 2.0);
			float inword = step(0.08, word) * step(word, 0.36);
			float g = fract(word * 34.0);
			float stem = step(0.18, g) * step(g, 0.72 + 0.2 * fract(sin(floor(word * 34.0) * 12.9) * 43758.5));
			float band = smoothstep(0.0, 0.15, (r / tyre_radius - 0.74) / 0.10) * smoothstep(1.0, 0.85, (r / tyre_radius - 0.74) / 0.10);
			col = mix(col, vec3(0.16), inword * stem * band * 0.9 * fade);
		}
		ALBEDO = col;
		ROUGHNESS = rough;
	}
}
