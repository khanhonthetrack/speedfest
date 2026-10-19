class_name TmTrackDecor
extends RefCounted
## Dresses our tracks the way TMNF's are dressed (the campaign: thousands of Control rows,
## inflatables and sculptures around the roads): Fabric grandstands framing the start and the
## finish, an inflatable wall with a billboard beyond the outside of each curve, camera booths and
## light rigs by the checkpoints, rows of glass booths, advert boards and camera booms beside the
## straights (the Control "road" blocks, laid as a straight network a cell away from the road,
## dead ends at both ends), inflatable palm trees, cacti and snow trees on the grass near the
## track, sculptures further out, and the airship over the field. Seeded by the track's id, so a
## track always looks the same; only on cells nothing else uses, with a free cell between them and
## the road (a car that runs wide or lands off the road can get back on), and nothing tall where
## the track passes at any height.

const ROWS := ["StadiumControlRoadGlass", "StadiumControlRoadPub", "StadiumControlRoadCamera"]
const STANDS := "StadiumFabricStraight1x1"
const GATES := ["StadiumRoadMainStartLine", "StadiumRoadMainStartFinishLine", "StadiumRoadMainFinishLine"]
const STANDS_SPAN := [-1, 2]     ## the grandstands run from a cell behind the gate to two past it
## Raised gates get raised grandstands as TMNF builds them (A07): the stand on a stack of fabric
## pillars (the ground piece, then pieces three levels tall), so its level is G + 1 + 3k.
const STAND_PILLAR := "StadiumFabricPillarAir"
const WALL := "StadiumInflatablePillar"
const BILLBOARD := "StadiumInflatableAdvert"
const INFLATABLES := ["StadiumInflatablePalmTree", "StadiumInflatableCactus", "StadiumInflatableSnowTree"]
const SCULPTS := ["StadiumSculptA", "StadiumSculptB", "StadiumSculptC"]
## Blocks a run of straight road is made of (one cell on the ground).
const RUN_BLOCKS := ["StadiumRoadMain", "StadiumRoadMainTurbo", "StadiumRoadMainCheckpoint",
	"StadiumRoadMainStartLine", "StadiumRoadMainFinishLine"]
const G := TmTrackBuilder.GROUND_LEVEL


