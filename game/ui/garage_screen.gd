class_name GarageScreen
extends Control
## The garage: pick one of the five cars, see what it does, and spend credits on parts.
##
## Left: the lineup and the car's specs. Right: the slot list (eight performance, eight look) with
## the levels of the selected slot. Middle: the car itself on a turntable under neon rim lights,
## rebuilt the moment anything changes.
##
## Keys: left/right or A/D change the car, up/down pick a slot, enter/space install a level,
## tab switches between performance and look, escape leaves, R drives.

signal drive_requested
signal closed

const TURNTABLE_RPM := 3.0

var car_id: String
var slot_index := 0
var level_index := 0
var showing_perf := true

var _viewport: SubViewport
var _stage: Node3D
var _visual: CarVisual
var _turntable: Node3D
var _name_label: Label
var _arch_label: Label
var _blurb_label: Label
var _credits_label: Label
var _price_label: Label
var _stat_bars: Dictionary = {}
var _stat_values: Dictionary = {}
var _slot_rows: Array[Control] = []
var _level_box: VBoxContainer
var _hint: Label
var _spin := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fill_viewport()
	car_id = Garage.selected if CarDefs.has(Garage.selected) else CarDefs.IDS[0]
	add_child(UiTheme.backdrop())
	_build_stage()
	_build_left()
	_build_right()
	_build_footer()
	_refresh(true)
	set_process_unhandled_input(true)


# --- the car on its turntable --------------------------------------------------------------

func _build_stage() -> void:
	var holder := SubViewportContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1600, 900)
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_4X if Settings.quality >= 2 else Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	holder.add_child(_viewport)
	_stage = Node3D.new()
	_viewport.add_child(_stage)

	var we := WorldEnvironment.new()
	var env := Settings.night_environment()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.016, 0.018, 0.026)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.20, 0.26, 0.40)
	env.ambient_light_energy = 0.10
	env.sdfgi_enabled = false
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_length = 40.0
	env.tonemap_exposure = 0.78
	env.glow_intensity = 0.65
	env.glow_bloom = 0.04
	Settings.tune_environment(env)
	we.environment = env
	_stage.add_child(we)

	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.022, 0.023, 0.030)
	fm.roughness = 0.10
	fm.metallic = 0.70
	floor_mi.material_override = fm
	_stage.add_child(floor_mi)

	# a ring of neon tubes behind the platform: the garage's rim light, kept out of the camera's
	# way (the near half of the ring would otherwise sit across the car)
	for i in 10:
		var a := TAU * float(i) / 10.0
		var p := Vector3(cos(a) * 9.0, 1.6, sin(a) * 9.0)
		var col := UiTheme.CYAN if i % 2 == 0 else UiTheme.MAGENTA
		var tube := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.10, 3.2, 0.10)
		tube.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = col * 0.3
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 2.2
		tube.material_override = m
		tube.position = p
		_stage.add_child(tube)
		var ol := OmniLight3D.new()
		ol.position = p + Vector3(0, 0.2, 0)
		ol.light_color = col
		ol.light_energy = 1.6
		ol.omni_range = 11.0
		ol.light_specular = 1.0
		ol.shadow_enabled = false
		_stage.add_child(ol)

	# two soft practicals over the car, the way a workshop is lit
	for xz: Vector3 in [Vector3(2.6, 4.2, -1.4), Vector3(-2.2, 4.0, 2.0)]:
		var sp := SpotLight3D.new()
		sp.position = xz
		sp.look_at_from_position(xz, Vector3(0, 0.5, 0), Vector3.UP)
		sp.light_energy = 6.0
		sp.light_color = Color(0.92, 0.95, 1.0)
		sp.spot_range = 12.0
		sp.spot_angle = 38.0
		sp.spot_attenuation = 1.4
		sp.shadow_enabled = Settings.quality >= 2
		_stage.add_child(sp)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 143, 0)
	key.light_energy = 0.18
	key.light_color = Color(0.70, 0.80, 1.0)
	key.shadow_enabled = Settings.quality >= 1
	_stage.add_child(key)

	_turntable = Node3D.new()
	_stage.add_child(_turntable)

	var cam := Camera3D.new()
	cam.fov = 34.0
	_stage.add_child(cam)
	cam.look_at_from_position(Vector3(5.6, 1.75, -6.6), Vector3(0, 0.62, 0), Vector3.UP)
	cam.current = true



