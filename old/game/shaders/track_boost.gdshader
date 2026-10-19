shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
// Boost pad: scrolling chevrons. UV.x = meters across (0..w), UV.y = meters along the pad.

uniform vec4 color_a : source_color = vec4(1.0, 0.45, 0.05, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.1, 0.6, 1.0);
uniform float speed = 9.0;
instance uniform float pad_len = 10.0;

void fragment() {
	float w = 1.0 / max(fwidth(UV.x), 0.0001);
	float x = UV.x;
	float width = max(x, 0.0);
	// center the chevron on the pad: use derivative-free center from UV range (pad is <= 9 m)
	float cx = abs(fract(UV.x / 9.0 + 0.0) * 9.0 - 4.5);
	float y = UV.y + TIME * speed;
	float chev = fract((y + cx * 0.8) / 3.0);
	float m = smoothstep(0.0, 0.08, chev) * (1.0 - smoothstep(0.42, 0.5, chev));
	float edge_fade = smoothstep(0.0, 1.2, UV.y) * (1.0 - smoothstep(pad_len - 1.2, pad_len, UV.y));
	vec3 c = mix(color_a.rgb, color_b.rgb, fract(UV.y / pad_len));
	float border = step(UV.x, 0.25) + step(8.75, UV.x);
	ALBEDO = c * (m * 2.6 + 0.25 + border * 0.0) * edge_fade;
}
