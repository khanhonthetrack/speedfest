class_name CarParts
extends RefCounted
## Body parts and details, built into the same MeshKit as the shell (ground space):
## lights, grilles, mirrors, door seams, exhausts, plate, interior, and the style parts
## (hood 0..3, front 0..2, rear 0..2, skirts 0..2, spoiler 0..4).
##
## Vertex colors: on "paint", R = 1 marks carbon-capable hood parts, G = 1 forces the accent color.
## On "lights", A = lamp type (see car_lights.gdshader). On "trim"/"chrome", RGB = albedo.

const PAINT := Color(0, 0, 0, 1)
const HOOD := Color(1, 0, 0, 1)
const ACCENT := Color(0, 1, 0, 1)
const BLACK := Color(0.03, 0.03, 0.035, 1)
const DARK := Color(0.012, 0.012, 0.014, 1)
const GREY := Color(0.09, 0.09, 0.1, 1)
const PLATE_BG := Color(0.85, 0.85, 0.8, 1)
const CHROME := Color(0.9, 0.9, 0.92, 1)
const L_HEAD := Color(0.9, 0.9, 0.9, 1.0)
const L_TAIL := Color(0.4, 0.02, 0.02, 0.75)
const L_REV := Color(0.8, 0.8, 0.8, 0.5)
const L_AMBER := Color(0.6, 0.3, 0.02, 0.25)
const L_DARK := Color(0.15, 0.15, 0.17, 0.0)


static func build(s: CarShape, kit: MeshKit, style: Dictionary) -> Dictionary:
	var info := {"exhausts": [], "headlights": [], "exhaust_r": 0.04}
	_interior(s, kit)
	_mirrors(s, kit)
	_doors(s, kit)
	match s.car_id:
		"brute":
			_brute_front(s, kit, info)
			_brute_rear(s, kit, info)
		"veloce":
			_veloce_front(s, kit, info)
			_veloce_rear(s, kit, info)
		"kitsune":
			_kitsune_front(s, kit, info)
			_kitsune_rear(s, kit, info)
		"pixie":
			_pixie_front(s, kit, info)
			_pixie_rear(s, kit, info)
		"goliath":
			_goliath_front(s, kit, info)
			_goliath_rear(s, kit, info)
		_:
			_kaze_front(s, kit, info)
			_kaze_rear(s, kit, info)
	_plate(s, kit, info)
	_hood(s, kit, int(style.get("hood", 0)))
	_front_kit(s, kit, int(style.get("front", 0)))
	_rear_kit(s, kit, int(style.get("rear", 0)))
	_skirts(s, kit, int(style.get("skirts", 0)))
	_spoiler(s, kit, int(style.get("spoiler", 0)))
	kit.color = Color(1, 1, 1, 1)
	kit.mirror_x = false
	return info


# --- surface helpers ----------------------------------------------------------

## z of the front (t = 0) or rear (t = 1) face at (x, y).
static func face_z(s: CarShape, rear: bool, x: float, y: float) -> float:
	var t := 1.0 if rear else 0.0
	return s.z_of(t) + s.end_bulge(x, y, t)


## A patch lying on the front or rear face, `out` meters proud of it.
static func face_patch(s: CarShape, kit: MeshKit, key: String, rear: bool, x0: float, x1: float, y0: float, y1: float,
		out := 0.004, nx := 4, ny := 2) -> void:
	var dirz := 1.0 if rear else -1.0
	var rows: Array = []
	for i in ny + 1:
		var y := lerpf(y0, y1, float(i) / float(ny))
		var row := PackedVector3Array()
		for j in nx + 1:
			var x := lerpf(x0, x1, float(j) / float(nx))
			row.append(Vector3(x, y, face_z(s, rear, x, y) + dirz * out))
		rows.append(row)
	# u = +x, v = +y: cross = +z. Front faces want -z.
	kit.grid(key, rows, dirz)


## A patch on the deck (hood/trunk top) between half-widths x0..x1 and stations t0..t1.
static func deck_patch(s: CarShape, kit: MeshKit, key: String, x0: float, x1: float, t0: float, t1: float, out := 0.004, nx := 4, nt := 4) -> void:
	var rows: Array = []
	for i in nt + 1:
		var t := lerpf(t0, t1, float(i) / float(nt))
		var row := PackedVector3Array()
		for j in nx + 1:
			var x := lerpf(x0, x1, float(j) / float(nx))
			var y := s.deck_y(x, t) + out
			row.append(Vector3(x, y, s.z_of(t) + s.end_bulge(x, y, t)))
		rows.append(row)
	# u = +x, v = +z: cross = -y, we want +y
	kit.grid(key, rows, -1.0)


## A patch on the right body side between stations t0..t1 and heights y0..y1.
static func side_patch(s: CarShape, kit: MeshKit, key: String, t0: float, t1: float, y0: float, y1: float, out := 0.003, nt := 4, ny := 2) -> void:
	var rows: Array = []
	for i in nt + 1:
		var t := lerpf(t0, t1, float(i) / float(nt))
		var row := PackedVector3Array()
		for j in ny + 1:
			var y := lerpf(y0, y1, float(j) / float(ny))
			var x := s.side_x(y, t) + out
			row.append(Vector3(x, y, s.z_of(t) + s.end_bulge(x, y, t)))
		rows.append(row)
	# u = +y, v = +z: cross = +x
	kit.grid(key, rows, 1.0)


