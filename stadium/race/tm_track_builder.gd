class_name TmTrackBuilder
extends RefCounted
## Our own tracks (the game is standalone; TMNF's tracks and .Challenge.Gbx files are extras). A
## track is a list of pieces laid end to end on the 32 x 8 x 32 m block grid, like a turtle: each
## piece is a Stadium block whose entry and exit come from the block catalogue's clip sides, turned
## to fit, so a piece list becomes the same block list a .Challenge.Gbx gives (a TmChallenge),
## plus the line a car should follow through it (`path`, for the driving bot, TmBot).
##
## A track spec (tracks/*.json): {"id", "name", "author", "start": [x, y, z, heading], "pieces":
## [...], "medals": {"author", "gold", "silver", "bronze"} (ms), "laps": n (a lap race: the start
## is TMNF's start/finish line and the pieces end with ["close"], back onto it), "mood": "night"
## (raced at night; default day), "scenery": "city" (towers around the road, TmSkyline.field)}. Pieces:
##   ["start"], ["finish"], ["cp"] (a checkpoint), ["turbo"], ["s", n] (n straight road blocks),
##   ["l"] / ["r"] (a road corner), ["gt", 2..5, "l" | "r"] (a GT curve of that size),
##   ["up"] / ["down"] (a slope one level up / down), ["up2"] / ["down2"] (two levels),
##   ["climb", n] / ["dive", n] (a long hill, n + 2 levels up / down over n + 4 blocks: TMNF's
##   slope start (2 blocks), n slope blocks, its slope end (2 blocks); ["climb", n, "cp" | "turbo"]:
##   the middle slope block a checkpoint or a turbo),
##   ["jump", gap] (a low ramp, then gap empty blocks; ["jump", gap, "high"]: the high ramp),
##   ["loop", "l" | "r"] (a full loop, coming out 4 blocks to that side), ["block", id] (any block
##   with two clips, entered at its first).
##   ["fork", "l" | "r", [pieces]] (a T junction: the pieces in the list leave it to that side, a
##   second way to its own finish (after the last checkpoint); the track goes on straight),
##   ["split", "l" | "r", [pieces]] (right after a rooftop 3 cells wide or more: the pieces leave its
##   far edge a cell to that side of the road, side by side with it, at full speed),
##   and the Sky maps' road of our own (TmSkyTrack: walls, faces, twists, banks, kickers, gaps,
##   drops, rooftops; "scenery": "sky").
## Surfaces (the pieces after it are laid on it; the join is placed where it changes):
##   ["road"] (the default: TMNF's Road/Main), ["dirt"] (dirt road on the ground: s, l, r, gt 2-3,
##   cp; joined to the road by StadiumRoadDirtToRoad), ["platform", w] / ["platform", w, "walls"]
##   and ["circuit", w] (lanes w cells wide, w odd: s, l, r, gt, cp (on a one-cell lane), turbo,
##   up, down, climb, dive; joined to the road a level above by StadiumPlatformToRoadMain;
##   TmTrackAreas lays their plates, borders and walls).
## Headings (and clip sides): 0 +z, 1 -x, 2 -z, 3 +x in TMNF's block axes (x right of +z); a left
## turn adds one. The map is 32 x 32 blocks; level 1 is the ground.

const GROUND_LEVEL := 1
const GROUND_FLAG := 4096
const MAP := 32
const SIDE: Array[Vector3i] = [Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(1, 0, 0)]
const ROAD_Y := 1.345            ## the road's top above its level's base (m)
const LOOP_R := 44.0 - ROAD_Y    ## the loop road's radius (blocks/shapes/road.gd: LOOP_BASE_R less TOP)
const LOOP_SHIFT := 64.0         ## and how far each half turn drifts sideways (LOOP_FRAMES m)
const LOOP_EASE := 40.0          ## the line eases into and out of a loop's drift over this (m)
const LOOP_GRIP_COS := 0.32      ## where the loop is steeper than this (|cos| of its tilt), hold straight
const STEP := 8.0                ## path point spacing (m)
const CREST_R := 256.0           ## the slope end's crest radius (m: 14 degrees over its 64 m)
const RUN_OFF := 3               ## straights after the finish line to stop on

## A path point: steer towards it; hold straight (BLIND: over jumps); steer towards it for the
## turn the car makes at its speed (LOOP: into, round and out of loops, at 300 km/h and more); or
## hold straight but look through it (WALL: a loop's steep sides, where the tyres don't grip:
## TmTuning slope adherence, none below |cos| 0.3).
enum Drive { STEER, BLIND, LOOP, WALL }

