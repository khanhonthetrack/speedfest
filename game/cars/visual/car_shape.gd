class_name CarShape
extends RefCounted
## Shape description of one car body: keyframed profiles along the length, plus helpers to sample
## the body surface. Heights here are meters above the GROUND (the builder shifts them to car space,
## where the ground is at y = -wheel_radius). t = 0 is the front bumper, t = 1 the rear bumper.
##
## Profiles (arrays of [t, value], Catmull-Rom interpolated):
##   bot    underside / sill height          belt   height of the body side top (fender line)
##   crown  deck height on the centerline    wmax   half width at the widest point of the side
##   tuck   how far the shoulder tucks in from wmax   wlow  inset of the sill from wmax
## Greenhouse (cabin) keys are t positions: cowl (windshield base), ws_top (roof front),
## roof_end (roof rear), back_end (where the back glass / fastback meets the deck).

var car_id: String
var g: Dictionary
var length: float
var half_w: float
var radius: float
var axle_t: Array[float] = []    # front, rear
var p: Dictionary = {}           # profile arrays
var gh: Dictionary = {}          # greenhouse params
var style_k: Dictionary = {}     # misc per-car styling numbers
var _cabin: Dictionary = {}

## Right-hand drive for the JDM coupe, a rear bench where the roof is long enough for one.
const CABIN_RHD: Array[String] = ["kaze"]
const CABIN_REAR_SEATS: Array[String] = ["kaze", "vector", "polonez"]


func _init(p_car_id: String) -> void:
	car_id = p_car_id
	g = CarDefs.geometry(car_id)
	length = g["length"]
	half_w = g["width"] * 0.5
	radius = g["wheel_radius"]
	var wb: float = g["wheelbase"]
	axle_t = [t_of(-wb * 0.5), t_of(wb * 0.5)]
	match car_id:
		"vector":
			_vector()
		"polonez":
			_polonez()
		"ridge":
			_ridge()
		"f4":
			_f4()
		_:
			_kaze()


func _kaze() -> void:
	# JDM sport coupe: wedge nose with pop-up lights, boxy flares over the arches, notchback.
	p["bot"] = [[0.0, 0.25], [0.05, 0.19], [0.14, 0.165], [0.86, 0.165], [0.95, 0.215], [1.0, 0.285]]
	p["belt"] = [[0.0, 0.55], [0.04, 0.65], [0.12, 0.73], [0.21, 0.78], [0.34, 0.80], [0.6, 0.845], [0.8, 0.885], [0.93, 0.905], [1.0, 0.875]]
	p["crown"] = [[0.0, 0.57], [0.04, 0.675], [0.12, 0.755], [0.25, 0.80], [0.36, 0.825], [0.75, 0.915], [0.82, 0.93], [0.94, 0.935], [1.0, 0.895]]
	p["wmax"] = [[0.0, 0.81], [0.015, 0.85], [0.05, 0.885], [0.12, 0.90], [0.5, 0.895], [0.88, 0.90], [0.95, 0.885], [0.985, 0.85], [1.0, 0.81]]
	p["tuck"] = [[0.0, 0.03], [0.3, 0.04], [0.6, 0.06], [1.0, 0.04]]
	p["wlow"] = [[0.0, 0.02], [1.0, 0.025]]
	gh = {"cowl": 0.355, "ws_top": 0.5, "roof_end": 0.7, "back_end": 0.805,
		"roof_y": g["height"], "roof_w": 0.61, "base_inset": 0.075, "roof_crown": 0.025,
		"notch": true, "side_glass_top": 0.83, "b_pillar": 0.62}
	style_k = {"flare": 0.032, "flare_box": true, "mid_frac": 0.5, "hood_from": 0.07, "hood_to": 0.35,
		"intake": false, "shoulder_r": 0.035}


