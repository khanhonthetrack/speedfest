class_name TmEditorModel
extends RefCounted
## The track editor's rules, apart from its scene (testable headless): placing a block where its
## cells are free and inside the map (one start per track), erasing, undo and redo, what a track
## still needs before it can be raced. Works on a TmUserTracks track ({..., "blocks": [[id, dir,
## x, y, z], ...]}); the scene rebuilds what changed (TmUserTracks.challenge_blocks).

const UNDO_MAX := 200

var track: Dictionary
var dirty := false
var _occ := {}                     ## Vector3i -> the block (Array) covering that cell
var _undo: Array = []              ## snapshots of track.blocks before each change
var _redo: Array = []


func _init(t: Dictionary = {}) -> void:
	track = t if not t.is_empty() else TmUserTracks.blank()
	reindex()


func reindex() -> void:
	_occ.clear()
	for b: Array in track["blocks"]:
		for c in cells_of(b):
			_occ[c] = b


static func cells_of(b: Array) -> Array[Vector3i]:
	return TmUserTracks.cells(String(b[0]), int(b[1]), Vector3i(int(b[2]), int(b[3]), int(b[4])))


## Where a block goes so that its first unit sits on the cursor's cell.
static func anchor(id: String, d: int, cursor: Vector3i) -> Vector3i:
	var units := TmUserTracks.units(id, d)
	if units.is_empty():
		return cursor
	return cursor - (units[0][0] as Vector3i)


static func waypoint(id: String) -> int:
	return int(TmBlockCatalogue.info(id).get("waypoint", TmBlockCatalogue.Waypoint.NONE))


## Why a block can't go there ("" if it can).
func why_not(id: String, d: int, coord: Vector3i) -> String:
	if TmBlockCatalogue.info(id).is_empty():
		return "unknown block"
	for c in TmUserTracks.cells(id, d, coord):
		if not TmUserTracks.inside(c):
			return "outside the stadium"
		if _occ.has(c):
			return "the space is taken"
	if waypoint(id) == TmBlockCatalogue.Waypoint.START and starts() > 0:
		return "a track has one start"
	return ""


func place(id: String, d: int, coord: Vector3i) -> bool:
	if not why_not(id, d, coord).is_empty():
		return false
	_snapshot()
	var b := [id, posmod(d, 4), coord.x, coord.y, coord.z]
	(track["blocks"] as Array).append(b)
	for c in cells_of(b):
		_occ[c] = b
	return true


## The block covering a cell ([] if none).
func block_at(c: Vector3i) -> Array:
	return _occ.get(c, [])


func erase_at(c: Vector3i) -> bool:
	var b := block_at(c)
	if b.is_empty():
		return false
	_snapshot()
	(track["blocks"] as Array).erase(b)
	for cc in cells_of(b):
		_occ.erase(cc)
	return true


func _snapshot() -> void:
	_undo.append((track["blocks"] as Array).duplicate(true))
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()
	_redo.clear()
	dirty = true


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append((track["blocks"] as Array).duplicate(true))
	track["blocks"] = _undo.pop_back()
	reindex()
	dirty = true
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append((track["blocks"] as Array).duplicate(true))
	track["blocks"] = _redo.pop_back()
	reindex()
	dirty = true
	return true


func starts() -> int:
	var n := 0
	for b: Array in track["blocks"]:
		if waypoint(String(b[0])) == TmBlockCatalogue.Waypoint.START:
			n += 1
	return n


## What the track lacks to be raced: "" when it has a start (or a start/finish line) and a finish
## (or a start/finish line).
func missing() -> String:
	var start := false
	var finish := false
	for b: Array in track["blocks"]:
		match waypoint(String(b[0])):
			TmBlockCatalogue.Waypoint.START:
				start = true
			TmBlockCatalogue.Waypoint.FINISH:
				finish = true
			TmBlockCatalogue.Waypoint.START_FINISH:
				start = true
				finish = true
	if not start:
		return "Place a start"
	if not finish:
		return "Place a finish"
	return ""
