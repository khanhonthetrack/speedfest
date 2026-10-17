class_name TmTrackBuilder
extends RefCounted
## Our own tracks (the game is standalone; TMNF's tracks and .Challenge.Gbx files are extras). A
## track is a list of pieces laid end to end on the 32 x 8 x 32 m block grid, like a turtle: each
## piece is a Stadium block whose entry and exit come from the block catalogue's clip sides, turned
## to fit, so a piece list becomes the same block list a .Challenge.Gbx gives (a TmChallenge),
## plus the line a car should follow through it (`path`, for the driving bot, TmBot).
##
## A track spec (tracks/*.json): {"id", "name", "author", "start": [x, y, z, heading], "pieces":
## [...], "medals": {"author", "gold", "silver", "bronze"} (ms)}. Pieces:
##   ["start"], ["finish"], ["cp"] (a checkpoint), ["turbo"], ["s", n] (n straight road blocks),
##   ["l"] / ["r"] (a road corner), ["gt", 2..5, "l" | "r"] (a GT curve of that size),
##   ["up"] / ["down"] (a slope one level up / down), ["up2"] / ["down2"] (two levels),
##   ["jump", gap] (a low ramp, then gap empty blocks; ["jump", gap, "high"]: the high ramp),
##   ["loop", "l" | "r"] (a full loop, coming out 4 blocks to that side), ["block", id] (any block
##   with two clips, entered at its first).
## Headings (and clip sides): 0 +z, 1 -x, 2 -z, 3 +x in TMNF's block axes (x right of +z); a left
## turn adds one. The map is 32 x 32 blocks; level 1 is the ground.

const GROUND_LEVEL := 1
const GROUND_FLAG := 4096
const MAP := 32
const SIDE: Array[Vector3i] = [Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(1, 0, 0)]
const ROAD_Y := 1.345            ## the road's top above its level's base (m)
const LOOP_R := 44.0             ## the loops' radius (blocks/shapes/road.gd LOOP_BASE_R)
const LOOP_SHIFT := 64.0         ## and how far each half turn drifts sideways (LOOP_FRAMES m)
const STEP := 8.0                ## path point spacing (m)

enum Drive { STEER, BLIND }      ## a path point: steer towards it, or hold straight (loops, jumps)

var blocks: Array = []           ## [{name, dir, coord, flags, ground}] like TmChallenge.blocks
## The line to drive: [{p: Vector3 (Godot), dir: Vector3 (Godot, unit), mode: Drive, r: float
## (the turn's radius there, m; 0 straight)}].
var path: Array = []
var errors: Array[String] = []
var checkpoints := 0
var cell := Vector3i(16, GROUND_LEVEL, 2)
var heading := 0
var _occupied := {}


## Lays out a track spec.
static func build(spec: Dictionary) -> TmTrackBuilder:
	var b := TmTrackBuilder.new()
	var s: Array = spec.get("start", [16, GROUND_LEVEL, 2, 0])
	b.cell = Vector3i(int(s[0]), int(s[1]), int(s[2]))
	b.heading = posmod(int(s[3]), 4)
	for p: Array in spec.get("pieces", []):
		b.piece(p)
		if not b.errors.is_empty():
			break
	if b.errors.is_empty():
		b.add_pillars()
	return b


## Pillars under raised road, the way TMNF's tracks hold it up: under every other one-block piece
## off the ground, a StadiumTube right under the road and StadiumTubePillars down to the ground
## (turned across the road), where nothing else is in the way.
func add_pillars() -> void:
	var n := 0
	for blk: Dictionary in blocks.duplicate():
		var c: Vector3i = blk["coord"]
		var entry := TmBlockCatalogue.info(String(blk["name"]))
		if c.y <= GROUND_LEVEL or TmBlockCatalogue.footprint(entry, false) != Vector3i.ONE \
				and String(blk["name"]) not in ["StadiumRoadMainCheckpoint", "StadiumRoadMainStartLine", "StadiumRoadMainFinishLine"]:
			continue
		n += 1
		if n % 2 == 0:
			continue
		var free := true
		for y in range(GROUND_LEVEL, c.y):
			free = free and not _occupied.has(Vector3i(c.x, y, c.z))
		if not free:
			continue
		# across the road: a straight runs along z when its dir is even (and so do the others here)
		var d := int(blk["dir"]) % 2
		for y in range(GROUND_LEVEL, c.y):
			var id := "StadiumTube" if y == c.y - 1 else "StadiumTubePillar"
			var w := Vector3i(c.x, y, c.z)
			_occupied[w] = id
			blocks.append({"name": id, "dir": d, "coord": w, "flags": GROUND_FLAG if y == GROUND_LEVEL else 0, "ground": y == GROUND_LEVEL})


