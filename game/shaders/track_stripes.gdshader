shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/rt.gdshaderinc"
// Diagonal stripes: road-edge curbs and jump lips/landings. UV.x = metres across, UV.y = metres along.
// M7 look plan step 6: painted, not unshaded stickers. They take the scene's lights, get glossy
// when wet, glow a little (self_lit, more on the web where there are few lights) and retro-reflect
// toward the camera like road paint, strongest close by.

uniform vec4 color_a : source_color = vec4(1.0, 0.75, 0.05, 1.0);
uniform vec4 color_b : source_color = vec4(0.04, 0.04, 0.05, 1.0);
uniform float stripe = 1.2;
uniform float wetness = 0.0;
uniform float self_lit = 0.1;
uniform float retro = 0.5;
uniform float profile_len = 0.0;   // > 0: darker at both ends of the profile (the curb's base)

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float k = fract((UV.x + UV.y) / stripe);
	float aa = fwidth((UV.x + UV.y) / stripe) * 1.5;
	float m = smoothstep(0.5 - aa, 0.5 + aa, k);
	vec3 alb = mix(color_a.rgb, color_b.rgb, m);
	alb *= 0.88 + 0.12 * h21(floor(UV * vec2(6.0, 3.0)));   // worn paint
	if (profile_len > 0.0) {
		alb *= mix(0.55, 1.0, smoothstep(0.0, 0.1, min(UV.x, profile_len - UV.x)));
	}
	ALBEDO = alb;
	ROUGHNESS = mix(0.45, 0.12, wetness);
	SPECULAR = 0.5;
#if defined(RT)
	EMISSION = alb * self_lit;
#else
	float facing = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = alb * (self_lit + retro * facing * 25.0 / (25.0 + length(VERTEX)));
#endif
}