## Loft along x that follows the front/rear face curvature. `prof` points are (outward offset from
## the face at height y_ref, absolute y). Closed profile; the x ends are capped.
static func face_loft(s: CarShape, kit: MeshKit, key: String, rear: bool, xw: float, y_ref: float, prof: PackedVector2Array, n := 12) -> void:
	var dirz := 1.0 if rear else -1.0
	var rows: Array = []
	for i in n + 1:
		var x := lerpf(-xw, xw, float(i) / float(n))
		var fz := face_z(s, rear, x, y_ref)
		var row := PackedVector3Array()
		for p in prof:
			row.append(Vector3(x, p.y, fz + dirz * p.x))
		row.append(row[0])
		rows.append(row)
	kit.grid(key, rows, 0.0)
	_cap_rows(kit, key, rows[0], Vector3.LEFT)
	_cap_rows(kit, key, rows[n], Vector3.RIGHT)


## Loft along x that follows the deck near station t_ref. `prof` points are (z offset, height above deck).
static func deck_loft(s: CarShape, kit: MeshKit, key: String, t_ref: float, xw: float, prof: PackedVector2Array, n := 12) -> void:
	var rows: Array = []
	for i in n + 1:
		var x := lerpf(-xw, xw, float(i) / float(n))
		var yd := s.deck_y(absf(x), t_ref)
		var z0 := s.z_of(t_ref) + s.end_bulge(x, yd, t_ref)
		var row := PackedVector3Array()
		for p in prof:
			row.append(Vector3(x, yd + p.y, z0 + p.x))
		row.append(row[0])
		rows.append(row)
	kit.grid(key, rows, 0.0)
	_cap_rows(kit, key, rows[0], Vector3.LEFT)
	_cap_rows(kit, key, rows[n], Vector3.RIGHT)


static func _cap_rows(kit: MeshKit, key: String, row: PackedVector3Array, out: Vector3) -> void:
	var c := Vector3.ZERO
	for k in row.size() - 1:
		c += row[k]
	c /= float(row.size() - 1)
	for k in row.size() - 1:
		kit.flat_tri(key, c, row[k], row[k + 1], out)


## A band on the deck whose x range slides from [xa0, xa1] at t0 to [xb0, xb1] at t1 (swept strips).
static func deck_band(s: CarShape, kit: MeshKit, key: String, t0: float, t1: float, xa0: float, xa1: float, xb0: float, xb1: float, out := 0.005, nt := 6) -> void:
	var rows: Array = []
	for i in nt + 1:
		var f := float(i) / float(nt)
		var t := lerpf(t0, t1, f)
		var row := PackedVector3Array()
		for x in [lerpf(xa0, xb0, f), lerpf(xa1, xb1, f)]:
			var y := s.deck_y(x, t) + out
			row.append(Vector3(x, y, s.z_of(t) + s.end_bulge(x, y, t)))
		rows.append(row)
	kit.grid(key, rows, -1.0)


## Prism with a side-view (z, y) profile, extruded across x from x0 to x1.
static func side_prism(kit: MeshKit, key: String, prof: PackedVector2Array, x0: float, x1: float) -> void:
	kit.prism(key, Vector3((x0 + x1) * 0.5, 0, 0), prof, Vector3.BACK, Vector3.UP, Vector3.RIGHT, absf(x1 - x0))


## Prism with a front-view (x, y) profile, extruded along z from z0 to z1.
static func front_prism(kit: MeshKit, key: String, prof: PackedVector2Array, z0: float, z1: float) -> void:
	kit.prism(key, Vector3(0, 0, (z0 + z1) * 0.5), prof, Vector3.RIGHT, Vector3.UP, Vector3.BACK, absf(z1 - z0))


static func rect(cx: float, cy: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(cx - w * 0.5, cy - h * 0.5), Vector2(cx + w * 0.5, cy - h * 0.5),
		Vector2(cx + w * 0.5, cy + h * 0.5), Vector2(cx - w * 0.5, cy + h * 0.5)])


## Round lamp (short cylinder along z) on the front or rear face.
static func round_lamp(s: CarShape, kit: MeshKit, rear: bool, x: float, y: float, r: float, lamp: Color, bezel := true) -> void:
	var dirz := 1.0 if rear else -1.0
	var z := face_z(s, rear, x, y)
	if bezel:
		kit.color = CHROME
		kit.cylinder("chrome", Vector3(x, y, z - dirz * 0.03), Vector3(0, 0, dirz), 0.04, r * 1.18, r * 1.12, 16, false, true)
	kit.color = lamp
	kit.cylinder("lights", Vector3(x, y, z - dirz * 0.03), Vector3(0, 0, dirz), 0.045, r, r * 0.97, 16, false, true)


# --- shared details -----------------------------------------------------------

## Interior and driver: see res://cars/visual/car_cabin.gd (session 7).
static func _interior(s: CarShape, kit: MeshKit) -> void:
	CarCabin.build(s, kit)