func _vector() -> void:
	# Grand tourer V8: long low nose over a wide track, cab-back glasshouse, fastback tail with
	# big haunches over the rear wheels.
	p["bot"] = [[0.0, 0.19], [0.06, 0.145], [0.15, 0.125], [0.9, 0.125], [0.96, 0.16], [1.0, 0.22]]
	p["belt"] = [[0.0, 0.50], [0.04, 0.60], [0.13, 0.70], [0.26, 0.755], [0.42, 0.78], [0.58, 0.80], [0.74, 0.845], [0.9, 0.875], [1.0, 0.83]]
	p["crown"] = [[0.0, 0.52], [0.04, 0.62], [0.13, 0.715], [0.26, 0.77], [0.38, 0.80], [0.62, 0.875], [0.78, 0.90], [0.93, 0.895], [1.0, 0.845]]
	p["wmax"] = [[0.0, 0.88], [0.015, 0.93], [0.055, 0.965], [0.19, 0.985], [0.42, 0.955], [0.62, 0.965], [0.80, 0.99], [0.93, 0.98], [0.985, 0.94], [1.0, 0.89]]
	p["tuck"] = [[0.0, 0.035], [0.35, 0.055], [0.68, 0.085], [1.0, 0.05]]
	p["wlow"] = [[0.0, 0.03], [1.0, 0.035]]
	gh = {"cowl": 0.40, "ws_top": 0.545, "roof_end": 0.665, "back_end": 0.93,
		"roof_y": g["height"], "roof_w": 0.635, "base_inset": 0.085, "roof_crown": 0.028,
		"notch": false, "side_glass_top": 0.845, "b_pillar": 0.0}
	style_k = {"flare": 0.0, "flare_box": false, "mid_frac": 0.46, "hood_from": 0.05, "hood_to": 0.40,
		"intake": true, "intake_t": [0.56, 0.70], "intake_y": [0.26, 0.58], "shoulder_r": 0.042,
		"nose_bulge": 0.07, "tail_bulge": 0.045}


func _polonez() -> void:
	# Eastern Bloc classic: a wedge drawn with a ruler. Flat bonnet, upright glass on thin pillars,
	# slab sides with a single crease, and a near-vertical hatch. Crisp shoulders, no flares.
	p["bot"] = [[0.0, 0.30], [0.05, 0.235], [0.13, 0.205], [0.87, 0.205], [0.95, 0.245], [1.0, 0.315]]
	p["belt"] = [[0.0, 0.735], [0.035, 0.775], [0.12, 0.80], [0.3, 0.815], [0.55, 0.835], [0.8, 0.855], [0.95, 0.865], [1.0, 0.845]]
	p["crown"] = [[0.0, 0.75], [0.035, 0.80], [0.12, 0.825], [0.3, 0.835], [0.52, 0.855], [0.8, 0.875], [0.96, 0.88], [1.0, 0.855]]
	p["wmax"] = [[0.0, 0.775], [0.02, 0.815], [0.06, 0.835], [0.14, 0.84], [0.5, 0.838], [0.86, 0.84], [0.94, 0.835], [0.98, 0.815], [1.0, 0.775]]
	p["tuck"] = [[0.0, 0.018], [0.5, 0.022], [1.0, 0.018]]
	p["wlow"] = [[0.0, 0.012], [1.0, 0.014]]
	gh = {"cowl": 0.335, "ws_top": 0.485, "roof_end": 0.775, "back_end": 0.945,
		"roof_y": g["height"], "roof_w": 0.665, "base_inset": 0.055, "roof_crown": 0.018,
		"notch": false, "side_glass_top": 0.86, "b_pillar": 0.60}
	style_k = {"flare": 0.0, "flare_box": false, "mid_frac": 0.55, "hood_from": 0.05, "hood_to": 0.325,
		"intake": false, "shoulder_r": 0.022, "nose_bulge": 0.025, "tail_bulge": 0.015}


