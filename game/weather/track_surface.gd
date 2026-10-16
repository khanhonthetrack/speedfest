class_name TrackSurface
extends RefCounted
## Surface grip map of a track under the current weather: wet asphalt everywhere plus puddles.
## Built by Track from the layout's {"puddle": ...} markers; Car queries it per wheel contact.
##
## A puddle is an ellipse lying on the road: center frame (road frame at its middle, shifted
## sideways), half width `hx`, half length `hz`, both at STORM size. Rain shrinks it to
## Weather.puddle_extent(mode). Water depth falls off smoothly toward the rim, so the grip
## change is never a step.

var mode: String = "dry"
var puddles: Array = []        # [{xf, inv, hx, hz, r2, storm}]

## Ground surfaces besides asphalt (owner, session 4): patches lying on the road from layout
## {"surface": "grass"|"gravel"|"sand", ...} markers. Each patch is a chain of short boxes in road
## frames (so it follows curves). Weather-independent; multiplied with the weather grip.
## M7 (TM styles): dirt (drifty), ice (very low grip, no drag), plastic (grippy-ish but slows you).
const KINDS: Array[String] = ["asphalt", "grass", "gravel", "sand", "dirt", "ice", "plastic"]
const KIND_GRIP: Array[float] = [1.0, 0.74, 0.62, 0.68, 0.78, 0.32, 0.85]   # tire grip multiplier
const KIND_DRAG: Array[float] = [0.0, 2.0, 3.0, 7.0, 1.2, 0.0, 2.5]         # rolling drag, m/s^2
## Loose ground where rally tires (car param "loose_grip") win grip back; not ice or plastic.
const KIND_LOOSE: Array[bool] = [false, true, true, true, true, false, false]
var patches: Array = []        # [{kind, d0, d1, x0, x1, c, r2, boxes: [{xf, inv, hx, hz, r2}]}]
var _road_grip := 1.0
var _puddle_grip := 1.0
var _drag := 0.0
var _extent := 0.0


func set_mode(m: String) -> void:
	mode = Weather.sanitize(m)
	_road_grip = Weather.road_grip(mode)
	_puddle_grip = Weather.puddle_grip(mode)
	_drag = Weather.puddle_drag(mode)
	_extent = Weather.puddle_extent(mode)


## center: road frame at the puddle's middle (origin on the road surface).
func add_puddle(center: Transform3D, half_width: float, half_length: float, storm_only: bool) -> void:
	var r := maxf(half_width, half_length) + 1.0
	puddles.append({"xf": center, "inv": center.affine_inverse(), "hx": half_width, "hz": half_length,
		"r2": r * r, "storm": storm_only})


func is_active(p: Dictionary) -> bool:
	if mode == "dry":
		return false
	return mode == "storm" or not bool(p["storm"])


func active_count() -> int:
	var n := 0
	for p in puddles:
		if is_active(p):
			n += 1
	return n


static func kind_id(name: String) -> int:
	return maxi(0, KINDS.find(name))


## boxes: [{xf: Transform3D (road frame at the box centre), hx, hz}] in path order.
func add_patch(kind: int, d0: float, d1: float, x0: float, x1: float, boxes: Array) -> void:
	var bx: Array = []
	var c := Vector3.ZERO
	for b in boxes:
		var xf: Transform3D = b["xf"]
		var r := Vector2(float(b["hx"]), float(b["hz"])).length() + 0.5
		bx.append({"xf": xf, "inv": xf.affine_inverse(), "hx": float(b["hx"]), "hz": float(b["hz"]), "r2": r * r})
		c += xf.origin
	c /= maxf(1.0, float(bx.size()))
	var rad := 0.0
	for b in bx:
		rad = maxf(rad, c.distance_to((b["xf"] as Transform3D).origin) + sqrt(float(b["r2"])))
	patches.append({"kind": kind, "d0": d0, "d1": d1, "x0": x0, "x1": x1, "c": c, "r2": rad * rad, "boxes": bx})


## Ground kind index (KINDS) under a world point: 0 = asphalt.
func kind_at(pos: Vector3) -> int:
	for p in patches:
		if pos.distance_squared_to(p["c"]) > float(p["r2"]):
			continue
		for b in p["boxes"]:
			if pos.distance_squared_to((b["xf"] as Transform3D).origin) > float(b["r2"]):
				continue
			var l: Vector3 = (b["inv"] as Transform3D) * pos
			if absf(l.x) <= float(b["hx"]) and absf(l.z) <= float(b["hz"]) and absf(l.y) < 1.2:
				return int(p["kind"])
	return 0


## Grip multiplier of the ground on the road centreline at distance d (for the AutoDriver's plan).
func centerline_grip(d: float) -> float:
	var g := 1.0
	for p in patches:
		if d >= float(p["d0"]) and d <= float(p["d1"]) and float(p["x0"]) <= 0.5 and float(p["x1"]) >= -0.5:
			g = minf(g, KIND_GRIP[int(p["kind"])])
	return g


## Water depth 0..1 at a world point (0 = dry or wet asphalt, 1 = puddle center).
func water_at(pos: Vector3) -> float:
	if _extent <= 0.0:
		return 0.0
	var best := 0.0
	for p in puddles:
		if not is_active(p):
			continue
		var xf: Transform3D = p["xf"]
		if pos.distance_squared_to(xf.origin) > float(p["r2"]):
			continue
		var l: Vector3 = (p["inv"] as Transform3D) * pos
		if absf(l.y) > 1.2:
			continue
		var u := l.x / (float(p["hx"]) * _extent)
		var v := l.z / (float(p["hz"]) * _extent)
		var e := u * u + v * v
		if e < 1.0:
			best = maxf(best, 1.0 - smoothstep(0.55, 1.0, e))
	return best


## Tire grip multiplier for a given water depth (from water_at).
func grip_for_water(water: float) -> float:
	return _road_grip * lerpf(1.0, _puddle_grip, water)


func grip_at(pos: Vector3) -> float:
	return grip_for_water(water_at(pos))


## Water drag per wheel (m/s^2 times corner mass) for a given water depth.
func drag_for_water(water: float) -> float:
	return _drag * water
