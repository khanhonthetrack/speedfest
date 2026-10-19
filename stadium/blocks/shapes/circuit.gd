extends RefCounted
## Stadium "Circuit" blocks: the raised plate (base), its slopes, and the tall border walls. Our own
## geometry from measured numbers (TMNF block-local metres: x right, y up, z forward; see TmGeo).
##
## Every border is one wall section swept along a path: its inner (road) face runs 8.985 m inside
## the border's cell; corners and GT curves are arcs about the footprint's inner corner (radius
## 32k - 8.985) or outer corner (32(k - 1) + 8.985); the ledge behind the wall (top 8 m) fills the
## rest of the footprint. Its top is the blue border strip, BAND wide along the wall as on a
## straight, and the lane's deck beyond it (TMNF's StadiumRoadCircuitBorder and StadiumPlatform,
## measured on every border). Slopes rise 16 m per block (0.5); start/end ease in over a block.

const S_ASPHALT := 16   # TmTuning.Surface ids
const S_METAL := 4
const S_RUBBER := 9
const S_CONCRETE := 0
const FACE := 23.015            ## the wall's inner face, from the cell's road side (z)
const LEDGE_D := 4.075          ## the stands' foot behind the face (d), where the ledge starts
const BAND := 32.0 - FACE - LEDGE_D   ## the blue strip on the ledge, along the wall (4.91 m)
const GROUND_STRIP := [0.465, 5.155]  ## ground borders: the blue strip on the terrain, from / to (m out from the face)
const GROUND_LIFT := 0.01       ## that strip above the grass (no z-fighting; a wheel's ray finds it first)
## Outer GT curves on the ground: the strip widens mid-curve by this much (m, at 45 deg; measured)
const GROUND_OUT_BULGE := {2: 0.46, 3: 0.33, 4: 0.10}
## Rubber pads across the ground strip where it meets a cell corner (TMNF x, z; measured)
const GROUND_PADS := {
	"GTCurve2Out": [[[29.88, 29.94], [32.0, 32.0], [34.03, 34.16], [32.98, 35.09], [31.02, 32.99], [28.92, 31.04]]],
	"GTCurve4In": [[[97.28, 61.97], [98.14, 62.52], [96.75, 64.64], [95.31, 66.73], [94.45, 66.13], [96.0, 64.0]],
		[[66.17, 94.48], [66.75, 95.31], [64.66, 96.74], [62.53, 98.13], [61.98, 97.3], [64.0, 96.0]]],
}
const LEDGE_Y := 8.0
const FLOOR_Y := 0.24

## Wall section: (d, y) points around the solid, d = offset from the inner face outward, with the
## material/surface of the segment starting at each point. Rubber bumper at the foot, light band,
## blue band, white cladding, blue top lip at 15-16 m, cap, truss and the dark screen on the lane's
## side above the lane-level ledge (8 m), down to the truss' foot (TMNF's colours: TmMaterials).
const WALL := [
	[-0.465, 0.10, "rubber_dark", S_RUBBER], [-0.585, 0.31, "rubber_dark", S_RUBBER], [-0.645, 0.54, "rubber_dark", S_RUBBER],
	[-0.615, 0.81, "rubber_dark", S_RUBBER], [-0.415, 1.28, "metal", S_METAL], [-0.415, 1.79, "metal", S_METAL],
	[0.305, 2.41, "metal", S_METAL], [-0.055, 2.65, "metal", S_METAL], [-0.125, 2.87, "metal", S_METAL],
	[-0.125, 3.22, "metal", S_METAL], [0.0, 3.40, "circuit_band", S_METAL], [0.0, 7.00, "circuit_panel", S_RUBBER],
	[-0.135, 7.07, "circuit_panel", S_RUBBER], [-0.135, 14.86, "circuit_trim", S_RUBBER], [-0.065, 15.61, "circuit_trim", S_RUBBER],
	[0.105, 15.83, "circuit_trim", S_RUBBER], [0.415, 15.96, "circuit_trim", S_RUBBER], [0.775, 16.0, "fabric", S_METAL],
	[2.665, 16.0, "fabric", S_METAL], [2.835, 15.94, "fabric", S_METAL], [2.885, 15.77, "fabric", S_METAL],
	[2.885, 15.28, "circuit_trim", S_METAL], [2.595, 15.06, "truss", S_CONCRETE], [2.595, 12.66, "screen_dark", S_METAL],
	[2.595, 9.63, "truss", S_CONCRETE], [2.595, 9.42, "circuit_bumper", S_RUBBER], [3.565, 9.09, "circuit_bumper", S_RUBBER],
	[3.935, 8.81, "circuit_bumper", S_RUBBER], [4.145, 8.33, "circuit_bumper", S_RUBBER], [4.075, 8.0, "", S_METAL],
	[4.075, 0.24, "truss", S_METAL], [3.595, 0.24, "truss", S_METAL], [3.415, 0.0, "fabric_auvent", S_RUBBER],
	[-0.245, 0.0, "rubber_dark", S_RUBBER],
]

