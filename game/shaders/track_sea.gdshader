shader_type spatial;
// Fallback sea (used only when the scenery module doesn't provide one). UV = world XZ.

uniform vec4 deep : source_color = vec4(0.05, 0.12, 0.2, 1.0);
uniform vec4 shallow : source_color = vec4(0.12, 0.32, 0.38, 1.0);
uniform float wave_scale = 0.06;

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

float waves(vec2 p) {
	float t = TIME;
	return vnoise(p * wave_scale + vec2(t * 0.05, t * 0.03)) * 0.6 + vnoise(p * wave_scale * 3.1 - vec2(t * 0.09, -t * 0.04)) * 0.4;
}

void fragment() {
	vec2 p = UV;
	float e = 0.6;
	float h0 = waves(p);
	float hx = waves(p + vec2(e, 0.0));
	float hz = waves(p + vec2(0.0, e));
	vec3 n_world = normalize(vec3((h0 - hx) * 2.2, 1.0, (h0 - hz) * 2.2));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep.rgb, shallow.rgb, h0 * 0.5);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.6 + 0.4 * fres;
}
