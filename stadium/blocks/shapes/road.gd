extends RefCounted
## Stadium "Road/Main" blocks: the classic road (a 21 m asphalt strip at 1.345 m between grid
## shoulders and rounded curbs; elevated pieces have a shallow keel below, ground pieces run their
## curbs' outer faces down to the terrain). Our own geometry from measured numbers (TMNF
## block-local metres: x right, y up, z forward; see TmGeo).
##
## Straights and slopes sweep the section along z (slopes shear it up 8 m per block, as TMNF does);
## corners and GT curves sweep it around the footprint's corner (road centre radius 32k - 16);
## junctions (T, cross) are a flat deck with straight curbs along the closed sides and the curb
## revolved around each block corner where two arms meet; dead ends and the lone base piece are
## short crowned sweeps ending in a low nose. Shape index: 0 base, 1 dead end (opens to +z),
## 2 corner (+z, -x), 3 straight (+z, -z), 4 T (adds -x), 5 cross.

const S_ROAD := 16              # StadiumRoad (asphalt)
const S_METAL := 4
const S_RUBBER := 9
const S_TURBO := 7
const S_FREEWHEEL := 29
const TOP := 1.345              ## the road surface
const CROWN := 0.19             ## dead ends and the base sink this much toward their noses

## Left half of the cross-section, (x, y) with x across the road (centre 16), from the bottom
## centre round the left curb to the top centre; each point's material is the segment's from it.
## Air: keel underneath. Ground: the curb's outer face runs down to the terrain (1 m).
const HALF_AIR := [
	[16.0, 0.0, "structure", S_METAL], [14.339, 0.0, "structure", S_METAL], [9.758, 0.418, "structure", S_METAL],
	[5.177, 0.836, "metal", S_METAL], [5.177, 1.243, "grid", S_METAL], [3.212, 1.243, "metal", S_METAL],
	[2.004, 1.243, "rubber_white", S_RUBBER], [1.712, 1.753, "rubber_white", S_RUBBER],
]
const HALF_GROUND := [
	[16.0, 1.0, "", TmGeo.NO_COLLISION], [1.0, 1.0, "metal", S_METAL], [1.282, 1.851, "metal", S_METAL],
]
## The curb and the road surface, shared by both (air starts at the curb's outer rubber face).
const HALF_TOP_AIR := [[1.419, 2.263, "metal", S_METAL], [1.492, 2.482, "metal", S_METAL]]
const HALF_TOP := [
	[1.565, 2.701, "metal", S_METAL], [1.616, 2.739, "metal", S_METAL], [1.668, 2.777, "metal", S_METAL],
	[1.792, 2.777, "metal", S_METAL], [1.834, 2.636, "metal", S_METAL], [1.875, 2.495, "metal", S_METAL],
	[2.735, 2.495, "metal", S_METAL], [2.753, 2.444, "metal", S_METAL], [2.770, 2.394, "rubber_white", S_RUBBER],
	[2.857, 2.358, "rubber_white", S_RUBBER], [2.943, 2.322, "rubber_white", S_RUBBER],
	[3.022, 2.269, "rubber_white", S_RUBBER], [3.101, 2.216, "rubber_white", S_RUBBER],
	[3.166, 2.143, "rubber_white", S_RUBBER], [3.231, 2.069, "rubber_white", S_RUBBER],
	[3.272, 1.968, "rubber_white", S_RUBBER], [3.312, 1.867, "rubber_white", S_RUBBER],
	[3.312, 1.606, "rubber_white", S_RUBBER], [3.280, 1.475, "rubber_white", S_RUBBER],
	[3.248, TOP, "grid", S_METAL], [5.177, TOP, "rubber_white", S_RUBBER], [5.232, 1.376, "rubber_white", S_RUBBER],
	[5.508, 1.361, "rubber_white", S_RUBBER], [5.540, TOP, "asphalt", S_ROAD],
]
const ROAD_EDGE := 5.540        ## where the asphalt starts (x)
const SHOULDER := 5.177         ## the grid shoulder's inner edge (x)

const ARMS := {
	"Base": [], "Deadend": [0], "Corner": [0, 1], "Straight": [0, 2], "TShaped": [0, 2, 1], "Cross": [0, 1, 2, 3],
}
const SIDES := [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)]

