class_name TrackBuildings
extends RefCounted
## Real buildings that are part of the track (layout marker {"building": ...}, parsed by
## TrackBuilder.build_layout into data["buildings"]). Downtown rework (M4.6-1, owner: "a checkpoint
## inside a building, wall rides on facades, jumping and bouncing off buildings, rooftops").
##   "roof"    tower under the road: the road runs over its roof (rooftop gap jumps)
##   "through" tower around the road: the road drives through it (tunnel shell inside)
##   "facade"  tower wall beside the road, following a wall ride's raised edge; solid
## Options: "margin" (m beyond the road edge), "height" (m above the road), "gap" (facade: m
## beyond the road edge), "depth" (facade thickness), "side" (facade: left/right/both),
## "sign" (through: text over the entry portal).
## Drawn with the city's facade shader (unit boxes as MultiMesh instances, so the windows match
## the generated city) plus neon roof-edge strips. Footprints go to path meta "reserved" so the
## city kit keeps its random buildings out of them.

const ROOF_DROP := 0.9          # roof surface below the lowest deck point
const FACET := 12.0             # facade segment length along the road
const NEON_COLS := [Color(1.0, 0.17, 0.84), Color(0.0, 0.9, 1.0), Color(1.0, 0.7, 0.0), Color(0.55, 0.3, 1.0)]


static func build(root: Node3D, data: Dictionary, layout: Dictionary) -> void:
	var list: Array = data.get("buildings", [])
	if list.is_empty():
		return
	var path: TrackPath = data["path"]
	var ground_y: float = float(layout.get("ground_y", 0.0)) - 0.3
	var node := Node3D.new()
	node.name = "TrackBuildings"
	root.add_child(node)
	var bmat := SceneryMat.shader_mat("building", {"wetness": 0.7, "window_energy": 1.25})
	var inst := SceneryInstances.new(SceneryProps.unit_box(), bmat, 400.0, false, true)
	var neon := SceneryMesh.new()
	var col := TrackBuilder.Acc.new()
	var reserved: Array = []
	var i := 0
	for bd: Dictionary in list:
		var seed := fmod(0.137 + i * 0.311, 1.0)
		var accent: Color = NEON_COLS[i % NEON_COLS.size()]
		match String(bd["kind"]):
			"roof":
				_roof(path, bd, ground_y, seed, accent, inst, neon, reserved)
			"through":
				_through(node, path, bd, ground_y, seed, accent, inst, neon, col, reserved)
			"facade":
				_facade(path, bd, ground_y, seed, accent, inst, neon, col, reserved)
			_:
				push_warning("TrackBuildings: unknown kind %s" % bd["kind"])
		i += 1
	inst.build(node, "Towers", 0.0, true)
	if not neon.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "TowerNeon"
		mi.mesh = neon.commit()
		mi.material_override = SceneryMat.neon(4.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	if not col.is_empty():
		var sb := StaticBody3D.new()
		sb.name = "TowerBody"
		sb.collision_layer = TrackBuilder.LAYER_WORLD
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(col.faces())
		cs.shape = shape
		sb.add_child(cs)
		node.add_child(sb)
	var prev: Array = path.get_meta("reserved", []) if path.has_meta("reserved") else []
	prev.append_array(reserved)
	path.set_meta("reserved", prev)
	node.set_meta("count", reserved.size())


## Horizontal basis of the road at d: x = right, y = up, z = backwards (Godot convention).
static func _yaw_basis(path: TrackPath, d: float) -> Basis:
	var f := path.sample_transform(d)
	var fwd := -f.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 1e-6 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP).normalized()
	return Basis(right, Vector3.UP, -fwd)


## One facade block: base center `c` (on the ground), basis `b`, size (w across, h, l along).
static func _block(inst: SceneryInstances, c: Vector3, b: Basis, w: float, h: float, l: float, seed: float, style: float, lit: float) -> void:
	if h <= 0.2 or w <= 0.1 or l <= 0.1:
		return
	inst.add(Transform3D(b.scaled_local(Vector3(w, h, l)), c), Color.WHITE, Color(seed, style, lit, 0.6))


## Collision box (center `c` of the box, basis `b`, full size).
static func _col_box(col: TrackBuilder.Acc, c: Vector3, b: Basis, size: Vector3) -> void:
	col.box(Transform3D(b, c), size)


## Neon strip around a rectangle (center `c` at height y, basis `b`, half extents hx/hz).
static func _edge_strip(neon: SceneryMesh, c: Vector3, b: Basis, hx: float, hz: float, accent: Color) -> void:
	var colr := SceneryMat.hdr(accent, 1.4)
	for s: float in [-1.0, 1.0]:
		neon.add_box(Transform3D(b, c + b.z * (hz + 0.06) * s), Vector3(hx * 2.0 + 0.24, 0.3, 0.12), colr, Vector2(0, 0))
		neon.add_box(Transform3D(b, c + b.x * (hx + 0.06) * s), Vector3(0.12, 0.3, hz * 2.0 + 0.24), colr, Vector2(0, 0))


