shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A searchlight's beam in the night sky (TmSearchlights): an open cone, brightest at its foot and
// along its axis (the faces seen edge-on fade), fading out towards its tip. UV.y: 0 at the lamp,
// 1 at the tip.

uniform vec3 colour : source_color = vec3(0.72, 0.82, 1.0);
uniform float strength = 0.16;

void fragment() {
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 2.4);
	float fade = pow(1.0 - UV.y, 1.8) * smoothstep(0.0, 0.02, UV.y);
	ALBEDO = colour * strength;
	ALPHA = edge * fade;
}
