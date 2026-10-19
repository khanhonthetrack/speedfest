class_name TmSolid
extends RefCounted
## A TMNF car model (MainBody.Solid.Gbx, a CPlugSolid) as players share them (ManiaPark car models
## and skins): its tree of parts, each a triangle mesh with UVs. Our own reader of the public GBX
## format, chunk layouts as documented by GBX.NET (Unlicense); prototype and checks:
## tests/test_compat_cars over a ManiaPark sample (stadium/tools/compat/fetch_maniapark.py).
## Reads binary files (compressed or not) and the old text ones (format 'T': values as text lines,
## ids and class ids in hex, data arrays raw), and every chunk version TM 1.0 to TMNF wrote.
##
## Coordinates are TMNF's car frame, which is the car's visual frame (TmCarVisual: x left, y up,
## z forward, ground at y 0; TMNF's FL wheel is at +x). TMNF winds front faces counter-clockwise
## about their normal, Godot clockwise: triangles are reversed. Every file (binary or text) keeps
## texture v upwards (0 at the texture's bottom, as GBX.NET's OBJ export shows); UVs are flipped
## to Godot's. Checked against ManiaPark's screenshots (lettering, liveries) of 27 packs.
##
## parts: [{name, xform (Transform3D: the part's place in the car), verts (PackedVector3Array),
##          normals (PackedVector3Array, may be empty), uvs (PackedVector2Array, may be empty),
##          indices (PackedInt32Array)}]
## points: {name: Transform3D} the tree's nodes without geometry (lights, dummies).

const CLASS_SOLID := 0x09005000
const FACADE := 0xFACADE01
const PIKS := 0x534B4950
const TEXT_SKIP := "1397442896"     ## "PIKS" as a text u32: a skippable chunk in a text file
const MAX_NODES := 100000

var error := ""
var parts: Array = []
var points := {}

var _d: PackedByteArray
var _p := 0
var _text := false
var _ids: PackedStringArray = []
var _ids_started := false
var _nodes := {}                     ## node index -> Dictionary
var _refs := {}                      ## node index -> external file name


static func load_bytes(bytes: PackedByteArray) -> TmSolid:
	var s := TmSolid.new()
	s._parse(bytes)
	return s


static func load_file(path: String) -> TmSolid:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		var s := TmSolid.new()
		s.error = "cannot open %s" % path
		return s
	return load_bytes(f.get_buffer(f.get_length()))


func ok() -> bool:
	return error.is_empty()


## Triangles in all parts.
func triangle_count() -> int:
	var n := 0
	for p: Dictionary in parts:
		n += (p["indices"] as PackedInt32Array).size() / 3
	return n


# --- file -----------------------------------------------------------------------------------------

func _parse(raw: PackedByteArray) -> void:
	if raw.size() < 20 or raw.slice(0, 3).get_string_from_ascii() != "GBX":
		error = "not a GBX file"
		return
	var ver := raw.decode_u16(3)
	if ver < 6:
		error = "GBX version %d not supported" % ver
		return
	var root := {}
	if raw[5] == 0x54:   # 'T': a text file
		_d = raw
		_p = 9
		_text = true
		var cls := _hex()
		if _u32() != 0:
			error = "a text file with header chunks"
			return
		_u32()   # nodes
		if _u32() != 0:
			error = "a text file with external references"
			return
		root["cls"] = cls
	else:
		var cls := raw.decode_u32(9)
		var p := 17 + raw.decode_u32(13)
		if p + 8 > raw.size():
			error = "truncated header"
			return
		p += 4   # nodes
		p = _read_refs(raw, p)
		if not error.is_empty():
			return
		if raw[7] == 0x43:   # 'C': LZO body
			var usize := raw.decode_u32(p)
			var csize := raw.decode_u32(p + 4)
			if p + 8 + csize > raw.size():
				error = "truncated body"
				return
			_d = Lzo1x.decompress(raw.slice(p + 8, p + 8 + csize), usize)
			if _d.is_empty():
				error = "the body failed to decompress"
				return
		else:
			_d = raw.slice(p)
		_p = 0
		root["cls"] = cls
	if int(root["cls"]) != CLASS_SOLID:
		error = "not a car mesh (class %08X, not a CPlugSolid)" % int(root["cls"])
		return
	_nodes[0] = root
	_body(root)
	if not error.is_empty():
		return
	var tree: Variant = root.get("tree")
	if not tree is Dictionary or (tree as Dictionary).has("ext"):
		error = "the model has no tree of parts"
		return
	_walk(tree, Transform3D.IDENTITY, 0)
	if parts.is_empty():
		error = "the model has no geometry"


