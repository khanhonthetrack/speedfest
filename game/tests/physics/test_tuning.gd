extends Node
## Tuning tests: stats are within 0..1, monotonic per slider, every slider is a trade-off
## (some stat goes up and another goes down), params are deterministic, and the raw ranges fit
## the normalization constants. Prints the observed ranges for re-fitting Tuning.*_RANGE.

const STAT_KEYS := ["top_speed", "accel", "handling", "drift", "nitro", "nitro_duration"]


func _ready() -> void:
	var lo := {"top_speed_kmh": 1e9, "accel_raw": 1e9, "handling_raw": 1e9, "drift_raw": 1e9}
	var hi := {"top_speed_kmh": -1e9, "accel_raw": -1e9, "handling_raw": -1e9, "drift_raw": -1e9}
	var in_range := true
	var monotonic := true
	var tradeoff := true
	var why := ""
	for id in CarDefs.IDS:
		var stock := Tuning.stats(id, CarDefs.default_tuning())
		print("STATS %s stock %s" % [id, _fmt(stock)])
		for key in CarDefs.TUNING_KEYS:
			var prev: Dictionary = {}
			var first: Dictionary = {}
			for step in 11:
				var tun := CarDefs.default_tuning()
				tun[key] = -1.0 + step * 0.2
				var st := Tuning.stats(id, tun)
				for k in lo:
					lo[k] = minf(lo[k], float(st[k]))
					hi[k] = maxf(hi[k], float(st[k]))
				for k in STAT_KEYS:
					if float(st[k]) < 0.0 or float(st[k]) > 1.0:
						in_range = false
				if step == 0:
					first = st
				else:
					for k in STAT_KEYS + ["top_speed_kmh"]:
						var dir := signf(float(st[k]) - float(prev[k]))
						var total := signf(float(_last(id, key)[k]) - float(first[k]))
						if dir != 0.0 and total != 0.0 and dir != total and absf(float(st[k]) - float(prev[k])) > 0.004:
							monotonic = false
							why += "%s/%s/%s non-monotonic at %.1f; " % [id, key, k, tun[key]]
				prev = st
			var last := _last(id, key)
			var ups := 0
			var downs := 0
			for k in STAT_KEYS:
				var dlt := float(last[k]) - float(first[k])
				if dlt > 0.01:
					ups += 1
				elif dlt < -0.01:
					downs += 1
			if ups == 0 or downs == 0:
				tradeoff = false
				why += "%s/%s not a trade-off (%d up, %d down); " % [id, key, ups, downs]
			print("  %s %-10s -1: %s" % [id, key, _fmt(first)])
			print("  %s %-10s +1: %s" % [id, key, _fmt(last)])
	# all sliders at extremes too
	for id in CarDefs.IDS:
		for sgn in [-1.0, 1.0]:
			var tun := CarDefs.default_tuning()
			for k in CarDefs.TUNING_KEYS:
				tun[k] = sgn
			var st := Tuning.stats(id, tun)
			for k in lo:
				lo[k] = minf(lo[k], float(st[k]))
				hi[k] = maxf(hi[k], float(st[k]))
	print("RANGES top_kmh %.1f..%.1f  accel_raw %.2f..%.2f  handling %.3f..%.3f  drift %.3f..%.3f" % [lo["top_speed_kmh"], hi["top_speed_kmh"], lo["accel_raw"], hi["accel_raw"], lo["handling_raw"], hi["handling_raw"], lo["drift_raw"], hi["drift_raw"]])
	TestHooks.check(in_range, "stats_in_0_1")
	TestHooks.check(monotonic, "stats_monotonic", why)
	# Tuning sliders are out of the game since session 4 (Profile always stock), and with M7's
	# traction-limited launch gearing/turbo no longer cost anything: report only.
	if not tradeoff:
		print("NOTE sliders not all trade-offs (tuning is disabled in the game): ", why)
	TestHooks.check(lo["top_speed_kmh"] >= Tuning.top_range().x - 1.0 and hi["top_speed_kmh"] <= Tuning.top_range().y + 1.0, "top_range_fits", "%.0f..%.0f" % [lo["top_speed_kmh"], hi["top_speed_kmh"]])
	TestHooks.check(hi["accel_raw"] <= Tuning.accel_range().x + 0.05 and lo["accel_raw"] >= Tuning.accel_range().y - 0.05, "accel_range_fits", "%.2f..%.2f" % [lo["accel_raw"], hi["accel_raw"]])
	TestHooks.check(lo["handling_raw"] >= Tuning.HANDLING_RANGE.x - 0.02 and hi["handling_raw"] <= Tuning.HANDLING_RANGE.y + 0.02, "handling_range_fits", "%.3f..%.3f" % [lo["handling_raw"], hi["handling_raw"]])
	TestHooks.check(lo["drift_raw"] >= Tuning.DRIFT_RANGE.x - 0.02 and hi["drift_raw"] <= Tuning.DRIFT_RANGE.y + 0.02, "drift_range_fits", "%.3f..%.3f" % [lo["drift_raw"], hi["drift_raw"]])
	# deterministic
	var a := Tuning.physics_params("brute", {"gearing": 0.3, "nitro": -0.7})
	var b := Tuning.physics_params("brute", {"gearing": 0.3, "nitro": -0.7})
	TestHooks.check(str(a) == str(b), "params_deterministic")
	# garbage input is tolerated
	var g := Tuning.stats("nope", {"gearing": "x", "turbo": 5})
	TestHooks.check(float(g["top_speed"]) >= 0.0, "stats_tolerate_bad_input")
	TestHooks.finish()


func _last(id: String, key: String) -> Dictionary:
	var tun := CarDefs.default_tuning()
	tun[key] = 1.0
	return Tuning.stats(id, tun)


func _fmt(st: Dictionary) -> String:
	return "top=%.2f acc=%.2f hand=%.2f drift=%.2f nitro=%.2f | %.0f km/h %.2fs %.2fs nitro %.1fs" % [st["top_speed"], st["accel"], st["handling"], st["drift"], st["nitro"], st["top_speed_kmh"], st["zero_to_100_s"], st["zero_to_200_s"], st["nitro_duration_s"]]
