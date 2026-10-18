extends RefCounted
## Stadium "Fabric" blocks: the grandstands under TMNF's white wave roofs. Our own geometry from
## measured numbers (TMNF block-local metres: x right, y up, z forward; see TmGeo).
##
## A straight grandstand is two cells deep (x 0..64): the stands (a block with a quarter-pipe front
## and a flat top at 8.26 m) and the roof shell, 0.3-0.4 m thick, rising from the ground in front of
## the stands and curving back over them to 48 m above the far cell's edge. The fabric is a road
## surface in TMNF (asphalt, 16): cars can drive on the roofs. Section tables are (x, y) along the
## block's z (measured: the same section at every z). Under the roof hang its truss arches (TRUSS).

const S_ROAD := 16
const S_STANDS := 0
const S_METAL := 4
const S_RUBBER := 9
const SculptShapes := preload("res://blocks/shapes/sculpt.gd")

## The roof's truss arches, hung under the shell along its underside from the foot to the top edge
## (measured on TMNF's visual mesh): light ones 1.45 m deep and 0.6 m thick at these z, the main one
## at z 16, 1.1 m thick, from 5 m deep at the foot to 4.4 m at the top; white chords, a dark lattice
## between them. Visual only (out of reach under the roof).
const TRUSS_LIGHT := [0.3, 12.5, 19.5, 31.7]
const TRUSS_MAIN := 16.0
const TRUSS_STEP := 3.5            ## lattice panel length along the arch (m)
## Advert boards (measured on TMNF's): two hung from the main truss facing the field, one on the
## back of the roof's foot facing out: [bottom edge (x, y), top edge (x, y), z0, z1, faces out
## (+x side)]. The hung ones are turned 3 deg steeper than TMNF's so the screens show adverts.
const BOARDS := [[Vector2(40.62, 27.5), Vector2(37.94, 30.56), 6.63, 15.74, false],
	[Vector2(40.62, 27.5), Vector2(37.94, 30.56), 16.28, 25.39, false],
	[Vector2(60.61, 2.43), Vector2(59.78, 7.79), 10.03, 22.23, true]]
const BOARDS_AIR := [[Vector2(38.38, 21.17), Vector2(35.7, 24.22), 6.63, 15.74, false],
	[Vector2(38.38, 21.17), Vector2(35.7, 24.22), 16.28, 25.39, false],
	[Vector2(56.22, 8.5), Vector2(54.97, 13.78), 10.02, 22.22, true]]

## The roof shell's closed section: its underside from the foot up to the top edge, then its top
## surface back down (measured, simplified to 5 cm).
const SHELL := [[59.8, 1.0, "fabric_under", S_ROAD], [59.42, 4.35, "fabric_under", S_ROAD], [58.7, 8.7, "fabric_under", S_ROAD],
	[57.55, 12.97, "fabric_under", S_ROAD], [55.9, 17.13, "fabric_under", S_ROAD], [53.8, 21.15, "fabric_under", S_ROAD],
	[51.27, 24.98, "fabric_under", S_ROAD], [48.33, 28.6, "fabric_under", S_ROAD], [45.04, 31.98, "fabric_under", S_ROAD],
	[41.47, 35.09, "fabric_under", S_ROAD], [37.64, 37.89, "fabric_under", S_ROAD], [33.59, 40.37, "fabric_under", S_ROAD],
	[29.34, 42.51, "fabric_under", S_ROAD], [24.91, 44.28, "fabric_under", S_ROAD], [20.27, 45.7, "fabric_under", S_ROAD],
	[15.4, 46.78, "fabric_under", S_ROAD], [10.34, 47.38, "fabric_under", S_ROAD], [5.13, 47.69, "fabric_under", S_ROAD],
	[0.0, 47.69, "structure", S_METAL], [0.0, 48.04, "fabric", S_ROAD], [5.15, 48.1, "fabric", S_ROAD],
	[10.37, 47.78, "fabric", S_ROAD], [15.46, 47.18, "fabric", S_ROAD], [20.37, 46.09, "fabric", S_ROAD],
	[25.04, 44.66, "fabric", S_ROAD], [29.5, 42.88, "fabric", S_ROAD], [33.78, 40.73, "fabric", S_ROAD],
	[37.86, 38.23, "fabric", S_ROAD], [41.72, 35.41, "fabric", S_ROAD], [45.32, 32.28, "fabric", S_ROAD],
	[48.63, 28.88, "fabric", S_ROAD], [51.59, 25.23, "fabric", S_ROAD], [54.14, 21.36, "fabric", S_ROAD],
	[56.26, 17.3, "fabric", S_ROAD], [57.93, 13.1, "fabric", S_ROAD], [59.09, 8.78, "fabric", S_ROAD],
	[59.82, 4.41, "fabric", S_ROAD], [60.04, 1.85, "fabric_under", S_ROAD]]
