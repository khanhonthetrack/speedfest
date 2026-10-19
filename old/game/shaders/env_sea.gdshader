shader_type spatial;
// Animated sea (fragment-only waves: normals from a sum of moving directional waves plus
// fine ripples). Reflects the sky via radiance (and SSR on Forward+). Opaque and cheap.

uniform vec3 deep_color : source_color = vec3(0.02, 0.07, 0.11);
uniform vec3 scatter_color : source_color = vec3(0.05, 0.22, 0.26);
uniform float wave_scale = 1.0;
uniform float roughness_near = 0.04;
uniform float roughness_far = 0.18;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = wp.xz;
	float dist = length(VERTEX);
	vec2 grad = vec2(0.0);
	// directional waves: (dir, wavelength, amplitude, speed)
	vec4 w[6] = vec4[6](
		vec4(1.0, 0.3, 38.0, 0.35), vec4(0.7, -0.7, 23.0, 0.25), vec4(-0.4, 0.9, 15.0, 0.18),
		vec4(0.9, 0.45, 9.0, 0.1), vec4(-0.8, -0.3, 5.5, 0.06), vec4(0.2, -1.0, 3.3, 0.04));
	for (int i = 0; i < 6; i++) {
		vec2 dir = normalize(w[i].xy);
		float k = 6.2831 / w[i].z;
		float c = sqrt(9.81 / k);
		float ph = k * dot(dir, p) - c * k * TIME * 0.6;
		grad += dir * k * w[i].w * cos(ph) * wave_scale;
	}
	// fine ripples (fade with distance to avoid shimmer)
	float fine = clamp(1.0 - dist / 250.0, 0.0, 1.0);
	vec2 q = p * 0.6 + vec2(TIME * 0.3, TIME * 0.17);
	float e = 0.15;
	float n0 = vnoise(q);
	grad += vec2(vnoise(q + vec2(e, 0.0)) - n0, vnoise(q + vec2(0.0, e)) - n0) / e * 0.25 * fine;
	float far_k = clamp(dist / 1500.0, 0.0, 1.0);
	grad *= mix(1.0, 0.35, far_k);
	vec3 n = normalize(vec3(-grad.x, 1.0, -grad.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float facing = clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0);
	ALBEDO = mix(scatter_color, deep_color, facing * 0.6 + 0.4);
	ROUGHNESS = mix(roughness_near, roughness_far, far_k);
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
