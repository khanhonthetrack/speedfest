class_name TmRefVisuals
extends RefCounted
## Research aid, off unless a scene is started with --ref=<dir>: blocks are drawn with TMNF's own
## visual meshes and textures, read from local files that tools/research/tmnf/ref_visuals.py
## writes from the player's install (never committed). Collision stays ours. Used to compare our
## look with the original at the same camera (map_view, race). <dir>/vis/<Shape>.json,
## <dir>/materials.json, <dir>/tex/<Texture>.png.

static var _dir := ""
static var _checked := false
static var _mats := {}            ## material name -> {"D": texture name, "N": .., "S": ..}
static var _mat_cache := {}       ## material name -> Material
static var _tex_cache := {}       ## texture name -> Texture2D (or null)


static func active() -> bool:
	if not _checked:
		_checked = true
		_dir = String(TestHooks.arg("ref", ""))
		if not _dir.is_empty():
			var f := FileAccess.open(_dir.path_join("materials.json"), FileAccess.READ)
			if f != null:
				_mats = JSON.parse_string(f.get_as_text())
			else:
				push_warning("ref: no materials.json in %s" % _dir)
	return not _dir.is_empty()


## The original's visual meshes for a shape (catalogue name, e.g. "Road/Main/StraightAir") as one
## MeshInstance3D in our block-local space (x negated), or null when there is no file for it.
static func visual(shape: String) -> MeshInstance3D:
	var path := _dir.path_join("vis").path_join(shape.replace("/", "__") + ".json")
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	return mesh_from(data.get("meshes", []))


## flip_x: blocks are authored in TMNF's block space (Godot = x negated); the car's visual space
## is already Godot's (nose +z, left +x).
static func mesh_from(meshes: Array, flip_x := true) -> MeshInstance3D:
	var fx := -1.0 if flip_x else 1.0
	# one surface per material (a mesh holds at most 256 surfaces; the surround has 400 parts)
	var tools := {}
	for m: Dictionary in meshes:
		var verts: Array = m["verts"]
		var tris: Array = m["tris"]
		var uvs: Array = m.get("uvs", [])
		var key := String(m.get("mat", ""))
		if not tools.has(key):
			var st0 := SurfaceTool.new()
			st0.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = st0
		var st: SurfaceTool = tools[key]
		for t: Array in tris:
			var ok := true
			for k in 3:
				if int(t[k]) >= verts.size():
					ok = false
			if not ok:
				continue
			for k in ([0, 2, 1] if flip_x else [0, 1, 2]):   # x negated: reverse the winding
				var i := int(t[k])
				if uvs.size() > 0 and i < (uvs[0] as Array).size():
					var uv: Array = uvs[0][i]
					st.set_uv(Vector2(float(uv[0]), 1.0 - float(uv[1])))   # TMNF's v runs up
				var p: Array = verts[i]
				st.add_vertex(Vector3(fx * float(p[0]), float(p[1]), float(p[2])))
	var am := ArrayMesh.new()
	for key: String in tools:
		var st: SurfaceTool = tools[key]
		st.generate_normals()
		var arrays := st.commit_to_arrays()
		if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.surface_set_material(am.get_surface_count() - 1, material(key))
	if am.get_surface_count() == 0:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "RefMesh"
	mi.mesh = am
	return mi


static func material(name: String) -> Material:
	if _mat_cache.has(name):
		return _mat_cache[name]
	var m := StandardMaterial3D.new()
	var roles: Dictionary = _mats.get(name, {})
	var d := _tex(String(roles.get("D", name)))
	if d != null:
		m.albedo_texture = d
		# alpha-cut materials (TMNF's names; its StructureGeneric girders are lattice cards too)
		if name.contains("Alpha") or name.contains("Glass") or name.contains("Fan") or name.contains("StructureGeneric"):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
	else:
		m.albedo_color = Color(1, 0, 1)
	var n := _tex(String(roles.get("N", "")), true)
	if n != null:
		m.normal_enabled = true
		m.normal_texture = n
	m.roughness = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_cache[name] = m
	return m


## normal: the file is a normal map in TMNF's layout (x in alpha, red empty, y in green): moved
## into red, so Godot reads the normals as authored (else they all lean along -x).
static func _tex(name: String, normal := false) -> Texture2D:
	if name.is_empty():
		return null
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path := _dir.path_join("tex").path_join(name + ".png")
	if not FileAccess.file_exists(path):
		path = _dir.path_join("tex").path_join(name + "D.png")
	if not FileAccess.file_exists(path):
		_tex_cache[name] = null
		return null
	var img := Image.load_from_file(path)
	var t: Texture2D = null
	if img != null and not img.is_empty():
		if normal and img.detect_alpha() != Image.ALPHA_NONE:
			img.convert(Image.FORMAT_RGBA8)
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(c.a, c.g, c.b, 1.0))
		img.generate_mipmaps()
		t = ImageTexture.create_from_image(img)
	_tex_cache[name] = t
	return t