## The TmChallenge of a track spec (uid "SF-<id>"; its `path` is the bot's line).
static func challenge(spec: Dictionary) -> TmChallenge:
	var b := build(spec)
	var ch := TmChallenge.new()
	ch.uid = "SF-" + String(spec.get("id", "track"))
	ch.name = String(spec.get("name", "Track"))
	ch.author = String(spec.get("author", "SpeedFest"))
	ch.environment = "Stadium"
	ch.decoration = "Day"
	var m: Dictionary = spec.get("medals", {})
	ch.author_ms = int(m.get("author", -1))
	ch.gold_ms = int(m.get("gold", -1))
	ch.silver_ms = int(m.get("silver", -1))
	ch.bronze_ms = int(m.get("bronze", -1))
	ch.blocks = b.blocks
	ch.path = b.path
	if not b.errors.is_empty():
		ch.error = "track %s: %s" % [spec.get("id", "?"), "; ".join(b.errors)]
	return ch


# --- placing blocks -------------------------------------------------------------------------

static func _rot(v: Vector2, d: int) -> Vector2:
	for _i in posmod(d, 4):
		v = Vector2(-v.y, v.x)
	return v


## A block's units turned by dir d: [[unit cell relative to the block's coord, [clip per side]]].
static func _rotated_units(entry: Dictionary, d: int) -> Array:
	var units: Array = TmBlockCatalogue.variant(entry, false).get("units", [])
	if units.is_empty():
		units = TmBlockCatalogue.variant(entry, true).get("units", [])
	var size := TmBlockCatalogue.footprint(entry, false)
	var minx := INF
	var minz := INF
	for c: Vector2 in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.z), Vector2(size.x, size.z)]:
		var p := _rot(c, d)
		minx = minf(minx, p.x)
		minz = minf(minz, p.y)
	var out := []
	for u: Array in units:
		var c := _rot(Vector2(float(u[0]) + 0.5, float(u[2]) + 0.5), d)
		out.append([Vector3i(floori(c.x - minx), int(u[1]), floori(c.y - minz)), u[3] if u.size() > 3 else []])
	return out