var blocks: Array = []           ## [{name, dir, coord, flags, ground}] like TmChallenge.blocks
## The line to drive: [{p: Vector3 (Godot), dir: Vector3 (Godot, unit), mode: Drive, r: float
## (the turn's radius there, m; 0 straight), rv: float (a crest's radius, m; absent: none)}].
var path: Array = []
var errors: Array[String] = []
var checkpoints := 0
var cell := Vector3i(16, GROUND_LEVEL, 2)
var heading := 0
var _occupied := {}
var _loops: Array = []           ## each loop's line: {piece, start, end (path indices), face, exit, f, lat}
var _pieces := 0
var surface := "road"            ## what the turtle lays: road, dirt, platform, circuit
var width := 1                   ## an area lane's width in cells (platform, circuit)
var lane_walls := false          ## a platform lane with walls along its open edges
var deck := ROAD_Y               ## the surface's top above its level's base (m)
var areas: TmTrackAreas
var laps := 1                    ## a lap race's laps (the line repeats once per lap)
var _start := {}                 ## a lap race's start/finish line: {cell (the car enters it), heading}
var _closed := false
## Pieces of our own beside the blocks (TmSkyTrack: the Sky maps' road and rooftops), built by
## TmSkyPieces: [{kind: "ribbon", frames} | {kind: "roof", lo, hi, y, ...}] (TMNF metres).
var extras: Array = []
var sky: TmSkyTrack
## The other ways to a finish (forks): each a whole line from the start, through its fork.
var alt_paths: Array = []
var finishes := 0                ## finish lines laid (a fork's way has its own)
var notes: Array[String] = []    ## for whoever lays the track out (a ski jump's design speed)

const DIRT_DECK := 0.4           ## the dirt road's top: 0.6 m into the grass (9 m; blocks/shapes/dirt.gd)


## Lays out a track spec.
static func build(spec: Dictionary) -> TmTrackBuilder:
	var b := TmTrackBuilder.new()
	var s: Array = spec.get("start", [16, GROUND_LEVEL, 2, 0])
	b.cell = Vector3i(int(s[0]), int(s[1]), int(s[2]))
	b.heading = posmod(int(s[3]), 4)
	b.laps = maxi(1, int(spec.get("laps", 1)))
	b.areas = TmTrackAreas.new(b)
	for p: Array in spec.get("pieces", []):
		b._pieces += 1
		b.piece(p)
		if not b.errors.is_empty():
			break
	if b.sky != null and b.sky.on:
		b.sky.flush()
	if b.errors.is_empty():
		b.areas.finish()
	if b.errors.is_empty():
		b.ease_loops()
	if b.errors.is_empty():
		b._check_buildings()
	if b.errors.is_empty() and b.laps > 1 and not b._closed:
		b.errors.append("a lap race ends with [\"close\"], back onto its start/finish line")
	var in_sky := String(spec.get("scenery", "")) == "sky"
	if b.errors.is_empty() and not in_sky:
		# (the Sky maps' raised road hangs between the towers: TmSkyCity puts its pylons up)
		b.add_pillars()
		if bool(spec.get("decorate", true)):
			TmTrackDecor.decorate(b, String(spec.get("id", "")), String(spec.get("scenery", "")) == "city")
	if b.errors.is_empty() and b.laps > 1:
		# the line once per lap: the bot drives on round
		var lap := b.path.duplicate(true)
		for _i in b.laps - 1:
			b.path.append_array(lap.duplicate(true))
	return b


## Pillars under raised road, the way TMNF's tracks hold it up: under every other one-block piece
## off the ground (and every other cell a raised GT curve's road crosses), a StadiumTube right
## under the road and StadiumTubePillars down to the ground (turned across the road), where
## nothing else is in the way.
func add_pillars() -> void:
	var n := 0
	for blk: Dictionary in blocks.duplicate():
		var c: Vector3i = blk["coord"]
		var entry := TmBlockCatalogue.info(String(blk["name"]))
		if c.y <= GROUND_LEVEL or TmBlockCatalogue.footprint(entry, false) != Vector3i.ONE \
				and String(blk["name"]) not in ["StadiumRoadMainCheckpoint", "StadiumRoadMainStartLine", "StadiumRoadMainFinishLine"]:
			continue
		if String(blk["name"]).begins_with("StadiumPlatformWall") or String(blk["name"]).begins_with("StadiumCircuitBorder"):
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
		_pillar(c, int(blk["dir"]) % 2)
	# raised GT curves: under every other cell whose middle the line passes close to (the road's
	# middle there, turned across the road's main direction)
	var cells: Array[Vector3i] = []
	var along_z := {}
	for pt: Dictionary in path:
		var p: Vector3 = pt["p"]
		var w := Vector3i(floori(-p.x / 32.0), roundi((p.y - ROAD_Y) / 8.0), floori(p.z / 32.0))
		if w.y <= GROUND_LEVEL or not String(_occupied.get(w, "")).begins_with("StadiumRoadMainGTCurve"):
			continue
		var mid := to_godot(centre(w))
		if Vector2(p.x - mid.x, p.z - mid.z).length() > 8.0 or along_z.has(w):
			continue
		var d: Vector3 = pt["dir"]
		along_z[w] = absf(d.z) >= absf(d.x)
		cells.append(w)
	for i in cells.size():
		var c := cells[i]
		var free := i % 2 == 0
		for y in range(GROUND_LEVEL, c.y):
			free = free and not _occupied.has(Vector3i(c.x, y, c.z))
		if free:
			_pillar(c, 0 if along_z[c] else 1)


