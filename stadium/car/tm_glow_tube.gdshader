// Underglow neon tubes (TmUnderglow): a glass tube with lit gas inside. The gas's colour at the
// tube's edges, a white-hot core where the tube faces the eye, HDR emission (the environment's
// glow blooms it). UV.x: the place along the car (tm_glow.gdshaderinc).
shader_type spatial;
render_mode cull_back, shadows_disabled;

#include "res://car/tm_glow.gdshaderinc"

uniform float energy = 6.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 col = gas(UV.x);
	vec3 core = mix(col, vec3(max(col.r, max(col.g, col.b))), 0.7);
	ALBEDO = vec3(0.02);
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	EMISSION = mix(col, core, pow(facing, 4.0)) * energy * (0.45 + 0.55 * facing);
}