static func _mirrors(s: CarShape, kit: MeshKit) -> void:
	var t: float = float(s.gh["cowl"]) + 0.045
	var x := s.gh_base_w(t) + 0.07
	var y := s.gh_base_y(t) + 0.08
	var z := s.z_of(t)
	kit.mirror_x = true
	kit.color = BLACK
	kit.box("trim", Vector3(x - 0.05, y - 0.045, z + 0.02), Vector3(0.12, 0.05, 0.06))
	var shell := PackedVector2Array()
	var lens := PackedVector2Array()
	for k in 12:
		var a := TAU * float(k) / 12.0
		var e := Vector2(cos(a), sin(a))
		e = e.sign() * Vector2(pow(absf(e.x), 0.7), pow(absf(e.y), 0.7))
		shell.append(Vector2(x + 0.03 + e.x * 0.078, y + e.y * 0.045))
		lens.append(Vector2(x + 0.03 + e.x * 0.066, y + e.y * 0.035))
	kit.color = PAINT
	kit.prism("paint", Vector3(0, 0, z), shell, Vector3.RIGHT, Vector3.UP, Vector3.BACK, 0.1, true, true)
	kit.color = CHROME
	kit.prism("chrome", Vector3(0, 0, z + 0.05), lens, Vector3.RIGHT, Vector3.UP, Vector3.BACK, 0.008, true, false)
	kit.mirror_x = false


static func _doors(s: CarShape, kit: MeshKit) -> void:
	var c0: float = s.gh["cowl"]
	var c2: float = s.gh["roof_end"]
	var t_front := c0 + 0.015
	var t_rear := lerpf(c0, c2, 0.72) if s.car_id != "veloce" else float(s.style_k["intake_t"][0]) - 0.01
	kit.mirror_x = true
	kit.color = DARK
	for t in [t_front, t_rear]:
		var y0 := s.bot(t) + 0.06
		var y1 := s.belt(t) - 0.03
		side_patch(s, kit, "trim", t - 0.0012, t + 0.0012, y0, y1, 0.002, 1, 4)
	# door handle
	kit.color = CHROME
	var th := t_rear - 0.035
	var yh := s.belt(th) - 0.1
	kit.box("chrome", Vector3(s.side_x(yh, th) + 0.004, yh, s.z_of(th)), Vector3(0.012, 0.022, 0.12))
	kit.mirror_x = false


static func _exhaust(s: CarShape, kit: MeshKit, info: Dictionary, x: float, y: float, r: float, oval := 1.0) -> void:
	var z := face_z(s, true, x, y)
	var start := Vector3(x, y, z - 0.18)
	kit.color = CHROME
	kit.cylinder("chrome", start, Vector3.BACK, 0.24, r, r * 1.04, 16, false, false)
	kit.color = DARK
	kit.cylinder("trim", start + Vector3(0, 0, 0.21), Vector3.BACK, 0.01, r * 0.82, r * 0.82, 14, false, true)
	info["exhausts"].append(Vector3(x, y, z + 0.06))
	info["exhaust_r"] = r


static func _plate(s: CarShape, kit: MeshKit, info: Dictionary) -> void:
	var y: float = s.style_k.get("plate_y", s.bot(1.0) + 0.17)
	var z := face_z(s, true, 0.0, y)
	kit.color = DARK
	face_patch(s, kit, "trim", true, -0.25, 0.25, y - 0.085, y + 0.085, 0.004, 4, 1)
	kit.color = PLATE_BG
	kit.box("trim", Vector3(0, y, z + 0.012), Vector3(0.44, 0.13, 0.012))
	info["plate"] = Transform3D(Basis.IDENTITY, Vector3(0, y, z + 0.0195))


# --- per-car fronts and rears -------------------------------------------------

static func _kaze_front(s: CarShape, kit: MeshKit, info: Dictionary) -> void:
	# raised pop-up headlights: painted pods on the hood corners with lit faces
	var tf := 0.035
	for side in [-1.0, 1.0]:
		var xc: float = side * 0.56
		var yd := s.deck_y(absf(xc), tf + 0.04)
		var z0 := s.z_of(tf) + 0.02
		var pod_h := 0.13
		kit.color = PAINT
		var prof := PackedVector2Array([Vector2(z0, yd - 0.04), Vector2(z0, yd + pod_h), Vector2(z0 + 0.2, yd + pod_h - 0.02), Vector2(z0 + 0.24, yd - 0.04)])
		side_prism(kit, "paint", prof, xc - 0.19, xc + 0.19)
		kit.color = DARK
		kit.box("trim", Vector3(xc, yd + 0.045, z0 - 0.003), Vector3(0.36, 0.12, 0.01))
		kit.color = L_HEAD
		kit.box("lights", Vector3(xc - 0.085, yd + 0.045, z0 - 0.008), Vector3(0.14, 0.085, 0.01))
		kit.box("lights", Vector3(xc + 0.085, yd + 0.045, z0 - 0.008), Vector3(0.14, 0.085, 0.01))
		info["headlights"].append(Vector3(xc, yd + 0.05, z0 - 0.01))
	# slim grille slot and amber corner lamps on the nose
	var yb := s.bot(0.0)
	var yt := s.crown(0.0)
	kit.color = BLACK
	face_patch(s, kit, "trim", false, -0.42, 0.42, lerpf(yb, yt, 0.55), lerpf(yb, yt, 0.78), 0.004, 6, 1)
	kit.mirror_x = true
	kit.color = L_AMBER
	face_patch(s, kit, "lights", false, 0.5, 0.7, lerpf(yb, yt, 0.55), lerpf(yb, yt, 0.75), 0.005, 2, 1)
	kit.mirror_x = false


