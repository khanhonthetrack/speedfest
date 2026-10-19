class_name FormulaBody
extends RefCounted
## The FIA F4 single-seater, built in code into the same MeshKit (and with the same material keys)
## as the closed cars, so CarVisual can treat it like any other body.
##
## Model space: the car faces -Z, its left is -X, y = 0 is the road. The proportions are a current
## FIA F4 car: 4.42 m long on a 2.47 m wheelbase, 1.74 m over the wheels, a 0.70 m wide survival
## cell, a raised nose into a two-element front wing, wedge sidepods with cooling inlets, an airbox
## over the roll hoop, a halo, and a two-element rear wing on a swan-neck mount.
##
## Wings are airfoil prisms (a 2D section extruded across the span), so every edge stays crisp.
##
## Vertex colours follow cars/visual/car_parts.gd: on "paint" R = 1 marks carbon-capable panels and
## G = 1 forces the accent colour; on "trim"/"chrome" RGB is the albedo; on "lights" A is the lamp
## type (1 head, 0.75 tail, 0.5 reverse, 0.25 indicator, 0.1 instrument).

const PAINT := Color(0, 0, 0, 1)
const CARBON := Color(1, 0, 0, 1)
const ACCENT := Color(0, 1, 0, 1)
const BLACK := Color(0.030, 0.030, 0.035, 1)
const DARK := Color(0.012, 0.012, 0.014, 1)
const GREY := Color(0.090, 0.090, 0.100, 1)
const ALU := Color(0.52, 0.53, 0.56, 1)
const CHROME := Color(0.90, 0.90, 0.92, 1)
const L_HEAD := Color(0.9, 0.9, 0.9, 1.0)
const L_TAIL := Color(0.4, 0.02, 0.02, 0.75)
const L_AMBER := Color(0.6, 0.3, 0.02, 0.25)
const L_SCREEN := Color(0.10, 0.70, 1.00, 0.1)
const SUIT := Color(0.07, 0.08, 0.11, 1)
const SKIN := Color(0.55, 0.40, 0.32, 1)

const PLANK := 0.042          ## floor height above the road
const CELL_W := 0.345         ## half width of the survival cell


static func build(s: CarShape, kit: MeshKit, style: Dictionary, info: Dictionary) -> void:
	var g := s.g
	var hl: float = float(g["length"]) * 0.5
	var r: float = float(g["wheel_radius"])
	var tf: float = float(g["track_front"]) * 0.5
	var tr: float = float(g["track_rear"]) * 0.5
	var wb: float = float(g["wheelbase"])
	kit.mirror_x = true                       # build the left half, get the right one free

	_floor_and_diffuser(kit, hl, wb, tf, tr)
	_cell(kit, wb)
	_nose(kit, hl, wb, info)
	_front_wing(kit, hl, tf, info)
	_sidepods(kit, wb, tr)
	_engine_cover(kit, hl, wb)
	_cockpit(kit)
	_halo(kit)
	_driver(kit)
	_suspension(kit, wb, tf, tr, r)
	_rear_wing(kit, hl, tr)
	_rear_end(kit, hl, info)

	kit.mirror_x = false
	kit.color = Color(1, 1, 1, 1)
	info["plate_hidden"] = true


# --- helpers -------------------------------------------------------------------------------------

