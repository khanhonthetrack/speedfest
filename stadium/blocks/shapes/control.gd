extends RefCounted
## Stadium "Control" blocks: the buildings that run along the stadium's tube network. RoadCamera is
## a camera gallery (a solid 8 m block with rounded roof edges and a ledge), RoadGlass a gallery
## with outward-leaning glass walls (ice surface), RoadPub a pipe with advertising screens. Our own
## geometry from measured numbers (TMNF block-local metres; see TmGeo).
##
## As with roads (road.gd), the measured cross-section is swept along the arms: straight, around the
## footprint corner (centre radius 16), revolved round the open corners of junctions; the lone base
## is a round pavilion (the section revolved about the block centre) and a dead end closes in a
## half round. Shape index: 0 base, 1 dead end (opens to +z), 2 corner (+z, -x), 3 straight,
## 4 T (adds -x), 5 cross. Ground variants stand on the terrain (nothing below 1 m).

const S_CONCRETE := 0
const S_ICE := 3
const S_METAL := 4
const S_ROAD := 16
const S_PIPE := 16

## Left halves of the cross-sections (x, y), from the bottom centre round the left wall to the
## roof centre; each point's material is the segment's from it.
const CAMERA_HALF := [
	[16.0, 0.0, "structure", S_CONCRETE], [3.11, 0.0, "control_panel", S_METAL], [3.11, 7.21, "control_panel", S_METAL],
	[3.15, 7.40, "control_panel", S_METAL], [3.33, 7.73, "control_panel", S_METAL], [3.71, 7.96, "control_panel", S_METAL],
	[4.0, 8.0, "truss", S_CONCRETE],
]
const GLASS_HALF := [
	[16.0, 0.0, "structure", S_CONCRETE], [4.0, 0.0, "control_panel", S_METAL], [4.0, 1.0, "glass_dark", S_ICE],
	[3.36, 2.54, "glass_dark", S_ICE], [1.42, 7.17, "control_panel", S_METAL], [2.07, 7.38, "control_panel", S_METAL],
	[4.0, 8.0, "truss", S_CONCRETE],
]
## Ground variants: a plinth over the whole cell (1 -> 2 m), the walls rising from it (the glass
## leaning inward), a low rail at the plinth's edge.
const CAMERA_GROUND_HALF := [
	[16.0, 1.0, "", TmGeo.NO_COLLISION], [0.0, 1.0, "structure", S_CONCRETE], [0.0, 1.5, "structure", S_CONCRETE],
	[0.49, 1.76, "structure", S_CONCRETE], [0.94, 2.0, "structure", S_ROAD], [3.11, 2.0, "control_panel", S_METAL],
	[3.11, 7.21, "control_panel", S_METAL], [3.15, 7.40, "control_panel", S_METAL], [3.33, 7.73, "control_panel", S_METAL],
	[3.71, 7.96, "control_panel", S_METAL], [4.0, 8.0, "truss", S_CONCRETE],
]
const GLASS_GROUND_HALF := [
	[16.0, 1.0, "", TmGeo.NO_COLLISION], [0.0, 1.0, "structure", S_CONCRETE], [0.0, 1.5, "structure", S_CONCRETE],
	[0.49, 1.76, "structure", S_CONCRETE], [0.94, 2.0, "structure", S_ROAD], [3.11, 2.0, "control_panel", S_METAL],
	[3.11, 3.36, "control_panel", S_METAL], [3.22, 3.58, "control_panel", S_METAL], [3.71, 3.7, "glass_dark", S_ICE],
	[3.11, 7.21, "control_panel", S_METAL], [3.15, 7.40, "control_panel", S_METAL], [3.33, 7.73, "control_panel", S_METAL],
	[3.71, 7.96, "control_panel", S_METAL], [4.0, 8.0, "truss", S_CONCRETE],
]
## The ledge along the walls (x0, x1, y0, y1); on the ground, the plinth's rail.
const CAMERA_LEDGE := [2.0, 3.11, 0.99, 1.99]
const GLASS_LEDGE := [2.0, 4.0, 1.0, 2.0]
const GROUND_RAIL := [0.94, 1.04, 2.0, 3.0]
const ROOF := 8.0
const WALL_ZONE := 6.0          ## the part of the section revolved round junction corners (x < this)

