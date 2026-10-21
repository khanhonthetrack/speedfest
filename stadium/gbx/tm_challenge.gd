class_name TmChallenge
extends RefCounted
## A TMNF track (.Challenge.Gbx) as read from the player's own files: name, author, medal times and
## the block list. Our own reader of the public GBX format (see tools/research/tmnf/gbx_challenge.py,
## the prototype). Nothing from these files is ever stored in the repo.
##
## Blocks: [{name, dir (0..3), coord (Vector3i, units of 32 x 8 x 32 m), flags, ground (bool),
##          variant (int), skin (String, may be empty)}]

const CLASS_CHALLENGE := 0x03043000
## Old class ids (TrackMania Original / Sunrise / Nations ESWC files, which TMNF still loads) ->
## TMNF's (from GBX.NET's public-domain WrapTMF table; only the classes a track body uses).
const WRAP := {0x24003000: 0x03043000, 0x2400A000: 0x0301A000, 0x2400C000: 0x0305B000,
	0x2403A000: 0x03059000, 0x2403C000: 0x0301B000}
const FACADE := 0xFACADE01
const PIKS := 0x534B4950

var error := ""
var uid := ""
var name := ""
var author := ""
var environment := ""
var decoration := ""
var scenery := ""               ## our own tracks' extra scenery: "city" (towers around the road, TmSkyline)
var bronze_ms := -1
var silver_ms := -1
var gold_ms := -1
var author_ms := -1
var time_limit_ms := -1
var lap_race := false
var nb_laps := 0
var size := Vector3i(32, 32, 32)
var blocks: Array = []
var path: Array = []           ## our own tracks only (TmTrackBuilder): the line the driving bot follows
## A TMUnlimiter 2 track: TMNF's block list is a placeholder (its one block's name says the track
## needs TMUnlimiter) and the real blocks are in Unlimiter's own chunks.
var unlimiter := false


## header_only: just the header (name, author, uid, medal times; no blocks): quick, for lists.
static func load_file(path: String, header_only := false) -> TmChallenge:
	var c := TmChallenge.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		c.error = "cannot open %s" % path
		return c
	c.parse(f.get_buffer(f.get_length()), header_only)
	return c


## A class or chunk id in TMNF's numbering (old ids mapped).
static func wrap_id(id: int) -> int:
	var w: int = WRAP.get(id & 0xFFFFF000, 0)
	return (w | (id & 0xFFF)) if w != 0 else id


func ok() -> bool:
	return error.is_empty()


func parse(raw: PackedByteArray, header_only := false) -> void:
	var s := GbxStream.new(raw)
	if s.bytes(3).get_string_from_ascii() != "GBX":
		error = "not a GBX file"
		return
	var ver := s.u16()
	if ver < 6:
		error = "GBX version %d not supported" % ver
		return
	var fmt := s.bytes(4)
	var cls := wrap_id(s.u32())
	if cls != CLASS_CHALLENGE:
		error = "not a challenge (class %08X)" % cls
		return
	var user_size := s.u32()
	if user_size > 0:
		var n := s.u32()
		var entries: Array = []
		for i in n:
			entries.append([s.u32(), s.u32() & 0x7FFFFFFF])
		for e in entries:
			_header_chunk(wrap_id(e[0]), s.bytes(e[1]))
	if header_only:
		if not s.ok():
			error = s.error
		return
	s.u32()   # number of nodes
	if s.u32() != 0:
		error = "external references are not supported"
		return
	var body: PackedByteArray
	if fmt.size() >= 3 and fmt[2] == 0x43:   # 'C': LZO-compressed body
		var usize := s.u32()
		var csize := s.u32()
		body = Lzo1x.decompress(s.bytes(csize), usize)
		if body.is_empty():
			error = "LZO body failed to decompress"
			return
	else:
		body = raw.slice(s.pos)
	if not s.ok():
		error = s.error
		return
	var b := GbxStream.new(body)
	var root := {}
	_node_body(b, root)
	if not b.ok():
		error = "body: " + b.error
	var params: Dictionary = root.get("params", {})
	if params.has("times"):
		var t: Array = params["times"]
		bronze_ms = t[0]
		silver_ms = t[1]
		gold_ms = t[2]
		author_ms = t[3]
	time_limit_ms = params.get("time_limit", -1)


func _header_chunk(cid: int, chunk: PackedByteArray) -> void:
	var r := GbxStream.new(chunk)
	if cid == 0x03043002:
		var v := r.u8()
		if v < 3:
			r.ident()
			r.string()
		r.u32()
		if v >= 1:
			bronze_ms = r.i32()
			silver_ms = r.i32()
			gold_ms = r.i32()
			author_ms = r.i32()
	elif cid == 0x03043003:
		r.u8()
		var id := r.ident()
		uid = id[0]
		environment = id[1]
		author = id[2]
		name = r.string()
		r.u8()
		r.u32()
		r.string()
		var deco := r.ident()
		decoration = deco[0]


