shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;
// Tyre marks (race/tm_tyre_marks.gd): one quad per segment of a mark, a MultiMesh instance each.
// INSTANCE_CUSTOM: x, y the metres along the mark at the segment's start and end (the texture runs
// on without seams), z its strength, w its serial number (the oldest fade out before they go).

uniform sampler2D mark_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_m = 1.0;          // metres along the mark one texture covers
uniform float roughness = 0.8;
uniform float newest = 0.0;          // the serial of the newest segment
uniform float capacity = 2048.0;     // segments kept

varying vec2 along;
varying float strength;

void vertex() {
	along = vec2(mix(INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.y, UV.y) / tile_m, 0.0);
	float age = newest - INSTANCE_CUSTOM.w;
	strength = INSTANCE_CUSTOM.z * (1.0 - smoothstep(capacity * 0.75, capacity, age));
}

void fragment() {
	vec4 t = texture(mark_tex, vec2(UV.x, along.x));
	ALBEDO = t.rgb;
	ALPHA = t.a * strength;
	ROUGHNESS = roughness;
}
