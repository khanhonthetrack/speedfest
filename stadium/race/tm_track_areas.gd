class_name TmTrackAreas
extends RefCounted
## The track builder's area surfaces (TmTrackBuilder ["platform", w] / ["circuit", w]): TMNF's
## platform and circuit, laid the way its campaign lays them (docs/research/m9_campaign.md). They
## have no clips: a lane is the cells within w * 16 m of the line the car follows (its centre,
## rasterised as it goes), filled with plates once the track is laid: StadiumPlatformRoad (its
## variant from the platform cells around it, like a road's) or StadiumCircuitBase. Gates, turbos,
## slopes and the joins to the road are blocks placed in the lane as it goes. Then, like TMNF's
## editor: every side of a circuit that faces nothing gets its border in the empty cell beyond
## (CircuitBorderStraight facing the plate, CornerIn where two plates meet, CornerOut round the
## outside of a corner), and a platform lane with walls gets a StadiumPlatformWallBorder above each
## open edge. Rules measured from the official tracks: a border's local +z faces its plate; a
## gate or turbo runs along its local z; slopes climb 2 levels a block, 1 more over the start and
## the end (platform straights sit a level higher than circuit straights).

const DECK := 8.0                     ## a plate's top above its level's base (m)
const KINDS := ["platform", "circuit"]
const SLOPES := {
	"platform": {"start": "StadiumPlatformBiSlope2Start", "straight": "StadiumPlatformSlope2Straight",
		"end": "StadiumPlatformBiSlope2End", "straight_dy": 1, "end_dy": 1},
	"circuit": {"start": "StadiumCircuitSlopeStart", "straight": "StadiumCircuitSlopeStraight",
		"end": "StadiumCircuitSlopeEnd", "straight_dy": 0, "end_dy": 0},
}
const SLOPE_BORDERS := {"StadiumCircuitSlopeStart": "Start", "StadiumCircuitSlopeStraight": "Straight",
	"StadiumCircuitSlopeEnd": "End"}

var b: TmTrackBuilder
var cells := {}                        ## Vector3i -> "platform" | "circuit": plates to fill
var lane := {}                         ## Vector3i -> kind: blocks laid in a lane (gates, turbos, joins, slopes)
var walled := {}                       ## Vector3i (a plate) -> true: its open edges get walls
var _slope_cells: Array = []           ## [cell, dir, id, kind]: circuit slope blocks (their side borders)


func _init(builder: TmTrackBuilder) -> void:
	b = builder


## The lane's cells along the line from a to b (TMNF metres, at the lane's level): every cell whose
## centre lies within w * 16 m of it (a little less, so a straight lane is exactly w wide).
func brush(from: Vector3, to: Vector3, level: int) -> void:
	var half := b.width * 16.0 - 1.0
	var n := maxi(1, ceili(from.distance_to(to) / 2.0))
	for i in n + 1:
		_dab(from.lerp(to, float(i) / n), level, half)


func brush_arc(points: Array, level: int) -> void:
	var half := b.width * 16.0 - 1.0
	for i in range(1, points.size()):
		var p: Vector3 = points[i - 1]
		var q: Vector3 = points[i]
		var n := maxi(1, ceili(p.distance_to(q) / 2.0))
		for k in n + 1:
			_dab(p.lerp(q, float(k) / n), level, half)


func _dab(p: Vector3, level: int, half: float) -> void:
	var r := ceili(half / 32.0) + 1
	var cx := floori(p.x / 32.0)
	var cz := floori(p.z / 32.0)
	for x in range(cx - r, cx + r + 1):
		for z in range(cz - r, cz + r + 1):
			var c := Vector3i(x, level, z)
			if cells.has(c) or x < 0 or z < 0 or x >= TmTrackBuilder.MAP or z >= TmTrackBuilder.MAP:
				continue
			if Vector2((x + 0.5) * 32.0 - p.x, (z + 0.5) * 32.0 - p.z).length() <= half:
				cells[c] = b.surface
				if b.lane_walls:
					walled[c] = true


## Puts block id at coord turned d, in the lane (its cells must be free). Returns false (and notes
## an error) if it doesn't fit.
func put(id: String, coord: Vector3i, d: int, flags := 0) -> bool:
	var entry := TmBlockCatalogue.info(id)
	if entry.is_empty():
		b.errors.append("unknown block %s" % id)
		return false
	var placed := b.put(id, coord, d, flags)
	if placed.is_empty():
		return false
	for w: Vector3i in placed:
		if w.y == coord.y:          # its bottom cells (a gate's arch above isn't the lane)
			lane[w] = b.surface
	return true


## The cells across the lane at the turtle (its centre, then the sides out to the lane's width).
func row() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var side := TmTrackBuilder.SIDE[posmod(b.heading + 1, 4)]
	var k := (b.width - 1) / 2
	for i in range(-k, k + 1):
		out.append(b.cell + side * i)
	return out