## Turbo gate: the U-frame round the road (x, y), 14.4 -> 17.45 m along z.
const TURBO_FRAME := [
	[4.000, 4.854, "structure", 22], [3.879, 5.538, "structure", 22], [3.532, 6.140, "structure", 22],
	[3.000, 6.586, "structure", 22], [2.347, 6.824, "structure", 22], [1.653, 6.824, "structure", 22],
	[1.000, 6.586, "structure", 22], [0.468, 6.140, "structure", 22], [0.121, 5.538, "structure", 22],
	[0.000, 4.854, "structure", 22], [0.000, 1.976, "structure", 22], [0.121, 1.292, "structure", 22],
	[0.468, 0.690, "structure", 22], [1.000, 0.244, "structure", 22], [1.653, 0.000, "structure", 22],
	[30.347, 0.000, "structure", 22], [31.000, 0.244, "structure", 22], [31.532, 0.690, "structure", 22],
	[31.879, 1.292, "structure", 22], [32.000, 1.976, "structure", 22], [32.000, 4.854, "structure", 22],
	[31.879, 5.538, "structure", 22], [31.532, 6.140, "structure", 22], [31.000, 6.586, "structure", 22],
	[30.347, 6.824, "structure", 22], [29.653, 6.824, "structure", 22], [29.000, 6.586, "structure", 22],
	[28.468, 6.140, "structure", 22], [28.121, 5.538, "structure", 22], [28.000, 4.854, "structure", 22],
	[28.000, 3.810, "structure", 22], [28.688, 2.765, "structure", 4], [28.688, 1.000, "structure", 22],
	[3.312, 1.000, "structure", 4], [3.312, 2.765, "structure", 22], [4.000, 3.810, "structure", 22]
]
## Checkpoint / finish / multilap gate: the arch band (x, y), 4.2 m along z.
const GATE_ARCH := [
	[16.000, 8.806, "structure", 22], [14.407, 8.743, "structure", 22], [12.824, 8.552, "structure", 22],
	[11.262, 8.236, "structure", 22], [9.729, 7.795, "structure", 22], [8.237, 7.234, "structure", 22],
	[6.794, 6.556, "structure", 22], [5.410, 5.764, "structure", 22], [4.094, 4.865, "structure", 4],
	[4.924, 3.748, "metal", 4], [6.149, 4.585, "metal", 4], [7.436, 5.321, "metal", 4],
	[8.778, 5.952, "metal", 4], [10.167, 6.474, "metal", 4], [11.592, 6.884, "metal", 4],
	[13.046, 7.178, "metal", 4], [14.518, 7.356, "metal", 4], [16.000, 7.415, "metal", 4],
	[17.482, 7.356, "metal", 4], [18.954, 7.178, "metal", 4], [20.408, 6.884, "metal", 4],
	[21.833, 6.474, "metal", 4], [23.222, 5.952, "metal", 4], [24.564, 5.321, "metal", 4],
	[25.851, 4.585, "metal", 4], [27.076, 3.748, "structure", 4], [27.906, 4.865, "structure", 22],
	[26.590, 5.764, "structure", 22], [25.206, 6.556, "structure", 22], [23.763, 7.234, "structure", 22],
	[22.271, 7.795, "structure", 22], [20.738, 8.236, "structure", 22], [19.176, 8.552, "structure", 22],
	[17.593, 8.743, "structure", 22]
]

