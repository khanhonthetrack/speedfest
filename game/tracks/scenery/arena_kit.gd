class_name SceneryArenaKit
extends RefCounted
## "arena" theme props: night stunt stadium. A bowl of stands with an animated crowd around the
## whole track, floodlight towers with volumetric beams, jumbotrons, neon arches over the road,
## neon pylons, sponsor LED boards and sweeping searchlights.

const CYAN := Color(0.0, 0.9, 1.0)
const MAGENTA := Color(1.0, 0.17, 0.84)
const AMBER := Color(1.0, 0.7, 0.0)
const LIME := Color(0.65, 1.0, 0.0)
const SPONSORS := [
	"VOLTCOLA", "HYPERION TIRES", "NEKO NITRO", "ORBITAL OIL", "PULSE ENERGY", "ZENITH",
	"GRIDLOCK", "APEX MOTORS", "SPEEDFEST", "MEGAWATT", "SKYLINE AUDIO", "QUANTUM FUEL",
]

var field: SceneryField
var root: Node3D
var rng := RandomNumberGenerator.new()
var floor_y: float = 0.0
var batches := SceneryBatches.new(300.0)
var footprints: Array = []
var ring: Array = []          # Transform3D frames around the bowl (basis.x = outward)
var ring_len: float = 0.0
var stats := {}


func build(p_field: SceneryField, rng_seed: int) -> Node3D:
	field = p_field
	rng.seed = rng_seed
	root = Node3D.new()
	root.name = "ArenaProps"
	floor_y = field.height_percentile(0.1)
	batches.register("neon", SceneryMat.neon(4.0), 0.0, false)
	batches.register("metal", SceneryMat.vcolor(0.5, 0.5, true), 0.0, true)
	batches.register("screen", SceneryMat.shader_mat("screen", {"energy": 2.0}), 0.0, false)
	batches.register("crowd", SceneryMat.shader_mat("crowd"), 0.0, false)
	batches.register("beam", SceneryMat.glow(1, 1.0, 1.4, 900.0), 0.0, false)
	_floor()
	_bowl()
	_towers()
	_jumbotrons()
	_arches()
	_pylons()
	_searchlights()
	batches.build(root)
	_real_lights()
	stats["duplicates"] = 0
	root.set_meta("footprints", footprints)
	root.set_meta("stats", stats)
	return root


func _floor() -> void:
	var t := SceneryTerrain.new(field)
	t.cell = 12.0 if Settings.quality >= 1 else 16.0
	t.margin = 60.0
	t.base = floor_y - 0.3
	t.flat_margin = 3.0
	t.blend = 10.0
	t.elevated_above = 1.5
	t.hole_below = 1.2
	t.far_fn = func(_x: float, _z: float, _s: float, _ry: float, _ed: float, _i: int) -> float: return floor_y - 0.3
	t.compute()
	t.build_meshes(root, SceneryMat.shader_mat("terrain", {"mode": 1}), "Floor")
	var far := MeshInstance3D.new()
	far.name = "GroundFar"
	var pm := PlaneMesh.new()
	pm.size = Vector2(12000, 12000)
	far.mesh = pm
	far.position = field.center() + Vector3(0, floor_y - 0.8, 0)
	far.material_override = SceneryMat.plain(Color(0.015, 0.012, 0.025), 0.6)
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(far)


## Rounded-rectangle ring around the track at `margin` metres, frames with basis.x outward.
func _ring_frames(margin: float, step: float) -> Array:
	var mn := field.bmin - Vector2(margin, margin)
	var mx := field.bmax + Vector2(margin, margin)
	var r := minf(90.0, minf(mx.x - mn.x, mx.y - mn.y) * 0.3)
	var pts: Array = []
	# corner arc centres in order, angle increasing continuously (point = c + (cos a, sin a) in XZ)
	var corners := [Vector2(mx.x - r, mn.y + r), Vector2(mx.x - r, mx.y - r), Vector2(mn.x + r, mx.y - r), Vector2(mn.x + r, mn.y + r)]
	for ci in 4:
		for k in 9:
			var a: float = -PI * 0.5 + PI * 0.5 * ci + PI * 0.5 * k / 8.0
			pts.append(Vector3(corners[ci].x + cos(a) * r, floor_y - 0.3, corners[ci].y + sin(a) * r))
	pts.append(pts[0])
	# resample evenly
	var out: Array = []
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i + 1] - pts[i]).length()
	ring_len = total
	var n := int(total / step)
	var seg := 0
	var acc := 0.0
	for k in n + 1:
		var want := minf(k * step, total - 0.001)
		while seg < pts.size() - 2 and acc + (pts[seg + 1] - pts[seg]).length() < want:
			acc += (pts[seg + 1] - pts[seg]).length()
			seg += 1
		var sl: float = (pts[seg + 1] - pts[seg]).length()
		var p: Vector3 = (pts[seg] as Vector3).lerp(pts[seg + 1], (want - acc) / maxf(sl, 0.001))
		var dir: Vector3 = ((pts[seg + 1] as Vector3) - (pts[seg] as Vector3)).normalized()
		var outward := dir.cross(Vector3.UP).normalized()
		var cen := Vector3((mn.x + mx.x) * 0.5, p.y, (mn.y + mx.y) * 0.5)
		if outward.dot(p - cen) < 0.0:
			outward = -outward
		# basis.x outward, y up, z = x × y (travel direction sign irrelevant for lofts with cull off)
		out.append(Transform3D(Basis(outward, Vector3.UP, outward.cross(Vector3.UP)), p))
	return out