## A wing element: airfoil section (chord along z, thickness along y) extruded across the span,
## from the centreline out to `span`. `aoa` tips the trailing edge down (radians).
static func _wing(kit: MeshKit, key: String, centre: Vector3, span: float, chord: float,
		thick: float, aoa: float) -> void:
	var pts := PackedVector2Array()
	var n := 10
	# upper surface, nose to tail
	for i in n + 1:
		var u := float(i) / float(n)
		pts.append(Vector2(chord * (u - 0.5), _camber(u) * chord * 0.10 + thick * 0.5 * sin(PI * pow(u, 0.7))))
	# lower surface, tail back to nose
	for i in range(n, -1, -1):
		var u2 := float(i) / float(n)
		pts.append(Vector2(chord * (u2 - 0.5), _camber(u2) * chord * 0.10 - thick * 0.35 * sin(PI * pow(u2, 0.7))))
	# rotate the section by the angle of attack
	var rot := PackedVector2Array()
	for p in pts:
		rot.append(Vector2(p.x * cos(aoa) - p.y * sin(aoa), p.x * sin(aoa) + p.y * cos(aoa)))
	kit.prism(key, centre + Vector3(-span * 0.5, 0.0, 0.0), rot, Vector3.BACK, Vector3.UP, Vector3.LEFT, span)


## Mean camber line of the wing sections (positive = the trailing edge hangs down).
static func _camber(u: float) -> float:
	return -sin(PI * pow(u, 0.85)) * 0.9


static func _tube(kit: MeshKit, key: String, a: Vector3, b: Vector3, r0: float, r1: float = -1.0, segs: int = 8) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	kit.cylinder(key, a, d / l, l, r0, r1 if r1 >= 0.0 else r0, segs, false, false)


# --- major masses --------------------------------------------------------------------------------

## Flat floor from the front bulkhead to the rear axle, edge wings, and the diffuser ramp.
static func _floor_and_diffuser(kit: MeshKit, hl: float, wb: float, tf: float, tr: float) -> void:
	var z0 := -wb * 0.48
	var z1 := wb * 0.52
	var w0 := CELL_W + 0.07
	var w1 := tr - 0.17
	kit.color = CARBON
	var rows: Array = []
	var n := 8
	for i in n + 1:
		var u := float(i) / float(n)
		var z := lerpf(z0, z1, u)
		var w := lerpf(w0, w1, smoothstep(0.0, 0.40, u))
		rows.append(PackedVector3Array([Vector3(0.0, PLANK, z), Vector3(-w * 0.5, PLANK, z), Vector3(-w, PLANK, z)]))
	kit.grid("paint", rows, 1.0)
	# underside and the edge wall
	for i in n:
		var ua := float(i) / float(n)
		var ub := float(i + 1) / float(n)
		var za := lerpf(z0, z1, ua)
		var zb := lerpf(z0, z1, ub)
		var wa := lerpf(w0, w1, smoothstep(0.0, 0.40, ua))
		var wbb := lerpf(w0, w1, smoothstep(0.0, 0.40, ub))
		kit.color = BLACK
		kit.flat_quad("trim", Vector3(0.0, PLANK - 0.024, za), Vector3(-wa, PLANK - 0.024, za),
			Vector3(-wbb, PLANK - 0.024, zb), Vector3(0.0, PLANK - 0.024, zb), Vector3.DOWN)
		kit.flat_quad("trim", Vector3(-wa, PLANK, za), Vector3(-wbb, PLANK, zb),
			Vector3(-wbb, PLANK - 0.024, zb), Vector3(-wa, PLANK - 0.024, za), Vector3.LEFT)
	# diffuser: the floor kicks up behind the rear axle
	kit.color = CARBON
	var dh := 0.16
	var zd := z1 + 0.34
	kit.flat_quad("paint", Vector3(0.0, PLANK, z1), Vector3(-w1, PLANK, z1),
		Vector3(-w1, PLANK + dh, zd), Vector3(0.0, PLANK + dh, zd), Vector3.UP)
	kit.color = BLACK
	kit.flat_quad("trim", Vector3(0.0, PLANK - 0.02, z1), Vector3(0.0, PLANK + dh - 0.02, zd),
		Vector3(-w1, PLANK + dh - 0.02, zd), Vector3(-w1, PLANK - 0.02, z1), Vector3.DOWN)
	for k in 2:
		var xs := -0.22 - float(k) * 0.26
		kit.flat_quad("trim", Vector3(xs, PLANK, z1), Vector3(xs, PLANK + dh, zd),
			Vector3(xs, PLANK + dh + 0.06, zd), Vector3(xs, PLANK + 0.06, z1), Vector3.LEFT)
	# floor edge fence alongside the cockpit
	kit.color = CARBON
	kit.box("paint", Vector3(-(w0 + 0.12), PLANK + 0.05, -wb * 0.10), Vector3(0.016, 0.10, 0.86))


