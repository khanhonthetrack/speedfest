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


func _init(p_car_id: String) -> void:
	car_id = p_car_id
	g = CarDefs.geometry(car_id)
	length = g["length"]
	half_w = g["width"] * 0.5
	radius = g["wheel_radius"]
	var wb: float = g["wheelbase"]
	axle_t = [t_of(-wb * 0.5), t_of(wb * 0.5)]
	match car_id:
		"brute":
			_brute()
		"veloce":
			_veloce()
		"kitsune":
			_kitsune()
		"pixie":
			_pixie()
		"goliath":
			_goliath()
		_:
			_kaze()


func _kaze() -> void:
	# JDM tuner coupe: wedge nose with pop-up lights, boxy flares, notchback.
	p["bot"] = [[0.0, 0.25], [0.05, 0.19], [0.14, 0.16], [0.86, 0.16], [0.95, 0.21], [1.0, 0.28]]
	p["belt"] = [[0.0, 0.54], [0.04, 0.64], [0.12, 0.72], [0.21, 0.77], [0.34, 0.79], [0.6, 0.83], [0.8, 0.87], [0.93, 0.89], [1.0, 0.86]]
	p["crown"] = [[0.0, 0.56], [0.04, 0.665], [0.12, 0.745], [0.25, 0.79], [0.36, 0.815], [0.75, 0.9], [0.82, 0.915], [0.94, 0.92], [1.0, 0.88]]
	p["wmax"] = [[0.0, 0.79], [0.015, 0.83], [0.05, 0.865], [0.12, 0.88], [0.5, 0.875], [0.88, 0.88], [0.95, 0.865], [0.985, 0.83], [1.0, 0.79]]
	p["tuck"] = [[0.0, 0.03], [0.3, 0.04], [0.6, 0.06], [1.0, 0.04]]
	p["wlow"] = [[0.0, 0.02], [1.0, 0.025]]
	gh = {"cowl": 0.355, "ws_top": 0.5, "roof_end": 0.7, "back_end": 0.805,
		"roof_y": g["height"], "roof_w": 0.6, "base_inset": 0.075, "roof_crown": 0.025,
		"notch": true, "side_glass_top": 0.83, "b_pillar": 0.62}
	style_k = {"flare": 0.03, "flare_box": true, "mid_frac": 0.5, "hood_from": 0.07, "hood_to": 0.35,
		"intake": false, "shoulder_r": 0.035}


func _brute() -> void:
	# American muscle: tall flat nose with a big grille, long hood, fastback, wide rear hips.
	p["bot"] = [[0.0, 0.23], [0.05, 0.19], [0.14, 0.17], [0.86, 0.17], [0.95, 0.22], [1.0, 0.3]]
	p["belt"] = [[0.0, 0.79], [0.03, 0.83], [0.15, 0.855], [0.4, 0.865], [0.6, 0.875], [0.78, 0.91], [0.94, 0.92], [1.0, 0.88]]
	p["crown"] = [[0.0, 0.8], [0.03, 0.845], [0.2, 0.885], [0.44, 0.9], [0.8, 0.94], [0.95, 0.945], [1.0, 0.905]]
	p["wmax"] = [[0.0, 0.86], [0.012, 0.9], [0.05, 0.93], [0.2, 0.945], [0.45, 0.925], [0.62, 0.94], [0.78, 0.965], [0.92, 0.955], [0.985, 0.925], [1.0, 0.89]]
	p["tuck"] = [[0.0, 0.03], [0.4, 0.05], [0.7, 0.07], [1.0, 0.05]]
	p["wlow"] = [[0.0, 0.03], [1.0, 0.035]]
	gh = {"cowl": 0.425, "ws_top": 0.565, "roof_end": 0.67, "back_end": 0.93,
		"roof_y": g["height"], "roof_w": 0.63, "base_inset": 0.085, "roof_crown": 0.03,
		"notch": false, "side_glass_top": 0.86, "b_pillar": 0.0}
	style_k = {"flare": 0.0, "flare_box": false, "mid_frac": 0.45, "hood_from": 0.05, "hood_to": 0.42,
		"intake": false, "shoulder_r": 0.045}


