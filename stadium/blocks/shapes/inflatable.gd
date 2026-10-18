extends RefCounted
## Stadium "Inflatable" blocks: the giant inflatable structures (cushion walls stacked three levels
## high under a roof, laid out by the editor round a rectangle: "pillar" pieces are the walls,
## "support" pieces the top level with the roof) and the inflatable decorations (cactus, palm tree,
## snow tree, castles). Our own geometry from measured numbers (TMNF block-local metres).
##
## A cushion wall is a row of pillows, each 8 m wide bulging 2.1 m out from its seam line (straight
## along x for the T piece, an arc of radius 24 about the footprint corner for the corner piece).
## The block's direction turns it; the rectasym shape slot repeats the same piece per direction.

const S_RUBBER := 9
const S_METAL := 4
const S_GRASS := 2

const PILLOW := 8.0             ## pillow width along the wall
const BULGE := 2.1              ## how far a pillow bulges out of its seam line

## [seam line offset from the cell's -z edge (straight) or radius about (0, 32) (corner), y0, y1]
const PILLAR := [8.0, 0.0, 8.0]
const SUPPORT := [9.7, 0.0, 8.0]
## The tube's mouth in a T pillar: the flared box (x0 at z 5, x0 at z 8, y0, y1), the pipe's and
## its rubber ring's radii (about (16, 4), along z 0..5); measured.
const TUBE_FLARE := [9.93, 7.67, 2.19, 5.81]
const TUBE_PIPE := [1.42, 1.66]
## The advert pillar's billboard frame (x0, x1, y0, y1, z0 = the screen, z1) and its posts (x).
const ADVERT_BOARD := [9.37, 54.63, 5.24, 28.53, 5.066, 9.058]
const ADVERT_POSTS := [8.0, 56.0]


func handles(shape: String) -> bool:
	return shape.begins_with("Inflatable/")


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var name := shape.trim_prefix("Inflatable/")
	var geo := TmGeo.new()
	var ground := name.ends_with("Ground")
	var y0 := 1.0 if ground else 0.0
	match name.trim_suffix("Ground").trim_suffix("Air"):
		"TShapedPillar":
			_straight_wall(geo, PILLAR[0], y0, PILLAR[2])
		"TubeTShapedPillar":
			# the wall with a tube's mouth: a flared box through it, its frame, and the pipe
			# leaving toward -z with a rubber ring at its end (measured)
			_straight_wall(geo, PILLAR[0], y0, PILLAR[2])
			var flare := [[Vector2(TUBE_FLARE[0], 5.0), "structure", S_METAL], [Vector2(32.0 - TUBE_FLARE[0], 5.0), "structure", S_METAL],
				[Vector2(32.0 - TUBE_FLARE[1], 8.0), "structure", S_METAL], [Vector2(TUBE_FLARE[1], 8.0), "structure", S_METAL]]
			geo.extrude_y(flare, TUBE_FLARE[2], TUBE_FLARE[3], true, "structure", S_METAL)
			geo.box(Vector3(TUBE_FLARE[1], 1.0, 7.367), Vector3(32.0 - TUBE_FLARE[1], 7.0, 8.0), "structure", S_METAL)
			geo.pipe(Vector3(16, 4, 0), Vector3(16, 4, 5), TUBE_PIPE[0], 16, "pipe", S_METAL)
			geo.pipe(Vector3(16, 4, 4.86), Vector3(16, 4, 5), TUBE_PIPE[1], 16, "rubber", S_RUBBER)
		"AdvertTShapedPillar":
			# a two-block cushion wall four levels high carrying a billboard frame through it
			_straight_wall(geo, PILLAR[0], 0.0, 32.0, 64.0)
			var b: Array = ADVERT_BOARD
			geo.box(Vector3(b[0], b[2], b[4]), Vector3(b[1], b[3], b[5]), "structure", S_METAL)
			geo.quad(Vector3(b[1], b[2], b[4] - 0.01), Vector3(b[0], b[2], b[4] - 0.01), Vector3(b[0], b[3], b[4] - 0.01),
				Vector3(b[1], b[3], b[4] - 0.01), "screen", TmGeo.NO_COLLISION)
			for x: float in ADVERT_POSTS:
				geo.box(Vector3(x - 0.26, 2.0, 7.543), Vector3(x + 0.26, 30.0, 8.058), "structure", S_METAL, "", -2, 0.03)
		"CornerPillar":
			_arc_wall(geo, 32.0 - PILLAR[0], y0, PILLAR[2])
		"TShaped":
			_straight_wall(geo, SUPPORT[0], y0, SUPPORT[2])
			_roof(geo, PackedVector2Array([Vector2(0, SUPPORT[0]), Vector2(32, SUPPORT[0]), Vector2(32, 32), Vector2(0, 32)]))
		"Corner":
			var r := 32.0 - SUPPORT[0]
			_arc_wall(geo, r, y0, SUPPORT[2])
			var poly := PackedVector2Array([Vector2(0, 32)])
			for i in 13:
				var a := lerpf(-PI * 0.5, 0.0, i / 12.0)
				poly.append(Vector2(0, 32) + Vector2(cos(a), sin(a)) * r)
			_roof(geo, poly)
		"Cross":
			_roof(geo, PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)]))
		"Cactus":
			_cactus(geo)
		"InflatablePalmTree":
			_palm(geo)
		"InflatableSnowTree":
			_snow_tree(geo)
		"Castle":
			_castle(geo, Vector2(32, 32), 17.6)
		"CastleBig":
			_castle(geo, Vector2(64, 64), 23.2)
		"InflatableCastleDoor":
			_castle(geo, Vector2(96, 32), 23.2)
		_:
			return null
	return geo.build()