func _ridge() -> void:
	# Offroad pre-runner: high sills over long-travel suspension, tall flat nose, upright cab and a
	# short bed behind it (the deck drops between the body sides, then rises to the tailgate).
	p["bot"] = [[0.0, 0.56], [0.05, 0.47], [0.13, 0.42], [0.87, 0.42], [0.95, 0.47], [1.0, 0.55]]
	p["belt"] = [[0.0, 1.14], [0.03, 1.19], [0.15, 1.22], [0.3, 1.23], [0.55, 1.24], [0.97, 1.24], [1.0, 1.22]]
	p["crown"] = [[0.0, 1.16], [0.03, 1.21], [0.15, 1.25], [0.3, 1.27], [0.565, 1.28], [0.61, 0.93], [0.95, 0.91],
		[0.975, 0.95], [0.99, 1.18], [1.0, 1.20]]
	p["wmax"] = [[0.0, 0.95], [0.012, 0.99], [0.05, 1.01], [0.2, 1.02], [0.5, 1.01], [0.8, 1.02], [0.95, 1.01], [0.985, 0.99], [1.0, 0.96]]
	p["tuck"] = [[0.0, 0.02], [0.5, 0.03], [1.0, 0.02]]
	p["wlow"] = [[0.0, 0.02], [1.0, 0.02]]
	gh = {"cowl": 0.345, "ws_top": 0.425, "roof_end": 0.545, "back_end": 0.575,
		"roof_y": g["height"], "roof_w": 0.80, "base_inset": 0.05, "roof_crown": 0.02,
		"notch": true, "side_glass_top": 0.90, "b_pillar": 0.49}
	style_k = {"flare": 0.055, "flare_box": true, "mid_frac": 0.5, "hood_from": 0.04, "hood_to": 0.325,
		"intake": false, "shoulder_r": 0.03, "nose_bulge": 0.03, "tail_bulge": 0.01, "dip_pow": 14.0}


func _f4() -> void:
	# The single-seater has no lofted shell: cars/visual/formula_body.gd builds it from the
	# geometry. These profiles only describe the survival cell, so anything that samples the shape
	# (shadow blob, contact patch, garage framing) still gets sane numbers.
	var hw: float = half_w * 0.42
	p["bot"] = [[0.0, 0.08], [0.1, 0.06], [0.9, 0.06], [1.0, 0.09]]
	p["belt"] = [[0.0, 0.26], [0.18, 0.40], [0.45, 0.52], [0.7, 0.56], [1.0, 0.46]]
	p["crown"] = [[0.0, 0.28], [0.18, 0.44], [0.45, 0.58], [0.7, 0.62], [1.0, 0.50]]
	p["wmax"] = [[0.0, hw * 0.35], [0.12, hw * 0.7], [0.35, hw], [0.75, hw * 0.92], [1.0, hw * 0.5]]
	p["tuck"] = [[0.0, 0.02], [1.0, 0.02]]
	p["wlow"] = [[0.0, 0.01], [1.0, 0.01]]
	gh = {"cowl": 0.40, "ws_top": 0.47, "roof_end": 0.62, "back_end": 0.70,
		"roof_y": g["height"] * 0.8, "roof_w": hw * 0.5, "base_inset": 0.03, "roof_crown": 0.01,
		"notch": true, "side_glass_top": 0.5, "b_pillar": 0.0}
	style_k = {"flare": 0.0, "flare_box": false, "mid_frac": 0.5, "hood_from": 0.1, "hood_to": 0.3,
		"intake": false, "shoulder_r": 0.02, "nose_bulge": 0.01, "tail_bulge": 0.01}


## How far the body surface bulges out beyond the end stations (rounded nose/tail in plan view
## and in side view). Returns a z offset (negative at the front) for a point at (x, y, t).
func end_bulge(x: float, y: float, t: float) -> float:
	var ef: float = style_k.get("nose_bulge", 0.08)
	var er: float = style_k.get("tail_bulge", 0.05)
	var wf := 1.0 - smoothstep(0.0, 0.1, t)
	var wr := smoothstep(0.92, 1.0, t)
	if wf <= 0.0 and wr <= 0.0:
		return 0.0
	var w := maxf(wmax(t), 0.1)
	var u := clampf(absf(x) / w, 0.0, 1.0)
	var plan := 1.0 - pow(u, 2.2)
	var yb := bot(t)
	var yt := maxf(crown(t), belt(t))
	var v := clampf((y - yb) / maxf(yt - yb, 0.05), 0.0, 1.0)
	var vert := 1.0 - pow(absf(v - 0.45) / 0.55, 2.0) * 0.6
	return (-ef * wf + er * wr) * plan * vert


# --- coordinates --------------------------------------------------------------

