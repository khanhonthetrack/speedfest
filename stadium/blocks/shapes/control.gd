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
## As TMNF's: the camera gallery's white wall has a dark foot and a band of windows (1.56 to 2.79 m
## above its foot), the roof is grey along its edge (to 8 m in) and dark beyond (measured).
const CAMERA_HALF := [
	[16.0, 0.0, "stands_dark", S_CONCRETE], [3.11, 0.0, "stands_dark", S_METAL], [3.11, 1.0, "control_panel", S_METAL],
	[3.11, 2.56, "glass_dark", S_METAL], [3.11, 3.79, "control_panel", S_METAL], [3.11, 7.21, "control_panel", S_METAL],
	[3.15, 7.40, "control_panel", S_METAL], [3.33, 7.73, "control_panel", S_METAL], [3.71, 7.96, "control_panel", S_METAL],
	[4.0, 8.0, "stands_top", S_CONCRETE], [8.0, 8.0, "truss", S_CONCRETE],
]
const GLASS_HALF := [
	[16.0, 0.0, "structure", S_CONCRETE], [4.0, 0.0, "control_panel", S_METAL], [4.0, 1.0, "glass_booth", S_ICE],
	[3.36, 2.54, "glass_booth", S_ICE], [1.42, 7.17, "control_panel", S_METAL], [2.07, 7.38, "control_panel", S_METAL],
	[4.0, 8.0, "stands_top", S_CONCRETE], [8.0, 8.0, "stands_dark", S_CONCRETE],
]
## Ground variants: a plinth over the whole cell (1 -> 2 m), the walls rising from it (the glass
## leaning inward), a low rail at the plinth's edge. As TMNF's glass booth: the plinth grey, the
## walkway and walls white, a dark sill under the glass, the roof grey along its edge (to 8 m in)
## and dark beyond, and a room behind the glass (GLASS_ROOM). The glass is TMNF's window modules
## (booth_glass: posts, mullion, transoms, see-through panes; the fifth column its rows, top 0).
const CAMERA_GROUND_HALF := [
	[16.0, 1.0, "", TmGeo.NO_COLLISION], [0.0, 1.0, "stands_top", S_CONCRETE], [0.0, 1.5, "stands_top", S_CONCRETE],
	[0.49, 1.76, "stands_top", S_CONCRETE], [0.94, 2.0, "stands_top", S_ROAD], [3.11, 2.0, "control_panel", S_METAL],
	[3.11, 3.56, "glass_dark", S_METAL], [3.11, 4.79, "control_panel", S_METAL],
	[3.11, 7.21, "control_panel", S_METAL], [3.15, 7.40, "control_panel", S_METAL], [3.33, 7.73, "control_panel", S_METAL],
	[3.71, 7.96, "control_panel", S_METAL], [4.0, 8.0, "stands_top", S_CONCRETE], [8.0, 8.0, "truss", S_CONCRETE],
]
const GLASS_GROUND_HALF := [
	[16.0, 1.0, "", TmGeo.NO_COLLISION], [0.0, 1.0, "stands_top", S_CONCRETE], [0.0, 1.5, "stands_top", S_CONCRETE],
	[0.49, 1.76, "stands_top", S_CONCRETE], [0.94, 2.0, "control_panel", S_ROAD], [3.11, 2.0, "control_panel", S_METAL],
	[3.11, 3.36, "control_panel", S_METAL], [3.22, 3.58, "stands_dark", S_METAL], [3.71, 3.7, "booth_glass", S_ICE, Vector2(512.0, 0.0)],
	[3.11, 7.21, "control_panel", S_METAL], [3.15, 7.40, "control_panel", S_METAL], [3.33, 7.73, "control_panel", S_METAL],
	[3.71, 7.96, "control_panel", S_METAL], [4.0, 8.0, "stands_top", S_CONCRETE], [8.0, 8.0, "stands_dark", S_CONCRETE],
]
## The glass booth's room (measured, TMNF's ControlInterior): its back wall, ceiling and floor as
## blocks (x0, x1 from the block edge, y0, y1, key; and the key of the face toward the glass: the
## wall's our concrete panels with a dark opening, booth_wall, its rows top to bottom).
const GLASS_ROOM := [
	[7.34, 8.0, 2.0, 6.0, "stands_top", "booth_wall"], [3.3, 7.34, 6.0, 7.2, "control_under"],
	[3.6, 7.34, 1.9, 2.0, "control_panel"],
]
## The ledge along the walls (x0, x1, y0, y1); on the ground, the plinth's rail: TMNF's open
## railing 1 m high (its top bar, and a cut-out railing card under it: _rails).
const CAMERA_LEDGE := [2.0, 3.11, 0.99, 1.99]
const GLASS_LEDGE := [2.0, 4.0, 1.0, 2.0]
const GROUND_RAIL := [0.94, 1.04, 2.9, 3.0]
## The round camera booth on the ground (TMNF's, measured; _camera_base): either side of +-x an
## advert band under the windows (CAMERA_PUB: degrees either side; the wall's segment from the
## walkway up, CAMERA_PUB_ROW, a screen there) and no railing (CAMERA_RAIL_GAP: the entrances);
## either side of +-z a light gap in the window band (CAMERA_DOOR, the band's row CAMERA_DOOR_ROW).
const CAMERA_PUB := 28.0
const CAMERA_PUB_ROW := 5
const CAMERA_RAIL_GAP := 11.25
const CAMERA_DOOR := 1.42
const CAMERA_DOOR_ROW := 6
const ROOF := 8.0
const WALL_ZONE := 6.0          ## the part of the section revolved round junction corners (x < this)

