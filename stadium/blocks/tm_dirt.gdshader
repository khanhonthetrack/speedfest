shader_type spatial;
#include "res://env/tm_occlusion.gdshaderinc"
// Dirt roads (blocks/shapes/dirt.gd, TmMaterials "dirt_road"): where the ground is level, the packed
// track combed by tyres along the piece (the mesh UVs are TmGeo's planar ones, block-local metres
// / 8, so its streaks run along the block's z: the road); on the berms and slopes the loose dirt.
// The two blend by the slope, broken up by the macro noise so the edge isn't a contour line.

uniform sampler2D road_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D loose_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D loose_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D loose_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 road_metres = vec2(16.0, 16.0);    // one road texture: across (block x), along (z)
uniform float loose_metres = 8.0;
uniform float level_lo = 0.90;                  // world normal's y: loose below, packed above hi
uniform float level_hi = 0.975;
uniform sampler2D macro_tex : filter_linear_mipmap, repeat_enable;
uniform float macro = 0.12;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec2 m = UV * 8.0;
	vec2 ru = m / road_metres;
	vec2 lu = m / loose_metres;
	float brk = texture(macro_tex, wpos.xz / 23.0).r;
	float t = smoothstep(level_lo, level_hi, n.y + (brk - 0.5) * 0.06);
	vec3 alb = mix(texture(loose_albedo, lu).rgb, texture(road_albedo, ru).rgb, t);
	vec3 orm = mix(texture(loose_orm, lu).rgb, texture(road_orm, ru).rgb, t);
	NORMAL_MAP = mix(texture(loose_normal, lu).rgb, texture(road_normal, ru).rgb, t);
	float mm = texture(macro_tex, wpos.xz / 173.0).r * 0.65 + texture(macro_tex, wpos.xz / 41.0).r * 0.35;
	ALBEDO = alb * (1.0 + macro * (mm * 2.0 - 1.0));
	ROUGHNESS = orm.g;
	METALLIC = 0.0;
	AO = orm.r * tm_sky_visibility(wpos, n);
	AO_LIGHT_AFFECT = 0.0;
}