## The stands: the quarter-pipe from the floor up to the seats, the seats' top, the back down to
## the ground (measured).
const STANDS := [[45.88, 1.0, "platform", S_ROAD], [47.08, 1.2, "platform", S_ROAD], [48.23, 1.56, "platform", S_ROAD],
	[49.28, 2.15, "platform", S_ROAD], [50.21, 2.93, "platform", S_ROAD], [50.97, 3.9, "platform", S_ROAD],
	[51.54, 4.99, "platform", S_ROAD], [51.89, 6.18, "platform", S_ROAD], [52.0, 7.42, "structure", S_ROAD],
	[52.0, 7.9, "structure", S_ROAD], [52.93, 8.26, "stands", S_STANDS], [57.34, 8.26, "structure", S_ROAD],
	[57.48, 7.42, "stands", S_STANDS], [58.03, 4.21, "stands", S_STANDS], [58.41, 1.0, "structure", S_STANDS]]


## The low rubber lip along the shell's foot, on the ground (measured).
const LIP := [[59.706, 1.0, "rubber", S_RUBBER], [59.706, 1.841, "rubber", S_RUBBER], [60.043, 1.841, "structure", S_ROAD],
	[60.943, 1.542, "structure", S_ROAD], [60.971, 1.519, "structure", S_ROAD], [60.971, 1.0, "structure", S_ROAD]]
## The raised grandstand (FabricStraight1x1Air): its own, shorter shell standing on a deck at 8 m
## (top surface down from the foot, then the underside), the deck (x, y0, y1) and the one wall
## holding it up along the block (x0, x1), measured.
const SHELL_AIR := [[55.77, 7.99, "fabric", S_ROAD], [54.62, 12.83, "fabric", S_ROAD], [53.04, 17.04, "fabric", S_ROAD],
	[51.04, 21.09, "fabric", S_ROAD], [48.64, 24.96, "fabric", S_ROAD], [45.85, 28.61, "fabric", S_ROAD],
	[42.73, 32.01, "fabric", S_ROAD], [39.33, 35.14, "fabric", S_ROAD], [35.7, 37.96, "fabric", S_ROAD],
	[31.85, 40.46, "fabric", S_ROAD], [27.81, 42.61, "fabric", S_ROAD], [23.61, 44.4, "fabric", S_ROAD],
	[19.21, 45.83, "fabric", S_ROAD], [14.58, 46.91, "fabric", S_ROAD], [9.78, 47.51, "fabric", S_ROAD],
	[4.85, 47.81, "fabric", S_ROAD], [0.0, 47.98, "structure", S_METAL], [0.0, 47.63, "fabric_under", S_ROAD],
	[9.75, 47.11, "fabric_under", S_ROAD], [14.52, 46.51, "fabric_under", S_ROAD], [19.11, 45.43, "fabric_under", S_ROAD],
	[23.48, 44.01, "fabric_under", S_ROAD], [27.66, 42.24, "fabric_under", S_ROAD], [31.67, 40.1, "fabric_under", S_ROAD],
	[35.49, 37.62, "fabric_under", S_ROAD], [39.1, 34.82, "fabric_under", S_ROAD], [42.47, 31.71, "fabric_under", S_ROAD],
	[45.57, 28.33, "fabric_under", S_ROAD], [48.34, 24.71, "fabric_under", S_ROAD], [50.72, 20.88, "fabric_under", S_ROAD],
	[52.7, 16.86, "fabric_under", S_ROAD], [54.26, 12.7, "fabric_under", S_ROAD], [55.4, 7.99, "fabric_under", S_ROAD]]