const ARMS := {
	"Base": [], "Deadend": [0], "Corner": [0, 1], "Straight": [0, 2], "TShaped": [0, 2, 1], "Cross": [0, 1, 2, 3],
}
const SIDES := [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)]

var _half: Array = CAMERA_HALF
var _glass := false                 ## a glass booth (RoadGlass): its room behind the glass
var _ledge: Array = CAMERA_LEDGE
var _floor := 0.0


## The camera light rig (Control/CameraLight): its section (x, y), measured: a block 16 m wide and
## 8 m tall with feet, under a 1 m top bar reaching out to the spotlights; the straight piece is
## this section along z, the base its right half revolved about (16, 16). In TMNF's colours: dark
## (its Stands2), the feet and the top bar with grey tops (Stands) and light undersides (Auvent),
## the block between the feet dark top and bottom, the top bar's outer bevel its lit strip; along
## each outer side, four floodlight bars (LIGHT_BARS: x0, x1, y0, y1 of the left ones; z runs).
const LIGHT_BARS := [1.04, 2.03, 2.88, 3.77]
const LIGHT_BAR_Z := [Vector2(0.51, 7.07), Vector2(9.0, 15.56), Vector2(16.44, 23.0), Vector2(24.93, 31.49)]
const LIGHT := [[28.243, 7.0, "control_under", S_METAL], [24.0, 7.0, "stands_dark", S_METAL], [24.0, 1.0, "stands_top", S_METAL],
	[28.0, 1.0, "stands_dark", S_METAL], [28.0, 0.0, "control_under", S_METAL], [24.0, 0.0, "stands_dark", S_METAL],
	[8.0, 0.0, "control_under", S_METAL], [4.0, 0.0, "stands_dark", S_METAL], [4.0, 1.0, "stands_top", S_METAL],
	[8.0, 1.0, "stands_dark", S_METAL], [8.0, 7.0, "control_under", S_METAL], [3.757, 7.0, "lamp", S_METAL],
	[3.879, 7.5, "stands_dark", S_METAL], [4.0, 8.0, "stands_top", S_METAL], [8.0, 8.0, "stands_dark", S_METAL],
	[24.0, 8.0, "stands_top", S_METAL], [28.0, 8.0, "stands_dark", S_METAL], [28.121, 7.5, "lamp", S_METAL]]
