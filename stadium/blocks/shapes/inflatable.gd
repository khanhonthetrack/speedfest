extends RefCounted
## Stadium "Inflatable" blocks: the giant inflatable structures (cushion walls stacked three levels
## high under a roof, laid out by the editor round a rectangle: "pillar" pieces are the walls,
## "support" pieces the top level with the roof) and the inflatable decorations (cactus, palm tree,
## snow tree, castles: castle.gd). Our own geometry from measured numbers (TMNF block-local metres).
##
## A cushion wall is a row of pillows, each 8 m wide bulging out from its seam line (straight along
## x for the T piece, an arc of radius 24 about the footprint corner for the corner piece; PILLOW_LINE):
## the levels below upright (PILLAR), the top level rounded over its top back to a trim and the
## grey quilted roof (SUPPORT_SECTION), TMNF's sections measured. The pillows are our own drawing
## of TMNF's layout (texgen/stadium.py inflatable_pillow: red vinyl, our banner on the tops).
## The block's direction turns it; the rectasym shape slot repeats the same piece per direction.

const Castles := preload("res://blocks/shapes/castle.gd")

const S_RUBBER := 9
const S_METAL := 4
const S_GRASS := 2

const PILLOW := 8.0             ## pillow width along the wall
const BULGE := 2.1              ## how far a ground pillar's pillow bulges out of its seam line

## [seam line offset from the cell's -z edge (straight) or radius about (0, 32) (corner), y0, y1]
const PILLAR := [8.0, 0.0, 8.0]
## A pillow's outline out of its seam line: [along from the seam (of its 8 m), out] to its middle
## (the rest mirrored); the corner's pillows stretched along the arc.
const PILLOW_LINE := [[0.0, 0.0], [0.395, 0.535], [1.473, 1.616], [4.0, 2.147]]
## The levels below: upright from y 0 to 8, TMNF's v 0.4 -> 1 up them (the red; rows of 1024).
const PILLAR_ROWS := Vector2(614.4, 0.0)
## The top level's section from its foot round over its top to its back: [row, at the seam (out,
## y), in the pillow's middle (out, y)]; between, the seam's section and the middle's mixed by the
## outline's share of its bulge (TMNF's own pillows are that mix, measured).
const SUPPORT_SECTION := [[0.0, 0.0, 0.0, 2.147, 0.0], [150.5, 0.0, 1.375, 2.147, 1.794], [308.2, -0.633, 2.718, 1.455, 3.65],
	[466.0, -1.641, 3.941, 0.343, 5.214], [619.5, -3.001, 4.947, -1.199, 6.535], [741.4, -4.424, 5.733, -3.125, 7.565],
	[864.3, -5.758, 6.295, -5.215, 7.977], [932.9, -6.36, 6.45, -6.209, 7.708], [983.0, -6.8, 6.57, -6.828, 7.096],
	[1002.5, -6.98, 6.59, -7.036, 6.824], [1024.0, -7.278, 6.638, -7.278, 6.638]]
## Behind the top level's pillows, along the wall: [out from the seam line, y] -> key: a rubber
## strip, the interior's grey edge, a white awning plate over them; then the roof (y, 8 m tiles).
const SUPPORT_TRIM := [[[-7.278, 6.638], [-7.461, 7.29], "rubber_dark"], [[-7.461, 7.29], [-8.0, 7.608], "stands_top"],
	[[-6.975, 7.604], [-8.0, 7.904], "sculpt_fabric"]]
const ROOF_Y := 7.99
const ROOF_TILE := 8.0
## The tube's mouth in a T pillar: the flared box (x0 at z 5, x0 at z 8, y0, y1), the pipe's and
## its rubber ring's radii (about (16, 4), along z 0..5); measured.
const TUBE_FLARE := [9.93, 7.67, 2.19, 5.81]
const TUBE_PIPE := [1.42, 1.66]
## The ground pillar pieces (TMNF's billboard walls, measured): each pillow rises from its seam
## line at y 2 with a rounded belly to its full bulge (PILLOW_BELLY: height, share of BULGE across
## the pillow's middle; across it the share BULGE_SHAPE of sin), red vinyl with a white banner
## printed on it (texgen/stadium.py inflatable_banner: our emblem and name where TMNF prints its
## logo; u across the pillow, v up its surface over BANNER_ARC m), a thin skin behind. Under them
## a low plinth in front of the seam line (PILLAR_BASE: (d in front, y), its face then a rubber
## strip up to the seam), a white foot at each seam (PILLAR_FOOT: half width, y0, y1, d0, d1) and
## a dark post in front of it (PILLAR_POST). The corner piece: PILLAR_CORNER pillows round its arc.
const PILLOW_BELLY := [[2.0, 0.0], [2.31, 0.1], [2.53, 0.24], [2.82, 0.42], [3.15, 0.58], [3.6, 0.71],
	[4.15, 0.82], [5.4, 0.88], [6.7, 0.94], [8.0, 1.0]]
const BULGE_SHAPE := 0.6
const BANNER_ARC := 6.65
const PILLAR_BASE := [[0.93, 1.0, "stands_top"], [0.63, 1.66, "rubber_dark"], [0.0, 2.0, ""]]
const PILLAR_FOOT := [0.39, 0.96, 2.24, -0.02, 1.22]
const PILLAR_POST := [0.09, 2.17, 8.0, 0.0, 0.29]
const PILLAR_CORNER := 4
const SKIN := 0.08
## The advert pillar's billboard frame (x0, x1, y0, y1, z0 = the screen, z1) and its posts (x).
const ADVERT_BOARD := [9.37, 54.63, 5.24, 28.53, 5.066, 9.058]
const ADVERT_POSTS := [8.0, 56.0]