const DECK_AIR := [47.93, 60.13, 7.61, 8.0]
const WALL_AIR := [53.76, 54.28]
## Under a raised grandstand: on the ground, a one-cell stands block (quarter-pipe front, seats at
## 8 m, the roof's fabric foot behind, the big screen on its back: x0, x1, y0, y1, z0, z1); higher
## up, the fabric wall carrying the roof down (x0, x1) with a post in the middle (x0, x1, z0, z1).
const PILLAR_STANDS := [[10.85, 1.0, "platform", S_ROAD], [12.04, 1.2, "platform", S_ROAD], [13.19, 1.56, "platform", S_ROAD],
	[14.25, 2.15, "platform", S_ROAD], [15.18, 2.93, "platform", S_ROAD], [15.94, 3.9, "platform", S_ROAD],
	[16.5, 4.99, "platform", S_ROAD], [16.85, 6.18, "platform", S_ROAD], [16.97, 7.16, "structure", S_ROAD],
	[17.0, 7.7, "structure", S_ROAD], [17.9, 8.0, "stands", S_STANDS], [26.56, 8.0, "structure", S_ROAD],
	[26.56, 7.16, "fabric", S_ROAD], [26.94, 7.16, "fabric", S_ROAD], [26.94, 1.83, "structure", S_ROAD],
	[27.76, 1.52, "structure", S_ROAD], [27.76, 1.0, "structure", S_ROAD]]
const PILLAR_SCREEN := [26.94, 27.44, 1.84, 6.07, 2.11, 30.18]
const PILLAR_WALL := [25.725, 26.107]
const PILLAR_POST := [21.43, 22.61, 15.51, 16.51]
## Cross1x1: a flat fabric roof over the cell (underside, top), on trusses (not recreated yet).
const CROSS_ROOF := [7.7, 7.98]
## Corners (2 x 2 cells): the straight's sections revolved through 90 deg in CORNER_STEPS segments
## (measured: the radial sections are the straight's). In: about (0, 0), the section's x being the
## distance from it. Out: about (64, 0), the distance being 64 - x, and the rest of the footprint
## (beyond 64 m from that corner) roofed flat at the shell's top (ROOF_TOP: underside, top).
## The Out pillar corner: a square truss post (x0, x1, z0, z1), 24 m, open like TMNF's posts.
const PILLAR_OUT_POST := [22.55, 28.11, 3.9, 9.45]
## Cross3x3: the flat roof over 3 x 3 cells (underside, top) with a round opening (centre (48, 48),
## radius), a tilted fabric canopy over it (its top line (x, y) along z CANOPY_Z, CANOPY_T thick)
## and advert boards round the base (x0, x1, z0, z1; 0.17..2.67 m), measured. Cross3x3Screen: the
## same 32 m higher (CROSS_SCREEN_LIFT) with the big screen hanging under it (lofted:
## blocks/data/sculpt_lofts.json "Fabric/FabricCross3x3Screen#screen").
const CROSS3_HOLE := 35.21
const CANOPY := [Vector2(0.0, 16.0), Vector2(18.05, 15.75), Vector2(33.03, 15.08), Vector2(48.89, 13.88), Vector2(64.72, 12.49),
	Vector2(80.28, 11.78), Vector2(85.41, 11.89), Vector2(90.64, 12.22), Vector2(96.0, 12.85)]
const CANOPY_Z := [17.24, 78.88]
const CANOPY_T := 0.36
const CROSS3_BOARDS := [[21.14, 27.03, 15.93, 15.99], [69.03, 74.92, 15.93, 15.99], [21.14, 27.03, 79.95, 80.02],
	[69.03, 74.92, 79.95, 80.02], [15.96, 16.02, 35.79, 41.68], [15.95, 16.02, 45.21, 50.8], [15.96, 16.02, 54.3, 60.2],
	[79.95, 80.01, 35.79, 41.68], [79.94, 80.0, 45.21, 50.8], [79.95, 80.01, 54.3, 60.2]]
