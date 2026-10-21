shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// A street tree's leaves (TmTrees): cards each showing a photographed frond (Poly Haven's
// jacaranda, CC0: its colour and alpha), the crown lit as a volume (the cards' normals point out
// from the crown's middle), light through the leaves from behind, a sway in the wind; each tree
// its own green (the instance data).

uniform sampler2D leaves : source_color, filter_linear_mipmap_anisotropic, repeat_disable;

varying vec3 tint;

void vertex() {
	tint = INSTANCE_CUSTOM.rgb;
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = sin(TIME * 1.3 + w.x * 0.21 + w.z * 0.17) * 0.06 + sin(TIME * 3.1 + VERTEX.y * 2.0 + VERTEX.x) * 0.025;
	VERTEX.x += s * max(VERTEX.y - 2.5, 0.0) * 0.15;
	VERTEX.z += s * 0.5 * max(VERTEX.y - 2.5, 0.0) * 0.1;
}

void fragment() {
	vec4 c = texture(leaves, UV);
	vec3 t = tint.r > 0.0 ? tint * 1.75 : vec3(1.0);
	ALBEDO = c.rgb * t;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	BACKLIGHT = c.rgb * t * 0.55;
}
