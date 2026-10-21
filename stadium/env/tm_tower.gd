class_name TmTower
extends RefCounted
## Our own skyscrapers (not TMNF's: the owner's ask for "tall, ultrarealistic buildings"), built in
## code from a spec: a footprint (rectangle, chamfered, rounded, octagon, circle), tiers set back as
## they rise, a podium with a lobby, a crown, roof plant and a mast with an aviation light. The
## facades carry their own detail in the shader (env/tm_tower.gdshader): curtain-wall glass with
## mullions and spandrels, rooms behind every window (interior mapping), reflections. Facade UVs are
## metres: u around the tower, v up from its foot, so floors and bays line up on every tier.
##
##   var tower := TmTower.build({"height": 320.0, "w": 48.0, "d": 40.0, "shape": "chamfer", "seed": 7})
##
## Spec keys (all optional): height (m), w, d (footprint, m), shape, tiers ([[height fraction, scale]],
## the setbacks), podium (m), crown ("flat", "spire", "slant", "ring"), floor (floor height, m), bay
## (window width, m), fins (a deeper vertical fin every this many bays; 0 none), glass (a palette
## name from GLASS), seed, shadows (casts shadows; default true).
## The city's lower buildings (TmSkyline) are merged walls of many blocks: Builder, walls(), cap(),
## material() and masonry().

## Glass palettes: tint (the coating's colour), reflectivity (metallic), mullion colour, spandrel colour.
const GLASS := {
	"blue": [Color(0.30, 0.42, 0.52), 0.80, Color(0.62, 0.65, 0.68), Color(0.10, 0.13, 0.17)],
	"green": [Color(0.32, 0.46, 0.44), 0.78, Color(0.70, 0.72, 0.72), Color(0.09, 0.13, 0.13)],
	"silver": [Color(0.55, 0.58, 0.62), 0.85, Color(0.80, 0.81, 0.82), Color(0.20, 0.21, 0.23)],
	"bronze": [Color(0.42, 0.34, 0.26), 0.80, Color(0.30, 0.25, 0.20), Color(0.14, 0.11, 0.09)],
	"dark": [Color(0.16, 0.18, 0.21), 0.82, Color(0.12, 0.12, 0.13), Color(0.05, 0.05, 0.06)],
}
## Masonry walls with punched or ribbon windows: wall colour, glass tint, reflectivity, mullion
## (pier) width, transom (lintel and sill) height, spandrel height (m), the glass's depth in its
## opening (m), the wall's grain ("brick" courses, precast "panels", "" plain) and grime.
const MASONRY := {
	"stone": [Color(0.70, 0.66, 0.58), Color(0.30, 0.33, 0.35), 0.55, 1.3, 1.0, 0.6, 0.3, "", 0.7],
	"brick": [Color(0.50, 0.30, 0.24), Color(0.28, 0.31, 0.33), 0.55, 1.2, 0.9, 0.6, 0.22, "brick", 0.6],
	"concrete": [Color(0.64, 0.64, 0.62), Color(0.26, 0.32, 0.38), 0.65, 0.18, 0.2, 1.2, 0.12, "panels", 0.5],
	"white": [Color(0.86, 0.86, 0.84), Color(0.24, 0.30, 0.36), 0.65, 0.5, 0.3, 1.0, 0.15, "panels", 0.3],
}
const SHAPES := ["rect", "chamfer", "rounded", "octagon", "circle"]
## The crowns' floodlights at night: warm white, cool white, blue, teal, amber.
const CROWN_LIGHTS := [Color(1.0, 0.92, 0.78), Color(0.85, 0.92, 1.0), Color(0.35, 0.55, 1.0), Color(0.3, 0.9, 0.85),
	Color(1.0, 0.7, 0.35)]
const DETAIL_END := 2500.0      ## roof plant and masts are drawn up to this far (m)

static var _shader: Shader
static var _shared := {}