## Survival cell: a tub that tapers from the front bulkhead back to the engine bulkhead.
static func _cell(kit: MeshKit, wb: float) -> void:
	kit.color = PAINT
	var stations := [
		[-wb * 0.50, CELL_W * 0.50, PLANK + 0.015, 0.345],
		[-wb * 0.32, CELL_W * 0.76, PLANK + 0.015, 0.405],
		[-wb * 0.10, CELL_W * 0.97, PLANK + 0.015, 0.455],
		[wb * 0.10, CELL_W, PLANK + 0.020, 0.480],
		[wb * 0.28, CELL_W * 0.94, PLANK + 0.025, 0.500],
		[wb * 0.46, CELL_W * 0.78, PLANK + 0.030, 0.510],
	]
	var rows: Array = []
	for st in stations:
		var z: float = st[0]
		var w: float = st[1]
		var fy: float = st[2]
		var dy: float = st[3]
		rows.append(PackedVector3Array([
			Vector3(0.0, fy, z),
			Vector3(-w * 0.70, fy + 0.004, z),
			Vector3(-w, fy + 0.060, z),
			Vector3(-w, lerpf(fy, dy, 0.66), z),
			Vector3(-w * 0.88, dy - 0.018, z),
			Vector3(-w * 0.42, dy, z),
			Vector3(0.0, dy + 0.004, z),
		]))
	kit.grid("paint", rows, 0.0)
	kit.color = BLACK
	var b: PackedVector3Array = rows[rows.size() - 1]
	for i in b.size() - 1:
		kit.flat_tri("trim", Vector3(0.0, 0.26, b[0].z), b[i], b[i + 1], Vector3.BACK)


## Raised nose from the front bulkhead to the crash-structure tip.
static func _nose(kit: MeshKit, hl: float, wb: float, info: Dictionary) -> void:
	kit.color = PAINT
	var z_tip := -hl + 0.13
	var z_bulk := -wb * 0.50
	var rows: Array = []
	var n := 7
	for i in n + 1:
		var u := float(i) / float(n)
		var z := lerpf(z_tip, z_bulk, u)
		var w := lerpf(0.060, CELL_W * 0.50, pow(u, 0.70))
		var y0 := lerpf(0.300, PLANK + 0.015, pow(u, 1.6))
		var y1 := lerpf(0.395, 0.345, u)
		rows.append(PackedVector3Array([
			Vector3(0.0, y0, z), Vector3(-w * 0.78, y0 + 0.012, z), Vector3(-w, lerpf(y0, y1, 0.5), z),
			Vector3(-w * 0.78, y1 - 0.010, z), Vector3(0.0, y1, z)]))
	kit.grid("paint", rows, 0.0)
	kit.color = BLACK
	var t: PackedVector3Array = rows[0]
	for i in t.size() - 1:
		kit.flat_tri("trim", Vector3(0.0, 0.348, t[0].z - 0.012), t[i], t[i + 1], Vector3.FORWARD)
	# LED position lamps on the nose shoulders (our night-city rule) and an amber marker
	kit.color = L_HEAD
	kit.box("lights", Vector3(-0.048, 0.352, z_tip + 0.035), Vector3(0.045, 0.020, 0.028))
	info["headlights"].append(Vector3(-0.055, 0.352, z_tip + 0.01))
	info["headlights"].append(Vector3(0.055, 0.352, z_tip + 0.01))
	kit.color = L_AMBER
	kit.box("lights", Vector3(-0.085, 0.315, z_tip + 0.10), Vector3(0.022, 0.016, 0.05))


