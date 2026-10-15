class_name SceneryInstances
extends RefCounted
## Collects instances of one mesh and builds chunked MultiMeshInstance3D nodes, so the
## renderer can frustum-cull and distance-cull (visibility range) per chunk.
## Per-instance color (COLOR in shaders) and custom data (INSTANCE_CUSTOM) are optional.

var mesh: Mesh
var material: Material
var chunk_size: float = 256.0
var use_colors: bool = false
var use_custom: bool = false
var _groups: Dictionary = {}   # Vector2i -> [Array[Transform3D], PackedColorArray, PackedColorArray]
var count: int = 0


func _init(p_mesh: Mesh, p_material: Material, p_chunk: float = 256.0, colors := false, custom := false) -> void:
	mesh = p_mesh
	material = p_material
	chunk_size = p_chunk
	use_colors = colors
	use_custom = custom


func add(xf: Transform3D, col := Color.WHITE, custom := Color(0, 0, 0, 0)) -> void:
	var key := Vector2i(floori(xf.origin.x / chunk_size), floori(xf.origin.z / chunk_size))
	if not _groups.has(key):
		_groups[key] = [[], PackedColorArray(), PackedColorArray()]
	var g: Array = _groups[key]
	(g[0] as Array).append(xf)
	g[1].append(col)
	g[2].append(custom)
	count += 1


## Create the MultiMeshInstance3D chunks under `parent`. Returns the number of nodes created.
func build(parent: Node3D, base_name: String, vis_end: float = 0.0, cast_shadows := true) -> int:
	var made := 0
	for key in _groups:
		var g: Array = _groups[key]
		var xfs: Array = g[0]
		var cols: PackedColorArray = g[1]
		var cus: PackedColorArray = g[2]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = use_colors
		mm.use_custom_data = use_custom
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		# Node sits at the chunk centre so visibility ranges measure from the chunk.
		var center := Vector3((key.x + 0.5) * chunk_size, 0.0, (key.y + 0.5) * chunk_size)
		for i in xfs.size():
			var xf: Transform3D = xfs[i]
			mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - center))
			if use_colors:
				mm.set_instance_color(i, cols[i])
			if use_custom:
				mm.set_instance_custom_data(i, cus[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [base_name, key.x, key.y]
		mmi.multimesh = mm
		mmi.position = center
		if material != null:
			mmi.material_override = material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if vis_end > 0.0:
			mmi.visibility_range_end = vis_end + chunk_size * 0.7
		parent.add_child(mmi)
		made += 1
	return made
