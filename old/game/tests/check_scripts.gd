extends Node
## Loads every .gd under res:// and reports scripts that fail to compile.
## Run as a scene (so autoload names resolve): tools/check_scripts.sh


func _ready() -> void:
	var files: Array[String] = []
	_collect("res://", files)
	var errors := 0
	for f in files:
		if f == "res://tests/check_scripts.gd":
			continue
		var s: Variant = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_REUSE)
		if s == null or not (s is GDScript) or not (s as GDScript).can_instantiate():
			print("SCRIPT_ERROR %s" % f)
			errors += 1
	print("SCRIPT_OK_COUNT %d" % (files.size() - errors))
	print("SCRIPT_ERRORS=%d" % errors)
	get_tree().quit(1 if errors > 0 else 0)


func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n.begins_with("."):
			n = d.get_next()
			continue
		var p := dir.path_join(n)
		if d.current_is_dir():
			if n != "addons":
				_collect(p, out)
		elif n.ends_with(".gd"):
			out.append(p)
		n = d.get_next()
