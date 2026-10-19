class_name SceneryMesh
extends RefCounted
## Collects triangles (position, normal, color, uv, uv2) and commits them as one ArrayMesh
## surface. Used to merge static scenery per material (one draw call per chunk).
## Winding: Godot front faces are clockwise as seen from the front. `add_quad(a, b, c, d)` takes
## the corners bottom-left, top-left, top-right, bottom-right as seen from the front.

var v := PackedVector3Array()
var n := PackedVector3Array()
var c := PackedColorArray()
var uv := PackedVector2Array()
var uv2 := PackedVector2Array()
var idx := PackedInt32Array()


func is_empty() -> bool:
	return idx.is_empty()


func vertex_count() -> int:
	return v.size()


func tri_count() -> int:
	return idx.size() / 3


func _vert(p: Vector3, nn: Vector3, col: Color, t: Vector2, t2: Vector2) -> int:
	v.append(p)
	n.append(nn)
	c.append(col)
	uv.append(t)
	uv2.append(t2)
	return v.size() - 1


func add_tri(a: Vector3, b: Vector3, d: Vector3, col: Color, t2 := Vector2.ZERO) -> void:
	var nn := (d - a).cross(b - a).normalized()
	var i := _vert(a, nn, col, Vector2(0, 1), t2)
	_vert(b, nn, col, Vector2(0, 0), t2)
	_vert(d, nn, col, Vector2(1, 0), t2)
	idx.append_array([i, i + 1, i + 2])


## Flat quad. Corners: bottom-left, top-left, top-right, bottom-right (seen from the front).
func add_quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color, t2 := Vector2.ZERO, uv_rect := Rect2(0, 0, 1, 1)) -> void:
	var nn := (e - a).cross(b - a).normalized()
	var i := _vert(a, nn, col, uv_rect.position + Vector2(0, uv_rect.size.y), t2)
	_vert(b, nn, col, uv_rect.position, t2)
	_vert(d, nn, col, uv_rect.position + Vector2(uv_rect.size.x, 0), t2)
	_vert(e, nn, col, uv_rect.position + uv_rect.size, t2)
	idx.append_array([i, i + 1, i + 2, i, i + 2, i + 3])


## Axis-aligned box of `size` centred at the origin of `xf` (all six faces).
func add_box(xf: Transform3D, size: Vector3, col: Color, t2 := Vector2.ZERO, skip_bottom := true) -> void:
	var h := size * 0.5
	var p := [
		xf * Vector3(-h.x, -h.y, -h.z), xf * Vector3(h.x, -h.y, -h.z),
		xf * Vector3(h.x, h.y, -h.z), xf * Vector3(-h.x, h.y, -h.z),
		xf * Vector3(-h.x, -h.y, h.z), xf * Vector3(h.x, -h.y, h.z),
		xf * Vector3(h.x, h.y, h.z), xf * Vector3(-h.x, h.y, h.z),
	]
	# front (+z)
	add_quad(p[4], p[7], p[6], p[5], col, t2)
	# back (-z)
	add_quad(p[1], p[2], p[3], p[0], col, t2)
	# right (+x)
	add_quad(p[5], p[6], p[2], p[1], col, t2)
	# left (-x)
	add_quad(p[0], p[3], p[7], p[4], col, t2)
	# top
	add_quad(p[7], p[3], p[2], p[6], col, t2)
	if not skip_bottom:
		add_quad(p[0], p[4], p[5], p[1], col, t2)


