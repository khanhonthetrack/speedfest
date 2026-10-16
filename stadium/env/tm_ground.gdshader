shader_type spatial;
#include "res://env/rt.gdshaderinc"
// The Stadium's outer ground (HD): the measured class grid (TmStadiumBuild, one texel per 16 m
// cell: R grass, G road, B parking, A forecourt) filtered smoothly and sharpened, so the borders
// curve instead of stepping; each class with its own surface: mown grass, asphalt, blue parking
// with white bay lines, paved forecourt.

uniform sampler2D class_map : filter_linear, repeat_disable;
uniform vec2 extent = vec2(1728.0, 1248.0);   // the grid's half extents (m)
uniform vec3 grass_col : source_color = vec3(0.26, 0.38, 0.19);
uniform vec3 road_col : source_color = vec3(0.34, 0.33, 0.34);
uniform vec3 parking_col : source_color = vec3(0.20, 0.29, 0.62);
uniform vec3 parvis_col : source_color = vec3(0.59, 0.58, 0.59);
uniform sampler2D noise_fine : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_coarse : filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 opos;

void vertex() {
	opos = VERTEX;   // the stadium node is only moved: these are field-centred metres
}

float lines(float x, float period, float width) {
	float d = abs(fract(x / period + 0.5) - 0.5) * period;
	float fw = fwidth(x) + 1e-4;
	return 1.0 - smoothstep(width - fw, width + fw, d);
}

void fragment() {
	vec2 uv = opos.xz / extent * 0.5 + 0.5;
	vec4 w = texture(class_map, uv);
	w = smoothstep(vec4(0.3), vec4(0.7), w);
	w /= max(w.r + w.g + w.b + w.a, 1e-3);
	float fine = texture(noise_fine, opos.xz * 0.35).r;
	float micro = texture(noise_fine, opos.xz * 2.3).r;
	float coarse = texture(noise_coarse, opos.xz * 0.025).r;
	float fade = 1.0 - smoothstep(0.08, 0.4, fwidth(opos.x));

	vec3 grass = grass_col * (1.0 + (fine - 0.5) * 0.25 + (coarse - 0.5) * 0.2);
	grass *= 1.0 + (step(0.5, fract(opos.x / 32.0)) - 0.5) * 0.10 * fade;
	vec3 road = road_col * (1.0 + (micro - 0.5) * 0.12 + (coarse - 0.5) * 0.1);
	vec3 parking = parking_col * (1.0 + (fine - 0.5) * 0.12);
	parking = mix(parking, vec3(0.85), lines(opos.x, 5.0, 0.08) * fade * 0.8);
	vec3 parvis = parvis_col * (1.0 + (micro - 0.5) * 0.1 + (coarse - 0.5) * 0.12);
	float joint = max(lines(opos.x, 2.0, 0.03), lines(opos.z, 2.0, 0.03)) * fade;
	parvis *= 1.0 - joint * 0.25;

	ALBEDO = grass * w.r + road * w.g + parking * w.b + parvis * w.a;
	ROUGHNESS = 0.92 - w.g * 0.1;
}
