shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
// Nitro exhaust flame. UV.y = 0 at the exhaust tip .. 1 at the flame end.

uniform float intensity = 1.0;
uniform vec4 core_color : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform vec4 outer_color : source_color = vec4(0.15, 0.3, 1.0, 1.0);

float n1(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void fragment() {
	float t = UV.y;
	float fl = 0.75 + 0.25 * mix(n1(floor(TIME * 40.0)), n1(floor(TIME * 40.0) + 1.0), fract(TIME * 40.0));
	float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.4);
	float len_fade = pow(clamp(1.0 - t / fl, 0.0, 1.0), 1.3);
	vec3 col = mix(core_color.rgb * 2.0, outer_color.rgb, smoothstep(0.0, 0.6, t));
	ALBEDO = col * edge * len_fade * intensity * 2.2;
}