static func _kaze_rear(s: CarShape, kit: MeshKit, info: Dictionary) -> void:
	var yb := s.bot(1.0)
	var yt := s.belt(1.0)
	var y0 := lerpf(yb, yt, 0.58)
	var y1 := lerpf(yb, yt, 0.86)
	kit.color = BLACK
	face_patch(s, kit, "trim", true, -0.76, 0.76, y0 - 0.015, y1 + 0.015, 0.003, 8, 1)
	kit.mirror_x = true
	kit.color = L_TAIL
	face_patch(s, kit, "lights", true, 0.36, 0.74, y0, y1, 0.007, 4, 1)
	kit.color = L_REV
	face_patch(s, kit, "lights", true, 0.22, 0.34, y0, y1, 0.007, 1, 1)
	kit.mirror_x = false
	s.style_k["plate_y"] = lerpf(yb, yt, 0.32)
	for side in [-1.0, 1.0]:
		_exhaust(s, kit, info, side * 0.52, yb + 0.06, 0.042)


static func _brute_front(s: CarShape, kit: MeshKit, info: Dictionary) -> void:
	var yb := s.bot(0.0)
	var yt := s.belt(0.0)
	var g0 := lerpf(yb, yt, 0.45)
	var g1 := lerpf(yb, yt, 0.9)
	# full-width grille with chrome surround and bars
	kit.color = CHROME
	face_patch(s, kit, "chrome", false, -0.8, 0.8, g0 - 0.025, g1 + 0.02, 0.004, 8, 1)
	kit.color = DARK
	face_patch(s, kit, "trim", false, -0.77, 0.77, g0, g1, 0.008, 8, 1)
	kit.color = BLACK
	for k in 4:
		var yy := lerpf(g0, g1, (float(k) + 0.5) / 4.0)
		face_patch(s, kit, "trim", false, -0.24, 0.24, yy - 0.008, yy + 0.008, 0.016, 4, 1)
	# quad round headlights in the grille ends
	var ly := lerpf(g0, g1, 0.52)
	for side in [-1.0, 1.0]:
		for xo in [0.64, 0.44]:
			round_lamp(s, kit, false, side * xo, ly, 0.072, L_HEAD)
			info["headlights"].append(Vector3(side * xo, ly, face_z(s, false, xo, ly) - 0.02))
	# bumper bar
	kit.color = CHROME
	face_patch(s, kit, "chrome", false, -0.85, 0.85, g0 - 0.09, g0 - 0.05, 0.02, 8, 1)
	kit.mirror_x = true
	kit.color = L_AMBER
	face_patch(s, kit, "lights", false, 0.5, 0.7, yb + 0.06, yb + 0.11, 0.01, 2, 1)
	kit.mirror_x = false


static func _brute_rear(s: CarShape, kit: MeshKit, info: Dictionary) -> void:
	var yb := s.bot(1.0)
	var yt := s.belt(1.0)
	var y0 := lerpf(yb, yt, 0.6)
	var y1 := lerpf(yb, yt, 0.84)
	kit.color = DARK
	face_patch(s, kit, "trim", true, -0.82, 0.82, y0 - 0.02, y1 + 0.02, 0.003, 10, 1)
	# full-width taillight bar in three segments per side
	kit.mirror_x = true
	kit.color = L_TAIL
	for k in 3:
		var x0 := 0.12 + float(k) * 0.23
		face_patch(s, kit, "lights", true, x0, x0 + 0.21, y0, y1, 0.008, 2, 1)
	kit.mirror_x = false
	kit.color = L_REV
	face_patch(s, kit, "lights", true, -0.1, 0.1, y0, y1, 0.008, 2, 1)
	kit.color = CHROME
	face_patch(s, kit, "chrome", true, -0.86, 0.86, yb + 0.03, yb + 0.07, 0.02, 8, 1)
	s.style_k["plate_y"] = lerpf(yb, yt, 0.36)
	for side in [-1.0, 1.0]:
		for xo in [0.5, 0.62]:
			_exhaust(s, kit, info, side * xo, yb + 0.02, 0.04)


static func _veloce_front(s: CarShape, kit: MeshKit, info: Dictionary) -> void:
	# slim LED strips swept back along the nose corners
	kit.mirror_x = true
	kit.color = BLACK
	deck_band(s, kit, "trim", 0.012, 0.1, 0.46, 0.66, 0.66, 0.84, 0.004)
	kit.color = L_HEAD
	deck_band(s, kit, "lights", 0.018, 0.088, 0.5, 0.56, 0.7, 0.78, 0.008)
	kit.color = L_AMBER
	deck_band(s, kit, "lights", 0.06, 0.092, 0.74, 0.8, 0.8, 0.83, 0.008, 2)
	# big lower intakes
	var yb := s.bot(0.0)
	var yt := s.crown(0.0)
	kit.color = DARK
	face_patch(s, kit, "trim", false, 0.22, 0.7, yb + 0.03, lerpf(yb, yt, 0.75), 0.004, 4, 1)
	kit.mirror_x = false
	kit.color = DARK
	face_patch(s, kit, "trim", false, -0.16, 0.16, yb + 0.04, lerpf(yb, yt, 0.6), 0.004, 2, 1)
	# slats across the side intakes
	var it: Array = s.style_k["intake_t"]
	var ta: float = float(it[0]) + 0.075
	var tb: float = float(it[1]) - 0.02
	var tm := (ta + tb) * 0.5
	kit.mirror_x = true
	kit.color = GREY
	for yy in [0.36, 0.44]:
		var xo := s.side_x(yy, tm) + s.intake_depth(yy, tm) - 0.025
		kit.box("trim", Vector3(xo, yy, s.z_of(tm)), Vector3(0.03, 0.014, s.z_of(tb) - s.z_of(ta)))
	kit.mirror_x = false
	info["headlights"].append(Vector3(-0.68, s.deck_y(0.68, 0.06), s.z_of(0.04)))
	info["headlights"].append(Vector3(0.68, s.deck_y(0.68, 0.06), s.z_of(0.04)))