const CROSS_SCREEN_LIFT := 32.0
const CORNER_STEPS := 18
const ROOF_TOP := [47.69, 48.04]
const ROOF_TOP_AIR := [47.63, 47.98]
## The raised In corner has a shell of its own reaching down to 1.5 m (top surface up from the
## foot, then the underside down; radius from (0, 0)), on a low deck and its base (radius r0..r1,
## y0..y1), measured.
const SHELL_IN_AIR := [[56.56, 1.54, "fabric", S_ROAD], [56.33, 3.73, "fabric", S_ROAD], [55.65, 8.14, "fabric", S_ROAD],
	[54.58, 12.41, "fabric", S_ROAD], [53.02, 16.64, "fabric", S_ROAD], [51.04, 20.73, "fabric", S_ROAD],
	[48.66, 24.63, "fabric", S_ROAD], [45.89, 28.31, "fabric", S_ROAD], [42.78, 31.74, "fabric", S_ROAD],
	[39.36, 34.91, "fabric", S_ROAD], [35.71, 37.76, "fabric", S_ROAD], [31.86, 40.28, "fabric", S_ROAD],
	[27.83, 42.45, "fabric", S_ROAD], [23.64, 44.25, "fabric", S_ROAD], [19.25, 45.7, "fabric", S_ROAD],
	[14.6, 46.81, "fabric", S_ROAD], [9.77, 47.42, "fabric", S_ROAD], [4.69, 47.68, "fabric", S_ROAD],
	[0.4, 47.68, "structure", S_METAL], [0.4, 47.57, "fabric_under", S_ROAD], [4.67, 47.57, "fabric_under", S_ROAD],
	[9.63, 47.32, "fabric_under", S_ROAD], [14.44, 46.72, "fabric_under", S_ROAD], [19.09, 45.62, "fabric_under", S_ROAD],
	[23.46, 44.19, "fabric_under", S_ROAD], [27.56, 42.44, "fabric_under", S_ROAD], [31.63, 40.26, "fabric_under", S_ROAD],
	[35.4, 37.79, "fabric_under", S_ROAD], [39.09, 34.93, "fabric_under", S_ROAD], [42.42, 31.85, "fabric_under", S_ROAD],
	[45.52, 28.45, "fabric_under", S_ROAD], [48.26, 24.83, "fabric_under", S_ROAD], [50.64, 20.96, "fabric_under", S_ROAD],
	[52.62, 16.92, "fabric_under", S_ROAD], [54.17, 12.73, "fabric_under", S_ROAD], [55.26, 8.43, "fabric_under", S_ROAD],
	[55.95, 4.05, "fabric_under", S_ROAD], [56.19, 1.84, "fabric_under", S_ROAD]]
const DECK_IN_AIR := [47.99, 61.84, 1.46, 1.84]
## The In pillar corners' arcs: centre (c, c) and segments (see _arc_in).
const PILLAR_ARC_C := 5.533
const PILLAR_ARC_STEPS := 17
const BASE_IN_AIR := [48.73, 61.04, 0.0, 1.46]


