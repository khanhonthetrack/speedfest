// The map's sky occlusion (env/tm_occlusion.gd, TM's "Compute Shadows" done our way): a top-down
// map of the highest collision surface over the field, baked when a map loads. A point is under
// cover where that surface is well above it; sampled around the point (pushed off its surface) at
// two radii, so the shade fades out softly past the edge of a bridge, a roof or an arch. Used as
// AO (ambient and reflections only; the sun has its own shadows).
global uniform sampler2D tm_occl_tex : filter_linear, repeat_disable;
global uniform vec4 tm_occl_rect;   // x0, z0 (Godot world), 1 / width, 1 / depth
global uniform float tm_occl_on;

float tm_cover(vec2 xz, float y) {
	vec2 uv = (xz - tm_occl_rect.xy) * tm_occl_rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return smoothstep(0.6, 4.0, texture(tm_occl_tex, uv).r - y);
}

float tm_sky_visibility(vec3 p, vec3 n) {
	if (tm_occl_on < 0.5) {
		return 1.0;
	}
	vec3 q = p + n * 0.75;
	float c = 2.0 * tm_cover(q.xz, q.y);
	for (int i = 0; i < 6; i++) {
		float a = float(i) * 1.0471976;
		c += tm_cover(q.xz + vec2(cos(a), sin(a)) * 3.0, q.y);
		c += tm_cover(q.xz + vec2(cos(a + 0.5236), sin(a + 0.5236)) * 8.0, q.y);
	}
	return 1.0 - 0.72 * (c / 14.0);
}
