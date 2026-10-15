shader_type spatial;
render_mode unshaded, cull_disabled;
// Corner chevron boards. UV.x runs along the direction of travel (0..1), UV.y up (0..1).

uniform vec4 fg : source_color = vec4(1.0, 0.75, 0.1, 1.0);
uniform vec4 bg : source_color = vec4(0.03, 0.03, 0.04, 1.0);
uniform float energy = 2.2;
uniform float flip = 0.0;

void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) { uv.x = 1.0 - uv.x; }
	float y = abs(uv.y - 0.5);
	float x = (1.0 - uv.x) * 2.0 - y * 1.4;   // tips point toward +u (direction of travel)
	float k = fract(x);
	float chev = step(0.15, k) * step(k, 0.55);
	float border = step(uv.y, 0.06) + step(0.94, uv.y);
	vec3 c = mix(bg.rgb, fg.rgb * energy, clamp(chev + border * 0.6, 0.0, 1.0));
	// slow sweep in the direction of travel
	float sweep = 0.75 + 0.25 * sin(uv.x * 6.0 - TIME * 5.0);
	ALBEDO = c * mix(1.0, sweep, chev);
}