func _rebuild_car() -> void:
	if _visual:
		_visual.queue_free()
	_visual = CarVisual.new()
	_turntable.add_child(_visual)
	_visual.build(car_id, CarDefs.style_from_setup(car_id, Garage.setup_of(car_id)))
	_visual.position = Vector3(0, float(CarDefs.geometry(car_id)["wheel_radius"]), 0)
	_visual.set_wheel_state(deg_to_rad(6.0), [0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0])
	_visual.set_headlights_real(Settings.quality >= 1)


# --- panels --------------------------------------------------------------------------------

## A dark vertical scrim so the panels stay readable over the lit car.
func _scrim(right_side: bool) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.015, 0.017, 0.026, 0.92))
	g.set_color(1, Color(0.015, 0.017, 0.026, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 8
	tex.fill_from = Vector2(1, 0) if right_side else Vector2(0, 0)
	tex.fill_to = Vector2(0, 0) if right_side else Vector2(1, 0)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE if right_side else Control.PRESET_LEFT_WIDE)
	if right_side:
		tr.offset_left = -640
	else:
		tr.offset_right = 640
	add_child(tr)


func _build_left() -> void:
	_scrim(false)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	box.offset_left = 56
	box.offset_top = 44
	box.offset_right = 516
	box.offset_bottom = 760
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var title := UiTheme.label("GARAGE", 26, UiTheme.MAGENTA, true)
	box.add_child(title)
	_name_label = UiTheme.label("", 52, UiTheme.WHITE, true)
	box.add_child(_name_label)
	_arch_label = UiTheme.label("", 20, UiTheme.CYAN)
	box.add_child(_arch_label)
	_blurb_label = UiTheme.label("", 18, UiTheme.DIM)
	_blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb_label.custom_minimum_size = Vector2(420, 54)
	box.add_child(_blurb_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	box.add_child(spacer)

	for bar: Dictionary in Tuning.SPEC_BARS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var lab := UiTheme.label(String(bar["label"]).to_upper(), 16, UiTheme.DIM)
		lab.custom_minimum_size = Vector2(130, 0)
		row.add_child(lab)
		var pb := UiTheme.stat_bar(UiTheme.CYAN)
		row.add_child(pb)
		var val := UiTheme.label("", 16, UiTheme.WHITE)
		val.custom_minimum_size = Vector2(66, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		_stat_bars[String(bar["key"])] = pb
		_stat_values[String(bar["key"])] = val

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer2)
	var lineup := HBoxContainer.new()
	lineup.add_theme_constant_override("separation", 8)
	box.add_child(lineup)
	for id: String in CarDefs.IDS:
		var b := UiTheme.button(CarDefs.name_of(id).split(" ")[0].to_upper(), UiTheme.CYAN)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func() -> void: _select_car(id))
		lineup.add_child(b)


func _build_right() -> void:
	_scrim(true)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -548
	box.offset_right = -48
	box.offset_top = 44
	box.offset_bottom = 820
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	box.add_child(head)
	var tabs := UiTheme.label("PERFORMANCE / LOOK  [TAB]", 16, UiTheme.MAGENTA)
	head.add_child(tabs)
	_credits_label = UiTheme.label("", 20, UiTheme.LIME)
	head.add_child(_credits_label)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	box.add_child(cols)

	var slots := VBoxContainer.new()
	slots.add_theme_constant_override("separation", 2)
	slots.custom_minimum_size = Vector2(230, 0)
	cols.add_child(slots)
	for i in 8:
		var row := UiTheme.panel(UiTheme.CYAN)
		var line := UiTheme.label("", 17, UiTheme.WHITE)
		row.add_child(line)
		row.set_meta("label", line)
		slots.add_child(row)
		_slot_rows.append(row)

	_level_box = VBoxContainer.new()
	_level_box.add_theme_constant_override("separation", 2)
	_level_box.custom_minimum_size = Vector2(220, 0)
	cols.add_child(_level_box)

	_price_label = UiTheme.label("", 18, UiTheme.AMBER)
	box.add_child(_price_label)


func _build_footer() -> void:
	_hint = UiTheme.label("[←→] car    [↑↓] part    [ENTER] fit    [TAB] performance / look    [R] drive    [ESC] back",
		17, UiTheme.DIM)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 56
	_hint.offset_top = -52
	_hint.offset_right = 1200
	_hint.offset_bottom = -20
	add_child(_hint)


# --- state ---------------------------------------------------------------------------------

func _slots() -> Array:
	return Tuning.PERF_SLOTS if showing_perf else Tuning.LOOK_SLOTS


func _current_slot() -> String:
	var s := _slots()
	return String(s[clampi(slot_index, 0, s.size() - 1)])


func _select_car(id: String) -> void:
	if id == car_id:
		return
	car_id = id
	Garage.select(id)
	_refresh(true)


func _refresh(rebuild: bool) -> void:
	var def := CarDefs.get_def(car_id)
	_name_label.text = String(def["name"]).to_upper()
	_arch_label.text = String(def["archetype"]).to_upper()
	_blurb_label.text = String(def["blurb"])
	_credits_label.text = "%s CR" % _money(Garage.credits)
	var setup := Garage.setup_of(car_id)
	var res := Tuning.resolve(car_id, setup)
	var ratings := Tuning.ratings(car_id, setup)
	for bar: Dictionary in Tuning.SPEC_BARS:
		var key := String(bar["key"])
		var pb: ProgressBar = _stat_bars[key]
		pb.value = float(ratings.get(key, 0.0))
		UiTheme.set_bar_color(pb, UiTheme.CYAN.lerp(UiTheme.MAGENTA, pb.value))
		var v: Label = _stat_values[key]
		match key:
			"top_kmh":
				v.text = "%d" % roundi(float(res["top_kmh"]))
			"boost":
				v.text = "%d%%" % roundi(float(res["boost"]) * 100.0)
			_:
				v.text = "%.2f" % float(res.get(key, 0.0))
	_refresh_slots()
	if rebuild:
		_rebuild_car()


func _refresh_slots() -> void:
	var slots := _slots()
	slot_index = clampi(slot_index, 0, slots.size() - 1)
	var setup := Garage.setup_of(car_id)
	for i in _slot_rows.size():
		var row := _slot_rows[i]
		var lab: Label = row.get_meta("label")
		if i >= slots.size():
			lab.text = ""
			continue
		var slot := String(slots[i])
		var lvl := int(setup.get(slot, 0))
		lab.text = "%s   %s" % [Tuning.slot_label(slot).to_upper(), Tuning.level_name(slot, lvl)]
		var sel := i == slot_index
		lab.add_theme_color_override("font_color", UiTheme.WHITE if sel else UiTheme.DIM)
		var sb := row.get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb.border_width_left = 5 if sel else 2
			sb.border_color = UiTheme.MAGENTA if sel else Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.35)
	_refresh_levels()


