shader_type canvas_item;
// The menus' backdrop (SfUi, PLAN M16): charcoal, a red glow rising from the bottom left with a few
// faint diagonal streaks through it, a violet glow from the top right, drifting slowly; a little
// grain against banding.

uniform vec4 base : source_color = vec4(0.043, 0.047, 0.063, 1.0);
uniform vec4 red : source_color = vec4(0.91, 0.21, 0.31, 1.0);
uniform vec4 violet : source_color = vec4(0.45, 0.34, 1.0, 1.0);
uniform float aspect = 1.7778;
uniform float strength = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = vec2(UV.x * aspect, UV.y);
	float t = TIME * 0.05;
	vec3 c = base.rgb * (1.12 - 0.22 * UV.y);
	vec2 rc = vec2(-0.05 * aspect + 0.04 * sin(t), 1.12 + 0.03 * cos(t * 1.3));
	float dr = length(p - rc);
	c += red.rgb * 0.17 * strength * exp(-dr * dr * 2.6);
	vec2 vc = vec2(1.06 * aspect + 0.05 * cos(t * 0.8), -0.18 + 0.03 * sin(t));
	float dv = length(p - vc);
	c += violet.rgb * 0.15 * strength * exp(-dv * dv * 1.7);
	// streaks rising to the right at 60 degrees, only near the bottom left corner
	float b = dot(p, vec2(0.866, 0.5));
	float lines = pow(max(sin(b * 15.0 - t * 2.0), 0.0), 18.0) + 0.6 * pow(max(sin(b * 9.0 + 1.7), 0.0), 26.0);
	float near = exp(-pow(length(p - vec2(0.0, 1.0)), 2.0) * 3.5);
	c += red.rgb * 0.10 * strength * lines * near;
	// darker towards the edges
	vec2 q = UV - 0.5;
	c *= 1.0 - 0.35 * dot(q, q);
	c += (hash(FRAGCOORD.xy + fract(TIME) * 61.0) - 0.5) / 255.0 * 1.5;
	COLOR = vec4(c, 1.0);
}