func t_of(z: float) -> float:
	return (z + length * 0.5) / length


func z_of(t: float) -> float:
	return t * length - length * 0.5


## Catmull-Rom through keyframes [[t, v], ...] (clamped ends, slightly monotone-limited).
static func curve(keys: Array, t: float) -> float:
	var n := keys.size()
	if t <= keys[0][0]:
		return keys[0][1]
	if t >= keys[n - 1][0]:
		return keys[n - 1][1]
	var k := 0
	while k < n - 2 and t > keys[k + 1][0]:
		k += 1
	var t0: float = keys[k][0]
	var t1: float = keys[k + 1][0]
	var v0: float = keys[k][1]
	var v1: float = keys[k + 1][1]
	var vm: float = keys[k - 1][1] if k > 0 else v0
	var tm: float = keys[k - 1][0] if k > 0 else t0 - (t1 - t0)
	var vp: float = keys[k + 2][1] if k + 2 < n else v1
	var tp: float = keys[k + 2][0] if k + 2 < n else t1 + (t1 - t0)
	var h := t1 - t0
	# tangents (finite differences over non-uniform spacing)
	var m0 := (v1 - vm) / (t1 - tm) * h
	var m1 := (vp - v0) / (tp - t0) * h
	# limit overshoot
	var d := v1 - v0
	if absf(d) > 1e-6:
		m0 = clampf(m0, -3.0 * absf(d), 3.0 * absf(d))
		m1 = clampf(m1, -3.0 * absf(d), 3.0 * absf(d))
	var s := (t - t0) / h
	var s2 := s * s
	var s3 := s2 * s
	return (2 * s3 - 3 * s2 + 1) * v0 + (s3 - 2 * s2 + s) * m0 + (-2 * s3 + 3 * s2) * v1 + (s3 - s2) * m1


func bot(t: float) -> float:
	return curve(p["bot"], t)


func belt(t: float) -> float:
	return curve(p["belt"], t)


func crown(t: float) -> float:
	return curve(p["crown"], t)


func wmax(t: float) -> float:
	return curve(p["wmax"], t) + flare(t)


func wsh(t: float) -> float:
	return curve(p["wmax"], t) - curve(p["tuck"], t)


func wlow(t: float) -> float:
	return wmax(t) - curve(p["wlow"], t)


## Extra width over the wheels (box flares).
func flare(t: float) -> float:
	var f: float = style_k["flare"]
	if f <= 0.0:
		return 0.0
	var best := 0.0
	for at in axle_t:
		var dz := absf(z_of(t) - z_of(at))
		var r := radius + 0.16
		var s := 1.0 - smoothstep(r - 0.12, r + 0.04, dz)
		best = maxf(best, s)
	return f * best


## Wheel arch: returns the height the side's bottom edge must clear at t (or -1 outside an arch).
func arch_y(t: float) -> float:
	var z := z_of(t)
	var ra := arch_radius()
	for at in axle_t:
		var dz := z - z_of(at)
		if absf(dz) < ra:
			return radius + sqrt(maxf(ra * ra - dz * dz, 0.0))
	return -1.0


func arch_radius() -> float:
	return radius + 0.055


## Side half-width at height y (ground space) for station t.
func side_x(y: float, t: float) -> float:
	var yb := bot(t)
	var yt := belt(t) - float(style_k["shoulder_r"])
	var f := clampf((y - yb) / maxf(yt - yb, 0.01), 0.0, 1.0)
	var fm: float = style_k["mid_frac"]
	var wl := wlow(t)
	var wm := wmax(t)
	var ws := wsh(t) + flare(t) * 0.35
	var x: float
	if f < fm:
		x = lerpf(wl, wm, sin(PI * 0.5 * f / fm))
	else:
		var q := (f - fm) / (1.0 - fm)
		x = lerpf(wm, ws, 1.0 - cos(PI * 0.5 * q))
	# box flares keep their width low down
	if style_k["flare_box"] and f < fm:
		x = maxf(x, wm - 0.01 * (1.0 - f / fm))
	# side intake (veloce): recessed scoop behind the doors
	if style_k["intake"]:
		x -= intake_depth(y, t)
	return x


