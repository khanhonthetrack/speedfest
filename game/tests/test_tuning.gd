extends Node
## The garage maths: every car is distinct, every slot does what the catalogue says, prices and
## credits add up, and a fully built car beats a stock one everywhere it should.


func _ready() -> void:
	_cars_are_distinct()
	_slots_well_formed()
	_effects_apply()
	_ratings_in_range()
	_prices_and_credits()
	_surface_overrides()
	_styles_resolve()
	TestHooks.finish()


func _cars_are_distinct() -> void:
	TestHooks.check(CarDefs.IDS.size() == 5, "five cars", str(CarDefs.IDS))
	var tops: Array[float] = []
	var names: Array[String] = []
	for id: String in CarDefs.IDS:
		var d := CarDefs.get_def(id)
		var s := CarDefs.specs(id)
		names.append(String(d["name"]))
		tops.append(float(s["top_kmh"]))
		TestHooks.check(float(s["top_kmh"]) > 150.0 and float(s["top_kmh"]) < 420.0,
			"top speed sane %s" % id, str(s["top_kmh"]))
		TestHooks.check(float(s["boost_gain"]) > 0.0, "boost gain %s" % id, str(s["boost_gain"]))
		TestHooks.check(float(s["mass_kg"]) > 400.0, "mass %s" % id, str(s["mass_kg"]))
		var g := CarDefs.geometry(id)
		TestHooks.check(float(g["length"]) > 3.0 and float(g["width"]) > 1.4, "size %s" % id, str(g))
		TestHooks.check(CarDefs.body_ellipsoids(id).size() == 4, "4 collision ellipsoids %s" % id)
		TestHooks.check(CarDefs.wheel_positions(id).size() == 4, "4 wheels %s" % id)
	# no two cars share a top speed: they must feel different
	var uniq := {}
	for t in tops:
		uniq[t] = true
	TestHooks.check(uniq.size() == tops.size(), "top speeds differ", str(tops))
	TestHooks.check("f4" in CarDefs.IDS and String(CarDefs.get_def("f4")["body"]) == "formula",
		"the F4 is an open-wheeler")
	TestHooks.check(String(CarDefs.get_def("ridge")["body"]) == "offroad", "the Ridge is offroad")


func _slots_well_formed() -> void:
	TestHooks.check(Tuning.SLOTS.size() == 16, "16 tuning slots", str(Tuning.SLOTS.size()))
	TestHooks.check(Tuning.PERF_SLOTS.size() == 8 and Tuning.LOOK_SLOTS.size() == 8,
		"8 performance + 8 look slots")
	for slot: String in Tuning.SLOTS:
		var levels := Tuning.levels(slot)
		TestHooks.check(levels.size() >= 2, "slot %s has levels" % slot, str(levels.size()))
		var choice := Tuning.is_choice(slot)
		TestHooks.check(Tuning.level_price(slot, 0) == 0 or choice,
			"slot %s starts free" % slot, str(Tuning.level_price(slot, 0)))
		var last := -1
		var rising := true
		for i in levels.size():
			var p := Tuning.level_price(slot, i)
			if p < last:
				rising = false
			last = p
			TestHooks.check(Tuning.level_name(slot, i) != "", "slot %s level %d named" % [slot, i])
		# upgrade ladders get dearer with every level; choice slots (paint, vinyl, gearbox) do not
		TestHooks.check(rising or choice, "slot %s prices rise" % slot)


