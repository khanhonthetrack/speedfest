extends Node
## Command-line hooks for automated testing and screenshots. Does nothing in normal play.
##
## User args (after `--` on the godot command line):
##   --shot=/abs/path.png   save a screenshot of the root viewport (at --frames, or on quit)
##   --frames=N             quit automatically after N rendered frames
##   --shots=a.png@60,b.png@120   several screenshots at given frames
##   any --key=value        readable by scenes through TestHooks.arg("key", default)
##
## Scenes can call TestHooks.ok("name") / TestHooks.fail("name", "why"), which print
## the standard TEST_OK/TEST_FAIL lines, and TestHooks.finish() to quit (exit code 1 if any failed).

var args: Dictionary = {}
var frame: int = 0
var quit_frame: int = -1
var shots: Array = []   # [[frame, path], ...]
var failures: int = 0
var oks: int = 0
## A test scene (res://tests/...) or an automated run (--frames, --shot, --shots), decided from the
## command line at start: the menus also keep state in args, so args alone don't mean a test.
var testing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if not s.begins_with("--"):
			continue
		s = s.substr(2)
		var eq := s.find("=")
		if eq == -1:
			args[s] = "true"
		else:
			args[s.substr(0, eq)] = s.substr(eq + 1)
	for a in OS.get_cmdline_args():
		if String(a).begins_with("res://tests/"):
			testing = true
	testing = testing or args.has("frames") or args.has("shot") or args.has("shots")
	if args.has("frames"):
		quit_frame = int(args["frames"])
	if args.has("shot"):
		shots.append([quit_frame if quit_frame > 0 else 60, String(args["shot"])])
	if args.has("shots"):
		for item in String(args["shots"]).split(","):
			var parts := item.split("@")
			if parts.size() == 2:
				shots.append([int(parts[1]), parts[0]])


func has_arg(key: String) -> bool:
	return args.has(key)


func arg(key: String, default: Variant = "") -> Variant:
	if not args.has(key):
		return default
	var v: String = args[key]
	match typeof(default):
		TYPE_INT:
			return int(v)
		TYPE_FLOAT:
			return float(v)
		TYPE_BOOL:
			return v == "true" or v == "1"
	return v


func is_testing() -> bool:
	return testing


func _process(_delta: float) -> void:
	frame += 1
	for s in shots:
		if s[0] == frame:
			save_screenshot(s[1])
	if quit_frame > 0 and frame >= quit_frame:
		finish()


func save_screenshot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("TEST_FAIL screenshot: no image (headless?)")
		return
	var err := img.save_png(path)
	print("SCREENSHOT %s %s" % [path, "ok" if err == OK else "error %d" % err])


func ok(name: String) -> void:
	oks += 1
	print("TEST_OK %s" % name)


func fail(name: String, why: String = "") -> void:
	failures += 1
	print("TEST_FAIL %s: %s" % [name, why])


func check(cond: bool, name: String, why: String = "") -> bool:
	if cond:
		ok(name)
	else:
		fail(name, why)
	return cond


func finish() -> void:
	print("TEST_SUMMARY ok=%d fail=%d" % [oks, failures])
	get_tree().quit(1 if failures > 0 else 0)
