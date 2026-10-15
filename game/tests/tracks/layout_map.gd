extends Node
## Tool: prints layout stats and draws a top-down PNG map of each layout (headless OK).
## Args: --track=all|<id> --out=/abs/dir


func _ready() -> void:
	var which: String = TestHooks.arg("track", "all")
	var out: String = TestHooks.arg("out", "/tmp")
	var ids: Array = TrackDefs.IDS if which == "all" else [which]
	for id in ids:
		var layout: Dictionary = load("res://tracks/defs/%s.gd" % id).new().layout()
		var data := TrackBuilder.build_layout(layout)
		var path: TrackPath = data["path"]
		var miny := 1e9
		var maxy := -1e9
		var mn := Vector2(1e9, 1e9)
		var mx := Vector2(-1e9, -1e9)
		var d := 0.0
		while d <= path.length:
			var p := path.sample_position(d)
			miny = minf(miny, p.y)
			maxy = maxf(maxy, p.y)
			mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.z))
			mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.z))
			d += 2.0
		print("%s length=%.0f cps=%s start=%.0f finish=%.0f y=[%.1f, %.1f] bbox=%s..%s" % [id, path.length, str(data["checkpoints"]), data["start_d"], data["finish_d"], miny, maxy, mn, mx])
		for j in data["jumps"]:
			print("  jump lip=%.0f v_min=%.1f km/h" % [j["lip"], j["v_min"] * 3.6])
		var sz := 1024
		var span := maxf(mx.x - mn.x, mx.y - mn.y) + 80.0
		var img := Image.create(sz, sz, false, Image.FORMAT_RGB8)
		img.fill(Color(0.08, 0.08, 0.1))
		d = 0.0
		while d <= path.length:
			var t := path.sample_transform(d)
			var w := path.width_at(d)
			var hcol := Color.from_hsv(0.66 - 0.66 * clampf((t.origin.y - miny) / maxf(1.0, maxy - miny), 0, 1), 0.8, 1.0)
			if path.in_zone(d, "tunnel"):
				hcol = Color(1, 0.6, 0.1)
			if TrackBuilder.in_ranges(d, data["gaps"]):
				hcol = Color(0.3, 0.3, 0.3)
			for k in range(-4, 5):
				var p := t.origin + t.basis.x * (w * 0.5 * k / 4.0)
				var px := int((p.x - mn.x + 40.0) / span * (sz - 1))
				var py := int((p.z - mn.y + 40.0) / span * (sz - 1))
				if px >= 0 and py >= 0 and px < sz and py < sz:
					img.set_pixel(px, py, hcol)
			d += 0.5
		for i in data["checkpoints"].size():
			_dot(img, path.sample_position(data["checkpoints"][i]), mn, span, sz, Color.WHITE)
		_dot(img, path.sample_position(data["start_d"]), mn, span, sz, Color.GREEN)
		_dot(img, path.sample_position(data["finish_d"]), mn, span, sz, Color.RED)
		img.save_png("%s/map_%s.png" % [out, id])
	TestHooks.finish()


func _dot(img: Image, p: Vector3, mn: Vector2, span: float, sz: int, c: Color) -> void:
	var px := int((p.x - mn.x + 40.0) / span * (sz - 1))
	var py := int((p.z - mn.y + 40.0) / span * (sz - 1))
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			if px + dx >= 0 and py + dy >= 0 and px + dx < sz and py + dy < sz:
				img.set_pixel(px + dx, py + dy, c)