func handles(shape: String) -> bool:
	return shape.begins_with("Inflatable/")


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var name := shape.trim_prefix("Inflatable/")
	var geo := TmGeo.new()
	var ground := name.ends_with("Ground")
	match name.trim_suffix("Ground").trim_suffix("Air"):
		"TShapedPillar":
			if ground:
				var seam: float = PILLAR[0]
				_banner_wall(geo, 32.0, 4, func(t: float, d: float, y: float) -> Vector3: return Vector3(t, y, seam - d))
			else:
				_pillows(geo, 32.0, 4, _line_at(PILLAR[0]), false)
		"TubeTShapedPillar":
			# the wall with a tube's mouth: a flared box through it, its frame, and the pipe
			# leaving toward -z with a rubber ring at its end (measured)
			_pillows(geo, 32.0, 4, _line_at(PILLAR[0]), false)
			var flare := [[Vector2(TUBE_FLARE[0], 5.0), "structure", S_METAL], [Vector2(32.0 - TUBE_FLARE[0], 5.0), "structure", S_METAL],
				[Vector2(32.0 - TUBE_FLARE[1], 8.0), "structure", S_METAL], [Vector2(TUBE_FLARE[1], 8.0), "structure", S_METAL]]
			geo.extrude_y(flare, TUBE_FLARE[2], TUBE_FLARE[3], true, "structure", S_METAL)
			geo.box(Vector3(TUBE_FLARE[1], 1.0, 7.367), Vector3(32.0 - TUBE_FLARE[1], 7.0, 8.0), "structure", S_METAL)
			geo.pipe(Vector3(16, 4, 0), Vector3(16, 4, 5), TUBE_PIPE[0], 16, "pipe", S_METAL)
			geo.pipe(Vector3(16, 4, 4.86), Vector3(16, 4, 5), TUBE_PIPE[1], 16, "rubber", S_RUBBER)
		"AdvertTShapedPillar":
			# a two-block cushion wall four levels high carrying a billboard frame through it
			for level in 4:
				_pillows(geo, 64.0, 8, _line_at(PILLAR[0], 8.0 * level), false)
			var b: Array = ADVERT_BOARD
			geo.box(Vector3(b[0], b[2], b[4]), Vector3(b[1], b[3], b[5]), "structure", S_METAL)
			geo.screen_rect(Vector3(b[1], b[2], b[4] - 0.01), Vector3(b[0], b[2], b[4] - 0.01), Vector3(b[0], b[3], b[4] - 0.01),
				Vector3(b[1], b[3], b[4] - 0.01), "screen_on", TmGeo.NO_COLLISION)
			for x: float in ADVERT_POSTS:
				geo.box(Vector3(x - 0.26, 2.0, 7.543), Vector3(x + 0.26, 30.0, 8.058), "structure", S_METAL, "", -2, 0.03)
		"CornerPillar":
			var r: float = 32.0 - float(PILLAR[0])
			if ground:
				# along the arc from (0, 32 - r) round to (r, 32), outward
				_banner_wall(geo, r * PI * 0.5, PILLAR_CORNER, func(t: float, d: float, y: float) -> Vector3:
					var a := -PI * 0.5 + t / r
					return Vector3(cos(a) * (r + d), y, 32.0 + sin(a) * (r + d)))
			else:
				_pillows(geo, r * PI * 0.5, PILLAR_CORNER, _arc_at(r), false)
		"TShaped":
			_pillows(geo, 32.0, 4, _line_at(PILLAR[0]), true)
			_roof(geo, PackedVector2Array([Vector2(0, 16), Vector2(32, 16), Vector2(32, 32), Vector2(0, 32)]))
		"Corner":
			var r: float = 32.0 - float(PILLAR[0])
			_pillows(geo, r * PI * 0.5, PILLAR_CORNER, _arc_at(r), true)
			var poly := PackedVector2Array([Vector2(0, 32)])
			for i in 9:
				var a := lerpf(-PI * 0.5, 0.0, i / 8.0)
				poly.append(Vector2(0, 32) + Vector2(cos(a), sin(a)) * (r - 8.0))
			_roof(geo, poly)
		"Cross":
			_roof(geo, PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)]))
		"Cactus":
			_cactus(geo)
		"InflatablePalmTree":
			_palm(geo)
		"InflatableSnowTree":
			_snow_tree(geo)
		"Castle", "CastleBig", "InflatableCastleDoor":
			Castles.build(geo, name)
		_:
			return null
	return geo.build()