static func _veloce_rear(s: CarShape, kit: MeshKit, info: Dictionary) -> void:
	var yb := s.bot(1.0)
	var yt := s.belt(1.0)
	kit.color = DARK
	face_patch(s, kit, "trim", true, -0.86, 0.86, lerpf(yb, yt, 0.55), lerpf(yb, yt, 0.92), 0.003, 10, 1)
	kit.color = L_TAIL
	face_patch(s, kit, "lights", true, -0.84, 0.84, lerpf(yb, yt, 0.82), lerpf(yb, yt, 0.88), 0.008, 10, 1)
	kit.mirror_x = true
	for xo in [0.68, 0.48]:
		kit.color = L_TAIL
		round_lamp(s, kit, true, xo, lerpf(yb, yt, 0.68), 0.06, L_TAIL, false)
	kit.color = L_REV
	face_patch(s, kit, "lights", true, 0.25, 0.36, lerpf(yb, yt, 0.62), lerpf(yb, yt, 0.74), 0.008, 1, 1)
	kit.mirror_x = false
	# engine vents over the tail
	kit.color = DARK
	face_patch(s, kit, "trim", true, -0.22, 0.22, lerpf(yb, yt, 0.6), lerpf(yb, yt, 0.78), 0.004, 2, 1)
	s.style_k["plate_y"] = lerpf(yb, yt, 0.3)
	for xo in [-0.075, 0.075]:
		_exhaust(s, kit, info, xo, lerpf(yb, yt, 0.69), 0.05)


static func _kitsune_front(s: CarShape, kit: MeshKit, info: Dictionary) -> void:
	# twin round headlights, a black mesh grille and the rally signature: four spot lamps on a bar
	var yb := s.bot(0.0)
	var yt := s.crown(0.0)
	var ly := lerpf(yb, yt, 0.72)
	kit.color = BLACK
	face_patch(s, kit, "trim", false, -0.38, 0.38, lerpf(yb, yt, 0.5), lerpf(yb, yt, 0.86), 0.005, 6, 1)
	for side in [-1.0, 1.0]:
		round_lamp(s, kit, false, side * 0.6, ly, 0.075, L_HEAD)
		info["headlights"].append(Vector3(side * 0.6, ly, face_z(s, false, 0.6, ly) - 0.02))
	# lamp bar across the lower bumper with four round spots
	var by := yb + 0.1
	kit.color = DARK
	face_patch(s, kit, "trim", false, -0.62, 0.62, by - 0.05, by + 0.05, 0.03, 8, 1)
	for xo in [-0.45, -0.15, 0.15, 0.45]:
		round_lamp(s, kit, false, xo, by, 0.052, L_HEAD)
	kit.mirror_x = true
	kit.color = L_AMBER
	face_patch(s, kit, "lights", false, 0.7, 0.8, lerpf(yb, yt, 0.55), lerpf(yb, yt, 0.68), 0.008, 1, 1)
	kit.mirror_x = false


static func _kitsune_rear(s: CarShape, kit: MeshKit, info: Dictionary) -> void:
	var yb := s.bot(1.0)
	var yt := s.belt(1.0)
	# tall taillights up the hatch corners, a black bumper strip and one big exhaust
	kit.mirror_x = true
	kit.color = L_TAIL
	face_patch(s, kit, "lights", true, 0.58, 0.78, lerpf(yb, yt, 0.45), lerpf(yb, yt, 0.95), 0.008, 2, 2)
	kit.color = L_REV
	face_patch(s, kit, "lights", true, 0.5, 0.57, lerpf(yb, yt, 0.45), lerpf(yb, yt, 0.6), 0.008, 1, 1)
	kit.mirror_x = false
	kit.color = BLACK
	face_patch(s, kit, "trim", true, -0.84, 0.84, yb + 0.02, yb + 0.12, 0.012, 8, 1)
	s.style_k["plate_y"] = lerpf(yb, yt, 0.38)
	_exhaust(s, kit, info, 0.45, yb + 0.05, 0.06)


static func _pixie_front(s: CarShape, kit: MeshKit, info: Dictionary) -> void:
	# frog-eye lamps high on the nose and a small smiling grille
	var yb := s.bot(0.0)
	var yt := s.crown(0.0)
	var ly := lerpf(yb, yt, 0.82)
	for side in [-1.0, 1.0]:
		round_lamp(s, kit, false, side * 0.46, ly, 0.08, L_HEAD)
		info["headlights"].append(Vector3(side * 0.46, ly, face_z(s, false, 0.46, ly) - 0.02))
	kit.color = BLACK
	face_patch(s, kit, "trim", false, -0.26, 0.26, lerpf(yb, yt, 0.32), lerpf(yb, yt, 0.5), 0.005, 6, 1)
	kit.color = CHROME
	face_patch(s, kit, "chrome", false, -0.28, 0.28, lerpf(yb, yt, 0.3), lerpf(yb, yt, 0.33), 0.008, 6, 1)
	kit.mirror_x = true
	kit.color = L_AMBER
	face_patch(s, kit, "lights", false, 0.5, 0.62, lerpf(yb, yt, 0.36), lerpf(yb, yt, 0.46), 0.006, 1, 1)
	kit.mirror_x = false