const LIGHT_HALF := [[16.0, 0.0, "stands_dark", S_METAL], [24.0, 0.0, "control_under", S_METAL], [28.0, 0.0, "stands_dark", S_METAL],
	[28.0, 1.0, "stands_top", S_METAL], [24.0, 1.0, "stands_dark", S_METAL], [24.0, 7.0, "control_under", S_METAL],
	[28.243, 7.0, "lamp", S_METAL], [28.121, 7.5, "stands_dark", S_METAL], [28.0, 8.0, "stands_top", S_METAL],
	[24.0, 8.0, "stands_dark", S_METAL], [16.0, 8.0, "stands_dark", S_METAL]]
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
	_glass = glass
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
			if ground and not glass:
				_camera_base(geo)
			else:
				_revolve(geo, Vector3(16, 0, 16), 0.0, TAU, 32)
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
		geo.wall_sweep(sec, [Vector3(0, 0, 0), Vector3(0, 0, 32)], [Vector3(1, 0, 0), Vector3(1, 0, 0)], true,
			"stands_dark" if table == LIGHT else "structure", S_METAL)
	match shape:
		"Control/CameraLight/StraightAir":
			along.call(LIGHT)
			var b: Array = LIGHT_BARS
			for z: Vector2 in LIGHT_BAR_Z:
				for right in [false, true]:
					var x0: float = 32.0 - float(b[1]) if right else float(b[0])
					var x1: float = 32.0 - float(b[0]) if right else float(b[1])
					geo.box(Vector3(x0, b[2], z.x), Vector3(x1, b[3], z.y), "stands_dark", S_METAL)
					# the lamps' face, outward
					var xf: float = x1 + 0.01 if right else x0 - 0.01
					var q := [Vector3(xf, float(b[2]) + 0.12, z.x + 0.15), Vector3(xf, float(b[3]) - 0.12, z.x + 0.15),
						Vector3(xf, float(b[3]) - 0.12, z.y - 0.15), Vector3(xf, float(b[2]) + 0.12, z.y - 0.15)]
					if ((q[1] - q[0]) as Vector3).cross(q[2] - q[0]).x * (1.0 if right else -1.0) < 0.0:
						geo.quad(q[0], q[3], q[2], q[1], "lamp", TmGeo.NO_COLLISION)
					else:
						geo.quad(q[0], q[1], q[2], q[3], "lamp", TmGeo.NO_COLLISION)
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
			for i in 2:
				var x0: float = [s[0], 32.0 - s[1]][i]
				geo.screen_box(Vector3(x0, s[2], s[4]), Vector3(x0 + s[1] - s[0], s[3], s[5]), "screen", S_METAL, 0.03, i)
	return geo.build()


## The closed section (d = x - 16, y); ground variants rest on the terrain.
func _section() -> Array:
	var out := []
	for q in _half:
		out.append([Vector2(float(q[0]) - 16.0, maxf(float(q[1]), _floor)), String(q[2]), int(q[3])] + q.slice(4))
	out.append([Vector2(0.0, ROOF), String(_half[_half.size() - 1][2]), S_CONCRETE])
	for i in range(_half.size() - 1, 0, -1):
		var q: Array = _half[i]
		var prev: Array = _half[i - 1]
		var rows := [Vector2((prev[4] as Vector2).y, (prev[4] as Vector2).x)] if prev.size() > 4 else []
		out.append([Vector2(16.0 - float(q[0]), maxf(float(q[1]), _floor)), String(prev[2]), int(prev[3])] + rows)
	return out


## The glass booth's room blocks (GLASS_ROOM) as sections like the ledge's (none for the camera
## galleries).
func _rooms(mirror: bool) -> Array:
	var out := []
	if not _glass:
		return out
	for r: Array in GLASS_ROOM:
		var sec := []
		for p in [[r[0], r[2]], [r[1], r[2]], [r[1], r[3]], [r[0], r[3]]]:
			sec.append([Vector2((16.0 - float(p[0])) if mirror else (float(p[0]) - 16.0), maxf(float(p[1]), _floor)),
				String(r[4]), TmGeo.NO_COLLISION])
		_room_face(sec, r)
		out.append(sec)
	return out


## A room block's section: its face toward the glass (from its top corner down) the block's own key.
static func _room_face(sec: Array, r: Array) -> void:
	if r.size() > 5:
		sec[3] = [sec[3][0], String(r[5]), TmGeo.NO_COLLISION, Vector2(0.0, 512.0)]


