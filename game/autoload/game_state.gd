extends Node
## Session state shared between the menu, the garage and the race: which track is selected, the
## result of the last run, and the personal bests (user://records.json).

signal track_changed(track_id: String)
signal record_set(track_id: String, car_id: String, ms: int)

const SAVE_PATH := "user://records.json"

var track: String = "downtown"
var laps: int = 2
## track_id -> {car_id -> best lap ms}, plus "_any" for the best regardless of car.
var records: Dictionary = {}
var last_result: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_records()
	if TestHooks.has_arg("track"):
		track = String(TestHooks.arg("track", track))
	if TestHooks.has_arg("laps"):
		laps = maxi(1, int(TestHooks.arg("laps", laps)))


func select_track(id: String) -> void:
	if id == track:
		return
	track = id
	track_changed.emit(id)


func best_lap(track_id: String, car_id: String = "") -> int:
	var t: Dictionary = records.get(track_id, {})
	if car_id == "":
		return int(t.get("_any", 0))
	return int(t.get(car_id, 0))


## Record a finished lap. Returns true when it is a new personal best.
func submit_lap(track_id: String, car_id: String, ms: int) -> bool:
	if ms <= 0:
		return false
	var t: Dictionary = records.get(track_id, {})
	var improved := false
	var prev := int(t.get(car_id, 0))
	if prev == 0 or ms < prev:
		t[car_id] = ms
		improved = true
	var any := int(t.get("_any", 0))
	if any == 0 or ms < any:
		t["_any"] = ms
		improved = true
	records[track_id] = t
	if improved:
		save_records()
		record_set.emit(track_id, car_id, ms)
	return improved


static func format_time(ms: int) -> String:
	if ms <= 0:
		return "--:--.---"
	var m := ms / 60000
	var s := (ms / 1000) % 60
	var f := ms % 1000
	return "%d:%02d.%03d" % [m, s, f]


static func format_delta(ms: int) -> String:
	var sign_s := "+" if ms >= 0 else "-"
	var a := absi(ms)
	return "%s%d.%03d" % [sign_s, a / 1000, a % 1000]


func load_records() -> void:
	if TestHooks.is_testing():
		return                      # tests keep their lap times to themselves
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) == TYPE_DICTIONARY:
		records = data


func save_records() -> void:
	if TestHooks.is_testing():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(records, "\t"))
	f.close()
