shader_type spatial;
render_mode unshaded;
// Emissive neon tubes and strips; optional checkerboard (start/finish banners and lines).

uniform vec4 color : source_color = vec4(0.0, 0.85, 1.0, 1.0);
uniform float energy = 3.0;
uniform float pulse = 0.12;
uniform float checker = 0.0;
uniform vec2 checker_scale = vec2(1.0, 1.0);
uniform float unlit_mix = 1.0;

void fragment() {
	vec3 c = color.rgb;
	float e = energy * (1.0 - pulse + pulse * sin(TIME * 3.0 + UV.y * 0.15));
	if (checker > 0.5) {
		vec2 q = floor(UV / checker_scale);
		float k = mod(q.x + q.y, 2.0);
		c = mix(vec3(0.03), c, k);
		e = energy;
	}
	ALBEDO = c * e;
}