## The wall part of the left half (x < WALL_ZONE), closed by an internal face; d = x from the edge.
func _wall_section() -> Array:
	var out := []
	for i in range(1, _half.size()):
		var q: Array = _half[i]
		out.append([Vector2(float(q[0]), maxf(float(q[1]), _floor)), String(q[2]), int(q[3])] + q.slice(4))
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
	_rails(geo, [a, b], [lat, lat], [float(_ledge[0]) - 16.0, 16.0 - float(_ledge[0])])
	for mirror in [false, true]:
		geo.wall_sweep(_ledge_section(mirror), [a, b], [lat, lat], true, "structure", S_METAL)
		for room: Array in _rooms(mirror):
			geo.wall_sweep(room, [a, b], [lat, lat], true, String(room[0][1]), TmGeo.NO_COLLISION)


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
	_rails(geo, path, lat, [float(_ledge[0]) - 16.0, 16.0 - float(_ledge[0])])
	for mirror in [false, true]:
		geo.wall_sweep(_ledge_section(mirror), path, lat, true, "structure", S_METAL)
		for room: Array in _rooms(mirror):
			geo.wall_sweep(room, path, lat, true, String(room[0][1]), TmGeo.NO_COLLISION)


## On the ground, the plinth's railing under its top bar (a cut-out card from the walkway up), along
## the path at each lateral distance in ds (as the sections' d).
func _rails(geo: TmGeo, path: Array, lat: Array, ds: Array) -> void:
	if _ledge != GROUND_RAIL:
		return
	var y0 := _floor + 1.0
	var h := float(GROUND_RAIL[2]) - y0
	for d: float in ds:
		var u := 0.0
		for i in path.size() - 1:
			var a: Vector3 = (path[i] as Vector3) + (lat[i] as Vector3) * d
			var b: Vector3 = (path[i + 1] as Vector3) + (lat[i + 1] as Vector3) * d
			var du := a.distance_to(b) / 8.0
			geo.quad_uv(Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z), Vector3(b.x, y0 + h, b.z), Vector3(a.x, y0 + h, a.z),
				"railing", TmGeo.NO_COLLISION, Vector2(u, 1), Vector2(u + du, 1), Vector2(u + du, 0), Vector2(u, 0))
			u += du


## The section's half (wall side outward) revolved about c from angle a0 to a1 (radians, from +x
## toward +z): a round pavilion or a dead end's half round.
func _revolve(geo: TmGeo, c: Vector3, a0: float, a1: float, steps: int, half: Array = [], rails := true) -> void:
	var sec := []
	for q in (_half if half.is_empty() else half):
		sec.append([Vector2(16.0 - float(q[0]), maxf(float(q[1]), _floor)), String(q[2]), int(q[3])] + q.slice(4))
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
	if rails:
		geo.wall_sweep(led, path, lat, false)
		_rails(geo, path, lat, [16.0 - float(_ledge[0])])
	for r: Array in (GLASS_ROOM if _glass else []):
		var room := []
		for p in [[r[0], r[2]], [r[1], r[2]], [r[1], r[3]], [r[0], r[3]]]:
			room.append([Vector2(16.0 - float(p[0]), maxf(float(p[1]), _floor)), String(r[4]), TmGeo.NO_COLLISION])
		_room_face(room, r)
		geo.wall_sweep(room, path, lat, false)


## The round camera booth on the ground (CAMERA_PUB, CAMERA_DOOR, CAMERA_RAIL_GAP): its section
## revolved in arcs, the advert bands and the window band's gaps where TMNF has them, the railing
## (top bar and card) on its two arcs between the entrances.
func _camera_base(geo: TmGeo) -> void:
	var c := Vector3(16, 0, 16)
	var pub := _half.duplicate(true)
	pub[CAMERA_PUB_ROW] = [pub[CAMERA_PUB_ROW][0], pub[CAMERA_PUB_ROW][1], "screen", S_METAL]
	var door := _half.duplicate(true)
	door[CAMERA_DOOR_ROW] = [door[CAMERA_DOOR_ROW][0], door[CAMERA_DOOR_ROW][1], "control_panel", S_METAL]
	# arcs from -CAMERA_PUB round the circle: [from, to (degrees), table]
	var p := CAMERA_PUB
	var d := CAMERA_DOOR
	var arcs := [[-p, p, pub], [p, 90.0 - d, _half], [90.0 - d, 90.0 + d, door], [90.0 + d, 180.0 - p, _half],
		[180.0 - p, 180.0 + p, pub], [180.0 + p, 270.0 - d, _half], [270.0 - d, 270.0 + d, door], [270.0 + d, 360.0 - p, _half]]
	for a: Array in arcs:
		var steps := maxi(1, roundi((float(a[1]) - float(a[0])) / 11.25))
		_revolve(geo, c, deg_to_rad(a[0]), deg_to_rad(a[1]), steps, a[2], false)
	var g := CAMERA_RAIL_GAP
	for a: Vector2 in [Vector2(g, 180.0 - g), Vector2(180.0 + g, 360.0 - g)]:
		_rail_arc(geo, c, deg_to_rad(a.x), deg_to_rad(a.y), roundi((a.y - a.x) / 11.25))


