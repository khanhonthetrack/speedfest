shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Traffic far below the Sky maps' road (M19, TmSkyCity): streams of headlights one way and tail
// lights the other along a street, on a strip just over the paving. UV: x across the strip (its
// two halves the two directions), y metres along it; UV2.x a per-street seed.

uniform float speed = 15.0;          // m/s
uniform float spacing = 9.0;         // m: a car's slot
uniform float energy = 3.0;
global uniform float tm_neon;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	float lane = step(0.5, UV.x);
	float x = fract(UV.x * 2.0);
	float dir = lane > 0.5 ? -1.0 : 1.0;
	float v = UV.y - dir * TIME * speed * (0.85 + 0.3 * hash(UV2.x * 7.0 + lane)) + UV2.x * 1000.0;
	float slot = floor(v / spacing);
	float f = fract(v / spacing);
	float car = step(hash(slot + lane * 17.0 + UV2.x * 3.1), 0.5);
	float blob = smoothstep(0.0, 0.1, f) * (1.0 - smoothstep(0.2, 0.3, f));
	float across = smoothstep(0.12, 0.3, x) * (1.0 - smoothstep(0.7, 0.88, x));
	vec3 c = mix(vec3(1.0, 0.9, 0.72), vec3(1.0, 0.1, 0.05), lane);
	ALBEDO = c * car * blob * across * energy * max(tm_neon, 0.15);
}
