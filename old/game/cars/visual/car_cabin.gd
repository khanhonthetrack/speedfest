class_name CarCabin
extends RefCounted
## Car interior and driver (session 7, owner: "Interiors suck, they look weird. Put effort, put a
## driver inside as well."). Built into the body MeshKit in ground space, from CarShape.cabin():
## the shell's deck under the glass is already sunk into a dark tub (CarBody.section), so here go
## the bucket seats (and a rear bench on 2+2s), the dash binnacle with glowing gauges, the center
## console and shifter, door cards, the rear-view mirror, the steering wheel and the driver:
## helmet in the vinyl (accent) color with a smoked visor, race suit, gloves on the wheel at ten
## and two, legs down to the pedals. Right-hand drive on the JDM cars (CarShape.CABIN_RHD).
## Roughly 2k triangles; surfaces: "trim" (vertex colored), "paint" (helmet), "chrome" (visor,
## shifter knob), "lights" (gauges, instrument type A = 0.1).

const SHELL := Color(0.05, 0.05, 0.055, 1)        # seat shells, binnacle, console
const DARK := Color(0.025, 0.025, 0.028, 1)       # wheel rim, gloves, shoes
const METAL := Color(0.16, 0.16, 0.17, 1)         # spokes, column, rails
const VISOR := Color(0.07, 0.06, 0.055, 1)        # smoked visor (on chrome: a dark mirror)
const GAUGE := Color(0.3, 0.85, 1.0, 0.1)         # lights surface, instrument type
const SCREEN := Color(0.25, 0.35, 0.9, 0.1)
const NEEDLE := Color(1.0, 0.15, 0.05, 1)

## Per car: seat insert / door trim color and race suit color.
const COLORS := {
	"kaze": [Color(0.42, 0.04, 0.035), Color(0.78, 0.78, 0.8)],
	"brute": [Color(0.32, 0.2, 0.1), Color(0.12, 0.22, 0.65)],
	"veloce": [Color(0.45, 0.05, 0.04), Color(0.55, 0.06, 0.05)],
	"kitsune": [Color(0.06, 0.14, 0.45), Color(0.1, 0.28, 0.8)],
	"pixie": [Color(0.6, 0.55, 0.45), Color(0.05, 0.5, 0.45)],
	"goliath": [Color(0.22, 0.13, 0.07), Color(0.7, 0.3, 0.03)],
}
const HARNESS := Color(0.75, 0.05, 0.04, 1)


static func build(s: CarShape, kit: MeshKit) -> void:
	var c := s.cabin()
	var k: float = c["k"]
	var side: float = c["side"]
	var cols: Array = COLORS.get(s.car_id, COLORS["kaze"])
	var insert: Color = cols[0]
	var suit: Color = cols[1]
	var xs: float = c["x_seat"]
	kit.mirror_x = false
	_seat(s, kit, c, side * xs, insert, false)
	_seat(s, kit, c, -side * xs, insert, false)
	if c["rear"]:
		_rear_bench(s, kit, c, insert)
	_dash(s, kit, c, side * xs)
	_console(s, kit, c)
	_doors(s, kit, c, insert)
	_mirror(s, kit)
	_wheel(kit, c, side * xs)
	_driver(s, kit, c, side * xs, suit)
	kit.color = Color(1, 1, 1, 1)


# --- primitives -----------------------------------------------------------------------------------

## Ellipsoid (or a patch of one): lat from -PI/2 (bottom) to PI/2 (top), lon 0 = forward (-z),
## positive lon toward +x. `b` orients it.
static func ellipsoid(kit: MeshKit, key: String, c: Vector3, rad: Vector3, rings: int, segs: int,
		b := Basis.IDENTITY, lat0 := -PI * 0.5, lat1 := PI * 0.5, lon0 := -PI, lon1 := PI) -> void:
	for i in rings:
		var la0 := lerpf(lat0, lat1, float(i) / float(rings))
		var la1 := lerpf(lat0, lat1, float(i + 1) / float(rings))
		for j in segs:
			var lo0 := lerpf(lon0, lon1, float(j) / float(segs))
			var lo1 := lerpf(lon0, lon1, float(j + 1) / float(segs))
			var p := [_ell(c, rad, b, la0, lo0), _ell(c, rad, b, la0, lo1), _ell(c, rad, b, la1, lo1), _ell(c, rad, b, la1, lo0)]
			kit.quad(key, p[0][0], p[1][0], p[2][0], p[3][0], p[0][1], p[1][1], p[2][1], p[3][1])


