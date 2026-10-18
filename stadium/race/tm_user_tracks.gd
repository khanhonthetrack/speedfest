class_name TmUserTracks
extends RefCounted
## Tracks made in the track editor (editor/editor.tscn): our own file format, a JSON ".sftrack" in
## user://tracks (or --tracks_dir=<dir>): {"format": "speedfest-track", "version", "id" (made once),
## "name", "author", "laps", "medals": {author, gold, silver, bronze} (ms; set by validating the
## track: finishing it in a test drive), "validated": the layout the medals belong to, "pillars"
## (pillars under raised road, added when the track is built), "blocks": [[id, dir, x, y, z], ...]}.
## Blocks are TMNF's Stadium blocks on its 32 x 8 x 32 m grid (TmBlockCatalogue); a road block's
## variant (dead end, corner, straight, T, cross) comes from its neighbours (road_variant), so
## files keep only what was placed. A track loads as a TmChallenge like any other (TmStage).

const FORMAT := "speedfest-track"
const VERSION := 1
const EXT := ".sftrack"
const DIR := "user://tracks"
const MAP := 32
const MAX_LEVEL := 24
const G := TmTrackBuilder.GROUND_LEVEL
const SIDE := TmTrackBuilder.SIDE
## A road block's shape group (TmBlockCatalogue.shape_name index) by its open sides, and those
## sides in the shape's own frame (blocks/shapes/road.gd ROAD_SIDES).
const ROAD_SHAPES := {"Base": [0, []], "Deadend": [1, [0]], "Corner": [2, [0, 1]], "Straight": [3, [0, 2]],
	"TShaped": [4, [0, 1, 2]], "Cross": [5, [0, 1, 2, 3]]}


static func dir() -> String:
	return String(TestHooks.arg("tracks_dir", DIR))


## A new, empty track.
static func blank(track_name := "My Track") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return {"format": FORMAT, "version": VERSION, "id": "%08x%04x" % [rng.randi(), rng.randi() & 0xffff], "name": track_name,
		"author": String(TmUi.setting("name")), "laps": 1, "medals": {}, "validated": "", "pillars": true, "blocks": []}


static func load_file(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary) or String(d.get("format", "")) != FORMAT:
		return {}
	d["blocks"] = normal_blocks(d.get("blocks", []))
	return d


## Blocks as [id (String), dir, x, y, z (ints)] (JSON reads numbers as floats).
static func normal_blocks(blocks: Variant) -> Array:
	var out: Array = []
	if not blocks is Array:
		return out
	for b: Variant in blocks:
		if b is Array and (b as Array).size() >= 5:
			out.append([String(b[0]), posmod(int(b[1]), 4), int(b[2]), int(b[3]), int(b[4])])
	return out


static func save(track: Dictionary, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(track, "\t"))
	return true


## A file name for a track ("<name>.sftrack", file-safe; a number added if taken by another track).
static func path_for(track: Dictionary) -> String:
	var base := ""
	for c in String(track.get("name", "track")):
		base += c if (c.is_valid_identifier() or c.is_valid_int() or c in "- ") else "_"
	base = base.strip_edges()
	if base.is_empty():
		base = "track"
	var p := dir().path_join(base + EXT)
	var n := 2
	while FileAccess.file_exists(p) and String(load_file(p).get("id", "")) != String(track.get("id", "")):
		p = dir().path_join("%s %d%s" % [base, n, EXT])
		n += 1
	return p


## The tracks made here, newest first: [{path, track}].
static func list() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir()):
		return out
	for f in DirAccess.get_files_at(dir()):
		if not f.ends_with(EXT) or f.begins_with("_"):
			continue
		var t := load_file(dir().path_join(f))
		if not t.is_empty():
			out.append({"path": dir().path_join(f), "track": t, "time": FileAccess.get_modified_time(dir().path_join(f))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["time"]) > int(b["time"]))
	return out


## The layout's fingerprint: the blocks and laps (records and validation belong to a layout).
static func layout(track: Dictionary) -> String:
	var blocks := normal_blocks(track.get("blocks", []))
	blocks.sort_custom(func(a: Array, b: Array) -> bool: return str(a) < str(b))   # the order blocks were placed in doesn't matter
	return "%08x" % (hash(JSON.stringify([blocks, int(track.get("laps", 1))])) & 0xffffffff)


