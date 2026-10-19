shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Additive fake-light effects: light pools on the ground (mode 0, radial on UV) and
// volumetric beams/cones (mode 1, UV.y = 0 at the source .. 1 at the far end).
// Color from vertex/instance COLOR, alpha scales intensity.

uniform int mode = 0;
uniform float energy = 1.0;
uniform float falloff = 2.0;
uniform float fade_distance = 600.0;
uniform float near_fade = 6.0;

void fragment() {
	float a;
	if (mode == 0) {
		float r = length(UV * 2.0 - 1.0);
		a = pow(clamp(1.0 - r, 0.0, 1.0), falloff);
	} else {
		float along = clamp(UV.y, 0.0, 1.0);
		float fres = abs(dot(normalize(NORMAL), normalize(VIEW)));
		a = pow(1.0 - along, falloff) * fres * fres;
	}
	float dist = length(VERTEX);
	a *= clamp(1.0 - dist / fade_distance, 0.0, 1.0) * clamp(dist / near_fade, 0.0, 1.0);
	ALBEDO = COLOR.rgb * COLOR.a * energy * a;
}
