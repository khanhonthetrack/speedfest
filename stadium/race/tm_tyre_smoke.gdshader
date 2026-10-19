shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;
// The tyre smoke's puffs (race/tm_tyre_marks.gd, a CPUParticles3D per wheel): camera-facing quads,
// their colour the wheel's surface's (`tint`) and only their opacity from the particle (its colour
// ramp's fade), so a puff can fade but never draw darker than its tint.

uniform sampler2D puff_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.78, 0.78, 0.79, 0.3);

void vertex() {
	// as BaseMaterial3D's particle billboard: face the camera, keep the particle's size and spin
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	world = world * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0),
		vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 t = texture(puff_tex, UV);
	ALBEDO = tint.rgb * t.rgb;
	ALPHA = clamp(t.a * tint.a * COLOR.a, 0.0, 1.0);
}
