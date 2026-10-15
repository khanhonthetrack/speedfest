shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// SpeedFest car paint: finishes (gloss, metallic flake, pearl, matte, chrome), procedural liveries in
// car-local (ground-space) coordinates, and a carbon weave on parts tagged with vertex color R = 1.
// Works on Forward+ and Compatibility. Vertex color G = 1 forces the accent color (e.g. wing endplates).

uniform vec4 paint_color : source_color = vec4(1.0, 0.42, 0.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.06, 0.06, 0.06, 1.0);
uniform int finish = 1;       // 0 gloss, 1 metallic, 2 pearl, 3 matte, 4 chrome
uniform int livery = 0;       // 0 none, 1 racing_stripes, 2 side_stripe, 3 two_tone, 4 fade, 5 checker
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
