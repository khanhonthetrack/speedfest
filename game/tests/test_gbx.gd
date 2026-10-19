extends Node
## GBX reader test. With --tmnf=/path/to/TmNationsForever it loads every official campaign track
## from the player's install (GameData/Tracks/Campaigns) and checks names, medals and blocks.
## Without it, it only checks the LZO decoder on a built-in sample.

func _ready() -> void:
	_lzo_sample()
	var root: String = TestHooks.arg("tmnf", "")
	if root.is_empty():
		print("TEST_SKIP campaign: pass --tmnf=/path/to/TMNF to read the official tracks")
	else:
		_campaign(root.path_join("GameData/Tracks/Campaigns/Nations"))
	TestHooks.finish()


func _lzo_sample() -> void:
	# a minimal valid LZO1X stream: 5 literals ("hello") then the end marker (0x11 0x00 0x00)
	var src := PackedByteArray([22, 0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x11, 0x00, 0x00])
	var out := Lzo1x.decompress(src, 5)
	TestHooks.check(out.get_string_from_ascii() == "hello", "lzo_literals", out.get_string_from_ascii())
	# malformed or truncated streams return empty, without errors
	TestHooks.check(Lzo1x.decompress(PackedByteArray([0x00]), 10).is_empty(), "lzo_rejects_garbage")
	TestHooks.check(Lzo1x.decompress(src.slice(0, 7), 5).is_empty(), "lzo_rejects_truncated")


func _campaign(dir: String) -> void:
	var files: PackedStringArray = []
	for colour in ["White", "Green", "Blue", "Red", "Black"]:
		var d := DirAccess.open(dir.path_join(colour))
		if d == null:
			continue
		for f in d.get_files():
			if f.to_lower().ends_with(".challenge.gbx"):
				files.append(dir.path_join(colour).path_join(f))
	TestHooks.check(files.size() == 65, "campaign_found_65", "found %d" % files.size())
	var failed := 0
	var total_blocks := 0
	var names := {}
	var t0 := Time.get_ticks_msec()
	for f in files:
		var c := TmChallenge.load_file(f)
		if not c.ok() or c.blocks.is_empty() or c.gold_ms <= 0 or c.author_ms <= 0:
			failed += 1
			print("FAILED %s: %s" % [f.get_file(), c.error])
			continue
		total_blocks += c.blocks.size()
		for blk in c.blocks:
			names[blk["name"]] = true
		if f.get_file().begins_with("A01"):
			print("A01: '%s' by %s, %s / %s / %s / author %s, %d blocks, size %s, deco %s" % [c.name, c.author,
				c.medal_text(c.bronze_ms), c.medal_text(c.silver_ms), c.medal_text(c.gold_ms), c.medal_text(c.author_ms),
				c.blocks.size(), c.size, c.decoration])
			TestHooks.check(c.name == "A01-Race" and c.author_ms == 24540 and c.blocks.size() == 397, "a01_values")
	print("campaign: %d files, %d blocks, %d block types, %d ms" % [files.size(), total_blocks, names.size(), Time.get_ticks_msec() - t0])
	TestHooks.check(failed == 0, "campaign_all_parse", "%d failed" % failed)
	TestHooks.check(total_blocks == 41523, "campaign_block_count", "%d" % total_blocks)
	TestHooks.check(names.size() == 242, "campaign_block_types", "%d" % names.size())
