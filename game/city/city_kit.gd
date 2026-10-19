class_name CityKit
extends RefCounted
## "city" theme props: rain-wet night downtown. Skyscrapers with lit windows (MultiMesh +
## window shader), original neon signs, street lamps with fake light pools, billboards,
## overhead gantries and puddles.

const NEON := [
	Color(0.0, 0.9, 1.0), Color(1.0, 0.17, 0.84), Color(1.0, 0.7, 0.0), Color(0.65, 1.0, 0.0),
	Color(1.0, 0.15, 0.2), Color(0.55, 0.3, 1.0), Color(0.85, 0.92, 1.0), Color(1.0, 0.45, 0.1),
]
const BRANDS := [
	"SPEEDFEST", "NEKO RAMEN", "VOLTCOLA", "KAIJU BAR", "HOTEL ORBIT", "24H", "NITRO GARAGE",
	"PIXEL ARCADE", "OKAMI", "LUNA CLUB", "ZERO-G", "SYNTH MOTEL", "DRIFT KINGS", "MOTOR OIL",
	"SUSHI", "KARAOKE", "TURBO", "NEON NOODLE", "CYBER CAFE", "APEX", "HYPERDRIVE", "BAR", "OPEN",
	"PACHINKO", "MIDNIGHT", "RED LINE", "STREET HEAT", "VAPOR", "GRID 9", "UNDERGLOW",
]
const VERTICAL := ["HOTEL", "BAR", "SUSHI", "RAMEN", "CLUB", "NEKO", "DRIFT", "TURBO", "OKAMI", "24H"]

var field: SceneryField
var root: Node3D
var rng := RandomNumberGenerator.new()
var ground_y: float = 0.0
var _deck_h: float = 0.0        # deck height above ground next to the building being placed
var batches := SceneryBatches.new(300.0)
var occupancy: Dictionary = {}     # Vector2i (4 m cells) -> true
var footprints: Array = []         # [pos, radius, kind] for tests
var lamp_spots: Array = []         # Transform3D of lamp heads (for real lights)
var neon_spots: Array = []         # [position in front of a sign/billboard, colour, size] (real lights)
var n_buildings := 0
var n_signs := 0

var _bld: SceneryInstances
var _poles: SceneryInstances
var _heads: SceneryInstances
var _pools: SceneryInstances
var _cones: SceneryInstances


func build(p_field: SceneryField, rng_seed: int) -> Node3D:
	field = p_field
	rng.seed = rng_seed
	root = Node3D.new()
	root.name = "CityProps"
	ground_y = field.ground_level()
	var bmat := SceneryMat.shader_mat("building", {"wetness": 0.7, "window_energy": 1.25})
	_bld = SceneryInstances.new(SceneryProps.unit_box(), bmat, 400.0, false, true)
	_poles = SceneryInstances.new(SceneryProps.street_lamp_pole(), SceneryMat.plain(Color(0.2, 0.21, 0.23), 0.4, 0.6), 250.0)
	_heads = SceneryInstances.new(SceneryProps.street_lamp_head(), SceneryMat.neon(5.0), 250.0, true)
	_pools = SceneryInstances.new(SceneryProps.ground_quad(), SceneryMat.glow(0, 1.0, 1.6, 420.0), 250.0, true)
	_cones = SceneryInstances.new(SceneryProps.beam_cone(), SceneryMat.glow(1, 1.0, 1.3, 300.0), 250.0, true)
	batches.register("neon", SceneryMat.neon(4.5), 700.0, false)
	batches.register("board", SceneryMat.vcolor(0.35, 0.3), 600.0, true)
	batches.register("metal", SceneryMat.vcolor(0.45, 0.6), 600.0, true)
	batches.register("screen", SceneryMat.shader_mat("screen", {"energy": 2.2}), 700.0, false)
	_ground()
	_reserve_track_buildings()
	_frontage()
	_backfill()
	_skyline()
	_lamps()
	_gantries()
	_billboards_on_poles()
	_bld.build(root, "Buildings", 0.0, true)
	_poles.build(root, "LampPoles", 450.0, true)
	_heads.build(root, "LampHeads", 700.0, false)
	_pools.build(root, "LightPools", 420.0, false)
	if Settings.quality >= 1:
		_cones.build(root, "LightCones", 260.0, false)
	batches.build(root)
	_real_lights()
	_puddles()
	root.set_meta("footprints", footprints)
	root.set_meta("stats", {"buildings": n_buildings, "signs": n_signs, "lamps": _poles.count})
	return root


# --- ground -------------------------------------------------------------------