## A pillow's bulge at u in [0, 1] across it (a rounded bump, measured shape).
static func _bulge(u: float) -> float:
	return BULGE * sqrt(maxf(0.0, sin(PI * clampf(u, 0.0, 1.0))))


## Cushion wall along x (0..width) with its seam line at z = seam, pillows bulging toward -z.
func _straight_wall(geo: TmGeo, seam: float, y0: float, y1: float, width := 32.0) -> void:
	var loop := []
	var n := int(width / PILLOW)
	for k in n:
		for s in 8:
			var u := s / 8.0
			loop.append([Vector2(k * PILLOW + u * PILLOW, seam - _bulge(u)), "inflatable", S_RUBBER])
	loop.append([Vector2(width, seam), "inflatable", S_RUBBER])
	loop.append([Vector2(width, seam + 0.3), "inflatable", S_RUBBER])
	loop.append([Vector2(0, seam + 0.3), "inflatable", S_RUBBER])
	geo.extrude_y(loop, y0, y1, true, "inflatable", S_RUBBER)


## Cushion wall on an arc of radius r about the footprint corner (0, 32), pillows bulging outward.
func _arc_wall(geo: TmGeo, r: float, y0: float, y1: float) -> void:
	var c := Vector2(0, 32)
	var n := maxi(1, int(round(r * PI * 0.5 / PILLOW)))
	var outer := []
	var inner := []
	for k in n * 8 + 1:
		var u := float(k) / (n * 8)
		var a := lerpf(-PI * 0.5, 0.0, u)
		var dir := Vector2(cos(a), sin(a))
		outer.append(c + dir * (r + _bulge(fmod(u * n, 1.0) if k < n * 8 else 0.0)))
		inner.append(c + dir * (r - 0.3))
	var loop := []
	for p in outer:
		loop.append([p, "inflatable", S_RUBBER])
	inner.reverse()
	for p in inner:
		loop.append([p, "inflatable", S_RUBBER])
	geo.extrude_y(loop, y0, y1, true, "inflatable", S_RUBBER)


## The structure's roof at the top of the support level.
func _roof(geo: TmGeo, poly: PackedVector2Array) -> void:
	geo.flat_polygon(poly, 8.0, "inflatable", S_RUBBER)
	geo.flat_polygon(poly, 7.6, "inflatable", S_RUBBER, true)


## Decorations: simple inflatable shapes of the measured sizes, standing on the ground (1 m).
func _cactus(geo: TmGeo) -> void:
	geo.pipe(Vector3(16, 1, 16), Vector3(16, 13.4, 16), 2.2, 12, "grass", S_RUBBER)
	geo.pipe(Vector3(16, 6, 16), Vector3(21, 6, 16), 1.2, 10, "grass", S_RUBBER)
	geo.pipe(Vector3(21, 6, 16), Vector3(21, 10.5, 16), 1.2, 10, "grass", S_RUBBER)
	geo.pipe(Vector3(16, 8, 16), Vector3(11.5, 8, 16), 1.1, 10, "grass", S_RUBBER)
	geo.pipe(Vector3(11.5, 8, 16), Vector3(11.5, 11.5, 16), 1.1, 10, "grass", S_RUBBER)


func _palm(geo: TmGeo) -> void:
	geo.pipe(Vector3(16, 1, 16), Vector3(16, 12.5, 16), 1.0, 10, "dirt", S_RUBBER)
	for k in 6:
		var a := TAU * k / 6.0
		var tip := Vector3(16, 11.0, 16) + Vector3(cos(a), 0, sin(a)) * 9.0
		geo.pipe(Vector3(16, 13.5, 16), tip, 0.9, 6, "grass", S_RUBBER)


func _snow_tree(geo: TmGeo) -> void:
	geo.pipe(Vector3(16, 0.8, 16), Vector3(16, 3.0, 16), 1.2, 10, "dirt", S_RUBBER)
	for k in 3:
		var y := 3.0 + k * 3.0
		var r := 7.0 - k * 2.0
		# a cone tier as a short tapered stack of pipes
		geo.pipe(Vector3(16, y, 16), Vector3(16, y + 1.6, 16), r, 16, "rubber_white", S_RUBBER)
		geo.pipe(Vector3(16, y + 1.6, 16), Vector3(16, y + 3.6, 16), r * 0.55, 16, "rubber_white", S_RUBBER)


func _castle(geo: TmGeo, size: Vector2, h: float) -> void:
	var wall := minf(size.x, size.y) * 0.35
	geo.box(Vector3(2, 0.9, 2), Vector3(size.x - 2, h * 0.55, size.y - 2), "inflatable", S_RUBBER, "inflatable", S_RUBBER)
	for corner in [Vector2(4, 4), Vector2(size.x - 4, 4), Vector2(4, size.y - 4), Vector2(size.x - 4, size.y - 4)]:
		geo.pipe(Vector3(corner.x, 0.9, corner.y), Vector3(corner.x, h, corner.y), minf(4.0, wall * 0.3), 12, "inflatable", S_RUBBER)