## A StadiumTube under raised road at cell c and StadiumTubePillars down to the ground (d: 0 when
## the road runs along z).
func _pillar(c: Vector3i, d: int) -> void:
	for y in range(GROUND_LEVEL, c.y):
		var id := "StadiumTube" if y == c.y - 1 else "StadiumTubePillar"
		var w := Vector3i(c.x, y, c.z)
		_occupied[w] = id
		blocks.append({"name": id, "dir": d, "coord": w, "flags": GROUND_FLAG if y == GROUND_LEVEL else 0, "ground": y == GROUND_LEVEL})


## The TmChallenge of a track spec (uid "SF-<id>"; its `path` is the bot's line).
static func challenge(spec: Dictionary) -> TmChallenge:
	var b := build(spec)
	var ch := TmChallenge.new()
	# keyed by the layout too: records of an older layout of the same track don't carry over
	var layout := "%08x" % (hash(JSON.stringify([spec.get("start", []), spec.get("pieces", [])] + ([spec["laps"]] if spec.has("laps") else [])))
		& 0xffffffff)
	ch.uid = "SF-%s-%s" % [String(spec.get("id", "track")), layout]
	ch.name = String(spec.get("name", "Track"))
	ch.author = String(spec.get("author", "SpeedFest"))
	ch.environment = "Stadium"
	ch.decoration = "Night" if String(spec.get("mood", "day")).to_lower() == "night" else "Day"
	ch.scenery = String(spec.get("scenery", ""))
	var m: Dictionary = spec.get("medals", {})
	ch.author_ms = int(m.get("author", -1))
	ch.gold_ms = int(m.get("gold", -1))
	ch.silver_ms = int(m.get("silver", -1))
	ch.bronze_ms = int(m.get("bronze", -1))
	ch.lap_race = b.laps > 1
	ch.nb_laps = b.laps
	ch.blocks = b.blocks
	ch.path = b.path
	ch.extras = b.extras
	ch.alt_paths = b.alt_paths
	if not b.errors.is_empty():
		ch.error = "track %s: %s" % [spec.get("id", "?"), "; ".join(b.errors)]
	return ch


# --- placing blocks -------------------------------------------------------------------------

static func _rot(v: Vector2, d: int) -> Vector2:
	for _i in posmod(d, 4):
		v = Vector2(-v.y, v.x)
	return v


## A block's units turned by dir d: [[unit cell relative to the block's coord, [clip per side]]]
## (the air variant's, or the ground one's for a block that stands on the ground only, turned in
## that variant's own box).
static func _rotated_units(entry: Dictionary, d: int) -> Array:
	var ground := false
	var units: Array = TmBlockCatalogue.variant(entry, false).get("units", [])
	if units.is_empty():
		units = TmBlockCatalogue.variant(entry, true).get("units", [])
		ground = true
	var size := TmBlockCatalogue.footprint(entry, ground)
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


## Puts block id at coord turned d, without clips (area plates, borders, gates): the cells it
## took, or [] if it leaves the map or meets another block (noted as an error unless quiet).
func put(id: String, coord: Vector3i, d: int, flags := 0, quiet := false) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var entry := TmBlockCatalogue.info(id)
	if entry.is_empty():
		errors.append("unknown block %s" % id)
		return out
	var ground := TmUserTracks.has_ground(id) and coord.y == GROUND_LEVEL
	if not ground and TmBlockCatalogue.variant(entry, false).get("units", []).is_empty():
		if not quiet:
			errors.append("%s at %s stands on the ground only" % [id, coord])
		return out
	for u: Array in TmUserTracks.units(id, d, ground):
		var w: Vector3i = coord + (u[0] as Vector3i)
		if not inside(w) or _occupied.has(w):
			if not quiet:
				errors.append("%s at %s %s (unit %s)" % [id, coord, "runs into %s" % _occupied[w] if _occupied.has(w)
					else "leaves the map", w])
			out.clear()
			return out
		out.append(w)
	for w in out:
		_occupied[w] = id
	blocks.append({"name": id, "dir": posmod(d, 4), "coord": coord, "flags": flags | (GROUND_FLAG if ground else 0), "ground": ground})
	if int(entry.get("waypoint", 3)) == TmBlockCatalogue.Waypoint.CHECKPOINT:
		checkpoints += 1
	return out