func _effects_apply() -> void:
	for id: String in CarDefs.IDS:
		var stock := Tuning.default_setup(id)
		var base := Tuning.resolve(id, stock)
		var maxed := stock.duplicate()
		for slot: String in Tuning.PERF_SLOTS:
			maxed[slot] = Tuning.level_count(slot) - 1
		maxed["gearbox"] = 1          # close ratio, not the long highway set
		var full := Tuning.resolve(id, maxed)
		TestHooks.check(float(full["accel"]) > float(base["accel"]) * 1.3,
			"engine work pays off %s" % id, "%.2f -> %.2f" % [base["accel"], full["accel"]])
		TestHooks.check(float(full["grip"]) > float(base["grip"]), "tyres add grip %s" % id)
		TestHooks.check(float(full["brake"]) > float(base["brake"]), "brakes add bite %s" % id)
		TestHooks.check(float(full["mass_kg"]) < float(base["mass_kg"]), "weight comes off %s" % id)
		TestHooks.check(float(full["boost_power"]) > 0.0 and float(full["boost_tank"]) > 0.0,
			"nitrous fitted %s" % id)
		TestHooks.check(float(full["ride"]) < 0.0, "the body drops %s" % id, str(full["ride"]))
	# every car rolls out with a small bottle; removing it takes the boost away entirely
	var s := Tuning.default_setup("kaze")
	TestHooks.check(int(s["nitrous"]) == 1, "a bottle is fitted from the showroom", str(s["nitrous"]))
	TestHooks.check(float(Tuning.resolve("kaze", s)["boost_power"]) > 0.0, "so the car can boost")
	s["nitrous"] = 0
	TestHooks.check(float(Tuning.resolve("kaze", s)["boost_power"]) == 0.0, "no bottle, no boost")
	TestHooks.check(float(Tuning.resolve("kaze", s)["boost_tank"]) == 0.0, "and no tank")
	# the long gearbox trades acceleration for top speed, the drag set does the opposite
	var longg := Tuning.default_setup("kaze")
	longg["gearbox"] = 3
	var drag := Tuning.default_setup("kaze")
	drag["gearbox"] = 2
	TestHooks.check(float(Tuning.resolve("kaze", longg)["top_kmh"]) > float(Tuning.resolve("kaze", drag)["top_kmh"]),
		"long gearing is faster flat out")
	TestHooks.check(float(Tuning.resolve("kaze", drag)["accel"]) > float(Tuning.resolve("kaze", longg)["accel"]),
		"drag gearing pulls harder")


func _ratings_in_range() -> void:
	for id: String in CarDefs.IDS:
		var r := Tuning.ratings(id, Tuning.default_setup(id))
		for key in r:
			TestHooks.check(float(r[key]) >= 0.0 and float(r[key]) <= 1.0,
				"rating %s/%s in 0..1" % [id, key], str(r[key]))


func _prices_and_credits() -> void:
	Garage.reset_all()
	Garage.free_build = false
	Garage.credits = 100000
	var before := Garage.credits
	var price := Garage.price_to("kaze", "engine", 2)
	TestHooks.check(price > 0, "upgrading costs", str(price))
	TestHooks.check(Garage.set_level("kaze", "engine", 2), "bought the engine")
	TestHooks.check(Garage.credits == before - price, "credits paid", "%d vs %d" % [Garage.credits, before - price])
	TestHooks.check(Garage.price_to("kaze", "engine", 1) == 0, "going back down is free")
	TestHooks.check(Garage.set_level("kaze", "engine", 1), "refit a part already owned")
	TestHooks.check(Garage.credits == before - price, "no charge the second time")
	Garage.credits = 10
	TestHooks.check(not Garage.set_level("kaze", "engine", 3), "cannot buy what you cannot afford")
	Garage.reset_all()


func _surface_overrides() -> void:
	var slick := Tuning.default_setup("kaze")
	slick["tyres"] = 3
	var so := Tuning.surface_overrides("kaze", slick)
	TestHooks.check(so.has(TmTuning.Surface.GRASS), "slicks override grass")
	var grass_grip := float((so[TmTuning.Surface.GRASS] as Array)[3])
	TestHooks.check(grass_grip < float(TmTuning.surface_vals(TmTuning.Surface.GRASS)[3]),
		"slicks lose grip off the tarmac", str(grass_grip))
	var truck := Tuning.surface_overrides("ridge", Tuning.default_setup("ridge"))
	TestHooks.check(float((truck[TmTuning.Surface.DIRT] as Array)[3]) > float(TmTuning.surface_vals(TmTuning.Surface.DIRT)[3]),
		"the truck keeps its grip on dirt")


func _styles_resolve() -> void:
	for id: String in CarDefs.IDS:
		var style := CarDefs.style_from_setup(id, Tuning.default_setup(id))
		for key: String in CarDefs.STYLE_KEYS:
			TestHooks.check(style.has(key), "style %s has %s" % [id, key])
		TestHooks.check(Color.html_is_valid(String(style["paint"])), "paint colour %s" % id, String(style["paint"]))
		var wide := Tuning.default_setup(id)
		wide["bodykit"] = 3
		wide["spoiler"] = 4
		var s2 := CarDefs.style_from_setup(id, wide)
		TestHooks.check(int(s2["front"]) == 2 and int(s2["spoiler"]) == 4, "kit and wing map through %s" % id)
		var sane := CarDefs.sanitize_style(id, {"paint": "not a colour", "spoiler": 99, "tint": 5.0})
		TestHooks.check(Color.html_is_valid(String(sane["paint"])), "bad colour rejected %s" % id)
		TestHooks.check(int(sane["spoiler"]) <= 4 and float(sane["tint"]) <= 1.0, "values clamped %s" % id)