func _node_ref(b: GbxStream) -> Variant:
	var idx := b.i32()
	if idx == -1 or not b.ok():
		return null
	if b.nodes.has(idx):
		return b.nodes[idx]
	var node := {"class": wrap_id(b.u32())}
	b.nodes[idx] = node
	_node_body(b, node)
	return node


func _node_body(b: GbxStream, node: Dictionary) -> void:
	while b.ok():
		var cid := wrap_id(b.u32())
		if cid == FACADE:
			return
		if b.peek_u32() == PIKS:
			b.u32()
			var sz := b.u32()
			var end := b.pos + sz
			if cid == 0x03043018:
				lap_race = b.u32() != 0
				nb_laps = b.u32()
			b.pos = end
			continue
		if not _chunk(b, cid, node):
			return
		if cid == 0x0304301F or cid == 0x03043013:
			if not blocks.is_empty() and String(blocks[0]["name"]).contains("TMUnlimiter"):
				unlimiter = true
			return   # the rest of the body (media clips, ...) isn't needed


## Returns false when the chunk is unknown (we can't skip it).
func _chunk(b: GbxStream, cid: int, node: Dictionary) -> bool:
	match cid:
		0x0304300D:
			node["vehicle"] = b.ident()
		0x03043011:
			node["collectors"] = _node_ref(b)
			node["params"] = _node_ref(b)
			b.u32()
		0x0301B000:
			var n := b.u32()
			for i in n:
				b.ident()
				b.u32()
		0x0305B000:
			b.skip(32)
		0x0305B001:
			for i in 4:
				b.string()
		0x0305B004:
			node["times"] = [b.i32(), b.i32(), b.i32(), b.i32(), b.i32()]
		0x0305B005:
			b.skip(12)
		0x0305B006:
			b.skip(4 * b.u32())
		0x0305B008:
			node["time_limit"] = b.i32()
			b.i32()
		0x0305B00D:
			_node_ref(b)
		0x03059000:
			node["text"] = b.string()
			b.string()
		0x03059001:
			node["text"] = b.string()
			node["pack"] = b.fileref()
		0x03059002:
			node["text"] = b.string()
			node["pack"] = b.fileref()
			b.fileref()
		0x03059003:
			b.u32()
			b.fileref()
		0x2E009000:
			var v := b.u32()
			if v == 1:
				b.u32()
				node["order"] = b.u32()
			elif v == 2:
				node["tag"] = b.string()
				node["order"] = b.u32()
		0x0304301F:
			_blocks(b)
		0x03043013:     # TrackMania PowerUp's block list: no version, the oldest block layout
			_blocks(b, true)
		_:
			b.fail("unknown chunk %08X" % cid)
			return false
	return true


func _blocks(b: GbxStream, legacy := false) -> void:
	var id := b.ident()
	if uid.is_empty():
		uid = id[0]
	var n2 := b.string()
	if name.is_empty():
		name = n2
	b.ident()
	size = Vector3i(b.u32(), b.u32(), b.u32())
	b.u32()
	var ver := 0 if legacy else b.u32()
	b.u32()   # block count (free blocks are listed too)
	while b.ok() and b.remaining() >= 4 and (b.peek_u32() & 0xC0000000) != 0:
		var bname := b.lookback()
		var dir := b.u8()
		var coord := Vector3i(b.u8(), b.u8(), b.u8())
		var flags := b.u16() if ver == 0 else b.u32()
		var blk := {"name": bname, "dir": dir, "coord": coord, "flags": flags,
			"ground": (flags & 0x1000) != 0, "variant": flags & 0x3F, "skin": ""}
		if flags != 0xFFFFFFFF and (ver == 0 and flags != 0xFFFF or ver != 0):
			if flags & 0x8000:
				b.lookback()
				var skin: Variant = _node_ref(b)
				if skin is Dictionary:
					blk["skin"] = (skin as Dictionary).get("pack", "")
			# bit 20: a waypoint's special property, from version 2 of the list (version 1's bit is unrelated)
			if ver >= 2 and flags & 0x100000:
				_node_ref(b)
		blocks.append(blk)


func medal_text(ms: int) -> String:
	if ms < 0:
		return "-"
	return "%d:%02d.%02d" % [ms / 60000, (ms / 1000) % 60, (ms % 1000) / 10]