## A cell on the map (the 32 x 32 blocks, level 1 up).
static func inside(c: Vector3i) -> bool:
	return c.x >= 0 and c.z >= 0 and c.x < MAP and c.z < MAP and c.y >= GROUND_LEVEL and c.y <= TmUserTracks.MAX_LEVEL


func occupied(c: Vector3i) -> bool:
	return _occupied.has(c)


## The block id covering a cell ("" if none).
func occupant(c: Vector3i) -> String:
	return String(_occupied.get(c, ""))


func piece_count() -> int:
	return _pieces


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


## Where the car enters the current cell (TMNF metres): the middle of the face it comes through,
## at the surface's height.
func entry_face() -> Vector3:
	return Vector3((cell.x + 0.5) * 32.0, cell.y * 8.0 + deck, (cell.z + 0.5) * 32.0) - vec(heading) * 16.0


## k: the line's signed curvature there (1/m, + to the left), for the bot's road-frame steering.
func _point(p: Vector3, dir: Vector3, mode := Drive.STEER, r := 0.0, k := 0.0) -> void:
	path.append({"p": to_godot(p), "dir": to_godot(dir).normalized(), "mode": mode, "r": r, "k": k})


func segment(a: Vector3, ha: int, b: Vector3, hb: int, r := 0.0, mode := Drive.STEER) -> void:
	_segment(a, ha, b, hb, r, mode)


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
	# a left turn when the new heading lies to the left of the old one (Godot: up x forward = left)
	var left := to_godot(f1).dot(Vector3.UP.cross(to_godot(f0))) > 0.0
	var k := (1.0 if left else -1.0) / maxf(rr, 1.0)
	for i in range(1, n + 1):
		var t := float(i) / n * PI * 0.5
		var p := o - f1 * rr * cos(t) + f0 * rr * sin(t)
		p.y = lerpf(a.y, b.y, float(i) / n)
		_point(p, f0 * cos(t) + f1 * sin(t), mode, r if r > 0.0 else rr, k)


# --- pieces -------------------------------------------------------------------------------------

func piece(p: Array) -> void:
	var kind := String(p[0])
	if TmSkyTrack.handles(kind):
		if sky == null:
			sky = TmSkyTrack.new(self)
		sky.piece(p)
		return
	if kind == "split":
		_split(String(p[1]) == "l", p[2] if p.size() > 2 else [])
		return
	if sky != null and sky.on and not sky.land():
		return
	if kind == "fork":
		_fork(String(p[1]) == "l", p[2] if p.size() > 2 else [])
		return
	if kind in ["road", "dirt", "platform", "circuit"]:
		_switch(kind, int(p[1]) if p.size() > 1 else 1, p.size() > 2 and String(p[2]) == "walls")
		return
	if surface in TmTrackAreas.KINDS:
		areas.piece(p)
		return
	if surface == "dirt":
		_dirt(p)
		return
	match kind:
		"close":
			# the lap ends where it began: into the start/finish line, through it
			if laps < 2 or _start.is_empty() or cell != _start["cell"] or heading != int(_start["heading"]):
				errors.append("[\"close\"] (piece %d) at %s heading %d: the lap's start/finish line takes the car at %s heading %s"
					% [_pieces, cell, heading, _start.get("cell"), _start.get("heading")])
				return
			var a := entry_face()
			_segment(a, heading, a + vec(heading) * 32.0, heading)
			_closed = true
		"start":
			var line := "StadiumRoadMainStartFinishLine" if laps > 1 else "StadiumRoadMainStartLine"
			if laps > 1:
				_start = {"cell": cell, "heading": heading}
				finishes += 1              # (a lap race finishes on its start/finish line)
			var res := place(line, -1, 0)
			if not res.is_empty():
				cell = res["exit_cell"]
				heading = res["exit_heading"]
				_point(entry_face(), vec(heading))
		"finish":
			_finish()
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
		"climb", "dive":
			_hill(kind == "climb", int(p[1]) if p.size() > 1 else 1, String(p[2]) if p.size() > 2 else "")
		"jump":
			_jump(int(p[1]) if p.size() > 1 else 2, p.size() > 2 and String(p[2]) == "high")
		"loop":
			_loop(String(p[1]) == "r" if p.size() > 1 else false)
		"block":
			_through(String(p[1]), 0, 1)
		_:
			errors.append("unknown piece %s" % kind)


