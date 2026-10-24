@tool
extends EditorScenePostImport
## The cast's import (PLAN M20-9): MPFB exports every material as alpha-blended with its textures;
## this gives each the material its role wants (the role is the material's name before "__", set by
## tools/cast/blender/gen_char.py; the tint comes from the sidecar <id>.cast.json):
## skin -- opaque, subsurface scattering in skin mode; cloth -- opaque, rough, both sides (the body
## under it is cut away: gen_char.py's cover mask; a cuff or a hood shows its inside); hair, brows, lashes --
## alpha blended over a depth pre-pass, both sides (the spike, 24 Oct: alpha-to-coverage left the
## hairline a hard edge and the card brows stippled; plain blending sorted the hair's cards wrong;
## the pre-pass keeps the textures' feathered hairline and is right under DLSS and path tracing,
## which break alpha-to-coverage); eyes -- the cornea's see-through texels cut, a wet highlight;
## teeth, tongue -- opaque, a little shine; hivis (a bespoke vest, gen_char.py) -- cloth with a faint
## fluorescent glow, so it reads in the dark.
## Thin parts (brows, lashes) cast no shadow.

const ALPHA_ROLES := ["hair", "brow", "lash"]


func _post_import(scene: Node) -> Object:
	var meta := {}
	var side := get_source_file().get_basename() + ".cast.json"
	if FileAccess.file_exists(side):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(side))
		meta = d if d is Dictionary else {}
	var mats: Dictionary = meta.get("materials", {})
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if src == null:
				continue
			var name := src.resource_name
			var role := name.get_slice("__", 0) if name.contains("__") else "cloth"
			var tint := Color(String((mats.get(name, {}) as Dictionary).get("tint", "#ffffff")))
			mi.mesh.surface_set_material(i, material(role, src, tint))
		if mi.name.begins_with("brow__") or mi.name.begins_with("lash__"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return scene


static func material(role: String, src: BaseMaterial3D, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = src.resource_name
	m.albedo_texture = src.albedo_texture
	m.albedo_color = Color(src.albedo_color.r, src.albedo_color.g, src.albedo_color.b) * tint
	if src.normal_enabled and src.normal_texture != null:
		m.normal_enabled = true
		m.normal_texture = src.normal_texture
		m.normal_scale = 1.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	match role:
		"skin":
			m.roughness = 0.52
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.35
			m.subsurf_scatter_skin_mode = true
		"hair", "brow", "lash":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.55
			m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		"eye":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.roughness = 0.08
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
			m.clearcoat_roughness = 0.02
		"teeth", "tongue":
			m.roughness = 0.35
		"hivis":
			m.roughness = 0.7
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.emission_enabled = true
			m.emission = Color.WHITE
			m.emission_texture = src.albedo_texture
			m.emission_energy_multiplier = 0.05
		_:
			m.roughness = 0.85
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