const ARMS := {
	"Base": [], "Deadend": [0], "Corner": [0, 1], "Straight": [0, 2], "TShaped": [0, 2, 1], "Cross": [0, 1, 2, 3],
}
const SIDES := [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)]

var _half: Array = CAMERA_HALF
var _ledge: Array = CAMERA_LEDGE
var _floor := 0.0


## The camera light rig (Control/CameraLight): its section (x, y), measured: a block 16 m wide and
## 8 m tall with feet, under a 1 m top bar reaching out to the spotlights; the straight piece is
## this section along z, the base its right half revolved about (16, 16).
const LIGHT := [[28.243, 7.0, "structure", S_METAL], [24.0, 7.0, "structure", S_METAL], [24.0, 1.0, "structure", S_METAL],
	[28.0, 1.0, "structure", S_METAL], [28.0, 0.0, "structure", S_METAL], [24.0, 0.0, "structure", S_METAL],
	[8.0, 0.0, "structure", S_METAL], [4.0, 0.0, "structure", S_METAL], [4.0, 1.0, "structure", S_METAL],
	[8.0, 1.0, "structure", S_METAL], [8.0, 7.0, "lamp", S_METAL], [3.757, 7.0, "structure", S_METAL],
	[3.879, 7.5, "structure", S_METAL], [4.0, 8.0, "glass_dark", S_METAL], [8.0, 8.0, "glass_dark", S_METAL],
	[24.0, 8.0, "glass_dark", S_METAL], [28.0, 8.0, "structure", S_METAL], [28.121, 7.5, "lamp", S_METAL]]
const LIGHT_HALF := [[16.0, 0.0, "structure", S_METAL], [24.0, 0.0, "structure", S_METAL], [28.0, 0.0, "structure", S_METAL],
	[28.0, 1.0, "structure", S_METAL], [24.0, 1.0, "structure", S_METAL], [24.0, 7.0, "lamp", S_METAL],
	[28.243, 7.0, "structure", S_METAL], [28.121, 7.5, "structure", S_METAL], [28.0, 8.0, "glass_dark", S_METAL],
	[24.0, 8.0, "glass_dark", S_METAL], [16.0, 8.0, "structure", S_METAL]]
## The camera pub (Control/CameraPub): a block with rounded top edges along z, a screen on each
## side (x0, x1 of the left one, y0, y1, z0, z1); on the ground it stands on a low plinth (measured).
const PUB := [[3.113, 0.0, "structure", S_METAL], [28.887, 0.0, "structure", S_METAL], [28.889, 7.207, "structure", S_METAL],
	[28.851, 7.396, "structure", S_METAL], [28.669, 7.729, "structure", S_METAL], [28.285, 7.965, "structure", S_METAL],
	[28.0, 8.0, "glass_dark", S_METAL], [4.0, 8.0, "structure", S_METAL], [3.715, 7.965, "structure", S_METAL],
	[3.331, 7.729, "structure", S_METAL], [3.149, 7.396, "structure", S_METAL], [3.111, 7.207, "structure", S_METAL]]
const PUB_GROUND := [[0.0, 1.0, "structure", S_METAL], [32.0, 1.0, "structure", S_METAL], [32.0, 1.5, "structure", S_METAL],
	[31.06, 2.0, "structure", S_METAL], [28.887, 2.0, "structure", S_METAL], [28.889, 7.207, "structure", S_METAL],
	[28.851, 7.396, "structure", S_METAL], [28.669, 7.729, "structure", S_METAL], [28.285, 7.965, "structure", S_METAL],
	[28.0, 8.0, "glass_dark", S_METAL], [4.0, 8.0, "structure", S_METAL], [3.715, 7.965, "structure", S_METAL],
	[3.331, 7.729, "structure", S_METAL], [3.149, 7.396, "structure", S_METAL], [3.111, 7.207, "structure", S_METAL],
	[3.113, 2.0, "structure", S_METAL], [0.942, 2.0, "structure", S_METAL], [0.0, 1.5, "structure", S_METAL]]