## Two-element front wing with endplates, on two pylons under the nose.
static func _front_wing(kit: MeshKit, hl: float, tf: float, info: Dictionary) -> void:
	var z := -hl + 0.20
	var span := (tf + 0.00) * 2.0            # full span, tip to tip
	kit.color = CARBON
	_wing(kit, "paint", Vector3(0.0, 0.095, z), span, 0.26, 0.030, 0.17)
	kit.color = ACCENT
	_wing(kit, "paint", Vector3(0.0, 0.165, z + 0.115), span * 0.97, 0.13, 0.016, 0.34)
	# endplates: a vertical plate turned slightly out, with a carbon footplate
	var x := span * 0.5
	kit.color = ACCENT
	kit.box("paint", Vector3(-x, 0.145, z + 0.03), Vector3(0.015, 0.21, 0.40), Basis(Vector3.UP, 0.05))
	kit.color = CARBON
	kit.box("paint", Vector3(-x - 0.012, 0.050, z + 0.03), Vector3(0.040, 0.020, 0.38), Basis(Vector3.UP, 0.05))
	# pylons up to the nose
	kit.color = CARBON
	for xo in [0.075, 0.175]:
		kit.box("paint", Vector3(-xo, 0.215, z + 0.10), Vector3(0.020, 0.24, 0.085), Basis(Vector3.RIGHT, 0.30))


## Wedge sidepods with a cooling inlet, a side-impact tube and a bargeboard.
static func _sidepods(kit: MeshKit, wb: float, tr: float) -> void:
	kit.color = PAINT
	var z0 := -wb * 0.17
	var z1 := wb * 0.50
	var rows: Array = []
	var n := 8
	for i in n + 1:
		var u := float(i) / float(n)
		var z := lerpf(z0, z1, u)
		var w := lerpf(CELL_W + 0.055, tr - 0.195, smoothstep(0.0, 0.28, u)) * (1.0 - smoothstep(0.60, 1.0, u) * 0.52)
		var top := lerpf(0.330, 0.275, smoothstep(0.08, 1.0, u))
		var bot := PLANK + 0.010 + smoothstep(0.40, 1.0, u) * 0.105
		rows.append(PackedVector3Array([
			Vector3(-CELL_W * 0.95, bot + 0.02, z),
			Vector3(-w * 0.82, bot, z),
			Vector3(-w, lerpf(bot, top, 0.42), z),
			Vector3(-w * 0.95, top - 0.008, z),
			Vector3(-CELL_W * 0.95, top + 0.045, z),
		]))
	kit.grid("paint", rows, 0.0)
	# inlet mouth: a dark recess in the front face of the pod
	kit.color = DARK
	var mouth: PackedVector3Array = rows[0]
	for i in mouth.size() - 1:
		kit.flat_tri("trim", Vector3(-(CELL_W + 0.10), 0.19, z0 - 0.004), mouth[i], mouth[i + 1], Vector3.FORWARD)
	kit.color = GREY
	kit.box("trim", Vector3(-(CELL_W + 0.115), 0.19, z0 - 0.014), Vector3(0.14, 0.085, 0.010))
	# side impact structure along the pod shoulder
	kit.color = CARBON
	_tube(kit, "paint", Vector3(-(CELL_W + 0.03), 0.215, z0 + 0.03), Vector3(-(CELL_W + 0.26), 0.195, z0 + 0.34), 0.035, 0.030, 10)
	# bargeboard ahead of the pod
	kit.color = CARBON
	kit.box("paint", Vector3(-(CELL_W + 0.115), 0.150, z0 - 0.30), Vector3(0.014, 0.17, 0.40), Basis(Vector3.UP, -0.10))