func _ground() -> void:
	var t := SceneryTerrain.new(field)
	t.cell = 10.0 if Settings.quality >= 1 else 14.0
	t.margin = 420.0
	t.base = ground_y - 0.3
	t.flat_margin = 4.0
	t.blend = 18.0
	t.elevated_above = 2.5
	t.hole_below = 1.2
	t.shoulder_drop = 0.25
	t.deck_clear = 2.0
	t.far_fn = func(_x: float, _z: float, _s: float, _ry: float, _ed: float, _i: int) -> float: return ground_y - 0.3
	t.compute()
	t.build_meshes(root, _ground_material(), "Ground")
	# endless dark ground beyond the grid
	var far := MeshInstance3D.new()
	far.name = "GroundFar"
	var pm := PlaneMesh.new()
	pm.size = Vector2(12000, 12000)
	far.mesh = pm
	far.position = field.center() + Vector3(0, ground_y - 0.6, 0)
	far.material_override = SceneryMat.plain(Color(0.02, 0.02, 0.025), 0.4)
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far.set_meta("scenery_ground", true)
	root.add_child(far)


## Wet city asphalt between the buildings: dark, glossy enough for the neon to streak on it.
func _ground_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.030, 0.031, 0.038)
	m.roughness = 0.22
	m.metallic = 0.35
	m.metallic_specular = 0.75
	return m


# --- occupancy ----------------------------------------------------------------

func _cells_of(c: Vector3, xd: Vector3, zd: Vector3, hx: float, hz: float) -> Array:
	var out: Array = []
	var r := sqrt(hx * hx + hz * hz)
	var i0 := floori((c.x - r) / 4.0)
	var i1 := floori((c.x + r) / 4.0)
	var j0 := floori((c.z - r) / 4.0)
	var j1 := floori((c.z + r) / 4.0)
	for i in range(i0, i1 + 1):
		for j in range(j0, j1 + 1):
			var p := Vector3(i * 4.0 + 2.0, 0, j * 4.0 + 2.0) - c
			if absf(p.dot(xd)) <= hx + 1.0 and absf(p.dot(zd)) <= hz + 1.0:
				out.append(Vector2i(i, j))
	return out


## Footprints of the track's own buildings (res://tracks/track_buildings.gd, path meta "reserved":
## [[center, x_axis, z_axis, hx, hz], ...]): random buildings stay out of them.
func _reserve_track_buildings() -> void:
	if not field.path.has_meta("reserved"):
		return
	for r: Array in field.path.get_meta("reserved"):
		_claim(_cells_of(r[0], r[1], r[2], float(r[3]) + 2.0, float(r[4]) + 2.0))


func _free(cells: Array) -> bool:
	for k in cells:
		if occupancy.has(k):
			return false
	return true


func _claim(cells: Array) -> void:
	for k in cells:
		occupancy[k] = true


# --- buildings ----------------------------------------------------------------

## One building = podium + optional tower + crown; `front` is the facade normal facing the road.
func _add_building(c: Vector3, b: Basis, w: float, dpt: float, h: float, front: Vector3, near_road: bool) -> void:
	var seed := rng.randf()
	var style: float = [0.1, 0.1, 0.35, 0.7][rng.randi_range(0, 3)]
	var lit := rng.randf_range(0.12, 0.4)
	var tint := rng.randf_range(0.15, 0.85)
	var cus := Color(seed, style, lit, tint)
	var podium_h := h
	# next to a high deck keep facades flat so deck-level signs sit on the main face
	var tall := h > 45.0 and _deck_h <= 8.0
	if tall:
		podium_h = rng.randf_range(8.0, 16.0)
	_bld.add(Transform3D(b.scaled_local(Vector3(w, podium_h, dpt)), c), Color.WHITE, cus)
	var top_w := w
	var top_d := dpt
	var top_y := podium_h
	if tall:
		var sw := rng.randf_range(0.55, 0.85)
		var sd := rng.randf_range(0.55, 0.85)
		top_w = w * sw
		top_d = dpt * sd
		var off := b.z * (dpt - top_d) * 0.5 * rng.randf_range(0.0, 1.0)
		var tc := c + off + Vector3(0, podium_h, 0)
		var th := h - podium_h
		var cus2 := Color(fmod(seed + 0.37, 1.0), [0.35, 0.35, 0.7, 0.1][rng.randi_range(0, 3)], lit, tint)
		_bld.add(Transform3D(b.scaled_local(Vector3(top_w, th, top_d)), tc), Color.WHITE, cus2)
		top_y = h
		c = tc - Vector3(0, podium_h, 0)
		if rng.randf() < 0.45:
			# crown
			var cw := top_w * rng.randf_range(0.5, 0.8)
			var cd := top_d * rng.randf_range(0.5, 0.8)
			var ch := rng.randf_range(4.0, 14.0)
			_bld.add(Transform3D(b.scaled_local(Vector3(cw, ch, cd)), c + Vector3(0, h, 0)), Color.WHITE, Color(seed, 0.7, lit * 0.5, tint))
			top_y = h + ch
			top_w = cw
			top_d = cd
	# rooftop boxes (no windows: lit fraction 0)
	var roof_n := rng.randi_range(0, 3)
	for i in roof_n:
		var rw := rng.randf_range(2.0, 6.0)
		var rp := c + b.x * rng.randf_range(-top_w * 0.3, top_w * 0.3) + b.z * rng.randf_range(-top_d * 0.3, top_d * 0.3)
		_bld.add(Transform3D(b.scaled_local(Vector3(rw, rng.randf_range(1.5, 3.5), rw * rng.randf_range(0.6, 1.4))), rp + Vector3(0, top_y, 0)), Color.WHITE, Color(seed, 0.1, 0.0, 0.5))
	# antenna with a blinking red aviation light on tall towers
	var neon := batches.at("neon", c)
	if top_y > 70.0:
		var metal := batches.at("metal", c)
		var ah := rng.randf_range(8.0, 25.0)
		metal.add_box(Transform3D(Basis.IDENTITY, c + Vector3(0, top_y + ah * 0.5, 0)), Vector3(0.35, ah, 0.35), Color(0.15, 0.15, 0.17))
		neon.add_box(Transform3D(Basis.IDENTITY, c + Vector3(0, top_y + ah + 0.3, 0)), Vector3(0.7, 0.7, 0.7), Color(1.0, 0.08, 0.05), Vector2(2.0, rng.randf()))
	# glowing edge strip along the roof line of some towers
	if top_y > 30.0 and rng.randf() < 0.4:
		var col: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
		var y := top_y - 0.4
		var hx := top_w * 0.5 + 0.08
		var hz := top_d * 0.5 + 0.08
		for sgn: float in [-1.0, 1.0]:
			neon.add_box(Transform3D(b, c + b.z * hz * sgn + Vector3(0, y, 0)), Vector3(top_w + 0.2, 0.25, 0.12), col * 0.9, Vector2(0, 0))
			neon.add_box(Transform3D(b, c + b.x * hx * sgn + Vector3(0, y, 0)), Vector3(0.12, 0.25, top_d + 0.2), col * 0.9, Vector2(0, 0))
	n_buildings += 1
	if near_road:
		_facade_dressing(c, b, w, dpt, podium_h if tall else h, front, h)