## Road slope pieces: road-surface heights along z every 2 m at the centre line (measured).
const SLOPES := {
	"BiSlopeStart": [1.345, 1.376, 1.407, 1.438, 1.469, 1.556, 1.643, 1.730, 1.817, 1.964, 2.112, 2.260, 2.408, 2.623, 2.838, 3.053, 3.267, 3.549, 3.830, 4.112, 4.393, 4.743, 5.093, 5.443, 5.792, 6.208, 6.624, 7.041, 7.457, 7.929, 8.401, 8.873, 9.345],
	"BiSlopeEnd": [1.345, 1.826, 2.307, 2.770, 3.234, 3.666, 4.098, 4.499, 4.900, 5.265, 5.630, 5.962, 6.294, 6.592, 6.890, 7.155, 7.420, 7.652, 7.883, 8.083, 8.282, 8.446, 8.610, 8.742, 8.874, 8.975, 9.076, 9.148, 9.220, 9.264, 9.308, 9.327, 9.345],
	"Base": [1.345, 1.407, 1.631, 1.997, 2.490, 3.097, 3.793, 4.553, 5.345, 6.137, 6.897, 7.593, 8.199, 8.692, 9.058, 9.283, 9.345],
	"Base2": [1.345, 1.469, 1.918, 2.650, 3.636, 4.849, 6.241, 7.761, 9.345, 10.929, 12.449, 13.840, 15.054, 16.040, 16.771, 17.220, 17.345],
	"UBottom": [9.345, 8.873, 8.457, 8.107, 7.825, 7.611, 7.463, 7.376, 7.345, 7.376, 7.463, 7.611, 7.825, 8.107, 8.457, 8.873, 9.345],
	"UTop": [1.345, 1.817, 2.233, 2.583, 2.864, 3.079, 3.227, 3.314, 3.345, 3.314, 3.227, 3.079, 2.864, 2.583, 2.233, 1.817, 1.345],
}

## Platform/ToRoad2: the running curb's edge line, an arc of this radius about (R, 0) from the
## road end (0, 0), and the angle where it stops short of the far corner.
const TO_PLATFORM_R := 83.13
const TO_PLATFORM_END := 48.0

## The gate's sign boards (visual), left one (x, y); the right one is mirrored.
const GATE_SIGN := [[6.96, 8.17], [7.26, 8.17], [10.26, 11.4], [9.81, 11.4]]

var _road_mat := "asphalt"
var _road_surf := S_ROAD


func handles(shape: String) -> bool:
	if not shape.begins_with("Road/Main/"):
		return false
	var rest := shape.trim_prefix("Road/Main/")
	if rest.begins_with("Slope/") and SLOPES.has(_form(rest.trim_prefix("Slope/"))):
		return true
	return ARMS.has(_form(rest)) or rest.begins_with("Slope/StraightAir") or rest.begins_with("Slope/StraightGround") \
		or rest.begins_with("GTCurve/") or rest.begins_with("Turbo/Air") or rest.begins_with("Turbo/Ground") \
		or rest.begins_with("FreeWheeling/") or rest.begins_with("Checkpoint/") or rest.begins_with("MultiLap/") \
		or rest.begins_with("Finish/") or rest.begins_with("Start/")


## The shape's form, without its variant suffix (Air, Ground, or an alternative GroundA/B/C).
static func _form(rest: String) -> String:
	for suffix in ["GroundA", "GroundB", "GroundC", "Ground", "Air"]:
		if rest.ends_with(suffix):
			return rest.trim_suffix(suffix)
	return rest


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var rest := shape.trim_prefix("Road/Main/")
	var ground := rest.contains("Ground")
	var geo := TmGeo.new()
	_road_mat = "asphalt"
	_road_surf = S_ROAD
	var form := _form(rest)
	if ARMS.has(form):
		_junction(geo, form, ground)
	elif rest.begins_with("Slope/") and SLOPES.has(_form(rest.trim_prefix("Slope/"))):
		_profile_slope(geo, SLOPES[_form(rest.trim_prefix("Slope/"))], ground)
	elif rest.begins_with("Slope/Straight"):
		_sweep(geo, [Vector3(16, 0, 0), Vector3(16, 8, 32)], [Vector3(1, 0, 0), Vector3(1, 0, 0)], ground)
	elif rest.begins_with("GTCurve/"):
		var k := int(rest.trim_prefix("GTCurve/").substr(0, 1))
		if k < 2 or k > 5:
			return null
		_curve(geo, k, ground)
	elif rest.begins_with("Turbo/") or rest.begins_with("FreeWheeling/"):
		_road_mat = "turbo"
		_road_surf = S_TURBO if rest.begins_with("Turbo/") else S_FREEWHEEL
		_straight(geo, 0.0, 32.0, ground)
		_turbo_gate(geo)
	elif rest.begins_with("Checkpoint/") or rest.begins_with("MultiLap/"):
		_straight(geo, 0.0, 32.0, ground)
		_gate(geo, 16.0)
	elif rest.begins_with("Finish/"):
		# the road comes in from -z and ends past the line in a nose
		_straight(geo, 0.0, 17.0, ground)
		_nose(geo, 17.0, 1.0, ground, TOP - 0.04)
		_gate(geo, 12.0)
	elif rest.begins_with("Start/"):
		# the road leaves to +z from a nose behind the spawn (z 11.2); the line near the far end
		_straight(geo, 8.0, 32.0, ground)
		_nose(geo, 8.0, -1.0, ground, TOP - 0.04)
		_gate(geo, 28.0)
	else:
		return null
	return geo.build()