## Changes the surface, with the join between the two: road down onto a platform or circuit a
## level below (TMNF's StadiumPlatformToRoadMain, its road end towards the road) and back up,
## road to dirt and back (StadiumRoadDirtToRoad, on the ground); platform and circuit meet as they
## are. w: a lane's width (odd).
func _switch(to: String, w: int, walls: bool) -> void:
	var from := surface
	if to in TmTrackAreas.KINDS:
		if w < 1 or w % 2 == 0:
			errors.append("a lane is 1, 3 or 5 cells wide, not %d (piece %d)" % [w, _pieces])
			return
		width = w
		lane_walls = walls
	if to == from:
		return
	var a := entry_face()
	var h := heading
	if from == "road" and to in TmTrackAreas.KINDS:
		var res := place("StadiumPlatformToRoadMain", 0, -1)
		if res.is_empty():
			return
		areas.lane[res["coord"]] = to
		cell = res["exit_cell"] - Vector3i(0, 1, 0)
		surface = to
		deck = TmTrackAreas.DECK
		var z := entry_face()
		areas.brush(a, z, cell.y)
		_segment(a, h, z, h)
	elif from in TmTrackAreas.KINDS and to == "road":
		cell.y += 1
		var res := place("StadiumPlatformToRoadMain", -1, 0)
		if res.is_empty():
			return
		areas.lane[res["coord"]] = from
		cell = res["exit_cell"]
		surface = to
		deck = ROAD_Y
		_segment(a, h, entry_face(), h)
	elif from in TmTrackAreas.KINDS and to in TmTrackAreas.KINDS:
		surface = to
	elif (from == "road" and to == "dirt") or (from == "dirt" and to == "road"):
		if cell.y != GROUND_LEVEL:
			errors.append("dirt roads lie on the ground (piece %d)" % _pieces)
			return
		var res := place("StadiumRoadDirtToRoad", 1 if to == "dirt" else 0, 0 if to == "dirt" else 1)
		if res.is_empty():
			return
		cell = res["exit_cell"]
		heading = res["exit_heading"]
		surface = to
		deck = DIRT_DECK if to == "dirt" else ROAD_Y
		_segment(a, h, entry_face(), heading)
	else:
		errors.append("no join from %s to %s (piece %d): go through the road" % [from, to, _pieces])


## A dirt road piece (TMNF's Road/Dirt: on the ground only).
func _dirt(p: Array) -> void:
	var kind := String(p[0])
	match kind:
		"s":
			for _i in (int(p[1]) if p.size() > 1 else 1):
				if not _through("StadiumRoadDirt", 0, 1, 0.0, 3, [0, 2]):
					return
		"l", "r":
			_through("StadiumRoadDirt", 0, 1, 16.0, 2, [1, 0] if kind == "l" else [0, 1])
		"gt":
			var k := clampi(int(p[1]), 2, 3)
			_through("StadiumRoadDirtGTCurve%d" % k, 0 if String(p[2]) == "l" else 1,
				1 if String(p[2]) == "l" else 0, 32.0 * k - 16.0)
		"cp":
			_through("StadiumRoadDirtCheckpoint", 1, 0)
		_:
			errors.append("%s can't be laid on dirt (piece %d)" % [kind, _pieces])


## A fork (multiple finishes): TMNF's road T junction, the pieces in `branch` laid from its side
## exit (left or right) as a second way to their own finish, then the track goes on straight. The
## way's line is kept whole from the start (alt_paths: the bot can drive it too); a checkpoint on
## it would have to be taken on the main way as well, so they belong before the fork.
func _fork(left: bool, branch: Array) -> void:
	if surface != "road":
		errors.append("a fork stands on road (piece %d)" % _pieces)
		return
	var a := entry_face()
	var h := heading
	# TMNF's T (Road/Main shape 4: arms +z, -z, -x): in at -z for a left branch, at +z for a right
	var res := place("StadiumRoadMain", 0, 1, 4, [2, 0, 1] if left else [0, 2, 1])
	if res.is_empty():
		return
	var side := posmod(1 + int(res["dir"]), 4)
	var main_cell: Vector3i = res["exit_cell"]
	# the branch, laid with the turtle's own state, then put back
	var keep := {"cell": main_cell, "heading": heading, "path": path, "pieces": _pieces}
	var junction: Vector3i = res["coord"]
	path = path.duplicate()
	cell = junction + SIDE[side]
	heading = side
	_segment(a, h, entry_face(), heading, 16.0)
	var finishes_before := finishes
	var saved_sky := sky
	sky = null
	for bp: Array in branch:
		piece(bp)
		if not errors.is_empty():
			return
	if sky != null and sky.on:
		sky.flush()
	sky = saved_sky
	if finishes == finishes_before:
		errors.append("a fork's way (piece %d) ends with its own [\"finish\"]" % keep["pieces"])
		return
	alt_paths.append(path)
	path = keep["path"]
	cell = keep["cell"]
	heading = keep["heading"]
	_segment(a, h, entry_face(), h)