## The header's external references (files the model points at: shaders, textures of the game's
## own packs): node index -> file name. A car draws without them (its textures are in the pack).
func _read_refs(raw: PackedByteArray, p: int) -> int:
	var ne := raw.decode_u32(p)
	p += 4
	if ne == 0:
		return p
	if ne > MAX_NODES:
		error = "bad reference table"
		return p
	p += 4   # ancestor level
	var folders: PackedStringArray = []
	var stack := [[raw.decode_u32(p), ""]]
	p += 4
	while not stack.is_empty() and p < raw.size():
		var top: Array = stack.back()
		if int(top[0]) == 0:
			stack.pop_back()
			continue
		top[0] = int(top[0]) - 1
		var n := raw.decode_u32(p)
		var name := raw.slice(p + 4, p + 4 + n).get_string_from_utf8()
		p += 4 + n
		var path := String(top[1]) + name + "/"
		folders.append(path)
		stack.append([raw.decode_u32(p), path])
		p += 4
	for i in ne:
		if p + 8 > raw.size():
			error = "truncated reference table"
			return p
		var flags := raw.decode_u32(p)
		p += 4
		var name := ""
		if flags & 4 == 0:
			var n := raw.decode_u32(p)
			name = raw.slice(p + 4, p + 4 + n).get_string_from_utf8()
			p += 4 + n
		else:
			name = "resource %d" % raw.decode_u32(p)
			p += 4
		var idx := raw.decode_u32(p)
		p += 8   # node index, use-file
		if flags & 4 == 0:
			var fi := raw.decode_u32(p)
			p += 4
			if fi > 0 and fi <= folders.size():
				name = folders[fi - 1] + name
		_refs[idx] = name
	return p


# --- the tree -------------------------------------------------------------------------------------

func _walk(t: Dictionary, parent: Transform3D, depth: int) -> void:
	if depth > 64:
		return
	var xf := parent * (t["loc"] as Transform3D) if t.has("loc") else parent
	var name := String(t.get("name", ""))
	var v: Variant = t.get("visual")
	if v is Dictionary and (v as Dictionary).has("verts") and (v as Dictionary).has("indices"):
		_add_part(name, xf, v)
	elif not name.is_empty():
		points[name] = xf
	for c: Variant in t.get("children", []):
		if c is Dictionary and not (c as Dictionary).has("ext"):
			_walk(c, xf, depth + 1)
	# a level-of-detail node: its nearest (most detailed) level
	var levels: Array = t.get("levels", [])
	var best: Variant = null
	var best_z := INF
	for lv: Array in levels:
		if lv[1] is Dictionary and not (lv[1] as Dictionary).has("ext") and float(lv[0]) < best_z:
			best_z = float(lv[0])
			best = lv[1]
	if best != null:
		_walk(best, xf, depth + 1)


func _add_part(name: String, xf: Transform3D, v: Dictionary) -> void:
	var verts: PackedVector3Array = v["verts"]
	var src: PackedInt32Array = v["indices"]
	var n := verts.size()
	var idx := PackedInt32Array()
	idx.resize(src.size() / 3 * 3)
	var k := 0
	for i in range(0, src.size() - 2, 3):
		var a := src[i]
		var b := src[i + 1]
		var c := src[i + 2]
		if a >= n or b >= n or c >= n:
			continue
		idx[k] = a          # counter-clockwise (TMNF) -> clockwise (Godot)
		idx[k + 1] = c
		idx[k + 2] = b
		k += 3
	idx.resize(k)
	if k == 0:
		return
	var uvs: PackedVector2Array = (v.get("uv0", PackedVector2Array()) as PackedVector2Array).duplicate()
	if uvs.size() != n:
		uvs = PackedVector2Array()
	for i in uvs.size():
		uvs[i].y = 1.0 - uvs[i].y
	var normals: PackedVector3Array = v.get("normals", PackedVector3Array())
	if normals.size() != n:
		normals = PackedVector3Array()
	parts.append({"name": name, "xform": xf, "verts": verts, "normals": normals, "uvs": uvs, "indices": idx})


# --- primitives (binary, or text lines) -----------------------------------------------------------

func _fail(why: String) -> void:
	if error.is_empty():
		error = "%s (at byte %d)" % [why, _p]


