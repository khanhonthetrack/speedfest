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