## A ground pillar's billboard wall (PILLOW_BELLY etc.) `length` m along its seam line in `n`
## pillows; at(t, d, y): the block point t m along the seam line, d m in front of it, at height y.
func _banner_wall(geo: TmGeo, length: float, n: int, at: Callable) -> void:
	var w := length / n
	var cols := 12
	var rows := PILLOW_BELLY.size()
	# v up the surface (the pillow's middle), shared by each row
	var arc := [0.0]
	for i in range(1, rows):
		var p0: Vector2 = Vector2(BULGE * float(PILLOW_BELLY[i - 1][1]), float(PILLOW_BELLY[i - 1][0]))
		var p1: Vector2 = Vector2(BULGE * float(PILLOW_BELLY[i][1]), float(PILLOW_BELLY[i][0]))
		arc.append(float(arc[i - 1]) + p0.distance_to(p1))
	var front := func(t: float, u: float, i: int, skin: float) -> Vector3:
		var d := BULGE * pow(sin(PI * u), BULGE_SHAPE) * float(PILLOW_BELLY[i][1]) - skin
		return at.call(t, d, float(PILLOW_BELLY[i][0]))
	for k in n:
		for j in cols:
			var u0 := float(j) / cols
			var u1 := float(j + 1) / cols
			for i in rows - 1:
				var p := [front.call(w * (k + u0), u0, i, 0.0), front.call(w * (k + u1), u1, i, 0.0),
					front.call(w * (k + u1), u1, i + 1, 0.0), front.call(w * (k + u0), u0, i + 1, 0.0)]
				var q := [front.call(w * (k + u0), u0, i, SKIN), front.call(w * (k + u1), u1, i, SKIN),
					front.call(w * (k + u1), u1, i + 1, SKIN), front.call(w * (k + u0), u0, i + 1, SKIN)]
				var v0 := 1.0 - float(arc[i]) / BANNER_ARC
				var v1 := 1.0 - float(arc[i + 1]) / BANNER_ARC
				# the banner reads left to right from in front (the bulge side, toward the track;
				# TMNF's logo reads mirrored from there)
				var out: Vector3 = (p[0] - q[0]) + (p[2] - q[2])
				_face_uv(geo, p, [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)],
					out, "inflatable_banner", S_RUBBER)
				# the skin behind: plain red (the texture's top, above the banner)
				_face_uv(geo, q, [Vector2(u0, v0 * 0.2), Vector2(u1, v0 * 0.2), Vector2(u1, v1 * 0.2), Vector2(u0, v1 * 0.2)],
					-out, "inflatable_banner", S_RUBBER)
			# the skin's top edge
			var top := rows - 1
			_face(geo, [front.call(w * (k + u0), u0, top, 0.0), front.call(w * (k + u1), u1, top, 0.0),
				front.call(w * (k + u1), u1, top, SKIN), front.call(w * (k + u0), u0, top, SKIN)], Vector3.UP, "inflatable_banner",
				TmGeo.NO_COLLISION, [Vector2(u0, 0.01), Vector2(u1, 0.01), Vector2(u1, 0.02), Vector2(u0, 0.02)])
	# the plinth and the rubber strip along the whole wall
	var segs := maxi(1, int(ceil(length / 2.0)))
	for m in segs:
		var t0 := length * m / segs
		var t1 := length * (m + 1) / segs
		for b in PILLAR_BASE.size() - 1:
			var e0: Array = PILLAR_BASE[b]
			var e1: Array = PILLAR_BASE[b + 1]
			var f := [at.call(t0, float(e0[0]), float(e0[1])), at.call(t1, float(e0[0]), float(e0[1])),
				at.call(t1, float(e1[0]), float(e1[1])), at.call(t0, float(e1[0]), float(e1[1]))]
			var o: Vector3 = at.call(t0, 1.0, float(e0[1])) - at.call(t0, 0.0, float(e0[1])) + Vector3.UP * 0.5
			_face(geo, f, o, String(e0[2]), S_RUBBER)
	# a foot and a post at each seam
	for k in n + 1:
		var t := w * k
		var foot: Array = PILLAR_FOOT
		_block(geo, at, maxf(t - float(foot[0]), 0.0), minf(t + float(foot[0]), length), foot[3], foot[4], foot[1], foot[2], "fabric")
		var post: Array = PILLAR_POST
		_block(geo, at, maxf(t - float(post[0]), 0.0), minf(t + float(post[0]), length), post[3], post[4], post[1], post[2],
			"stands_dark")


## A block between t0..t1 along a wall's seam line, d0..d1 in front of it, y0..y1 (at: as
## _banner_wall's), its faces but the bottom; visual only.
func _block(geo: TmGeo, at: Callable, t0: float, t1: float, d0: float, d1: float, y0: float, y1: float, key: String) -> void:
	var c: Vector3 = at.call((t0 + t1) * 0.5, (d0 + d1) * 0.5, (y0 + y1) * 0.5)
	var p := func(t: float, d: float, y: float) -> Vector3: return at.call(t, d, y)
	var faces := [
		[p.call(t0, d0, y1), p.call(t1, d0, y1), p.call(t1, d1, y1), p.call(t0, d1, y1)],
		[p.call(t0, d1, y0), p.call(t1, d1, y0), p.call(t1, d1, y1), p.call(t0, d1, y1)],
		[p.call(t0, d0, y0), p.call(t1, d0, y0), p.call(t1, d0, y1), p.call(t0, d0, y1)],
		[p.call(t0, d0, y0), p.call(t0, d1, y0), p.call(t0, d1, y1), p.call(t0, d0, y1)],
		[p.call(t1, d0, y0), p.call(t1, d1, y0), p.call(t1, d1, y1), p.call(t1, d0, y1)],
	]
	for f: Array in faces:
		var m: Vector3 = (f[0] + f[1] + f[2] + f[3]) * 0.25
		_face(geo, f, m - c, key, TmGeo.NO_COLLISION)


## A quad facing `out` (whichever way its corners run), with its UVs in p's order if given.
func _face(geo: TmGeo, p: Array, out: Vector3, key: String, surface: int, uv: Array = []) -> void:
	if not uv.is_empty():
		_face_uv(geo, p, uv, out, key, surface)
		return
	if ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).dot(out) < 0.0:
		geo.quad(p[0], p[3], p[2], p[1], key, surface)
	else:
		geo.quad(p[0], p[1], p[2], p[3], key, surface)


