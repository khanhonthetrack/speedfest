class_name TmTrackDecor
extends RefCounted
## Dresses our tracks the way TMNF's are dressed (the campaign: thousands of Control rows,
## inflatables and sculptures around the roads): rows of glass booths, advert boards and camera
## booms beside the straights (the Control "road" blocks, laid as a straight network a cell away
## from the road, dead ends at both ends), inflatable palm trees, cacti and snow trees on the
## grass near the track, sculptures further out, and the airship over the field. Seeded by the
## track's id, so a track always looks the same; only on cells nothing else uses.

const ROWS := ["StadiumControlRoadGlass", "StadiumControlRoadPub", "StadiumControlRoadCamera"]
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
