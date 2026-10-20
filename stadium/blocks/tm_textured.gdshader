shader_type spatial;
#include "res://env/tm_occlusion.gdshaderinc"
// The textured surfaces (TmMaterials.TEXTURED, the gate paint): our own albedo / normal / ORM maps
// from assets/tex (and an emission map where there is one), on the mesh's UVs scaled to metres, or
// projected in world space on three planes (surfaces without a direction: concrete, facades), with
// the map's sky occlusion as ambient occlusion. What ORMMaterial3D did, plus the occlusion, and an
// optional detail map (TmMaterials.DETAIL: the decks' fine tread) tiled finely over the same mapping.
// A texture mod's maps (TmMaterials.MOD_MAP) come as atlases: `atlas` is the region of the image a
// surface repeats (TMNF's textures hold several parts), `spec_map` reads orm_tex as TMNF's specular
// map (roughness from its brightness).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D emission_tex : source_color, hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_emission = false;
uniform vec3 emission_colour : source_color = vec3(1.0, 0.97, 0.9);
uniform float emission_energy = 6.0;
uniform vec2 uv_scale = vec2(1.0);
uniform bool world = false;
uniform float world_scale = 0.0625;     // 1 / metres per texture
uniform vec2 world_aspect = vec2(1.0);  // the texture's v metres against its u (atlas regions aren't square)
uniform vec4 atlas = vec4(0.0, 0.0, 1.0, 1.0);   // x, y, width, height of the repeated region
// world mapping in the block's own frame (TMNF's road textures run along the block's z), and with
// u and v swapped (u along z)
uniform bool local_map = false;
uniform bool swap_uv = false;
uniform bool spec_map = false;
uniform float sharpness = 8.0;
uniform float metallic = 0.0;          // times the ORM map's blue, as ORMMaterial3D (default 0)
uniform float roughness = 1.0;         // times its green
uniform vec3 tint : source_color = vec3(1.0);   // times the albedo (one set, light and dark walls)
// large-scale variation over the tiles (world xz), so a 16 m texture doesn't read as a grid far off
uniform sampler2D macro_tex : filter_linear_mipmap, repeat_enable;
uniform float macro = 0.0;
uniform float translucent = 0.0;       // fabric: tm_membrane_glow
// detail: red/green its normal's x/y, blue an albedo factor (0.5 = 1); detail_ratio textures per
// main texture, detail_strength scales it
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_detail = false;
uniform float detail_ratio = 64.0;
uniform float detail_strength = 1.0;

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 mpos;     // where the world mapping reads (world, or the block's frame)
varying vec3 mnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	mpos = local_map ? VERTEX : wpos;
	mnrm = local_map ? NORMAL : wnrm;
}

// a texture at uv, repeating the atlas region (gradients from the unwrapped uv: no mip seam where
// the region wraps)
vec4 tex_at(sampler2D t, vec2 uv) {
	vec2 g = uv * atlas.zw;
	return textureGrad(t, atlas.xy + fract(uv) * atlas.zw, dFdx(g), dFdy(g));
}

vec3 unpack_normal(vec4 t) {
	return vec3(t.xy * 2.0 - 1.0, 0.0) + vec3(0.0, 0.0, sqrt(max(0.0, 1.0 - dot(t.xy * 2.0 - 1.0, t.xy * 2.0 - 1.0))));
}

// a tangent-space normal with the detail map's at uv whiteout-blended in; alb_k: its albedo factor
vec3 with_detail(vec3 tn, vec2 uv, inout float alb_k) {
	vec4 d = texture(detail_tex, uv * detail_ratio);
	vec2 dxy = (d.xy * 2.0 - 1.0) * detail_strength;
	alb_k = mix(1.0, d.z * 2.0, detail_strength);
	return normalize(vec3(tn.xy + dxy, tn.z));
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 alb;
	vec3 orm;
	vec3 em = vec3(0.0);
	if (world) {
		vec3 w = pow(abs(local_map ? normalize(mnrm) : n), vec3(sharpness));
		w /= (w.x + w.y + w.z);
		// ORMMaterial3D's world triplanar mapping: y flipped, then each plane's own flips
		vec3 p = mpos * world_scale * vec3(1.0, -1.0, 1.0);
		vec2 ux = p.zy * vec2(-1.0, 1.0);
		vec2 uy = p.xz * vec2(1.0, -1.0);
		vec2 uz = p.xy;
		if (swap_uv) {
			ux = ux.yx;
			uy = uy.yx;
			uz = uz.yx;
		}
		ux *= world_aspect;
		uy *= world_aspect;
		uz *= world_aspect;
		alb = tex_at(albedo_tex, ux).rgb * w.x + tex_at(albedo_tex, uy).rgb * w.y + tex_at(albedo_tex, uz).rgb * w.z;
		orm = tex_at(orm_tex, ux).rgb * w.x + tex_at(orm_tex, uy).rgb * w.y + tex_at(orm_tex, uz).rgb * w.z;
		// tangent-space normals per plane, whiteout-blended into the surface normal (world space)
		// (the planes' uv axes against world (z, y), (x, z), (x, y): flipped as the mapping above)
		vec3 nx = unpack_normal(tex_at(normal_tex, ux));
		vec3 ny = unpack_normal(tex_at(normal_tex, uy));
		vec3 nz = unpack_normal(tex_at(normal_tex, uz));
		if (has_detail) {
			float kx = 1.0;
			float ky = 1.0;
			float kz = 1.0;
			nx = with_detail(nx, ux, kx);
			ny = with_detail(ny, uy, ky);
			nz = with_detail(nz, uz, kz);
			alb *= kx * w.x + ky * w.y + kz * w.z;
		}
		vec3 tx = nx * vec3(-1.0, -1.0, 1.0);
		vec3 ty = ny * vec3(1.0, -1.0, 1.0);
		vec3 tz = nz * vec3(1.0, -1.0, 1.0);
		tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
		ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
		tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
		vec3 wn = normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
		if (has_emission) {
			em = texture(emission_tex, uy).rgb * w.y + texture(emission_tex, ux).rgb * w.x + texture(emission_tex, uz).rgb * w.z;
		}
	} else {
		vec2 uv = UV * uv_scale;
		alb = tex_at(albedo_tex, uv).rgb;
		orm = tex_at(orm_tex, uv).rgb;
		NORMAL_MAP = tex_at(normal_tex, uv).rgb;
		if (has_detail) {
			float k = 1.0;
			NORMAL_MAP = with_detail(unpack_normal(vec4(NORMAL_MAP, 1.0)), uv, k) * 0.5 + 0.5;
			alb *= k;
		}
		if (has_emission) {
			em = texture(emission_tex, uv).rgb;
		}
	}
	if (macro > 0.0) {
		float m = texture(macro_tex, wpos.xz / 173.0).r * 0.65 + texture(macro_tex, wpos.xz / 41.0).r * 0.35;
		alb *= 1.0 + macro * (m * 2.0 - 1.0);
	}
	if (spec_map) {
		orm = vec3(1.0, clamp(1.05 - dot(orm, vec3(0.333)) * 1.1, 0.3, 1.0), 0.0);
	}
	ALBEDO = alb * tint;
	ROUGHNESS = orm.g * roughness;
	METALLIC = orm.b * metallic;
	// ORMMaterial3D's emission: (colour + map) * energy ("add")
	EMISSION = (has_emission ? (emission_colour + em) * emission_energy : vec3(0.0)) + tm_membrane_glow(ALBEDO, n, translucent);
	AO = orm.r * tm_sky_visibility(wpos, n);
	AO_LIGHT_AFFECT = 0.0;
}