func handles(shape: String) -> bool:
	return shape in ["Fabric/FabricStraight1x1", "Fabric/FabricStraight1x1Air", "Fabric/FabricPillarGround",
		"Fabric/FabricPillarAir", "Fabric/FabricCross1x1", "Fabric/FabricCornerIn", "Fabric/FabricCornerInAir",
		"Fabric/FabricCornerOut", "Fabric/FabricCornerOutAir", "Fabric/FabricPillarCornerInAir",
		"Fabric/FabricPillarCornerInGround", "Fabric/FabricPillarCornerOutGround", "Fabric/FabricPillarCornerOutAir",
		"Fabric/FabricCross3x3", "Fabric/FabricCross3x3Screen"]


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var geo := TmGeo.new()
	match shape:
		"Fabric/FabricStraight1x1":
			_extrude(geo, SHELL)
			_extrude(geo, STANDS)
			_extrude(geo, LIP)
			_trusses(geo, SHELL)
			_boards(geo, BOARDS)
		"Fabric/FabricStraight1x1Air":
			_extrude(geo, SHELL_AIR)
			_trusses(geo, SHELL_AIR)
			_boards(geo, BOARDS_AIR)
			geo.box(Vector3(DECK_AIR[0], DECK_AIR[2], 0), Vector3(DECK_AIR[1], DECK_AIR[3], 32), "structure", S_METAL,
				"stands", S_STANDS)
			geo.box(Vector3(WALL_AIR[0], 0, 0), Vector3(WALL_AIR[1], DECK_AIR[2], 32), "structure", S_METAL)
		"Fabric/FabricPillarGround":
			_extrude(geo, PILLAR_STANDS)
			var s: Array = PILLAR_SCREEN
			geo.box(Vector3(s[0], s[2], s[4]), Vector3(s[1], s[3], s[5]), "screen", S_METAL, "", -2, 0.03)
		"Fabric/FabricPillarAir":
			geo.box(Vector3(PILLAR_WALL[0], 0, 0), Vector3(PILLAR_WALL[1], 24, 32), "fabric", S_ROAD)
			_open_post(geo, Vector3(PILLAR_POST[0], 0, PILLAR_POST[2]), Vector3(PILLAR_POST[1], 24, PILLAR_POST[3]))
		"Fabric/FabricCross1x1":
			geo.box(Vector3(0, CROSS_ROOF[0], 0), Vector3(32, CROSS_ROOF[1], 32), "structure", S_ROAD, "fabric", S_ROAD)
		"Fabric/FabricCornerIn", "Fabric/FabricCornerOut", "Fabric/FabricCornerInAir", "Fabric/FabricCornerOutAir":
			var out := shape.contains("Out")
			var air := shape.ends_with("Air")
			var c := Vector2(64, 0) if out else Vector2.ZERO
			var a0 := 90.0 if out else 0.0
			var flip := 64.0 if out else -1.0
			if air and not out:
				_revolve(geo, SHELL_IN_AIR, c, a0, flip)
				var d: Array = DECK_IN_AIR
				var b: Array = BASE_IN_AIR
				_revolve(geo, _band(d[0], d[1], d[2], d[3], "stands", S_STANDS), c, a0, flip)
				_revolve(geo, _band(b[0], b[1], b[2], b[3], "structure", S_METAL), c, a0, flip)
			elif air:
				_revolve(geo, SHELL_AIR, c, a0, flip)
				_revolve(geo, _band(DECK_AIR[0], DECK_AIR[1], DECK_AIR[2], DECK_AIR[3], "stands", S_STANDS), c, a0, flip)
				_revolve(geo, _band(WALL_AIR[0], WALL_AIR[1], 0.0, DECK_AIR[2], "structure", S_METAL), c, a0, flip)
			else:
				_revolve(geo, SHELL, c, a0, flip)
				_revolve(geo, STANDS, c, a0, flip)
				_revolve(geo, LIP, c, a0, flip)
			if out:
				_flat_roof(geo, ROOF_TOP_AIR if air else ROOF_TOP)
		"Fabric/FabricPillarCornerInAir":
			# the pillar's fabric wall round the In corner: in the far cells, 32 m further out
			_arc_in(geo, _band(PILLAR_WALL[0] + 32.0, PILLAR_WALL[1] + 32.0, 0.0, 24.0, "fabric", S_ROAD))
		"Fabric/FabricPillarCornerInGround":
			_arc_in(geo, _shift(PILLAR_STANDS, 32.0))
		"Fabric/FabricPillarCornerOutGround":
			_revolve(geo, PILLAR_STANDS, Vector2(32, 0), 90.0, 32.0)
		"Fabric/FabricPillarCornerOutAir":
			var p: Array = PILLAR_OUT_POST
			_open_post(geo, Vector3(p[0], 0, p[2]), Vector3(p[1], 24, p[3]))
		"Fabric/FabricCross3x3", "Fabric/FabricCross3x3Screen":
			var lift := CROSS_SCREEN_LIFT if shape.ends_with("Screen") else 0.0
			_cross3(geo, lift)
			if lift > 0.0:
				var sculpt := SculptShapes.new()
				for tube: Dictionary in SculptShapes.lofts().get(shape + "#screen", []):
					sculpt._tube(geo, tube, "screen", S_METAL)
		_:
			return null
	return geo.build()


## A section table revolved about the vertical axis through c (x, z) from angle a0 through 90 deg
## (degrees from +x toward +z); flip > 0: the radius is flip - x (else x).
func _revolve(geo: TmGeo, table: Array, c: Vector2, a0: float, flip: float) -> void:
	var sec := table.map(func(q: Array) -> Array:
		return [Vector2(flip - float(q[0]) if flip > 0.0 else float(q[0]), float(q[1])), q[2], q[3]])
	var path := []
	var outs := []
	for i in CORNER_STEPS + 1:
		var a := deg_to_rad(a0 + 90.0 * float(i) / CORNER_STEPS)
		path.append(Vector3(c.x, 0, c.y))
		outs.append(Vector3(cos(a), 0, sin(a)))
	geo.wall_sweep(sec, path, outs, true, "structure", S_METAL)