static func _ell(c: Vector3, rad: Vector3, b: Basis, la: float, lo: float) -> Array:
	var d := Vector3(cos(la) * sin(lo), sin(la), -cos(la) * cos(lo))
	return [c + b * (d * rad), (b * (d / rad)).normalized()]


## Torus around axis `n` (steering wheel rim).
static func torus(kit: MeshKit, key: String, c: Vector3, n: Vector3, big_r: float, r: float, segs: int, sides: int) -> void:
	var u := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := n.cross(u).normalized()
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var e0 := u * cos(a0) + v * sin(a0)
		var e1 := u * cos(a1) + v * sin(a1)
		for j in sides:
			var b0 := TAU * float(j) / float(sides)
			var b1 := TAU * float(j + 1) / float(sides)
			var o00 := e0 * cos(b0) + n * sin(b0)
			var o01 := e0 * cos(b1) + n * sin(b1)
			var o10 := e1 * cos(b0) + n * sin(b0)
			var o11 := e1 * cos(b1) + n * sin(b1)
			kit.quad(key, c + e0 * big_r + o00 * r, c + e0 * big_r + o01 * r, c + e1 * big_r + o11 * r, c + e1 * big_r + o10 * r,
				o00, o01, o11, o10)


## Tapered limb from a to b.
static func limb(kit: MeshKit, key: String, a: Vector3, b: Vector3, ra: float, rb: float, segs := 7) -> void:
	var d := b - a
	if d.length() < 0.005:
		return
	kit.cylinder(key, a, d, d.length(), ra, rb, segs, true, true)


## Rounded rectangle cross-section (superellipse), for the torso.
static func _round_rect(hw: float, hd: float, n := 10) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var e := Vector2(cos(a), sin(a))
		e = e.sign() * Vector2(pow(absf(e.x), 0.55), pow(absf(e.y), 0.55))
		poly.append(Vector2(e.x * hw, e.y * hd))
	return poly


# --- parts ----------------------------------------------------------------------------------------

## Bucket seat centered on x: cushion, backrest along the torso recline, side bolsters, integrated
## headrest, colored inserts, base down to the floor.
static func _seat(_s: CarShape, kit: MeshKit, c: Dictionary, x: float, insert: Color, _rear: bool) -> void:
	var k: float = c["k"]
	var th: float = c["theta"]
	var tdir: Vector3 = c["tdir"]
	var fwd := Vector3(0.0, sin(th), -cos(th))     # out of the backrest, toward the driver's chest
	var hip: Vector3 = c["hip"]
	hip.x = x
	var floor_y: float = c["floor_y"]
	var back_b := Basis(Vector3.RIGHT, tdir, -fwd)
	var back_c := hip + tdir * (0.32 * k) - fwd * (0.12 * k + 0.035)
	kit.color = SHELL
	kit.box("trim", back_c, Vector3(0.5 * k, 0.64 * k, 0.08 * k), back_b)
	for sx in [-1.0, 1.0]:
		var bb := back_b * Basis(Vector3.UP, sx * 0.4)
		kit.box("trim", back_c + Vector3.RIGHT * (sx * 0.22 * k) + fwd * (0.05 * k), Vector3(0.07 * k, 0.56 * k, 0.15 * k), bb)
	# headrest wings of the bucket
	kit.box("trim", back_c + tdir * (0.39 * k) + fwd * (0.01 * k), Vector3(0.28 * k, 0.17 * k, 0.09 * k), back_b)
	kit.color = insert
	kit.box("trim", back_c + fwd * (0.042 * k) - tdir * (0.04 * k), Vector3(0.22 * k, 0.48 * k, 0.012), back_b)
	# cushion, front edge raised a little
	var cush_b := Basis(Vector3.RIGHT, -0.12)
	var cush_c := hip + Vector3(0.0, -0.1 * k, -0.13 * k)
	kit.color = SHELL
	kit.box("trim", cush_c, Vector3(0.46 * k, 0.09 * k, 0.5 * k), cush_b)
	for sx in [-1.0, 1.0]:
		kit.box("trim", cush_c + Vector3(sx * 0.2 * k, 0.05 * k, 0.0), Vector3(0.07 * k, 0.08 * k, 0.46 * k), cush_b)
	kit.color = insert
	kit.box("trim", cush_c + Vector3(0.0, 0.046 * k, 0.0), Vector3(0.22 * k, 0.012, 0.4 * k), cush_b)
	# base / rails down to the floor
	var top := cush_c.y - 0.045 * k
	if top > floor_y + 0.02:
		kit.color = METAL
		kit.box("trim", Vector3(x, (top + floor_y) * 0.5, cush_c.z), Vector3(0.36 * k, top - floor_y, 0.36 * k))