## A split off a rooftop (multiple finishes, at speed): the pieces in `branch` leave the roof's far
## edge a cell to the left or right of the road, heading the same way. Its line: the road's over the
## roof, drifting over to that lane across the roof's last two blocks, then the branch's own.
func _split(left: bool, branch: Array) -> void:
	var roof: Dictionary = extras[-1] if not extras.is_empty() else {}
	if sky == null or not sky.on or String(roof.get("kind", "")) != "roof" or sky.pos.distance_to(roof["exit"]) > 0.1:
		errors.append("a split (piece %d) comes right after a rooftop" % _pieces)
		return
	var w := absf(((roof["hi"] as Vector3) - (roof["lo"] as Vector3)).dot(TmSkyTrack.right_of(roof["f"], Vector3.UP)))
	if w < 3.0 * 32.0 - 0.1:
		errors.append("a split (piece %d) needs a rooftop 3 cells wide" % _pieces)
		return
	var f: Vector3 = roof["f"]
	var side := TmSkyTrack.right_of(f, Vector3.UP) * (-32.0 if left else 32.0)
	var keep := {"path": path, "cell": cell, "heading": heading, "pieces": _pieces}
	# the branch's line: the road's up to the roof, then over to the lane across the roof's length
	var span := (roof["entry"] as Vector3).distance_to(roof["exit"]) - 8.0
	var exit_g := to_godot(roof["exit"])
	var start_g := to_godot((roof["exit"] as Vector3) - f * span)
	var line: Array = []
	for pt: Dictionary in path:
		if (pt["p"] as Vector3).distance_to(exit_g) < span - 0.1 and (pt["p"] as Vector3).distance_to(start_g) < span + 0.1 \
				and bool(pt.get("sky", false)):
			continue
		line.append(pt)
	var n := ceili(span / STEP)
	var r_min := span * span / (6.0 * 32.0)            # the blend's tightest bend (its steepest curvature)
	for i in range(1, n + 1):
		var t := float(i) / n
		var e := t * t * (3.0 - 2.0 * t)
		var q := (roof["exit"] as Vector3) - f * span * (1.0 - t) + side * e
		var slope := 6.0 * t * (1.0 - t) * 32.0 / span
		var dir := (f + side.normalized() * slope).normalized()
		var bend := 6.0 * (1.0 - 2.0 * t) * 32.0 / (span * span)
		var toward_left := (side.dot(TmSkyTrack.right_of(f, Vector3.UP)) < 0.0) == (bend > 0.0)
		line.append({"p": to_godot(q), "dir": to_godot(dir), "mode": Drive.STEER, "r": r_min / maxf(absf(1.0 - 2.0 * t), 0.2),
			"k": absf(bend) * (1.0 if toward_left else -1.0), "sky": true})
	path = line
	var saved_sky := sky
	sky = null
	var h := TmSkyTrack._axis(f)
	var c := (roof["exit"] as Vector3) + side + f * 16.0
	cell = Vector3i(floori(c.x / 32.0), roundi(((roof["exit"] as Vector3).y - ROAD_Y) / 8.0), floori(c.z / 32.0))
	heading = h
	var finishes_before := finishes
	for bp: Array in branch:
		piece(bp)
		if not errors.is_empty():
			return
	if sky != null and sky.on:
		sky.flush()
	if finishes == finishes_before:
		errors.append("a split's way (piece %d) ends with its own [\"finish\"]" % keep["pieces"])
		return
	alt_paths.append(path)
	path = keep["path"]
	cell = keep["cell"]
	heading = keep["heading"]
	sky = saved_sky