## Places block `id` so that its clip number `entry_clip` (clips counted unit by unit, side by side)
## takes the car at `cell` coming in along `heading`; with entry_clip -1, so that clip `exit_clip`
## faces along `heading` from `cell` (a start). `sides`: a road block's open sides (its variant).
## Returns {coord, dir, exit_cell, exit_heading} (exit_clip -1: on out of the entry unit's far
## side), or {} after noting an error.
func place(id: String, entry_clip: int, exit_clip: int, flags := 0, sides: Array = []) -> Dictionary:
	var entry := TmBlockCatalogue.info(id)
	if entry.is_empty():
		errors.append("unknown block %s" % id)
		return {}
	var has_ground: bool = not TmBlockCatalogue.variant(entry, true).get("units", []).is_empty()
	for d in 4:
		var units := _rotated_units(entry, d)
		var clips := []      # [unit index, world side]
		if sides.is_empty():
			for i in units.size():
				var cl: Array = units[i][1]
				for s in cl.size():
					if not String(cl[s]).is_empty():
						clips.append([i, posmod(s + d, 4)])
		else:
			for s: int in sides:
				clips.append([0, posmod(s + d, 4)])
		if entry_clip >= clips.size() or exit_clip >= clips.size():
			continue
		var anchor_unit: int
		if entry_clip >= 0:
			if int(clips[entry_clip][1]) != posmod(heading + 2, 4):
				continue
			anchor_unit = int(clips[entry_clip][0])
		else:
			if int(clips[exit_clip][1]) != heading:
				continue
			anchor_unit = int(clips[exit_clip][0])
		var anchor: Vector3i = units[anchor_unit][0]
		var coord := cell - anchor
		var cells := []
		for u: Array in units:
			var w: Vector3i = coord + (u[0] as Vector3i)
			if w.x < 0 or w.z < 0 or w.x >= MAP or w.z >= MAP or w.y < GROUND_LEVEL:
				errors.append("%s at %s leaves the map (unit %s)" % [id, coord, w])
				return {}
			if _occupied.has(w):
				errors.append("%s at %s runs into %s (unit %s)" % [id, coord, _occupied[w], w])
				return {}
			cells.append(w)
		for w: Vector3i in cells:
			_occupied[w] = id
		var ground: bool = has_ground and coord.y == GROUND_LEVEL
		blocks.append({"name": id, "dir": d, "coord": coord, "flags": flags | (GROUND_FLAG if ground else 0), "ground": ground})
		if int(entry.get("waypoint", 3)) == TmBlockCatalogue.Waypoint.CHECKPOINT:
			checkpoints += 1
		var out := {"coord": coord, "dir": d}
		if exit_clip >= 0:
			var ex: Array = clips[exit_clip]
			out["exit_cell"] = coord + (units[int(ex[0])][0] as Vector3i) + SIDE[int(ex[1])]
			out["exit_heading"] = int(ex[1])
		else:
			out["exit_cell"] = cell + SIDE[heading]
			out["exit_heading"] = heading
		return out
	errors.append("%s fits no turn at %s heading %d" % [id, cell, heading])
	return {}


## Places a block with an entry and an exit, adds the line through it and moves on past it.
## r: the turn's radius (m) for the path when it turns.
func _through(id: String, entry_clip: int, exit_clip: int, r := 0.0, flags := 0, sides: Array = []) -> bool:
	var a := entry_face()
	var h := heading
	var res := place(id, entry_clip, exit_clip, flags, sides)
	if res.is_empty():
		return false
	cell = res["exit_cell"]
	heading = res["exit_heading"]
	_segment(a, h, entry_face(), heading, r)
	return true


# --- the line through the track ---------------------------------------------------------------

## A cell's centre on its road (TMNF metres).
static func centre(c: Vector3i) -> Vector3:
	return Vector3((c.x + 0.5) * 32.0, c.y * 8.0 + ROAD_Y, (c.z + 0.5) * 32.0)


static func vec(h: int) -> Vector3:
	var s: Vector3i = SIDE[posmod(h, 4)]
	return Vector3(s.x, 0, s.z)


static func to_godot(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, p.z)


## Where the car enters the current cell (TMNF metres): the middle of the face it comes through.
func entry_face() -> Vector3:
	return centre(cell) - vec(heading) * 16.0


func _point(p: Vector3, dir: Vector3, mode := Drive.STEER, r := 0.0) -> void:
	path.append({"p": to_godot(p), "dir": to_godot(dir).normalized(), "mode": mode, "r": r})


## The line from a (heading ha) to b (heading hb), both TMNF metres: straight on, or a quarter
## circle when the heading turns.
func _segment(a: Vector3, ha: int, b: Vector3, hb: int, r := 0.0, mode := Drive.STEER) -> void:
	if ha == hb:
		var n := maxi(1, ceili(a.distance_to(b) / STEP))
		for i in range(1, n + 1):
			_point(a.lerp(b, float(i) / n), vec(ha), mode, 0.0)
		return
	var f0 := vec(ha)
	var f1 := vec(hb)
	var rr := absf((b - a).dot(f0))
	var o := a + f1 * rr
	var n := maxi(2, ceili(rr * PI * 0.5 / STEP))
	for i in range(1, n + 1):
		var t := float(i) / n * PI * 0.5
		var p := o - f1 * rr * cos(t) + f0 * rr * sin(t)
		p.y = lerpf(a.y, b.y, float(i) / n)
		_point(p, f0 * cos(t) + f1 * sin(t), mode, r if r > 0.0 else rr)


# --- pieces -------------------------------------------------------------------------------------