## Level walls across a slope (Top: at the top of the slope, facing down it; Bottom: at its foot):
## the wall's section (z, y, material, surface) reshaped to sit on the ramp, the same at every x
## (measured: tools/research/tmnf/section_loop.py).
const SLOPE_TOP_WALL := [
	[9.405, 6.495, "structure", S_ASPHALT], [9.027, 6.629, "structure", S_ASPHALT],
	[8.681, 6.753, "circuit_panel", S_RUBBER], [9.039, 7.164, "circuit_panel", S_RUBBER], [9.112, 7.429, "circuit_panel", S_RUBBER],
	[9.115, 7.780, "circuit_panel", S_RUBBER], [9.082, 7.893, "circuit_panel", S_RUBBER], [8.985, 7.892, "circuit_trim", S_RUBBER],
	[8.985, 8.034, "circuit_band", S_METAL], [8.985, 11.351, "circuit_trim", S_RUBBER], [8.985, 11.492, "circuit_panel", S_RUBBER],
	[9.115, 11.627, "circuit_panel", S_RUBBER], [9.117, 19.417, "circuit_trim", S_RUBBER],
	[9.118, 19.798, "circuit_trim", S_RUBBER], [9.048, 20.130, "circuit_trim", S_RUBBER],
	[8.883, 20.274, "circuit_trim", S_RUBBER], [8.573, 20.250, "circuit_trim", S_RUBBER],
	[8.214, 20.107, "circuit_trim", S_RUBBER], [7.944, 19.972, "circuit_panel", S_RUBBER],
	[6.323, 19.162, "circuit_panel", S_RUBBER], [6.153, 19.020, "circuit_panel", S_RUBBER], [6.103, 18.820, "circuit_panel", S_RUBBER],
	[6.102, 18.409, "circuit_panel", S_RUBBER], [6.101, 18.334, "circuit_panel", S_RUBBER], [6.145, 18.302, "rubber_dark", S_RUBBER],
	[6.386, 18.247, "truss", S_CONCRETE], [6.386, 15.850, "screen_dark", S_METAL],
	[6.386, 12.818, "truss", S_CONCRETE], [6.386, 12.612, "rubber_dark", S_RUBBER],
	[6.281, 12.232, "rubber_dark", S_RUBBER], [5.421, 11.802, "rubber_dark", S_RUBBER], [5.386, 11.683, "rubber_dark", S_RUBBER],
	[5.055, 11.340, "rubber_dark", S_RUBBER], [4.924, 11.128, "rubber_dark", S_RUBBER], [4.843, 10.885, "rubber_dark", S_RUBBER],
	[4.843, 10.624, "rubber_dark", S_RUBBER], [4.908, 10.454, "circuit_floor", S_RUBBER],
	[0.000, 8.000, "circuit_side", S_METAL], [0.000, 0.243, "truss", S_CONCRETE],
	[5.387, 2.937, "rubber_dark", S_RUBBER], [5.575, 2.787, "circuit_panel", S_RUBBER], [9.228, 4.614, "circuit_panel", S_RUBBER],
	[9.449, 4.828, "rubber_dark", S_RUBBER], [9.568, 5.093, "rubber_dark", S_RUBBER], [9.630, 5.353, "rubber_dark", S_RUBBER],
	[9.597, 5.611, "rubber_dark", S_RUBBER], [9.405, 5.983, "structure", S_ASPHALT]
]
const SLOPE_BOTTOM_WALL := [
	[22.595, 5.089, "structure", S_ASPHALT], [22.627, 5.132, "structure", S_ASPHALT],
	[23.319, 6.072, "circuit_panel", S_RUBBER], [22.961, 6.126, "circuit_panel", S_RUBBER], [22.888, 6.318, "circuit_panel", S_RUBBER],
	[22.885, 6.665, "circuit_panel", S_RUBBER], [22.918, 6.811, "circuit_panel", S_RUBBER],
	[23.015, 6.908, "circuit_trim", S_RUBBER], [23.015, 7.049, "circuit_band", S_METAL],
	[23.015, 10.366, "circuit_trim", S_RUBBER], [23.015, 10.508, "circuit_panel", S_RUBBER],
	[22.885, 10.512, "circuit_panel", S_RUBBER], [22.883, 18.299, "circuit_trim", S_RUBBER],
	[22.882, 18.681, "circuit_trim", S_RUBBER], [22.952, 19.081, "circuit_trim", S_RUBBER],
	[23.117, 19.391, "circuit_trim", S_RUBBER], [23.427, 19.677, "circuit_trim", S_RUBBER],
	[23.786, 19.893, "circuit_trim", S_RUBBER], [24.056, 20.028, "circuit_panel", S_RUBBER],
	[25.677, 20.838, "circuit_panel", S_RUBBER], [25.847, 20.867, "circuit_panel", S_RUBBER], [25.897, 20.717, "circuit_panel", S_RUBBER],
	[25.898, 20.306, "circuit_panel", S_RUBBER], [25.898, 20.232, "circuit_panel", S_RUBBER], [25.855, 20.157, "rubber_dark", S_RUBBER],
	[25.614, 19.862, "truss", S_CONCRETE], [25.614, 17.464, "screen_dark", S_METAL],
	[25.614, 14.432, "truss", S_CONCRETE], [25.614, 14.226, "rubber_dark", S_RUBBER],
	[25.719, 13.951, "rubber_dark", S_RUBBER], [26.579, 14.381, "rubber_dark", S_RUBBER],
	[26.614, 14.297, "rubber_dark", S_RUBBER], [26.945, 14.286, "rubber_dark", S_RUBBER],
	[27.076, 14.203, "rubber_dark", S_RUBBER], [27.157, 14.041, "rubber_dark", S_RUBBER],
	[27.157, 13.780, "rubber_dark", S_RUBBER], [27.092, 13.546, "circuit_floor", S_RUBBER],
	[32.000, 16.000, "circuit_side", S_METAL], [32.000, 8.243, "truss", S_CONCRETE],
	[26.613, 5.550, "rubber_dark", S_RUBBER], [26.425, 5.213, "circuit_panel", S_RUBBER], [22.772, 3.386, "circuit_panel", S_RUBBER],
	[22.551, 3.379, "rubber_dark", S_RUBBER], [22.432, 3.525, "rubber_dark", S_RUBBER], [22.370, 3.723, "rubber_dark", S_RUBBER],
	[22.404, 4.014, "rubber_dark", S_RUBBER], [22.595, 4.578, "structure", S_ASPHALT]
]

