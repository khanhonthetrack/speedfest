extends Node
## Community track compatibility: reads every .Challenge.Gbx in a folder (a TrackMania Exchange
## sample from tools/compat/fetch_tmx.py, or any player's folder) and checks that each one reads,
## is a Stadium track, uses only blocks we recreate (no placeholder, no unknown block) and has a
## start and a finish. Modded tracks (TMUnlimiter 2, custom or other environments' blocks) are counted
## apart. --build also builds every map with TmMapBuilder (slower) and checks the
## race's start and waypoints from the built map.
##
## Run: stadium/tools/run.sh res://tests/test_compat_tracks.tscn --headless --timeout 3000 -- \
##          --dir=/abs/tmx [--build] [--limit=N] [--report=/abs/report.json] [--results=/abs/r.json] [--verbose]
## results.json (tools/compat/compat_run.py): {file: {ok, why, name, environment, modded, built, raceable}}.
## Prints TEST_OK/TEST_FAIL per check and COMPAT lines (counts, failing tracks, missing shapes).

var _lib: TmBlockLib
var _failures: Array = []         ## [{file, name, why}]
var _results := {}                ## file -> its outcome (--results)
var _missing := {}                ## shape or ?block -> number of tracks that need it
var _counts := {"tracks": 0, "read": 0, "stadium": 0, "modded": 0, "complete": 0, "built": 0, "raceable": 0}


func _ready() -> void:
	var dir := String(TestHooks.arg("dir", ""))
	if dir.is_empty():
		print("TEST_SKIP compat: pass --dir=/path/to/a/folder/of/tracks (tools/compat/fetch_tmx.py)")
		TestHooks.finish()
		return
	_lib = TmBlockLib.new()
	var files := _files(dir)
	var limit := int(TestHooks.arg("limit", 0))
	if limit > 0:
		files = files.slice(0, limit)
	var build := TestHooks.has_arg("build")
	var t0 := Time.get_ticks_msec()
	for f: String in files:
		_check(f, build)
	var dt := (Time.get_ticks_msec() - t0) / 1000.0
	print("COMPAT %d tracks in %.0f s: %s" % [files.size(), dt, _counts])
	var keys := _missing.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _missing[a] > _missing[b])
	for k: String in keys.slice(0, 60):
		print("COMPAT_MISSING %5d tracks  %s" % [_missing[k], k])
	for fl: Dictionary in _failures.slice(0, int(TestHooks.arg("show", 80))):
		print("COMPAT_FAIL %s (%s): %s" % [fl["file"], fl["name"], fl["why"]])
	var rp := String(TestHooks.arg("results", ""))
	if not rp.is_empty():
		var ro := FileAccess.open(rp, FileAccess.WRITE)
		if ro:
			ro.store_string(JSON.stringify(_results, " "))
	var report := String(TestHooks.arg("report", ""))
	if not report.is_empty():
		var out := FileAccess.open(report, FileAccess.WRITE)
		if out:
			out.store_string(JSON.stringify({"counts": _counts, "missing": _missing, "failures": _failures}, " "))
	var n := maxi(1, files.size())
	TestHooks.check(_counts["read"] == files.size(), "compat_all_read", "%d of %d read" % [_counts["read"], n])
	TestHooks.check(_counts["complete"] == _counts["stadium"], "compat_all_blocks_built",
		"%d of %d Stadium tracks use blocks we don't build" % [_counts["stadium"] - _counts["complete"], _counts["stadium"]])
	TestHooks.check(_counts["raceable"] == _counts["stadium"], "compat_all_raceable",
		"%d of %d Stadium tracks have no start or no finish" % [_counts["stadium"] - _counts["raceable"], _counts["stadium"]])
	TestHooks.finish()


func _files(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		TestHooks.fail("compat_dir", "cannot open %s" % dir)
		return out
	for f in d.get_files():
		if f.to_lower().ends_with(".gbx"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub)))
	out.sort()
	return out


func _fail(file: String, name: String, why: String) -> void:
	_failures.append({"file": file.get_file(), "name": name, "why": why})
	var r: Dictionary = _results.get(file.get_file(), {"name": name})
	r["ok"] = false
	r["why"] = why if String(r.get("why", "")).is_empty() else "%s; %s" % [r["why"], why]
	_results[file.get_file()] = r
	if TestHooks.has_arg("verbose"):
		print("  FAIL %s: %s" % [file.get_file(), why])


func _check(file: String, build: bool) -> void:
	_counts["tracks"] += 1
	var ch := TmChallenge.load_file(file)
	_results[file.get_file()] = {"ok": true, "why": "", "name": ch.name, "environment": ch.environment, "modded": false,
		"built": false, "raceable": false}
	if not ch.ok():
		_fail(file, ch.name, "read: " + ch.error)
		return
	_counts["read"] += 1
	if not ch.environment.is_empty() and ch.environment != "Stadium":
		print("COMPAT_SKIP %s: environment %s" % [file.get_file(), ch.environment])
		_results[file.get_file()]["why"] = "not a Stadium track (%s)" % ch.environment
		return
	var report := TmTrackCheck.check(ch, _lib)
	if report["modded"]:
		# TMUnlimiter tracks and other mods' blocks (custom, other environments): TMNF itself needs
		# the mod; counted apart and listed
		_counts["modded"] += 1
		print("COMPAT_MODDED %s (%s): %s %s" % [file.get_file(), ch.name, report["why"], report["missing"].keys()])
		_results[file.get_file()]["modded"] = true
		_results[file.get_file()]["why"] = "modded: %s" % report["why"]
		return
	_counts["stadium"] += 1
	for k: String in report["missing"]:
		_missing[k] = int(_missing.get(k, 0)) + 1
	if not report["missing"].is_empty():
		_fail(file, ch.name, "blocks we don't build: %s" % ", ".join(PackedStringArray(report["missing"].keys())))
	else:
		_counts["complete"] += 1
	if not report["raceable"]:
		_fail(file, ch.name, report["why"])
	elif not build:
		_counts["raceable"] += 1
	if build:
		var b := TmMapBuilder.build(ch, _lib)
		var ok: bool = b.stats["placeholder"] == 0 and b.stats["unknown"] == 0
		if ok:
			_counts["built"] += 1
			_results[file.get_file()]["built"] = true
		else:
			for k: String in b.missing:
				_missing["built: " + k] = int(_missing.get("built: " + k, 0)) + 1
			_fail(file, ch.name, "built with %d placeholders, %d unknown: %s" % [b.stats["placeholder"],
				b.stats["unknown"], ", ".join(PackedStringArray(b.missing.keys()))])
		if report["raceable"]:
			if b.has_start and (not b.finishes.is_empty() or ch.lap_race or _has_multilap(b)):
				_counts["raceable"] += 1
				_results[file.get_file()]["raceable"] = true
			else:
				_fail(file, ch.name, "built map has no start or finish")
		b.root.free()


func _has_multilap(b: TmMapBuilder) -> bool:
	for wp: Dictionary in b.waypoints:
		if int(wp["kind"]) == TmBlockCatalogue.Waypoint.START_FINISH:
			return true
	return false