func _bowl() -> void:
	ring = _ring_frames(55.0, 6.0)
	if ring.size() < 4:
		return
	# Orientation: lofts produce faces on one side depending on travel direction. Make sure the
	# profile's "up/inward" side is the visible one: if the ring runs clockwise, flip x sign.
	var tiers := 16
	var crowd := PackedVector2Array()
	for k in tiers + 1:
		var x := 3.0 + k * 1.7
		var y := 4.0 + k * 1.0
		crowd.append(Vector2(x, y))
		crowd.append(Vector2(x + 1.7, y))
	var wall := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 4.0), Vector2(3.0, 4.0)])
	var top_x := 3.0 + (tiers + 1) * 1.7
	var top_y := 4.0 + tiers * 1.0
	var back := PackedVector2Array([Vector2(top_x, top_y), Vector2(top_x, top_y + 6.0), Vector2(top_x + 1.0, top_y + 6.0), Vector2(top_x + 1.0, 0.0)])
	var roof := PackedVector2Array([Vector2(top_x - 18.0, top_y + 12.0), Vector2(top_x + 1.0, top_y + 7.0)])
	# split into chunks so each piece is culled separately
	var per := 40
	var i := 0
	while i < ring.size() - 1:
		var j := mini(i + per, ring.size() - 1)
		var frames := ring.slice(i, j + 1)
		var mid: Transform3D = frames[frames.size() / 2]
		_loft2(batches.at("crowd", mid.origin), crowd, frames, Color(1, 1, 1), i * 6.0)
		_loft2(batches.at("metal", mid.origin), wall, frames, Color(0.06, 0.06, 0.09), 0.0)
		_loft2(batches.at("metal", mid.origin), back, frames, Color(0.07, 0.07, 0.1), 0.0)
		_loft2(batches.at("metal", mid.origin), roof, frames, Color(0.05, 0.05, 0.08), 0.0)
		# neon edge lines: top of the front wall and the roof's leading edge
		var neon := batches.at("neon", mid.origin)
		_loft2(neon, PackedVector2Array([Vector2(-0.05, 3.85), Vector2(-0.05, 4.1)]), frames, CYAN, 0.0)
		_loft2(neon, PackedVector2Array([Vector2(top_x - 18.0, top_y + 11.7), Vector2(top_x - 18.0, top_y + 12.2)]), frames, MAGENTA, 0.0)
		i = j
	# LED sponsor boards on the front wall
	var d := 0.0
	var k2 := 0
	while d < ring_len - 30.0:
		var fi := int(d / 6.0)
		var fj := mini(fi + 4, ring.size() - 1)
		var a: Transform3D = ring[fi]
		var b: Transform3D = ring[fj]
		var inward_a := -a.basis.x
		var inward_b := -b.basis.x
		var p0 := a.origin + inward_a * 0.08
		var p1 := b.origin + inward_b * 0.08
		var col: Color = [CYAN, MAGENTA, AMBER, LIME][k2 % 4]
		var scr := batches.at("screen", p0)
		scr.add_quad(p1 + Vector3(0, 0.4, 0), p1 + Vector3(0, 3.6, 0), p0 + Vector3(0, 3.6, 0), p0 + Vector3(0, 0.4, 0), col, Vector2(4.0, rng.randf()))
		var txt: String = SPONSORS[k2 % SPONSORS.size()]
		var arr := batches.text_arrays(txt)
		var sz := SceneryBatches.arrays_size(arr)
		var mid := (p0 + p1) * 0.5 + Vector3(0, 2.0, 0)
		var face := -((a.basis.x + b.basis.x) * 0.5).normalized()
		var tb := Basis(Vector3.UP.cross(face).normalized(), Vector3.UP, face)
		var s := minf(2.0 / sz.y, (p1 - p0).length() * 0.85 / sz.x)
		batches.at("neon", mid).add_arrays(arr, Transform3D(tb.scaled_local(Vector3(s, s, s)), mid + face * 0.05), Color(1, 1, 1), Vector2(0, 0))
		d += 24.0 + 6.0
		k2 += 1
	stats["ring_m"] = int(ring_len)