## The closed cross-section as wall_sweep points: (d = x - 16, y).
func _section(ground: bool) -> Array:
	var left: Array = (HALF_GROUND if ground else HALF_AIR + HALF_TOP_AIR) + HALF_TOP
	var out := []
	for q in left:
		out.append([Vector2(float(q[0]) - 16.0, float(q[1])), String(q[2]), int(q[3])])
	# the right half mirrored, walked back from the top centre to the bottom; a segment keeps the
	# material of its mirrored twin (which starts at the next point of the left half)
	out.append([Vector2(0.0, TOP), _road_mat, _road_surf])
	for i in range(left.size() - 1, 0, -1):
		var q: Array = left[i]
		var prev: Array = left[i - 1]
		out.append([Vector2(16.0 - float(q[0]), float(q[1])), String(prev[2]), int(prev[3])])
	for p in out:
		if p[1] == "asphalt":
			p[1] = _road_mat
			p[2] = _road_surf
	return out


## The left curb alone (the section up to the asphalt's edge), closed underneath; d = x.
func _curb_section(ground: bool) -> Array:
	var left: Array = (HALF_GROUND.slice(1) if ground else HALF_AIR.slice(5) + HALF_TOP_AIR) + HALF_TOP
	var out := []
	for q in left:
		out.append([Vector2(float(q[0]), float(q[1])), String(q[2]), int(q[3])])
	var bottom := 1.0 if ground else 1.243
	out[out.size() - 1][1] = ""                      # the curb's inner end is internal
	out[out.size() - 1][2] = TmGeo.NO_COLLISION
	out.append([Vector2(ROAD_EDGE, bottom), "" if ground else "metal", TmGeo.NO_COLLISION if ground else S_METAL])
	return out


func _sweep(geo: TmGeo, path: Array, lateral: Array, ground: bool, y_at := Callable()) -> void:
	geo.wall_sweep(_section(ground), path, lateral, true, "metal", S_METAL, y_at)


## GT curves (and the 1x1 corner, k = 1): the section around the footprint's corner (0, 32k).
func _curve(geo: TmGeo, k: int, ground: bool) -> void:
	var s := 32.0 * k
	var steps := 8 * k
	var path := []
	var lat := []
	for i in steps + 1:
		var a := lerpf(-PI * 0.5, 0.0, float(i) / steps)
		var d := Vector3(cos(a), 0.0, sin(a))
		path.append(Vector3(0, 0, s) + d * (s - 16.0))
		lat.append(d)
	_sweep(geo, path, lat, ground)


## Road-type pieces by their arms (SIDES indices).
func _junction(geo: TmGeo, form: String, ground: bool) -> void:
	match form:
		"Straight":
			_straight(geo, 0.0, 32.0, ground)
		"Corner":
			_curve(geo, 1, ground)
		"Deadend":
			# crowned: level from the open end to z 24, sinking CROWN toward the nose at z 16
			var path := [Vector3(16, 0, 16), Vector3(16, 0, 24), Vector3(16, 0, 32)]
			var drop := [CROWN, 0.0, 0.0]
			_sweep(geo, path, [Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0)], ground,
				func(y: float, i: int) -> float: return y - drop[i])
			_nose(geo, 16.0, -1.0, ground)
		"Base":
			var path := [Vector3(16, 0, 8), Vector3(16, 0, 16), Vector3(16, 0, 24)]
			var drop := [CROWN, 0.0, CROWN]
			_sweep(geo, path, [Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0)], ground,
				func(y: float, i: int) -> float: return y - drop[i])
			_nose(geo, 8.0, -1.0, ground)
			_nose(geo, 24.0, 1.0, ground)
		_:
			_cross(geo, ARMS[form], ground)