## Engine cover: from behind the cockpit to the rear crash structure, with the airbox scoop.
static func _engine_cover(kit: MeshKit, hl: float, wb: float) -> void:
	kit.color = PAINT
	var z0 := wb * 0.06
	var z1 := hl - 0.50
	var rows: Array = []
	var n := 8
	for i in n + 1:
		var u := float(i) / float(n)
		var z := lerpf(z0, z1, u)
		var w := lerpf(CELL_W * 0.92, 0.095, pow(u, 1.2))
		var top := lerpf(0.520, 0.330, pow(u, 1.5))
		var bot := PLANK + 0.115 + u * 0.055
		rows.append(PackedVector3Array([
			Vector3(0.0, bot, z),
			Vector3(-w * 0.9, bot + 0.02, z),
			Vector3(-w, lerpf(bot, top, 0.55), z),
			Vector3(-w * 0.6, top - 0.012, z),
			Vector3(0.0, top, z),
		]))
	kit.grid("paint", rows, 0.0)
	# airbox over the roll hoop, feeding back into the cover
	kit.color = PAINT
	var scoop: Array = []
	var ns := 6
	for i in ns + 1:
		var u2 := float(i) / float(ns)
		var z2 := lerpf(z0 - 0.14, z0 + 0.42, u2)
		var w2 := lerpf(0.090, 0.150, sin(PI * u2 * 0.6))
		var top2 := lerpf(0.880, 0.560, pow(u2, 1.5))
		var bot2 := lerpf(0.700, 0.500, u2)
		scoop.append(PackedVector3Array([
			Vector3(0.0, bot2, z2), Vector3(-w2 * 0.88, bot2 + 0.012, z2),
			Vector3(-w2, lerpf(bot2, top2, 0.5), z2), Vector3(-w2 * 0.66, top2 - 0.010, z2),
			Vector3(0.0, top2, z2)]))
	kit.grid("paint", scoop, 0.0)
	kit.color = DARK
	var mouth: PackedVector3Array = scoop[0]
	for i in mouth.size() - 1:
		kit.flat_tri("trim", Vector3(0.0, 0.790, z2_of(scoop) - 0.006), mouth[i], mouth[i + 1], Vector3.FORWARD)
	# shark fin along the spine: a thin triangular blade from the airbox to the rear wing
	kit.mirror_x = false
	kit.color = ACCENT
	for sgn in [-1.0, 1.0]:
		kit.flat_tri("paint", Vector3(sgn * 0.006, 0.555, z0 + 0.40), Vector3(sgn * 0.006, 0.345, z1),
			Vector3(sgn * 0.006, 0.470, z0 + 0.40), Vector3(sgn, 0.0, 0.0))
	kit.flat_quad("paint", Vector3(-0.006, 0.555, z0 + 0.40), Vector3(0.006, 0.555, z0 + 0.40),
		Vector3(0.006, 0.345, z1), Vector3(-0.006, 0.345, z1), Vector3.UP)
	kit.mirror_x = true


static func z2_of(scoop: Array) -> float:
	return (scoop[0] as PackedVector3Array)[0].z


## Cockpit opening: padded rim, dash, steering wheel, mirrors.
static func _cockpit(kit: MeshKit) -> void:
	kit.color = BLACK
	var zc := -0.14
	var n := 12
	var prev := Vector3.ZERO
	for i in n + 1:
		var a := PI * float(i) / float(n)
		var p := Vector3(-sin(a) * CELL_W * 0.80, 0.470 + cos(a) * 0.012, zc - cos(a) * 0.40)
		if i > 0:
			_tube(kit, "trim", prev, p, 0.021, 0.021, 6)
		prev = p
	# dash bulkhead
	kit.color = DARK
	kit.box("trim", Vector3(-CELL_W * 0.32, 0.420, zc - 0.295), Vector3(CELL_W * 0.64, 0.090, 0.085), Basis(Vector3.RIGHT, 0.38))
	kit.mirror_x = false
	# steering wheel (a squared-off rim with a screen in the middle)
	kit.color = GREY
	kit.cylinder("trim", Vector3(0.0, 0.452, zc - 0.215), Vector3(0.0, 0.40, -0.92).normalized(), 0.030, 0.100, 0.100, 16)
	kit.color = L_SCREEN
	kit.box("lights", Vector3(0.0, 0.470, zc - 0.238), Vector3(0.115, 0.030, 0.010), Basis(Vector3.RIGHT, 0.40))
	kit.mirror_x = true
	# mirrors on stalks
	kit.color = PAINT
	kit.box("paint", Vector3(-CELL_W - 0.055, 0.462, zc - 0.255), Vector3(0.105, 0.048, 0.050))
	kit.color = CHROME
	kit.box("chrome", Vector3(-CELL_W - 0.102, 0.462, zc - 0.258), Vector3(0.012, 0.040, 0.042))


