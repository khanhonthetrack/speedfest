extends Node
## The player's garage: which car is selected, what is bolted to each one, what has been paid for,
## and the credit balance. Saved to user://garage.json so a session survives a restart.
##
## A car's "setup" is the Dictionary described in cars/tuning.gd. `owned[car][slot]` is the highest
## level bought for that slot: switching between levels you already own is free, going above costs
## the levels in between. All five cars are in the garage from the start; parts are what you buy.

signal changed(car_id: String)
signal credits_changed(credits: int)

const SAVE_PATH := "user://garage.json"
const START_CREDITS := 150000

var credits: int = START_CREDITS
var selected: String = "kaze"
## car_id -> setup Dictionary
var setups: Dictionary = {}
## car_id -> {slot: highest level paid for}
var owned: Dictionary = {}
## Garage test scenes and the showroom set this to ignore the price of everything.
var free_build: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in CarDefs.IDS:
		setups[id] = Tuning.default_setup(id)
		owned[id] = _owned_from_setup(setups[id])
	load_garage()
	if TestHooks.has_arg("car") and CarDefs.has(String(TestHooks.arg("car", ""))):
		selected = String(TestHooks.arg("car", selected))
	if TestHooks.has_arg("free_build"):
		free_build = true


func _owned_from_setup(setup: Dictionary) -> Dictionary:
	var o := {}
	for slot in Tuning.SLOTS:
		o[slot] = int(setup.get(slot, 0))
	return o


func setup_of(car_id: String) -> Dictionary:
	if not setups.has(car_id):
		setups[car_id] = Tuning.default_setup(car_id)
		owned[car_id] = _owned_from_setup(setups[car_id])
	return setups[car_id]


func current_setup() -> Dictionary:
	return setup_of(selected)


func specs_of(car_id: String) -> Dictionary:
	return Tuning.resolve(car_id, setup_of(car_id))


func select(car_id: String) -> void:
	if not CarDefs.has(car_id) or car_id == selected:
		return
	selected = car_id
	changed.emit(car_id)
	save_garage()


func owned_level(car_id: String, slot: String) -> int:
	var o: Dictionary = owned.get(car_id, {})
	return int(o.get(slot, 0))


## Price of moving this slot up to `level` (0 if it is already paid for).
func price_to(car_id: String, slot: String, level: int) -> int:
	var have := owned_level(car_id, slot)
	if level <= have or free_build:
		return 0
	var sum := 0
	for i in range(have + 1, level + 1):
		sum += Tuning.level_price(slot, i)
	return sum


func can_afford(car_id: String, slot: String, level: int) -> bool:
	return credits >= price_to(car_id, slot, level)


## Install a level. Buys the levels in between if needed. Returns false when it is too expensive.
func set_level(car_id: String, slot: String, level: int) -> bool:
	var n := Tuning.level_count(slot)
	if n == 0:
		return false
	level = clampi(level, 0, n - 1)
	var cost := price_to(car_id, slot, level)
	if cost > credits:
		return false
	if cost > 0:
		credits -= cost
		credits_changed.emit(credits)
	var setup := setup_of(car_id)
	setup[slot] = level
	var o: Dictionary = owned.get(car_id, {})
	o[slot] = maxi(int(o.get(slot, 0)), level)
	owned[car_id] = o
	changed.emit(car_id)
	save_garage()
	return true


## Colour and free-text fields (paint_color, neon_color, headlight_color, rim_color, plate...).
func set_value(car_id: String, key: String, value: Variant) -> void:
	setup_of(car_id)[key] = value
	changed.emit(car_id)
	save_garage()


func add_credits(amount: int) -> void:
	credits = maxi(0, credits + amount)
	credits_changed.emit(credits)
	save_garage()


func reset_car(car_id: String) -> void:
	setups[car_id] = Tuning.default_setup(car_id)
	changed.emit(car_id)
	save_garage()


# --- persistence --------------------------------------------------------------------------------

func load_garage() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	credits = int(d.get("credits", credits))
	var sel := String(d.get("selected", selected))
	if CarDefs.has(sel):
		selected = sel
	for id in CarDefs.IDS:
		var saved: Dictionary = (d.get("setups", {}) as Dictionary).get(id, {})
		if not saved.is_empty():
			var base := Tuning.default_setup(id)
			for k in saved:
				base[k] = saved[k]
			setups[id] = base
		var o: Dictionary = (d.get("owned", {}) as Dictionary).get(id, {})
		if not o.is_empty():
			var oo := _owned_from_setup(setups[id])
			for k in o:
				oo[k] = maxi(int(oo.get(k, 0)), int(o[k]))
			owned[id] = oo


func save_garage() -> void:
	var d := {"credits": credits, "selected": selected, "setups": setups, "owned": owned}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