## A quad with its UVs (in p's order) facing `out`.
func _face_uv(geo: TmGeo, p: Array, uv: Array, out: Vector3, key: String, surface: int) -> void:
	if ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).dot(out) < 0.0:
		geo.quad_uv(p[0], p[3], p[2], p[1], key, surface, uv[0], uv[3], uv[2], uv[1])
	else:
		geo.quad_uv(p[0], p[1], p[2], p[3], key, surface, uv[0], uv[1], uv[2], uv[3])


## The straight walls' frame: at(t, d, y) = the point t m along the seam line z = seam, d m out of it
## (toward -z), at height y (+ lift).
static func _line_at(seam: float, lift := 0.0) -> Callable:
	return func(t: float, d: float, y: float) -> Vector3: return Vector3(t, y + lift, seam - d)


## The corner walls' frame: along the arc of radius r about (0, 32) from (0, 32 - r), out of it.
static func _arc_at(r: float) -> Callable:
	return func(t: float, d: float, y: float) -> Vector3:
		var a := -PI * 0.5 + t / r
		return Vector3(cos(a) * (r + d), y, 32.0 + sin(a) * (r + d))


## A row of n pillows `length` m along a wall (at: _line_at / _arc_at), each TMNF's outline
## (PILLOW_LINE, stretched to its share of the length): upright from y 0 to 8 (the levels below),
## or the top level's pillows rounded over their tops back to the trim (SUPPORT_SECTION,
## SUPPORT_TRIM). Our pillow drawing across each, read from in front.
func _pillows(geo: TmGeo, length: float, n: int, at: Callable, support: bool) -> void:
	var w := length / n
	var line := []
	for q: Array in PILLOW_LINE:
		line.append([float(q[0]) / PILLOW, float(q[1])])
	for k in range(PILLOW_LINE.size() - 2, -1, -1):
		line.append([1.0 - float(PILLOW_LINE[k][0]) / PILLOW, float(PILLOW_LINE[k][1])])
	var mid := float(PILLOW_LINE[PILLOW_LINE.size() - 1][1])
	for p in n:
		var pts := []
		var uvs := []
		var rows := SUPPORT_SECTION.size() if support else 2
		for r in rows:
			var row := []
			var urow := []
			for q: Array in line:
				var t := w * (p + float(q[0]))
				var share := float(q[1]) / mid
				var d: float
				var y: float
				var v: float
				if support:
					var s: Array = SUPPORT_SECTION[r]
					d = lerpf(float(s[1]), float(s[3]), share)
					y = lerpf(float(s[2]), float(s[4]), share)
					v = float(s[0])
				else:
					d = float(q[1])
					y = 8.0 * r
					v = PILLAR_ROWS.x if r == 0 else PILLAR_ROWS.y
				row.append(at.call(t, d, y))
				urow.append(Vector2(float(q[0]), v / 1024.0))
			pts.append(row)
			uvs.append(urow)
		# columns along the wall, rows up: (along) x (up) faces back, so turned round
		geo.grid(pts, uvs, "inflatable_pillow", S_RUBBER, true)
	if not support:
		return
	var segs := maxi(1, n * 4)
	for tr: Array in SUPPORT_TRIM:
		var a: Vector2 = tr[0]
		var b: Vector2 = tr[1]
		for m in segs:
			var t0 := length * m / segs
			var t1 := length * (m + 1) / segs
			var q := [at.call(t0, a.x, a.y), at.call(t1, a.x, a.y), at.call(t1, b.x, b.y), at.call(t0, b.x, b.y)]
			var o: Vector3 = (at.call(t0, 1.0, 0.0) - at.call(t0, 0.0, 0.0)) + Vector3.UP * 2.0
			_face(geo, q, o, String(tr[2]), S_RUBBER)


## The top level's roof: TMNF's grey quilted vinyl (texgen inflatable_roof) in ROOF_TILE m tiles.
func _roof(geo: TmGeo, poly: PackedVector2Array) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for k in range(0, idx.size(), 3):
		var t := [poly[idx[k]], poly[idx[k + 1]], poly[idx[k + 2]]]
		var p := [Vector3(t[0].x, ROOF_Y, t[0].y), Vector3(t[1].x, ROOF_Y, t[1].y), Vector3(t[2].x, ROOF_Y, t[2].y)]
		if ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).y < 0.0:
			p = [p[0], p[2], p[1]]
			t = [t[0], t[2], t[1]]
		geo.tri(p[0], p[1], p[2], "infl_roof", S_RUBBER, Vector3.UP, Vector3.UP, Vector3.UP, t[0] / ROOF_TILE + Vector2(1e-4, 0),
			t[1] / ROOF_TILE, t[2] / ROOF_TILE)


