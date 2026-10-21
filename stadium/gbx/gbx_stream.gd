class_name GbxStream
extends RefCounted
## Little-endian reader over a GBX byte buffer with the format's lookback strings ("ids") and
## inline node references.

const COLLECTIONS := {0: "Desert", 1: "Snow", 2: "Rally", 3: "Island", 4: "Bay", 5: "Coast",
	6: "Stadium", 7: "Valley", 8: "Speed", 11: "Alpine", 12: "Rally", 13: "Island", 14: "Bay",
	25: "Stadium256", 26: "Stadium", 10003: "Common"}

var data: PackedByteArray
var pos := 0
var error := ""
var _ids: PackedStringArray = []
var _ids_started := false
var nodes := {}                 ## node index -> Dictionary


func _init(bytes: PackedByteArray = PackedByteArray(), at: int = 0) -> void:
	data = bytes
	pos = at


func ok() -> bool:
	return error.is_empty()


func fail(why: String) -> void:
	if error.is_empty():
		error = "%s (at byte %d)" % [why, pos]


func remaining() -> int:
	return data.size() - pos


func _need(n: int) -> bool:
	if pos + n > data.size():
		fail("unexpected end of data")
		return false
	return true


func u8() -> int:
	if not _need(1):
		return 0
	pos += 1
	return data[pos - 1]


func u16() -> int:
	if not _need(2):
		return 0
	pos += 2
	return data.decode_u16(pos - 2)


func u32() -> int:
	if not _need(4):
		return 0
	pos += 4
	return data.decode_u32(pos - 4)


func i32() -> int:
	if not _need(4):
		return 0
	pos += 4
	return data.decode_s32(pos - 4)


func f32() -> float:
	if not _need(4):
		return 0.0
	pos += 4
	return data.decode_float(pos - 4)


func peek_u32() -> int:
	if pos + 4 > data.size():
		return 0
	return data.decode_u32(pos)


func bytes(n: int) -> PackedByteArray:
	if not _need(n):
		return PackedByteArray()
	pos += n
	return data.slice(pos - n, pos)


func skip(n: int) -> void:
	if _need(n):
		pos += n


func string() -> String:
	var n := u32()
	if n > remaining():
		fail("bad string length %d" % n)
		return ""
	return bytes(n).get_string_from_utf8()


## Starts a fresh lookback-string table (each header chunk and the body have their own).
func reset_ids() -> void:
	_ids = []
	_ids_started = false


func lookback() -> String:
	if not _ids_started:
		var ver := u32()
		if ver < 2:
			fail("lookback version %d" % ver)
			return ""
		_ids_started = true
	var v := u32()
	if v == 0xFFFFFFFF or v == 0xFFFFFFFE:     # unassigned (some editors write -2: TMX tracks' vehicle)
		return ""
	if (v & 0xC0000000) != 0 and (v & 0x3FFFFFFF) == 0:
		var s := string()
		_ids.append(s)
		return s
	if (v & 0xC0000000) == 0:
		return COLLECTIONS.get(v, "#%d" % v)
	var i := (v & 0x3FFFFFFF) - 1
	if i < 0 or i >= _ids.size():
		fail("lookback index %d out of range" % i)
		return ""
	return _ids[i]


## Ident: [id, collection, author].
func ident() -> PackedStringArray:
	return PackedStringArray([lookback(), lookback(), lookback()])


## File reference (path of a pack/skin file).
func fileref() -> String:
	var v := u8()
	if v >= 3:
		skip(32)
	var path := string()
	if (path.length() > 0 and v >= 1) or v >= 3:
		string()
	return path
