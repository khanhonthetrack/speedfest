extends Node
## Texture mod compatibility: opens every mod (.zip) in a folder (ManiaPark's, from
## tools/compat/compat_run.py, or any player's) as the game does (TmTextureMod) and checks that it
## reads, that every texture it ships decodes, and which game and environment it is for; a Stadium
## mod must give our blocks at least one material (TmMaterials.MOD_MAP), and wearing it must build
## them. Mods for environments the game doesn't have (Canyon, Valley, Lagoon, Storm; Island, Bay,
## Coast, Desert, Rally, Snow) open and decode but can't be worn: counted apart.
##
## Run: stadium/tools/run.sh res://tests/test_compat_mods.tscn --headless --timeout 3000 -- \
##          --dir=/abs/mods [--index=/abs/index.json] [--results=/abs/results.json] [--verbose]
## index.json (optional): {file: {name, game}} (ManiaPark's name tells some environments apart).
## results.json: {file: {ok, why, game, environment, textures, undecoded, wearable, keys}}.

var _counts := {"mods": 0, "read": 0, "decoded": 0, "stadium": 0, "worn": 0, "other_env": 0, "unknown_env": 0}
var _failures: Array = []
var _results := {}


func _ready() -> void:
	var dir := String(TestHooks.arg("dir", ""))
	if dir.is_empty():
		print("TEST_SKIP compat_mods: pass --dir=/path/to/a/folder/of/mods")
		TestHooks.finish()
		return
	var index := {}
	var ip := String(TestHooks.arg("index", ""))
	if not ip.is_empty() and FileAccess.file_exists(ip):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ip))
		if parsed is Dictionary:
			index = parsed
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.to_lower().ends_with(".zip"):
			files.append(dir.path_join(f))
	files.sort()
	var t0 := Time.get_ticks_msec()
	for f: String in files:
		_check(f, index.get(f.get_file(), {}))
	print("MODS %d mods in %.0f s: %s" % [files.size(), (Time.get_ticks_msec() - t0) / 1000.0, _counts])
	for fl: Dictionary in _failures.slice(0, 80):
		print("MODS_FAIL %s: %s" % [fl["file"], fl["why"]])
	var rp := String(TestHooks.arg("results", ""))
	if not rp.is_empty():
		var out := FileAccess.open(rp, FileAccess.WRITE)
		if out:
			out.store_string(JSON.stringify(_results, " "))
	TestHooks.check(_counts["read"] == files.size(), "mods_all_read", "%d of %d didn't read" % [files.size() - _counts["read"], files.size()])
	TestHooks.check(_counts["decoded"] == _counts["read"], "mods_all_decode", "%d mods have textures that don't decode" % (_counts["read"] - _counts["decoded"]))
	TestHooks.check(_counts["worn"] == _counts["stadium"], "mods_stadium_worn",
		"%d of %d Stadium mods give our blocks nothing" % [_counts["stadium"] - _counts["worn"], _counts["stadium"]])
	TmMaterials.use_mod(null)
	TestHooks.finish()


func _fail(file: String, why: String) -> void:
	_failures.append({"file": file.get_file(), "why": why})
	if TestHooks.has_arg("verbose"):
		print("  FAIL %s: %s" % [file.get_file(), why])


func _check(file: String, meta: Dictionary) -> void:
	_counts["mods"] += 1
	var r := {"ok": false, "why": "", "game": "", "environment": "", "textures": 0, "undecoded": [], "wearable": false, "keys": 0}
	_results[file.get_file()] = r
	var mod := TmTextureMod.load_zip(file, String(meta.get("name", "")))
	if not mod.ok():
		r["why"] = mod.error
		_fail(file, mod.error)
		return
	_counts["read"] += 1
	r["game"] = mod.game
	r["environment"] = mod.environment
	r["textures"] = mod.images.size()
	var bad := mod.check_all()
	# a ManiaPlanet sky's EXR needs Godot's EXR loader, which export builds may not have: noted, not failed
	var hard: Array = bad.filter(func(n: String) -> bool: return n.get_extension().to_lower() != "exr")
	r["undecoded"] = bad
	if hard.is_empty():
		_counts["decoded"] += 1
	else:
		r["why"] = "textures that don't decode: %s" % ", ".join(PackedStringArray(hard.slice(0, 6)))
		_fail(file, r["why"])
	if mod.environment == "Stadium":
		_counts["stadium"] += 1
		TmMaterials.use_mod(mod)
		var keys := 0
		for k: String in TmMaterials.MOD_MAP:
			var m := TmMaterials.get_material(k)
			if m is ShaderMaterial and (m as ShaderMaterial).get_shader_parameter("atlas") != null \
					and (m as ShaderMaterial).get_shader_parameter("albedo_tex") == mod.texture(mod.first(TmMaterials.MOD_MAP[k][0])):
				keys += 1
		r["keys"] = keys
		r["wearable"] = keys > 0
		if keys > 0:
			_counts["worn"] += 1
		else:
			_fail(file, "a Stadium mod our blocks take nothing from (%s)" % ", ".join(PackedStringArray(mod.images.keys().slice(0, 8))))
		TmMaterials.use_mod(null)
	elif mod.environment.is_empty():
		_counts["unknown_env"] += 1
	else:
		_counts["other_env"] += 1
	r["ok"] = String(r["why"]).is_empty()
	if TestHooks.has_arg("verbose"):
		print("  %s: %s %s, %d textures, %s" % [file.get_file(), mod.game, mod.environment, mod.images.size(), r])
	TmTextureMod.forget(file)