static func _pixie_rear(s: CarShape, kit: MeshKit, info: Dictionary) -> void:
	var yb := s.bot(1.0)
	var yt := s.belt(1.0)
	var ly := lerpf(yb, yt, 0.7)
	kit.mirror_x = true
	for xo in [0.56, 0.38]:
		round_lamp(s, kit, true, xo, ly, 0.055, L_TAIL, false)
	kit.color = L_REV
	face_patch(s, kit, "lights", true, 0.2, 0.28, lerpf(yb, yt, 0.62), lerpf(yb, yt, 0.76), 0.008, 1, 1)
	kit.mirror_x = false
	kit.color = CHROME
	face_patch(s, kit, "chrome", true, -0.7, 0.7, yb + 0.05, yb + 0.08, 0.012, 6, 1)
	s.style_k["plate_y"] = lerpf(yb, yt, 0.35)
	_exhaust(s, kit, info, -0.4, yb + 0.04, 0.035)


static func _goliath_front(s: CarShape, kit: MeshKit, info: Dictionary) -> void:
	# tall chrome grille with heavy bars, square headlights, a steel bumper and a roof light bar
	var yb := s.bot(0.0)
	var yt := s.belt(0.0)
	var g0 := lerpf(yb, yt, 0.42)
	var g1 := lerpf(yb, yt, 0.92)
	kit.color = CHROME
	face_patch(s, kit, "chrome", false, -0.62, 0.62, g0 - 0.03, g1 + 0.03, 0.004, 8, 1)
	kit.color = DARK
	face_patch(s, kit, "trim", false, -0.58, 0.58, g0, g1, 0.008, 8, 1)
	kit.color = CHROME
	for k in 3:
		var yy := lerpf(g0, g1, (float(k) + 1.0) / 4.0)
		face_patch(s, kit, "chrome", false, -0.58, 0.58, yy - 0.012, yy + 0.012, 0.016, 6, 1)
	var ly := lerpf(g0, g1, 0.62)
	kit.mirror_x = true
	kit.color = L_HEAD
	face_patch(s, kit, "lights", false, 0.66, 0.9, ly - 0.07, ly + 0.07, 0.008, 2, 1)
	kit.color = L_AMBER
	face_patch(s, kit, "lights", false, 0.66, 0.9, ly - 0.13, ly - 0.09, 0.008, 2, 1)
	kit.mirror_x = false
	for side in [-1.0, 1.0]:
		info["headlights"].append(Vector3(side * 0.78, ly, face_z(s, false, 0.78, ly) - 0.02))
	# steel bumper
	kit.color = GREY
	face_patch(s, kit, "trim", false, -0.98, 0.98, yb + 0.02, g0 - 0.06, 0.05, 10, 1)
	# roof light bar (above the windshield)
	var tr := float(s.gh["ws_top"]) + 0.012
	var ry := float(s.gh["roof_y"]) + 0.05
	kit.color = DARK
	kit.box("trim", Vector3(0, ry, s.z_of(tr)), Vector3(1.2, 0.07, 0.1))
	kit.color = L_HEAD
	for k in 6:
		var x := -0.5 + 0.2 * float(k)
		kit.box("lights", Vector3(x, ry, s.z_of(tr) - 0.052), Vector3(0.14, 0.045, 0.01))


static func _goliath_rear(s: CarShape, kit: MeshKit, info: Dictionary) -> void:
	var yb := s.bot(1.0)
	var yt := s.belt(1.0)
	# tall taillights on the bed corners, a dark tailgate band and twin pipes under the bumper
	kit.mirror_x = true
	kit.color = L_TAIL
	face_patch(s, kit, "lights", true, 0.82, 0.96, lerpf(yb, yt, 0.45), lerpf(yb, yt, 0.95), 0.008, 1, 3)
	kit.color = L_REV
	face_patch(s, kit, "lights", true, 0.82, 0.96, lerpf(yb, yt, 0.36), lerpf(yb, yt, 0.44), 0.008, 1, 1)
	kit.mirror_x = false
	kit.color = DARK
	face_patch(s, kit, "trim", true, -0.6, 0.6, lerpf(yb, yt, 0.78), lerpf(yb, yt, 0.84), 0.004, 6, 1)
	kit.color = GREY
	face_patch(s, kit, "trim", true, -0.98, 0.98, yb + 0.02, yb + 0.14, 0.04, 10, 1)
	s.style_k["plate_y"] = lerpf(yb, yt, 0.42)
	for side in [-1.0, 1.0]:
		_exhaust(s, kit, info, side * 0.62, yb + 0.03, 0.05)


# --- style parts --------------------------------------------------------------