# --- pieces ---------------------------------------------------------------------------------

func piece(p: Array) -> void:
	var kind := String(p[0])
	match kind:
		"s":
			for _i in (int(p[1]) if p.size() > 1 else 1):
				_straight()
		"l", "r":
			_turn(kind == "l", 1)
		"gt":
			_turn(String(p[2]) == "l", clampi(int(p[1]), 2, 5))
		"cp":
			_gate()
		"turbo":
			_turbo()
		"up", "climb":
			_slope(true, int(p[1]) if kind == "climb" and p.size() > 1 else 0)
		"down", "dive":
			_slope(false, int(p[1]) if kind == "dive" and p.size() > 1 else 0)
		_:
			b.errors.append("%s can't be laid on %s (piece %d)" % [kind, b.surface, b.piece_count()])


func _straight() -> void:
	var a := b.entry_face()
	b.cell += TmTrackBuilder.SIDE[b.heading]
	var z := b.entry_face()
	brush(a, z, b.cell.y)
	b.segment(a, b.heading, z, b.heading)


## A turn of the lane's centre about the inner corner of an m x m square (m at least the lane's
## half width, so the inner edge doesn't fold).
func _turn(left: bool, m: int) -> void:
	m = maxi(m, (b.width + 1) / 2)
	var h := b.heading
	var h2 := posmod(h + (1 if left else -1), 4)
	var a := b.entry_face()
	b.cell += TmTrackBuilder.SIDE[h] * (m - 1) + TmTrackBuilder.SIDE[h2] * m
	b.heading = h2
	var z := b.entry_face()
	var from := b.path.size()
	b.segment(a, h, z, h2, 32.0 * m - 16.0)
	var pts: Array = [a]
	for i in range(from, b.path.size()):
		pts.append(TmTrackBuilder.to_godot(b.path[i]["p"]))
	brush_arc(pts, b.cell.y)


## A gate: the platform checkpoint, across a one-cell lane (TMNF's gates are one cell wide).
func _gate() -> void:
	if b.width != 1:
		b.errors.append("a gate needs a one-cell lane (piece %d): set the width to 1 before it" % b.piece_count())
		return
	if not put("StadiumPlatformCheckpoint", b.cell, b.heading):
		return
	_straight()


## A row of turbo plates across the lane (each boosts along the way the car goes).
func _turbo() -> void:
	for c in row():
		if not put("StadiumPlatformTurbo", c, b.heading):
			return
	_straight()


## A slope up (or down) the lane: the start, n straights, the end, across its width; 2n + 2 levels
## over n + 2 blocks. Down is the same blocks turned round, laid from the top.
func _slope(up: bool, n: int) -> void:
	var sl: Dictionary = SLOPES[b.surface]
	var top_rise := 2 * n + 2
	var bottom := b.cell.y if up else b.cell.y - top_rise
	if bottom < TmTrackBuilder.GROUND_LEVEL + 1:
		b.errors.append("the slope (piece %d) goes below level 2" % b.piece_count())
		return
	# the blocks bottom to top: [id, level]
	var seq: Array = [[sl["start"], bottom]]
	for i in n:
		seq.append([sl["straight"], bottom + 1 + int(sl["straight_dy"]) + 2 * i])
	seq.append([sl["end"], bottom + 1 + int(sl["end_dy"]) + 2 * n])
	if not up:
		seq.reverse()
	var d := b.heading if up else posmod(b.heading + 2, 4)
	var y0 := float(b.cell.y) * 8.0 + DECK
	var a := b.entry_face()
	for k in seq.size():
		var id := String(seq[k][0])
		var level := int(seq[k][1])
		var start := b.cell
		for c in row():
			var at := Vector3i(c.x, level, c.z)
			if not put(id, at, d):
				return
			if b.surface == "circuit":
				_slope_cells.append([at, d, id])
		b.cell += TmTrackBuilder.SIDE[b.heading]
		# heights along the slope: +1 level over the start and the end, +2 over a straight
		var rise := 8.0 if (id == sl["start"] or id == sl["end"]) else 16.0
		var y1 := y0 + (rise if up else -rise)
		var z := Vector3((start.x + 0.5) * 32.0, y1, (start.z + 0.5) * 32.0) + TmTrackBuilder.vec(b.heading) * 16.0
		b.segment(a, b.heading, z, b.heading)
		if (up and id == sl["end"]) or (not up and id == sl["start"]):
			b.path[b.path.size() - 1]["rv"] = TmTrackBuilder.CREST_R
		a = z
		y0 = y1
	b.cell.y = bottom + top_rise if up else bottom


# --- after the track is laid ---------------------------------------------------------------

## The plates, then the circuit's borders and the platform's walls.
func finish() -> void:
	for c: Vector3i in cells.keys():
		if b.occupied(c):
			continue
		var kind := String(cells[c])
		if kind == "circuit":
			b.put("StadiumCircuitBase", c, 0, 0, true)
		else:
			var v := _plate_variant(c)
			b.put("StadiumPlatformRoad", c, int(v["dir"]), int(v["flags"]), true)
	_borders()
	_slope_borders()
	_walls()