## Cylinder / cone frustum along the local +Y of `xf`, base at the origin.
func add_cylinder(xf: Transform3D, r0: float, r1: float, height: float, sides: int, col: Color, t2 := Vector2.ZERO, cap := true) -> void:
	var nb := xf.basis.inverse().transposed()
	var base := v.size()
	var slope := (r0 - r1) / maxf(height, 0.001)
	for i in sides + 1:
		var a := TAU * float(i) / sides
		var dir := Vector3(cos(a), 0.0, sin(a))
		var nn := (nb * (dir + Vector3(0, slope, 0))).normalized()
		_vert(xf * (dir * r0), nn, col, Vector2(float(i) / sides, 1.0), t2)
		_vert(xf * (dir * r1 + Vector3(0, height, 0)), nn, col, Vector2(float(i) / sides, 0.0), t2)
	for i in sides:
		var k := base + i * 2
		idx.append_array([k, k + 1, k + 3, k, k + 3, k + 2])
	if cap and r1 > 0.001:
		var up := (nb * Vector3.UP).normalized()
		var ci := _vert(xf * Vector3(0, height, 0), up, col, Vector2(0.5, 0.5), t2)
		var first := v.size()
		for i in sides + 1:
			var a := TAU * float(i) / sides
			_vert(xf * (Vector3(cos(a), 0.0, sin(a)) * r1 + Vector3(0, height, 0)), up, col, Vector2.ZERO, t2)
		for i in sides:
			idx.append_array([ci, first + i + 1, first + i])


## Append arrays of another mesh (e.g. a TextMesh) transformed by `xf`.
func add_arrays(arrays: Array, xf: Transform3D, col: Color, t2 := Vector2.ZERO) -> void:
	var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if pv.is_empty():
		return
	var pn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var pu: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var pc: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var nb := xf.basis.inverse().transposed()
	var base := v.size()
	for i in pv.size():
		v.append(xf * pv[i])
		n.append((nb * pn[i]).normalized() if i < pn.size() else Vector3.UP)
		c.append(col * pc[i] if i < pc.size() else col)
		uv.append(pu[i] if i < pu.size() else Vector2.ZERO)
		uv2.append(t2)
	var pi = arrays[Mesh.ARRAY_INDEX]
	if pi == null or (pi as PackedInt32Array).is_empty():
		for i in pv.size():
			idx.append(base + i)
	else:
		for i in (pi as PackedInt32Array):
			idx.append(base + i)


## Loft a 2D profile (x = lateral, y = up, in frame space) along a list of frames.
## Profile points are listed left to right; faces point to the side the profile winds towards
## (counter-clockwise profile in the x/y plane, seen along the travel direction = outward faces).
func add_loft(profile: PackedVector2Array, frames: Array, col: Color, t2 := Vector2.ZERO, colors: PackedColorArray = PackedColorArray()) -> void:
	var np := profile.size()
	if np < 2 or frames.size() < 2:
		return
	var base := v.size()
	var acc := 0.0
	for fi in frames.size():
		var f: Transform3D = frames[fi]
		if fi > 0:
			acc += (f.origin - (frames[fi - 1] as Transform3D).origin).length()
		for pi in np:
			var q := profile[pi]
			# normal from profile neighbours (perpendicular in profile plane)
			var a := profile[maxi(pi - 1, 0)]
			var b := profile[mini(pi + 1, np - 1)]
			var tan := (b - a).normalized()
			var n2 := Vector2(-tan.y, tan.x)
			var nn := (f.basis.x * n2.x + f.basis.y * n2.y).normalized()
			_vert(f * Vector3(q.x, q.y, 0.0), nn, colors[pi] if pi < colors.size() else col, Vector2(float(pi) / (np - 1), acc), t2)
	for fi in frames.size() - 1:
		for pi in np - 1:
			var k0 := base + fi * np + pi
			var k1 := k0 + np
			idx.append_array([k0, k1, k1 + 1, k0, k1 + 1, k0 + 1])


func commit(existing: ArrayMesh = null) -> ArrayMesh:
	var m := existing if existing != null else ArrayMesh.new()
	if idx.is_empty():
		return m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Commit into a MeshInstance3D with `mat` (null if empty).
func to_instance(mat: Material, inst_name: String, cast_shadows := true) -> MeshInstance3D:
	if idx.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.name = inst_name
	mi.mesh = commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