func _need(n: int) -> bool:
	if _p + n > _d.size():
		_fail("unexpected end of data")
		return false
	return true


func _line() -> String:
	var e := -1
	var stop := mini(_p + 300, _d.size() - 1)
	for i in range(_p, stop):
		if _d[i] == 0x0D and _d[i + 1] == 0x0A:
			e = i
			break
	if e < 0:
		_fail("a text value too long")
		_p = _d.size()
		return ""
	var s := _d.slice(_p, e).get_string_from_ascii()
	_p = e + 2
	return s


func _u32() -> int:
	if _text:
		return _line().to_int() & 0xFFFFFFFF
	if not _need(4):
		return 0
	_p += 4
	return _d.decode_u32(_p - 4)


func _i32() -> int:
	var v := _u32()
	return v - 0x100000000 if v & 0x80000000 else v


## A class or chunk id (hex in text files).
func _hex() -> int:
	if _text:
		return _line().hex_to_int() & 0xFFFFFFFF
	return _u32()


## Raw 32 bits even in text files ("data" values).
func _data32() -> int:
	if not _need(4):
		return 0
	_p += 4
	return _d.decode_u32(_p - 4)


func _data64() -> int:
	if not _need(8):
		return 0
	_p += 8
	return _d.decode_u64(_p - 8)


func _u64() -> int:
	if _text:
		return _line().to_int()
	return _data64()


func _u16() -> int:
	if _text:
		return _line().to_int() & 0xFFFF
	if not _need(2):
		return 0
	_p += 2
	return _d.decode_u16(_p - 2)


func _i16() -> int:
	var v := _u16()
	return v - 0x10000 if v & 0x8000 else v


func _u8() -> int:
	if not _need(1):
		return 0
	_p += 1
	return _d[_p - 1]


func _f32() -> float:
	if _text:
		return _line().to_float()
	if not _need(4):
		return 0.0
	_p += 4
	return _d.decode_float(_p - 4)


func _floats(n: int) -> void:
	if _text:
		for i in n:
			_line()
	else:
		_skip(4 * n)


func _b() -> bool:
	if _text:
		var s := _line()
		if s != "True" and s != "False":
			_fail("bad boolean %s" % s)
		return s == "True"
	var v := _u32()
	if v > 1:
		_fail("bad boolean %d" % v)
	return v == 1


func _str() -> String:
	if _text:
		return _line()
	var n := _u32()
	if n > _d.size() - _p:
		_fail("bad string length %d" % n)
		return ""
	_p += n
	return _d.slice(_p - n, _p).get_string_from_utf8()


func _skip(n: int) -> void:
	if n < 0 or not _need(n):
		_p = _d.size()
		return
	_p += n


func _ident() -> String:
	if not _ids_started:
		_ids_started = true
		_u32()   # version
	var v := 0
	if _text:
		var s := _line()
		v = 0xFFFFFFFF if s == "4294967295" else (s.hex_to_int() & 0xFFFFFFFF)
	else:
		v = _u32()
	if v == 0xFFFFFFFF:
		return ""
	if v & 0xC0000000:
		if v & 0x3FFFFFFF == 0:
			var s := _str()
			_ids.append(s)
			return s
		var i := (v & 0x3FFFFFFF) - 1
		return _ids[i] if i >= 0 and i < _ids.size() else ""
	return "#%d" % v


## The next u32 if it reads as a chunk id (0 if it can't be one): no raw value ever does.
func _peek_id() -> int:
	if not _text:
		return _d.decode_u32(_p) if _p + 4 <= _d.size() else 0
	var e := _p
	while e < mini(_p + 12, _d.size()) and _d[e] != 0x0D:
		var c := _d[e]
		if not ((c >= 0x30 and c <= 0x39) or (c >= 0x61 and c <= 0x66) or (c >= 0x41 and c <= 0x46)):
			return 0
		e += 1
	return _d.slice(_p, e).get_string_from_ascii().hex_to_int() if e > _p else 0


## A node reference: the node read inline the first time, {ext: name} for an external file, null.
func _node() -> Variant:
	var idx := _i32()
	if idx == -1:
		return null
	if _refs.has(idx):
		return {"ext": _refs[idx]}
	if _nodes.has(idx):
		return _nodes[idx]
	if idx < 0 or idx > MAX_NODES:
		_fail("bad node index %d" % idx)
		return null
	var n := {"cls": _hex()}
	_nodes[idx] = n
	_body(n)
	return n