## The ground rail (its top bar and the railing card under it) on an arc about c (radians).
func _rail_arc(geo: TmGeo, c: Vector3, a0: float, a1: float, steps: int) -> void:
	var led := []
	for p in [[_ledge[0], _ledge[2]], [_ledge[1], _ledge[2]], [_ledge[1], _ledge[3]], [_ledge[0], _ledge[3]]]:
		led.append([Vector2(16.0 - float(p[0]), maxf(float(p[1]), _floor)), "structure", S_METAL])
	var path := []
	var lat := []
	for i in steps + 1:
		var ang := lerpf(a0, a1, float(i) / steps)
		path.append(c)
		lat.append(Vector3(cos(ang), 0.0, sin(ang)))
	geo.wall_sweep(led, path, lat, true, "structure", S_METAL)
	_rails(geo, path, lat, [16.0 - float(_ledge[0])])


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
## block, with advertising screens on each side of it; on the ground, a plinth under it all. As
## TMNF's (measured): the screens 2:1 boards PUB_BOARD_W long and PUB_BOARD_Y high, two side by side
## along a straight (PUB_GAP apart), one on each face of the lone base's kiosk (PUB_KIOSK either side
## of the centre); the block and the kiosk its dark Stands2; the plinth (PUB_PLINTH either side of
## the run) grey with a dark rubber top, a light strip down its middle (PUB_STRIP) and a railing's
## top bar along each edge (PUB_RAIL); the base's plinth runs along z (PUB_BASE_RUN either way);
## a straight's boards sit in a dark frame, under a dark portal at each end on the ground.
const PUB_BOARD_W := 12.2
const PUB_GAP := 0.76
const PUB_BOARD_Y := {"ground": Vector2(1.92, 7.48), "air": Vector2(1.21, 6.92)}
const PUB_KIOSK := 6.48
const PUB_PLINTH := 8.0
const PUB_STRIP := 4.9
const PUB_RAIL := 7.07
const PUB_BASE_RUN := 13.19
const PUB_FRAME := 0.25         ## the dark frame's margin round a straight's boards