## Triangles in plain arrays (fast to fill in GDScript; no tangents: the shader needs none).
class Builder:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var tint := Color.WHITE

	func tri(p: Array, nn: Array, uu: Array) -> void:
		tri3(p[0], p[1], p[2], nn[0], nn[1], nn[2], uu[0], uu[1], uu[2])

	## One triangle without arrays (the hot path: thousands of walls).
	func tri3(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
		v.append(a)
		v.append(b)
		v.append(c)
		n.append(na)
		n.append(nb)
		n.append(nc)
		uv.append(ua)
		uv.append(ub)
		uv.append(uc)
		col.append(tint)
		col.append(tint)
		col.append(tint)

	func empty() -> bool:
		return v.is_empty()

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = col
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


## A tower as one node: its facade mesh, roofs, plant and mast. Its foot at the node's origin.
static func build(spec: Dictionary) -> Node3D:
	var height := float(spec.get("height", 240.0))
	var w := float(spec.get("w", 44.0))
	var d := float(spec.get("d", 36.0))
	var shape := String(spec.get("shape", "rect"))
	var seed := int(spec.get("seed", 1))
	var podium := float(spec.get("podium", 12.0))
	var tiers: Array = spec.get("tiers", [[1.0, 1.0]])
	var root := Node3D.new()
	root.name = "Tower"
	var facade := Builder.new()
	var roofs := Builder.new()
	# the podium: a wider, lower block with the lobby's tall glass
	var lobby := Builder.new()
	var pod := footprint(shape, w * 1.18, d * 1.25)
	walls(lobby, pod, 0.0, podium)
	cap(roofs, pod, podium)
	# the tiers: each from the last one's top, smaller as it rises
	var y := podium
	var last: PackedVector2Array = footprint(shape, w, d)
	for t: Array in tiers:
		var top := podium + (height - podium) * float(t[0])
		var poly := footprint(shape, w * float(t[1]), d * float(t[1]))
		if top <= y + 1.0:
			continue
		walls(facade, poly, y, top)
		if not _same(poly, last) or y == podium:
			_ring_cap(roofs, last, poly, y)      # the setback's terrace
		cap(roofs, poly, top)
		last = poly
		y = top
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var glass := String(spec.get("glass", "blue"))
	var mat := material(glass, seed, float(spec.get("floor", 4.0)), float(spec.get("bay", 3.0)))
	mat.set_shader_parameter("fin_every", float(spec.get("fins", 0)))
	# the crown and the roof: a parapet, plant, a mast and its light; at night its floodlights
	mat.set_shader_parameter("crown_light", CROWN_LIGHTS[rng.randi() % CROWN_LIGHTS.size()])
	facade.tint.a = 0.5
	_crown(root, facade, last, y, String(spec.get("crown", "flat")), rng)
	facade.tint.a = 1.0
	var shadows := bool(spec.get("shadows", true))
	_add(root, facade, mat, "Facade", shadows)
	# the podium: one tall storey of clear lobby glass between stone piers
	var lobby_mat := material(glass, seed + 11, podium, float(spec.get("bay", 3.0)) * 2.5)
	lobby_mat.set_shader_parameter("lobby", 1.0)
	lobby_mat.set_shader_parameter("glass_tint", Color(0.40, 0.45, 0.47))
	lobby_mat.set_shader_parameter("reflectivity", 0.5)
	lobby_mat.set_shader_parameter("frame_colour", Color(0.42, 0.41, 0.40))
	lobby_mat.set_shader_parameter("frame_metal", 0.0)
	lobby_mat.set_shader_parameter("frame_rough", 0.6)
	lobby_mat.set_shader_parameter("mullion", 1.1)
	lobby_mat.set_shader_parameter("transom", 0.9)
	_add(root, lobby, lobby_mat, "Lobby", shadows)
	_add(root, roofs, shared("roof"), "Roofs", shadows)
	return root


## A footprint polygon (counter-clockwise from above, centred), w along x, d along z.
static func footprint(shape: String, w: float, d: float) -> PackedVector2Array:
	var hw := w * 0.5
	var hd := d * 0.5
	var out := PackedVector2Array()
	match shape:
		"chamfer":
			var c := minf(hw, hd) * 0.28
			out = PackedVector2Array([Vector2(-hw + c, -hd), Vector2(hw - c, -hd), Vector2(hw, -hd + c), Vector2(hw, hd - c),
				Vector2(hw - c, hd), Vector2(-hw + c, hd), Vector2(-hw, hd - c), Vector2(-hw, -hd + c)])
		"rounded":
			var r := minf(hw, hd) * 0.35
			for k in 4:
				var cx := hw - r if k == 0 or k == 1 else -hw + r
				var cz := -hd + r if k == 0 or k == 3 else hd - r
				for s in 5:
					var a := (k * 90.0 - 90.0 + s * 22.5) * PI / 180.0
					out.append(Vector2(cx + cos(a) * r, cz + sin(a) * r))
		"octagon":
			for k in 8:
				var a := (k * 45.0 + 22.5) * PI / 180.0
				out.append(Vector2(cos(a) * hw * 1.08, sin(a) * hd * 1.08))
		"circle":
			for k in 24:
				var a := k * TAU / 24.0
				out.append(Vector2(cos(a) * hw, sin(a) * hd))
		_:
			out = PackedVector2Array([Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)])
	return out