## Decorations, as TMNF lays them out (measured from its blocks: every object's place, heights and
## radii; colours its textures' area-weighted means): a group of inflatables on the grass (1 m),
## each on a grey base ring and tied down with ropes.
## Cacti: [trunk base (x, z), trunk top (x, z), radius, top y, base ring (r in, r out, y top),
## arms [[axis (x, z), elbow y, top y, radius], ...]]; the two kinds each twice, turned.
const CACTI := [
	[Vector2(11.0, 10.25), Vector2(11.0, 10.25), 1.6, 13.43, [0.86, 1.69, 1.34],
		[[Vector2(10.91, 6.5), 5.85, 9.25, 1.05], [Vector2(9.85, 13.65), 8.35, 11.25, 0.95]]],
	[Vector2(25.85, 21.87), Vector2(25.85, 21.87), 1.6, 13.43, [0.86, 1.69, 1.34],
		[[Vector2(22.07, 21.95), 5.85, 9.25, 1.05], [Vector2(29.3, 23.02), 8.35, 11.25, 0.95]]],
	[Vector2(25.0, 6.42), Vector2(25.4, 5.95), 1.33, 11.1, [0.71, 1.39, 1.25],
		[[Vector2(22.3, 5.0), 5.0, 7.75, 0.85], [Vector2(27.45, 8.2), 6.75, 9.2, 0.78]]],
	[Vector2(7.36, 25.8), Vector2(7.85, 26.3), 1.33, 11.1, [0.71, 1.39, 1.25],
		[[Vector2(8.95, 23.3), 5.0, 7.75, 0.85], [Vector2(5.37, 28.1), 6.75, 9.2, 0.78]]],
]
const RIB := 0.09              ## the cacti's ribs: how far each swells out and in (of the radius)
## The cacti's and palms' white label bands (TMNF's sponsor bands; ours plain with an ink line):
## from, ink line from, to, band to (y)
const LABEL := [1.6, 2.45, 2.75, 3.9]
const PALM_LABEL := [2.42, 3.3, 3.8, 4.9]
## The cacti's red tie ropes: [peg on the grass, knot on the cactus] (TMNF x, y, z)
const CACTUS_ROPES := [
	[Vector3(11.02, 1.0, 8.14), Vector3(10.99, 4.44, 8.62)], [Vector3(10.98, 1.0, 12.32), Vector3(11.0, 4.44, 11.84)],
	[Vector3(8.91, 1.0, 10.23), Vector3(9.45, 4.44, 10.25)], [Vector3(13.08, 1.0, 10.25), Vector3(12.54, 4.44, 10.23)],
	[Vector3(23.72, 1.0, 21.84), Vector3(24.2, 4.44, 21.87)], [Vector3(27.9, 1.0, 21.89), Vector3(27.42, 4.44, 21.86)],
	[Vector3(25.81, 1.0, 23.96), Vector3(25.83, 4.44, 23.41)], [Vector3(25.83, 1.0, 19.78), Vector3(25.81, 4.44, 20.32)],
	[Vector3(23.37, 0.97, 5.68), Vector3(23.79, 3.79, 5.81)], [Vector3(26.54, 0.97, 7.15), Vector3(26.2, 3.77, 6.93)],
	[Vector3(24.24, 0.97, 8.01), Vector3(24.47, 3.83, 7.54)], [Vector3(25.7, 0.97, 4.86), Vector3(25.53, 3.73, 5.22)],
	[Vector3(8.22, 0.97, 24.27), Vector3(8.06, 3.79, 24.68)], [Vector3(6.49, 0.97, 27.3), Vector3(6.73, 3.77, 26.98)],
	[Vector3(5.83, 0.97, 24.93), Vector3(6.28, 3.83, 25.2)], [Vector3(8.84, 0.97, 26.66), Vector3(8.5, 3.73, 26.46)],
]
## Snow trees: [base centre (x, z), tip (x, z), base y, tip y]
const SNOW_TREES := [
	[Vector2(21.4, 7.05), Vector2(21.6, 7.2), 1.15, 11.12], [Vector2(9.0, 8.3), Vector2(8.8, 8.32), 1.15, 10.5],
	[Vector2(20.6, 15.65), Vector2(19.95, 15.05), 1.33, 12.59], [Vector2(13.7, 24.55), Vector2(14.6, 24.55), 1.16, 10.4],
]
## A snow tree's outline (r, y) for one 1.15 -> 10.5 m high (scaled to each), from the bottom centre
## out and up to the tip, each segment's colour: four tiers, the snow on each tier's slope above its
## green rim (on the first from 1.95 to 2.5 m), the top cone all snow (measured where TMNF's texture
## is light, sampled across its faces). The radii are the mean round the tree; each tier's rim hangs
## in eight branches reaching out by the lobe depth (of the radius; measured: the widest against the
## mean), the tiers' branches staggered (phase).
const SNOW_TREE := [
	[0.0, 1.15, "infl_tree", 0.0, 0.0], [2.9, 1.15, "infl_tree", 0.1, 0.0], [3.45, 1.6, "infl_tree", 0.26, 0.0],
	[3.4, 1.95, "infl_snow", 0.22, 0.0], [3.0, 2.5, "infl_tree", 0.15, 0.0], [2.6, 3.05, "infl_tree", 0.12, 0.39],
	[2.65, 3.45, "infl_tree", 0.24, 0.39], [2.5, 3.8, "infl_snow", 0.26, 0.39], [2.3, 4.4, "infl_snow", 0.15, 0.39],
	[2.2, 4.62, "infl_tree", 0.14, 0.39], [2.0, 4.95, "infl_tree", 0.12, 0.0], [2.15, 5.45, "infl_tree", 0.3, 0.0],
	[2.0, 6.0, "infl_snow", 0.2, 0.0], [1.7, 6.55, "infl_tree", 0.14, 0.0],
	[1.6, 6.75, "infl_tree", 0.12, 0.39], [1.55, 7.3, "infl_snow", 0.4, 0.39], [1.35, 7.9, "infl_snow", 0.25, 0.39],
	[1.1, 8.5, "infl_snow", 0.17, 0.0], [0.8, 9.1, "infl_snow", 0.2, 0.0], [0.54, 9.7, "infl_snow", 0.2, 0.0],
	[0.23, 10.3, "infl_snow", 0.0, 0.0], [0.0, 10.5, "", 0.0, 0.0],
]
## Palms: two islands (the second the first turned half round the block's centre), two palms on
## each. A trunk's centre line every metre from 2.92 m up (x, z), its radius there.
const PALM_TRUNKS := [
	[Vector2(10.37, 9.43), Vector2(10.33, 9.52), Vector2(10.37, 9.74), Vector2(10.38, 9.87), Vector2(10.35, 10.12),
		Vector2(10.37, 10.35), Vector2(10.36, 10.58), Vector2(10.36, 10.77), Vector2(10.35, 10.94), Vector2(10.35, 11.0),
		Vector2(10.35, 11.02)],
	[Vector2(7.54, 4.85), Vector2(7.53, 4.82), Vector2(7.41, 4.86), Vector2(7.38, 4.86), Vector2(7.24, 4.86),
		Vector2(7.12, 4.88), Vector2(6.97, 4.88), Vector2(6.87, 4.91), Vector2(6.73, 4.91), Vector2(6.7, 4.89),
		Vector2(6.67, 4.91)],
]
const PALM_R := [1.0, 1.0, 0.98, 0.94, 0.87, 0.78, 0.68, 0.6, 0.53, 0.46, 0.4]
## Each palm's fronds: [direction (deg, from +x toward +z), kind]; kinds' centre lines (distance
## out from the trunk's axis, height), their width and thickness along them.
const PALM_FRONDS := [
	[[-157.5, 0], [-91.3, 1], [-26.2, 2], [42.8, 1], [126.1, 2]],
	[[-74.6, 0], [128.1, 1], [-156.5, 2], [-10.6, 1], [49.1, 2]],
]
const FROND_LINES := [
	[Vector2(0.2, 13.5), Vector2(1.5, 13.6), Vector2(2.5, 13.8), Vector2(3.5, 13.75), Vector2(4.4, 12.75), Vector2(5.4, 10.9)],
	[Vector2(0.1, 13.7), Vector2(0.9, 14.1), Vector2(1.9, 14.2), Vector2(2.9, 14.0), Vector2(3.9, 13.5), Vector2(4.85, 12.0)],
	[Vector2(0.1, 13.55), Vector2(1.1, 14.4), Vector2(2.1, 14.75), Vector2(3.1, 14.7), Vector2(4.1, 14.3), Vector2(5.1, 12.8)],
]
const FROND_W := [0.6, 1.6, 1.95, 1.9, 1.5, 0.08]
const FROND_T := [0.6, 0.6, 0.55, 0.48, 0.36, 0.06]
## The first island's outline (x, z; its grey rim 0.97 -> 1.27 m, the sand up to 1.95 m inside)
const PALM_ISLAND := [
	Vector2(8.17, 0.81), Vector2(10.1, 1.05), Vector2(10.48, 3.35), Vector2(11.62, 6.93), Vector2(13.64, 9.8),
	Vector2(16.04, 11.82), Vector2(17.43, 12.87), Vector2(16.81, 14.53), Vector2(15.21, 17.11), Vector2(13.86, 18.57),
	Vector2(11.19, 17.21), Vector2(7.1, 13.56), Vector2(4.35, 8.81), Vector2(3.27, 4.22), Vector2(3.15, 1.7),
	Vector2(5.13, 1.07),
]


