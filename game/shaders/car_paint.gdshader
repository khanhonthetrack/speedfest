shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/rt.gdshaderinc"
// SpeedFest car paint: finishes (gloss, metallic flake, pearl, matte, chrome), procedural liveries in
// car-local (ground-space) coordinates, and a carbon weave on parts tagged with vertex color R = 1.
// Works on Forward+ and Compatibility. Vertex color G = 1 forces the accent color (e.g. wing endplates).

uniform vec4 paint_color : source_color = vec4(1.0, 0.42, 0.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.06, 0.06, 0.06, 1.0);
uniform int finish = 1;       // 0 gloss, 1 metallic, 2 pearl, 3 matte, 4 chrome
uniform int livery = 0;       // index into CarDefs.LIVERIES (0 none ... 15 circuit), see livery_mask()
uniform int race_number = 7;  // "race" livery: the number in the roundels (0..99)
uniform bool carbon = false;
uniform float half_length = 2.2;
uniform float half_width = 0.88;
uniform float belt_y = 0.8;   // ground-space height of the shoulder line
uniform float sill_y = 0.16;
// Night readability (set by the race scene for dark themes, 0 elsewhere): a cool self-lit rim on
// silhouette edges plus a faint "sky" sheen on upward-facing panels, so the body shape reads from the
// chase camera even where no light reaches the car. No extra lights; works on both renderers.
uniform float night_rim = 0.0;
uniform vec3 rim_color : source_color = vec3(0.42, 0.58, 1.0);

varying vec3 lpos;
varying vec3 lnrm;
varying vec2 tag;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
	tag = COLOR.rg;
}

float band(float x, float a, float b) {
	float fw = max(fwidth(x), 0.0005);
	return smoothstep(a - fw, a + fw, x) - smoothstep(b - fw, b + fw, x);
}