func _node_list() -> Array:
	var out := []
	var n := _u32()
	if n > MAX_NODES:
		_fail("bad node count %d" % n)
		return out
	for i in n:
		out.append(_node())
		if not error.is_empty():
			break
	return out


func _iso4() -> Transform3D:
	var m := []
	for i in 12:
		m.append(_f32())
	return Transform3D(Basis(Vector3(m[0], m[3], m[6]), Vector3(m[1], m[4], m[7]), Vector3(m[2], m[5], m[8])),
		Vector3(m[9], m[10], m[11]))


## Reads a node's chunks up to its end marker.
func _body(n: Dictionary) -> void:
	while error.is_empty():
		var cid := _hex()
		if cid == FACADE or not error.is_empty():
			return
		var size := -1
		if _text:
			if _p + 12 <= _d.size() and _d.slice(_p, _p + 10).get_string_from_ascii() == TEXT_SKIP:
				_p += 12
				size = _u32()
		elif _p + 4 <= _d.size() and _d.decode_u32(_p) == PIKS:
			_p += 4
			size = _u32()
		if size >= 0:
			var end := _p + size
			if end > _d.size():
				_fail("bad skippable chunk size")
				return
			if not _text:
				_chunk(cid, n)
			_p = end
			continue
		if not _chunk(cid, n):
			_fail("unknown chunk %08X in class %08X" % [cid, int(n.get("cls", 0))])
			return


# --- chunks (GBX.NET's layouts) -------------------------------------------------------------------

## Reads chunk cid of node n; false if we don't know it.
func _chunk(cid: int, n: Dictionary) -> bool:
	match cid:
		# CPlugSolid
		0x09005000:
			_i32()
		0x09005006:
			_floats(15)
		0x09005007:
			_b()
		0x0900500B:
			for i in 6:
				_b()
			_i32()
		0x0900500C:
			for i in 10:
				_b()
			_f32()
			_i32()
			_floats(4)
			_i32()
			_i32()
		0x0900500D:
			_b()
			_b()
			n["tree"] = _node()
		0x0900500E:
			_floats(16)
		0x0900500F:
			_floats(2)
		0x09005010:
			_node()
		0x09005011:
			_b()
			if _b():
				_b()
			n["tree"] = _node()
		0x09005012:
			_u8()
		# CPlugTree, CPlugTreeVisualMip
		0x0904F006:
			_u32()
			n["children"] = _node_list()
		0x0904F00C:
			if _i32() != 0:
				_fail("tree ids not supported")
		0x0904F00D:
			n["name"] = _ident()
			_ident()
		0x0904F011, 0x0904F017:
			_node()
		0x0904F015, 0x0904F019, 0x0904F01A:
			_tree_location(n, _data32())
		0x0904F018:
			_tree_location(n, _data64())
		0x0904F016:
			n["visual"] = _node()
			_node()   # shader
			_node()   # surface
			_node()   # generator
		0x09015002:
			var levels := []
			for i in _u32():
				levels.append([_f32(), _node()])
				if not error.is_empty():
					break
			n["levels"] = levels
		# CPlugVisual, CPlugVisual3D, CPlugVisualIndexed, CPlugIndexBuffer
		0x09006001:
			_ident()
		0x09006004, 0x0902C002:
			_node()
		0x09006005:
			_floats(3 * _u32())   # sub-visuals: three ints each, as wide as floats
		0x09006006:
			n["has_normals"] = _b()
		0x09006007:
			_b()
		0x09006009:
			_f32()
		0x0900600B:
			for i in _u32():
				_i32()
				_i32()
				_floats(6)
		0x09006008, 0x0900600A, 0x0900600C:
			_visual_old(cid, n)
		0x0900600D:
			_visual(n, 1, false, -1)
		0x0900600E:
			_visual(n, 2, true, -1)
		0x0900600F:
			var v := _i32()
			_visual(n, 2 + v, true, v)
		0x0902C003:
			_vertices_old(n)
		0x0902C004:
			_vertices(n)
		0x0906A000:
			var idx := PackedInt32Array()
			for i in _i32():
				idx.append(_u16())
			n["indices"] = idx
		0x0906A001:
			if _b():
				var ib := {"cls": 0x09057000}
				_body(ib)
				n["indices"] = ib.get("indices", PackedInt32Array())
		0x09057000:
			_data32()
			var k := _i32()
			if k < 0 or not _need(2 * k):
				return true
			var idx := PackedInt32Array()
			idx.resize(k)
			for i in k:
				idx[i] = _d.decode_u16(_p + 2 * i)
			_p += 2 * k
			n["indices"] = idx
		0x09057001:
			_data32()
			var k := _i32()
			var idx := PackedInt32Array()
			idx.resize(maxi(k, 0))
			var cur := 0
			for i in k:
				cur = (cur + _i16()) & 0xFFFF
				idx[i] = cur
			n["indices"] = idx
		# shaders: read through (a car's textures come from its pack, by part name)
		0x09002007:
			_node()
			_node_list()
			_node()
		0x0900200E:
			_node()
			_node_list()
			_node()
			_node_list()
		0x09002010:
			_u64()
			_f32()
			_node()
			_u16()
		0x09002014, 0x09002015, 0x09002016:
			_data64()
			_f32()
			_node()
			_u16()
		0x09002018, 0x0900201D:
			_u32()
		0x09004001, 0x09004002, 0x09004003:
			_skip(88)
		0x09026001:
			_i32()
			_i32()
			_node_list()
			_data32()
		0x09026002:
			_node_list()
		0x09026004, 0x09026006, 0x09026007:
			_i32()
		0x09026008:
			_i32()
			_i32()
		0x0902600A:
			_u32()
			_u32()
			_u32()
		0x0902600D, 0x09026010:
			_u8()
		0x09063002:   # CPlugShaderMaterial (TM Sunrise's)
			_data32()
			_i32()
			for i in 5:
				_node()
		# bitmaps
		0x0907E002, 0x0907E005, 0x0907E006, 0x0907E007, 0x0907E008:
			_sampler()
		0x0907E00B:
			_u32()
			_sampler()
		0x09047002:
			_i32()
		0x09047004, 0x09047005:
			_i32()
			_u8()
			_i32()
			_b()
			_b()
			_b()
		0x09047007:
			_u32()
			_i32()
			var k := _u8()
			if k == 1:
				_floats(6)
			elif k == 2:
				_floats(16)
		0x09047008:
			_i32()
			_f32()
		0x09047009, 0x09011019:
			_f32()
		0x09011014, 0x09011015, 0x09011018, 0x09011022:
			var image: Variant = _node()
			_u64()
			_floats(3)
			_i32()
			if cid in [0x09011018, 0x09011022] and image != null:
				_node()
		0x09011017:
			_u32()
			_floats(2)
		0x0901101B, 0x0901101F, 0x09011021, 0x09011023, 0x09011024:
			_u32()
		0x0901101C:
			_floats(5)
		0x0901101D:
			_i16()
			_i16()
		0x09011020:
			_floats(_u32())
		_:
			return false
	return true


