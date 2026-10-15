shader_type spatial;
// Coast terrain: sand at the waterline, dry grass and scrub on gentle slopes, rock on cliffs.
// UV = world XZ.

uniform vec4 sand : source_color = vec4(0.72, 0.6, 0.42, 1.0);
uniform vec4 grass : source_color = vec4(0.32, 0.36, 0.17, 1.0);
uniform vec4 scrub : source_color = vec4(0.2, 0.25, 0.12, 1.0);
uniform vec4 rock : source_color = vec4(0.42, 0.34, 0.29, 1.0);
uniform vec4 rock_dark : source_color = vec4(0.24, 0.2, 0.18, 1.0);

varying float v_height;
varying float v_slope;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	v_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	v_slope = 1.0 - NORMAL.y;
}

void fragment() {
	vec2 p = UV;
	float n = vnoise(p * 0.05) * 0.5 + vnoise(p * 0.21) * 0.3 + vnoise(p * 1.1) * 0.2;
	vec3 veg = mix(grass.rgb, scrub.rgb, smoothstep(0.35, 0.65, n));
	float strata = vnoise(vec2(p.x * 0.02, v_height * 0.6));
	vec3 rk = mix(rock_dark.rgb, rock.rgb, strata * 0.7 + n * 0.3);
	float rockiness = smoothstep(0.18, 0.4, v_slope + (n - 0.5) * 0.2);
	vec3 col = mix(veg, rk, rockiness);
	float beach = 1.0 - smoothstep(0.6, 2.4, v_height + n * 1.5);
	col = mix(col, sand.rgb * (0.9 + 0.2 * n), beach);
	col = mix(col, sand.rgb * 0.55, 1.0 - smoothstep(-1.5, 0.3, v_height));
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