## The tower's facade material (TmTower's shader): a glass palette, its seed (each tower's rooms
## differ), floor height and bay width (m).
static func material(glass: String, seed: int, floor_h := 4.0, bay := 3.0) -> ShaderMaterial:
	if _shader == null:
		_shader = preload("res://env/tm_tower.gdshader")
	var g: Array = GLASS.get(glass, GLASS["blue"])
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("glass_tint", g[0])
	m.set_shader_parameter("reflectivity", g[1])
	m.set_shader_parameter("frame_colour", g[2])
	m.set_shader_parameter("spandrel_colour", g[3])
	m.set_shader_parameter("seed", float(seed % 997) * 0.731)
	m.set_shader_parameter("floor_h", floor_h)
	m.set_shader_parameter("bay_w", bay)
	return m


## A masonry building's walls (MASONRY: stone, brick, concrete, white): the same shader, its frames
## the wall, its windows punched (stone, brick) or in ribbons (concrete, white), the glass set back
## in its opening, brick courses or precast panel joints, grime under the sills.
static func masonry(style: String, seed: int, floor_h := 3.5, bay := 3.0) -> ShaderMaterial:
	var s: Array = MASONRY.get(style, MASONRY["stone"])
	var m := material("blue", seed, floor_h, bay)
	m.set_shader_parameter("frame_colour", s[0])
	m.set_shader_parameter("spandrel_colour", s[0])
	m.set_shader_parameter("glass_tint", s[1])
	m.set_shader_parameter("reflectivity", s[2])
	m.set_shader_parameter("mullion", s[3])
	m.set_shader_parameter("transom", s[4])
	m.set_shader_parameter("spandrel", s[5])
	m.set_shader_parameter("frame_metal", 0.0)
	m.set_shader_parameter("frame_rough", 0.85)
	m.set_shader_parameter("span_metal", 0.0)
	m.set_shader_parameter("span_rough", 0.85)
	m.set_shader_parameter("reveal", s[6])
	m.set_shader_parameter("brick", 1.0 if s[7] == "brick" else 0.0)
	m.set_shader_parameter("panels", 1.0 if s[7] == "panels" else 0.0)
	m.set_shader_parameter("grime", s[8])
	return m


## The materials every tower shares: "roof", "plant", "steel", "beacon".
static func shared(key: String) -> Material:
	if _shared.has(key):
		return _shared[key]
	var m: Material
	if key == "beacon":
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://env/tm_beacon.gdshader")
		m = sm
	else:
		var s := StandardMaterial3D.new()
		s.vertex_color_use_as_albedo = key == "roof"
		match key:
			"roof":
				s.albedo_color = Color(0.36, 0.37, 0.38)
				s.roughness = 0.9
			"plant":
				s.albedo_color = Color(0.55, 0.56, 0.55)
				s.roughness = 0.7
				s.metallic = 0.3
			_:
				s.albedo_color = Color(0.72, 0.73, 0.75)
				s.metallic = 1.0
				s.roughness = 0.3
		m = s
	_shared[key] = m
	return m


# --- geometry -----------------------------------------------------------------------------------

## The walls of a prism: one quad per edge, normals out, UV in metres (u around from u0, v up).
static func walls(b: Builder, poly: PackedVector2Array, y0: float, y1: float, u0 := 0.0) -> void:
	var u := u0
	var n := poly.size()
	var smooth := n > 12          # a circle's walls shade round
	for i in n:
		var a := poly[i]
		var e := poly[(i + 1) % n]
		var len := a.distance_to(e)
		var nf := Vector3(e.y - a.y, 0.0, -(e.x - a.x)).normalized()
		var na := nf
		var nb := nf
		if smooth:
			na = Vector3(a.x, 0.0, a.y).normalized()
			nb = Vector3(e.x, 0.0, e.y).normalized()
		var p0 := Vector3(a.x, y0, a.y)
		var p1 := Vector3(e.x, y0, e.y)
		var p2 := Vector3(e.x, y1, e.y)
		var p3 := Vector3(a.x, y1, a.y)
		var t0 := Vector2(u, y0)
		var t1 := Vector2(u + len, y0)
		var t2 := Vector2(u + len, y1)
		var t3 := Vector2(u, y1)
		# clockwise from outside (Godot's front faces)
		b.tri3(p0, p1, p2, na, nb, nb, t0, t1, t2)
		b.tri3(p0, p2, p3, na, nb, na, t0, t2, t3)
		u += len