func _sampler() -> void:
	_ident()
	_node()
	_u32()
	_f32()


## A tree node's flags and place. TM 1.0's chunk sets bit 2 without a place in some files: a place
## never starts with what reads as one of the node's chunk ids.
func _tree_location(n: Dictionary, flags: int) -> void:
	if flags & 4 == 0:
		return
	var nxt := _peek_id()
	if (nxt & 0xFFFFF000) in [0x0904F000, 0x09015000] or nxt == FACADE:
		return
	n["loc"] = _iso4()


## The visual's flags as the chunks store them -> CPlugVisual's.
static func _chunk_flags(x: int) -> int:
	var f := x & 15
	f |= (x << 1) & 0x20
	f |= (x << 2) & 0x80
	f |= (x << 2) & 0x100
	f |= (x << 13) & 0x100000
	f |= (x << 13) & 0x200000
	f |= (x << 13) & 0x400000
	return f


## Older visual headers (TM 1.0 / Sunrise): 0x008, 0x00A, 0x00C.
func _visual_old(cid: int, n: Dictionary) -> void:
	var flags := int(n.get("flags", 0)) | (0x80 if n.get("has_normals", false) else 0)
	if _b():
		flags |= 8
	if _b():
		flags |= 0x20
	var ntc := _i32()
	var skin := _i32() & 7
	flags |= skin
	n["count"] = _i32()
	n["streams"] = [] if cid == 0x09006008 else _node_list()
	_texcoords(n, ntc)
	if skin != 0:
		if cid != 0x0900600C:
			_fail("skinned visual in chunk %08X" % cid)
			return
		_skin_data(0)
	if _b():
		flags |= 0x100
	n["flags"] = flags
	if cid == 0x0900600C:
		_floats(6)
	else:
		_skip(48 * _u32())