func piece(p: Array) -> void:
	var kind := String(p[0])
	match kind:
		"start":
			var res := place("StadiumRoadMainStartLine", -1, 0)
			if not res.is_empty():
				cell = res["exit_cell"]
				heading = res["exit_heading"]
				_point(entry_face(), vec(heading))
		"finish":
			var a := entry_face()
			if place("StadiumRoadMainFinishLine", 0, -1).is_empty():
				return
			# on through the finish and a block past it
			_segment(a, heading, a + vec(heading) * 64.0, heading)
		"cp":
			_through("StadiumRoadMainCheckpoint", 1, 0)
		"turbo":
			_through("StadiumRoadMainTurbo", 1, 0)
		"s":
			for _i in (int(p[1]) if p.size() > 1 else 1):
				if not _through("StadiumRoadMain", 0, 1, 0.0, 3, [0, 2]):
					return
		"l", "r":
			# a road corner joins sides dir and dir + 1
			_through("StadiumRoadMain", 0, 1, 16.0, 2, [1, 0] if kind == "l" else [0, 1])
		"gt":
			var k := clampi(int(p[1]), 2, 5)
			# clip 0 on side 1 of the first unit, clip 1 on side 0 of the last: in at 0 turns left
			_through("StadiumRoadMainGTCurve%d" % k, 0 if String(p[2]) == "l" else 1,
				1 if String(p[2]) == "l" else 0, 32.0 * k - 16.0)
		"up":
			_through("StadiumRoadMainSlopeBase", 0, 1)
		"down":
			_through("StadiumRoadMainSlopeBase", 1, 0)
		"up2":
			_through("StadiumRoadMainSlopeBase2", 0, 1)
		"down2":
			_through("StadiumRoadMainSlopeBase2", 1, 0)
		"jump":
			_jump(int(p[1]) if p.size() > 1 else 2, p.size() > 2 and String(p[2]) == "high")
		"loop":
			_loop(String(p[1]) == "r" if p.size() > 1 else false)
		"block":
			_through(String(p[1]), 0, 1)
		_:
			errors.append("unknown piece %s" % kind)


## A ramp (its open side towards the car) and `gap` empty blocks to fly over.
func _jump(gap: int, high: bool) -> void:
	var a := entry_face()
	var res := place("StadiumRamp" if high else "StadiumRampLow", 0, -1)
	if res.is_empty():
		return
	_segment(a, heading, a + vec(heading) * 32.0, heading)
	var lip := a + vec(heading) * 32.0
	cell = res["exit_cell"]
	for i in gap:
		cell += SIDE[heading]
	_segment(lip, heading, entry_face(), heading, 0.0, Drive.BLIND)


## A full loop: two loop blocks (TMNF's way: the second turned round, behind and beside the
## first, their tops meeting), coming out 4 blocks to the right (or left) heading the same way.
## StadiumLoopLeft's exit shifts right, StadiumLoopRight's left.
func _loop(right: bool) -> void:
	var id := "StadiumLoopLeft" if right else "StadiumLoopRight"
	var h := heading
	var e := cell
	var side_h := posmod(h - 1 if right else h + 1, 4)
	var face := entry_face()
	if place(id, 0, -1).is_empty():
		return
	cell = e - SIDE[h] + SIDE[side_h] * 4
	heading = posmod(h + 2, 4)
	if place(id, 0, -1).is_empty():
		return
	cell = e + SIDE[side_h] * 4
	heading = h
	# the line: a helix (blocks/shapes/road.gd _loop: each half turn drifts 64 m sideways), up
	# through the first block, over the top above the entry and down through the second
	var f := vec(h)
	var lat := vec(side_h)
	var n := 48
	for i in range(1, n + 1):
		var th := TAU * float(i) / n
		var p := face + lat * (LOOP_SHIFT * th / PI) + Vector3(0, LOOP_R * (1.0 - cos(th)), 0) + f * (LOOP_R * sin(th))
		var t := lat * (LOOP_SHIFT / PI) + Vector3(0, LOOP_R * sin(th), 0) + f * (LOOP_R * cos(th))
		_point(p, t.normalized())