static func _hood(s: CarShape, kit: MeshKit, v: int) -> void:
	if v <= 0:
		return
	var h0: float = s.style_k["hood_from"]
	var h1: float = s.style_k["hood_to"]
	var span := h1 - h0
	match v:
		1:  # vented: two louvered vents
			kit.mirror_x = true
			var ta := h0 + span * 0.35
			var tb := h0 + span * 0.62
			kit.color = DARK
			deck_patch(s, kit, "trim", 0.16, 0.42, ta, tb, 0.003, 3, 3)
			kit.color = HOOD
			for k in 5:
				var t := lerpf(ta, tb, (float(k) + 0.5) / 5.0)
				var y := s.deck_y(0.29, t)
				kit.box("paint", Vector3(0.29, y + 0.012, s.z_of(t)), Vector3(0.26, 0.012, 0.022), Basis(Vector3.RIGHT, -0.5))
			kit.mirror_x = false
		2:  # center scoop
			_scoop(s, kit, 0.0, h0 + span * 0.3, h0 + span * 0.78, 0.5 if s.car_id == "brute" else 0.4, 0.1)
		3:  # twin scoops
			for side in [-1.0, 1.0]:
				_scoop(s, kit, side * 0.3, h0 + span * 0.35, h0 + span * 0.8, 0.26, 0.075)


static func _scoop(s: CarShape, kit: MeshKit, xc: float, t0: float, t1: float, w: float, h: float) -> void:
	var z0 := s.z_of(t0)
	var z1 := s.z_of(t1)
	var y0 := s.deck_y(absf(xc), t0)
	var y1 := s.deck_y(absf(xc), t1)
	kit.color = HOOD
	var prof := PackedVector2Array([Vector2(z0, y0 - 0.02), Vector2(z0 + 0.02, y0 + h), Vector2(z1 - 0.05, y1 + h * 0.7), Vector2(z1, y1 - 0.02)])
	side_prism(kit, "paint", prof, xc - w * 0.5, xc + w * 0.5)
	# tapered side cheeks
	kit.color = DARK
	kit.box("trim", Vector3(xc, y0 + h * 0.5, z0 - 0.002), Vector3(w * 0.84, h * 0.75, 0.01))


static func _front_kit(s: CarShape, kit: MeshKit, v: int) -> void:
	var yb := s.bot(0.0)
	var w := s.wmax(0.02) - 0.03
	match v:
		0:
			kit.color = DARK
			face_patch(s, kit, "trim", false, -0.35, 0.35, yb + 0.02, yb + 0.07, 0.004, 4, 1)
		1:  # street: painted chin spoiler with a black lower lip
			kit.color = PAINT
			face_loft(s, kit, "paint", false, w, yb, PackedVector2Array([Vector2(-0.06, yb + 0.06), Vector2(0.02, yb + 0.05), Vector2(0.035, yb - 0.035), Vector2(-0.12, yb - 0.04)]))
			kit.color = DARK
			face_loft(s, kit, "trim", false, w - 0.04, yb, PackedVector2Array([Vector2(-0.1, yb - 0.035), Vector2(0.03, yb - 0.035), Vector2(0.04, yb - 0.05), Vector2(-0.1, yb - 0.05)]))
			face_patch(s, kit, "trim", false, -0.5, 0.5, yb + 0.015, yb + 0.07, 0.006, 4, 1)
		2:  # race: deep bumper, carbon splitter, canards, big intake
			kit.color = PAINT
			face_loft(s, kit, "paint", false, w, yb, PackedVector2Array([Vector2(-0.06, yb + 0.07), Vector2(0.025, yb + 0.06), Vector2(0.04, yb - 0.04), Vector2(-0.14, yb - 0.045)]))
			kit.color = DARK
			face_loft(s, kit, "trim", false, w + 0.02, yb, PackedVector2Array([Vector2(-0.2, yb - 0.045), Vector2(0.1, yb - 0.045), Vector2(0.11, yb - 0.062), Vector2(-0.2, yb - 0.062)]))
			kit.mirror_x = true
			for k in 2:
				var yy := yb + 0.1 + float(k) * 0.075
				var xx := w - 0.07
				var zz := face_z(s, false, xx, yy)
				kit.box("trim", Vector3(xx, yy, zz - 0.03), Vector3(0.16, 0.01, 0.1), Basis(Vector3.BACK, 0.22 * (1.0 if k == 0 else 0.6)))
			kit.mirror_x = false
			face_patch(s, kit, "trim", false, -0.55, 0.55, yb + 0.0, yb + 0.1, 0.044, 4, 1)


static func _rear_kit(s: CarShape, kit: MeshKit, v: int) -> void:
	if v <= 0:
		return
	var yb := s.bot(1.0)
	var w := s.wmax(0.98) - 0.04
	kit.color = DARK
	if v == 1:
		face_loft(s, kit, "trim", true, w * 0.8, yb, PackedVector2Array([Vector2(-0.3, yb + 0.01), Vector2(0.03, yb + 0.03), Vector2(0.04, yb - 0.01), Vector2(-0.3, yb - 0.035)]))
		for k in 3:
			var x := (float(k) - 1.0) * 0.3
			var z := face_z(s, true, x, yb)
			kit.box("trim", Vector3(x, yb - 0.005, z - 0.08), Vector3(0.012, 0.07, 0.22))
	else:
		face_loft(s, kit, "trim", true, w * 0.95, yb, PackedVector2Array([Vector2(-0.45, yb + 0.0), Vector2(0.06, yb + 0.05), Vector2(0.07, yb - 0.02), Vector2(-0.45, yb - 0.045)]))
		for k in 5:
			var x := (float(k) - 2.0) * 0.22
			var z := face_z(s, true, x, yb)
			var prof := PackedVector2Array([Vector2(z - 0.4, yb - 0.04), Vector2(z + 0.07, yb - 0.04), Vector2(z + 0.07, yb + 0.13), Vector2(z - 0.05, yb + 0.03)])
			side_prism(kit, "trim", prof, x - 0.007, x + 0.007)
		kit.mirror_x = true
		face_patch(s, kit, "trim", true, w - 0.22, w - 0.06, yb + 0.06, yb + 0.16, 0.006, 2, 1)
		kit.mirror_x = false


