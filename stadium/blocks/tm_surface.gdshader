shader_type spatial;
#include "res://env/rt.gdshaderinc"
#include "res://env/tm_occlusion.gdshaderinc"
// The remake's surfaces (our own procedural materials in the Stadium's style; TmMaterials sets
// them up per material key). Patterns are drawn in world space, so they run on across blocks and
// need no UVs: noise is blended over the three axis planes, lines and tiles use the plane the
// face is closest to. Relief is bump-mapped from a height (screen-space derivatives), fading out
// with distance against shimmer.
// pattern: 0 plain, 1 concrete, 2 grass, 3 dirt, 4 perforated grid, 5 brushed metal, 6 turbo
// stripes, 7 seat rows, 8 screen/LED (the adverts scrolling, else animated bands), 9 fabric,
// 10 louvres, 11 wall panels, 12 paving, 13 lamp grid (floodlights), 14 striped vinyl (inflatables).

uniform int pattern = 0;
uniform vec3 albedo : source_color = vec3(0.65);
uniform vec3 albedo2 : source_color = vec3(0.3);
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform float emission_energy = 0.0;
uniform float scale = 4.0;          // the pattern's size in metres (panels, tiles, stripes)
uniform float variation = 0.08;     // albedo noise
uniform float bump = 0.02;          // relief strength
uniform sampler2D noise_fine : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_coarse : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D advert_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_advert = false;
uniform float ad_scale = 1.0;       // the ads' size on this material's screens (big screens: 3)
const float AD_PANELS = 16.0;       // ads side by side in advert_tex (env/tm_adverts.gd)
const float AD_W = 8.0;             // one ad's width on a screen (m)
const float AD_H = 4.0;             // and height

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri_w(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / (w.x + w.y + w.z);
}

float tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy).r * w.x + texture(t, p.xz).r * w.y + texture(t, p.xy).r * w.z;
}

// the face's plane coordinates (metres) and which way is "along" for lines
vec2 plane_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) {
		return p.xz;
	}
	if (a.x >= a.z) {
		return vec2(p.z, p.y);
	}
	return vec2(p.x, p.y);
}

// 1 on a seam of a grid of cells `size` with lines `width` wide, antialiased; fades out where
// the cells get small on screen (a dense grid would read as graph paper)
float seams(vec2 uv, vec2 size, float width) {
	vec2 d = abs(fract(uv / size + 0.5) - 0.5) * size;
	vec2 fw = fwidth(uv) + 1e-4;
	vec2 s = 1.0 - smoothstep(vec2(width) - fw, vec2(width) + fw, d);
	float fade = 1.0 - smoothstep(0.015, 0.06, max(fw.x, fw.y) / min(size.x, size.y));
	return max(s.x, s.y) * fade;
}