## Curved borders (but the 1x1 outer corner) lower the wall's top (above the screen, 12.66 m) by
## TOP_DROP in their middle (16 -> 13.81 m), ramping between these distances (m along the face)
## from each end (measured).
const TOP_DROP := 2.19
const TOP_DIP_CORNER := [2.2, 6.0]
const TOP_DIP_GT := [5.3, 10.4]

## Circuit slope road heights (z, y) of the base blocks: start eases 0 -> 0.5, end 0.5 -> 0.
const SLOPE_START := [[0, 8.0], [1.92, 8.0], [3.98, 8.0], [6, 8.09], [8, 8.27], [10, 8.52], [12, 8.85], [14, 9.27],
	[16, 9.74], [18, 10.27], [20, 10.86], [22, 11.52], [24, 12.24], [26, 13.05], [28, 13.94], [30, 14.93], [32, 16.0]]
const SLOPE_STRAIGHT := [[0, 8.0], [32, 24.0]]
const SLOPE_K := 0.5
## Turns on a slope: the flat piece's quarter turns (about the footprint's centre, +x toward +z)
## per variant (measured: the curve's centre and arc in each piece).
const SLOPE_TURNS_IN := {"RightBottom": 0, "LeftBottom": 1, "LeftTop": 2, "RightTop": 3}
const SLOPE_TURNS_OUT := {"LeftBottom": 0, "LeftTop": 1, "RightTop": 2, "RightBottom": 3}
const SLOPE_END := [[0, 8.0], [2.01, 8.99], [4, 9.92], [6, 10.78], [8, 11.56], [10, 12.28], [12, 12.93], [14, 13.52],
	[16, 14.05], [18, 14.53], [20, 14.95], [22, 15.31], [24, 15.59], [26, 15.81], [28.02, 15.93], [30.08, 15.97], [32, 16.0]]


func handles(shape: String) -> bool:
	return shape.begins_with("Circuit/Road/Base") or shape.begins_with("Circuit/Border/") \
		or shape.begins_with("Circuit/Slope/")


var _cells: Array = []        ## the shape's footprint cells (bottom layer, Vector2i x, z units)
var _sides_mapped := false    ## the circuit sides' UVs are TMNF's already (before a turn or shear)
var _top_at := Callable()     ## the sides' top at a point (TMNF x, y, z) on slopes (else 8 m)


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var geo := TmGeo.new()
	geo.cap_uv = _cap_uv
	geo.cap_split = LEDGE_Y
	_cells = []
	_sides_mapped = false
	_top_at = Callable()
	for u in TmBlockCatalogue.shape_units(shape):
		if int(u[1]) == 0:
			_cells.append(Vector2i(int(u[0]), int(u[2])))
	var ground := shape.contains("Ground")
	var dy := 1.0 if ground else 0.0
	var parts := shape.split("/")
	if shape.begins_with("Circuit/Road/Base"):
		if not (shape.ends_with("BaseAir") or shape.ends_with("BaseGround")):
			return null   # bump/hole/pillar variants: not yet
		_plate(geo, dy)
	elif shape.begins_with("Circuit/Border/"):
		if not _border(geo, parts[2], parts[3], dy):
			return null
		if ground:
			_ground_floor(geo, parts[2], parts[3])
	else:
		if not _slope(geo, parts[2], parts[3], dy):
			return null
		if ground and parts[2] == "Start" and not parts[3].begins_with("Base"):
			_slope_start_floor(geo, parts[3])
	_map_sides(geo)
	return geo.build()


## The circuit sides' texture as TMNF lays it: 16 m a tile along every upright face (mirrored
## every other tile), the whole texture over 8 m of height down from the piece's top (on slopes
## the road's edge).
func _map_sides(geo: TmGeo) -> void:
	if not _sides_mapped:
		geo.remap_uv_sides("circuit_side", 16.0, 8.0, 8.0, _top_at)
		_sides_mapped = true


## The walls' end caps as TMNF maps them: the circuit side's left part (its bolted plate) laid over
## the section (q: d, y), one chart up to the ledge's top and one above it (measured on the straight).
static func _cap_uv(q: Vector2, cen: Vector2) -> Vector2:
	if cen.y < LEDGE_Y:
		return Vector2(0.012 + (32.0 - FACE - q.x) * 0.0484, 0.861 - 0.0874 * q.y)
	return Vector2(0.007 + (q.x + 0.135) * 0.0385, 1.406 - 0.0781 * q.y)


## The circuit's plate: the deck on top, TMNF's circuit sides, the white fabric underneath.
func _plate(geo: TmGeo, dy: float) -> void:
	var y0 := dy
	geo.quad(Vector3(0, 8, 0), Vector3(0, 8, 32), Vector3(32, 8, 32), Vector3(32, 8, 0), "platform", S_ASPHALT)
	if dy <= 0.0:   # (on the ground the terrain hides it)
		geo.quad(Vector3(0, y0, 0), Vector3(32, y0, 0), Vector3(32, y0, 32), Vector3(0, y0, 32), "fabric_auvent", S_RUBBER)
	geo.quad(Vector3(0, y0, 0), Vector3(0, 8, 0), Vector3(32, 8, 0), Vector3(32, y0, 0), "circuit_side", S_METAL)
	geo.quad(Vector3(32, y0, 32), Vector3(32, 8, 32), Vector3(0, 8, 32), Vector3(0, y0, 32), "circuit_side", S_METAL)
	geo.quad(Vector3(0, y0, 32), Vector3(0, 8, 32), Vector3(0, 8, 0), Vector3(0, y0, 0), "circuit_side", S_METAL)
	geo.quad(Vector3(32, y0, 0), Vector3(32, 8, 0), Vector3(32, 8, 32), Vector3(32, y0, 32), "circuit_side", S_METAL)


