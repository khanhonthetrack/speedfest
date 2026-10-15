extends Node
## Headless: garage changes go to Profile (tuning, style, selected car), sanitize the plate,
## reset works, and the values survive a save + reload of the profile.


func _ready() -> void:
	var g: Control = load("res://ui/garage.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	# car selection
	g.select_car("brute")
	TestHooks.check(Profile.selected_car == "brute", "garage_select_car")
	# tuning through the real slider signal
	(g.sliders["gearing"] as HSlider).value = 0.7
	TestHooks.check(is_equal_approx(float(Profile.get_config("brute")["tuning"]["gearing"]), 0.7), "garage_tuning_slider",
		str(Profile.get_config("brute")["tuning"]))
	g.set_tuning_value("balance", -0.33)
	TestHooks.check(is_equal_approx(float(Profile.get_config("brute")["tuning"]["balance"]), -0.3), "garage_tuning_snapped")
	# style through chips and swatches (press the actual buttons)
	var finish_row: Container = g.chip_rows["finish"]
	(finish_row.get_child(4) as Button).pressed.emit()
	TestHooks.check(Profile.get_config("brute")["style"]["finish"] == "chrome", "garage_finish_chip")
	var spoiler_row: Container = g.chip_rows["spoiler"]
	(spoiler_row.get_child(4) as Button).pressed.emit()
	TestHooks.check(int(Profile.get_config("brute")["style"]["spoiler"]) == 4, "garage_spoiler_chip")
	var paint_row: Container = g.swatch_rows["paint"]
	(paint_row.get_child(2) as BaseButton).pressed.emit()
	TestHooks.check(Color(String(Profile.get_config("brute")["style"]["paint"])).is_equal_approx(Color(MenuKit.PAINT_SWATCHES[2])), "garage_paint_swatch",
		String(Profile.get_config("brute")["style"]["paint"]))
	g.carbon_check.button_pressed = true
	TestHooks.check(Profile.get_config("brute")["style"]["hood_carbon"] == true, "garage_carbon_toggle")
	(g.style_sliders["ride_height"] as HSlider).value = -0.8
	TestHooks.check(is_equal_approx(float(Profile.get_config("brute")["style"]["ride_height"]), -0.8), "garage_ride_height")
	(g.chip_rows["underglow_mode"].get_child(4) as Button).pressed.emit()
	TestHooks.check(Profile.get_config("brute")["style"]["underglow_mode"] == "rainbow", "garage_underglow_mode")
	# plate sanitizing through text_changed
	g.plate_edit.text = "ab!c-12345"
	g.plate_edit.text_changed.emit(g.plate_edit.text)
	TestHooks.check(Profile.get_config("brute")["style"]["plate"] == "ABC-1234", "garage_plate_sanitized",
		String(Profile.get_config("brute")["style"]["plate"]))
	# per-car independence
	g.select_car("kaze")
	TestHooks.check(Profile.get_config("kaze")["style"]["finish"] == CarDefs.default_style("kaze")["finish"], "garage_cars_independent")
	TestHooks.check(is_equal_approx((g.sliders["gearing"] as HSlider).value, float(Profile.get_config("kaze")["tuning"]["gearing"])), "garage_controls_reload")
	g.select_car("brute")
	TestHooks.check(is_equal_approx((g.sliders["gearing"] as HSlider).value, 0.7), "garage_controls_show_brute")
	# save + reload
	Profile.save()
	var saved := Profile.get_config("brute")
	Profile.cars = {}
	Profile.load_profile()
	var loaded := Profile.get_config("brute")
	TestHooks.check(JSON.stringify(loaded, "", true) == JSON.stringify(saved, "", true) and Profile.selected_car == "brute", "garage_persisted",
		"%s\nvs\n%s (selected %s)" % [JSON.stringify(loaded, "", true), JSON.stringify(saved, "", true), Profile.selected_car])
	# reset
	g.reset_tuning()
	TestHooks.check(Profile.get_config("brute")["tuning"] == CarDefs.default_tuning(), "garage_reset_tuning")
	g.reset_style()
	TestHooks.check(Profile.get_config("brute")["style"] == CarDefs.sanitize_config(CarDefs.default_config("brute"))["style"], "garage_reset_style")
	# stats respond (with real Tuning: gearing toward top speed raises top_speed)
	var s0 := Tuning.stats("brute", CarDefs.default_tuning())
	TestHooks.check(s0.has("top_speed_kmh") and s0.has("zero_to_100_s"), "garage_stats_shape")
	TestHooks.finish()