func _cactus(geo: TmGeo) -> void:
	for c: Array in CACTI:
		var base: Vector2 = c[0]
		var r: float = c[2]
		var top: float = c[3]
		var outline := [[Vector2(0, 1.0), "infl_cactus"], [Vector2(r, 1.0), "infl_cactus", RIB], [Vector2(r, LABEL[0]), "infl_label", RIB],
			[Vector2(r, LABEL[1]), "infl_ink", RIB], [Vector2(r, LABEL[2]), "infl_label", RIB], [Vector2(r, LABEL[3]), "infl_cactus", RIB]]
		for k in 5:
			var a := PI * 0.5 * k / 4.0
			outline.append([Vector2(r * cos(a), top - r + r * sin(a)), "infl_cactus", RIB * cos(a)])
		_lathe(geo, outline, base, c[1], 1.0, top, 32, 8)
		var ring: Array = c[4]
		_lathe(geo, [[Vector2(float(ring[0]), 0.96), "infl_base"], [Vector2(float(ring[1]), 1.02), "infl_base"],
			[Vector2(float(ring[1]), float(ring[2]) - 0.08), "infl_base"], [Vector2(float(ring[0]) + 0.2, float(ring[2])), ""]],
			base, base, 0.0, 1.0)
		for arm: Array in c[5]:
			var ax: Vector2 = arm[0]
			var e: float = arm[1]
			var ar: float = arm[3]
			# up from a round elbow to a round top, joined to the trunk by a level tube
			var out := []
			for k in 4:
				var a := -PI * 0.5 + PI * 0.5 * k / 3.0
				out.append([Vector2(ar * cos(a), e + ar * sin(a)), "infl_cactus", RIB * cos(a)])
			for k in 5:
				var a := PI * 0.5 * k / 4.0
				out.append([Vector2(ar * cos(a), float(arm[2]) - ar + ar * sin(a)), "infl_cactus", RIB * cos(a)])
			_lathe(geo, out, ax, ax, 0.0, 1.0, 24, 8)
			var at := base.lerp(c[1], clampf((e - 1.0) / (top - 1.0), 0.0, 1.0))
			_tube(geo, [Vector3(at.x, e, at.y), Vector3(ax.x, e, ax.y)], [Vector2(ar, ar), Vector2(ar, ar)], "infl_cactus", 14)
	for rope: Array in CACTUS_ROPES:
		_tube(geo, [rope[0], rope[1]], [Vector2(0.035, 0.035), Vector2(0.035, 0.035)], "infl_rope_red", 6, TmGeo.NO_COLLISION)