## A flat roof over a convex polygon (a fan), facing up.
static func cap(b: Builder, poly: PackedVector2Array, y: float) -> void:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= poly.size()
	var up := Vector3.UP
	var cc := Vector3(c.x, y, c.y)
	for i in poly.size():
		var a := poly[i]
		var e := poly[(i + 1) % poly.size()]
		b.tri3(cc, Vector3(a.x, y, a.y), Vector3(e.x, y, e.y), up, up, up, c * 0.25, a * 0.25, e * 0.25)


## A flat ring between two polygons of the same vertex count, facing up, or down (a ledge's underside).
static func ring_cap(b: Builder, outer: PackedVector2Array, inner: PackedVector2Array, y: float, down := false) -> void:
	if not down:
		_ring_cap(b, outer, inner, y)
		return
	var n := outer.size()
	var dn := [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN]
	for i in n:
		var a := outer[i]
		var e := outer[(i + 1) % n]
		var c := inner[(i + 1) % n]
		var f := inner[i]
		b.tri([Vector3(a.x, y, a.y), Vector3(c.x, y, c.y), Vector3(e.x, y, e.y)], dn, [a * 0.25, c * 0.25, e * 0.25])
		b.tri([Vector3(a.x, y, a.y), Vector3(f.x, y, f.y), Vector3(c.x, y, c.y)], dn, [a * 0.25, f * 0.25, c * 0.25])


## The terrace between a tier and the smaller one on it (both polygons have the same vertex count).
static func _ring_cap(b: Builder, outer: PackedVector2Array, inner: PackedVector2Array, y: float) -> void:
	if outer.size() != inner.size():
		cap(b, outer, y)
		return
	var n := outer.size()
	var up := [Vector3.UP, Vector3.UP, Vector3.UP]
	for i in n:
		var a := outer[i]
		var e := outer[(i + 1) % n]
		var c := inner[(i + 1) % n]
		var f := inner[i]
		b.tri([Vector3(a.x, y, a.y), Vector3(e.x, y, e.y), Vector3(c.x, y, c.y)], up, [a * 0.25, e * 0.25, c * 0.25])
		b.tri([Vector3(a.x, y, a.y), Vector3(c.x, y, c.y), Vector3(f.x, y, f.y)], up, [a * 0.25, c * 0.25, f * 0.25])


static func _same(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i].distance_to(b[i]) > 0.01:
			return false
	return true


## A mesh node from a builder (none if it is empty); end: drawn up to this far (0: always).
static func add_mesh(root: Node3D, b: Builder, mat: Material, name: String, shadows := true, end := 0.0) -> MeshInstance3D:
	if b.empty():
		return null
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = b.mesh()
	mi.material_override = mat
	mi.visibility_range_end = end
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func _add(root: Node3D, b: Builder, mat: Material, name: String, shadows := true, end := 0.0) -> void:
	add_mesh(root, b, mat, name, shadows, end)