static func _rear_bench(_s: CarShape, kit: MeshKit, c: Dictionary, insert: Color) -> void:
	var k: float = c["k"]
	var hip: Vector3 = c["hip"]
	var rz: float = c["rear_z"]
	var floor_y: float = c["floor_y"]
	var w := (float(c["x_wall"]) - 0.06) * 2.0
	var th := deg_to_rad(16.0)
	var tdir := Vector3(0.0, cos(th), sin(th))
	var fwd := Vector3(0.0, sin(th), -cos(th))
	var back_b := Basis(Vector3.RIGHT, tdir, -fwd)
	var y_hip := hip.y - 0.02 * k
	var cz := Vector3(0.0, y_hip - 0.1 * k, rz - 0.12 * k)
	kit.color = SHELL
	kit.box("trim", cz, Vector3(w, 0.1 * k, 0.46 * k))
	kit.box("trim", Vector3(0.0, (cz.y - 0.05 * k + floor_y) * 0.5, cz.z), Vector3(w, maxf(cz.y - 0.05 * k - floor_y, 0.02), 0.42 * k))
	var bc := Vector3(0.0, y_hip, rz) + tdir * (0.28 * k) - fwd * (0.12 * k)
	kit.box("trim", bc, Vector3(w, 0.56 * k, 0.1 * k), back_b)
	kit.color = insert
	for sx in [-1.0, 1.0]:
		kit.box("trim", bc + Vector3.RIGHT * (sx * 0.3 * k) + fwd * (0.052 * k), Vector3(0.3 * k, 0.42 * k, 0.012), back_b)
	kit.color = SHELL
	for sx in [-1.0, 1.0]:
		kit.box("trim", bc + Vector3.RIGHT * (sx * 0.3 * k) + tdir * (0.34 * k), Vector3(0.22 * k, 0.13 * k, 0.08 * k), back_b)


## Binnacle over glowing gauges in front of the driver, a center screen, a needle each.
static func _dash(s: CarShape, kit: MeshKit, c: Dictionary, x: float) -> void:
	var k: float = c["k"]
	var td: float = c["t_dash"]
	var zd := s.z_of(td)
	var yd := s.deck_y(absf(x), td)
	kit.color = SHELL
	kit.box("trim", Vector3(x, yd + 0.03, zd - 0.05), Vector3(0.36 * k, 0.06, 0.16))
	kit.box("trim", Vector3(x, yd + 0.005, zd + 0.035), Vector3(0.36 * k, 0.07, 0.03))
	for gx in [-0.08, 0.08]:
		var gc := Vector3(x + gx * k, yd - 0.045, zd + 0.008)
		kit.color = GAUGE
		kit.cylinder("lights", gc, Vector3.BACK, 0.006, 0.055 * k, 0.055 * k, 14, false, true)
		kit.color = DARK
		kit.cylinder("trim", gc + Vector3(0, 0, 0.004), Vector3.BACK, 0.004, 0.04 * k, 0.04 * k, 12, false, true)
		kit.color = NEEDLE
		kit.box("trim", gc + Vector3(0.012 * k, 0.012 * k, 0.01), Vector3(0.006, 0.04 * k, 0.003), Basis(Vector3.BACK, -0.9))
	# center screen
	kit.color = SCREEN
	kit.box("lights", Vector3(0.0, yd - 0.07, zd + 0.006), Vector3(0.17 * k, 0.09 * k, 0.006))


static func _console(s: CarShape, kit: MeshKit, c: Dictionary) -> void:
	var k: float = c["k"]
	var hip: Vector3 = c["hip"]
	var floor_y: float = c["floor_y"]
	var zd := s.z_of(float(c["t_dash"]))
	var z1 := hip.z + 0.05
	var top := hip.y - 0.02
	kit.color = SHELL
	kit.box("trim", Vector3(0.0, (top + floor_y) * 0.5, (zd + z1) * 0.5), Vector3(0.2 * k, top - floor_y, z1 - zd))
	var sz := hip.z - 0.32 * k
	kit.color = METAL
	kit.cylinder("trim", Vector3(0.0, top, sz), Vector3(0, 1, -0.25), 0.13 * k, 0.009, 0.008, 6)
	kit.color = Color(0.8, 0.8, 0.82, 1)
	CarCabin.ellipsoid(kit, "chrome", Vector3(0.0, top + 0.125 * k, sz - 0.03 * k), Vector3(0.022, 0.022, 0.022) * k, 4, 8)