## The halo: a titanium hoop over the cockpit with a central strut.
static func _halo(kit: MeshKit) -> void:
	kit.color = DARK
	var zc := -0.14
	var ring: Array[Vector3] = []
	var n := 10
	for i in n + 1:
		var u := float(i) / float(n)
		var a := PI * u
		ring.append(Vector3(-sin(a) * (CELL_W + 0.035),
			lerpf(0.720, 0.495, pow(sin(a * 0.5), 1.4)),
			zc - 0.44 + (1.0 - cos(a)) * 0.50))
	for i in ring.size() - 1:
		_tube(kit, "trim", ring[i], ring[i + 1], 0.025, 0.025, 8)
	kit.mirror_x = false
	_tube(kit, "trim", ring[0], ring[0] + Vector3(0.0, -0.30, -0.055), 0.028, 0.032, 8)
	kit.mirror_x = true


## Driver: shoulders in a race suit, helmet with a visor, arms to the wheel.
static func _driver(kit: MeshKit) -> void:
	var zc := -0.14
	kit.mirror_x = false
	kit.color = SUIT
	kit.box("trim", Vector3(0.0, 0.430, zc + 0.115), Vector3(CELL_W * 1.42, 0.150, 0.280), Basis(Vector3.RIGHT, 0.18))
	# helmet
	kit.color = ACCENT
	kit.cylinder("paint", Vector3(-0.112, 0.585, zc - 0.015), Vector3.RIGHT, 0.224, 0.112, 0.112, 20)
	kit.color = Color(0.03, 0.03, 0.04, 1)
	kit.box("trim", Vector3(0.0, 0.572, zc - 0.112), Vector3(0.200, 0.072, 0.028), Basis(Vector3.RIGHT, 0.04))
	kit.color = Color(0.14, 0.20, 0.28, 1)
	kit.box("glass", Vector3(0.0, 0.578, zc - 0.124), Vector3(0.182, 0.058, 0.012))
	# HANS collar
	kit.color = BLACK
	kit.box("trim", Vector3(0.0, 0.492, zc + 0.015), Vector3(0.265, 0.040, 0.120), Basis(Vector3.RIGHT, 0.20))
	kit.mirror_x = true
	# arms
	kit.color = SUIT
	_tube(kit, "trim", Vector3(-0.095, 0.462, zc + 0.045), Vector3(-0.055, 0.452, zc - 0.185), 0.040, 0.034, 8)
	kit.color = SKIN
	kit.box("trim", Vector3(-0.058, 0.452, zc - 0.205), Vector3(0.050, 0.055, 0.060))