## The road's own buildings stand from the streets up (TmSkyCity): no road may pass under a
## rooftop, or through a spiral's round tower.
func _check_buildings() -> void:
	for e: Dictionary in extras:
		var kind := String(e["kind"])
		if kind != "roof" and kind != "hub":
			continue
		for line: Array in [path] + alt_paths:
			for pt: Dictionary in line:
				var p := to_godot(pt["p"])          # (back to TMNF's axes)
				var inside := false
				if kind == "roof":
					var lo: Vector3 = e["lo"]
					var hi: Vector3 = e["hi"]
					inside = p.x > lo.x + 2.0 and p.x < hi.x - 2.0 and p.z > lo.z + 2.0 and p.z < hi.z - 2.0 \
						and p.y < float(e["y"]) - 2.0
				else:
					var c: Vector3 = e["c"]
					var half := (float(e["r"]) - TmSkyTrack.EDGE - 5.0) * 0.7
					inside = float(e["bank"]) <= deg_to_rad(70.0) and absf(p.x - c.x) < half and absf(p.z - c.z) < half
				if inside:
					errors.append("the road passes %s at %s" % ["under a rooftop (its building)" if kind == "roof"
						else "through a spiral's tower", p.snapped(Vector3.ONE * 0.1)])
					return


## The finish with road to stop on: TMNF's through start/finish line block (it finishes a
## one-lap race), up to RUN_OFF straights and a rounded dead end, as far as the cells ahead are
## free; else the finish block that ends in its nose (the car flew off it into the grass).
func _finish() -> void:
	finishes += 1
	var free := 0
	while free < RUN_OFF + 2:
		var w := cell + SIDE[heading] * free
		if _occupied.has(w) or w.x < 0 or w.z < 0 or w.x >= MAP or w.z >= MAP:
			break
		free += 1
	if free < 3:
		var a := entry_face()
		if place("StadiumRoadMainFinishLine", 0, -1).is_empty():
			return
		_segment(a, heading, a + vec(heading) * 64.0, heading)
		return
	if not _through("StadiumRoadMainStartFinishLine", 1, 0):
		return
	for _i in mini(RUN_OFF, free - 2):
		if not _through("StadiumRoadMain", 0, 1, 0.0, 3, [0, 2]):
			return
	var a := entry_face()
	if not place("StadiumRoadMain", 0, -1, 1, [0]).is_empty():
		_segment(a, heading, a + vec(heading) * 16.0, heading)


## A long hill the way TMNF's tracks climb: the slope start (2 blocks, 1 level: flat into the
## 14-degree slope), n slope blocks (a level each; the middle one a checkpoint or a turbo if `mid`
## says so) and the slope end (2 blocks, 1 level), or the same downhill from the top.
func _hill(up: bool, n: int, mid: String) -> void:
	var ids: Array[String] = ["StadiumRoadMainBiSlopeStart"]
	for i in n:
		var id := "StadiumRoadMainSlopeStraight"
		if i == n / 2 and mid == "cp":
			id = "StadiumRoadMainCheckpointUp" if up else "StadiumRoadMainCheckpointDown"
		elif i == n / 2 and mid == "turbo":
			id = "StadiumRoadMainTurboUp" if up else "StadiumRoadMainTurboDown"
		ids.append(id)
	ids.append("StadiumRoadMainBiSlopeEnd")
	if not up:
		ids.reverse()
	for id in ids:
		var from := path.size() - 1
		# clip 0 is the low end on all of them (the Down gates face the other way, downhill)
		if not _through(id, 0 if up else 1, 1 if up else 0):
			return
		# the slope end is a crest either way: a car over ~315 km/h takes off there
		if id == "StadiumRoadMainBiSlopeEnd":
			for i in range(maxi(from, 0), path.size()):
				path[i]["rv"] = CREST_R


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
	# the line: a helix on the road (blocks/shapes/road.gd _loop: each half turn drifts 64 m
	# sideways), up through the first block, over the top above the entry and down through the
	# second; held straight where it is steep. Loop points also carry the road's normal (n) and
	# the line's curvature about it (k, 1/m, + = to the left; 0: the helix is the cylinder's
	# straight line). ease_loops eases the line into the drift and out of it.
	var f := vec(h)
	var lat := vec(side_h)
	var n := 48
	var start := path.size()
	for i in range(1, n + 1):
		var th := TAU * float(i) / n
		var p := face + lat * (LOOP_SHIFT * th / PI) + Vector3(0, LOOP_R * (1.0 - cos(th)), 0) + f * (LOOP_R * sin(th))
		var t := lat * (LOOP_SHIFT / PI) + Vector3(0, LOOP_R * sin(th), 0) + f * (LOOP_R * cos(th))
		_point(p, t.normalized(), Drive.WALL if absf(cos(th)) < LOOP_GRIP_COS else Drive.LOOP)
		path[path.size() - 1]["n"] = to_godot(Vector3(0, cos(th), 0) - f * sin(th))
		path[path.size() - 1]["k"] = 0.0
	_loops.append({"piece": _pieces, "start": start, "end": path.size() - 1, "face": to_godot(face),
		"exit": to_godot(face + lat * LOOP_SHIFT * 2.0), "f": to_godot(f), "lat": to_godot(lat)})