func intake_depth(y: float, t: float) -> float:
	if not style_k["intake"]:
		return 0.0
	var it: Array = style_k["intake_t"]
	var iy: Array = style_k["intake_y"]
	var ft := smoothstep(it[0], it[0] + 0.07, t) * (1.0 - smoothstep(it[1] - 0.015, it[1], t))
	# the intake's top edge slopes up toward the rear
	var top: float = lerpf(iy[1] - 0.12, iy[1], clampf((t - it[0]) / (it[1] - it[0]), 0.0, 1.0))
	var fy := smoothstep(iy[0], iy[0] + 0.06, y) * (1.0 - smoothstep(top - 0.05, top, y))
	return 0.09 * ft * fy


func in_intake(y: float, t: float) -> bool:
	return intake_depth(y, t) > 0.02


## Deck (top surface) height at half-width x for station t.
func deck_y(x: float, t: float) -> float:
	var w := wsh(t) - float(style_k["shoulder_r"])
	var u := clampf(absf(x) / maxf(w, 0.01), 0.0, 1.0)
	var b := belt(t)
	var c := crown(t)
	# where the deck dips below the belt (a pickup bed) a car may ask for a flat floor with steep
	# inner walls ("dip_pow"); otherwise the usual rounded crown
	var e: float = float(style_k.get("dip_pow", 2.4)) if c < b - 0.05 else 2.4
	return b + (c - b) * (1.0 - pow(u, e))


## Half-width of the deck at t (where the shoulder rounding ends): the deck samples' 100%.
func deck_half(t: float) -> float:
	var r: float = style_k["shoulder_r"]
	return side_x(belt(t) - r, t) - r


## Cabin layout in ground space (car-local, -z = front), computed once from the greenhouse:
##   t_dash / t_back   where the cabin tub starts (the dash face) and ends (bulkhead behind the seats)
##   floor_y           tub floor; fw, fe: tub wall as a fraction of deck_half (+- half the crisp edge)
##   k                 driver scale (fits the helmet under the roof); side: +1 right-hand drive
##   hip, shoulder, head, wheel (Vector3, x = 0: add side * x_seat), wheel_n (wheel face normal),
##   wheel_r, x_seat, theta (torso recline), rear (bool), rear_z (rear bench hip z)
## The tub replaces the body deck under the glass (CarBody.section via shell_deck_y), so the
## driver sits IN the car instead of on a shelf at the window line.
func cabin() -> Dictionary:
	if not _cabin.is_empty():
		return _cabin
	var c0: float = gh["cowl"]
	var c1: float = gh["ws_top"]
	var c2: float = gh["roof_end"]
	var c3: float = gh["back_end"]
	var z0 := z_of(c0)
	var z1 := z_of(c1)
	var z2 := z_of(c2)
	var tm := lerpf(c1, c2, 0.4)
	var floor_y := maxf(bot(tm) + 0.12, belt(tm) - 0.5)
	var roof_in := float(gh["roof_y"]) - 0.06
	# hip-to-helmet-top is ~0.97 m at scale 1 (seated, reclined)
	var k := clampf((roof_in - 0.02 - floor_y) / 0.97, 0.72, 1.0)
	var theta := deg_to_rad(23.0)
	var tdir := Vector3(0.0, cos(theta), sin(theta))
	var lt := 0.5 * k
	var lh := 0.19 * k      # shoulder -> head center (helmet sits down on the shoulders)
	var head_z := z1 + clampf(0.42 * (z2 - z1), 0.18, 0.42)
	var hip := Vector3(0.0, floor_y + 0.16 * k, head_z - (lt + lh) * tdir.z)
	var shoulder := hip + tdir * lt
	var wheel := shoulder + Vector3(0.0, -0.12 * k, -0.42 * k)
	var wheel_r := 0.17 * k
	# short cabs (the pickup): slide everyone back so the wheel clears the windshield base
	var shift := maxf(0.0, z0 + 0.2 - (wheel.z - wheel_r * 0.4))
	hip.z += shift
	shoulder.z += shift
	wheel.z += shift
	var head := shoulder + tdir * lh
	var rear := car_id in CABIN_REAR_SEATS
	var rear_z := hip.z + 0.78 * k
	var z_back := (rear_z + 0.34 * k) if rear else (shoulder.z + 0.24 * k)
	var t_dash := clampf(t_of(wheel.z - 0.17 * k), c0 + 0.012, c1 - 0.012)
	var t_back := clampf(t_of(z_back), t_of(head.z + 0.15), c3 - 0.01)
	var x_wall := 9.0
	for i in 17:
		x_wall = minf(x_wall, gh_base_w(lerpf(t_dash, t_back, float(i) / 16.0)) - 0.05)
	var dh := deck_half(t_of(hip.z))
	var fw := clampf(x_wall / dh, 0.6, 0.95)
	var fe := 0.014 / dh
	var x_seat := clampf(x_wall - 0.3 * k, 0.26, 0.4)
	_cabin = {
		"t_dash": t_dash, "t_back": t_back, "floor_y": floor_y, "fw": fw, "fe": fe, "x_wall": x_wall,
		"k": k, "theta": theta, "tdir": tdir, "side": 1.0 if car_id in CABIN_RHD else -1.0,
		"hip": hip, "shoulder": shoulder, "head": head, "wheel": wheel, "wheel_r": wheel_r,
		"wheel_n": (shoulder - wheel).normalized(), "x_seat": x_seat, "rear": rear, "rear_z": rear_z,
		"et": 0.012 / length,
	}
	return _cabin