## Door cards: armrest, pull handle, colored trim line, on both sides of the tub.
static func _doors(s: CarShape, kit: MeshKit, c: Dictionary, insert: Color) -> void:
	var k: float = c["k"]
	var hip: Vector3 = c["hip"]
	var xw: float = c["x_wall"]
	var za := hip.z - 0.42 * k
	var zb := hip.z + 0.1 * k
	kit.mirror_x = true
	kit.color = SHELL
	kit.box("trim", Vector3(xw - 0.03, hip.y + 0.1 * k, (za + zb) * 0.5), Vector3(0.06, 0.05, zb - za))
	kit.color = insert
	var yl := s.belt(s.t_of(hip.z)) - 0.07
	kit.box("trim", Vector3(xw - 0.004, yl, (za + zb) * 0.5), Vector3(0.006, 0.02, (zb - za) * 1.2))
	kit.color = Color(0.7, 0.7, 0.72, 1)
	kit.box("chrome", Vector3(xw - 0.012, yl - 0.05, za + 0.08), Vector3(0.012, 0.02, 0.08))
	kit.mirror_x = false


static func _mirror(s: CarShape, kit: MeshKit) -> void:
	var t1: float = s.gh["ws_top"]
	var z := s.z_of(t1) + 0.06
	var y := float(s.gh["roof_y"]) - 0.1
	kit.color = DARK
	kit.box("trim", Vector3(0.0, y + 0.05, z - 0.01), Vector3(0.02, 0.06, 0.02))
	kit.box("trim", Vector3(0.0, y, z), Vector3(0.22, 0.055, 0.025))


## Steering wheel: rim, three spokes, hub with a red center, column into the dash.
static func _wheel(kit: MeshKit, c: Dictionary, x: float) -> void:
	var k: float = c["k"]
	var w: Vector3 = c["wheel"]
	w.x = x
	var n: Vector3 = c["wheel_n"]
	var r: float = c["wheel_r"]
	var u := Vector3.RIGHT
	var v := n.cross(u).normalized()
	if v.y < 0.0:
		v = -v
	kit.color = DARK
	CarCabin.torus(kit, "trim", w, n, r, 0.017 * k, 18, 6)
	kit.color = METAL
	for dirv in [u, -u, -v]:
		limb(kit, "trim", w, w + (dirv as Vector3) * (r - 0.01), 0.013 * k, 0.01 * k, 5)
	kit.cylinder("trim", w - n * 0.02, n, 0.04, 0.05 * k, 0.045 * k, 12)
	kit.color = NEEDLE
	kit.cylinder("trim", w + n * 0.02, n, 0.004, 0.02 * k, 0.02 * k, 10, false, true)
	kit.color = DARK
	limb(kit, "trim", w - n * 0.02, w - n * 0.32, 0.03 * k, 0.04 * k, 8)


