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
## leaning inward), a low rail at the plinth's edge. As TMNF's booths: the plinth's rim a bluish
## grey (booth_rim), the walkway and walls white, a dark sill under the glass booth's glass, the
## roof grey along its edge (to 8 m in) and dark beyond, and a room behind the glass (GLASS_ROOM).
## The glass is TMNF's window modules (booth_glass: posts, mullion, transoms, see-through panes;
## the fifth column its rows, top 0).
const CAMERA_GROUND_HALF := [
	[16.0, 1.0, "", TmGeo.NO_COLLISION], [0.0, 1.0, "booth_rim", S_CONCRETE], [0.0, 1.5, "booth_rim", S_CONCRETE],
	[0.49, 1.76, "booth_rim", S_CONCRETE], [0.94, 2.0, "control_panel", S_ROAD], [3.11, 2.0, "control_panel", S_METAL],
	[3.11, 3.56, "glass_dark", S_METAL], [3.11, 4.79, "control_panel", S_METAL],
	[3.11, 7.21, "control_panel", S_METAL], [3.15, 7.40, "control_panel", S_METAL], [3.33, 7.73, "control_panel", S_METAL],
	[3.71, 7.96, "control_panel", S_METAL], [4.0, 8.0, "stands_top", S_CONCRETE], [8.0, 8.0, "truss", S_CONCRETE],
]
const GLASS_GROUND_HALF := [
	[16.0, 1.0, "", TmGeo.NO_COLLISION], [0.0, 1.0, "booth_rim", S_CONCRETE], [0.0, 1.5, "booth_rim", S_CONCRETE],
	[0.49, 1.76, "booth_rim", S_CONCRETE], [0.94, 2.0, "control_panel", S_ROAD], [3.11, 2.0, "control_panel", S_METAL],
	[3.11, 3.36, "control_panel", S_METAL], [3.22, 3.58, "stands_dark", S_METAL], [3.71, 3.7, "booth_glass", S_ICE, Vector2(512.0, 0.0)],
	[3.11, 7.21, "control_panel", S_METAL], [3.15, 7.40, "control_panel", S_METAL], [3.33, 7.73, "control_panel", S_METAL],
	[3.71, 7.96, "control_panel", S_METAL], [4.0, 8.0, "stands_top", S_CONCRETE], [8.0, 8.0, "stands_dark", S_CONCRETE],
]
## The glass booth's room (measured, TMNF's ControlInterior): its back wall, ceiling and floor as
## blocks (x0, x1 from the block edge, y0, y1, key; and the key of the face toward the glass: the
## wall's dark openings between light columns, booth_wall, its rows top to bottom). A y given as
## [at x0, at x1] slopes: the ceiling, a thin plate rising from the back wall's top to the glass's.
const GLASS_ROOM := [
	[7.34, 8.0, 2.0, 6.0, "stands_top", "booth_wall"], [3.11, 7.34, [7.11, 5.9], [7.21, 6.0], "control_under"],
	[3.6, 7.34, 1.9, 2.0, "control_panel"],
]
## The ground pavilion's room is split in four (TMNF's): thin walls from the back wall to the glass
## (TMNF x, z of the glass end, of the back end), double-sided light concrete, the room's height.
const GLASS_PARTITIONS := [
	[Vector2(4.0, 16.0), Vector2(7.34, 16.0)], [Vector2(28.0, 16.0), Vector2(24.66, 16.0)],
	[Vector2(16.0, 27.98), Vector2(15.15, 24.61)], [Vector2(16.0, 27.98), Vector2(16.85, 24.61)],
	[Vector2(16.0, 4.02), Vector2(15.15, 7.39)], [Vector2(16.0, 4.02), Vector2(16.85, 7.39)],
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
## the block between the feet dark top and bottom, the top bar's outer bevel its spotlights (our
## drawing, texgen/booth.py spots_nose: groups of four); along each outer side, four floodlight
## bars (LIGHT_BARS: x0, x1, y0, y1 of the left ones; z runs; their faces six pairs of lamps,
## spots_bank). The straight piece's steel as TMNF's (dark cut-out cards; the left side's, the
## right's mirrored): a W-truss panel over each bar (LIGHT_PANEL: x, y0, y1, z runs) under a rail
## (LIGHT_RAIL: x0, x1, y0, y1), held out by two trusses under the top bar (LIGHT_TRUSS: x0, x1,
## y0, y1, z runs) and one across each end (LIGHT_END_TRUSS: x0, y0, y1, z); a grating along the
## foot (LIGHT_WALK: x0, x1, y) with a railing at its edge (LIGHT_WALK_RAIL: x, y0, y1) and a
## lattice down from it to the foot's bottom.
const LIGHT_BARS := [1.04, 2.03, 2.88, 3.77]
const LIGHT_BAR_Z := [Vector2(0.51, 7.07), Vector2(9.0, 15.56), Vector2(16.44, 23.0), Vector2(24.93, 31.49)]
const LIGHT_PANEL := [1.55, 2.88, 6.0, [Vector2(0.13, 7.46), Vector2(8.62, 15.94), Vector2(16.06, 23.38), Vector2(24.55, 31.87)]]
const LIGHT_RAIL := [1.51, 1.66, 5.97, 6.14]
const LIGHT_TRUSS := [0.0, 8.0, 5.39, 7.0, [Vector2(7.49, 8.51), Vector2(23.49, 24.51)]]
const LIGHT_END_TRUSS := [1.51, 5.47, 6.11, 0.17]
const LIGHT_WALK := [2.0, 4.0, 1.0]
const LIGHT_WALK_RAIL := [2.0, 1.0, 2.0]
const LIGHT := [[28.243, 7.0, "control_under", S_METAL], [24.0, 7.0, "stands_dark", S_METAL], [24.0, 1.0, "stands_top", S_METAL],
	[28.0, 1.0, "stands_dark", S_METAL], [28.0, 0.0, "control_under", S_METAL], [24.0, 0.0, "stands_dark", S_METAL],
	[8.0, 0.0, "control_under", S_METAL], [4.0, 0.0, "stands_dark", S_METAL], [4.0, 1.0, "stands_top", S_METAL],
	[8.0, 1.0, "stands_dark", S_METAL], [8.0, 7.0, "control_under", S_METAL], [3.757, 7.0, "spots_nose", S_METAL, Vector2(512, 0)],
	[3.879, 7.5, "stands_dark", S_METAL], [4.0, 8.0, "stands_top", S_METAL], [8.0, 8.0, "stands_dark", S_METAL],
	[24.0, 8.0, "stands_top", S_METAL], [28.0, 8.0, "stands_dark", S_METAL], [28.121, 7.5, "spots_nose", S_METAL, Vector2(0, 512)]]
const LIGHT_HALF := [[16.0, 0.0, "stands_dark", S_METAL], [24.0, 0.0, "control_under", S_METAL], [28.0, 0.0, "stands_dark", S_METAL],
	[28.0, 1.0, "stands_top", S_METAL], [24.0, 1.0, "stands_dark", S_METAL], [24.0, 7.0, "control_under", S_METAL],
	[28.243, 7.0, "spots_nose", S_METAL, Vector2(512, 0)], [28.121, 7.5, "stands_dark", S_METAL], [28.0, 8.0, "stands_top", S_METAL],
	[24.0, 8.0, "stands_dark", S_METAL], [16.0, 8.0, "stands_dark", S_METAL]]
## The camera pub (Control/CameraPub): a block with rounded top edges along z (measured); on the
## ground it stands on a low plinth with a walkway along each side. TMNF's look: the long sides
## its facade (our drawing, texgen/booth.py pub_facade: rows of 512 from the facade's foot, 512,
## split 3.2 m up above the windows, 260.6, its top, 103, up the rounded edge to the roof, 0), the
## roof light along its edges (x 4..8, 24..28) and dark between, the ends dark panels; a screen on each
## side (PUB_SCREEN: x0, x1 of the left one, y0, y1, z0, z1) in a dark frame (PUB_SCREEN_FRAME:
## x0, x1, y0, y1, z0, z1) between two dark posts (PUB_POSTS: x0, x1, their z spans), an advert
## band under one end's windows on the ground (PUB_BAND: y0, y1, z0, z1), the walkway's railing
## (PUB_WALK_RAIL: x, y0, y1; a cut-out card). All given for the -x side; the +x side's turned
## round (x -> 32 - x, z -> 32 - z).
const PUB := [[3.113, 0.0, "structure", S_METAL], [28.887, 0.0, "stands_dark", S_METAL],
	[28.887, 1.0, "pub_facade", S_METAL, Vector2(512, 260.6)], [28.888, 4.2, "pub_facade", S_METAL, Vector2(260.6, 103)],
	[28.889, 7.207, "pub_facade", S_METAL, Vector2(103, 87.85)], [28.851, 7.396, "pub_facade", S_METAL, Vector2(87.85, 58.04)],
	[28.669, 7.729, "pub_facade", S_METAL, Vector2(58.04, 22.63)], [28.285, 7.965, "pub_facade", S_METAL, Vector2(22.63, 0)],
	[28.0, 8.0, "control_panel", S_METAL], [24.0, 8.0, "stands_dark", S_METAL], [8.0, 8.0, "control_panel", S_METAL],
	[4.0, 8.0, "pub_facade", S_METAL, Vector2(0, 22.63)], [3.715, 7.965, "pub_facade", S_METAL, Vector2(22.63, 58.04)],
	[3.331, 7.729, "pub_facade", S_METAL, Vector2(58.04, 87.85)], [3.149, 7.396, "pub_facade", S_METAL, Vector2(87.85, 103)],
	[3.111, 7.207, "pub_facade", S_METAL, Vector2(103, 260.6)], [3.112, 4.2, "pub_facade", S_METAL, Vector2(260.6, 512)],
	[3.113, 1.0, "stands_dark", S_METAL]]
const PUB_GROUND := [[0.0, 1.0, "structure", S_METAL], [32.0, 1.0, "stands_top", S_METAL], [32.0, 1.5, "stands_top", S_METAL],
	[31.06, 2.0, "stands_top", S_METAL], [28.887, 2.0, "pub_facade", S_METAL, Vector2(512, 260.6)],
	[28.888, 5.2, "pub_facade", S_METAL, Vector2(260.6, 103)], [28.889, 7.207, "pub_facade", S_METAL, Vector2(103, 87.85)],
	[28.851, 7.396, "pub_facade", S_METAL, Vector2(87.85, 58.04)], [28.669, 7.729, "pub_facade", S_METAL, Vector2(58.04, 22.63)],
	[28.285, 7.965, "pub_facade", S_METAL, Vector2(22.63, 0)], [28.0, 8.0, "control_panel", S_METAL],
	[24.0, 8.0, "stands_dark", S_METAL], [8.0, 8.0, "control_panel", S_METAL], [4.0, 8.0, "pub_facade", S_METAL, Vector2(0, 22.63)],
	[3.715, 7.965, "pub_facade", S_METAL, Vector2(22.63, 58.04)], [3.331, 7.729, "pub_facade", S_METAL, Vector2(58.04, 87.85)],
	[3.149, 7.396, "pub_facade", S_METAL, Vector2(87.85, 103)], [3.111, 7.207, "pub_facade", S_METAL, Vector2(103, 260.6)],
	[3.112, 5.2, "pub_facade", S_METAL, Vector2(260.6, 512)], [3.113, 2.0, "stands_top", S_METAL],
	[0.942, 2.0, "stands_top", S_METAL], [0.0, 1.5, "stands_top", S_METAL]]
const PUB_SCREEN := [2.67, 3.113, 2.47, 6.81, 11.36, 20.64]
const PUB_SCREEN_FRAME := [2.72, 3.11, 1.99, 7.17, 11.07, 20.93]
const PUB_POSTS := [2.66, 3.12, [Vector2(9.26, 9.72), Vector2(22.41, 22.87)]]
const PUB_BAND := [2.0, 3.56, 0.25, 8.36]
const PUB_WALK_RAIL := [0.94, 2.0, 3.0]


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
				if ground:
					_partitions(geo)
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
		var sec := table.map(func(q: Array) -> Array: return [Vector2(q[0], q[1]), q[2], q[3]] + q.slice(4))
		geo.wall_sweep(sec, [Vector3(0, 0, 0), Vector3(0, 0, 32)], [Vector3(1, 0, 0), Vector3(1, 0, 0)], true,
			"stands_dark" if table == LIGHT else "pub_end", S_METAL)
	match shape:
		"Control/CameraLight/StraightAir":
			along.call(LIGHT)
			var b: Array = LIGHT_BARS
			for z: Vector2 in LIGHT_BAR_Z:
				for right in [false, true]:
					var x0: float = 32.0 - float(b[1]) if right else float(b[0])
					var x1: float = 32.0 - float(b[0]) if right else float(b[1])
					geo.box(Vector3(x0, b[2], z.x), Vector3(x1, b[3], z.y), "stands_dark", S_METAL)
					# the lamps' face, outward (u along the bar, v down it)
					var xf: float = x1 + 0.01 if right else x0 - 0.01
					var q := [Vector3(xf, float(b[2]), z.x), Vector3(xf, float(b[3]), z.x), Vector3(xf, float(b[3]), z.y),
						Vector3(xf, float(b[2]), z.y)]
					var uv := [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
					if ((q[1] - q[0]) as Vector3).cross(q[2] - q[0]).x * (1.0 if right else -1.0) < 0.0:
						geo.quad_uv(q[0], q[3], q[2], q[1], "spots_bank", TmGeo.NO_COLLISION, uv[0], uv[3], uv[2], uv[1])
					else:
						geo.quad_uv(q[0], q[1], q[2], q[3], "spots_bank", TmGeo.NO_COLLISION, uv[0], uv[1], uv[2], uv[3])
			_light_steel(geo)
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
			var ground := shape.ends_with("Ground")
			along.call(PUB_GROUND if ground else PUB)
			var s: Array = PUB_SCREEN
			for i in 2:
				var x0: float = [s[0], 32.0 - s[1]][i]
				geo.screen_box(Vector3(x0, s[2], s[4]), Vector3(x0 + s[1] - s[0], s[3], s[5]), "screen", S_METAL, 0.03, i)
			_camera_pub_dress(geo, ground)
	return geo.build()


## The camera light's steel (LIGHT_PANEL ... LIGHT_WALK_RAIL), on both sides: dark cut-out cards.
func _light_steel(geo: TmGeo) -> void:
	var nz := TmGeo.NO_COLLISION
	for side in 2:
		var mx := func(x: float) -> float: return 32.0 - x if side == 1 else x
		var card := func(a: Vector3, b: Vector3, h: Vector3, key: String, u: float) -> void:
			# a card from the edge a -> b up (or across) by h: u along a -> b, v 0 at its far edge
			geo.quad_uv(a, b, b + h, a + h, key, nz, Vector2(0, 1), Vector2(u, 1), Vector2(u, 0), Vector2(0, 0))
		var pn: Array = LIGHT_PANEL
		var px: float = mx.call(pn[0])
		for z: Vector2 in pn[3]:
			card.call(Vector3(px, pn[1], z.x), Vector3(px, pn[1], z.y), Vector3(0, float(pn[2]) - float(pn[1]), 0), "railing",
				(z.y - z.x) / 8.0)
		var r: Array = LIGHT_RAIL
		geo.box(Vector3(minf(mx.call(r[0]), mx.call(r[1])), r[2], 0.0), Vector3(maxf(mx.call(r[0]), mx.call(r[1])), r[3], 32.0),
			"stands_dark", nz)
		var t: Array = LIGHT_TRUSS
		var x0: float = mx.call(t[0])
		var x1: float = mx.call(t[1])
		for z: Vector2 in t[4]:
			for zz: float in [z.x, z.y]:
				card.call(Vector3(x0, t[2], zz), Vector3(x1, t[2], zz), Vector3(0, float(t[3]) - float(t[2]), 0), "girder_dark",
					absf(x1 - x0) / 8.0)
			card.call(Vector3(x0, t[2], z.x), Vector3(x1, t[2], z.x), Vector3(0, 0, z.y - z.x), "grate", absf(x1 - x0))
		var e: Array = LIGHT_END_TRUSS
		for zz: float in [float(e[3]), 32.0 - float(e[3])]:
			card.call(Vector3(mx.call(e[0]), e[1], zz), Vector3(mx.call(8.0), e[1], zz), Vector3(0, float(e[2]) - float(e[1]), 0),
				"girder_dark", (8.0 - float(e[0])) / 8.0)
		var w: Array = LIGHT_WALK
		var wa: float = mx.call(w[0])
		var wb: float = mx.call(w[1])
		card.call(Vector3(wa, w[2], 0.0), Vector3(wa, w[2], 32.0), Vector3(wb - wa, 0, 0), "grate", 32.0)
		card.call(Vector3(wb, 0.0, 0.0), Vector3(wb, 0.0, 32.0), Vector3(wa - wb, float(w[2]), 0), "girder_dark", 4.0)
		var wr: Array = LIGHT_WALK_RAIL
		var rx: float = mx.call(wr[0])
		card.call(Vector3(rx, wr[1], 0.0), Vector3(rx, wr[1], 32.0), Vector3(0, float(wr[2]) - float(wr[1]), 0), "railing", 4.0)


## The camera pub's frames, posts, advert band and railing (PUB_*), on both sides.
func _camera_pub_dress(geo: TmGeo, ground: bool) -> void:
	var y0 := 2.0 if ground else 0.0
	for side in 2:
		var turn := func(p: Vector3) -> Vector3: return Vector3(32.0 - p.x, p.y, 32.0 - p.z) if side == 1 else p
		var bx := func(a: Vector3, b: Vector3) -> void:
			var p: Vector3 = turn.call(a)
			var q: Vector3 = turn.call(b)
			geo.box(Vector3(minf(p.x, q.x), p.y, minf(p.z, q.z)), Vector3(maxf(p.x, q.x), q.y, maxf(p.z, q.z)), "stands_dark", S_METAL)
		var f: Array = PUB_SCREEN_FRAME
		bx.call(Vector3(f[0], f[2], f[4]), Vector3(f[1], f[3], f[5]))
		for z: Vector2 in PUB_POSTS[2]:
			bx.call(Vector3(PUB_POSTS[0], y0, z.x), Vector3(PUB_POSTS[1], 8.0, z.y))
		if not ground:
			continue
		var b: Array = PUB_BAND
		var x := 3.113 - 0.01
		geo.screen_rect(turn.call(Vector3(x, b[0], b[2])), turn.call(Vector3(x, b[0], b[3])), turn.call(Vector3(x, b[1], b[3])),
			turn.call(Vector3(x, b[1], b[2])), "screen", TmGeo.NO_COLLISION, 2 + side, Vector3(-1, 0, 0) if side == 0 else Vector3(1, 0, 0),
			1.0)
		var r: Array = PUB_WALK_RAIL
		var p: Vector3 = turn.call(Vector3(r[0], r[1], 0.0))
		var q: Vector3 = turn.call(Vector3(r[0], r[1], 32.0))
		geo.quad_uv(p, q, q + Vector3(0, r[2] - r[1], 0), p + Vector3(0, r[2] - r[1], 0), "railing", TmGeo.NO_COLLISION,
			Vector2(0, 1), Vector2(4, 1), Vector2(4, 0), Vector2(0, 0))


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
		for p in _room_corners(r):
			sec.append([Vector2((16.0 - float(p[0])) if mirror else (float(p[0]) - 16.0), maxf(float(p[1]), _floor)),
				String(r[4]), TmGeo.NO_COLLISION])
		_room_face(sec, r)
		out.append(sec)
	return out


## A room block's corners (x from the block edge, y): its foot at x0, x1, its top at x1, x0 (a y
## given as [at x0, at x1] slopes; GLASS_ROOM).
static func _room_corners(r: Array) -> Array:
	var y := func(v: Variant, i: int) -> float: return float(v[i]) if v is Array else float(v)
	return [[r[0], y.call(r[2], 0)], [r[1], y.call(r[2], 1)], [r[1], y.call(r[3], 1)], [r[0], y.call(r[3], 0)]]


## The ground pavilion's partitions (GLASS_PARTITIONS): from the floor at the glass end up to the
## glass's top (further out) and down the back wall's height, seen from both sides.
func _partitions(geo: TmGeo) -> void:
	var back: Array = GLASS_ROOM[0]
	var top: Array = GLASS_GROUND_HALF[9]     # the glass's top (x from the edge, y)
	for w: Array in GLASS_PARTITIONS:
		var g: Vector2 = w[0]
		var b: Vector2 = w[1]
		var t := Vector2(16, 16) + (g - Vector2(16, 16)).normalized() * (16.0 - float(top[0]))
		var pts := [Vector3(g.x, back[2], g.y), Vector3(t.x, top[1], t.y), Vector3(b.x, back[3], b.y),
			Vector3(b.x, back[2], b.y)]
		for k in 2:
			for f: Array in [[0, 1, 2], [2, 3, 0]]:
				var i: Array = f if k == 0 else [f[0], f[2], f[1]]
				geo.tri(pts[i[0]], pts[i[1]], pts[i[2]], "stands_top", TmGeo.NO_COLLISION)


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
	# its ends dark where it stops (TMNF's; hidden against the next piece)
	geo.wall_sweep(_section(), [a, b], [lat, lat], true, "stands_dark", S_METAL)
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
	geo.wall_sweep(_section(), path, lat, true, "stands_dark", S_METAL)
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
		for p in _room_corners(r):
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
## of the centre, flush in a dark border frame, PUB_KIOSK_FRAME: its margins below, above and at
## the sides, the kiosk's dark box set back PUB_KIOSK_SET behind them, a lip over the gap); the
## block and the kiosk its dark Stands2; the plinth (PUB_PLINTH either side of the run) grey with
## a dark rubber top, a light strip down its middle (PUB_STRIP) and a railing (a cut-out card under
## its top bar, PUB_RAIL_H high) along each edge; the base's plinth runs along z (PUB_BASE_RUN
## either way), its railing round all four sides (PUB_BASE_RAIL in from its ends); a straight's
## boards sit in a dark frame, under a dark portal at each end on the ground.
const PUB_BOARD_W := 12.2
const PUB_GAP := 0.76
const PUB_BOARD_Y := {"ground": Vector2(1.92, 7.48), "air": Vector2(1.21, 6.92)}
const PUB_KIOSK := 6.48
const PUB_KIOSK_FRAME := [0.63, 0.47, 0.38]
const PUB_KIOSK_SET := 0.6
const PUB_PLINTH := 8.0
const PUB_STRIP := 4.9
const PUB_RAIL := 7.07
const PUB_BASE_RUN := 13.19
const PUB_BASE_RAIL := 0.93
const PUB_RAIL_H := 1.0
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
		var kin := PUB_KIOSK - PUB_KIOSK_SET
		geo.box(Vector3(16.0 - kin, maxf(top, _floor), 16.0 - kin), Vector3(16.0 + kin, ROOF, 16.0 + kin), "stands_dark",
			S_CONCRETE, "", -2, 0.05)
		var hw := PUB_BOARD_W * 0.5
		var fr: Array = PUB_KIOSK_FRAME
		var y_lo: float = by.x - float(fr[0])
		var y_hi: float = by.y + float(fr[1])
		var face := func(o: Vector3, d0: float, d1: float, t0: float, t1: float, y0: float, y1: float, key: String,
				board := 0) -> void:
			# a box on the kiosk's face toward o: d0..d1 out from the centre, t0..t1 along the face
			var t := Vector3(o.z, 0.0, -o.x)
			var a := Vector3(16, y0, 16) + o * d0 + t * t0
			var b := Vector3(16, y1, 16) + o * d1 + t * t1
			var lo := Vector3(minf(a.x, b.x), y0, minf(a.z, b.z))
			var hi := Vector3(maxf(a.x, b.x), y1, maxf(a.z, b.z))
			if key == "screen":
				geo.screen_box(lo, hi, key, S_METAL, 0.03, board)
			else:
				geo.box(lo, hi, key, S_METAL)
		for i in 4:
			var o: Vector3 = SIDES[i]
			var k := PUB_KIOSK
			face.call(o, k - 0.08, k, -hw, hw, by.x, by.y, "screen", first)
			first += 1
			face.call(o, k - 0.1, k, -k, k, y_lo, by.x, "stands_dark")
			face.call(o, k - 0.1, k, -k, k, by.y, y_hi, "stands_dark")
			for e: float in [-1.0, 1.0]:
				face.call(o, k - 0.1, k, e * hw, e * k, by.x, by.y, "stands_dark")
			# the lip on the frame, over the gap to the box (its corners on the x faces')
			var w := k if absf(o.x) > 0.5 else kin
			face.call(o, kin, k, -w, w, y_hi, y_hi + 0.05, "stands_dark")
		if _floor > 0.0:
			_pub_plinth(geo, Vector3(16, 0, 16 - PUB_BASE_RUN), Vector3(16, 0, 16 + PUB_BASE_RUN), Vector3(1, 0, 0),
				PUB_BASE_RAIL)
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
## rubber top inside the railing (a light rim outside it) with a light strip down its middle, the
## railing along each edge (inset > 0: from that far in from a and b, and across both ends).
func _pub_plinth(geo: TmGeo, a: Vector3, b: Vector3, side: Vector3, inset := 0.0) -> void:
	var run := (b - a).normalized()
	var ra := a + run * inset
	var rb := b - run * inset
	var box := func(p: Vector3, q: Vector3, w0: float, w1: float, top_key: String) -> void:
		var p0 := p + side * w0
		var p1 := q + side * w1
		geo.box(Vector3(minf(p0.x, p1.x), _floor, minf(p0.z, p1.z)), Vector3(maxf(p0.x, p1.x), 1.81, maxf(p0.z, p1.z)),
			"stands_top", S_ROAD, top_key, S_ROAD)
	# the rubber top inside the railing, TMNF's light rim outside it
	box.call(ra, rb, -PUB_RAIL, PUB_RAIL, "rubber_dark")
	for k: float in [-1.0, 1.0]:
		box.call(a, b, k * PUB_RAIL, k * PUB_PLINTH, "stands_top")
	if inset > 0.0:
		box.call(a, ra, -PUB_RAIL, PUB_RAIL, "stands_top")
		box.call(rb, b, -PUB_RAIL, PUB_RAIL, "stands_top")
	var s0 := ra - side * PUB_STRIP
	var s1 := rb + side * PUB_STRIP
	var lo := Vector3(minf(s0.x, s1.x), 1.812, minf(s0.z, s1.z))
	var hi := Vector3(maxf(s0.x, s1.x), 1.812, maxf(s0.z, s1.z))
	geo.quad(lo, Vector3(lo.x, lo.y, hi.z), hi, Vector3(hi.x, lo.y, lo.z), "control_panel", TmGeo.NO_COLLISION)
	var edges := [[ra + side * PUB_RAIL, rb + side * PUB_RAIL], [ra - side * PUB_RAIL, rb - side * PUB_RAIL]]
	if inset > 0.0:
		edges.append([ra - side * PUB_RAIL, ra + side * PUB_RAIL])
		edges.append([rb - side * PUB_RAIL, rb + side * PUB_RAIL])
	var y0 := 1.81
	var y1 := y0 + PUB_RAIL_H
	for e: Array in edges:
		var p: Vector3 = e[0]
		var q: Vector3 = e[1]
		var across := Vector3(absf((q - p).z), 0.0, absf((q - p).x)).normalized() * 0.05
		geo.box(Vector3(minf(p.x, q.x), y1 - 0.1, minf(p.z, q.z)) - across,
			Vector3(maxf(p.x, q.x), y1, maxf(p.z, q.z)) + across, "structure", S_METAL)
		var du := p.distance_to(q) / 8.0
		geo.quad_uv(Vector3(p.x, y0, p.z), Vector3(q.x, y0, q.z), Vector3(q.x, y1 - 0.1, q.z), Vector3(p.x, y1 - 0.1, p.z),
			"railing", TmGeo.NO_COLLISION, Vector2(0, 1), Vector2(du, 1), Vector2(du, 0.1), Vector2(0, 0.1))