float hash3(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

vec3 hue_shift(vec3 c, float h) {
	// rotate around the grey axis
	const vec3 k = vec3(0.57735);
	float ca = cos(h * 6.2831853);
	return c * ca + cross(k, c) * sin(h * 6.2831853) + k * dot(k, c) * (1.0 - ca);
}

float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

// anti-aliased "inside" for a signed distance (negative inside)
float fill(float d) {
	float fw = max(fwidth(d), 0.0008);
	return 1.0 - smoothstep(-fw, fw, d);
}

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// seven-segment digit in a cell 1 wide x 2 tall centered at the origin (segments a..g)
float seg_digit(vec2 p, int dg) {
	// bit per segment: a=1 top, b=2 top-right, c=4 bottom-right, d=8 bottom, e=16 bottom-left,
	// f=32 top-left, g=64 middle
	int m = 0;
	if (dg == 0) m = 63; else if (dg == 1) m = 6; else if (dg == 2) m = 91; else if (dg == 3) m = 79;
	else if (dg == 4) m = 102; else if (dg == 5) m = 109; else if (dg == 6) m = 125; else if (dg == 7) m = 7;
	else if (dg == 8) m = 127; else m = 111;
	float t = 0.17;
	float d = 1e3;
	if ((m & 1) != 0) d = min(d, sd_box(p - vec2(0.0, 0.85), vec2(0.36, t)));
	if ((m & 2) != 0) d = min(d, sd_box(p - vec2(0.38, 0.43), vec2(t, 0.38)));
	if ((m & 4) != 0) d = min(d, sd_box(p - vec2(0.38, -0.43), vec2(t, 0.38)));
	if ((m & 8) != 0) d = min(d, sd_box(p - vec2(0.0, -0.85), vec2(0.36, t)));
	if ((m & 16) != 0) d = min(d, sd_box(p - vec2(-0.38, -0.43), vec2(t, 0.38)));
	if ((m & 32) != 0) d = min(d, sd_box(p - vec2(-0.38, 0.43), vec2(t, 0.38)));
	if ((m & 64) != 0) d = min(d, sd_box(p, vec2(0.36, t)));
	return d;
}

// "race" roundel: accent disc, paint-colored number inside, thin accent ring around
float roundel(vec2 p, float r) {
	float disc = fill(length(p) - r);
	float ring = fill(abs(length(p) - r * 1.18) - r * 0.045);
	int n = clamp(race_number, 0, 99);
	float digits;
	float sc = n >= 10 ? r * 0.4 : r * 0.5;
	vec2 q = p / sc;
	if (n >= 10) {
		float d1 = seg_digit((q - vec2(-0.64, 0.0)), n / 10);
		float d2 = seg_digit((q - vec2(0.64, 0.0)), n % 10);
		digits = fill(min(d1, d2) * sc);
	} else {
		digits = fill(seg_digit(q, n) * sc);
	}
	return max(disc * (1.0 - digits), ring);
}

// hexagon distance (flat-top cells): returns (distance to cell edge, cell id)
vec4 hex_cell(vec2 p) {
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
	return dot(h.xy, h.xy) < dot(h.zw, h.zw) ? vec4(h.xy, hc.xy) : vec4(h.zw, hc.zw + 9.73);
}

float livery_mask() {
	float zn = lpos.z / half_length;          // -1 front .. +1 rear
	float ax = abs(lpos.x);
	bool side = abs(lnrm.x) > 0.45;
	if (lnrm.y < -0.6) {
		return 0.0;
	}
	if (livery == 1) {
		// twin racing stripes over nose, hood, roof, deck and tail
		float w = half_width * 0.15;
		float g = half_width * 0.045;
		float m = band(ax, g, g + w);
		float pin = band(ax, g + w + 0.025, g + w + 0.04);
		return side ? 0.0 : max(m, pin);
	}
	if (livery == 2) {
		// hockey-stick side stripe rising toward the tail, with a pinstripe under it
		if (!side) return 0.0;
		float t = zn * 0.5 + 0.5;
		float yc = mix(sill_y + 0.2, belt_y - 0.1, t * t);
		float w = mix(0.11, 0.05, t);
		float m = band(lpos.y, yc - w * 0.5, yc + w * 0.5);
		float pin = band(lpos.y, yc - w * 0.5 - 0.035, yc - w * 0.5 - 0.022);
		return max(m, pin) * smoothstep(-0.97, -0.88, zn) * (1.0 - smoothstep(0.9, 0.97, zn));
	}
	if (livery == 3) {
		// two-tone: accent lower body with a crisp pinstripe on the split line
		float split = mix(sill_y, belt_y, 0.42);
		float m = 1.0 - smoothstep(split - 0.004, split + 0.004, lpos.y);
		float pin = band(lpos.y, split + 0.02, split + 0.032);
		return max(m, pin);
	}
	if (livery == 4) {
		// halftone fade from clean nose to accent tail
		float a = smoothstep(-0.35, 0.85, zn);
		vec2 uv = side ? lpos.zy : lpos.zx;
		vec2 cell = fract(uv / 0.045) - 0.5;
		float r = sqrt(a) * 0.62;
		float d = length(cell);
		float fw = max(fwidth(d), 0.001);
		float dots = 1.0 - smoothstep(r - fw, r + fw, d);
		return max(dots, smoothstep(0.93, 0.98, a));
	}
	if (livery == 5) {
		// checkered flag band sweeping over the rear quarter and deck
		vec2 uv = side ? lpos.zy : lpos.zx;
		float s = 0.085;
		vec2 c = floor(uv / s);
		float chk = mod(c.x + c.y, 2.0);
		float zone = smoothstep(0.18, 0.24, zn) * (1.0 - smoothstep(0.62, 0.68, zn));
		if (side) zone *= step(lpos.y, belt_y + 0.05);
		return chk * zone;
	}
	float u = zn * 0.5 + 0.5;                          // 0 nose .. 1 tail
	float vs = clamp((lpos.y - sill_y) / max(belt_y - sill_y, 0.05), 0.0, 1.0);   // 0 sill .. 1 belt
	vec2 pl = side ? lpos.zy : lpos.zx;                // panel plane coordinates (m)
	if (livery == 6) {
		// hot-rod flames licking back from the nose (sides and hood)
		float n = side ? 4.0 : 5.0;
		float v = side ? vs : (lpos.x / half_width) * 0.5 + 0.5;
		v += sin(u * 26.0 + v * 7.0) * 0.025;
		float i = floor(v * n);
		float w = abs(fract(v * n) - 0.5) * 2.0;
		float len = (side ? 0.3 : 0.22) + (side ? 0.32 : 0.2) * hash2(vec2(i, 3.1));
		float tip = len * (1.0 - pow(w, 1.4));
		float m = fill((u - tip) * half_length * 2.0);
		if (side) m *= step(sill_y + 0.03, lpos.y) * (1.0 - step(belt_y + 0.02, lpos.y));
		return max(m, fill((u - 0.06) * half_length * 2.0));
	}
	if (livery == 7) {
		// lightning bolt along the side, thinning to a point at the tail
		if (!side) return 0.0;
		// a jagged polyline: long falling strokes with short kicks back up (sawtooth), bold at the
		// front wheel and sharpening to a point at the tail
		float k = (u - 0.1) * 3.2;
		float f = fract(k);
		float zig = f < 0.78 ? f / 0.78 : 1.0 - (f - 0.78) / 0.22;
		float yc = mix(belt_y - 0.07, sill_y + 0.1, zig);
		float th = mix(0.19, 0.014, smoothstep(0.1, 0.95, u));
		// thickness measured across the stroke, not vertically: steep strokes stay bold
		float slope = (belt_y - sill_y - 0.17) * 3.2 / (half_length * 2.0) * (f < 0.78 ? 1.0 / 0.78 : 1.0 / 0.22);
		float m = fill(abs(lpos.y - yc) / sqrt(1.0 + slope * slope) - th * 0.5);
		return m * step(0.1, u) * (1.0 - step(0.95, u));
	}
	if (livery == 8) {
		// 80s triple stripes along the side, kicking up over the rear wheel; graded tones
		if (!side) return 0.0;
		float yc = belt_y - 0.12 + 0.11 * smoothstep(0.62, 0.9, u);
		float d = lpos.y - yc;
		float m = fill(abs(d) - 0.022);
		m = max(m, 0.7 * fill(abs(d + 0.05) - 0.014));
		m = max(m, 0.45 * fill(abs(d + 0.085) - 0.009));
		return m * smoothstep(-0.98, -0.9, zn) * (1.0 - smoothstep(0.9, 0.97, zn));
	}
	if (livery == 9) {
		// digital camo: three tones from two noise octaves snapped to 6 cm pixels
		vec2 c = floor(pl / 0.06);
		float nv = vnoise(c * 0.22 + (side ? vec2(0.0) : vec2(13.0, 7.0))) * 0.7 + vnoise(c * 0.6 + 4.0) * 0.3;
		return nv > 0.6 ? 1.0 : (nv > 0.46 ? 0.5 : 0.0);
	}
	if (livery == 10) {
		// tiger stripes: warped bands across the body, tapering away from the shoulder line
		float q = lpos.z * 4.2 + 0.9 * vnoise(pl * 2.3 + 1.7);
		float i = floor(q);
		float f = fract(q);
		float depth = side ? 1.0 - vs : 1.0 - abs(lpos.x) / half_width;   // 0 at the shoulder
		float len = 0.45 + 0.5 * hash2(vec2(i, 1.3));
		float th = (0.16 + 0.2 * hash2(vec2(i, 7.7))) * clamp(1.0 - depth / len, 0.0, 1.0);
		return fill(abs(f - 0.5) - th * 0.5);
	}
	if (livery == 11) {
		// honeycomb: filled hexagons growing denser toward the tail
		vec4 h = hex_cell(pl / 0.075);
		float a = smoothstep(-0.2, 0.9, zn);
		float on = step(hash2(h.zw), a);
		float edge = 0.5 - max(abs(h.x) * 0.5 + abs(h.y) * 0.866, abs(h.x));
		return on * fill(0.07 - edge);
	}
	if (livery == 12) {
		// smooth nose-to-tail fade
		return smoothstep(-0.75, 0.85, zn);
	}
	if (livery == 13) {
		// race car: number roundels on both doors and the hood, a stripe over the roof
		if (side) {
			float r = clamp((belt_y - sill_y) * 0.42, 0.13, 0.27);
			vec2 c = vec2(0.05 * half_length, mix(sill_y, belt_y, 0.55));
			vec2 p = vec2((lpos.z - c.x) * (lnrm.x < 0.0 ? 1.0 : -1.0), lpos.y - c.y);
			return roundel(p, r);
		}
		vec2 ph = vec2(-lpos.x, lpos.z + 0.62 * half_length);
		float hood = roundel(ph, half_width * 0.26);
		float stripe = fill(abs(lpos.x) - half_width * 0.09) * step(-0.25, zn);
		return max(hood, stripe);
	}
	if (livery == 14) {
		// dripping paint: accent tops running down over the shoulders in drips of random length
		if (!side) return lnrm.y > 0.55 ? 1.0 : 0.0;
		float cw = 0.055;
		float col = floor(lpos.z / cw);
		float cx = fract(lpos.z / cw) - 0.5;
		float h = hash2(vec2(col, 2.0));
		float len = 0.03 + 0.42 * h * h * h;
		float wd = 0.28 + 0.18 * hash2(vec2(col, 5.0));
		float yb = belt_y - 0.035 - len * (1.0 - smoothstep(wd * 0.6, wd, abs(cx)));
		float bulb = fill(length(vec2(cx * cw, lpos.y - yb)) - cw * wd * 0.62) * step(0.12, len);
		return max(fill(yb - lpos.y), bulb);
	}
	if (livery == 15) {
		// circuit board: traces and vias on a 9 cm grid, denser toward the tail
		float g = 0.09;
		vec2 c = floor(pl / g);
		vec2 f = fract(pl / g) - 0.5;
		float hsh = hash2(c + 0.5);
		float a = 0.35 + 0.55 * smoothstep(-0.6, 0.9, zn);
		if (hsh > a) return 0.0;
		float lw = 0.065;
		float k = floor(hsh / a * 4.0);
		float d;
		if (k < 1.0) d = abs(f.y);                                       // straight
		else if (k < 2.0) d = abs(f.x);
		else if (k < 3.0) d = min(max(abs(f.y), -f.x), max(abs(f.x), -f.y)); // elbow
		else d = abs(length(f) - 0.18) - 0.03;                             // via
		float via = fill(length(f - vec2(0.5, 0.0)) - 0.12) * step(k, 1.5);
		return max(fill(d - lw), via);
	}
	return 0.0;
}

void fragment() {
	vec3 base = paint_color.rgb;
	float acc = clamp(livery_mask() + step(0.5, tag.g), 0.0, 1.0);
	base = mix(base, accent_color.rgb, acc);
	float NdotV = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - NdotV, 3.0);
	float metal = 0.0;
	float rough = 0.12;
	float spec = 0.6;
	float coat = 1.0;
	if (finish == 1) {
		// metallic flake, faded out with distance so it never turns into noise
		vec3 fp = lpos * 520.0;
		float fade = 1.0 - smoothstep(0.35, 1.0, length(fwidth(fp)));
		float fl = mix(0.5, hash3(floor(fp)), fade);
		metal = 0.72;
		rough = 0.34 - (fl - 0.5) * 0.18;
		base *= 0.95 + 0.12 * fl;
	} else if (finish == 2) {
		vec3 shift = hue_shift(base, -0.09) * 1.1 + vec3(0.03);
		base = mix(base, shift, clamp(fres * 1.6, 0.0, 1.0));
		base = mix(base, vec3(0.95, 0.92, 1.0), fres * 0.25);
		metal = 0.45;
		rough = 0.18;
	} else if (finish == 3) {
		metal = 0.05;
		rough = 0.72;
		spec = 0.3;
		coat = 0.0;
	} else if (finish == 4) {
		base = mix(base, vec3(1.0), 0.3);
		metal = 1.0;
		rough = 0.05;
		coat = 0.0;
	}
	if (carbon && tag.r > 0.5) {
		// 2x2 twill weave
		vec2 uv = lpos.xz * 70.0;
		vec2 cell = floor(uv);
		vec2 f = fract(uv);
		float dir = mod(cell.x + floor(cell.y * 0.5) * 2.0 + cell.y, 4.0) < 2.0 ? 1.0 : 0.0;
		float fiber = dir > 0.5 ? sin(f.x * 3.14159) : sin(f.y * 3.14159);
		float w = 0.035 + 0.06 * fiber * (dir > 0.5 ? 1.0 : 0.6);
		base = vec3(w, w, w * 1.08);
		metal = 0.35;
		rough = 0.22;
		coat = 1.0;
	}
	if (night_rim > 0.0) {
		vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float up = clamp(wn.y, 0.0, 1.0);
		float edge = pow(1.0 - NdotV, 2.2);
		vec3 sheen = rim_color * (edge * 0.55 + up * 0.10) + base * 0.06;
		EMISSION = sheen * night_rim;
	}
	ALBEDO = base;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = spec;
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.04;
#else
	// no clearcoat on Compatibility: fake a little extra edge sheen instead
	ROUGHNESS = mix(rough, 0.08, fres * coat * 0.6);
#endif
}
