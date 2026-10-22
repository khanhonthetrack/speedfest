// Underglow halos (TmUnderglow): the light a neon tube spreads in the air round it, a ribbon along
// the tube turned to face the eye about the tube's axis, added to what is behind it, soft where it
// meets the road or the car (the depth there) and at the tube's ends. The mesh: VERTEX on the tube's
// axis, NORMAL the axis's direction, UV (-1..1 across, t along the car), UV2.x 0 at the ends.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://car/tm_glow.gdshaderinc"

uniform float width = 0.08;
uniform float strength = 1.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

void vertex() {
	vec3 p = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 axis = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	vec3 side = cross(axis, normalize(p));
	float l = length(side);
	side = l > 1e-4 ? side / l : vec3(0.0, 1.0, 0.0);
	VERTEX = p + side * UV.x * width;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float d = abs(UV.x);
	float g = exp(-d * d * 5.0) * (1.0 - d) * smoothstep(0.0, 1.0, UV2.x);
	float z = textureLod(depth_tex, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z * 2.0 - 1.0, 1.0);
#else
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
#endif
	float soft = clamp((-v.z / v.w + VERTEX.z) / 0.04, 0.0, 1.0);
	ALBEDO = gas(UV.y) * strength;
	ALPHA = g * soft;
}