## Ground borders stand on the terrain (the map's ground at 1 m block-local, built separately). In
## front of the wall's foot TMNF lays its blue border strip on the terrain, GROUND_STRIP out from
## the face: along a straight, radially round corners and GT curves (outer ones a little wider
## mid-curve), along the cell edges by a diagonal (as the wall's section is sheared there); a few
## rubber pads cross it (GROUND_PADS).
func _ground_floor(geo: TmGeo, kind: String, variant: String) -> void:
	var a: float = GROUND_STRIP[0]
	var b: float = GROUND_STRIP[1]
	var k := int(variant.substr(0, 1)) if kind == "GTCurve" else 1
	var s := 32.0 * k
	var poly := PackedVector2Array()
	match kind:
		"Straight":
			poly = PackedVector2Array([Vector2(0, FACE - b), Vector2(32, FACE - b), Vector2(32, FACE - a), Vector2(0, FACE - a)])
		"Corner", "GTCurve":
			if variant.contains("In"):
				# the grass inside the arc about (0, 0)
				var r := s - (32.0 - FACE)
				for i in 8 * k + 1:
					var ang := PI * 0.5 * float(i) / (8 * k)
					poly.append(Vector2(cos(ang), sin(ang)) * (r - a))
				for i in 8 * k + 1:
					var ang := PI * 0.5 * (1.0 - float(i) / (8 * k))
					poly.append(Vector2(cos(ang), sin(ang)) * (r - b))
			else:
				# outside the arc about (0, s)
				var r := s - FACE
				for i in 6 * k + 1:
					var ang := -PI * 0.5 + PI * 0.5 * float(i) / (6 * k)
					poly.append(Vector2(0, s) + Vector2(cos(ang), sin(ang)) * (r + a))
				var bulge: float = GROUND_OUT_BULGE.get(k, 0.0)
				for i in 6 * k + 1:
					var t := float(i) / (6 * k)
					var ang := -PI * 0.5 * t
					poly.append(Vector2(0, s) + Vector2(cos(ang), sin(ang)) * (r + b + bulge * sin(PI * t)))
		"Diag":
			if variant.contains("In"):
				poly = PackedVector2Array([Vector2(FACE - b, 0), Vector2(FACE - a, 0), Vector2(0, FACE - a), Vector2(0, FACE - b)])
			else:
				poly = PackedVector2Array([Vector2(0, FACE - b), Vector2(0, FACE - a), Vector2(32 - FACE + a, 32),
					Vector2(32 - FACE + b, 32)])
	if poly.size() < 3:
		return
	var y := 1.0 + GROUND_LIFT
	var pieces: Array = [poly]
	for pad: Array in GROUND_PADS.get(kind + ("%d" % k if kind == "GTCurve" else "") + ("In" if variant.contains("In") else "Out"), []):
		var pp := PackedVector2Array()
		for q: Array in pad:
			pp.append(Vector2(q[0], q[1]))
		# split through the pad first, so clipping it leaves notches, never a hole
		var cx := 0.0
		for q in pp:
			cx += q.x / pp.size()
		var halves := [PackedVector2Array([Vector2(-1e4, -1e4), Vector2(cx, -1e4), Vector2(cx, 1e4), Vector2(-1e4, 1e4)]),
			PackedVector2Array([Vector2(cx, -1e4), Vector2(1e4, -1e4), Vector2(1e4, 1e4), Vector2(cx, 1e4)])]
		var rest := []
		for piece: PackedVector2Array in pieces:
			for half: PackedVector2Array in halves:
				for part: PackedVector2Array in Geometry2D.intersect_polygons(piece, half):
					rest.append_array(Geometry2D.clip_polygons(part, pp))
		pieces = rest
		geo.flat_polygon(pp, y, "rubber_dark", S_RUBBER)
	for piece: PackedVector2Array in pieces:
		if absf(_area(piece)) > 0.01:
			geo.flat_polygon(piece, y, "circuit_floor", S_RUBBER)


## A slope start on the terrain ("GroundLeft" / "GroundRight"): TMNF's black rubber strip in front
## of the wall's foot, GROUND_STRIP out from the face, for the first 12 m (before the ramp lifts
## the wall off the ground).
func _slope_start_floor(geo: TmGeo, variant: String) -> void:
	var a: float = GROUND_STRIP[0]
	var b: float = GROUND_STRIP[1]
	var x0 := 32.0 - FACE + a if variant.ends_with("Left") else FACE - b
	var x1 := 32.0 - FACE + b if variant.ends_with("Left") else FACE - a
	geo.flat_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, 12), Vector2(x0, 12)]),
		1.0 + GROUND_LIFT, "rubber_dark", S_RUBBER)


