shader_type spatial;
render_mode blend_mul, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;
// Contact shadow under a car (M7 look plan step 4): darkens the road under the body and at the four
// tyre contacts, so the car sits on the road instead of floating over the underglow. Multiplies
// what is already drawn. UV 0..1 over a plane a little larger than the car.

uniform float strength = 0.55;
uniform vec2 inner = vec2(0.3, 0.55);
uniform vec2 wheel_uv = vec2(0.4, 0.33);   // tyre contact centres from the middle, in UV units
uniform vec2 wheel_r = vec2(0.08, 0.06);   // tyre contact half size, in UV units

void fragment() {
	vec2 q = abs(UV - 0.5) * 2.0;
	vec2 d = max(q - inner, vec2(0.0)) / (vec2(1.0) - inner);
	float body = 1.0 - clamp(length(d), 0.0, 1.0);
	body = body * body * 0.7;
	vec2 w = (abs(UV - 0.5) - wheel_uv) / wheel_r;   // mirrored: one test covers all four tyres
	float tyre = 1.0 - smoothstep(0.4, 1.0, length(w));
	ALBEDO = vec3(1.0 - strength * clamp(max(body, tyre), 0.0, 1.0));
}
