class_name LobbyLineup
extends SubViewportContainer
## Rocket League-style car lineup for the online room (owner, session 4): every player's car,
## parked side by side under a soft light, with their name and HOST / READY / YOU above it.
## A player who joins rolls their car in; leaving slides the others together; a car or style
## change (from that player's garage) updates live. Own 3D world, so it never touches the scene.
##   set_players(players: Array, my_id: int, host_id: int)   # Net room "players" entries

const SPACING := 2.9           # m between car centres
const CAR_YAW := PI - 0.45     # rad: cars face the camera at a 3/4 front angle
const ARRIVE_FROM := Vector3(0, 0, -9.0)

var viewport: SubViewport
var camera: Camera3D
var _stage: Node3D
var _slots: Dictionary = {}     # player id -> {root, visual, name, status, car, style_json, pool}
var _order: Array = []          # player ids in display order
var _cam_tween: Tween
var _pool_mesh: Mesh
var _pool_mat: StandardMaterial3D
var _pool_me_mat: StandardMaterial3D
## The lineup is static except while cars arrive/move or styles change: render only then (keeps
## the last frame otherwise). Big win on weak GPUs / software rendering.
var _awake := 0.0
const AWAKE_S := 1.4


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(320, 180)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.msaa_3d = Viewport.MSAA_DISABLED if Settings.is_compat() else Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_awake = AWAKE_S
	add_child(viewport)
	_stage = Node3D.new()
	_stage.name = "Stage"
	viewport.add_child(_stage)
	_build_stage()


func car_count() -> int:
	return _slots.size()


func has_player(id: int) -> bool:
	return _slots.has(id)


## Style dictionary currently shown for a player (tests).
func shown_config(id: int) -> Dictionary:
	if not _slots.has(id):
		return {}
	return {"car": _slots[id]["car"], "style": JSON.parse_string(_slots[id]["style_json"])}


func _process(delta: float) -> void:
	if _awake > 0.0:
		_awake -= delta
		if _awake <= 0.0:
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Render continuously for a moment (animations, style changes), then freeze on the last frame.
func wake(seconds: float = AWAKE_S) -> void:
	_awake = maxf(_awake, seconds)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func set_players(players: Array, my_id: int, host_id: int) -> void:
	wake()
	var ids: Array = []
	for p in players:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var id := int(p.get("id", -1))
		ids.append(id)
		var cfg := CarDefs.sanitize_config(p.get("car", {}))
		if not _slots.has(id):
			_add_slot(id, cfg)
		else:
			_update_slot(id, cfg)
		_set_tags(id, String(p.get("name", "?")), id == my_id, id == host_id, bool(p.get("ready", false)))
	for id in _slots.keys():
		if not id in ids:
			var s: Dictionary = _slots[id]
			(s["root"] as Node3D).queue_free()
			_slots.erase(id)
	_order = ids
	_layout()


# --- slots -----------------------------------------------------------------------------------------

func _add_slot(id: int, cfg: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Slot%d" % id
	_stage.add_child(root)
	var pool := MeshInstance3D.new()
	pool.mesh = _pool_mesh
	pool.material_override = _pool_mat
	pool.position = Vector3(0, 0.012, 0)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pool)
	var car_holder := Node3D.new()
	car_holder.name = "Car"
	root.add_child(car_holder)
	var name_l := _label(64, Color.WHITE)
	name_l.position = Vector3(0, 2.45, 0)
	root.add_child(name_l)
	var status_l := _label(34, UITheme.TEXT_DIM)
	status_l.position = Vector3(0, 1.95, 0)
	root.add_child(status_l)
	_slots[id] = {"root": root, "holder": car_holder, "visual": null, "name": name_l, "status": status_l,
		"car": "", "style_json": "", "pool": pool, "new": true}
	_update_slot(id, cfg)


func _update_slot(id: int, cfg: Dictionary) -> void:
	var s: Dictionary = _slots[id]
	var car_id := String(cfg["car"])
	var style_json := JSON.stringify(cfg["style"])
	if car_id == s["car"] and style_json == s["style_json"]:
		return
	var holder: Node3D = s["holder"]
	var v: CarVisual = s["visual"]
	if v == null or car_id != s["car"]:
		if v:
			v.queue_free()
		v = CarVisual.new()
		v.underglow_light_allowed = false
		holder.add_child(v)
		v.build(car_id, cfg["style"])
		v.set_headlights_real(false)
		v.position = Vector3(0, float(CarDefs.geometry(car_id)["wheel_radius"]), 0)
		s["visual"] = v
		if not s.get("new", false):
			_pop(holder)
	else:
		v.apply_style(cfg["style"])
	v.set_underglow_enabled(true)
	s["car"] = car_id
	s["style_json"] = style_json


