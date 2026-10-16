class_name ProcGeo
extends RefCounted
## Procedural surfaces: builds one ArrayMesh and a matching ConcavePolygonShape3D from quads, with
## the winding chosen so the side facing `up` is the solid (front) side for rendering and collision.

var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _uvs := PackedVector2Array()


## Quad a-b-c-d (in order around the edge), drivable side facing `up`. uv in metres (world-ish).
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, up: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(up) > 0.0:   # Godot's front faces are clockwise seen from the front: flip
		var t := b
		b = d
		d = t
	var face_n := -(b - a).cross(c - a).normalized()
	for p in [a, b, c, a, c, d]:
		_verts.append(p)
		_norms.append(face_n)
		_uvs.append(Vector2(p.x + p.y * 0.5, p.z + p.y * 0.5) / 32.0)


## Ribbon along a centre line: sections [centre, left half-width vector, up], drivable side up.
func ribbon(sections: Array) -> void:
	for k in sections.size() - 1:
		var s0: Array = sections[k]
		var s1: Array = sections[k + 1]
		var l0: Vector3 = s0[0] + s0[1]
		var r0: Vector3 = s0[0] - s0[1]
		var l1: Vector3 = s1[0] + s1[1]
		var r1: Vector3 = s1[0] - s1[1]
		quad(l0, r0, r1, l1, (s0[2] as Vector3) + (s1[2] as Vector3))


func is_empty() -> bool:
	return _verts.is_empty()


func mesh(material: Material = null) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _norms
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		m.surface_set_material(0, material)
	return m


func shape() -> ConcavePolygonShape3D:
	var s := ConcavePolygonShape3D.new()
	s.set_faces(_verts)
	return s


## A static body with this geometry (collision layer 1) and its mesh.
func body(material: Material = null, surface: int = -1) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape()
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(material)
	b.add_child(mi)
	if surface >= 0:
		b.set_meta("surface", surface)
	return b


## Helix loop around an axis along +X: starts at `start` (bottom, tangent to the ground, heading +Z),
## radius r, lateral shift per turn `shift`, ribbon half-width hw.
static func loop_sections(start: Vector3, r: float, shift: float, hw: float, steps: int = 96) -> Array:
	var out: Array = []
	for i in steps + 1:
		var th := TAU * i / float(steps)
		var c := start + Vector3(shift * th / TAU, r - r * cos(th), r * sin(th))
		var up := Vector3(0.0, cos(th), -sin(th))
		var fwd := Vector3(shift / TAU, r * sin(th), r * cos(th)).normalized()
		var left := up.cross(fwd).normalized()
		out.append([c, left * hw, up])
	return out


## Quarter pipe along +Z from z0 to z1: the floor at `x_floor_edge` curves up to vertical over
## radius r toward -X (the wall side), as a list of quads.
func quarter_pipe(x_edge: float, z0: float, z1: float, r: float, steps: int = 16, extra_wall: float = 4.0) -> void:
	var prof: Array = []   # [point in (x, y), inward normal]
	for i in steps + 1:
		var ph := PI * 0.5 * i / float(steps)
		prof.append([Vector2(x_edge - r * sin(ph), r - r * cos(ph)), Vector2(sin(ph), cos(ph))])
	prof.append([Vector2(x_edge - r, r + extra_wall), Vector2(1, 0)])
	for i in prof.size() - 1:
		var p0: Vector2 = prof[i][0]
		var p1: Vector2 = prof[i + 1][0]
		var n: Vector2 = (prof[i][1] as Vector2) + (prof[i + 1][1] as Vector2)
		quad(Vector3(p0.x, p0.y, z0), Vector3(p1.x, p1.y, z0), Vector3(p1.x, p1.y, z1), Vector3(p0.x, p0.y, z1),
			Vector3(n.x, n.y, 0.0))