## Neon signs and awnings on a road-facing facade.
func _facade_dressing(c: Vector3, b: Basis, w: float, dpt: float, podium_h: float, front: Vector3, total_h: float) -> void:
	# facade plane: centre of the front face
	var fz := front.normalized()
	var fx := Vector3.UP.cross(fz).normalized()
	var half_extent := absf(fz.dot(b.z)) * dpt * 0.5 + absf(fz.dot(b.x)) * w * 0.5
	var along := absf(fx.dot(b.x)) * w + absf(fx.dot(b.z)) * dpt
	var face_c := c + fz * (half_extent + 0.25)
	var neon := batches.at("neon", face_c)
	var board := batches.at("board", face_c)
	var sb := Basis(fx, Vector3.UP, fz)
	if _deck_h > 8.0:
		_deck_signs(c, fz, fx, half_extent, along, face_c, sb, total_h)
		return
	# shop-front glow strip
	var strip_col: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
	if rng.randf() < 0.7:
		neon.add_box(Transform3D(sb, face_c + Vector3(0, 3.6, 0.0)), Vector3(along * 0.9, 0.12, 0.1), strip_col * 0.8, Vector2(0, 0))
	# horizontal sign above the shop
	if rng.randf() < 0.75:
		var txt: String = BRANDS[rng.randi_range(0, BRANDS.size() - 1)]
		var lh := rng.randf_range(1.0, 1.8)
		var y := rng.randf_range(4.6, minf(podium_h - lh - 0.5, 9.0))
		if y > 4.0:
			var col: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
			var off := fx * rng.randf_range(-along * 0.2, along * 0.2)
			_sign(face_c + off + Vector3(0, y, 0.05), sb, txt, lh, col, along * 0.85, true)
	# vertical blade sign sticking out towards the road at a facade end
	if rng.randf() < 0.45 and podium_h > 12.0:
		var txt2: String = VERTICAL[rng.randi_range(0, VERTICAL.size() - 1)]
		var letters := txt2.length()
		var lh2 := rng.randf_range(1.3, 1.9)
		var col2: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
		var xoff := (along * 0.5 - 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var blade_h := letters * lh2 * 1.15 + 1.0
		var y0 := clampf(rng.randf_range(5.0, podium_h - blade_h - 1.0), 4.5, 60.0)
		var bc := face_c + fx * xoff + fz * 0.9 + Vector3(0, y0 + blade_h * 0.5, 0)
		# blade board perpendicular to the facade, text on both sides
		var bb := Basis(fz, Vector3.UP, -fx)
		board.add_box(Transform3D(bb, bc), Vector3(1.6, blade_h, 0.25), Color(0.03, 0.03, 0.04))
		neon.add_box(Transform3D(bb, bc), Vector3(1.75, blade_h + 0.15, 0.12), col2 * 0.35, Vector2(0, 0))
		var mode := 1.0 if rng.randf() < 0.3 else 0.0
		for side: float in [-1.0, 1.0]:
			var sbx := Basis(fz * side, Vector3.UP, -fx * side)
			for li in letters:
				var ch := txt2.substr(li, 1)
				var arr := batches.text_arrays(ch)
				var sz := SceneryBatches.arrays_size(arr)
				if sz.y <= 0.0:
					continue
				var s := lh2 / sz.y
				var ly := blade_h * 0.5 - 0.5 - lh2 * 0.5 - li * lh2 * 1.15
				var p := bc + sbx.z * 0.14 + Vector3(0, ly, 0)
				neon.add_arrays(arr, Transform3D(sbx.scaled_local(Vector3(s, s, s)), p), col2, Vector2(mode, rng.randf()))
		n_signs += 1
	# big rooftop sign on lower buildings
	if total_h < 40.0 and rng.randf() < 0.22:
		var txt3: String = BRANDS[rng.randi_range(0, 6)]
		var lh3 := rng.randf_range(3.0, 5.0)
		var col3: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
		var pc := c + fz * (half_extent - 2.0) + Vector3(0, total_h + lh3 * 0.5 + 1.2, 0)
		var metal := batches.at("metal", pc)
		var wsign := minf(along * 0.95, lh3 * txt3.length() * 0.95)
		for k in 3:
			var px := (float(k) - 1.0) * wsign * 0.4
			metal.add_box(Transform3D(sb, pc + fx * px + Vector3(0, -lh3 * 0.5 - 0.6, -0.5)), Vector3(0.25, 1.4 + lh3 * 0.4, 0.25), Color(0.12, 0.12, 0.13))
		_sign(pc, sb, txt3, lh3, col3, wsign, false)


## Signs readable from a deck at rooftop height: big signs at deck level on taller buildings,
## rooftop signs facing the road on lower ones (seen from above).
func _deck_signs(c: Vector3, fz: Vector3, fx: Vector3, half_extent: float, along: float, face_c: Vector3, sb: Basis, total_h: float) -> void:
	var col: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
	if total_h > _deck_h + 6.0:
		if rng.randf() < 0.8:
			var txt: String = BRANDS[rng.randi_range(0, BRANDS.size() - 1)]
			var lh := rng.randf_range(2.5, 4.5)
			var y := clampf(_deck_h + rng.randf_range(-1.0, 7.0), lh, total_h - lh - 1.0)
			_sign(face_c + fx * rng.randf_range(-along * 0.15, along * 0.15) + Vector3(0, y, 0.05), sb, txt, lh, col, along * 0.85, true)
		if rng.randf() < 0.35:
			var stripe := NEON[rng.randi_range(0, NEON.size() - 1)] as Color
			var neon := batches.at("neon", face_c)
			for k in 3:
				neon.add_box(Transform3D(sb, face_c + Vector3(0, _deck_h - 4.0 + k * 5.0, 0.0)), Vector3(along * 0.95, 0.18, 0.12), stripe * 0.8, Vector2(4.0, float(k) * 0.3))
	elif total_h > 10.0 and rng.randf() < 0.55:
		var txt3: String = BRANDS[rng.randi_range(0, BRANDS.size() - 1)]
		var lh3 := rng.randf_range(3.5, 6.0)
		var pc := c + fz * (half_extent - 2.0) + Vector3(0, total_h + lh3 * 0.5 + 1.2, 0)
		var metal := batches.at("metal", pc)
		var wsign := minf(along * 0.95, lh3 * txt3.length() * 0.95)
		for k in 3:
			var px := (float(k) - 1.0) * wsign * 0.4
			metal.add_box(Transform3D(sb, pc + fx * px + Vector3(0, -lh3 * 0.5 - 0.6, -0.5)), Vector3(0.25, 1.4 + lh3 * 0.4, 0.25), Color(0.12, 0.12, 0.13))
		# tilt the sign back a little so it reads from the deck above
		var tb := sb.rotated(fx, -0.35)
		_sign(pc, tb, txt3, lh3, col, wsign, false)


## Text sign with a dark backing board and a thin neon frame. Fits in max_w.
func _sign(p: Vector3, b: Basis, txt: String, letter_h: float, col: Color, max_w: float, frame: bool) -> void:
	var arr := batches.text_arrays(txt)
	var sz := SceneryBatches.arrays_size(arr)
	if sz.x <= 0.0:
		return
	var s := letter_h / sz.y
	if sz.x * s > max_w:
		s = max_w / sz.x
	var tw := sz.x * s
	var th := sz.y * s
	var neon := batches.at("neon", p)
	var board := batches.at("board", p)
	var mode := 0.0
	var r := rng.randf()
	if r < 0.18:
		mode = 1.0
	elif r < 0.3:
		mode = 3.0
	board.add_box(Transform3D(b, p - b.z * 0.12), Vector3(tw + th * 0.8, th * 1.6, 0.2), Color(0.025, 0.025, 0.035))
	if frame:
		var fw := tw + th * 0.8
		var fh := th * 1.6
		var fc := col * 0.75
		neon.add_box(Transform3D(b, p + b.y * fh * 0.5), Vector3(fw, 0.07, 0.07), fc, Vector2(0, 0))
		neon.add_box(Transform3D(b, p - b.y * fh * 0.5), Vector3(fw, 0.07, 0.07), fc, Vector2(0, 0))
		neon.add_box(Transform3D(b, p + b.x * fw * 0.5), Vector3(0.07, fh, 0.07), fc, Vector2(0, 0))
		neon.add_box(Transform3D(b, p - b.x * fw * 0.5), Vector3(0.07, fh, 0.07), fc, Vector2(0, 0))
	neon.add_arrays(arr, Transform3D(b.scaled_local(Vector3(s, s, s)), p + b.z * 0.02), col, Vector2(mode, rng.randf()))
	n_signs += 1
	neon_spots.append([p + b.z * (1.5 + th), col, maxf(tw, th)])


func _frontage() -> void:
	for side: float in [-1.0, 1.0]:
		var d := rng.randf_range(0.0, 20.0)
		while d < field.path.length - 5.0:
			var frontage := rng.randf_range(16.0, 34.0)
			var gap := rng.randf_range(2.0, 8.0)
			var dm := d + frontage * 0.5
			d += frontage + gap
			if field.zone_near(dm, ["no_props"], 5.0):
				continue
			var i := clampi(int(round(dm / field.path.length * (field.count - 1))), 0, field.count - 1)
			var fr := field.frame(i)
			var road_y := fr.origin.y
			var b := SceneryField.yaw_basis(field.fwd[i])
			var right := b.x
			var setback := field.half[i] + rng.randf_range(6.0, 9.0)
			var depth := rng.randf_range(18.0, 36.0)
			var c := fr.origin + right * side * (setback + depth * 0.5)
			c.y = ground_y - 0.3
			var hx := frontage * 0.5
			var hz := depth * 0.5
			# building basis: x along the road, z across (towards the road for side = +1 is -right)
			var bb := Basis(b.z, Vector3.UP, -b.x)  # x along road (backwards), z = right
			var clear := field.rect_clearance(c, bb.x, bb.z, hx, hz, 30.0)
			if clear < 4.5:
				# try a shallower building closer to the road
				depth *= 0.6
				hz = depth * 0.5
				c = fr.origin + right * side * (setback + hz)
				c.y = ground_y - 0.3
				clear = field.rect_clearance(c, bb.x, bb.z, hx, hz, 30.0)
				if clear < 4.5:
					continue
			var cells := _cells_of(c, bb.x, bb.z, hx, hz)
			if not _free(cells):
				continue
			_claim(cells)
			var h := _pick_height(c, true)
			_deck_h = road_y - ground_y if field.is_deck(i, ground_y) else 0.0
			if _deck_h > 8.0:
				# towers below, beside and above the deck
				if rng.randf() < 0.55:
					h = _deck_h + rng.randf_range(8.0, 70.0)
				else:
					h = maxf(8.0, (_deck_h - 6.0) * rng.randf_range(0.35, 0.9))
			_add_building(c, bb, frontage, depth, h, -right * side, true)
			_deck_h = 0.0
			footprints.append([c, 0.0, "building", hx, hz, bb])


func _pick_height(c: Vector3, near_road: bool) -> float:
	var r := rng.randf()
	var dc := Vector2(c.x - field.center().x, c.z - field.center().z).length()
	var core := exp(-pow(dc / maxf(field.extent().length() * 0.45, 200.0), 2.0))
	var h: float
	if r < 0.6:
		h = rng.randf_range(12.0, 38.0)
	elif r < 0.9:
		h = rng.randf_range(38.0, 80.0)
	else:
		h = rng.randf_range(80.0, 150.0)
	h *= 0.7 + core * (0.9 if not near_road else 0.5)
	return h


func _backfill() -> void:
	var spacing := 34.0
	var mn := field.bmin - Vector2(380, 380)
	var mx := field.bmax + Vector2(380, 380)
	var x := mn.x
	while x < mx.x:
		var z := mn.y
		while z < mx.y:
			var c := Vector3(x + rng.randf_range(-4, 4), ground_y - 0.3, z + rng.randf_range(-4, 4))
			z += spacing
			var w := rng.randf_range(16.0, 28.0)
			var dpt := rng.randf_range(16.0, 28.0)
			var bb := Basis(Vector3.UP, rng.randf_range(-0.08, 0.08))
			var clear := field.rect_clearance(c, bb.x, bb.z, w * 0.5, dpt * 0.5, 40.0)
			if clear < 10.0:
				continue
			var cells := _cells_of(c, bb.x, bb.z, w * 0.5, dpt * 0.5)
			if not _free(cells):
				continue
			_claim(cells)
			var h := _pick_height(c, false)
			if clear < 40.0:
				h = minf(h, 70.0)
			_add_building(c, bb, w, dpt, h, Vector3.FORWARD, false)
			footprints.append([c, 0.0, "building", w * 0.5, dpt * 0.5, bb])
		x += spacing


func _skyline() -> void:
	# Very tall towers on a ring far away: the silhouette against the glowing clouds.
	var cen := field.center()
	var rad := field.extent().length() * 0.5 + 520.0
	var n := 46
	for i in n:
		var a := TAU * float(i) / n + rng.randf_range(-0.05, 0.05)
		var r := rad + rng.randf_range(0.0, 450.0)
		var c := cen + Vector3(cos(a) * r, ground_y - 0.3, sin(a) * r)
		var w := rng.randf_range(30.0, 60.0)
		var bb := Basis(Vector3.UP, rng.randf_range(0.0, PI))
		_add_building(c, bb, w, w * rng.randf_range(0.7, 1.3), rng.randf_range(120.0, 320.0), Vector3.FORWARD, false)


# --- street furniture ----------------------------------------------------------

func _lamps() -> void:
	var spacing := 34.0
	var warm := Color(1.0, 0.6, 0.25)
	var cool := Color(0.65, 0.8, 1.0)
	for side: float in [-1.0, 1.0]:
		var d := spacing * 0.5 if side > 0 else 0.0
		while d < field.path.length:
			var dm := d
			d += spacing
			if field.zone_near(dm, ["tunnel", "no_props", "loop", "jump"], 6.0):
				continue
			var i := clampi(int(round(dm / field.path.length * (field.count - 1))), 0, field.count - 1)
			var fr := field.frame(i)
			var elevated := field.is_deck(i, ground_y, 2.0)
			if elevated:
				continue   # open platform decks: no lamp posts in the air
			var lateral := field.half[i] + 2.6
			var base := fr.origin + fr.basis.x * side * lateral
			if not elevated:
				base.y = fr.origin.y - 0.05
			if not elevated and field.query(base, 20.0) < 2.2:
				continue
			# the pole's arm points along local -X: face it towards the road centre
			var to_road := fr.origin - base
			to_road.y = 0.0
			to_road = to_road.normalized() if to_road.length_squared() > 1e-4 else -fr.basis.x * side
			var lb := Basis(-to_road, Vector3.UP, (-to_road).cross(Vector3.UP).normalized())
			var xf := Transform3D(lb, base)
			var col := warm if (int(dm / 400.0) % 3) != 1 else cool
			_poles.add(xf)
			_heads.add(xf, col)
			var head := xf * Vector3(-2.75, 8.6, 0)
			lamp_spots.append(Transform3D(Basis.IDENTITY, head))
			# light pool on the road below the head
			var pool_c := head
			pool_c.y = fr.origin.y + 0.06 + (fr.basis.x.dot(head - fr.origin) * fr.basis.x.y)
			var pb := Basis(fr.basis.x, fr.basis.y, fr.basis.z).scaled_local(Vector3(15, 1, 15))
			_pools.add(Transform3D(pb, pool_c), Color(col.r, col.g, col.b, 0.42 if col == warm else 0.26))
			var cb := Basis.IDENTITY.scaled_local(Vector3(3.6, 8.4, 3.6))
			_cones.add(Transform3D(cb, head), Color(col.r, col.g, col.b, 0.09))
			footprints.append([base, 0.5, "lamp", 0.3, 0.3, Basis.IDENTITY, elevated])


func _gantries() -> void:
	# Overhead sign gantries on straight sections (intentional road-spanning props).
	var want := clampi(int(field.path.length / 600.0), 2, 5)
	var placed: Array = []
	var tries := 0
	var texts := ["SPEEDFEST", "DOWNTOWN", "NEON DISTRICT", "HARBOR >", "< AIRPORT", "EXIT 7", "SPEED KILLS", "DRIVE SAFE"]
	while placed.size() < want and tries < 200:
		tries += 1
		var dm := rng.randf_range(60.0, field.path.length - 60.0)
		if field.zone_near(dm, ["tunnel", "loop", "jump", "no_props", "wallride"], 40.0):
			continue
		var ok := true
		for pd in placed:
			if absf(pd - dm) < field.path.length / (want + 1.0) * 0.8:
				ok = false
		if not ok:
			continue
		var i := clampi(int(round(dm / field.path.length * (field.count - 1))), 2, field.count - 3)
		# straightness check
		var i2 := clampi(i + 6, 0, field.count - 1)
		var i0 := clampi(i - 6, 0, field.count - 1)
		if field.fwd[i0].dot(field.fwd[i2]) < 0.985:
			continue
		placed.append(dm)
		var fr := field.frame(i)
		var yb := SceneryField.yaw_basis(field.fwd[i])
		var hw := field.half[i] + 2.6
		var top := 7.6
		var metal := batches.at("metal", fr.origin)
		var neon := batches.at("neon", fr.origin)
		var screen := batches.at("screen", fr.origin)
		var mcol := Color(0.25, 0.26, 0.28)
		for side: float in [-1.0, 1.0]:
			var pp := fr.origin + yb.x * side * hw
			# on a deck the posts run all the way down to the street
			var bottom := ground_y - 0.3 if field.is_deck(i, ground_y) else fr.origin.y - 0.3
			var post_h := fr.origin.y + top + 0.9 - bottom
			metal.add_box(Transform3D(yb, Vector3(pp.x, bottom + post_h * 0.5, pp.z)), Vector3(0.6, post_h, 0.6), mcol)
			_post_collision(pp, Vector3(0.6, top + 1.2, 0.6), yb)
		for k in 2:
			metal.add_box(Transform3D(yb, fr.origin + Vector3(0, top + 0.2 + k * 1.0, 0)), Vector3(hw * 2.0 + 0.6, 0.25, 0.25), mcol)
		var pw := minf(hw * 0.8, 8.0)
		for s2: float in [-1.0, 1.0]:
			var pc := fr.origin + yb.x * s2 * (hw * 0.45) + Vector3(0, top + 1.6, 0) - yb.z * 0.3
			var pb := Basis(yb.x, Vector3.UP, -yb.z)   # face against travel (towards drivers)
			screen.add_quad(pc + pb * Vector3(-pw * 0.5, -1.3, 0.0), pc + pb * Vector3(-pw * 0.5, 1.3, 0.0), pc + pb * Vector3(pw * 0.5, 1.3, 0.0), pc + pb * Vector3(pw * 0.5, -1.3, 0.0), Color(0.1, 0.4, 1.0), Vector2(1.0, rng.randf()))
			var txt: String = texts[rng.randi_range(0, texts.size() - 1)]
			var arr := batches.text_arrays(txt)
			var sz := SceneryBatches.arrays_size(arr)
			var s := minf(1.1 / sz.y, pw * 0.85 / sz.x)
			neon.add_arrays(arr, Transform3D(pb.scaled_local(Vector3(s, s, s)), pc + pb.z * 0.05), Color(0.95, 0.97, 1.0), Vector2(0, 0))
		footprints.append([fr.origin + Vector3(0, top, 0), 0.0, "gantry", hw, 0.5, yb, true])


func _post_collision(p: Vector3, size: Vector3, b: Basis) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.transform = Transform3D(b, p + Vector3(0, size.y * 0.5 - 0.3, 0))
	body.add_child(cs)
	root.add_child(body)


func _billboards_on_poles() -> void:
	# Big animated billboards on tall poles in open lots next to the road.
	var n := clampi(int(field.path.length / 350.0), 3, 10)
	var tries := 0
	var made := 0
	while made < n and tries < 120:
		tries += 1
		var dm := rng.randf_range(0.0, field.path.length)
		var i := clampi(int(round(dm / field.path.length * (field.count - 1))), 0, field.count - 1)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var fr := field.frame(i)
		var yb := SceneryField.yaw_basis(field.fwd[i])
		var lat := field.half[i] + rng.randf_range(10.0, 16.0)
		var base := fr.origin + yb.x * side * lat
		base.y = ground_y - 0.3
		if field.query(base, 30.0) < 8.0:
			continue
		var cells := _cells_of(base, yb.x, yb.z, 1.5, 1.5)
		if not _free(cells):
			continue
		_claim(cells)
		var bw := rng.randf_range(14.0, 20.0)
		var bh := bw * 0.5
		var ph := rng.randf_range(12.0, 18.0)
		if field.is_deck(i, ground_y):
			ph = fr.origin.y - ground_y + rng.randf_range(-1.0, 6.0)   # readable from the deck
		# face oncoming drivers, angled towards the road
		var face := (-yb.z * 0.8 - yb.x * side * 0.6).normalized()
		var fb := Basis(Vector3.UP.cross(face).normalized(), Vector3.UP, face)
		var metal := batches.at("metal", base)
		metal.add_cylinder(Transform3D(Basis.IDENTITY, base), 0.7, 0.5, ph, 8, Color(0.2, 0.2, 0.22))
		var pc := base + Vector3(0, ph + bh * 0.5, 0)
		metal.add_box(Transform3D(fb, pc - face * 0.35), Vector3(bw + 0.8, bh + 0.8, 0.5), Color(0.1, 0.1, 0.11))
		_billboard_panel(pc, fb, bw, bh)
		made += 1
		footprints.append([base, 1.0, "billboard", 0.7, 0.7, Basis.IDENTITY])


func _billboard_panel(pc: Vector3, fb: Basis, bw: float, bh: float) -> void:
	var screen := batches.at("screen", pc)
	var neon := batches.at("neon", pc)
	var col: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
	neon_spots.append([pc + fb.z * 4.0, col, bw])
	screen.add_quad(pc + fb * Vector3(-bw * 0.5, -bh * 0.5, 0), pc + fb * Vector3(-bw * 0.5, bh * 0.5, 0), pc + fb * Vector3(bw * 0.5, bh * 0.5, 0), pc + fb * Vector3(bw * 0.5, -bh * 0.5, 0), col, Vector2(float(rng.randi_range(2, 4)), rng.randf()))
	var txt: String = BRANDS[rng.randi_range(0, BRANDS.size() - 1)]
	var arr := batches.text_arrays(txt)
	var sz := SceneryBatches.arrays_size(arr)
	var s := minf(bh * 0.32 / sz.y, bw * 0.8 / sz.x)
	neon.add_arrays(arr, Transform3D(fb.scaled_local(Vector3(s, s, s)), pc + fb.z * 0.06 + Vector3(0, -bh * 0.18, 0)), Color(1, 1, 1), Vector2(0, 0))
	# frame lights
	for sy: float in [-1.0, 1.0]:
		neon.add_box(Transform3D(fb, pc + fb.y * (bh * 0.5 + 0.15) * sy + fb.z * 0.05), Vector3(bw + 0.3, 0.12, 0.1), col * 0.8, Vector2(4.0, 0.0))


func _real_lights() -> void:
	# Real lights near lamps (half the budget) and, on Forward+, next to the neon signs and
	# billboards closest to the road, so the road and the walls pick up their colour; the rest of
	# the light is faked with pools and bloom. A few stay free for the cars' headlights.
	var budget := Settings.light_budget()
	var n := mini(budget / 2, lamp_spots.size())
	_neon_lights(maxi(0, budget - n - 8))
	if n <= 0:
		return
	var stride := maxf(1.0, float(lamp_spots.size()) / n)
	var k := 0.0
	var made := 0
	while int(k) < lamp_spots.size() and made < n:
		var xf: Transform3D = lamp_spots[int(k)]
		var sl := SpotLight3D.new()
		sl.name = "LampLight%d" % made
		sl.position = xf.origin
		sl.rotation_degrees = Vector3(-90, 0, 0)
		sl.spot_range = 16.0
		sl.spot_angle = 58.0
		sl.spot_attenuation = 0.8
		sl.light_energy = 6.0
		sl.light_color = Color(1.0, 0.65, 0.35)
		sl.light_volumetric_fog_energy = 3.0   # lamp cones in the haze
		sl.shadow_enabled = false
		sl.distance_fade_enabled = true
		sl.distance_fade_begin = 140.0
		sl.distance_fade_length = 40.0
		root.add_child(sl)
		made += 1
		k += stride


func _neon_lights(n: int) -> void:
	if n <= 0 or neon_spots.is_empty():
		return
	# signs that face the road from up to 22 m off its edge and not far above or below it
	var near: Array = []
	for spot: Array in neon_spots:
		var p: Vector3 = spot[0]
		var clear := field.query(p, 22.0)
		if field.q_index < 0 or clear > 22.0:
			continue
		var dy := p.y - field.pos[field.q_index].y
		if dy < -4.0 or dy > 26.0:
			continue
		near.append([float(field.q_index), spot])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var stride := maxf(1.0, float(near.size()) / n)
	var k := 0.0
	var made := 0
	while int(k) < near.size() and made < n:
		var spot: Array = near[int(k)][1]
		var col: Color = spot[1]
		var ol := OmniLight3D.new()
		ol.name = "NeonLight%d" % made
		ol.position = spot[0]
		ol.light_color = col.lightened(0.15)
		ol.light_energy = 3.0
		ol.light_specular = 0.8           # long neon streaks on the damp road
		ol.light_volumetric_fog_energy = 2.0
		ol.omni_range = clampf(10.0 + float(spot[2]) * 0.8, 12.0, 24.0)
		ol.omni_attenuation = 1.4
		ol.shadow_enabled = false
		ol.distance_fade_enabled = true
		ol.distance_fade_begin = 160.0
		ol.distance_fade_length = 50.0
		root.add_child(ol)
		made += 1
		k += stride


func _puddles() -> void:
	# Forward+ only (no decals on Compatibility): mirror-like wet patches on the road.
	if Settings.quality < 2:
		return
	var tex := _puddle_textures()
	var n := clampi(int(field.path.length / 45.0), 10, 80)
	for k in n:
		var dm := rng.randf_range(0.0, field.path.length)
		if field.zone_near(dm, ["loop", "jump", "wallride"], 5.0):
			continue
		var i := clampi(int(round(dm / field.path.length * (field.count - 1))), 0, field.count - 1)
		var fr := field.frame(i)
		var dec := Decal.new()
		dec.name = "Puddle%d" % k
		var lat := rng.randf_range(-field.half[i] * 0.8, field.half[i] * 0.8)
		dec.position = fr.origin + fr.basis.x * lat
		dec.basis = Basis(fr.basis.x, fr.basis.y, fr.basis.z).rotated(fr.basis.y, rng.randf_range(0, TAU))
		dec.size = Vector3(rng.randf_range(3.0, 7.0), 1.0, rng.randf_range(2.0, 5.0))
		dec.texture_albedo = tex[0]
		dec.texture_orm = tex[1]
		dec.albedo_mix = 0.85
		dec.modulate = Color(0.25, 0.25, 0.3)
		dec.upper_fade = 0.5
		dec.lower_fade = 0.5
		dec.cull_mask = 1
		dec.distance_fade_enabled = true
		dec.distance_fade_begin = 120.0
		dec.distance_fade_length = 30.0
		root.add_child(dec)


func _puddle_textures() -> Array:
	var size := 128
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.03
	var alb := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var orm := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (Vector2(x, y) / size - Vector2(0.5, 0.5)) * 2.0
			var fall := clampf(1.0 - u.length(), 0.0, 1.0)
			var nval := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((nval * 0.8 + fall * 0.9 - 0.75) * 6.0, 0.0, 1.0)
			alb.set_pixel(x, y, Color(0.1, 0.1, 0.12, a))
			orm.set_pixel(x, y, Color(1.0, 0.02, 0.0, a))
	return [ImageTexture.create_from_image(alb), ImageTexture.create_from_image(orm)]
