shader_type spatial;
render_mode unshaded;
// Diagonal hazard stripes (jump lips and landings). UV.x = meters across, UV.y = meters along.

uniform vec4 color_a : source_color = vec4(1.0, 0.75, 0.05, 1.0);
uniform vec4 color_b : source_color = vec4(0.04, 0.04, 0.05, 1.0);
uniform float energy = 1.4;
uniform float stripe = 1.2;

void fragment() {
	float k = fract((UV.x + UV.y) / stripe);
	float aa = fwidth((UV.x + UV.y) / stripe) * 1.5;
	float m = smoothstep(0.5 - aa, 0.5 + aa, k);
#if defined(RT)
	ALBEDO = color_b.rgb * m;
	EMISSION = color_a.rgb * energy * (1.0 - m);
#else
	ALBEDO = mix(color_a.rgb * energy, color_b.rgb, m);
#endif
}
