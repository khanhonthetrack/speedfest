extends Node
## The local player's identity, garage (per-car tuning + style), personal bests and PB ghosts.
## Persisted as JSON in user://profile.json (IndexedDB on web); ghosts in user://ghosts/.

signal changed

const SAVE_PATH := "user://profile.json"
const GHOST_DIR := "user://ghosts"

var player_name: String = ""
var selected_car: String = "kaze"
var cars: Dictionary = {}          # car_id -> {"tuning": {...}, "style": {...}}
var pbs: Dictionary = {}           # track_id -> {"ms": int, "car": String}


func _ready() -> void:
	load_profile()
	if player_name == "":
		player_name = "Racer%03d" % (randi() % 1000)
	for id in CarDefs.IDS:
		if not cars.has(id):
			var d := CarDefs.default_config(id)
			cars[id] = {"tuning": d["tuning"], "style": d["style"]}


func get_config(car_id: String = "") -> Dictionary:
	if car_id == "":
		car_id = selected_car
	var entry: Dictionary = cars.get(car_id, {})
	return CarDefs.sanitize_config({"car": car_id, "tuning": entry.get("tuning", {}), "style": entry.get("style", {})})


func set_selected_car(car_id: String) -> void:
	if car_id in CarDefs.IDS:
		selected_car = car_id
		changed.emit()


func set_tuning(car_id: String, tuning: Dictionary) -> void:
	var cfg := CarDefs.sanitize_config({"car": car_id, "tuning": tuning, "style": get_config(car_id)["style"]})
	cars[car_id] = {"tuning": cfg["tuning"], "style": cfg["style"]}
	changed.emit()


func set_style(car_id: String, style: Dictionary) -> void:
	var cfg := CarDefs.sanitize_config({"car": car_id, "tuning": get_config(car_id)["tuning"], "style": style})
	cars[car_id] = {"tuning": cfg["tuning"], "style": cfg["style"]}
	changed.emit()


func set_player_name(n: String) -> void:
	n = n.strip_edges().substr(0, 16)
	if n != "":
		player_name = n
		changed.emit()


# --- personal bests -----------------------------------------------------------

func get_pb(track_id: String) -> int:
	return int(pbs.get(track_id, {}).get("ms", -1))


## Records a finished run. Returns true if it is a new personal best.
func submit_time(track_id: String, ms: int, car_id: String) -> bool:
	var pb := get_pb(track_id)
	if pb < 0 or ms < pb:
		pbs[track_id] = {"ms": ms, "car": car_id}
		save()
		return true
	return false


func save_ghost(track_id: String, ghost: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(GHOST_DIR)
	var f := FileAccess.open("%s/%s.json" % [GHOST_DIR, track_id], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(ghost))


func load_ghost(track_id: String) -> Dictionary:
	var path := "%s/%s.json" % [GHOST_DIR, track_id]
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == TYPE_DICTIONARY else {}


# --- persistence --------------------------------------------------------------

func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": 1,
		"player_name": player_name,
		"selected_car": selected_car,
		"cars": cars,
		"pbs": pbs,
	}, "\t"))


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	player_name = String(data.get("player_name", ""))
	var sel := String(data.get("selected_car", "kaze"))
	selected_car = sel if sel in CarDefs.IDS else "kaze"
	var c: Variant = data.get("cars", {})
	if typeof(c) == TYPE_DICTIONARY:
		for id in c:
			if id in CarDefs.IDS and typeof(c[id]) == TYPE_DICTIONARY:
				var cfg := CarDefs.sanitize_config({"car": id, "tuning": c[id].get("tuning", {}), "style": c[id].get("style", {})})
				cars[id] = {"tuning": cfg["tuning"], "style": cfg["style"]}
	var p: Variant = data.get("pbs", {})
	if typeof(p) == TYPE_DICTIONARY:
		pbs = p