## The top: a parapet of the facade, plant boxes, and per crown a spire, a slanted top, a ring
## or a flat roof with a mast; an aviation light (red, blinking) at the highest point.
static func _crown(root: Node3D, facade: Builder, top: PackedVector2Array, y: float, crown: String, rng: RandomNumberGenerator) -> void:
	var size := Vector2.ZERO
	for p in top:
		size = Vector2(maxf(size.x, absf(p.x)), maxf(size.y, absf(p.y)))
	var peak := y
	match crown:
		"spire":
			var tier := top.duplicate()
			for i in tier.size():
				tier[i] *= 0.55
			walls(facade, tier, y, y + 14.0)
			var spire_h := 40.0 + rng.randf() * 50.0
			_spire(root, Vector3(0.0, y + 14.0, 0.0), spire_h, 1.6)
			peak = y + 14.0 + spire_h
		"slant":
			# a top cut on a slope: the walls rise one side to the other (plain shapes only)
			var rise := size.x * 0.6
			_prism_slant(facade, top, y, rise)
			peak = y + rise
		"ring":
			walls(facade, top, y, y + 9.0)     # a glass crown standing proud of the roof, open above
			peak = y + 9.0
		_:
			walls(facade, top, y, y + 3.0)     # a parapet
			peak = y + 3.0
	# plant on the roof: a few boxes, kept inside the top's footprint
	var plant := Builder.new()
	for k in 2 + rng.randi() % 4:
		var at := Vector2((rng.randf() - 0.5) * size.x * 0.9, (rng.randf() - 0.5) * size.y * 0.9)
		var box := footprint("rect", 3.0 + rng.randf() * 7.0, 3.0 + rng.randf() * 7.0)
		var bh := 2.0 + rng.randf() * 4.0
		for i in box.size():
			box[i] += at
		walls(plant, box, y, y + bh)
		cap(plant, box, y + bh)
	_add(root, plant, shared("plant"), "Plant", true, DETAIL_END)
	if crown != "spire":
		var mast_h := 12.0 + rng.randf() * 25.0
		_spire(root, Vector3(size.x * 0.25, peak, -size.y * 0.2), mast_h, 0.35)
		peak += mast_h
	_beacon(root, Vector3(0.0 if crown == "spire" else size.x * 0.25, peak + 0.6, 0.0 if crown == "spire" else -size.y * 0.2))


static func _prism_slant(b: Builder, poly: PackedVector2Array, y0: float, rise: float) -> void:
	var minx := INF
	var maxx := -INF
	for p in poly:
		minx = minf(minx, p.x)
		maxx = maxf(maxx, p.x)
	var u := 0.0
	var n := poly.size()
	var top := PackedVector3Array()
	for i in n:
		var a := poly[i]
		var e := poly[(i + 1) % n]
		var ya := y0 + rise * (a.x - minx) / maxf(maxx - minx, 0.01)
		var yb := y0 + rise * (e.x - minx) / maxf(maxx - minx, 0.01)
		var len := a.distance_to(e)
		var nf := Vector3(e.y - a.y, 0.0, -(e.x - a.x)).normalized()
		var nn := [nf, nf, nf]
		var p0 := Vector3(a.x, y0, a.y)
		var p1 := Vector3(e.x, y0, e.y)
		var p2 := Vector3(e.x, yb, e.y)
		var p3 := Vector3(a.x, ya, a.y)
		b.tri([p0, p1, p2], nn, [Vector2(u, y0), Vector2(u + len, y0), Vector2(u + len, yb)])
		b.tri([p0, p2, p3], nn, [Vector2(u, y0), Vector2(u + len, yb), Vector2(u, ya)])
		u += len
		top.append(p3)
	# the sloped roof (a fan; glass too, it reads as the crown)
	var c := Vector3.ZERO
	for p in top:
		c += p
	c /= top.size()
	var nr := (top[0] - c).cross(top[1] - c).normalized()
	if nr.y < 0.0:
		nr = -nr
	for i in n:
		var q0 := top[i]
		var q1 := top[(i + 1) % n]
		b.tri([c, q0, q1], [nr, nr, nr], [Vector2(c.x, c.y), Vector2(q0.x, q0.y), Vector2(q1.x, q1.y)])


## A steel spire or mast: a tapering octagonal pole.
static func _spire(root: Node3D, foot: Vector3, h: float, r: float) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r * 0.15
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 1
	var mi := MeshInstance3D.new()
	mi.name = "Mast"
	mi.mesh = m
	mi.position = foot + Vector3(0.0, h * 0.5, 0.0)
	mi.material_override = shared("steel")
	if r < 1.0:
		mi.visibility_range_end = DETAIL_END
	root.add_child(mi)


## The aviation obstruction light: a small red lamp that blinks (by its shader's TIME).
static func _beacon(root: Node3D, at: Vector3) -> void:
	var s := SphereMesh.new()
	s.radius = 0.6
	s.height = 1.2
	s.radial_segments = 8
	s.rings = 4
	var mi := MeshInstance3D.new()
	mi.name = "Beacon"
	mi.mesh = s
	mi.position = at
	mi.material_override = shared("beacon")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
