extends Node
## Campaign coverage (needs a TMNF install): builds every official track with TmMapBuilder and
## totals how many blocks came from recreated shapes, and which shapes are still missing.
## Run: stadium/tools/run.sh res://tests/campaign_coverage.tscn --headless -- --tmnf=/path/to/TMNF [--top=40]


func _ready() -> void:
	var root := String(TestHooks.arg("tmnf", ""))
	if root.is_empty():
		print("TEST_SKIP coverage: pass --tmnf=/path/to/TMNF")
		TestHooks.finish()
		return
	var lib := TmBlockLib.new()
	var base := root.path_join("GameData/Tracks/Campaigns/Nations")
	var totals := {"blocks": 0, "built": 0, "empty": 0, "placeholder": 0, "unknown": 0}
	var missing := {}
	var maps := 0
	for colour in ["White", "Green", "Blue", "Red", "Black"]:
		var d := DirAccess.open(base.path_join(colour))
		if d == null:
			continue
		var files := d.get_files()
		files.sort()
		for f in files:
			if not f.to_lower().ends_with(".challenge.gbx"):
				continue
			var ch := TmChallenge.load_file(base.path_join(colour).path_join(f))
			if not ch.ok():
				continue
			var b := TmMapBuilder.build(ch, lib)
			maps += 1
			for k in totals:
				totals[k] += int(b.stats[k])
			for s in b.missing:
				missing[s] = int(missing.get(s, 0)) + int(b.missing[s])
			b.root.free()
	var keys := missing.keys()
	keys.sort_custom(func(a, c): return missing[a] > missing[c])
	print("COVERAGE %d maps: %s (%.1f%% built or empty)" % [maps, totals,
		100.0 * (totals["built"] + totals["empty"]) / maxf(1.0, totals["blocks"])])
	for k in keys.slice(0, int(TestHooks.arg("top", 40))):
		print("  MISSING %5d %s" % [missing[k], k])
	TestHooks.finish()