func _palm(geo: TmGeo) -> void:
	for half in 2:
		var turn := func(q: Vector2) -> Vector2: return Vector2(32.0, 32.0) - q if half == 1 else q
		# the island: a grey rim round the sand, rising to a low dome
		var rim := []
		var poly := PackedVector2Array()
		for q: Vector2 in PALM_ISLAND:
			poly.append(turn.call(q))
		for q in poly:
			rim.append([q, "infl_base", S_RUBBER])
		geo.extrude_y(rim, 0.97, 1.27)
		var inner := _inset(poly, 0.7)
		for i in poly.size():
			var j := (i + 1) % poly.size()
			geo.quad(Vector3(poly[i].x, 1.27, poly[i].y), Vector3(inner[i].x, 1.9, inner[i].y),
				Vector3(inner[j].x, 1.9, inner[j].y), Vector3(poly[j].x, 1.27, poly[j].y), "infl_sand", S_RUBBER)
		geo.flat_polygon(inner, 1.95, "infl_sand", S_RUBBER)
		for i in inner.size():
			var j := (i + 1) % inner.size()
			geo.quad(Vector3(inner[i].x, 1.9, inner[i].y), Vector3(inner[i].x, 1.95, inner[i].y),
				Vector3(inner[j].x, 1.95, inner[j].y), Vector3(inner[j].x, 1.9, inner[j].y), "infl_sand", S_RUBBER)
		for t in 2:
			var line: Array = PALM_TRUNKS[t]
			var centre := func(y: float) -> Vector3:
				var f := clampf(y - 2.92, 0.0, line.size() - 1.001)
				var q: Vector2 = turn.call((line[floori(f)] as Vector2).lerp(line[floori(f) + 1], f - floorf(f)))
				return Vector3(q.x, y, q.y)
			var radius := func(y: float) -> float:
				var f := clampf(y - 2.92, 0.0, PALM_R.size() - 1.001)
				return lerpf(float(PALM_R[floori(f)]), float(PALM_R[floori(f) + 1]), f - floorf(f)) if y < 12.92 else lerpf(0.4, 0.38, y - 12.92)
			# the label band, then the trunk ringed every 0.6 m, darker at the foot and the crown
			var cuts := [PALM_LABEL[0], PALM_LABEL[1], PALM_LABEL[2], PALM_LABEL[3]]
			var keys := ["infl_label", "infl_ink", "infl_label"]
			var y := float(PALM_LABEL[3])
			while y < 13.9:
				keys.append("infl_trunk_low" if y < 7.0 else ("infl_trunk" if y < 10.5 else "infl_trunk_top"))
				keys.append("infl_trunk_ring")
				cuts.append(minf(y + 0.48, 13.92))
				cuts.append(minf(y + 0.6, 13.92))
				y += 0.6
			for part in keys.size():
				if cuts[part + 1] - cuts[part] < 0.01:
					continue
				var pts := []
				var sizes := []
				var ya: float = cuts[part]
				var yb: float = cuts[part + 1]
				var steps := maxi(1, ceili((yb - ya) / 0.5))
				for k in steps + 1:
					var yk := lerpf(ya, yb, float(k) / steps)
					pts.append(centre.call(yk))
					sizes.append(Vector2.ONE * float(radius.call(yk)))
				_tube(geo, pts, sizes, keys[part], 14)
			var crown: Vector2 = turn.call(line[line.size() - 1])
			var foot: Vector2 = turn.call(line[0])
			_lathe(geo, [[Vector2(0.5, 1.85), "infl_base"], [Vector2(1.08, 1.95), "infl_base"], [Vector2(1.08, 2.35), "infl_base"],
				[Vector2(0.6, 2.53), ""]], foot, foot, 0.0, 1.0)
			_lathe(geo, [[Vector2(0.0, 13.8), "infl_base"], [Vector2(0.45, 13.9), "infl_base"], [Vector2(0.4, 14.05), "infl_base"],
				[Vector2(0.0, 14.14), ""]], crown, crown, 0.0, 1.0, 12)
			for f: Array in PALM_FRONDS[t]:
				var a := deg_to_rad(float(f[0]) + (180.0 if half == 1 else 0.0))
				var dir := Vector2(cos(a), sin(a))
				var fpts := []
				var fsz := []
				var kind: Array = FROND_LINES[int(f[1])]
				for k in kind.size():
					var q: Vector2 = crown + dir * (kind[k] as Vector2).x
					fpts.append(Vector3(q.x, (kind[k] as Vector2).y, q.y))
					fsz.append(Vector2(FROND_W[k] * 0.5, FROND_T[k] * 0.5))
				_tube(geo, fpts, fsz, "infl_leaf", 12)
			# four ropes from a ring round the trunk (5.6 m) to pegs on the island
			for d: Vector2 in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
				var at := foot.lerp(crown, (5.6 - 2.42) / (13.92 - 2.42))
				_tube(geo, [Vector3(foot.x + d.x * 2.1, 1.92, foot.y + d.y * 2.1), Vector3(at.x + d.x * 0.95, 5.6, at.y + d.y * 0.95)],
					[Vector2(0.04, 0.04), Vector2(0.04, 0.04)], "infl_rope", 6, TmGeo.NO_COLLISION)