## Border walls: Straight, Corner In/Out, GTCurve kIn/kOut, Diag In/Out.
func _border(geo: TmGeo, kind: String, variant: String, dy: float) -> bool:
	var section := _section(dy)
	if kind == "Straight":
		_line_wall(geo, section, Vector3(32, 0, FACE), Vector3(0, 0, FACE), Vector3(0, 0, 1), dy, true)
		return true
	var inner := variant.begins_with("In") or variant.contains("In")
	var k := 1
	if kind == "GTCurve":
		k = int(variant.substr(0, 1))
	if kind == "Corner" or kind == "GTCurve":
		var s := 32.0 * k
		# curves wider than the 1x1 outer corner lower their top in the middle (see TOP_DIP)
		var dip: Array = TOP_DIP_CORNER if kind == "Corner" else TOP_DIP_GT
		if inner:
			var r := s - (32.0 - FACE)
			var a := _arc_dip(Vector2(0, 0), r, 0.0, PI * 0.5, 8 * k, dip)
			geo.wall_sweep(section, a[0], a[1], true, "circuit_cap", S_METAL, _dip_fn(a[2]))
			# ledge: the footprint outside the stands' foot circle; blue out to radius s, the deck
			# in the corner beyond
			var poly := PackedVector2Array()
			var band := PackedVector2Array()
			for i in 8 * k + 1:
				var ang := PI * 0.5 * (1.0 - float(i) / (8 * k))
				poly.append(Vector2(cos(ang), sin(ang)) * (r + LEDGE_D))
				band.append(Vector2(cos(ang), sin(ang)) * (r + LEDGE_D))
			for i in 8 * k + 1:
				var ang := PI * 0.5 * float(i) / (8 * k)
				band.append(Vector2(cos(ang), sin(ang)) * (r + LEDGE_D + BAND))
			poly.append(Vector2(s, 0))
			poly.append(Vector2(s, s))
			poly.append(Vector2(0, s))
			_ledge(geo, poly, dy, band, func(q: Vector2) -> bool: return absf(q.length() - r - LEDGE_D) < 0.01)
		else:
			var r := s - FACE
			var a := _arc_dip(Vector2(0, s), r, -PI * 0.5, 0.0, 6 * k, [] if kind == "Corner" else dip)
			var outs := []
			for d in a[1]:
				outs.append(-(d as Vector3))
			geo.wall_sweep(section, a[0], outs, true, "circuit_cap", S_METAL, _dip_fn(a[2]))
			# ledge: inside the stands' foot circle; blue down to radius s - 32, the deck inside
			# that (a 1x1 corner's ledge is all strip)
			var poly := PackedVector2Array()
			var band := PackedVector2Array()
			for i in 6 * k + 1:
				var ang := -PI * 0.5 + PI * 0.5 * float(i) / (6 * k)
				poly.append(Vector2(0, s) + Vector2(cos(ang), sin(ang)) * (r - LEDGE_D))
				band.append(Vector2(0, s) + Vector2(cos(ang), sin(ang)) * (r - LEDGE_D))
			poly.append(Vector2(0, s))
			if k > 1:
				for i in 6 * k + 1:
					var ang := -PI * 0.5 * float(i) / (6 * k)
					band.append(Vector2(0, s) + Vector2(cos(ang), sin(ang)) * (r - LEDGE_D - BAND))
			_ledge(geo, poly, dy, band if k > 1 else PackedVector2Array(),
				func(q: Vector2) -> bool: return absf((q - Vector2(0, s)).length() - r + LEDGE_D) < 0.01)
		return true
	if kind == "Diag":
		# 45 deg walls across the cell's corner: the straight wall's section sheared along each
		# cell edge it meets (so the ends match the neighbouring straights), mitred at the middle
		if inner:
			_diag_wall(geo, section, Vector3(0, 0, FACE), Vector3(FACE, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
			var e := FACE + LEDGE_D
			_ledge(geo, PackedVector2Array([Vector2(e, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32), Vector2(0, e)]), dy,
				PackedVector2Array([Vector2(e, 0), Vector2(32, 0), Vector2(0, 32), Vector2(0, e)]),
				func(q: Vector2) -> bool: return absf(q.x + q.y - e) < 0.01)
		else:
			_diag_wall(geo, section, Vector3(0, 0, FACE), Vector3(32 - FACE, 0, 32), Vector3(0, 0, 1), Vector3(-1, 0, 0))
			var e := LEDGE_D
			_ledge(geo, PackedVector2Array([Vector2(0, FACE + e), Vector2(32 - FACE - e, 32), Vector2(0, 32)]), dy,
				PackedVector2Array(), func(q: Vector2) -> bool: return absf(q.y - q.x - FACE - e) < 0.01)
		return true
	return false


## Arc points (TMNF x, z plane at y 0) about c from angle a0 to a1 in `steps` plus knots at the
## dip's ramp ends; returns [points, radial dirs, top drop per point]. The drop ramps 0 -> TOP_DROP
## between dip[0] and dip[1] metres (along the face) from each end.
static func _arc_dip(c: Vector2, r: float, a0: float, a1: float, steps: int, dip: Array) -> Array:
	var span := absf(a1 - a0)
	var ts := []
	for i in steps + 1:
		ts.append(float(i) / steps)
	for m in dip:
		ts.append(float(m) / (r * span))
		ts.append(1.0 - float(m) / (r * span))
	ts.sort()
	var pts := []
	var rad := []
	var drops := []
	var last := -1.0
	for t: float in ts:
		if t - last < 1e-4:
			continue
		last = t
		var ang := lerpf(a0, a1, t)
		var d := Vector3(cos(ang), 0.0, sin(ang))
		pts.append(Vector3(c.x, 0.0, c.y) + d * r)
		rad.append(d)
		var from_end := minf(t, 1.0 - t) * r * span
		drops.append(0.0 if dip.is_empty() else TOP_DROP * clampf((from_end - float(dip[0])) / (float(dip[1]) - float(dip[0])), 0.0, 1.0))
	return [pts, rad, drops]


## The section's heights at a curve point: the top (above the screen) lowered by its drop.
static func _dip_fn(drops: Array) -> Callable:
	return func(y: float, i: int) -> float: return y - float(drops[i]) if y > 14.5 else y


## A diagonal wall a -> b: at a its section runs along l_a (the outward of the straight wall that
## continues it there), at b along l_b; the two sheared halves meet on the mitre at the middle.
func _diag_wall(geo: TmGeo, section: Array, a: Vector3, b: Vector3, l_a: Vector3, l_b: Vector3) -> void:
	geo.wall_sweep(section, [a, (a + b) * 0.5, b], [l_a, (l_a + l_b) * 0.5, l_b], true, "circuit_cap", S_METAL)


## The wall section (d, y) with the ground variants' heights (see _lift).
func _section(dy: float) -> Array:
	var out := []
	for p in WALL:
		out.append([Vector2(float(p[0]), _lift(float(p[1]), dy)), String(p[2]), int(p[3])])
	# on the ground the faces on the terrain are collision only (the terrain hides them)
	for i in out.size() - 1:
		if dy > 0.0 and (out[i][0] as Vector2).y == dy and (out[i + 1][0] as Vector2).y == dy:
			out[i][1] = ""
	return out


## Ground variants stand on the terrain (dy = 1 m): the wall's lower part (below the 8 m ledge)
## rises by dy and its foot and floors sit on the terrain; the ledge top and the upper wall keep
## their heights (measured).
static func _lift(y: float, dy: float) -> float:
	if dy == 0.0 or y >= 7.5:
		return y
	if y <= FLOOR_Y + 0.01:
		return dy
	return y + dy


## A straight wall from a to b (TMNF x, z; y = base), outward horizontal; full = with the ledge
## out to the cell edge (8.985 m behind the face).
func _line_wall(geo: TmGeo, section: Array, a: Vector3, b: Vector3, outward: Vector3, dy: float, full: bool) -> void:
	var sec := section
	if full:
		sec = []
		for p in section:
			if (p[0] as Vector2).x >= LEDGE_D - 0.01 and (p[0] as Vector2).y < LEDGE_Y + 0.01:
				continue
			sec.append(p)
		# ledge to the cell edge: top at 8 m, outer face, floor
		var e := 32.0 - FACE
		var at := sec.find(sec.filter(func(q): return (q[0] as Vector2).x > 4.0 and absf((q[0] as Vector2).y - 8.33) < 0.01)[0])
		sec.insert(at + 1, [Vector2(4.075, LEDGE_Y), "circuit_floor", S_RUBBER])
		sec.insert(at + 2, [Vector2(e, LEDGE_Y), "circuit_side", S_METAL])
		sec.insert(at + 3, [Vector2(e, _lift(FLOOR_Y, dy)), "truss" if dy <= 0.0 else "", S_CONCRETE])
		sec.insert(at + 4, [Vector2(3.595, _lift(FLOOR_Y, dy)), "truss" if dy <= 0.0 else "", S_METAL])
	geo.wall_sweep(sec, [a, b], [outward, outward], true, "circuit_cap", S_METAL)


## Ledge behind a curved wall: a solid prism over the polygon (TMNF x, z), floor 0.24 m (ground:
## the terrain), top 8 m; clipped to the block's footprint cells (big curves leave out the cells
## near their centre or far corner). Its top is blue inside `band` (empty: all of it), the deck
## outside; no side where it meets the wall's back (`at_wall`: points on that line).
func _ledge(geo: TmGeo, poly: PackedVector2Array, dy: float, band := PackedVector2Array(), at_wall := Callable()) -> void:
	if _cells.is_empty():
		_prism(geo, poly, dy, band, at_wall)
		return
	var pieces := []
	for c: Vector2i in _cells:
		var o := Vector2(c) * 32.0
		var sq := PackedVector2Array([o, o + Vector2(32, 0), o + Vector2(32, 32), o + Vector2(0, 32)])
		for p: PackedVector2Array in Geometry2D.intersect_polygons(poly, sq):
			if absf(_area(p)) > 0.01:
				pieces.append(p)
	# merge the per-cell pieces into whole polygons
	var merged := []
	for p: PackedVector2Array in pieces:
		var cur := p
		var rest := []
		for q: PackedVector2Array in merged:
			var m := Geometry2D.merge_polygons(cur, q)
			if m.size() == 1:
				cur = m[0]
			else:
				rest.append(q)
		rest.append(cur)
		merged = rest
	for p: PackedVector2Array in merged:
		_prism(geo, p, dy, band, at_wall)


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5


func _prism(geo: TmGeo, poly: PackedVector2Array, dy: float, band := PackedVector2Array(), at_wall := Callable()) -> void:
	var lo := _lift(FLOOR_Y, dy)
	var hi := LEDGE_Y
	if band.is_empty():
		geo.flat_polygon(poly, hi, "circuit_floor", S_RUBBER)
	else:
		for p: PackedVector2Array in Geometry2D.intersect_polygons(poly, band):
			if absf(_area(p)) > 0.01:
				geo.flat_polygon(p, hi, "circuit_floor", S_RUBBER)
		for p: PackedVector2Array in Geometry2D.clip_polygons(poly, band):
			if absf(_area(p)) > 0.01:
				geo.flat_polygon(p, hi, "platform", S_ASPHALT)
	# underneath: TMNF's dark stands' floor under the blue strip, its white fabric under the deck
	# (on the ground the terrain hides it)
	if dy > 0.0:
		pass
	elif band.is_empty():
		geo.flat_polygon(poly, lo, "truss", S_METAL, true)
	else:
		for p: PackedVector2Array in Geometry2D.intersect_polygons(poly, band):
			if absf(_area(p)) > 0.01:
				geo.flat_polygon(p, lo, "truss", S_METAL, true)
		for p: PackedVector2Array in Geometry2D.clip_polygons(poly, band):
			if absf(_area(p)) > 0.01:
				geo.flat_polygon(p, lo, "fabric_auvent", S_RUBBER, true)
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		if at_wall.is_valid() and at_wall.call(p) and at_wall.call(q):
			continue
		var a := Vector3(p.x, lo, p.y)
		var b := Vector3(q.x, lo, q.y)
		var c := Vector3(q.x, hi, q.y)
		var d := Vector3(p.x, hi, p.y)
		# outward: away from the polygon's centroid
		var mid := (a + b) * 0.5
		var cen := Vector3.ZERO
		for v in poly:
			cen += Vector3(v.x, 0, v.y)
		cen /= poly.size()
		if (b - a).cross(c - a).dot(Vector3(mid.x - cen.x, 0, mid.z - cen.z)) < 0.0:
			geo.quad(a, d, c, b, "circuit_side", S_METAL)
		else:
			geo.quad(a, b, c, d, "circuit_side", S_METAL)


## Slope blocks: Base (the road ramp) and the border walls along (Left/Right) or across
## (Top/Bottom) the slope. kind: Start, Straight, End; Corner, GTCurve, Diag (turns on the slope).
func _slope(geo: TmGeo, kind: String, variant: String, dy: float) -> bool:
	if kind in ["Corner", "GTCurve", "Diag"]:
		return _slope_turn(geo, kind, variant)
	var prof: Array = SLOPE_START if kind == "Start" else (SLOPE_END if kind == "End" else SLOPE_STRAIGHT)
	if kind not in ["Start", "Straight", "End"]:
		return false
	_top_at = func(p: Vector3) -> float: return _prof_y(prof, p.z)
	if variant.begins_with("Base"):
		_ramp(geo, prof, dy)
		return true
	var section := _section(0.0)
	if variant.ends_with("Left") or variant.ends_with("Right"):
		var x := 32.0 - FACE if variant.ends_with("Left") else FACE
		var out := Vector3(-1, 0, 0) if variant.ends_with("Left") else Vector3(1, 0, 0)
		var path := []
		var outs := []
		for p in prof:
			path.append(Vector3(x, float(p[1]) - 8.0, float(p[0])))
			outs.append(out)
		_full_wall(geo, section, path, outs, dy)
		return true
	if variant.ends_with("Top") or variant.ends_with("Bottom"):
		if kind != "Straight":
			return false
		var table: Array = SLOPE_TOP_WALL if variant.ends_with("Top") else SLOPE_BOTTOM_WALL
		var top := 8.0 if variant.ends_with("Top") else 16.0
		_top_at = func(_p: Vector3) -> float: return top
		var sec := table.map(func(q: Array) -> Array: return [Vector2(q[0], q[1] + dy), q[2], q[3]])
		geo.wall_sweep(sec, [Vector3(0, 0, 0), Vector3(32, 0, 0)], [Vector3(0, 0, 1), Vector3(0, 0, 1)])
		return true
	return false


## Corners, GT curves and diagonals on a slope (e.g. "InAirLeftTop", "2outAirRightBottom"): the
## flat border wall with its ledge, turned by quarter turns about the footprint's centre and sheared
## up the slope (y += 0.5 z); the block then rests on the unit under its lowest point (measured:
## the radial sections are the flat wall's at every angle, the variants are the four turns).
func _slope_turn(geo: TmGeo, kind: String, variant: String) -> bool:
	var v := variant
	var k := 1
	if kind == "GTCurve":
		k = int(v.substr(0, 1))
		v = v.substr(1)
	var inner := v.to_lower().begins_with("in")
	var turns: Dictionary = SLOPE_TURNS_IN if inner else SLOPE_TURNS_OUT
	var at := ("Left" if v.contains("Left") else "Right") + ("Top" if v.ends_with("Top") else "Bottom")
	var flat := ("In" if inner else "Out")
	# the ledge stays inside the flat piece's own footprint cells
	var flat_shape := "Circuit/Border/%s/%s%sAir" % [kind, str(k) if kind == "GTCurve" else "", flat]
	_cells = []
	for u in TmBlockCatalogue.shape_units(flat_shape):
		if int(u[1]) == 0:
			_cells.append(Vector2i(int(u[0]), int(u[2])))
	if not _border(geo, kind, (str(k) if kind == "GTCurve" else "") + flat, 0.0):
		return false
	_map_sides(geo)
	geo.turn_y(int(turns[at]), Vector2(16.0 * k, 16.0 * k))
	geo.shear_y(0.0, SLOPE_K, 0.0)
	var lo := geo.min_y()
	if lo >= LEDGE_Y - 0.01:
		geo.shear_y(0.0, 0.0, -LEDGE_Y * floorf((lo + 0.01) / LEDGE_Y))
	return true


## A wall with its ledge swept along a (sloped) path. Ground variants keep the air heights, with
## the foot raised onto the terrain (dy) where the path runs below it.
func _full_wall(geo: TmGeo, section: Array, path: Array, outs: Array, dy: float) -> void:
	var sec := []
	for p in section:
		if (p[0] as Vector2).x >= LEDGE_D - 0.01 and (p[0] as Vector2).y < LEDGE_Y + 0.01:
			continue
		sec.append(p)
	var at := 0
	for i in sec.size():
		if (sec[i][0] as Vector2).x > 4.0 and absf((sec[i][0] as Vector2).y - 8.33) < 0.01:
			at = i
	var e := 32.0 - FACE
	sec.insert(at + 1, [Vector2(4.075, LEDGE_Y), "circuit_floor", S_RUBBER])
	sec.insert(at + 2, [Vector2(e, LEDGE_Y), "circuit_side", S_METAL])
	sec.insert(at + 3, [Vector2(e, FLOOR_Y), "truss", S_CONCRETE])
	sec.insert(at + 4, [Vector2(3.595, FLOOR_Y), "truss", S_METAL])
	var y_at := Callable()
	if dy > 0.0:
		y_at = func(y: float, i: int) -> float: return maxf(y, dy - (path[i] as Vector3).y)
	geo.wall_sweep(sec, path, outs, true, "circuit_cap", S_METAL, y_at)


## The circuit's slope base, as TMNF's: the plate (8 m thick) following the road's heights (z, y),
## its underside the white fabric (on the ground: where it is above the terrain), and a round pillar
## under its middle from the block's floor, a collar plate where it meets the underside (measured).
func _ramp(geo: TmGeo, prof: Array, dy: float) -> void:
	# the profile with a point every 16 m at most and where the underside meets the ground
	var pts := []
	for i in prof.size():
		var z := float(prof[i][0])
		var h := float(prof[i][1])
		if i > 0:
			var zp := float(prof[i - 1][0])
			var hp := float(prof[i - 1][1])
			var cuts := []
			for k in range(1, ceili((z - zp) / 16.0 - 1e-4)):
				cuts.append(zp + 16.0 * k)
			if (hp - 8.0 - dy) * (h - 8.0 - dy) < 0.0:
				cuts.append(lerpf(zp, z, (dy + 8.0 - hp) / (h - hp)))
			cuts.sort()
			for zc: float in cuts:
				pts.append(Vector2(zc, lerpf(hp, h, (zc - zp) / (z - zp))))
		pts.append(Vector2(z, h))
	var under := func(h: float) -> float: return maxf(h - 8.0, dy)
	for i in pts.size() - 1:
		var z0: float = pts[i].x
		var z1: float = pts[i + 1].x
		var h0: float = pts[i].y
		var h1: float = pts[i + 1].y
		var b0: float = under.call(h0)
		var b1: float = under.call(h1)
		# road (up), sides (x = 0 facing -x, x = 32 facing +x), underside (down)
		geo.quad(Vector3(32, h0, z0), Vector3(0, h0, z0), Vector3(0, h1, z1), Vector3(32, h1, z1), "platform", S_ASPHALT)
		geo.quad(Vector3(0, b0, z0), Vector3(0, b1, z1), Vector3(0, h1, z1), Vector3(0, h0, z0), "circuit_side", S_METAL)
		geo.quad(Vector3(32, b0, z0), Vector3(32, h0, z0), Vector3(32, h1, z1), Vector3(32, b1, z1), "circuit_side", S_METAL)
		if dy <= 0.0 or maxf(h0, h1) - 8.0 > dy + 1e-3:
			geo.quad(Vector3(0, b0, z0), Vector3(32, b0, z0), Vector3(32, b1, z1), Vector3(0, b1, z1), "fabric_auvent", S_RUBBER)
	var hn: float = pts[pts.size() - 1].y
	var h0: float = pts[0].y
	for x in [[0.0, 16.0], [16.0, 32.0]]:
		geo.quad(Vector3(x[0], under.call(h0), 0), Vector3(x[0], h0, 0), Vector3(x[1], h0, 0), Vector3(x[1], under.call(h0), 0), "circuit_side", S_METAL)
		geo.quad(Vector3(x[1], under.call(hn), 32), Vector3(x[1], hn, 32), Vector3(x[0], hn, 32), Vector3(x[0], under.call(hn), 32), "circuit_side", S_METAL)
	# the pillar: a 12-sided column (r 1.64 m, its foot chamfered to 1.49 m), a 24-sided collar
	# (r 2.0 m, 0.1 m thick) under the plate
	var c := Vector2(16, 16)
	var top := func(q: Vector2) -> float: return _prof_y(prof, q.y) - 8.0
	_ring(geo, c, 12, 1.49, func(_q: Vector2) -> float: return 0.0, 1.64, func(_q: Vector2) -> float: return 0.1, S_METAL)
	_ring(geo, c, 12, 1.64, func(_q: Vector2) -> float: return 0.1, 1.64, func(q: Vector2) -> float: return top.call(q) - 0.05, S_CONCRETE)
	_ring(geo, c, 24, 2.0, func(q: Vector2) -> float: return top.call(q) - 0.1, 2.0, top, S_METAL)
	_disc(geo, c, 12, 1.49, func(_q: Vector2) -> float: return 0.0)
	_disc(geo, c, 24, 2.0, func(q: Vector2) -> float: return top.call(q) - 0.1)


## The road's height at z on a slope profile.
static func _prof_y(prof: Array, z: float) -> float:
	for i in prof.size() - 1:
		if z <= float(prof[i + 1][0]) or i == prof.size() - 2:
			var z0 := float(prof[i][0])
			var z1 := float(prof[i + 1][0])
			return lerpf(float(prof[i][1]), float(prof[i + 1][1]), clampf((z - z0) / (z1 - z0), 0.0, 1.0))
	return float(prof[0][1])


## A band of a round pillar about c (TMNF x, z), n sides (a corner on +x): from radius r0 at
## heights y0(q) to r1 at y1(q) (q the corner's x, z), facing out, shaded round ("truss").
static func _ring(geo: TmGeo, c: Vector2, n: int, r0: float, y0: Callable, r1: float, y1: Callable, surface: int) -> void:
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var p0 := c + d0 * r0
		var p1 := c + d1 * r0
		var q0 := c + d0 * r1
		var q1 := c + d1 * r1
		var a := Vector3(p0.x, y0.call(p0), p0.y)
		var b := Vector3(p1.x, y0.call(p1), p1.y)
		var cc := Vector3(q1.x, y1.call(q1), q1.y)
		var d := Vector3(q0.x, y1.call(q0), q0.y)
		var n0 := Vector3(d0.x, 0, d0.y)
		var n1 := Vector3(d1.x, 0, d1.y)
		# (b - a) runs toward +angle, (d - a) up: their cross points in, so wind a, d, c, b
		geo.tri(a, d, cc, "truss", surface, n0, n0, n1)
		geo.tri(a, cc, b, "truss", surface, n0, n1, n1)


## A pillar's flat end about c, n sides of radius r, at heights y(q), facing down.
static func _disc(geo: TmGeo, c: Vector2, n: int, r: float, y: Callable) -> void:
	var m := Vector3(c.x, y.call(c), c.y)
	for k in n:
		var p0 := c + Vector2(cos(TAU * k / n), sin(TAU * k / n)) * r
		var p1 := c + Vector2(cos(TAU * (k + 1) / n), sin(TAU * (k + 1) / n)) * r
		geo.tri(m, Vector3(p0.x, y.call(p0), p0.y), Vector3(p1.x, y.call(p1), p1.y), "truss", S_METAL)