## Body deck height for the shell: the normal deck, sunk to the cabin floor inside the tub.
## u = |x| / deck_half(t) (the shell samples it at fixed fractions, see CarBody.section).
func shell_deck_y(x: float, u: float, t: float) -> float:
	var y := deck_y(x, t)
	var c := cabin()
	var et: float = c["et"]
	var ft := smoothstep(float(c["t_dash"]) - et, float(c["t_dash"]) + et, t) * (1.0 - smoothstep(float(c["t_back"]) - et, float(c["t_back"]) + et, t))
	if ft <= 0.0:
		return y
	var fx := 1.0 - smoothstep(float(c["fw"]) - float(c["fe"]), float(c["fw"]) + float(c["fe"]), u)
	return lerpf(y, float(c["floor_y"]), ft * fx)


# --- greenhouse ---------------------------------------------------------------

## Cabin roofline height on the centerline at t (or -1 outside the greenhouse).
func gh_height(t: float) -> float:
	var c0: float = gh["cowl"]
	var c1: float = gh["ws_top"]
	var c2: float = gh["roof_end"]
	var c3: float = gh["back_end"]
	if t < c0 or t > c3:
		return -1.0
	var ry: float = gh["roof_y"]
	var base := gh_base_y(t)
	if t < c1:
		var s := (t - c0) / (c1 - c0)
		# windshield: slightly convex rake
		return lerpf(base, ry, 1.0 - pow(1.0 - s, 1.35))
	if t <= c2:
		var s2 := (t - c1) / (c2 - c1)
		return ry + 0.015 * sin(PI * s2) - 0.01 * s2
	var s3 := (t - c2) / (c3 - c2)
	if gh["notch"]:
		return lerpf(ry - 0.01, base, pow(s3, 1.15))
	# fastback: the roof rolls over, then a long straight slope down to the tail
	return lerpf(ry - 0.01, base, s3 * s3 * (1.6 - 0.6 * s3))


func gh_base_y(t: float) -> float:
	return deck_y(gh_base_w(t), t) - 0.01


func gh_base_w(t: float) -> float:
	return wsh(t) - float(gh["base_inset"])


## Roof half-width at t (narrower at the windshield top and the back).
func gh_roof_w(t: float) -> float:
	var c0: float = gh["cowl"]
	var c1: float = gh["ws_top"]
	var c2: float = gh["roof_end"]
	var c3: float = gh["back_end"]
	var rw: float = gh["roof_w"]
	var bw := gh_base_w(t)
	if t < c1:
		var s := (t - c0) / (c1 - c0)
		return lerpf(bw - 0.02, rw - 0.03, s)
	if t <= c2:
		return rw
	var s3 := (t - c2) / (c3 - c2)
	return lerpf(rw, bw - 0.04, s3)