static func is_validated(track: Dictionary) -> bool:
	return String(track.get("validated", "")) == layout(track) and int((track.get("medals", {}) as Dictionary).get("author", -1)) > 0


## TMNF's medal rule of thumb from the author time: gold +6%, silver +20%, bronze +50% (rounded up
## to 10 ms, 0.1 s, 1 s, 1 s).
static func medals(author_ms: int) -> Dictionary:
	var a := _round_up(author_ms, 10)
	return {"author": a, "gold": _round_up(int(a * 1.06), 100), "silver": _round_up(int(a * 1.2), 1000),
		"bronze": _round_up(int(a * 1.5), 1000)}


static func _round_up(ms: int, step: int) -> int:
	return int(ceil(float(ms) / step)) * step


## A finish in a test drive validates the track (the author time is the best such finish on this
## layout). Returns true when the medals changed.
static func validate(track: Dictionary, time_ms: int) -> bool:
	if time_ms <= 0:
		return false
	var lay := layout(track)
	var m: Dictionary = track.get("medals", {})
	if String(track.get("validated", "")) == lay and int(m.get("author", -1)) > 0 and int(m["author"]) <= time_ms:
		return false
	track["medals"] = medals(time_ms)
	track["validated"] = lay
	return true


## Validates the track in a file after a finish (the race scene, testing a track). Returns true
## when the file's medals changed.
static func validate_file(path: String, time_ms: int) -> bool:
	var t := load_file(path)
	if t.is_empty() or not validate(t, time_ms):
		return false
	return save(t, path)


# --- blocks ---------------------------------------------------------------------------------

## A block's units turned by dir: [[cell offset (Vector3i, TMNF block coords), clips (per local
## side)]], offsets from the rotated footprint's min corner (TmTrackBuilder's convention).
static func units(id: String, d: int) -> Array:
	return TmTrackBuilder._rotated_units(TmBlockCatalogue.info(id), d)


static func is_road(id: String) -> bool:
	return String(TmBlockCatalogue.info(id).get("kind", "")) == "road"