## A road piece following a measured height profile along z (every 2 m), the section sheared up as
## TMNF does; ground pieces keep their base on the terrain (1 m).
func _profile_slope(geo: TmGeo, heights: Array, ground: bool) -> void:
	var path := []
	var lat := []
	for i in heights.size():
		path.append(Vector3(16, float(heights[i]) - TOP, 2.0 * i))
		lat.append(Vector3(1, 0, 0))
	var y_at := Callable()
	if ground:
		y_at = func(y: float, i: int) -> float: return 1.0 - (path[i] as Vector3).y if y <= 1.001 else y
	_sweep(geo, path, lat, ground, y_at)


## The road (asphalt and curbs) swept along z through measured surface heights (evenly spaced over
## the block), its underside cut off at floor_y where it rises off a platform deck; mat: the
## surface's material (the platform's own where the ramp is part of a platform block).
func ramp(geo: TmGeo, heights: Array, floor_y: float, mat := "asphalt") -> void:
	_road_mat = mat
	var path := []
	var lat := []
	for i in heights.size():
		path.append(Vector3(16, float(heights[i]) - TOP, 32.0 * i / (heights.size() - 1)))
		lat.append(Vector3(1, 0, 0))
	var y_at := func(y: float, i: int) -> float: return maxf(y, floor_y - (path[i] as Vector3).y)
	_sweep(geo, path, lat, false, y_at)
	_road_mat = "asphalt"


## Road/Main onto a platform floor at road level (Platform/ToRoad, where the platform loops begin):
## a plate the width of the block at the road's height. One block (blocks = 1): the road from z 16
## to 32, its curbs turned out round the side midpoints onto the plate. Two blocks (z 0 -> 64, the
## road at z 0): one curb turns out at once round its corner, the other runs on across the plate
## on an arc of radius TO_PLATFORM_R tangent to the road (measured) to near the far corner; mirror
## swaps the sides.
func to_platform(geo: TmGeo, blocks: int, ground: bool, mirror: bool) -> void:
	var len := 32.0 * blocks
	var plate_z1 := 16.0 if blocks == 1 else len
	geo.box(Vector3(0, 1.0, 0), Vector3(32, TOP, plate_z1), "structure", S_METAL, "platform" if blocks == 1 else "asphalt", S_ROAD)
	if not ground:
		geo.box(Vector3(14.34, 0.4, 0), Vector3(17.66, 1.0, plate_z1), "structure", S_METAL)
	var curb := _curb_section(ground)
	var mx := func(v: Vector3) -> Vector3: return Vector3(32.0 - v.x, v.y, v.z) if mirror else v
	var ml := func(v: Vector3) -> Vector3: return Vector3(-v.x, v.y, v.z) if mirror else v
	if blocks == 1:
		_straight(geo, 16.0, 32.0, ground)
		_turn_out(geo, curb, Vector3(0, 0, 16), Vector3(1, 0, 0), Vector3(0, 0, -1))
		_turn_out(geo, curb, Vector3(32, 0, 16), Vector3(-1, 0, 0), Vector3(0, 0, -1))
		return
	# the curb that turns out at once, round the corner at the road's end
	_turn_out(geo, curb, mx.call(Vector3(32, 0, 0)), ml.call(Vector3(-1, 0, 0)), Vector3(0, 0, 1))
	# the one that runs across: its edge line on the arc, d inward toward the arc's centre
	var path := []
	var lat := []
	var steps := 24
	for k in steps + 1:
		var a := deg_to_rad(TO_PLATFORM_END) * k / steps
		path.append(mx.call(Vector3(TO_PLATFORM_R * (1.0 - cos(a)), 0, TO_PLATFORM_R * sin(a))))
		lat.append(ml.call(Vector3(cos(a), 0, -sin(a))))
	geo.wall_sweep(curb, path, lat, true, "metal", S_METAL)


## A curb turned through a quarter circle about a point on the block's edge: its section's lateral
## goes from `from` (along the road) to `to` (along the edge it ends on).
func _turn_out(geo: TmGeo, curb: Array, c: Vector3, from: Vector3, to: Vector3) -> void:
	var path := []
	var lat := []
	var steps := 6
	for s in steps + 1:
		var ang := PI * 0.5 * float(s) / steps
		lat.append((from * cos(ang) + to * sin(ang)).normalized())
		path.append(c)
	geo.wall_sweep(curb, path, lat, true, "metal", S_METAL)


func _straight(geo: TmGeo, z0: float, z1: float, ground: bool) -> void:
	_sweep(geo, [Vector3(16, 0, z0), Vector3(16, 0, z1)], [Vector3(1, 0, 0), Vector3(1, 0, 0)], ground)