## Loft with UV.y offset; materials are double-sided (back faces get flipped normals).
func _loft2(m: SceneryMesh, prof: PackedVector2Array, frames: Array, col: Color, uv_offset: float) -> void:
	var base := m.v.size()
	m.add_loft(prof, frames, col)
	# UV.y = metres along the ring (for the crowd shader)
	for k in range(base, m.v.size()):
		m.uv[k].y += uv_offset


func _towers() -> void:
	if ring.is_empty():
		return
	var n := clampi(int(ring_len / 160.0), 6, 12)
	var cen := field.center()
	var tower_h := 58.0
	var metal_mesh := SceneryProps.flood_tower(tower_h)
	var lamp_mesh := SceneryProps.flood_lamps(tower_h)
	var tm := MultiMeshInstance3D.new()
	var lm := MultiMeshInstance3D.new()
	var xfs: Array = []
	for k in n:
		var fi := int(float(k) / n * (ring.size() - 1))
		var f: Transform3D = ring[fi]
		var p := f.origin + f.basis.x * 38.0
		var to_c := (cen - p)
		to_c.y = 0.0
		to_c = to_c.normalized()
		# lamp bank faces +Z locally: point +Z at the centre
		var b := Basis(Vector3.UP.cross(to_c).normalized(), Vector3.UP, to_c)
		xfs.append(Transform3D(b, p))
		# beams from the lamp bank towards the field, tilted down
		var src := p + Vector3(0, tower_h + 2.5, 0) + to_c * 0.6
		var target := cen + (p - cen) * 0.25 + Vector3(0, floor_y, 0)
		target.y = floor_y
		var dir := (target - src)
		var dl := dir.length()
		dir = dir / dl
		var bb := _basis_from_down(dir)
		var beams := batches.at("beam", src)
		var cone := SceneryProps.beam_cone()
		var arrs := cone.surface_get_arrays(0)
		for bi in 2:
			var off := Vector3(0, 0, 0) + b.x * (-3.0 + bi * 6.0)
			beams.add_arrays(arrs, Transform3D(bb.scaled_local(Vector3(dl * 0.16, dl * 0.85, dl * 0.16)), src + off), Color(0.75, 0.85, 1.0, 0.07))
	_mm(tm, metal_mesh, xfs, SceneryMat.plain(Color(0.12, 0.12, 0.16), 0.5, 0.5))
	_mm(lm, lamp_mesh, xfs, SceneryMat.neon(9.0), Color(0.85, 0.92, 1.0))
	tm.name = "FloodTowers"
	lm.name = "FloodLamps"
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tm)
	root.add_child(lm)
	stats["towers"] = n


## Basis whose local -Y points along `dir` (for beam cones opening along -Y).
func _basis_from_down(dir: Vector3) -> Basis:
	var y := -dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


func _mm(mmi: MultiMeshInstance3D, mesh: Mesh, xfs: Array, mat: Material, col := Color.WHITE) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, col)
	mmi.multimesh = mm
	mmi.material_override = mat


