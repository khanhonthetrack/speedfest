class_name TmTracks
extends RefCounted
## SpeedFest's own tracks, the game's campaign: tracks/*.json (track specs, laid out by
## TmTrackBuilder from the recreated blocks), in file name order. Ids are the file names (SF01 ..).
## TMNF's campaign (from a TMNF install) and .Challenge.Gbx files are optional extras (TmStage).

const DIR := "res://tracks"

static var _specs := {}
static var _ids: Array[String] = []


static func _load() -> void:
	if not _ids.is_empty():
		return
	var files := Array(DirAccess.get_files_at(DIR))
	files.sort()
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string(DIR.path_join(f))
		var spec: Variant = JSON.parse_string(text)
		if not spec is Dictionary:
			push_error("tracks: %s isn't a track spec" % f)
			continue
		var id := f.get_basename()
		(spec as Dictionary)["id"] = id
		_specs[id] = spec
		_ids.append(id)


## Our track ids, in order.
static func ids() -> Array[String]:
	_load()
	return _ids.duplicate()


static func has(id: String) -> bool:
	_load()
	return _specs.has(id)


static func spec(id: String) -> Dictionary:
	_load()
	return _specs.get(id, {})


## The track as a TmChallenge (blocks and the bot's line); error set if it doesn't lay out.
static func challenge(id: String) -> TmChallenge:
	if not has(id):
		var none := TmChallenge.new()
		none.error = "no track %s" % id
		return none
	return TmTrackBuilder.challenge(spec(id))


## The track after `id` in the campaign ("" after the last).
static func next(id: String) -> String:
	var i := ids().find(id)
	return _ids[i + 1] if i >= 0 and i + 1 < _ids.size() else ""


## Forgets the loaded specs (after the files change: medal times written by the track test).
static func reload() -> void:
	_ids.clear()
	_specs.clear()