## The In pillar corners: each point of the section (its x = the distance from the block's edge
## where the straight piece meets it) runs round an arc about (PILLAR_ARC_C, PILLAR_ARC_C) that
## meets both edges at that distance (measured: the fabric wall's line is such an arc, 17 even
## steps over a little more than 90 deg).
func _arc_in(geo: TmGeo, table: Array) -> void:
	var loop := table.map(func(q: Array) -> Array: return [Vector2(q[0], q[1]), q[2], q[3]])
	if TmGeo.loop_area(loop) < 0.0:
		loop = TmGeo.reversed_loop(loop)
	var c := PILLAR_ARC_C
	var at := func(p: Vector2, t: float) -> Vector3:
		var r := sqrt((p.x - c) * (p.x - c) + c * c)
		var a := asin(c / r)
		var phi := -a + t * (PI * 0.5 + 2.0 * a)
		return Vector3(c + r * cos(phi), p.y, c + r * sin(phi))
	var n := PILLAR_ARC_STEPS
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		for k in loop.size():
			var p: Vector2 = loop[k][0]
			var q: Vector2 = loop[(k + 1) % loop.size()][0]
			geo.quad(at.call(p, t0), at.call(q, t0), at.call(q, t1), at.call(p, t1), loop[k][1], loop[k][2])
	# the ends, on the block's edges
	var pe := PackedVector2Array()
	for q in loop:
		pe.append(q[0])
	for t: float in [0.0, 1.0]:
		var idx := Geometry2D.triangulate_polygon(pe)
		for j in range(0, idx.size(), 3):
			var a: Vector3 = at.call(pe[idx[j]], t)
			var b: Vector3 = at.call(pe[idx[j + 1]], t)
			var d: Vector3 = at.call(pe[idx[j + 2]], t)
			if t == 0.0:
				geo.tri(a, d, b, "structure", S_METAL)
			else:
				geo.tri(a, b, d, "structure", S_METAL)


## The 3 x 3 roof (lifted by lift): the plate round its opening (four quarters), the canopy, and
## the advert boards on the ground under it.
func _cross3(geo: TmGeo, lift: float) -> void:
	var c := Vector2(48, 48)
	for q in 4:
		var a0 := PI * 0.5 * q
		var poly := PackedVector2Array()
		var steps := 12
		for i in steps + 1:
			var a := a0 + PI * 0.5 * float(i) / steps
			poly.append(c + Vector2(cos(a), sin(a)) * CROSS3_HOLE)
		# out to the block's edges: the corner of this quarter
		var d1 := Vector2(cos(a0 + PI * 0.5), sin(a0 + PI * 0.5))
		var d0 := Vector2(cos(a0), sin(a0))
		poly.append(c + d1 * 48.0)
		poly.append(c + (d0 + d1) * 48.0)
		poly.append(c + d0 * 48.0)
		var loop := []
		for p in poly:
			loop.append([p, "structure", S_ROAD])
		geo.extrude_y(loop, CROSS_ROOF[0] + lift, CROSS_ROOF[1] + lift, true, "fabric", S_ROAD)
	var sec := []
	for p: Vector2 in CANOPY:
		sec.append([Vector2(p.x, p.y + lift), "fabric", S_ROAD])
	for i in range(CANOPY.size() - 1, -1, -1):
		var p: Vector2 = CANOPY[i]
		sec.append([Vector2(p.x, p.y + lift - CANOPY_T), "structure", S_ROAD])
	geo.wall_sweep(sec, [Vector3(0, 0, CANOPY_Z[0]), Vector3(0, 0, CANOPY_Z[1])], [Vector3(1, 0, 0), Vector3(1, 0, 0)],
		true, "structure", S_ROAD)
	for b: Array in CROSS3_BOARDS:
		geo.box(Vector3(b[0], 0.17 + lift, b[2]), Vector3(b[1], 2.67 + lift, b[3]), "screen", S_METAL, "", -2, 0.03)


## A section table moved along x.
static func _shift(table: Array, dx: float) -> Array:
	return table.map(func(q: Array) -> Array: return [float(q[0]) + dx, q[1], q[2], q[3]])