static func decorate(b: TmTrackBuilder, seed_text: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var road := _road_cells(b)
	var raised := _raised_cells(b)
	_stands(b, road)
	_checkpoint_cams(b, road)
	_curve_walls(b, road, raised)
	_rows(b, rng)
	_scatter(b, rng, road, INFLATABLES, 18, 2, 4, 2)
	_scatter(b, rng, road, SCULPTS, 2, 3, 8, 12)
	_airship(b, rng)


## The columns (x, z) the track uses at any height: raised road and its pillars too, so nothing
## tall stands beside a raised road where the car could catch it.
static func _road_cells(b: TmTrackBuilder) -> Dictionary:
	var out := {}
	for w: Vector3i in b._occupied:
		out[Vector2i(w.x, w.z)] = true
	return out


## The columns where the track is off the ground (raised road, its pillars).
static func _raised_cells(b: TmTrackBuilder) -> Dictionary:
	var out := {}
	for w: Vector3i in b._occupied:
		if w.y > G:
			out[Vector2i(w.x, w.z)] = true
	return out


## No column of `cols` within r cells (Chebyshev) of c.
static func _clear(cols: Dictionary, c: Vector2i, r: int) -> bool:
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			if cols.has(c + Vector2i(dx, dz)):
				return false
	return true


## Places block `id` turned by d with its units' lowest corner at `at` (the rotated units start at
## 0 on each axis) if every unit is on the map, free and off the track's columns; `ground`: its
## ground variant. Returns whether it did.
static func _try(b: TmTrackBuilder, road: Dictionary, id: String, at: Vector3i, d: int, flags := 0, ground := true) -> bool:
	var entry := TmBlockCatalogue.info(id)
	if entry.is_empty():
		return false
	var units := TmTrackBuilder._rotated_units(entry, d)
	for u: Array in units:
		var w: Vector3i = at + (u[0] as Vector3i)
		if w.x < 0 or w.z < 0 or w.x >= TmTrackBuilder.MAP or w.z >= TmTrackBuilder.MAP or b._occupied.has(w) \
				or road.has(Vector2i(w.x, w.z)):
			return false
	for u: Array in units:
		b._occupied[at + (u[0] as Vector3i)] = id
	var g := ground and at.y == G
	b.blocks.append({"name": id, "dir": d, "coord": at, "flags": flags | (TmTrackBuilder.GROUND_FLAG if g else 0), "ground": g})
	return true


## The turn that points a block's local +x along `v` (a unit step in x or z).
static func _facing(v: Vector2i) -> int:
	for d in 4:
		var r := TmTrackBuilder._rot(Vector2(1, 0), d)
		if Vector2i(roundi(r.x), roundi(r.y)) == v:
			return d
	return 0


## TMNF's white wave grandstands by the start and the finish: on each side of the gate a row of
## Fabric stands two cells out, facing the road, their roof arching over the cell between (48 m
## up), from a cell behind the gate to two past it, where the cells are clear. A gate two or more
## levels up gets them raised on fabric pillars, their seats at the pillar step nearest the road.
static func _stands(b: TmTrackBuilder, road: Dictionary) -> void:
	var entry := TmBlockCatalogue.info(STANDS)
	if entry.is_empty():
		return
	for blk: Dictionary in b.blocks.duplicate():
		var c: Vector3i = blk["coord"]
		if String(blk["name"]) not in GATES or (not bool(blk["ground"]) and c.y < G + 2):
			continue
		var steps := maxi(0, roundi(float(c.y - G - 2) / 3.0)) if c.y > G else -1
		var along := Vector2i(0, 1) if int(blk["dir"]) % 2 == 0 else Vector2i(1, 0)
		for s: int in [1, -1]:
			var out := Vector2i(along.y, along.x) * s
			# the stands are the block's +x cell (its roof's edge the -x one): +x points out
			var d := _facing(out)
			var units := TmTrackBuilder._rotated_units(entry, d)
			var stand_unit := Vector3i.ZERO
			for u: Array in units:
				if (u[0] as Vector3i).y == 0:
					stand_unit = u[0]
			for k in range(STANDS_SPAN[0], STANDS_SPAN[1] + 1):
				var cell := Vector2i(c.x, c.z) + along * k + out * 2
				if not _clear(road, cell, 1):
					continue
				if steps < 0:
					_try(b, road, STANDS, Vector3i(cell.x, G, cell.y) - Vector3i(stand_unit.x, 0, stand_unit.z), d)
					continue
				var level := G + 1 + 3 * steps
				var parts := [[STAND_PILLAR, Vector3i(cell.x, G, cell.y), true]]
				for j in steps:
					parts.append([STAND_PILLAR, Vector3i(cell.x, G + 1 + 3 * j, cell.y), false])
				parts.append([STANDS, Vector3i(cell.x, level, cell.y) - Vector3i(stand_unit.x, 0, stand_unit.z), false])
				_try_all(b, road, parts, d)


## Places every [id, at, ground] of `parts` (turned by d) if all of them fit, else none: each on
## the map, free and off the track's columns (as _try). Ground parts are one-unit blocks (their
## ground variant: TmTrackBuilder._rotated_units gives the raised one's units).
static func _try_all(b: TmTrackBuilder, road: Dictionary, parts: Array, d: int) -> bool:
	var cells := []
	var taken := {}
	for pt: Array in parts:
		var entry := TmBlockCatalogue.info(String(pt[0]))
		if entry.is_empty():
			return false
		var own := []
		var units := [[Vector3i.ZERO]] if bool(pt[2]) else TmTrackBuilder._rotated_units(entry, d)
		for u: Array in units:
			var w: Vector3i = (pt[1] as Vector3i) + (u[0] as Vector3i)
			if w.x < 0 or w.z < 0 or w.x >= TmTrackBuilder.MAP or w.z >= TmTrackBuilder.MAP or b._occupied.has(w) \
					or taken.has(w) or road.has(Vector2i(w.x, w.z)):
				return false
			taken[w] = true
			own.append(w)
		cells.append(own)
	for i in parts.size():
		var pt: Array = parts[i]
		for w: Vector3i in cells[i]:
			b._occupied[w] = String(pt[0])
		var g: bool = pt[2]
		b.blocks.append({"name": String(pt[0]), "dir": d, "coord": pt[1], "flags": TmTrackBuilder.GROUND_FLAG if g else 0,
			"ground": g})
	return true


## By each checkpoint on the ground, on both sides a cell out: a camera booth with its screens
## (CameraPub) at the gate and a light rig (CameraLight, its raised piece on the grass) either
## side of it along the road.
static func _checkpoint_cams(b: TmTrackBuilder, road: Dictionary) -> void:
	for blk: Dictionary in b.blocks.duplicate():
		if String(blk["name"]) != "StadiumRoadMainCheckpoint" or not bool(blk["ground"]):
			continue
		var c: Vector3i = blk["coord"]
		var along_z := int(blk["dir"]) % 2 == 0
		var along := Vector2i(0, 1) if along_z else Vector2i(1, 0)
		var d := 0 if along_z else 1
		for s: int in [1, -1]:
			var cell := Vector2i(c.x, c.z) + Vector2i(along.y, along.x) * s * 2
			if not _clear(road, cell, 1) or not _try(b, road, "StadiumControlCameraPub", Vector3i(cell.x, G, cell.y), d):
				continue
			for k: int in [-1, 1]:
				var w := cell + along * k
				if _clear(road, w, 1):
					_try(b, road, "StadiumControlLight", Vector3i(w.x, G, w.y), d, 0, false)


## Beyond the outside of each GT curve on the ground (straight on from where the car comes in, a
## free row between), TMNF's inflatable cushion wall: two cells deep and as long as the curve is
## wide, laid round its rectangle the editor's way (the T piece on each side, the corner pieces;
## the variant index says which, the direction follows it), with a billboard on the side facing
## the curve where nothing raised passes near.
static func _curve_walls(b: TmTrackBuilder, road: Dictionary, raised: Dictionary) -> void:
	# each ground curve's cells, and the way the line comes into it
	var curve_of := {}
	var curves := []
	for blk: Dictionary in b.blocks:
		var n := String(blk["name"])
		if not n.begins_with("StadiumRoadMainGTCurve") or not bool(blk["ground"]) or int(n.right(1)) < 3:
			continue
		var cells := []
		for u: Array in TmTrackBuilder._rotated_units(TmBlockCatalogue.info(n), int(blk["dir"])):
			var w: Vector3i = (blk["coord"] as Vector3i) + (u[0] as Vector3i)
			cells.append(Vector2i(w.x, w.z))
			curve_of[Vector2i(w.x, w.z)] = curves.size()
		curves.append({"cells": cells, "in": Vector2i.ZERO})
	if curves.is_empty():
		return
	for pt: Dictionary in b.path:
		var p: Vector3 = pt["p"]
		var cell := Vector2i(floori(-p.x / 32.0), floori(p.z / 32.0))
		if absf(p.y - (G * 8.0 + TmTrackBuilder.ROAD_Y)) > 1.0 or not curve_of.has(cell):
			continue
		var cv: Dictionary = curves[curve_of[cell]]
		if cv["in"] == Vector2i.ZERO:
			var dir := TmTrackBuilder.to_godot(pt["dir"])     # back to TMNF axes
			cv["in"] = Vector2i(signi(roundi(dir.x)), 0) if absf(dir.x) > absf(dir.z) else Vector2i(0, signi(roundi(dir.z)))
	for cv: Dictionary in curves:
		var f: Vector2i = cv["in"]
		if f == Vector2i.ZERO:
			continue
		var p := Vector2i(f.y, f.x).abs()
		var far := -1000000
		var lo := 1000000
		var hi := -1000000
		for c: Vector2i in cv["cells"]:
			far = maxi(far, c.x * f.x + c.y * f.y)
			lo = mini(lo, c.x * p.x + c.y * p.y)
			hi = maxi(hi, c.x * p.x + c.y * p.y)
		# the two rows (near, back) at 2 and 3 past the curve along f, trimmed to their clear
		# stretch: the cell at `row` along f and j across
		var at := func(row: int, j: int) -> Vector2i:
			return Vector2i(f.x * row + p.x * j, f.y * row + p.y * j)
		var ok := func(j: int) -> bool:
			for row: int in [far + 2, far + 3]:
				var w: Vector2i = at.call(row, j)
				if not _clear(road, w, 1) or not _free(b, w.x, w.y, 1):
					return false
			return true
		var span := []
		for j in range(lo, hi + 1):
			if ok.call(j):
				span.append(j)
			elif span.size() < 2:
				span.clear()
			else:
				break
		if span.size() < 2:
			continue
		var rect := []
		for j: int in span:
			rect.append(at.call(far + 2, j))
			rect.append(at.call(far + 3, j))
		_ring(b, road, rect)
		# the billboard: two cells of the near row, the middle of the wall
		var j0: int = span[(span.size() - 2) / 2]
		var pair: Array[Vector2i] = [at.call(far + 2, j0), at.call(far + 2, j0 + 1)]
		var near_edge := _edge_index(rect, pair[0])
		var high_ok := true
		for w in pair:
			high_ok = high_ok and _clear(raised, w, 2)
		if high_ok:
			var corner := Vector2i(mini(pair[0].x, pair[1].x), mini(pair[0].y, pair[1].y))
			_try(b, road, BILLBOARD, Vector3i(corner.x, G + 1, corner.y), near_edge % 4, near_edge, false)


## TMNF's variant index of a cell on a rectangle's rim (a rectasym block): the T piece on its
## -z, +x, +z, -x side is 4, 1, 2, 3, the corner at (+x, -z), (+x, +z), (-x, +z), (-x, -z) 5..8;
## 0 inside. Its direction: index % 4 for a T piece, index - 5 for a corner.
static func _edge_index(rect: Array, c: Vector2i) -> int:
	var mn := Vector2i(1000000, 1000000)
	var mx := -mn
	for w: Vector2i in rect:
		mn = Vector2i(mini(mn.x, w.x), mini(mn.y, w.y))
		mx = Vector2i(maxi(mx.x, w.x), maxi(mx.y, w.y))
	var ex := -1 if c.x == mn.x else (1 if c.x == mx.x else 0)
	var ez := -1 if c.y == mn.y else (1 if c.y == mx.y else 0)
	if ex != 0 and ez != 0:
		return {Vector2i(1, -1): 5, Vector2i(1, 1): 6, Vector2i(-1, 1): 7, Vector2i(-1, -1): 8}[Vector2i(ex, ez)]
	if ez == -1:
		return 4
	if ex == 1:
		return 1
	if ez == 1:
		return 2
	if ex == -1:
		return 3
	return 0


## An inflatable cushion wall one level high round the cells of a rectangle.
static func _ring(b: TmTrackBuilder, road: Dictionary, rect: Array) -> void:
	for c: Vector2i in rect:
		var idx := _edge_index(rect, c)
		if idx > 0:
			_try(b, road, WALL, Vector3i(c.x, G, c.y), idx % 4 if idx <= 4 else idx - 5, idx)


static func _free(b: TmTrackBuilder, x: int, z: int, levels: int) -> bool:
	if x < 0 or z < 0 or x >= TmTrackBuilder.MAP or z >= TmTrackBuilder.MAP:
		return false
	for y in range(G, G + levels):
		if b._occupied.has(Vector3i(x, y, z)):
			return false
	return true


static func _put(b: TmTrackBuilder, id: String, cell: Vector3i, dir: int, flags := 0, levels := 1) -> void:
	for y in levels:
		b._occupied[cell + Vector3i(0, y, 0)] = id
	var ground := cell.y == G
	b.blocks.append({"name": id, "dir": dir, "coord": cell, "flags": flags | (TmTrackBuilder.GROUND_FLAG if ground else 0),
		"ground": ground})


## Runs of three or more one-cell straight pieces on the ground, in the order they're driven:
## [{cells: [Vector2i], along_z: bool}].
static func _runs(b: TmTrackBuilder) -> Array:
	var runs := []
	var cur := {}
	for blk: Dictionary in b.blocks:
		var c: Vector3i = blk["coord"]
		var straight := String(blk["name"]) in RUN_BLOCKS and c.y == G and bool(blk["ground"]) \
			and (String(blk["name"]) != "StadiumRoadMain" or int(blk["flags"]) & 0x3F == 3)
		var along_z := int(blk["dir"]) % 2 == 0
		var cell := Vector2i(c.x, c.z)
		if straight and not cur.is_empty() and bool(cur["along_z"]) == along_z \
				and ((cur["cells"] as Array).back() as Vector2i).distance_squared_to(cell) == 1:
			(cur["cells"] as Array).append(cell)
			continue
		if not cur.is_empty() and (cur["cells"] as Array).size() >= 3:
			runs.append(cur)
		cur = {"cells": [cell], "along_z": along_z} if straight else {}
	if not cur.is_empty() and (cur["cells"] as Array).size() >= 3:
		runs.append(cur)
	return runs


## A row beside each long straight, on each side where the free cells allow (3+).
static func _rows(b: TmTrackBuilder, rng: RandomNumberGenerator) -> void:
	var kind := rng.randi() % ROWS.size()
	for run: Dictionary in _runs(b):
		var along_z: bool = run["along_z"]
		var sides := [1, -1] if rng.randf() < 0.5 else [-1, 1]
		for s: int in sides:
			# one empty cell between the road and the row: room for a car that runs wide or lands
			# off the road to get back on (next to the road, as TMNF has them, it got stuck on them)
			var off := Vector2i(s, 0) if along_z else Vector2i(0, s)
			var cells := []
			for c: Vector2i in run["cells"]:
				var w := c + off * 2
				var gap := c + off
				if _free(b, w.x, w.y, 3) and _free(b, gap.x, gap.y, 3):
					cells.append(w)
				elif cells.size() < 3:
					cells.clear()
				else:
					break
			if cells.size() < 3:
				continue
			cells.sort()      # increasing x (along x) or z (along z)
			var id: String = ROWS[kind % ROWS.size()]
			kind += 1
			for i in cells.size():
				var w: Vector2i = cells[i]
				var dir: int
				var flags := 3
				if i == 0:
					flags = 1
					dir = 0 if along_z else 3       # a dead end opens towards the row
				elif i == cells.size() - 1:
					flags = 1
					dir = 2 if along_z else 1
				else:
					dir = 0 if along_z else 1
				_put(b, id, Vector3i(w.x, G, w.y), dir, flags, 3)


## `count` blocks from `ids` on free grass between dmin and dmax cells (Chebyshev) from the road,
## free for `levels` levels up.
static func _scatter(b: TmTrackBuilder, rng: RandomNumberGenerator, road: Dictionary, ids: Array, count: int,
		dmin: int, dmax: int, levels: int) -> void:
	var spots := []
	for x in TmTrackBuilder.MAP:
		for z in TmTrackBuilder.MAP:
			if not _free(b, x, z, levels):
				continue
			var d := 99
			for dx in range(-dmax, dmax + 1):
				for dz in range(-dmax, dmax + 1):
					if road.has(Vector2i(x + dx, z + dz)):
						d = mini(d, maxi(absi(dx), absi(dz)))
			if d >= dmin and d <= dmax:
				spots.append(Vector2i(x, z))
	for i in count:
		if spots.is_empty():
			return
		var k := rng.randi() % spots.size()
		var p: Vector2i = spots[k]
		_put(b, String(ids[rng.randi() % ids.size()]), Vector3i(p.x, G, p.y), rng.randi() % 4, 0, levels)
		# keep them apart
		spots = spots.filter(func(q: Vector2i) -> bool: return maxi(absi(q.x - p.x), absi(q.y - p.y)) > 2)


## The airship, high over a free part of the field.
static func _airship(b: TmTrackBuilder, rng: RandomNumberGenerator) -> void:
	var entry := TmBlockCatalogue.info("StadiumAirship")
	if entry.is_empty():
		return
	for attempt in 30:
		var d := rng.randi() % 4
		var units := TmTrackBuilder._rotated_units(entry, d)
		var at := Vector3i(rng.randi_range(4, 22), 12, rng.randi_range(4, 22))
		var ok := true
		for u: Array in units:
			var w: Vector3i = at + (u[0] as Vector3i)
			if b._occupied.has(w) or w.x >= TmTrackBuilder.MAP or w.z >= TmTrackBuilder.MAP:
				ok = false
				break
		if ok:
			for u: Array in units:
				b._occupied[at + (u[0] as Vector3i)] = "StadiumAirship"
			b.blocks.append({"name": "StadiumAirship", "dir": d, "coord": at, "flags": 0, "ground": false})
			return