func _jumbotrons() -> void:
	if ring.is_empty():
		return
	var cen := field.center()
	var n := 4
	for k in n:
		var fi := int((float(k) + 0.5) / n * (ring.size() - 1))
		var f: Transform3D = ring[fi]
		var tiers_top := 4.0 + 16.0 + 8.0
		var p := f.origin + f.basis.x * 26.0 + Vector3(0, tiers_top + 14.0, 0)
		var to_c := cen - p
		to_c.y = 0.0
		to_c = to_c.normalized()
		var b := Basis(Vector3.UP.cross(to_c).normalized(), Vector3.UP, to_c)
		var w := 44.0
		var h := 24.0
		var metal := batches.at("metal", p)
		metal.add_box(Transform3D(b, p - to_c * 0.8), Vector3(w + 3.0, h + 3.0, 1.2), Color(0.05, 0.05, 0.07))
		for sx: float in [-1.0, 1.0]:
			metal.add_box(Transform3D(b, p + b.x * w * 0.3 * sx - to_c * 1.5 + Vector3(0, -h * 0.5 - 10.0, 0)), Vector3(1.5, 22.0, 1.5), Color(0.08, 0.08, 0.1))
		var scr := batches.at("screen", p)
		var col: Color = [CYAN, MAGENTA, AMBER, CYAN][k]
		scr.add_quad(p + b * Vector3(-w * 0.5, -h * 0.5, 0), p + b * Vector3(-w * 0.5, h * 0.5, 0), p + b * Vector3(w * 0.5, h * 0.5, 0), p + b * Vector3(w * 0.5, -h * 0.5, 0), col, Vector2([5.0, 3.0, 5.0, 2.0][k], rng.randf()))
		var neon := batches.at("neon", p)
		var txt := "PULSE ARENA" if k % 2 == 0 else "SPEEDFEST"
		var arr := batches.text_arrays(txt)
		var sz := SceneryBatches.arrays_size(arr)
		var s := minf(5.0 / sz.y, w * 0.7 / sz.x)
		neon.add_arrays(arr, Transform3D(b.scaled_local(Vector3(s, s, s)), p + to_c * 0.1 + Vector3(0, -h * 0.05, 0)), Color(1, 1, 1), Vector2(3.0, float(k) * 0.25))
		# frame
		for sy: float in [-1.0, 1.0]:
			neon.add_box(Transform3D(b, p + Vector3(0, (h * 0.5 + 0.8) * sy, 0) + to_c * 0.1), Vector3(w + 2.0, 0.35, 0.2), col, Vector2(4.0, 0.0))
	stats["jumbotrons"] = n


func _arches() -> void:
	var want := clampi(int(field.path.length / 280.0), 3, 7)
	var placed: Array = []
	var tries := 0
	while placed.size() < want and tries < 300:
		tries += 1
		var dm := rng.randf_range(40.0, field.path.length - 40.0)
		if field.zone_near(dm, ["loop", "jump", "tunnel", "no_props", "boost"], 35.0):
			continue
		var ok := true
		for pd in placed:
			if absf(float(pd) - dm) < field.path.length / (want + 2.0):
				ok = false
		if not ok:
			continue
		var i := clampi(int(round(dm / field.path.length * (field.count - 1))), 2, field.count - 3)
		var fr := field.frame(i)
		if fr.basis.y.dot(Vector3.UP) < 0.97:
			continue
		placed.append(dm)
		var yb := SceneryField.yaw_basis(field.fwd[i])
		var r := field.half[i] + 4.5
		var col: Color = CYAN if placed.size() % 2 == 1 else MAGENTA
		var neon := batches.at("neon", fr.origin)
		var metal := batches.at("metal", fr.origin)
		var segs := 28
		for k in segs:
			var a0 := PI * float(k) / segs
			var a1 := PI * float(k + 1) / segs
			var p0 := fr.origin + yb.x * cos(a0) * r + Vector3(0, sin(a0) * r * 0.9 + 1.5, 0)
			var p1 := fr.origin + yb.x * cos(a1) * r + Vector3(0, sin(a1) * r * 0.9 + 1.5, 0)
			var mid := (p0 + p1) * 0.5
			var dir := (p1 - p0)
			var len := dir.length()
			var bx := dir.normalized()
			var bb := Basis(bx, yb.z.cross(bx).normalized(), yb.z)
			metal.add_box(Transform3D(bb, mid), Vector3(len + 0.05, 0.9, 1.2), Color(0.06, 0.06, 0.08))
			neon.add_box(Transform3D(bb, mid - yb.z * 0.62), Vector3(len * 0.8, 0.3, 0.06), col * 0.55, Vector2(4.0, float(k) / segs))
			neon.add_box(Transform3D(bb, mid + yb.z * 0.62), Vector3(len * 0.8, 0.3, 0.06), col * 0.55, Vector2(4.0, float(k) / segs))
		for sx: float in [-1.0, 1.0]:
			var leg := fr.origin + yb.x * r * sx
			metal.add_box(Transform3D(yb, leg + Vector3(0, 0.75, 0)), Vector3(1.4, 1.5, 1.6), Color(0.06, 0.06, 0.08))
			_collision_box(leg + Vector3(0, 1.5, 0), Vector3(1.4, 3.0, 1.6), yb)
			footprints.append([leg, 0.7, "arch_leg", 0.7, 0.8, yb])
		footprints.append([fr.origin + Vector3(0, r, 0), 0.0, "arch", r, 1.0, yb, true])
	stats["arches"] = placed.size()


