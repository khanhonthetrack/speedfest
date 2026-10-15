shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Emissive neon / LED / signal lights. Color comes from the vertex (or instance) color,
// UV2.x selects the animation (0 steady, 1 flicker, 2 blink, 3 pulse, 4 chase), UV2.y its phase.

uniform float energy = 4.0;
varying float k;

float h11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void vertex() {
	float mode = UV2.x;
	float ph = UV2.y;
	k = 1.0;
	if (mode > 0.5 && mode < 1.5) {
		float t = floor(TIME * 9.0 + ph * 50.0);
		float a = h11(t + ph * 13.0);
		k = a > 0.93 ? 0.12 : (a > 0.88 ? 0.55 : 1.0);
	} else if (mode > 1.5 && mode < 2.5) {
		k = fract(TIME * 0.8 + ph) < 0.18 ? 1.0 : 0.04;
	} else if (mode > 2.5 && mode < 3.5) {
		k = 0.55 + 0.45 * sin(TIME * 2.5 + ph * 6.2831);
	} else if (mode > 3.5) {
		k = 0.25 + 0.75 * pow(0.5 + 0.5 * sin(TIME * 6.0 - ph * 6.2831), 3.0);
	}
}

void fragment() {
	ALBEDO = COLOR.rgb * energy * k;
}
