shader_type spatial;
// A gate's LED screen (blocks/tm_gate_screen.gd): the picture of its SubViewport shown as lit
// LED cells, the dots fading into a plain picture where a cell is smaller than a pixel (no moire
// far away). Dark glass between the cells.

uniform sampler2D screen_tex : source_color, filter_linear, repeat_disable;
uniform vec2 cells = vec2(384.0, 48.0);   // LED cells across and down
uniform float energy = 2.4;

void fragment() {
	vec3 c = texture(screen_tex, UV).rgb;
	vec2 g = UV * cells;
	vec2 fw = fwidth(g);
	float dot_ = 1.0 - smoothstep(0.32, 0.5, length(fract(g) - 0.5));
	float near = 1.0 - smoothstep(0.35, 0.8, max(fw.x, fw.y));
	float lit = mix(1.0, 0.25 + 0.75 * dot_, near);
	ALBEDO = vec3(0.015, 0.017, 0.02);
	ROUGHNESS = 0.18;
	SPECULAR = 0.6;
	EMISSION = c * energy * lit;
}