// 1 on stripes of period `period` (fraction `duty` on), antialiased
float stripes(float x, float period, float duty) {
	float f = fract(x / period);
	float fw = fwidth(x) / period + 1e-4;
	return smoothstep(0.0, fw, f) * (1.0 - smoothstep(duty - fw, duty, f));
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 w = tri_w(n);
	vec2 uv = plane_uv(wpos, n);
	float fine = tri(noise_fine, wpos * 0.35, w);        // ~3 m grain
	float micro = tri(noise_fine, wpos * 2.3, w);        // ~0.4 m
	float coarse = tri(noise_coarse, wpos * 0.025, w);   // ~40 m
	vec3 col = albedo;
	float h = 0.0;
	float rough = roughness;
	float metal = metallic;
	vec3 emit = vec3(0.0);
	float dist = length(VERTEX);
	float aa = clamp(fwidth(uv.x) * 40.0, 0.0, 1.0);    // 1 where fine patterns would alias

	if (pattern == 1) {            // concrete: grain, stains, optional panel seams
		col *= 1.0 + (fine - 0.5) * variation * 2.0 + (micro - 0.5) * variation;
		col *= 1.0 - smoothstep(0.55, 0.8, coarse) * 0.10;
		if (scale > 0.0) {
			float s = seams(uv, vec2(scale), 0.04);
			col *= 1.0 - s * 0.25;
			h -= s * 0.6;
		}
		h += micro * 0.4;
		rough = clamp(roughness + (fine - 0.5) * 0.15, 0.0, 1.0);
	} else if (pattern == 2) {     // grass: mown stripes, mottled, fine blades
		float stripe = stripes(wpos.x, scale * 2.0, 0.5);
		col *= 1.0 + (stripe - 0.5) * 0.12;
		col *= 1.0 + (fine - 0.5) * variation * 2.0 + (coarse - 0.5) * 0.2;
		col = mix(col, albedo2, smoothstep(0.62, 0.75, micro) * 0.25);
		h += micro * 1.2;
	} else if (pattern == 3) {     // dirt: lumpy, pebbles
		float lumps = tri(noise_fine, wpos * 0.9, w);
		col *= 1.0 + (lumps - 0.5) * variation * 3.0 + (fine - 0.5) * variation * 2.0;
		float peb = smoothstep(0.66, 0.72, micro);
		col = mix(col, albedo2, peb * 0.6);
		h += lumps * 2.0 + peb * 1.0;
	} else if (pattern == 4) {     // perforated metal: round holes on a square pitch
		vec2 c = fract(uv / scale) - 0.5;
		float r = length(c) * scale;
		float fw = fwidth(r) + 1e-4;
		float hole = 1.0 - smoothstep(scale * 0.32 - fw, scale * 0.32 + fw, r);
		hole = mix(hole, 0.32, aa);
		col = mix(albedo, albedo2, hole);
		metal = mix(metallic, 0.0, hole);
		h -= hole * 0.3;
		col *= 1.0 + (fine - 0.5) * variation;
	} else if (pattern == 5) {     // brushed metal with panel seams
		float brush = texture(noise_fine, vec2(uv.x * 0.15, uv.y * 6.0)).r;
		col *= 1.0 + (brush - 0.5) * variation * 2.0;
		float s = seams(uv, vec2(scale), 0.025);
		col *= 1.0 - s * 0.35;
		h -= s * 0.5;
		rough = clamp(roughness + (brush - 0.5) * 0.2, 0.0, 1.0);
	} else if (pattern == 6) {     // turbo: bright diagonal stripes on a dark grate
		float st = stripes(uv.x + uv.y, scale, 0.5);
		col = mix(albedo2, albedo, st);
		float grate = stripes(uv.x * 1.0, 0.08, 0.3);
		col *= 1.0 - mix(grate, 0.3, aa) * 0.25;
		emit = albedo * st * 0.15;
	} else if (pattern == 7) {     // stands: rows of seats in sectors of two colours, aisles between
		// on a rake (not a flat top): rows by height (the dark seat backs, a seat every 0.5 m),
		// sectors `scale` m wide along the stand in albedo / albedo2, concrete stairs between them
		// (each detail fades to its average where a pixel covers half of it)
		float rake = 1.0 - smoothstep(0.8, 0.97, abs(n.y));
		float along = abs(n.x) > abs(n.z) ? wpos.z : wpos.x;
		float sector = mod(floor(along / scale), 2.0);
		vec3 seat = mix(albedo, albedo2, sector);
		float row = mix(stripes(wpos.y, 0.45, 0.4), 0.4, clamp(fwidth(wpos.y) / 0.22 - 0.5, 0.0, 1.0));
		float gap = mix(stripes(along, 0.5, 0.12), 0.12, clamp(fwidth(along) / 0.25 - 0.5, 0.0, 1.0));
		float aisle = stripes(along + scale * 0.5, scale, 1.4 / scale) * rake;
		float walk = stripes(wpos.y, 5.4, 0.16) * rake;     // a walkway every 12 rows
		col = mix(seat, seat * 0.45, row * rake);
		col *= 1.0 - gap * 0.3 * rake;
		col = mix(col, vec3(0.62, 0.63, 0.65), max(aisle, walk));
		col *= 1.0 + (fine - 0.5) * variation;
		h += (row * 0.5 - max(aisle, walk) * 0.3) * rake;
	} else if (pattern == 8) {     // LED boards and screens: the adverts scrolling on a pixel grid
		float px = 1.0 - mix(seams(uv, vec2(0.12), 0.012), 0.08, aa) * 0.6;
		if (has_advert && abs(n.y) < 0.7) {
			// read from the front: "right" as a viewer facing the screen sees it, v down
			vec3 right = normalize(cross(-n, vec3(0.0, 1.0, 0.0)));
			vec2 ad = vec2(dot(wpos, right) / (AD_W * AD_PANELS * ad_scale) + TIME * 0.012 / ad_scale,
				-wpos.y / (AD_H * ad_scale));
			emit = texture(advert_tex, ad).rgb * px * 1.6;
		} else {
			float band = 0.55 + 0.45 * sin(uv.x * 0.25 - TIME * 2.0 + sin(uv.y * 0.6 + TIME) * 0.8);
			emit = mix(albedo2, albedo, band) * px;
		}
		col = albedo * 0.2;
	} else if (pattern == 9) {     // fabric: soft weave, seams every `scale`
		col *= 1.0 + (fine - 0.5) * variation;
		float s = seams(uv, vec2(scale), 0.05);
		col *= 1.0 - s * 0.12;
		h += micro * 0.15 - s * 0.3;
	} else if (pattern == 10) {    // louvres: slats with dark gaps
		float slat = stripes(uv.x, scale, 0.75);
		col = mix(albedo2, albedo, mix(slat, 0.75, aa));
		h += slat * 0.4;
	} else if (pattern == 11) {    // wall panels: seams, streaks running down
		float streak = texture(noise_fine, vec2(uv.x * 0.6, uv.y * 0.04)).r;
		col *= 1.0 + (fine - 0.5) * variation + (streak - 0.5) * variation;
		float s = seams(uv, vec2(scale, scale * 0.5), 0.03);
		col *= 1.0 - s * 0.3;
		h -= s * 0.5;
	} else if (pattern == 12) {    // paving: tiles with joints
		float s = seams(uv, vec2(scale), 0.03);
		float tile = texture(noise_coarse, floor(uv / scale) * 0.137).r;
		col *= 1.0 + (tile - 0.5) * variation * 1.5 + (micro - 0.5) * variation;
		col *= 1.0 - s * 0.35;
		h -= s * 0.6;
	} else if (pattern == 13) {    // lamp grid: round lamps in rows on a dark panel
		vec2 c = fract(uv / scale) - 0.5;
		float lit = 1.0 - smoothstep(0.26, 0.34, length(c));
		lit = mix(lit, 0.35, aa);
		emit = mix(albedo2 * 0.15, albedo, lit);
		col = mix(albedo2, albedo, lit * 0.5);
	} else if (pattern == 14) {    // striped vinyl: colour and white bands, puffed between seams
		float s = stripes(uv.x + uv.y * 0.15, scale, 0.5);
		col = mix(albedo, albedo2, mix(s, 0.5, aa));
		float puff = sin(fract((uv.x + uv.y * 0.15) / (scale * 0.5)) * 3.14159);
		col *= 0.85 + 0.15 * puff;
		h += puff * 0.6;
	} else {                       // plain: a little grain
		col *= 1.0 + (fine - 0.5) * variation;
		h += micro * 0.2;
	}

	// bump from the height, in view space (Mikkelsen's surface gradient)
	float b = bump * (1.0 - smoothstep(30.0, 140.0, dist));
	if (b > 0.0) {
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		float dhdx = dFdx(h);
		float dhdy = dFdy(h);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		if (abs(det) > 1e-12) {
			vec3 grad = (dhdx * r1 + dhdy * r2) / det;
			NORMAL = normalize(NORMAL - grad * b);
		}
	}
	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = (pattern == 6 || pattern == 8 || pattern == 13 ? emit : albedo) * emission_energy;
	AO = tm_sky_visibility(wpos, n);
	AO_LIGHT_AFFECT = 0.0;
}
