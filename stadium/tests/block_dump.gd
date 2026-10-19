extends Node
## Research tool (not in the gate): every block shape we build, as triangles with their material
## keys, in TMNF block-local coordinates (x right; ours is x negated), for
## tools/research/tmnf/material_check.py (ours against TMNF's own meshes, kept locally).
## Run: stadium/tools/run.sh res://tests/block_dump.tscn --headless --timeout 1200 -- \
##        --shapes=<file: one shape per line, "/" or "__"> --out=<dir>
## Writes <dir>/blocks.bin (per triangle: int32 key index, 9 float32), <dir>/blocks.json (per
## shape: name, first triangle, count, its keys) and <dir>/colours.json (key: mean albedo, sRGB 0..1).

var _keys := {}          ## Material -> key (TmMaterials' cache, inverted)
var _colours := {}       ## key -> [r, g, b]


func _ready() -> void:
	var lib := TmBlockLib.new()
	var dir := String(TestHooks.arg("out", ""))
	DirAccess.make_dir_recursive_absolute(dir)
	var bin := FileAccess.open(dir.path_join("blocks.bin"), FileAccess.WRITE)
	var index := []
	var tri := 0
	for line in FileAccess.get_file_as_string(String(TestHooks.arg("shapes", ""))).split("\n", false):
		var shape := line.strip_edges().replace("__", "/")
		if not lib.handles(shape):
			continue
		var node: Node3D = lib.make(shape, {}, shape.contains("Ground"))
		if node == null:
			continue
		_refresh_keys()
		var keys: Array[String] = []
		var count := 0
		for mi in node.find_children("*", "GeometryInstance3D", true, false):
			var xf := _relative(mi as Node3D, node)
			var meshes := []
			if mi is MeshInstance3D and (mi as MeshInstance3D).mesh:
				meshes.append([(mi as MeshInstance3D).mesh, [xf], (mi as MeshInstance3D).material_override])
			elif mi is MultiMeshInstance3D and (mi as MultiMeshInstance3D).multimesh:
				var mm := (mi as MultiMeshInstance3D).multimesh
				var xfs := []
				for i in mm.instance_count:
					xfs.append(xf * mm.get_instance_transform(i))
				meshes.append([mm.mesh, xfs, (mi as MultiMeshInstance3D).material_override])
			for entry: Array in meshes:
				var mesh: Mesh = entry[0]
				if mesh == null:
					continue
				for si in mesh.get_surface_count():
					var mat: Material = entry[2] if entry[2] != null else mesh.surface_get_material(si)
					var key := _key_of(mat)
					var ki := keys.find(key)
					if ki < 0:
						keys.append(key)
						ki = keys.size() - 1
					var arr := mesh.surface_get_arrays(si)
					var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					var idx := PackedInt32Array()
					if arr[Mesh.ARRAY_INDEX] != null:
						idx = arr[Mesh.ARRAY_INDEX]
					var n := idx.size() if idx.size() > 0 else v.size()
					for x: Transform3D in entry[1]:
						for t in range(0, n, 3):
							bin.store_32(ki)
							for j in 3:
								var p := x * v[idx[t + j] if idx.size() > 0 else t + j]
								bin.store_float(-p.x)
								bin.store_float(p.y)
								bin.store_float(p.z)
							count += 1
		index.append({"shape": shape, "first": tri, "count": count, "keys": keys})
		tri += count
		node.free()
	bin.close()
	var f := FileAccess.open(dir.path_join("blocks.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(index))
	f.close()
	f = FileAccess.open(dir.path_join("colours.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_colours))
	f.close()
	print("BLOCK_DUMP %d shapes, %d triangles" % [index.size(), tri])
	TestHooks.finish()


func _relative(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _refresh_keys() -> void:
	for k: String in TmMaterials._cache:
		_keys[TmMaterials._cache[k]] = k


## A material's key (TmMaterials) or, for one made elsewhere, its class and resource name.
func _key_of(mat: Material) -> String:
	if mat == null:
		return "<none>"
	var key: String = _keys.get(mat, "")
	if key.is_empty():
		key = "<%s:%s>" % [mat.get_class(), mat.resource_name]
	if not _colours.has(key):
		var c := _albedo(mat)
		_colours[key] = [c.r, c.g, c.b]
	return key


## The mean albedo a material shows (sRGB): its colour times its albedo texture's mean.
func _albedo(mat: Material) -> Color:
	var c := Color(1, 1, 1)
	var tex: Texture2D = null
	if mat is StandardMaterial3D:
		c = (mat as StandardMaterial3D).albedo_color
		tex = (mat as StandardMaterial3D).albedo_texture
	elif mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		var a: Variant = sm.get_shader_parameter("albedo")
		if a is Color:
			c = a
		elif a is Vector3:
			c = Color(a.x, a.y, a.z)
		var t: Variant = sm.get_shader_parameter("tint")
		if t is Color:
			c = Color(c.r * t.r, c.g * t.g, c.b * t.b)
		elif t is Vector3:
			c = Color(c.r * t.x, c.g * t.y, c.b * t.z)
		for param in ["albedo_tex", "road_albedo"]:      # (dirt roads: the packed track's)
			var at: Variant = sm.get_shader_parameter(param)
			if at is Texture2D:
				tex = at
				break
	if tex != null:
		var img := tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			while img.get_width() > 1 or img.get_height() > 1:     # halvings: a true mean
				img.resize(maxi(1, img.get_width() / 2), maxi(1, img.get_height() / 2), Image.INTERPOLATE_BILINEAR)
			var m := img.get_pixel(0, 0)
			c = Color(c.r * m.r, c.g * m.g, c.b * m.b)
	return c