func _pub(geo: TmGeo, arms: Array) -> void:
	var c := Vector3(16, 4, 16)
	var dirs := arms.map(func(i: int) -> Vector3: return SIDES[i])
	for d: Vector3 in dirs:
		geo.pipe(c, c + d * 16.0, 1.422, 12, "pillar", S_PIPE)
	var top := 1.81 if _floor > 0.0 else 0.0
	var by: Vector2 = PUB_BOARD_Y["ground" if _floor > 0.0 else "air"]
	var first := 0
	if arms.is_empty():
		# the lone base: a dark kiosk with a screen on each face, on a plinth along z
		var k0 := 16.0 - PUB_KIOSK
		var k1 := 16.0 + PUB_KIOSK
		geo.box(Vector3(k0, maxf(top, _floor), k0), Vector3(k1, ROOF, k1), "stands_dark", S_CONCRETE, "", -2, 0.05)
		var hw := PUB_BOARD_W * 0.5
		for i in 4:
			var o: Vector3 = SIDES[i]
			var t := Vector3(o.z, 0.0, -o.x)
			var a := Vector3(16, by.x, 16) + o * PUB_KIOSK - t * hw
			var b := Vector3(16, by.y, 16) + o * (PUB_KIOSK + 0.3) + t * hw
			geo.screen_box(Vector3(minf(a.x, b.x), by.x, minf(a.z, b.z)), Vector3(maxf(a.x, b.x), by.y, maxf(a.z, b.z)),
				"screen", S_METAL, 0.03, first)
			first += 1
		if _floor > 0.0:
			_pub_plinth(geo, Vector3(16, 0, 16 - PUB_BASE_RUN), Vector3(16, 0, 16 + PUB_BASE_RUN), Vector3(1, 0, 0))
		return
	geo.box(Vector3(12, maxf(top, _floor), 12), Vector3(20, ROOF, 20), "stands_dark", S_CONCRETE, "", -2, 0.05)
	var straight := arms.size() == 2 and arms.has(0) and arms.has(2)
	var runs := []          # [direction, t0, t1]: screens along the arms (t from the centre)
	if straight:
		runs.append([Vector3(0, 0, 1), -PUB_GAP * 0.5 - PUB_BOARD_W, -PUB_GAP * 0.5])
		runs.append([Vector3(0, 0, 1), PUB_GAP * 0.5, PUB_GAP * 0.5 + PUB_BOARD_W])
	else:
		for d: Vector3 in dirs:
			runs.append([d, 4.0, 12.96])
	for r in runs:
		var d: Vector3 = r[0]
		var side := Vector3(d.z, 0.0, -d.x)
		var a := Vector3(16, 0, 16) + d * float(r[1])
		var b := Vector3(16, 0, 16) + d * float(r[2])
		for k in [-1.0, 1.0]:
			var off: Vector3 = side * float(k) * 5.7
			var lo := Vector3(minf(a.x, b.x) + off.x - absf(side.x) * 0.3, by.x, minf(a.z, b.z) + off.z - absf(side.z) * 0.3)
			var hi := Vector3(maxf(a.x, b.x) + off.x + absf(side.x) * 0.3, by.y, maxf(a.z, b.z) + off.z + absf(side.z) * 0.3)
			geo.screen_box(lo, hi, "screen", S_METAL, 0.03, first)
			first += 1
	if straight:
		# TMNF's dark frame round each side's boards; on the ground, a portal over each end
		var z0 := 16.0 - PUB_GAP * 0.5 - PUB_BOARD_W - PUB_FRAME
		var z1 := 16.0 + PUB_GAP * 0.5 + PUB_BOARD_W + PUB_FRAME
		for x: float in [10.1, 21.5]:
			geo.box(Vector3(x, by.x - PUB_FRAME, z0), Vector3(x + 0.4, by.y + PUB_FRAME, z1), "stands_dark", S_METAL)
		if _floor > 0.0:
			for z: float in [0.0, 31.6]:
				for x: Vector2 in [Vector2(8.0, 10.5), Vector2(21.5, 24.0)]:
					geo.box(Vector3(x.x, 1.81, z), Vector3(x.y, ROOF, z + 0.4), "stands_dark", S_METAL)
				geo.box(Vector3(10.5, ROOF - 0.4, z), Vector3(21.5, ROOF, z + 0.4), "stands_dark", S_METAL)
	if _floor > 0.0:
		if straight:
			_pub_plinth(geo, Vector3(16, 0, 0), Vector3(16, 0, 32), Vector3(1, 0, 0))
		else:
			for d: Vector3 in dirs:
				_pub_plinth(geo, Vector3(16, 0, 16) + d * 4.0, Vector3(16, 0, 16) + d * 16.0, Vector3(d.z, 0.0, -d.x))


## The pub's plinth along a -> b (side: across it), from the ground to 1.81 m: grey sides, a dark
## rubber top with a light strip down its middle, the railing's top bar along each edge.
func _pub_plinth(geo: TmGeo, a: Vector3, b: Vector3, side: Vector3) -> void:
	var box := func(w0: float, w1: float, y0: float, y1: float, key: String, top_key: String, surface: int) -> void:
		var p0 := a + side * w0
		var p1 := b + side * w1
		geo.box(Vector3(minf(p0.x, p1.x), y0, minf(p0.z, p1.z)), Vector3(maxf(p0.x, p1.x), y1, maxf(p0.z, p1.z)),
			key, surface, top_key, surface)
	box.call(-PUB_PLINTH, PUB_PLINTH, _floor, 1.81, "stands_top", "rubber_dark", S_ROAD)
	var s0 := a - side * PUB_STRIP
	var s1 := b + side * PUB_STRIP
	var lo := Vector3(minf(s0.x, s1.x), 1.812, minf(s0.z, s1.z))
	var hi := Vector3(maxf(s0.x, s1.x), 1.812, maxf(s0.z, s1.z))
	geo.quad(lo, Vector3(lo.x, lo.y, hi.z), hi, Vector3(hi.x, lo.y, lo.z), "control_panel", TmGeo.NO_COLLISION)
	for k: float in [-1.0, 1.0]:
		box.call(k * PUB_RAIL - 0.05, k * PUB_RAIL + 0.05, 2.71, 2.81, "structure", "", S_METAL)