static func _reserve(reserved: Array, c: Vector3, b: Basis, hx: float, hz: float) -> void:
	reserved.append([Vector3(c.x, 0.0, c.z), b.x, b.z, hx, hz])


## Tower under the road: the road is its roof deck.
static func _roof(path: TrackPath, bd: Dictionary, ground_y: float, seed: float, accent: Color, inst: SceneryInstances, neon: SceneryMesh, reserved: Array) -> void:
	var d0: float = bd["d"]
	var d1: float = d0 + float(bd["len"])
	var margin: float = float(bd.get("margin", 6.0))
	var b := _yaw_basis(path, (d0 + d1) * 0.5)
	var o := path.sample_position((d0 + d1) * 0.5)
	var xmin := 1e9
	var xmax := -1e9
	var zmin := 1e9
	var zmax := -1e9
	var top := 1e9
	var d := d0
	while d <= d1 + 0.01:
		var f := path.sample_transform(d)
		var hw := path.width_at(d) * 0.5
		for sx: float in [-1.0, 0.0, 1.0]:
			var p := f.origin + f.basis.x * (hw + margin) * sx
			var r := p - o
			xmin = minf(xmin, r.dot(b.x))
			xmax = maxf(xmax, r.dot(b.x))
			zmin = minf(zmin, r.dot(b.z))
			zmax = maxf(zmax, r.dot(b.z))
			if sx != 0.0:
				top = minf(top, (f.origin + f.basis.x * hw * sx).y)
		top = minf(top, f.origin.y)
		d += 2.0
	top -= ROOF_DROP
	var cx := (xmin + xmax) * 0.5
	var cz := (zmin + zmax) * 0.5
	var c := o + b.x * cx + b.z * cz
	c.y = ground_y
	var w := xmax - xmin
	var l := zmax - zmin
	var h := top - ground_y
	_block(inst, c, b, w, h, l, seed, 0.35, 0.4)
	# setback crown below the roof edge reads as a real tower; rooftop clutter on the margins
	var roof_c := c + Vector3(0, h, 0)
	_edge_strip(neon, roof_c + Vector3(0, -0.4, 0), b, w * 0.5, l * 0.5, accent)
	for k in 4:
		var side := -1.0 if k % 2 == 0 else 1.0
		var along := (float(k / 2) - 0.5) * l * 0.5
		var pc := roof_c + b.x * side * (w * 0.5 - margin * 0.45) + b.z * along
		_block(inst, pc, b, minf(3.5, margin * 0.6), 2.2, 4.0, fmod(seed + 0.5, 1.0), 0.1, 0.0)
	_reserve(reserved, c, b, w * 0.5, l * 0.5)