## Pushrod suspension: wishbones, pushrod and upright at each corner.
static func _suspension(kit: MeshKit, wb: float, tf: float, tr: float, r: float) -> void:
	for axle in [[-wb * 0.5, tf, true], [wb * 0.5, tr, false]]:
		var z: float = axle[0]
		var t: float = axle[1]
		var front: bool = axle[2]
		var sgn := 1.0 if front else -1.0
		var hub := Vector3(-t + 0.035, r - 0.040, z)
		kit.color = DARK
		for pair in [
			[hub + Vector3(0.02, -0.105, 0.0), Vector3(-0.165, 0.095, z + sgn * 0.105)],
			[hub + Vector3(0.02, -0.105, 0.0), Vector3(-0.165, 0.095, z - sgn * 0.215)],
			[hub + Vector3(0.02, 0.095, 0.0), Vector3(-0.150, 0.330, z + sgn * 0.085)],
			[hub + Vector3(0.02, 0.095, 0.0), Vector3(-0.150, 0.330, z - sgn * 0.195)],
			[hub + Vector3(0.02, -0.080, 0.0), Vector3(-0.120, 0.420, z + sgn * 0.020)],
			[hub + Vector3(0.02, 0.020, sgn * 0.09), Vector3(-0.160, 0.215, z + sgn * 0.17)],
		]:
			_tube(kit, "trim", pair[0], pair[1], 0.018, 0.015, 7)
		kit.color = ALU
		kit.box("trim", hub, Vector3(0.048, 0.230, 0.058))


## Two-element rear wing on a swan-neck mount, plus the beam wing.
static func _rear_wing(kit: MeshKit, hl: float, tr: float) -> void:
	var z := hl - 0.26
	var span := (tr - 0.21) * 2.0
	kit.color = PAINT
	_wing(kit, "paint", Vector3(0.0, 0.790, z), span, 0.30, 0.034, 0.26)
	kit.color = ACCENT
	_wing(kit, "paint", Vector3(0.0, 0.885, z + 0.145), span * 0.98, 0.14, 0.018, 0.46)
	# endplates
	var x := span * 0.5
	kit.color = ACCENT
	kit.box("paint", Vector3(-x, 0.800, z + 0.035), Vector3(0.016, 0.34, 0.50))
	kit.color = CARBON
	kit.box("paint", Vector3(-x - 0.008, 0.590, z + 0.045), Vector3(0.016, 0.10, 0.44))
	# swan-neck supports
	kit.color = CARBON
	for xo in [0.085, 0.205]:
		kit.box("paint", Vector3(-xo, 0.640, z - 0.085), Vector3(0.020, 0.33, 0.085), Basis(Vector3.RIGHT, -0.22))
	# beam wing low behind the gearbox
	kit.color = CARBON
	_wing(kit, "paint", Vector3(0.0, 0.330, z - 0.02), span * 0.70, 0.17, 0.022, 0.20)


## Gearbox, crash structure, exhaust and the rain light.
static func _rear_end(kit: MeshKit, hl: float, info: Dictionary) -> void:
	kit.mirror_x = false
	kit.color = GREY
	kit.box("trim", Vector3(0.0, 0.245, hl - 0.60), Vector3(0.250, 0.215, 0.44))
	kit.color = DARK
	kit.cylinder("trim", Vector3(0.0, 0.235, hl - 0.40), Vector3.BACK, 0.22, 0.052, 0.042, 10)
	kit.color = CHROME
	kit.cylinder("chrome", Vector3(0.0, 0.370, hl - 0.44), Vector3(0.0, 0.07, 1.0).normalized(), 0.22, 0.044, 0.048, 12)
	info["exhausts"].append(Vector3(0.0, 0.385, hl - 0.22))
	info["exhaust_r"] = 0.048
	# rain light under the beam wing
	kit.color = L_TAIL
	kit.box("lights", Vector3(0.0, 0.255, hl - 0.195), Vector3(0.075, 0.075, 0.020))
	# roll hoop camera pod
	kit.color = ACCENT
	kit.box("paint", Vector3(0.0, 0.905, 0.145), Vector3(0.065, 0.045, 0.135))
	kit.mirror_x = true
	kit.color = DARK
	kit.box("trim", Vector3(-CELL_W * 0.55, 0.680, -0.38), Vector3(0.045, 0.040, 0.095))