func _is_area(c: Vector3i, kind: String) -> bool:
	return String(cells.get(c, "")) == kind or String(lane.get(c, "")) == kind


## A platform plate's variant: open towards the platform around it (plates, gates, turbos, slopes).
func _plate_variant(c: Vector3i) -> Dictionary:
	var open: Array[int] = []
	for s in 4:
		if _is_area(c + TmTrackBuilder.SIDE[s], "platform"):
			open.append(s)
	var pick := "Base"
	match open.size():
		1:
			pick = "Deadend"
		2:
			pick = "Straight" if posmod(open[1] - open[0], 4) == 2 else "Corner"
		3:
			pick = "TShaped"
		4:
			pick = "Cross"
	var local: Array = TmUserTracks.ROAD_SHAPES[pick][1]
	for d in 4:
		var turned: Array[int] = []
		for s: int in local:
			turned.append(posmod(s + d, 4))
		turned.sort()
		if turned == open or local.is_empty():
			return {"flags": int(TmUserTracks.ROAD_SHAPES[pick][0]), "dir": d}
	return {"flags": int(TmUserTracks.ROAD_SHAPES[pick][0]), "dir": 0}


## TMNF's circuit borders in the empty cells round the circuit: straight (facing the plate),
## inner corners (plates on two sides), then outer corners (a plate only across the diagonal).
func _borders() -> void:
	var circuit: Array = []
	for c: Vector3i in cells.keys():
		if String(cells[c]) == "circuit":
			circuit.append(c)
	for c: Vector3i in lane.keys():
		if String(lane[c]) == "circuit" and not circuit.has(c):
			circuit.append(c)
	var done := {}
	for c: Vector3i in circuit:
		for s in 4:
			var x: Vector3i = c + TmTrackBuilder.SIDE[s]
			if done.has(x) or b.occupied(x) or not b.inside(x):
				continue
			done[x] = true
			var sides: Array[int] = []
			for t in 4:
				if _is_area(x + TmTrackBuilder.SIDE[t], "circuit") and not _is_slope(x + TmTrackBuilder.SIDE[t]):
					sides.append(t)
			if sides.size() == 1:
				b.put("StadiumCircuitBorderStraight", x, sides[0], 0, true)
			elif sides.size() == 2 and posmod(sides[1] - sides[0], 4) != 2:
				var s2 := sides[1] if posmod(sides[1] - sides[0], 4) == 1 else sides[0]
				b.put("StadiumCircuitBorderCornerIn", x, s2, 0, true)
	# outer corners: an empty cell with circuit across one diagonal and borders on its two sides
	for c: Vector3i in circuit:
		for s in 4:
			var x: Vector3i = c - TmTrackBuilder.SIDE[s] - TmTrackBuilder.SIDE[posmod(s + 1, 4)]
			if b.occupied(x) or not b.inside(x):
				continue
			if String(b.occupant(x + TmTrackBuilder.SIDE[s])).begins_with("StadiumCircuitBorder") \
					and String(b.occupant(x + TmTrackBuilder.SIDE[posmod(s + 1, 4)])).begins_with("StadiumCircuitBorder"):
				b.put("StadiumCircuitBorderCornerOut", x, s, 0, true)


func _is_slope(c: Vector3i) -> bool:
	return String(b.occupant(c)).begins_with("StadiumCircuitSlope")


## The walls beside a circuit slope (TMNF's slope borders: the same turn as the slope, "Left" on
## its +x side, "Right" on its -x side), where the cell beside isn't the lane's.
func _slope_borders() -> void:
	for sc: Array in _slope_cells:
		var at: Vector3i = sc[0]
		var d: int = sc[1]
		var part := String(SLOPE_BORDERS[String(sc[2])])
		for side: Array in [["Left", 3], ["Right", 1]]:
			var x: Vector3i = at + TmTrackBuilder.SIDE[posmod(int(side[1]) + d, 4)]
			if b.occupied(x) or not b.inside(x):
				continue
			b.put("StadiumCircuitBorderSlope%s%s" % [part, side[0]], x, d, 0, true)


## A walled platform lane: a StadiumPlatformWallBorder on every open edge, a level above the plate
## (its local -z, where the wall stands, against the plate's edge).
func _walls() -> void:
	for c: Vector3i in walled.keys():
		if String(cells.get(c, "")) != "platform":
			continue
		for s in 4:
			var x: Vector3i = c + TmTrackBuilder.SIDE[s]
			if _is_area(x, "platform") or b.occupied(x):
				continue
			var up := x + Vector3i(0, 1, 0)
			if b.occupied(up) or not b.inside(up):
				continue
			b.put("StadiumPlatformWallBorder", up, s, 0, true)