func _visual(n: Dictionary, version: int, bitmaps: bool, ver_f: int) -> void:
	var flags := _chunk_flags(_i32())
	if n.get("has_normals", false):
		flags |= 0x80
	n["flags"] = flags
	var ntc := _i32()
	n["count"] = _i32()
	n["streams"] = _node_list()
	_texcoords(n, ntc)
	if flags & 7:
		_skin_data(version)
	_floats(6)   # bounding box
	if bitmaps:
		for i in _u32():
			for j in 5:
				_i32()
	if ver_f >= 5:
		_skip(2 * _u32())
		if ver_f >= 6:
			_i32()
			var k := _i32()
			if k > 0:
				_skip(k - 4)


## Texture coordinate sets: the first one is the model's UVs (raw data even in text files).
func _texcoords(n: Dictionary, ntc: int) -> void:
	var cnt := int(n.get("count", 0))
	if cnt < 0 or ntc < 0 or ntc > 8:
		_fail("bad vertex count")
		return
	for s in ntc:
		var v := _i32()
		var fl := -1
		if v >= 3:
			if _i32() != cnt:
				_fail("texture coordinates don't match the vertices")
				return
			fl = _i32()
		var stride := 8
		if v >= 1 and v < 3:
			stride += 4
		if v >= 2 and v < 3:
			stride += 4
		if not _need(cnt * stride):
			return
		if s == 0:
			var uv := PackedVector2Array()
			uv.resize(cnt)
			for i in cnt:
				var at := _p + i * stride
				uv[i] = Vector2(_d.decode_float(at), _d.decode_float(at + 4))
			n["uv0"] = uv
		_p += cnt * stride
		if fl >= 0:
			_skip(4 * ((cnt * fl) & 0xFF))


func _skin_data(version: int) -> void:
	_b()
	_i32()
	if version >= 5:
		if _b():
			_fail("skin data not supported")
			return
		_b()
	var bones := _i32()
	if version == 2:
		_skip(48 * _u32())
	for i in bones:
		_ident()
	if version != 3:
		_skip(4 * _u32())


## TM 1.0's vertices: position, normal and two unknowns, then two tangent arrays.
func _vertices_old(n: Dictionary) -> void:
	var cnt := int(n.get("count", 0))
	if not _need(cnt * 40):
		return
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(cnt)
	normals.resize(cnt)
	for i in cnt:
		var at := _p + i * 40
		verts[i] = Vector3(_d.decode_float(at), _d.decode_float(at + 4), _d.decode_float(at + 8))
		normals[i] = Vector3(_d.decode_float(at + 12), _d.decode_float(at + 16), _d.decode_float(at + 20))
	_p += cnt * 40
	n["verts"] = verts
	n["normals"] = normals
	_skip(12 * _u32())
	_skip(12 * _u32())


## Vertices: position, then a normal (packed in 10-bit fields or three floats) and a colour (packed
## or four floats) as the visual's flags say; then two tangent arrays. Visuals whose vertices are in
## vertex streams keep none here.
func _vertices(n: Dictionary) -> void:
	var fl := int(n.get("flags", 0))
	var has_n := (fl & (1 << 22)) == 0 or (fl & (1 << 7)) != 0
	var has_c := (fl & (1 << 22)) == 0 or (fl & (1 << 8)) != 0
	var packed_n := (fl & (1 << 20)) != 0
	var packed_c := (fl & (1 << 21)) != 0
	var cnt := int(n.get("count", 0))
	if (n.get("streams", []) as Array).is_empty():
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		verts.resize(cnt)
		if has_n:
			normals.resize(cnt)
		for i in cnt:
			verts[i] = Vector3(_f32(), _f32(), _f32())
			if has_n:
				if packed_n:
					var k := _i32()
					normals[i] = Vector3(_s10(k, 0), _s10(k, 10), _s10(k, 20))
				else:
					normals[i] = Vector3(_f32(), _f32(), _f32())
			if has_c:
				if packed_c:
					_i32()
				else:
					_floats(4)
			if not error.is_empty():
				return
		n["verts"] = verts
		n["normals"] = normals
	var per := (~((fl >> 17) & 0xFF) & 8) | 4
	for t in 2:
		var k := _i32()
		if k != 0 and k != cnt:
			_fail("tangents don't match the vertices")
			return
		_skip(k * per)


## A signed 10-bit field of a packed normal, as a -1..1 float.
static func _s10(k: int, shift: int) -> float:
	var v := (k >> shift) & 0x3FF
	if v & 0x200:
		v -= 0x400
	return v / 511.0