## A rectangle (x0..x1, y0..y1) as a section table.
static func _band(x0: float, x1: float, y0: float, y1: float, top_mat: String, top_surface: int) -> Array:
	return [[x0, y0, "structure", S_METAL], [x1, y0, "structure", S_METAL], [x1, y1, top_mat, top_surface],
		[x0, y1, "structure", S_METAL]]


## The Out corner's flat roof: the footprint beyond 64 m from (64, 0), between the heights y.
func _flat_roof(geo: TmGeo, y: Array) -> void:
	var poly := PackedVector2Array([Vector2(0, 64), Vector2(64, 64)])
	for i in range(1, CORNER_STEPS):
		var a := deg_to_rad(90.0 + 90.0 * float(i) / CORNER_STEPS)
		poly.append(Vector2(64, 0) + Vector2(cos(a), sin(a)) * 64.0)
	poly.append(Vector2(0, 0))
	var loop := []
	for p in poly:
		loop.append([p, "structure", S_ROAD])
	geo.extrude_y(loop, float(y[0]), float(y[1]), true, "fabric", S_ROAD)


## A vertical post open at both ends (as TMNF's are): the four sides of the box [lo, hi].
func _open_post(geo: TmGeo, lo: Vector3, hi: Vector3) -> void:
	var loop := [[Vector2(lo.x, lo.z), "structure", S_METAL], [Vector2(hi.x, lo.z), "structure", S_METAL],
		[Vector2(hi.x, hi.z), "structure", S_METAL], [Vector2(lo.x, hi.z), "structure", S_METAL]]
	geo.extrude_y(loop, lo.y, hi.y)


## A closed (x, y) section swept along z over the block (0..32), capped at both ends.
## The truss arches under a straight roof whose section is `table`.
func _trusses(geo: TmGeo, table: Array) -> void:
	var under := _underside(table)
	if under.size() < 2:
		return
	for z: float in TRUSS_LIGHT:
		_truss(geo, under, z, 0.3, 1.45, 1.45, 0.13, 0.07)
	_truss(geo, under, TRUSS_MAIN, 0.55, 5.0, 4.4, 0.22, 0.11)


## The advert boards: a 0.15 m slab each, the screen on its front, steel behind; the hung ones on
## two cables up to the main truss.
func _boards(geo: TmGeo, boards: Array) -> void:
	for bd: Array in boards:
		var lo: Vector2 = bd[0]
		var hi: Vector2 = bd[1]
		var up := (hi - lo).normalized()
		var front := Vector2(up.y, -up.x) if bool(bd[4]) else Vector2(-up.y, up.x)
		var back := -front * 0.15
		var z0: float = bd[2]
		var z1: float = bd[3]
		# corners: l/h the low/high edge, 0/1 at z0/z1, b on the back
		var l0 := Vector3(lo.x, lo.y, z0)
		var l1 := Vector3(lo.x, lo.y, z1)
		var h0 := Vector3(hi.x, hi.y, z0)
		var h1 := Vector3(hi.x, hi.y, z1)
		var bk := Vector3(back.x, back.y, 0.0)
		var n3 := Vector3(front.x, front.y, 0.0)
		var u3 := Vector3(up.x, up.y, 0.0)
		var nz := TmGeo.NO_COLLISION
		_face(geo, [l0, l1, h1, h0], n3, "screen", nz)
		_face(geo, [l0 + bk, l1 + bk, h1 + bk, h0 + bk], -n3, "structure", nz)
		_face(geo, [h0, h1, h1 + bk, h0 + bk], u3, "structure", nz)
		_face(geo, [l0, l1, l1 + bk, l0 + bk], -u3, "structure", nz)
		_face(geo, [l0, h0, h0 + bk, l0 + bk], Vector3(0, 0, -1), "structure", nz)
		_face(geo, [l1, h1, h1 + bk, l1 + bk], Vector3(0, 0, 1), "structure", nz)
		if not bool(bd[4]):
			for z: float in [z0 + 1.0, z1 - 1.0]:
				var top := Vector3(hi.x, hi.y, z) + bk * 0.5
				geo.pipe(top, top + Vector3(0, 2.6, 0), 0.04, 4, "cable", nz)