const PUB_SCREEN := [2.67, 3.113, 2.47, 6.81, 11.36, 20.64]


func handles(shape: String) -> bool:
	return shape.begins_with("Control/RoadCamera/") or shape.begins_with("Control/RoadGlass/") \
		or shape.begins_with("Control/RoadPub/") \
		or shape in ["Control/CameraLight/StraightAir", "Control/CameraLight/BaseAir", "Control/CameraPub/StraightAir",
			"Control/CameraPub/StraightGround"]


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	if shape.begins_with("Control/Camera"):
		return _camera_piece(shape)
	var parts := shape.split("/")
	var ground := parts[2].contains("Ground")
	var form := parts[2].trim_suffix("Ground").trim_suffix("Air")
	if not ARMS.has(form):
		return null
	var geo := TmGeo.new()
	_floor = 1.0 if ground else 0.0
	if parts[1] == "RoadPub":
		_pub(geo, ARMS[form])
		return geo.build()
	var glass := parts[1] == "RoadGlass"
	if ground:
		_half = GLASS_GROUND_HALF if glass else CAMERA_GROUND_HALF
		_ledge = GROUND_RAIL
	else:
		_half = GLASS_HALF if glass else CAMERA_HALF
		_ledge = GLASS_LEDGE if glass else CAMERA_LEDGE
	match form:
		"Straight":
			_along(geo, Vector3(16, 0, 0), Vector3(16, 0, 32))
		"Corner":
			_corner(geo)
		"Base":
			_revolve(geo, Vector3(16, 0, 16), 0.0, TAU, 24)
		"Deadend":
			_along(geo, Vector3(16, 0, 16), Vector3(16, 0, 32))
			# the half round toward -z: radial directions from +x through -z to -x
			_revolve(geo, Vector3(16, 0, 16), 0.0, -PI, 12)
		_:
			_junction(geo, ARMS[form])
	return geo.build()


## Camera lights and camera pubs: measured sections along z, or revolved (the light's base).
func _camera_piece(shape: String) -> Node3D:
	var geo := TmGeo.new()
	var along := func(table: Array) -> void:
		var sec := table.map(func(q: Array) -> Array: return [Vector2(q[0], q[1]), q[2], q[3]])
		geo.wall_sweep(sec, [Vector3(0, 0, 0), Vector3(0, 0, 32)], [Vector3(1, 0, 0), Vector3(1, 0, 0)], true, "structure", S_METAL)
	match shape:
		"Control/CameraLight/StraightAir":
			along.call(LIGHT)
		"Control/CameraLight/BaseAir":
			var sec := LIGHT_HALF.map(func(q: Array) -> Array: return [Vector2(float(q[0]) - 16.0, q[1]), q[2], q[3]])
			var path := []
			var outs := []
			for i in 33:
				var a := TAU * i / 32.0
				path.append(Vector3(16, 0, 16))
				outs.append(Vector3(cos(a), 0, sin(a)))
			geo.wall_sweep(sec, path, outs, false)
		"Control/CameraPub/StraightAir", "Control/CameraPub/StraightGround":
			along.call(PUB_GROUND if shape.ends_with("Ground") else PUB)
			var s: Array = PUB_SCREEN
			for x0: float in [s[0], 32.0 - s[1]]:
				geo.box(Vector3(x0, s[2], s[4]), Vector3(x0 + s[1] - s[0], s[3], s[5]), "screen", S_METAL, "", -2, 0.03)
	return geo.build()