## Tower the road drives through (the tunnel shell from TrackBuilder is the interior).
static func _through(node: Node3D, path: TrackPath, bd: Dictionary, ground_y: float, seed: float, accent: Color, inst: SceneryInstances, neon: SceneryMesh, col: TrackBuilder.Acc, reserved: Array) -> void:
	var d0: float = bd["d"]
	var d1: float = d0 + float(bd["len"])
	var dm := (d0 + d1) * 0.5
	var b := _yaw_basis(path, dm)
	var f := path.sample_transform(dm)
	var road_y := f.origin.y
	var hw := path.width_at(dm) * 0.5
	var oh := hw + 2.8                 # tunnel outer half width (TrackBuilder._build_tunnel)
	var side_w: float = float(bd.get("margin", 12.0))
	var height: float = float(bd.get("height", 46.0))
	var l := d1 - d0
	var c := f.origin
	c.y = ground_y
	var top_y := road_y + height
	# left and right wings
	for s: float in [-1.0, 1.0]:
		var wc := c + b.x * s * (oh + side_w * 0.5)
		_block(inst, wc, b, side_w, top_y - ground_y, l, seed, 0.35, 0.45)
		_col_box(col, Vector3(wc.x, (ground_y + top_y) * 0.5, wc.z), b, Vector3(side_w, top_y - ground_y, l))
	# over the tunnel and under the road
	_block(inst, c + Vector3(0, road_y + 9.4 - ground_y, 0), b, oh * 2.0, top_y - road_y - 9.4, l, seed, 0.35, 0.45)
	_col_box(col, Vector3(c.x, (road_y + 9.4 + top_y) * 0.5, c.z), b, Vector3(oh * 2.0, top_y - road_y - 9.4, l))
	_block(inst, c, b, oh * 2.0, road_y - 0.6 - ground_y, l, seed, 0.35, 0.45)
	var w := oh * 2.0 + side_w * 2.0
	_edge_strip(neon, c + Vector3(0, top_y - ground_y - 0.4, 0), b, w * 0.5, l * 0.5, accent)
	# crown
	_block(inst, c + Vector3(0, top_y - ground_y, 0), b, w * 0.6, 10.0, l * 0.6, fmod(seed + 0.37, 1.0), 0.7, 0.3)
	# neon portal frame and sign on the entry facade (facing the approaching car)
	var entry := path.sample_transform(d0)
	var fc := entry.origin - (-b.z) * 0.15
	var pb := Basis(b.x, Vector3.UP, b.z)
	var ac := SceneryMat.hdr(accent, 1.6)
	neon.add_box(Transform3D(pb, fc + Vector3(0, 9.7, 0)), Vector3(oh * 2.0, 0.35, 0.12), ac, Vector2(0, 0))
	for s: float in [-1.0, 1.0]:
		neon.add_box(Transform3D(pb, fc + b.x * s * oh + Vector3(0, 4.5, 0)), Vector3(0.35, 10.4, 0.12), ac, Vector2(0, 0))
	var txt := String(bd.get("sign", ""))
	if txt != "":
		var lbl := Label3D.new()
		lbl.name = "TowerSign"
		lbl.text = txt
		var font: Variant = load("res://assets/fonts/orbitron-latin-900-normal.woff2")
		if font is Font:
			lbl.font = font
		lbl.font_size = 160
		lbl.pixel_size = 0.03
		lbl.outline_size = 0
		lbl.modulate = Color(accent.r * 2.2, accent.g * 2.2, accent.b * 2.2)
		lbl.shaded = false
		lbl.double_sided = false
		lbl.transform = Transform3D(pb, fc + Vector3(0, 15.0, 0) - (-b.z) * 0.1)
		node.add_child(lbl)
	_reserve(reserved, c, b, w * 0.5, l * 0.5)


## Tower wall beside the road. On a wall ride it stands just beyond the raised edge.
static func _facade(path: TrackPath, bd: Dictionary, ground_y: float, seed: float, accent: Color, inst: SceneryInstances, neon: SceneryMesh, col: TrackBuilder.Acc, reserved: Array) -> void:
	var d0: float = bd["d"]
	var d1: float = d0 + float(bd["len"])
	var gap: float = float(bd.get("gap", 1.6))
	var depth: float = float(bd.get("depth", 16.0))
	var height: float = float(bd.get("height", 34.0))
	var sides: Array = []
	match String(bd.get("side", "right")):
		"left":
			sides = [-1.0]
		"both":
			sides = [-1.0, 1.0]
		_:
			sides = [1.0]
	var n := maxi(1, ceili((d1 - d0) / FACET))
	var seg := (d1 - d0) / n
	for s: float in sides:
		for k in n:
			var a := d0 + k * seg
			var e := a + seg
			var dm := (a + e) * 0.5
			var b := _yaw_basis(path, dm)
			var o := path.sample_position(dm)
			# innermost face: just beyond the barrier at every point of this facet
			var inner := 0.0
			var top := -1e9
			var low := 1e9
			var dd := a
			while dd <= e + 0.01:
				var f := path.sample_transform(dd)
				var hw := path.width_at(dd) * 0.5 + TrackBuilder.WALL_GAP + 0.7
				var edge := f.origin + f.basis.x * hw * s
				inner = maxf(inner, (edge - o).dot(b.x) * s)
				top = maxf(top, edge.y)
				low = minf(low, f.origin.y)
				dd += 1.5
			inner += gap
			var c := o + b.x * s * (inner + depth * 0.5)
			c.y = ground_y
			var h := maxf(top, low) + height - ground_y
			var bl := seg + 0.6
			_block(inst, c, b, depth, h, bl, seed, 0.35 if k % 3 != 1 else 0.66, 0.5)
			_col_box(col, Vector3(c.x, ground_y + h * 0.5, c.z), b, Vector3(depth, h, bl))
			# neon band at road level along the face (reads the wall at speed)
			var face := o + b.x * s * (inner - 0.08)
			face.y = low + 3.0
			neon.add_box(Transform3D(b, face), Vector3(0.12, 0.35, bl), SceneryMat.hdr(accent, 1.3), Vector2(0, 0))
			face.y = maxf(top, low) + 6.0
			neon.add_box(Transform3D(b, face), Vector3(0.12, 0.35, bl), SceneryMat.hdr(accent, 1.3), Vector2(0, 0))
			_reserve(reserved, c, b, depth * 0.5, bl * 0.5)
