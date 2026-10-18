class_name TmTracks
extends RefCounted
## SpeedFest's own tracks: tracks/*.json (track specs, laid out by TmTrackBuilder from the
## recreated blocks; ids are the file names, SF01 ..). The campaign (the menu, the server's
## rotation) is the list in tracks/campaign.json, in its order; any other track file can still be
## raced by id (--track=), e.g. one being made or tested. campaign.json is a list of ids (one
## series) or {"series": [{"name": "White", "tracks": ["A01", ..]}, ..]} (the menu's tabs).
## TMNF's campaign (from a TMNF install) and .Challenge.Gbx files are optional extras (TmStage).

const DIR := "res://tracks"
const CAMPAIGN := "campaign.json"

static var _specs := {}
static var _ids: Array[String] = []
static var _series: Array = []


static func _load() -> void:
	if not _ids.is_empty():
		return
	var files := Array(DirAccess.get_files_at(DIR))
	files.sort()
	for f: String in files:
		if not f.ends_with(".json") or f == CAMPAIGN:
			continue
		var text := FileAccess.get_file_as_string(DIR.path_join(f))
		var spec: Variant = JSON.parse_string(text)
		if not spec is Dictionary:
			push_error("tracks: %s isn't a track spec" % f)
			continue
		var id := f.get_basename()
		(spec as Dictionary)["id"] = id
		_specs[id] = spec
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(CAMPAIGN)))
	var groups: Array = []
	if listed is Dictionary and (listed as Dictionary).get("series") is Array:
		for g: Variant in listed["series"]:
			if g is Dictionary:
				groups.append({"name": String(g.get("name", "")), "tracks": g.get("tracks", [])})
	else:
		groups.append({"name": "SpeedFest", "tracks": listed if listed is Array else _specs.keys()})
	for g: Dictionary in groups:
		var ids_in: Array[String] = []
		for id: Variant in g["tracks"]:
			if _specs.has(String(id)) and not _ids.has(String(id)):
				_ids.append(String(id))
				ids_in.append(String(id))
		if not ids_in.is_empty():
			_series.append({"name": g["name"], "tracks": ids_in})


## The campaign's track ids, in order.
static func ids() -> Array[String]:
	_load()
	return _ids.duplicate()


## The campaign's series, in order: [{name, tracks (ids)}].
static func series() -> Array:
	_load()
	return _series.duplicate(true)


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
	_series.clear()