func _veloce() -> void:
	# Euro mid-engine supercar: very low nose, fender humps, cab-forward, side intakes, wide rear.
	p["bot"] = [[0.0, 0.17], [0.06, 0.135], [0.15, 0.12], [0.9, 0.12], [0.96, 0.15], [1.0, 0.2]]
	p["belt"] = [[0.0, 0.42], [0.05, 0.56], [0.12, 0.72], [0.2, 0.795], [0.28, 0.75], [0.38, 0.7], [0.52, 0.72], [0.66, 0.81], [0.79, 0.86], [0.92, 0.85], [1.0, 0.79]]
	p["crown"] = [[0.0, 0.43], [0.05, 0.53], [0.12, 0.6], [0.2, 0.645], [0.3, 0.68], [0.6, 0.86], [0.8, 0.87], [0.93, 0.86], [1.0, 0.81]]
	p["wmax"] = [[0.0, 0.84], [0.015, 0.9], [0.06, 0.95], [0.2, 0.985], [0.36, 0.955], [0.5, 0.95], [0.7, 0.99], [0.86, 0.99], [0.96, 0.96], [1.0, 0.9]]
	p["tuck"] = [[0.0, 0.05], [0.2, 0.06], [0.45, 0.12], [0.7, 0.08], [1.0, 0.06]]
	p["wlow"] = [[0.0, 0.03], [1.0, 0.03]]
	gh = {"cowl": 0.235, "ws_top": 0.43, "roof_end": 0.555, "back_end": 0.88,
		"roof_y": g["height"], "roof_w": 0.56, "base_inset": 0.1, "roof_crown": 0.02,
		"notch": false, "side_glass_top": 0.0, "b_pillar": 0.0}
	style_k = {"flare": 0.0, "flare_box": false, "mid_frac": 0.38, "hood_from": 0.06, "hood_to": 0.22,
		"intake": true, "intake_t": [0.53, 0.68], "intake_y": [0.28, 0.6], "shoulder_r": 0.05}


func _kitsune() -> void:
	# Rally hatch: raised, short nose, tall greenhouse that runs to a near-vertical hatch, box flares.
	p["bot"] = [[0.0, 0.32], [0.05, 0.26], [0.14, 0.23], [0.86, 0.23], [0.95, 0.27], [1.0, 0.34]]
	p["belt"] = [[0.0, 0.66], [0.04, 0.74], [0.12, 0.82], [0.25, 0.86], [0.5, 0.89], [0.8, 0.92], [0.95, 0.93], [1.0, 0.9]]
	p["crown"] = [[0.0, 0.68], [0.04, 0.76], [0.12, 0.84], [0.25, 0.88], [0.32, 0.9], [0.85, 0.95], [0.97, 0.95], [1.0, 0.92]]
	p["wmax"] = [[0.0, 0.8], [0.015, 0.84], [0.05, 0.87], [0.12, 0.885], [0.5, 0.875], [0.88, 0.885], [0.95, 0.87], [0.985, 0.84], [1.0, 0.8]]
	p["tuck"] = [[0.0, 0.04], [0.4, 0.05], [0.7, 0.07], [1.0, 0.05]]
	p["wlow"] = [[0.0, 0.02], [1.0, 0.025]]
	gh = {"cowl": 0.3, "ws_top": 0.46, "roof_end": 0.86, "back_end": 0.965,
		"roof_y": g["height"], "roof_w": 0.64, "base_inset": 0.07, "roof_crown": 0.025,
		"notch": false, "side_glass_top": 0.85, "b_pillar": 0.6}
	style_k = {"flare": 0.045, "flare_box": true, "mid_frac": 0.5, "hood_from": 0.06, "hood_to": 0.29,
		"intake": false, "shoulder_r": 0.04, "tail_bulge": 0.02}