func _snow_tree(geo: TmGeo) -> void:
	for t: Array in SNOW_TREES:
		var y0: float = t[2]
		var k := (float(t[3]) - y0) / (10.5 - 1.15)
		var outline := []
		for q: Array in SNOW_TREE:
			outline.append([Vector2(float(q[0]), y0 + (float(q[1]) - 1.15) * k), q[2], q[3], q[4]])
		_lathe(geo, outline, t[0], t[1], y0, float(t[3]), 32, 8)
		var c: Vector2 = t[0]
		_lathe(geo, [[Vector2(2.0, 0.85), "infl_base"], [Vector2(3.25, 0.95), "infl_base"], [Vector2(3.25, 1.25), "infl_base"],
			[Vector2(2.2, 1.35), ""]], c, c, 0.0, 1.0)


## A lathe about a vertical axis: outline [[Vector2(r, y), key, lobe depth, lobe phase], ...] from
## the bottom (centre) out and up (each segment the key of its first point; "" leaves it out), its
## axis moving from c0 at y0 to c1 at y1 (a lean); with `lobes`, each point's radius swells and
## shrinks round the axis by its depth (a cactus's ribs, a tree's branches); shaded round except
## across creases sharper than 50 deg.
func _lathe(geo: TmGeo, outline: Array, c0: Vector2, c1: Vector2, y0: float, y1: float, sides := 16, lobes := 0,
		surface := S_RUBBER) -> void:
	var n := outline.size()
	var sn := []
	for i in n - 1:
		var a: Vector2 = outline[i][0]
		var b: Vector2 = outline[i + 1][0]
		sn.append(Vector2(b.y - a.y, a.x - b.x).normalized())
	var soft := func(i: int, j: int) -> Vector2:
		# segment i's normal at its point j (i or i + 1), averaged with the neighbour's if gentle
		var o := i - 1 if j == i else i + 1
		if o < 0 or o >= sn.size() or (sn[i] as Vector2).dot(sn[o]) < cos(deg_to_rad(50.0)):
			return sn[i]
		return ((sn[i] as Vector2) + (sn[o] as Vector2)).normalized()
	var at := func(q: Array, th: float) -> Vector3:
		var p: Vector2 = q[0]
		var c := c0.lerp(c1, clampf((p.y - y0) / maxf(y1 - y0, 1e-6), 0.0, 1.0))
		var r := p.x
		if lobes > 0 and q.size() > 2:
			r *= 1.0 + float(q[2]) * cos(lobes * (th - (float(q[3]) if q.size() > 3 else 0.0)))
		return Vector3(c.x + r * cos(th), p.y, c.y + r * sin(th))
	for i in n - 1:
		var key: String = outline[i][1]
		if key.is_empty():
			continue
		var a: Vector2 = outline[i][0]
		var b: Vector2 = outline[i + 1][0]
		var na: Vector2 = soft.call(i, i)
		var nb: Vector2 = soft.call(i, i + 1)
		for s in sides:
			var t0 := TAU * s / sides
			var t1 := TAU * (s + 1) / sides
			var a0: Vector3 = at.call(outline[i], t0)
			var a1: Vector3 = at.call(outline[i], t1)
			var b0: Vector3 = at.call(outline[i + 1], t0)
			var b1: Vector3 = at.call(outline[i + 1], t1)
			var na0 := Vector3(na.x * cos(t0), na.y, na.x * sin(t0))
			var na1 := Vector3(na.x * cos(t1), na.y, na.x * sin(t1))
			var nb0 := Vector3(nb.x * cos(t0), nb.y, nb.x * sin(t0))
			var nb1 := Vector3(nb.x * cos(t1), nb.y, nb.x * sin(t1))
			geo.tri(a0, b0, b1, key, surface, na0, nb0, nb1)
			geo.tri(a0, b1, a1, key, surface, na0, nb1, na1)


## A tube through pts (TMNF) whose section at each point is an ellipse sizes[i] (half widths:
## x level across, y up-down), shaded round; the frames follow the line without twisting.
func _tube(geo: TmGeo, pts: Array, sizes: Array, key: String, sides := 12, surface := S_RUBBER) -> void:
	var frames := []
	var profiles := []
	var up := Vector3.UP
	for i in pts.size():
		var t := ((pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		if i == 0:
			up = Vector3.UP if absf(t.y) < 0.9 else Vector3(0, 0, 1)
		up = (up - t * up.dot(t)).normalized()
		frames.append(Transform3D(Basis(up.cross(t), up, t), pts[i]))
		var loop := []
		var sz: Vector2 = sizes[i]
		for k in sides:
			var a := TAU * k / sides
			loop.append([Vector2(cos(a) * sz.x, sin(a) * sz.y), key, surface])
		loop.append(loop[0])
		profiles.append(loop)
	geo.sweep(profiles[0], frames, true, profiles)


## A polygon's outline moved in by d (along each corner's bisector; gentle outlines only).
static func _inset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var ccw := TmGeo.loop_area(Array(poly).map(func(q: Vector2) -> Array: return [q])) > 0.0
	for i in poly.size():
		var p := poly[(i - 1 + poly.size()) % poly.size()]
		var q := poly[i]
		var r := poly[(i + 1) % poly.size()]
		var e1 := (q - p).normalized()
		var e2 := (r - q).normalized()
		var n1 := Vector2(-e1.y, e1.x)
		var n2 := Vector2(-e2.y, e2.x)
		var n := (n1 + n2).normalized()
		if not ccw:
			n = -n
		out.append(q + n * d / maxf(0.5, n.dot(n1 if ccw else -n1)))
	return out

