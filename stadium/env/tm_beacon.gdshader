shader_type spatial;
render_mode unshaded, cull_back;
// An aviation obstruction light (TmTower): red, a short flash every two seconds, each lamp at its
// own moment (from where it stands, so all lamps share one material).

void fragment() {
	float phase = fract(NODE_POSITION_WORLD.x * 0.0137 + NODE_POSITION_WORLD.z * 0.0071);
	float on = step(fract(TIME * 0.5 + phase), 0.12);
	ALBEDO = vec3(0.35, 0.02, 0.02) + vec3(1.0, 0.06, 0.04) * on * 6.0;
}