func _pixie() -> void:
	# Kei roadster: tiny and round, frog-eye lamps, short hardtop, stubby tail.
	p["bot"] = [[0.0, 0.22], [0.06, 0.17], [0.15, 0.15], [0.85, 0.15], [0.94, 0.18], [1.0, 0.24]]
	p["belt"] = [[0.0, 0.5], [0.05, 0.6], [0.14, 0.68], [0.3, 0.72], [0.55, 0.74], [0.8, 0.77], [0.93, 0.78], [1.0, 0.74]]
	p["crown"] = [[0.0, 0.52], [0.05, 0.62], [0.14, 0.69], [0.3, 0.73], [0.6, 0.76], [0.85, 0.79], [0.95, 0.79], [1.0, 0.75]]
	p["wmax"] = [[0.0, 0.72], [0.02, 0.77], [0.06, 0.8], [0.15, 0.81], [0.5, 0.8], [0.85, 0.81], [0.94, 0.8], [0.98, 0.77], [1.0, 0.72]]
	p["tuck"] = [[0.0, 0.04], [0.5, 0.05], [1.0, 0.04]]
	p["wlow"] = [[0.0, 0.02], [1.0, 0.02]]
	gh = {"cowl": 0.4, "ws_top": 0.54, "roof_end": 0.7, "back_end": 0.82,
		"roof_y": g["height"], "roof_w": 0.56, "base_inset": 0.08, "roof_crown": 0.03,
		"notch": true, "side_glass_top": 0.85, "b_pillar": 0.0}
	style_k = {"flare": 0.0, "flare_box": false, "mid_frac": 0.45, "hood_from": 0.06, "hood_to": 0.36,
		"intake": false, "shoulder_r": 0.05, "nose_bulge": 0.12, "tail_bulge": 0.08}


func _goliath() -> void:
	# Pickup truck: tall flat nose, long hood, upright cab, and a bed: behind the cab the deck
	# drops to the bed floor between the body sides, then rises to the tailgate.
	p["bot"] = [[0.0, 0.48], [0.05, 0.4], [0.13, 0.36], [0.87, 0.36], [0.95, 0.4], [1.0, 0.46]]
	p["belt"] = [[0.0, 1.08], [0.03, 1.13], [0.15, 1.16], [0.3, 1.17], [0.55, 1.18], [0.97, 1.18], [1.0, 1.16]]
	p["crown"] = [[0.0, 1.1], [0.03, 1.15], [0.15, 1.19], [0.3, 1.21], [0.555, 1.22], [0.6, 0.84], [0.95, 0.82],
		[0.975, 0.86], [0.99, 1.12], [1.0, 1.14]]
	p["wmax"] = [[0.0, 0.94], [0.012, 0.98], [0.05, 1.0], [0.2, 1.02], [0.5, 1.01], [0.8, 1.02], [0.95, 1.01], [0.985, 0.99], [1.0, 0.96]]
	p["tuck"] = [[0.0, 0.02], [0.5, 0.03], [1.0, 0.02]]
	p["wlow"] = [[0.0, 0.02], [1.0, 0.02]]
	gh = {"cowl": 0.36, "ws_top": 0.43, "roof_end": 0.535, "back_end": 0.56,
		"roof_y": g["height"], "roof_w": 0.8, "base_inset": 0.05, "roof_crown": 0.02,
		"notch": true, "side_glass_top": 0.88, "b_pillar": 0.5}
	style_k = {"flare": 0.05, "flare_box": true, "mid_frac": 0.5, "hood_from": 0.04, "hood_to": 0.33,
		"intake": false, "shoulder_r": 0.03, "nose_bulge": 0.03, "tail_bulge": 0.01}


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
	return b + (crown(t) - b) * (1.0 - pow(u, 2.4))


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