func _collision_box(p: Vector3, size: Vector3, b: Basis) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.transform = Transform3D(b, p)
	body.add_child(cs)
	root.add_child(body)


func _pylons() -> void:
	var d := 30.0
	var k := 0
	var made := 0
	while d < field.path.length:
		var dm := d
		d += rng.randf_range(45.0, 75.0)
		k += 1
		if field.zone_near(dm, ["loop", "tunnel", "no_props"], 10.0):
			continue
		var i := clampi(int(round(dm / field.path.length * (field.count - 1))), 0, field.count - 1)
		var side := 1.0 if k % 2 == 0 else -1.0
		var yb := SceneryField.yaw_basis(field.fwd[i])
		var p := field.pos[i] + yb.x * side * (field.half[i] + rng.randf_range(9.0, 18.0))
		p.y = floor_y - 0.3
		if field.query(p, 30.0) < 6.0:
			continue
		var h := rng.randf_range(10.0, 22.0)
		var col: Color = [CYAN, MAGENTA, AMBER, LIME][rng.randi_range(0, 3)]
		var metal := batches.at("metal", p)
		var neon := batches.at("neon", p)
		var b := Basis(Vector3.UP, rng.randf_range(0, TAU))
		metal.add_cylinder(Transform3D(b, p), 1.6, 0.5, h, 3, Color(0.05, 0.05, 0.07))
		# neon edges along the three corners
		for e in 3:
			var a := TAU * e / 3.0
			var dir0 := b * Vector3(cos(a), 0, sin(a))
			var p0 := p + dir0 * 1.65
			var p1 := p + dir0 * 0.55 + Vector3(0, h, 0)
			var mid := (p0 + p1) * 0.5
			var ax := (p1 - p0).normalized()
			var bb := Basis(ax.cross(dir0).normalized(), ax, dir0).orthonormalized()
			neon.add_box(Transform3D(bb, mid), Vector3(0.12, (p1 - p0).length(), 0.12), col, Vector2(3.0, rng.randf()))
		neon.add_box(Transform3D(b, p + Vector3(0, h + 0.4, 0)), Vector3(0.8, 0.8, 0.8), col, Vector2(2.0, rng.randf()))
		footprints.append([p, 1.6, "pylon", 1.6, 1.6, Basis.IDENTITY])
		made += 1
	stats["pylons"] = made


func _searchlights() -> void:
	# Sweeping sky beams from the stadium corners (rotated by SceneryRotor).
	if ring.is_empty() or (Settings.is_compat() and Settings.quality < 1):
		return
	var mat := SceneryMat.glow(1, 1.0, 1.0, 2500.0)
	var cone := SceneryProps.beam_cone()
	for k in 4:
		var fi := int((float(k) + 0.125) / 4.0 * (ring.size() - 1))
		var f: Transform3D = ring[fi]
		var rot := SceneryRotor.new()
		rot.name = "Searchlight%d" % k
		rot.position = f.origin + f.basis.x * 30.0 + Vector3(0, 30.0, 0)
		rot.speed = 0.25 + 0.1 * k
		rot.phase = k * 1.7
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# cone opens along -Y: tilt so it points up and outwards
		mi.basis = Basis(Vector3.RIGHT, PI * 0.82).scaled_local(Vector3(18, 600, 18))
		var col := CYAN if k % 2 == 0 else MAGENTA
		var m := SceneryMesh.new()
		m.add_arrays(cone.surface_get_arrays(0), Transform3D.IDENTITY, Color(col.r, col.g, col.b, 0.05))
		mi.mesh = m.commit()
		rot.add_child(mi)
		root.add_child(rot)


func _real_lights() -> void:
	# A few coloured omni lights near arches (Forward+), none on low-end Compatibility.
	var budget := Settings.light_budget()
	var n := 0 if Settings.is_compat() and Settings.quality < 2 else mini(budget / 4, 12)
	var made := 0
	for fp in footprints:
		if made >= n:
			break
		if fp[2] != "arch":
			continue
		var ol := OmniLight3D.new()
		ol.position = (fp[0] as Vector3) + Vector3(0, -2.0, 0)
		ol.omni_range = 26.0
		ol.light_energy = 3.0
		ol.light_color = CYAN if made % 2 == 0 else MAGENTA
		ol.distance_fade_enabled = true
		ol.distance_fade_begin = 200.0
		ol.distance_fade_length = 50.0
		root.add_child(ol)
		made += 1