func _set_tags(id: int, player_name: String, me: bool, host: bool, ready: bool) -> void:
	var s: Dictionary = _slots[id]
	var nl: Label3D = s["name"]
	nl.text = player_name
	nl.modulate = UITheme.CYAN if me else Color.WHITE
	# short status so neighbours never overlap (the name's colour already marks "you")
	var sl: Label3D = s["status"]
	sl.text = ("HOST · " if host else "") + ("READY" if ready else "NOT READY")
	sl.modulate = UITheme.LIME if ready else UITheme.TEXT_DIM
	(s["pool"] as MeshInstance3D).material_override = _pool_me_mat if me else _pool_mat


## Places cars left to right in join order, frames them, and animates arrivals.
func _layout() -> void:
	var n := _order.size()
	var x0 := -(n - 1) * SPACING * 0.5
	for i in n:
		var s: Dictionary = _slots[_order[i]]
		var root: Node3D = s["root"]
		var target := Vector3(x0 + i * SPACING, 0, 0)
		var holder: Node3D = s["holder"]
		holder.rotation.y = CAR_YAW
		if s.get("new", false):
			s["new"] = false
			root.position = target
			holder.position = ARRIVE_FROM
			var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.tween_property(holder, "position", Vector3.ZERO, 0.8)
		elif root.position.distance_to(target) > 0.01:
			create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(root, "position", target, 0.5)
	_frame_camera(n)


func _frame_camera(n: int) -> void:
	var width := maxf(float(n) * SPACING + 1.2, 6.5)
	var aspect := maxf(size.x, 1.0) / maxf(size.y, 1.0) if size.y > 1.0 else 2.0
	var hfov := 2.0 * atan(tan(deg_to_rad(camera.fov) * 0.5) * aspect)
	var dist := (width * 0.5) / tan(hfov * 0.5) + 2.2
	var goal := Vector3(0, 1.4 + dist * 0.3, dist)
	if _cam_tween:
		_cam_tween.kill()
	_cam_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_method(_place_camera, camera.position, goal, 0.5)


func _place_camera(p: Vector3) -> void:
	if camera.is_inside_tree():
		camera.look_at_from_position(p, Vector3(0, 0.9, 0), Vector3.UP)
	else:
		camera.transform = Transform3D.IDENTITY.looking_at(Vector3(0, 0.9, 0) - p, Vector3.UP).translated(p)


func _pop(holder: Node3D) -> void:
	holder.scale = Vector3(0.85, 0.85, 0.85)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(holder, "scale", Vector3.ONE, 0.35)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and camera:
		_frame_camera(_order.size())
		wake()


# --- stage -----------------------------------------------------------------------------------------

func _label(px: int, color: Color) -> Label3D:
	var l := Label3D.new()
	var f: Variant = load("res://assets/fonts/orbitron-latin-700-normal.woff2")
	if f is Font:
		l.font = f
	l.font_size = px
	l.pixel_size = 0.006
	l.outline_size = 10
	l.outline_modulate = Color(0.0, 0.01, 0.04, 0.9)
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	l.render_priority = 2
	return l


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.055, 0.075)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.055, 0.075)
	env.fog_density = 0.035
	Settings.tune_environment(env)
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, 28, 0)
	key.light_energy = 1.1
	key.light_color = Color(1.0, 0.96, 0.9)
	key.shadow_enabled = not Settings.is_compat()
	_stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.7
	rim.light_color = Color(0.6, 0.75, 1.0)
	_stage.add_child(rim)
	# polished dark concrete floor (no grid)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 40)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.11, 0.115, 0.13)
	fm.roughness = 0.6
	fm.metallic = 0.0
	floor_mi.material_override = fm
	_stage.add_child(floor_mi)
	# soft light pool under each car (a radial-gradient disc)
	var disc := QuadMesh.new()
	disc.size = Vector2(4.2, 6.0)
	disc.orientation = PlaneMesh.FACE_Y
	_pool_mesh = disc
	_pool_mat = _pool_material(Color(0.75, 0.8, 0.9), 0.16)
	_pool_me_mat = _pool_material(UITheme.CYAN, 0.24)
	camera = Camera3D.new()
	camera.fov = 34.0
	camera.far = 200.0
	_stage.add_child(camera)
	_place_camera(Vector3(0, 3.0, 12.0))


func _pool_material(color: Color, energy: float) -> StandardMaterial3D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = gt
	m.albedo_color = Color(color, energy)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m
