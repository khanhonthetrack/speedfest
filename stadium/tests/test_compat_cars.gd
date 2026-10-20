extends Node
## Community car compatibility: loads every car pack (.zip) in a folder (a ManiaPark sample from
## tools/compat/fetch_maniapark.py, or any player's folder) as the game does (TmCarPack: the model
## read by TmSolid, textures decoded, parts sorted into body and wheels) and checks that each one
## loads, has geometry and decodes the textures it ships; counts the models whose four wheels spin
## apart, those with some (the others are the body's) and those whose wheels are all the body's.
## --shots=/abs/dir also renders each car from the side (Forward+; look at them with the Read tool).
##
## Run: stadium/tools/run.sh res://tests/test_compat_cars.tscn --headless --timeout 3000 -- \
##          --dir=/abs/cars [--limit=N] [--report=/abs/report.json] [--results=/abs/r.json] [--verbose]
## results.json (tools/compat/compat_run.py): {file: {ok, why, skin_only, triangles, wheels, textures}}.
## Prints TEST_OK/TEST_FAIL per check and CARS lines (counts, failing packs).

var _failures: Array = []
var _results := {}
var _counts := {"packs": 0, "loaded": 0, "textured": 0, "four_wheels": 0, "some_wheels": 0, "wheels_in_body": 0,
	"triangles": 0, "text_format": 0}


func _ready() -> void:
	var dir := String(TestHooks.arg("dir", ""))
	if dir.is_empty():
		print("TEST_SKIP compat_cars: pass --dir=/path/to/a/folder/of/car/packs (tools/compat/fetch_maniapark.py)")
		TestHooks.finish()
		return
	var files := _files(dir)
	var limit := int(TestHooks.arg("limit", 0))
	if limit > 0:
		files = files.slice(0, limit)
	var t0 := Time.get_ticks_msec()
	for f: String in files:
		_check(f)
	print("CARS %d packs in %.0f s: %s" % [files.size(), (Time.get_ticks_msec() - t0) / 1000.0, _counts])
	for fl: Dictionary in _failures.slice(0, 80):
		print("CARS_FAIL %s: %s" % [fl["file"], fl["why"]])
	var rp := String(TestHooks.arg("results", ""))
	if not rp.is_empty():
		var ro := FileAccess.open(rp, FileAccess.WRITE)
		if ro:
			ro.store_string(JSON.stringify(_results, " "))
	var report := String(TestHooks.arg("report", ""))
	if not report.is_empty():
		var out := FileAccess.open(report, FileAccess.WRITE)
		if out:
			out.store_string(JSON.stringify({"counts": _counts, "failures": _failures}, " "))
	TestHooks.check(_counts["loaded"] == files.size(), "cars_all_loaded",
		"%d of %d car packs failed" % [files.size() - _counts["loaded"], files.size()])
	TestHooks.check(_counts["textured"] == _counts["loaded"], "cars_all_textured",
		"%d packs' textures didn't decode" % (_counts["loaded"] - _counts["textured"]))
	TestHooks.finish()


func _files(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		TestHooks.fail("cars_dir", "cannot open %s" % dir)
		return out
	for f in d.get_files():
		if f.to_lower().ends_with(".zip"):
			out.append(dir.path_join(f))
	out.sort()
	return out


func _fail(file: String, why: String) -> void:
	_failures.append({"file": file.get_file(), "why": why})
	var r: Dictionary = _results.get(file.get_file(), {})
	r["ok"] = false
	r["why"] = why if String(r.get("why", "")).is_empty() else "%s; %s" % [r["why"], why]
	_results[file.get_file()] = r
	if TestHooks.has_arg("verbose"):
		print("  FAIL %s: %s" % [file.get_file(), why])


func _check(file: String) -> void:
	_counts["packs"] += 1
	_results[file.get_file()] = {"ok": true, "why": "", "skin_only": false, "triangles": 0, "wheels": 0, "textures": ""}
	var pack := TmCarPack.load_zip(file)
	if not pack.ok():
		_fail(file, pack.error)
		return
	_counts["loaded"] += 1
	if pack.skin_only:
		_counts["skin_only"] = int(_counts.get("skin_only", 0)) + 1
	else:
		_counts["triangles"] += pack.solid.triangle_count()
		if pack.solid._text:
			_counts["text_format"] += 1
	# every texture the pack ships decodes (a skin without its own Diffuse paints the player's colour;
	# a file the pack ships empty, 0 bytes, holds no image to decode: it counts as not there)
	var zip := ZIPReader.new()
	var missing: Array = []
	if zip.open(file) == OK:
		for f in zip.get_files():
			var low := f.get_file().to_lower()
			for t in ["diffuse", "details", "illum"]:
				if low.get_basename() == t and low.get_extension() in TmCarPack.TEXTURE_EXT and not pack.textures.has(t) \
						and not zip.read_file(f).is_empty():
					missing.append(f.get_file())
		zip.close()
	if missing.is_empty():
		_counts["textured"] += 1
	else:
		_fail(file, "textures that don't decode: %s" % ", ".join(PackedStringArray(missing)))
	var n := 0
	for w: Dictionary in pack.wheels:
		if not w.is_empty():
			n += 1
	var res: Dictionary = _results[file.get_file()]
	res["skin_only"] = pack.skin_only
	res["triangles"] = pack.solid.triangle_count() if pack.solid else 0
	res["wheels"] = n
	res["textures"] = ",".join(PackedStringArray(pack.textures.keys()))
	if n == 4:
		_counts["four_wheels"] += 1
	elif n == 0:
		_counts["wheels_in_body"] += 1
	else:
		_counts["some_wheels"] += 1   # e.g. only the front wheels steer apart, the rear ones are the body's
	if TestHooks.has_arg("verbose"):
		print("  %s: %d parts, %d triangles, %d wheels, textures %s" % [file.get_file(),
			pack.solid.parts.size() if pack.solid else 0, pack.solid.triangle_count() if pack.solid else 0, n,
			pack.textures.keys()])