static func _skirts(s: CarShape, kit: MeshKit, v: int) -> void:
	if v <= 0:
		return
	var ra := s.arch_radius()
	var tf := s.t_of(s.z_of(s.axle_t[0]) + ra + 0.02)
	var tr := s.t_of(s.z_of(s.axle_t[1]) - ra - 0.02)
	var drop := 0.045 if v == 1 else 0.075
	kit.mirror_x = true
	var rows: Array = []
	var n := 8
	for i in n + 1:
		var t := lerpf(tf, tr, float(i) / float(n))
		var yb := s.bot(t)
		var x := s.side_x(yb + 0.02, t)
		rows.append(PackedVector3Array([
			Vector3(x - 0.06, yb - drop, s.z_of(t)),
			Vector3(x + 0.012, yb - drop + 0.012, s.z_of(t)),
			Vector3(x + 0.022, yb + 0.03, s.z_of(t)),
			Vector3(x + 0.006, yb + 0.1, s.z_of(t)),
		]))
	kit.color = PAINT
	kit.grid("paint", rows, -1.0, [1, 2])
	# end plugs
	for e in [0, n]:
		var r: PackedVector3Array = rows[e]
		var dz := -1.0 if e == 0 else 1.0
		kit.flat_quad("paint", r[0], r[1], r[2], r[3], Vector3(0, 0, dz))
	if v == 2:
		kit.color = DARK
		var t_mid := (tf + tr) * 0.5
		var x := s.side_x(s.bot(t_mid), t_mid)
		kit.box("trim", Vector3(x + 0.0, s.bot(t_mid) - drop - 0.006, s.z_of(t_mid)), Vector3(0.14, 0.012, s.z_of(tr) - s.z_of(tf)))
	kit.mirror_x = false


static func _spoiler(s: CarShape, kit: MeshKit, v: int) -> void:
	if v <= 0:
		return
	var t_edge := 0.985
	var w := s.wsh(0.96) - 0.06
	match v:
		1:  # lip
			kit.color = PAINT
			deck_loft(s, kit, "paint", t_edge, w * 0.92, PackedVector2Array([Vector2(-0.12, -0.01), Vector2(-0.02, 0.014), Vector2(0.015, 0.04), Vector2(0.02, -0.02)]))
		2:  # ducktail
			kit.color = PAINT
			var dz := s.z_of(t_edge) - s.z_of(0.9)
			var rise := s.deck_y(0.0, t_edge) - s.deck_y(0.0, 0.9)
			deck_loft(s, kit, "paint", t_edge, w * 0.96, PackedVector2Array([Vector2(-dz, -rise - 0.02), Vector2(-dz * 0.4, -rise * 0.4 + 0.035), Vector2(0.035, 0.09), Vector2(0.045, 0.07), Vector2(0.02, -0.03)]))
		_:
			var high := v == 4
			var chord := 0.36 if high else 0.28
			var lift := 0.36 if high else 0.2
			var t_up := 0.93
			var zc := s.z_of(t_up) + (0.02 if high else 0.0)
			var yd := s.deck_y(0.45, t_up)
			var y := yd + lift
			var span := w * (1.0 if high else 0.94)
			# airfoil (side view), angled nose-down slightly
			var foil := PackedVector2Array()
			var th := 0.04 if high else 0.034
			for k in 8:
				var a := TAU * float(k) / 8.0
				var px := cos(a) * chord * 0.5
				var py := sin(a) * th * 0.5 * (1.0 if sin(a) > 0.0 else 0.55)
				foil.append(Vector2(zc + px, y + py - px * 0.12))
			kit.color = PAINT
			side_prism(kit, "paint", foil, -span, span)
			if high:
				var flap := PackedVector2Array()
				for k in 8:
					var a := TAU * float(k) / 8.0
					flap.append(Vector2(zc + chord * 0.45 + cos(a) * chord * 0.2, y + 0.075 + sin(a) * 0.014 - cos(a) * 0.035))
				side_prism(kit, "paint", flap, -span, span)
			# endplates (accent)
			kit.color = ACCENT
			kit.mirror_x = true
			var ep_h := 0.2 if high else 0.13
			var ep := PackedVector2Array([Vector2(zc - chord * 0.55, y - ep_h * 0.45), Vector2(zc + chord * 0.6, y - ep_h * 0.5),
				Vector2(zc + chord * 0.62, y + ep_h * 0.55), Vector2(zc - chord * 0.35, y + ep_h * 0.3)])
			side_prism(kit, "paint", ep, span, span + 0.012)
			# uprights
			kit.color = DARK
			var ux := span * 0.62
			var prof_u := PackedVector2Array([Vector2(zc - 0.06, s.deck_y(ux, t_up) - 0.02), Vector2(zc + 0.06, s.deck_y(ux, t_up) - 0.02),
				Vector2(zc + 0.03, y), Vector2(zc - 0.05, y)])
			side_prism(kit, "trim", prof_u, ux - 0.012, ux + 0.012)
			kit.mirror_x = false