## The closed section (d = x - 16, y); ground variants rest on the terrain.
func _section() -> Array:
	var out := []
	for q in _half:
		out.append([Vector2(float(q[0]) - 16.0, maxf(float(q[1]), _floor)), String(q[2]), int(q[3])])
	out.append([Vector2(0.0, ROOF), "truss", S_CONCRETE])
	for i in range(_half.size() - 1, 0, -1):
		var q: Array = _half[i]
		var prev: Array = _half[i - 1]
		out.append([Vector2(16.0 - float(q[0]), maxf(float(q[1]), _floor)), String(prev[2]), int(prev[3])])
	return out


## The wall part of the left half (x < WALL_ZONE), closed by an internal face; d = x from the edge.
func _wall_section() -> Array:
	var out := []
	for i in range(1, _half.size()):
		var q: Array = _half[i]
		out.append([Vector2(float(q[0]), maxf(float(q[1]), _floor)), String(q[2]), int(q[3])])
	out.append([Vector2(WALL_ZONE, ROOF), "", TmGeo.NO_COLLISION])
	out.append([Vector2(WALL_ZONE, _floor), "structure", S_CONCRETE])
	return out


func _ledge_section(mirror: bool) -> Array:
	var x0 := float(_ledge[0])
	var x1 := float(_ledge[1])
	var y0 := maxf(float(_ledge[2]), _floor)
	var y1 := float(_ledge[3])
	var pts := [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]
	var out := []
	for p in pts:
		out.append([Vector2((16.0 - p[0]) if mirror else (p[0] - 16.0), p[1]), "structure", S_METAL])
	return out


func _along(geo: TmGeo, a: Vector3, b: Vector3) -> void:
	var lat := Vector3(1, 0, 0)
	geo.wall_sweep(_section(), [a, b], [lat, lat], true, "control_panel", S_METAL)
	for mirror in [false, true]:
		geo.wall_sweep(_ledge_section(mirror), [a, b], [lat, lat], true, "structure", S_METAL)


## Around the footprint corner (0, 32): the section on a quarter circle of radius 16.
func _corner(geo: TmGeo) -> void:
	var path := []
	var lat := []
	for i in 13:
		var ang := lerpf(-PI * 0.5, 0.0, i / 12.0)
		var d := Vector3(cos(ang), 0.0, sin(ang))
		path.append(Vector3(0, 0, 32) + d * 16.0)
		lat.append(d)
	geo.wall_sweep(_section(), path, lat, true, "control_panel", S_METAL)
	for mirror in [false, true]:
		geo.wall_sweep(_ledge_section(mirror), path, lat, true, "structure", S_METAL)


## The section's half (wall side outward) revolved about c from angle a0 to a1 (radians, from +x
## toward +z): a round pavilion or a dead end's half round.
func _revolve(geo: TmGeo, c: Vector3, a0: float, a1: float, steps: int) -> void:
	var sec := []
	for q in _half:
		sec.append([Vector2(16.0 - float(q[0]), maxf(float(q[1]), _floor)), String(q[2]), int(q[3])])
	sec.append([Vector2(0.0, ROOF), "", TmGeo.NO_COLLISION])
	var led := []
	for p in [[_ledge[0], _ledge[2]], [_ledge[1], _ledge[2]], [_ledge[1], _ledge[3]], [_ledge[0], _ledge[3]]]:
		led.append([Vector2(16.0 - float(p[0]), maxf(float(p[1]), _floor)), "structure", S_METAL])
	var path := []
	var lat := []
	for i in steps + 1:
		var ang := lerpf(a0, a1, float(i) / steps)
		path.append(c)
		lat.append(Vector3(cos(ang), 0.0, sin(ang)))
	geo.wall_sweep(sec, path, lat, false)
	geo.wall_sweep(led, path, lat, false)