## The cells a block covers: coord + its units' offsets.
static func cells(id: String, d: int, coord: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for u: Array in units(id, d):
		out.append(coord + (u[0] as Vector3i))
	return out


static func inside(c: Vector3i) -> bool:
	return c.x >= 0 and c.z >= 0 and c.x < MAP and c.z < MAP and c.y >= G and c.y <= MAX_LEVEL


static func has_ground(id: String) -> bool:
	return not TmBlockCatalogue.variant(TmBlockCatalogue.info(id), true).get("units", []).is_empty()


## The clip a block shows on world side `side` of its unit at cell c ("" none).
static func clip_at(id: String, d: int, coord: Vector3i, c: Vector3i, side: int) -> String:
	for u: Array in units(id, d):
		if coord + (u[0] as Vector3i) == c:
			var cl: Array = u[1]
			var local := posmod(side - d, 4)
			return String(cl[local]) if local < cl.size() else ""
	return ""


## A road block's variant from its neighbours: {flags (shape group), dir}. A side is open where the
## next cell holds a block with the road's own clip facing back (another road of its kind, a
## checkpoint, a slope...). occupant(c) -> {id, dir, coord} or {}.
static func road_variant(id: String, c: Vector3i, occupant: Callable) -> Dictionary:
	var own := clip_at(id, 0, c, c, 0)
	var open: Array[int] = []
	for s in 4:
		var n: Dictionary = occupant.call(c + SIDE[s])
		if n.is_empty():
			continue
		if clip_at(String(n["id"]), int(n["dir"]), n["coord"], c + SIDE[s], posmod(s + 2, 4)) == own and not own.is_empty():
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
	var local: Array = ROAD_SHAPES[pick][1]
	for d in 4:
		var turned: Array[int] = []
		for s: int in local:
			turned.append(posmod(s + d, 4))
		turned.sort()
		if turned == open or local.is_empty():
			return {"flags": int(ROAD_SHAPES[pick][0]), "dir": d}
	return {"flags": int(ROAD_SHAPES[pick][0]), "dir": 0}


## The track's blocks as a TmChallenge's ({name, dir, coord, flags, ground}): road variants from
## their neighbours, pillars under raised road (when on).
static func challenge_blocks(track: Dictionary) -> Array:
	var placed: Array = []
	var occ := {}
	for b: Array in track.get("blocks", []):
		var id := String(b[0])
		if TmBlockCatalogue.info(id).is_empty():
			continue
		var blk := {"id": id, "dir": posmod(int(b[1]), 4), "coord": Vector3i(int(b[2]), int(b[3]), int(b[4]))}
		placed.append(blk)
		for c in cells(id, blk["dir"], blk["coord"]):
			occ[c] = blk
	var occupant := func(c: Vector3i) -> Dictionary: return occ.get(c, {})
	var out: Array = []
	for blk: Dictionary in placed:
		var id := String(blk["id"])
		var d := int(blk["dir"])
		var coord: Vector3i = blk["coord"]
		var flags := 0
		if is_road(id):
			var v := road_variant(id, coord, occupant)
			flags = int(v["flags"])
			d = int(v["dir"])
		var ground := coord.y == G and has_ground(id)
		out.append({"name": id, "dir": d, "coord": coord, "flags": flags | (TmTrackBuilder.GROUND_FLAG if ground else 0), "ground": ground})
	if bool(track.get("pillars", true)):
		out.append_array(pillars(out, occ))
	return out


## Pillars under raised one-cell road blocks, TMNF's way (TmTrackBuilder.add_pillars): under every
## other one, a StadiumTube under the road and StadiumTubePillars down to the ground, where the
## cells below are free.
static func pillars(blocks: Array, occ: Dictionary) -> Array:
	var out: Array = []
	var n := 0
	for blk: Dictionary in blocks:
		var c: Vector3i = blk["coord"]
		var id := String(blk["name"])
		if c.y <= G or TmBlockCatalogue.footprint(TmBlockCatalogue.info(id), false) != Vector3i.ONE:
			continue
		if not (id.begins_with("StadiumRoadMain") or id.begins_with("StadiumPlatform")):
			continue
		n += 1
		if n % 2 == 0:
			continue
		var free := true
		for y in range(G, c.y):
			free = free and not occ.has(Vector3i(c.x, y, c.z))
		if not free:
			continue
		for y in range(G, c.y):
			var pid := "StadiumTube" if y == c.y - 1 else "StadiumTubePillar"
			out.append({"name": pid, "dir": int(blk["dir"]) % 2, "coord": Vector3i(c.x, y, c.z),
				"flags": TmTrackBuilder.GROUND_FLAG if y == G else 0, "ground": y == G})
	return out


## The track as a TmChallenge (uid "U-<id>-<layout>": records belong to the layout).
static func challenge(track: Dictionary) -> TmChallenge:
	var ch := TmChallenge.new()
	ch.uid = "U-%s-%s" % [String(track.get("id", "track")), layout(track)]
	ch.name = String(track.get("name", "Track"))
	ch.author = TmNick.strip(String(track.get("author", "")))
	ch.environment = "Stadium"
	ch.decoration = "Day"
	var m: Dictionary = track.get("medals", {}) if is_validated(track) else {}
	ch.author_ms = int(m.get("author", -1))
	ch.gold_ms = int(m.get("gold", -1))
	ch.silver_ms = int(m.get("silver", -1))
	ch.bronze_ms = int(m.get("bronze", -1))
	var laps := int(track.get("laps", 1))
	ch.lap_race = laps > 1
	ch.nb_laps = maxi(1, laps)
	ch.blocks = challenge_blocks(track)
	if ch.blocks.is_empty():
		ch.error = "the track %s has no blocks" % ch.name
	return ch


static func challenge_file(path: String) -> TmChallenge:
	var t := load_file(path)
	if t.is_empty():
		var none := TmChallenge.new()
		none.error = "%s isn't a SpeedFest track" % path.get_file()
		return none
	return challenge(t)