## The driver: legs to the pedals, torso along the seat back, arms to the wheel at ten and two,
## gloves, neck, helmet (vinyl color) with a smoked visor. Head upright, looking ahead.
static func _driver(s: CarShape, kit: MeshKit, c: Dictionary, x: float, suit: Color) -> void:
	var k: float = c["k"]
	var tdir: Vector3 = c["tdir"]
	var th: float = c["theta"]
	var fwd := Vector3(0.0, sin(th), -cos(th))
	var hip: Vector3 = c["hip"]
	hip.x = x
	var shoulder: Vector3 = c["shoulder"]
	shoulder.x = x
	var head: Vector3 = c["head"]
	head.x = x
	var w: Vector3 = c["wheel"]
	w.x = x
	var n: Vector3 = c["wheel_n"]
	var wr: float = c["wheel_r"]
	var floor_y: float = c["floor_y"]
	var u := Vector3.RIGHT
	var v := n.cross(u).normalized()
	if v.y < 0.0:
		v = -v
	# legs
	for sx in [-1.0, 1.0]:
		var h := hip + Vector3(sx * 0.1 * k, 0.0, 0.0)
		var knee := hip + Vector3(sx * 0.11 * k, 0.12 * k, -0.44 * k)
		var foot := Vector3(knee.x, floor_y + 0.06 * k, knee.z - 0.3 * k)
		kit.color = suit
		limb(kit, "trim", h, knee, 0.075 * k, 0.06 * k)
		limb(kit, "trim", knee, foot, 0.055 * k, 0.045 * k)
		kit.color = DARK
		kit.box("trim", foot + Vector3(0, -0.01, -0.05 * k), Vector3(0.09 * k, 0.07 * k, 0.2 * k), Basis(Vector3.RIGHT, -0.5))
	# torso: belly and chest, rounded sections along the seat back
	kit.color = suit
	var chest0 := hip + tdir * (0.26 * k)
	var belly_mid := (hip + chest0) * 0.5
	kit.prism("trim", belly_mid, _round_rect(0.15 * k, 0.1 * k), Vector3.RIGHT, -fwd, tdir, 0.26 * k, true, true)
	var chest_mid := (chest0 + shoulder) * 0.5
	kit.prism("trim", chest_mid, _round_rect(0.21 * k, 0.115 * k), Vector3.RIGHT, -fwd, tdir, (shoulder - chest0).length() + 0.02, true, true)
	# arms: shoulders out to the hands on the rim at ten and two
	for sx in [-1.0, 1.0]:
		var sj := shoulder + Vector3(sx * 0.19 * k, -0.04 * k, 0.0)
		var hand: Vector3 = w + u * (sx * wr * 0.87) + v * (wr * 0.5)
		var elbow: Vector3 = (sj + hand) * 0.5 + Vector3(sx * 0.08 * k, -0.1 * k, 0.0)
		kit.color = suit
		CarCabin.ellipsoid(kit, "trim", sj, Vector3(0.065, 0.065, 0.065) * k, 4, 8)
		limb(kit, "trim", sj, elbow, 0.052 * k, 0.045 * k)
		limb(kit, "trim", elbow, hand, 0.045 * k, 0.038 * k)
		kit.color = DARK
		CarCabin.ellipsoid(kit, "trim", hand, Vector3(0.042, 0.04, 0.05) * k, 4, 8)
	# neck with a padded collar (HANS-style) and the helmet (upright)
	kit.color = suit
	limb(kit, "trim", shoulder - tdir * 0.02, head + Vector3(0, -0.08 * k, 0.01), 0.055 * k, 0.05 * k, 8)
	kit.color = DARK
	CarCabin.torus(kit, "trim", shoulder + tdir * (0.015 * k), tdir, 0.085 * k, 0.03 * k, 12, 5)
	# helmet in the body paint with a vinyl-color stripe front to back, smoked visor
	var hc := head + Vector3(0.0, 0.01 * k, 0.0)
	var hr := Vector3(0.125, 0.135, 0.145) * k
	kit.color = CarParts.PAINT
	CarCabin.ellipsoid(kit, "paint", hc, hr, 8, 14)
	kit.color = CarParts.ACCENT
	CarCabin.ellipsoid(kit, "paint", hc, Vector3(hr.x, hr.z, hr.y) * 1.012, 6, 2, Basis(Vector3.RIGHT, PI * 0.5),
		deg_to_rad(-80.0), deg_to_rad(80.0), deg_to_rad(-11.0), deg_to_rad(11.0))
	kit.color = VISOR
	CarCabin.ellipsoid(kit, "chrome", hc + Vector3(0, 0, -0.004), hr * 1.035, 3, 8, Basis.IDENTITY,
		deg_to_rad(-16.0), deg_to_rad(22.0), deg_to_rad(-66.0), deg_to_rad(66.0))
	# shoulder harness over the chest
	kit.color = HARNESS
	for sx in [-1.0, 1.0]:
		var a: Vector3 = shoulder + Vector3(sx * 0.09 * k, 0.0, 0.0) + fwd * (0.115 * k)
		var b: Vector3 = hip + Vector3(sx * 0.07 * k, 0.06 * k, 0.0) + fwd * (0.105 * k)
		var mid := (a + b) * 0.5
		var dir := (a - b).normalized()
		kit.box("trim", mid, Vector3(0.045 * k, (a - b).length(), 0.01), Basis(Vector3.RIGHT, dir, Vector3.RIGHT.cross(dir).normalized()))
