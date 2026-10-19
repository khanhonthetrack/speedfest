extends Node
## Headless timing of CarVisual builds (garage / race startup cost).


func _ready() -> void:
	for id in CarDefs.IDS:
		var cv := CarVisual.new()
		add_child(cv)
		var t0 := Time.get_ticks_usec()
		cv.build(id, CarDefs.default_style(id))
		var t1 := Time.get_ticks_usec()
		var st := CarDefs.default_style(id)
		st["spoiler"] = 4
		cv.apply_style(st)
		var t2 := Time.get_ticks_usec()
		st["paint"] = "#00ff00"
		cv.apply_style(st)
		var t3 := Time.get_ticks_usec()
		print("BENCH %s build=%dms parts=%dms paint=%dms" % [id, (t1 - t0) / 1000, (t2 - t1) / 1000, (t3 - t2) / 1000])
	TestHooks.finish()