## A quad facing n (its winding chosen to match).
static func _face(geo: TmGeo, q: Array, n: Vector3, mat: String, surface: int) -> void:
	var a: Vector3 = q[0]
	var b: Vector3 = q[1]
	var c: Vector3 = q[2]
	var d: Vector3 = q[3]
	if (b - a).cross(c - a).dot(n) >= 0.0:
		geo.quad(a, b, c, d, mat, surface)
	else:
		geo.quad(a, d, c, b, mat, surface)


## The shell's underside (its longest run of "fabric_under" segments) from the foot up to the top.
static func _underside(table: Array) -> Array:
	var n := table.size()
	var best: Array = []
	var start := 0
	while start < n:
		if String(table[start][2]) != "fabric_under" or String(table[(start + n - 1) % n][2]) == "fabric_under":
			start += 1
			continue
		var run: Array = []
		var k := start
		while String(table[k % n][2]) == "fabric_under" and run.size() <= n:
			run.append(Vector2(table[k % n][0], table[k % n][1]))
			k += 1
		run.append(Vector2(table[k % n][0], table[k % n][1]))
		if run.size() > best.size():
			best = run
		start += 1
	if best.size() > 1 and (best[0] as Vector2).y > (best[best.size() - 1] as Vector2).y:
		best.reverse()
	return best


## One truss arch at z (thickness 2 half): resampled along the underside every TRUSS_STEP, the top
## chords just under the fabric, the bottom chords depth below it (d_foot at the foot, d_top at the
## top), Warren diagonals in both faces and zig-zagging across the bottom; nothing below the foot.
func _truss(geo: TmGeo, under: Array, z: float, half: float, d_foot: float, d_top: float, chord_r: float, web_r: float) -> void:
	var arc := [0.0]
	for i in range(1, under.size()):
		arc.append(float(arc[i - 1]) + ((under[i] as Vector2) - (under[i - 1] as Vector2)).length())
	var total: float = arc[arc.size() - 1]
	var floor_y: float = (under[0] as Vector2).y
	var count := maxi(2, int(round(total / TRUSS_STEP)))
	var tops: Array = []
	var bots: Array = []
	var j := 0
	for i in count + 1:
		var s := total * float(i) / count
		while j < under.size() - 2 and float(arc[j + 1]) < s:
			j += 1
		var a: Vector2 = under[j]
		var b: Vector2 = under[j + 1]
		var t := clampf((s - float(arc[j])) / maxf(float(arc[j + 1]) - float(arc[j]), 1e-6), 0.0, 1.0)
		var p := a.lerp(b, t)
		var along := (b - a).normalized()
		var inward := Vector2(-along.y, along.x)
		var depth := lerpf(d_foot, d_top, s / total)
		var top := p + inward * 0.12
		var bot := p + inward * depth
		bot.y = maxf(bot.y, floor_y)
		tops.append(top)
		bots.append(bot)
	var nz := TmGeo.NO_COLLISION
	for side: float in [-half, half]:
		var zz := z + side
		for i in count:
			geo.pipe(Vector3(tops[i].x, tops[i].y, zz), Vector3(tops[i + 1].x, tops[i + 1].y, zz), chord_r, 4, "mast", nz)
			geo.pipe(Vector3(bots[i].x, bots[i].y, zz), Vector3(bots[i + 1].x, bots[i + 1].y, zz), chord_r, 4, "mast", nz)
			var u: Vector2 = tops[i] if i % 2 == 0 else bots[i]
			var v: Vector2 = bots[i + 1] if i % 2 == 0 else tops[i + 1]
			geo.pipe(Vector3(u.x, u.y, zz), Vector3(v.x, v.y, zz), web_r, 4, "rubber_dark", nz)
	for i in count:
		var z0 := z - half if i % 2 == 0 else z + half
		geo.pipe(Vector3(bots[i].x, bots[i].y, z0), Vector3(bots[i + 1].x, bots[i + 1].y, 2.0 * z - z0), web_r, 4, "rubber_dark", nz)


func _extrude(geo: TmGeo, table: Array) -> void:
	var sec := table.map(func(q: Array) -> Array: return [Vector2(q[0], q[1]), q[2], q[3]])
	geo.wall_sweep(sec, [Vector3(0, 0, 0), Vector3(0, 0, 32)], [Vector3(1, 0, 0), Vector3(1, 0, 0)], true,
		"structure", S_METAL)