## T and cross: the solid block (its plan inset on the closed sides, with a quarter disc cut out at
## each block corner between two open sides), walls along the closed sides, and the wall revolved
## round each such corner (radius = the wall's distance from the edge).
func _junction(geo: TmGeo, arms: Array) -> void:
	var closed := []
	for i in 4:
		closed.append(not arms.has(i))
	var inset := func(i: int) -> float: return WALL_ZONE if closed[i] else 0.0
	var x0: float = inset.call(1)
	var x1: float = 32.0 - inset.call(3)
	var z0: float = inset.call(2)
	var z1: float = 32.0 - inset.call(0)
	var plan := PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])
	var wall := _wall_section()
	var c := Vector3(16, 0, 16)
	for i in 4:
		var o: Vector3 = SIDES[i]
		var t := Vector3(o.z, 0.0, -o.x)
		if closed[i]:
			geo.wall_sweep(wall, [c + o * 16.0 - t * 16.0, c + o * 16.0 + t * 16.0], [-o, -o], true, "control_panel", S_METAL)
		var j := SIDES.find(t)
		if not closed[i] and not closed[j]:
			var corner := c + o * 16.0 + t * 16.0
			var path := []
			var lat := []
			for s in 7:
				var ang := PI * 0.5 * s / 6.0
				lat.append((-t * cos(ang) - o * sin(ang)).normalized())
				path.append(corner)
			geo.wall_sweep(wall, path, lat, true, "control_panel", S_METAL)
			var disc := PackedVector2Array()
			for k in 24:
				disc.append(Vector2(corner.x, corner.z) + Vector2.from_angle(TAU * k / 24.0) * WALL_ZONE)
			var cut := Geometry2D.clip_polygons(plan, disc)
			if not cut.is_empty():
				plan = cut[0]
	var loop := []
	for p in plan:
		loop.append([p, "control_panel", S_METAL])
	geo.extrude_y(loop, _floor, ROOF, true, "truss", S_CONCRETE)


## RoadPub: a pipe along each arm (radius 1.422 at 4 m, like the tubes) over a central 8 m support
## block, with an advertising screen on each side of it (26 m along a straight); on the ground, a
## plinth under it all.
func _pub(geo: TmGeo, arms: Array) -> void:
	var c := Vector3(16, 4, 16)
	var dirs := arms.map(func(i: int) -> Vector3: return SIDES[i])
	for d: Vector3 in dirs:
		geo.pipe(c, c + d * 16.0, 1.422, 12, "pipe", S_PIPE)
	var top := 1.81 if _floor > 0.0 else 0.0
	geo.box(Vector3(12, maxf(top, _floor), 12), Vector3(20, ROOF, 20), "wall_dark", S_CONCRETE, "", -2, 0.05)
	var straight := arms.size() == 2 and arms.has(0) and arms.has(2)
	var runs := []          # [direction, t0, t1]: screens along the arms (t from the centre)
	if straight:
		runs.append([Vector3(0, 0, 1), -12.96, 12.96])
	else:
		for d: Vector3 in dirs:
			runs.append([d, 4.0, 12.96])
	var y0 := 1.29 if _floor > 0.0 else 0.58
	var y1 := 7.95 if _floor > 0.0 else 7.39
	for r in runs:
		var d: Vector3 = r[0]
		var side := Vector3(d.z, 0.0, -d.x)
		var a := Vector3(16, 0, 16) + d * float(r[1])
		var b := Vector3(16, 0, 16) + d * float(r[2])
		for k in [-1.0, 1.0]:
			var off: Vector3 = side * float(k) * 5.7
			var lo := Vector3(minf(a.x, b.x) + off.x - absf(side.x) * 0.3, y0, minf(a.z, b.z) + off.z - absf(side.z) * 0.3)
			var hi := Vector3(maxf(a.x, b.x) + off.x + absf(side.x) * 0.3, y1, maxf(a.z, b.z) + off.z + absf(side.z) * 0.3)
			geo.box(lo, hi, "screen", S_METAL, "", -2, 0.03)
		if _floor > 0.0:
			# the plinth under the screens and the pipe
			var w := side * 7.07
			var p0 := a - w
			var p1 := b + w
			geo.box(Vector3(minf(p0.x, p1.x), _floor, minf(p0.z, p1.z)), Vector3(maxf(p0.x, p1.x), 1.81, maxf(p0.z, p1.z)),
				"structure", S_CONCRETE, "structure", S_ROAD)