## A road end's low nose beyond z0 (toward dir): a thin plate 2.3 m long under the curbs' ends.
func _nose(geo: TmGeo, z0: float, dir: float, ground: bool, top := TOP - CROWN - 0.04) -> void:
	var z1 := z0 + dir * 2.3
	var y0 := 1.0 if ground else 1.05
	geo.box(Vector3(1.05, y0, minf(z0, z1)), Vector3(30.95, top, maxf(z0, z1)), "structure", S_METAL,
		"metal", S_METAL)


## Checkpoint / finish / multilap gate centred at z: the arch on brackets over the curbs, and the
## two sign boards on top (visual only).
func _gate(geo: TmGeo, zc: float) -> void:
	var sec := GATE_ARCH.map(func(q: Array) -> Array: return [Vector2(q[0], q[1]), q[2], q[3]])
	geo.wall_sweep(sec, [Vector3(0, 0, zc - 2.1), Vector3(0, 0, zc + 2.1)], [Vector3(1, 0, 0), Vector3(1, 0, 0)],
		true, "structure", S_METAL)
	for x0 in [2.9, 27.7]:
		geo.box(Vector3(x0, 2.5, zc - 1.4), Vector3(x0 + 1.4, 4.4, zc + 1.4), "structure", S_METAL)
	for mirror in [false, true]:
		var sign := []
		for q in GATE_SIGN:
			sign.append([Vector2(32.0 - q[0] if mirror else q[0], q[1]), "screen", TmGeo.NO_COLLISION])
		geo.wall_sweep(sign, [Vector3(0, 0, zc - 2.25), Vector3(0, 0, zc + 2.25)], [Vector3(1, 0, 0), Vector3(1, 0, 0)],
			true, "screen", TmGeo.NO_COLLISION)


## Turbo (and free-wheel) gate: the U-frame round the road and two booster pods along z.
func _turbo_gate(geo: TmGeo) -> void:
	var sec := TURBO_FRAME.map(func(q: Array) -> Array: return [Vector2(q[0], q[1]), q[2], q[3]])
	geo.wall_sweep(sec, [Vector3(0, 0, 14.4), Vector3(0, 0, 17.45)], [Vector3(1, 0, 0), Vector3(1, 0, 0)],
		true, "structure", 22)
	for x in [2.0, 30.0]:
		geo.pipe(Vector3(x, 4.85, 7.63), Vector3(x, 4.85, 14.4), 1.84, 16, "structure", 22)


## T and cross: a flat deck, curbs along the closed sides (full length), and the curb revolved
## around each block corner between two open sides.
func _cross(geo: TmGeo, arms: Array, ground: bool) -> void:
	var closed := []
	for i in 4:
		closed.append(not arms.has(i))
	var inset := func(i: int) -> float: return SHOULDER if closed[i] else 0.0
	var lo := Vector3(inset.call(1), 1.0 if ground else 0.0, inset.call(2))
	var hi := Vector3(32.0 - inset.call(3), TOP, 32.0 - inset.call(0))
	geo.box(lo, hi, "structure", S_METAL, _road_mat, _road_surf)
	var curb := _curb_section(ground)
	for i in 4:
		var o: Vector3 = SIDES[i]
		var t := Vector3(o.z, 0.0, -o.x)
		var c := Vector3(16, 0, 16)
		if closed[i]:
			# d measured inward from the edge: lateral = -o, the path along the edge
			geo.wall_sweep(curb, [c + o * 16.0 - t * 16.0, c + o * 16.0 + t * 16.0], [-o, -o], true, "metal", S_METAL)
		# the corner at the end of side i (toward +t) between side i and the next side (outward t)
		var j := SIDES.find(t)
		if not closed[i] and not closed[j]:
			var corner := c + o * 16.0 + t * 16.0
			var path := []
			var lat := []
			var steps := 6
			for s in steps + 1:
				var ang := PI * 0.5 * float(s) / steps
				# the radial direction sweeps from -t (toward the corner's side-i neighbour) to -o
				lat.append((-t * cos(ang) - o * sin(ang)).normalized())
				path.append(corner)
			geo.wall_sweep(curb, path, lat, true, "metal", S_METAL)