func _refresh_levels() -> void:
	for c in _level_box.get_children():
		c.queue_free()
	var slot := _current_slot()
	var setup := Garage.setup_of(car_id)
	var fitted := int(setup.get(slot, 0))
	var n := Tuning.level_count(slot)
	level_index = clampi(level_index, 0, maxi(0, n - 1))
	var hint := UiTheme.label(String((Tuning.CATALOGUE.get(slot, {}) as Dictionary).get("hint", "")),
		15, UiTheme.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(220, 46)
	_level_box.add_child(hint)
	for i in n:
		var owned := Garage.owned_level(car_id, slot) >= i
		var price := Garage.price_to(car_id, slot, i)
		var mark := "●" if i == fitted else ("○" if owned else "+")
		var text := "%s %s" % [mark, Tuning.level_name(slot, i)]
		if not owned and price > 0:
			text += "   %s" % _money(price)
		var lab := UiTheme.label(text, 16, UiTheme.WHITE if i == level_index else UiTheme.DIM)
		if not owned and price > Garage.credits:
			lab.add_theme_color_override("font_color", UiTheme.DANGER)
		elif i == fitted:
			lab.add_theme_color_override("font_color", UiTheme.LIME)
		_level_box.add_child(lab)
	var total := Tuning.total_price(setup)
	_price_label.text = "FITTED VALUE  %s CR" % _money(total)


func _install() -> void:
	var slot := _current_slot()
	var before := Garage.setup_of(car_id).duplicate()
	if Garage.set_level(car_id, slot, level_index):
		var changed := String(before.get(slot, 0)) != String(Garage.setup_of(car_id).get(slot, 0))
		_refresh(changed and _affects_model(slot))
		if not changed:
			_refresh(false)
	else:
		_price_label.text = "NOT ENOUGH CREDITS"
		_price_label.add_theme_color_override("font_color", UiTheme.DANGER)


## Which slots change the mesh or the materials (and so need the model rebuilt).
func _affects_model(slot: String) -> bool:
	return slot in ["bodykit", "spoiler", "rims", "paint", "vinyl", "neon", "headlights", "tint",
		"weight", "suspension"]


func _cycle_colour(slot: String, dir: int) -> void:
	var key: String = {"paint": "paint_color", "neon": "neon_color", "headlights": "headlight_color"}.get(slot, "")
	if key == "":
		return
	var palette: Array = {"paint": Tuning.PAINT_COLOURS, "neon": Tuning.NEON_COLOURS,
		"headlights": Tuning.HEADLIGHT_COLOURS}[slot]
	var cur := String(Garage.setup_of(car_id).get(key, palette[0]))
	var i := palette.find(cur)
	i = posmod(i + dir, palette.size()) if i >= 0 else 0
	Garage.set_value(car_id, key, String(palette[i]))
	_refresh(true)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.is_echo()):
		return
	var key := (event as InputEventKey).keycode
	match key:
		KEY_LEFT, KEY_A:
			var i := CarDefs.IDS.find(car_id)
			_select_car(String(CarDefs.IDS[posmod(i - 1, CarDefs.IDS.size())]))
		KEY_RIGHT, KEY_D:
			var i2 := CarDefs.IDS.find(car_id)
			_select_car(String(CarDefs.IDS[posmod(i2 + 1, CarDefs.IDS.size())]))
		KEY_UP, KEY_W:
			slot_index = posmod(slot_index - 1, _slots().size())
			level_index = int(Garage.setup_of(car_id).get(_current_slot(), 0))
			_refresh_slots()
		KEY_DOWN, KEY_S:
			slot_index = posmod(slot_index + 1, _slots().size())
			level_index = int(Garage.setup_of(car_id).get(_current_slot(), 0))
			_refresh_slots()
		KEY_BRACKETLEFT, KEY_COMMA:
			level_index = maxi(0, level_index - 1)
			_refresh_levels()
		KEY_BRACKETRIGHT, KEY_PERIOD:
			level_index = mini(Tuning.level_count(_current_slot()) - 1, level_index + 1)
			_refresh_levels()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_install()
		KEY_C:
			_cycle_colour(_current_slot(), 1)
		KEY_TAB:
			showing_perf = not showing_perf
			slot_index = 0
			level_index = 0
			_refresh_slots()
		KEY_R:
			drive_requested.emit()
		KEY_ESCAPE:
			closed.emit()
		KEY_P:
			_spin = not _spin


func _process(delta: float) -> void:
	if _turntable and _spin:
		_turntable.rotate_y(delta * TURNTABLE_RPM * TAU / 60.0)


static func _money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if v < 0 else "") + out


## Controls size themselves against their parent Control; when there is none (a test scene whose
## root is a plain Node) fall back to the viewport, so the anchored panels land on screen.
func _fill_viewport() -> void:
	if get_parent() is Control:
		return
	size = get_viewport_rect().size
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_fill_viewport):
		vp.size_changed.connect(_fill_viewport)
