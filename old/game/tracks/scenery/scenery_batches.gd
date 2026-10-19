class_name SceneryBatches
extends RefCounted
## Merged static geometry per (material key, chunk). Kits register materials by key, append
## geometry with `at(key, position)`, and `build()` creates one MeshInstance3D per non-empty
## chunk and material (few draw calls, but still frustum- and distance-culled per chunk).

var chunk_size: float = 300.0
var _mats: Dictionary = {}        # key -> Material
var _vis: Dictionary = {}         # key -> visibility end (0 = none)
var _shadow: Dictionary = {}      # key -> bool
var _meshes: Dictionary = {}      # key -> {Vector2i: SceneryMesh}
var _text_cache: Dictionary = {}


func _init(p_chunk := 300.0) -> void:
	chunk_size = p_chunk


func register(key: String, mat: Material, vis_end := 0.0, cast_shadows := true) -> void:
	_mats[key] = mat
	_vis[key] = vis_end
	_shadow[key] = cast_shadows
	if not _meshes.has(key):
		_meshes[key] = {}


func at(key: String, p: Vector3) -> SceneryMesh:
	var ck := Vector2i(floori(p.x / chunk_size), floori(p.z / chunk_size))
	var d: Dictionary = _meshes[key]
	if not d.has(ck):
		d[ck] = SceneryMesh.new()
	return d[ck]


func tri_count() -> int:
	var t := 0
	for key in _meshes:
		for ck in _meshes[key]:
			t += (_meshes[key][ck] as SceneryMesh).tri_count()
	return t


func build(parent: Node3D) -> int:
	var made := 0
	for key in _meshes:
		var d: Dictionary = _meshes[key]
		for ck in d:
			var m: SceneryMesh = d[ck]
			if m.is_empty():
				continue
			# re-centre on the chunk so visibility ranges measure from it
			var center := Vector3((ck.x + 0.5) * chunk_size, 0.0, (ck.y + 0.5) * chunk_size)
			for i in m.v.size():
				m.v[i] -= center
			var mi := m.to_instance(_mats[key], "%s_%d_%d" % [key, ck.x, ck.y], _shadow[key])
			mi.position = center
			var ve: float = _vis[key]
			if ve > 0.0:
				mi.visibility_range_end = ve + chunk_size * 0.7
			parent.add_child(mi)
			made += 1
	return made


## Flat text mesh arrays (in the XY plane, facing +Z, centred, 1 unit = 1 m tall letters).
func text_arrays(text: String, bold := true) -> Array:
	var key := "%s|%s" % [text, bold]
	if _text_cache.has(key):
		return _text_cache[key]
	# Rajdhani Bold triangulates cleanly except "Z"; Orbitron 500 fails on 0/4/8/9/A but not Z.
	var font_path := "res://assets/fonts/rajdhani-latin-700-normal.woff2"
	if text.contains("Z"):
		font_path = "res://assets/fonts/orbitron-latin-500-normal.woff2"
		for bad in ["0", "4", "8", "9", "A"]:
			if text.contains(bad):
				text = text.replace("Z", "2")
				font_path = "res://assets/fonts/rajdhani-latin-700-normal.woff2"
				break
	var font: Font = load(font_path)
	var tm := TextMesh.new()
	tm.font = font
	tm.text = text
	tm.font_size = 32
	tm.pixel_size = 1.0 / 24.0
	tm.depth = 0.0
	tm.curve_step = 2.0
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var arr := tm.get_mesh_arrays()
	_text_cache[key] = arr
	return arr


## Size (width, height) of text_arrays() output.
static func arrays_size(arr: Array) -> Vector2:
	var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	if pv.is_empty():
		return Vector2.ZERO
	var mn := pv[0]
	var mx := pv[0]
	for p in pv:
		mn = mn.min(p)
		mx = mx.max(p)
	return Vector2(mx.x - mn.x, mx.y - mn.y)
