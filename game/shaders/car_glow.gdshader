shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
// Underglow ground blob: soft rounded rectangle, animated by mode.

uniform vec4 glow_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform int mode = 1;          // 1 static, 2 pulse, 3 strobe, 4 rainbow
uniform float energy = 0.9;
uniform float enabled = 1.0;
uniform vec2 inner = vec2(0.25, 0.45);
uniform float phase = 0.0;

vec3 hue(float h) {
	vec3 k = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return k;
}

void fragment() {
	vec2 q = abs(UV - 0.5) * 2.0;
	vec2 d = max(q - inner, vec2(0.0)) / (vec2(1.0) - inner);
	float f = 1.0 - clamp(length(d), 0.0, 1.0);
	f = f * f;
	float t = TIME + phase;
	float k = 1.0;
	vec3 col = glow_color.rgb;
	if (mode == 2) {
		k = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 3.2));
	} else if (mode == 3) {
		k = step(0.45, fract(t * 5.0)) * 0.9 + 0.1;
	} else if (mode == 4) {
		col = hue(fract(t * 0.35 + UV.y * 0.6));
	}
	ALBEDO = col * f * k * energy * enabled;
}