## TMNF's loop drifts sideways from its first frame on (blocks/shapes/road.gd _loop): its road
## turns ~25 deg off the straight that leads in, and back onto the one that leads out. A car can't
## turn that sharply at loop speeds, and a wheel that meets the curb brings TMNF's wall slow-down
## (~60 m/s^2 for half a second: the car falls before the top). So the line eases into the drift
## over LOOP_EASE m either side of the entry (on the straight before it and the loop's floor), and
## out of it either side of the exit: in the loop unrolled flat, the corner between the two
## straight lines becomes a parabola, at most LOOP_EASE * k / 4 (~4.6 m) inside the corner. Each
## end needs a straight block next to the loop.
func ease_loops() -> void:
	var k := LOOP_SHIFT / (PI * LOOP_R)          # sideways drift per metre forward
	for lp: Dictionary in _loops:
		var face: Vector3 = lp["face"]
		var ex: Vector3 = lp["exit"]
		var f: Vector3 = lp["f"]
		var lat: Vector3 = lp["lat"]
		var start: int = lp["start"]
		var end: int = lp["end"]
		var n := end - start + 1
		# how much straight road the line has before the entry and after the exit
		var t_in := 0.0
		var j := start - 1
		while j >= 0 and _on_straight(j, face, f, lat) and -(path[j]["p"] - face).dot(f) <= LOOP_EASE + 0.01:
			t_in = maxf(t_in, -(path[j]["p"] - face).dot(f))
			j -= 1
		var t_out := 0.0
		j = end + 1
		while j < path.size() and _on_straight(j, ex, f, lat) and (path[j]["p"] - ex).dot(f) <= LOOP_EASE + 0.01:
			t_out = maxf(t_out, (path[j]["p"] - ex).dot(f))
			j += 1
		if t_in < 31.9 or t_out < 31.9:
			errors.append("loop (piece %d) needs a straight block before and after it" % lp["piece"])
			return
		for i in range(maxi(0, start - 8), mini(path.size(), end + 9)):
			# the point's distance forward of the entry (the loop: along its circle), and its tangent
			# per metre forward
			var s: float
			var tan: Vector3
			if i < start:
				s = (path[i]["p"] - face).dot(f)
				tan = f
			elif i <= end:
				var th := TAU * float(i - start + 1) / n
				s = LOOP_R * th
				tan = lat * k + Vector3.UP * sin(th) + f * cos(th)
			else:
				s = LOOP_R * TAU + (path[i]["p"] - ex).dot(f)
				tan = f
			# the shift across, and its change per metre forward (the entry and exit points count
			# as the loop's: their tangent is the loop's)
			var du := 0.0
			var slope := 0.0
			var bend := 0.0                      # the shift's second derivative
			var d := s - LOOP_R * TAU
			if absf(s) <= t_in:
				du = k * pow(absf(s) - t_in, 2) / (4.0 * t_in)
				slope = (-1.0 if i < start else 1.0) * k * (absf(s) - t_in) / (2.0 * t_in)
				bend = k / (2.0 * t_in)
			elif absf(d) <= t_out:
				du = -k * pow(absf(d) - t_out, 2) / (4.0 * t_out)
				slope = (-1.0 if i > end else 1.0) * k * (absf(d) - t_out) / (2.0 * t_out)
				bend = -k / (2.0 * t_out)
			else:
				continue
			var dir := (tan + lat * slope).normalized()
			var nrm: Vector3 = path[i].get("n", Vector3.UP)
			var drift := (k if i >= start and i <= end else 0.0) + slope
			path[i]["p"] = path[i]["p"] + lat * du
			path[i]["dir"] = dir
			path[i]["mode"] = Drive.LOOP
			path[i]["n"] = nrm
			path[i]["k"] = bend / pow(1.0 + drift * drift, 1.5) * signf(lat.dot(nrm.cross(dir)))


## Path point i lies on the straight line through `at` along f (steered, heading along f).
func _on_straight(i: int, at: Vector3, f: Vector3, lat: Vector3) -> bool:
	var pt: Dictionary = path[i]
	return int(pt["mode"]) == Drive.STEER and absf((pt["p"] - at).dot(lat)) < 0.5 \
		and absf((pt["p"] - at).y) < 0.5 and (pt["dir"] as Vector3).dot(f) > 0.999 and float(pt["r"]) == 0.0
