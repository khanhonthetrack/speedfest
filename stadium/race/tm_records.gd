class_name TmRecords
extends RefCounted
## The player's best runs, per track (the map's uid): the time, its checkpoint splits and the run's
## ghost, kept on this machine (user://records, or --records=<dir>). Nothing leaves the machine.


## Where the records live (tests pass --records=user://test_records).
static func dir() -> String:
	return String(TestHooks.arg("records", "user://records"))


## A file-safe key for a track: its uid, else its name.
static func key(ch: TmChallenge) -> String:
	var k := ch.uid if not ch.uid.is_empty() else ch.name
	var out := ""
	for c in k:
		out += c if (c.is_valid_identifier() or c.is_valid_int() or c == "-") else "_"
	return out if not out.is_empty() else "unnamed"


## The best run on a track: {time_ms, splits, name, way (its finish; older records lack it)}; {} if none yet.
static func best(ch: TmChallenge) -> Dictionary:
	var f := FileAccess.open(dir().path_join(key(ch) + ".json"), FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary) or not (d as Dictionary).has("time_ms"):
		return {}
	return d


## The best run's ghost, or null.
static func ghost(ch: TmChallenge) -> TmGhost:
	return TmGhost.load_file(dir().path_join(key(ch) + ".ghost"))


## Offers a finished run; it becomes the track's record (with its ghost) when it beats the best.
## way: which finish it crossed (TmChallenge.way_of), kept with the record. Returns true for a new record.
static func submit(ch: TmChallenge, time_ms: int, splits: Array, run: TmGhost, way := 0) -> bool:
	if time_ms <= 0:
		return false
	var prev := best(ch)
	if not prev.is_empty() and int(prev["time_ms"]) <= time_ms:
		return false
	DirAccess.make_dir_recursive_absolute(dir())
	var f := FileAccess.open(dir().path_join(key(ch) + ".json"), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"time_ms": time_ms, "splits": splits, "name": ch.name, "way": way}))
	if run != null:
		run.save(dir().path_join(key(ch) + ".ghost"))
	return true


## Removes every record in dir() (tests).
static func clear() -> void:
	var d := DirAccess.open(dir())
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
