shader_type spatial;
render_mode unshaded, cull_back;
// An aviation obstruction light (TmTower): red, a short flash every two seconds (a steady glow
// between them at night), each lamp at its
// own moment (from where it stands, so all lamps share one material). Far off it grows so that it
// stays a few pixels wide (as a real one does to the eye); at night it is brighter.

global uniform float tm_night;

void vertex() {
	VERTEX *= max(1.0, length(NODE_POSITION_VIEW) * 0.0022);
}

void fragment() {
	float phase = fract(NODE_POSITION_WORLD.x * 0.0137 + NODE_POSITION_WORLD.z * 0.0071);
	float on = step(fract(TIME * 0.5 + phase), 0.12);
	// at night a steady red glow between the flashes (an obstruction light seen across a city)
	ALBEDO = vec3(0.35, 0.02, 0.02) + vec3(1.0, 0.06, 0.04) * (on * mix(6.0, 14.0, tm_night) + 2.5 * tm_night);
}
