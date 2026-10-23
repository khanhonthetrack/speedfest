class_name StoryScene
extends Node3D
## Plays one cutscene from data (story/scenes/<id>.json; PLAN M20-3). A scene is a list of shots on
## our own tracks; everything in a shot is a function of the scene's time (seek(t)): the camera
## between its keys, cars standing or driving along the track's line, people playing their clips
## (StoryPerson), lights, rain, and the 2D layer (StorySubtitles: bars, subtitles, fades, title
## cards, a phone's texts). So a scene seeks to any frame (story/story_lab.tscn screenshots it), is
## skippable at any frame, never touches a race's simulation, and plays the same headless.
##
## Scene: {"id", "chapter", "title", "track" (default for its shots), "at" (default anchor),
##   "set": [flags the scene sets when it ends or is skipped], "shots": [shot, ...]}
## Shot: {"id", "track", "at" (fraction of the track's racing line where the shot's anchor stands),
##   "left", "ahead" (m off that point), "dur" (s; default: as long as its lines need, "lead"
##   before the first and "tail" after the last), "min" (s, default 2.5),
##   "camera": {"keys": [{"u" (0..1 of the shot) | "t" (s), "pos": [x, y, z], "look": [x, y, z],
##     "fov" (40), "roll" (deg), "dof": [far m, transition m, amount]}], "ease": "inout" | "linear" |
##     "in" | "out", "follow": a car's id (its frame instead of the anchor's), "shake": m},
##   "cars": [{"id", "model" (TmCarVisual.model: a road car's id, "hyper", "" the open-wheeler),
##     "livery", "colour" (TmUi.CAR_COLOURS index), "tuning": "spoiler.rims.glow.hood", "ghost",
##     "left", "ahead" (m from the anchor along the line), "lift", "yaw" (deg), "lights" (headlights),
##     "speed" (m/s along the line), "accel" (m/s^2; it stops when its speed reaches 0)}],
##   "people": [StoryPerson spec], "lights": [{"kind": "omni" | "spot", "pos", "look", "colour",
##     "energy", "range", "angle"}], "rain": 0..1, "fade_in", "fade_out" (s), "black": true (no
##   picture: a title card on black), "card": {"title", "subtitle"},
##   "lines": [{"id", "speaker", "text", "kind": "say" (a subtitle) | "text" (a message arriving on
##     the phone: "mine" for the player's own) | "phone" (the thread's name: {"from"}), "hold" (s;
##     default from the text's length), "gap" (s before it), "at" (s into the shot, else after the
##     line before), "if" (StoryState.holds), "set": [flags]}]}
## Positions are in the shot's anchor frame: x left, y up, z ahead along the line (menu_art's).

signal finished(skipped: bool)

const DIR := "res://story/scenes"
const READ_CPS := 15.0                 ## subtitle reading speed (characters per second)

var data := {}
var state: StoryState                  ## the save the conditions read (a fresh one if null)
var with_stage := true                 ## build the tracks (false: logic only, tests)
var shots: Array = []                  ## resolved: each with start, end (s) and its lines (absolute at, hold)
var length := 0.0
var t := 0.0
var playing := false
var subtitles: StorySubtitles
var camera: Camera3D
var skip_held := 0.0

var _shot := -1
var _stage: Node3D
var _stage_track := ""
var _challenge: TmChallenge
var _anchor := Transform3D()
var _cars := {}                        ## id -> {node: Node3D (TmCarVisual), spec}
var _people: Array[StoryPerson] = []
var _props: Node3D
var _rain: GPUParticles3D
var _attrs: CameraAttributesPractical
var _done := false


static func path_of(id: String) -> String:
	return DIR.path_join(id + ".json")


static func load_data(id: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path_of(id))
	var d: Variant = JSON.parse_string(text) if not text.is_empty() else null
	return d if d is Dictionary else {}


## Every scene file's id.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json"):
			out.append(f.get_basename())
	out.sort()
	return out


func setup(d: Dictionary, st: StoryState = null, stage := true) -> void:
	data = d
	state = st if st != null else StoryState.new()
	with_stage = stage
	resolve()
	camera = Camera3D.new()
	camera.far = TmSkyline.FAR
	camera.current = true
	_attrs = CameraAttributesPractical.new()
	camera.attributes = _attrs
	add_child(camera)
	_props = Node3D.new()
	_props.name = "Props"
	add_child(_props)
	subtitles = StorySubtitles.new()
	add_child(subtitles)


## Times every shot and line, the lines whose conditions fail left out (so a cold, warm or hot
## variant takes the time it needs).
func resolve() -> void:
	shots.clear()
	var at := 0.0
	for s: Dictionary in data.get("shots", []):
		var shot := s.duplicate(true)
		var lines: Array = []
		var cur := float(s.get("lead", 0.6))
		var first := true
		for l: Dictionary in s.get("lines", []):
			if not state.holds(l.get("if", null)):
				continue
			var line := l.duplicate(true)
			var hold := float(l.get("hold", reading_time(String(l.get("text", ""))))) if String(l.get("kind", "say")) != "phone" else 0.0
			var start := float(l["at"]) if l.has("at") else cur + (0.0 if first else float(l.get("gap", 0.3)))
			line["at"] = at + start
			line["hold"] = hold
			lines.append(line)
			cur = start + hold
			first = false
		var dur := float(s["dur"]) if s.has("dur") else maxf(float(s.get("min", 2.5)), cur + float(s.get("tail", 0.8)))
		shot["start"] = at
		shot["end"] = at + dur
		shot["lines"] = lines
		shots.append(shot)
		at += dur
	length = at


static func reading_time(text: String) -> float:
	return clampf(0.9 + text.length() / READ_CPS, 1.8, 9.0)


## The flags the scene sets: its own and those of every line that plays (also when skipped).
func flags_set() -> Array[String]:
	var out: Array[String] = []
	for f: Variant in data.get("set", []):
		out.append(String(f))
	for s: Dictionary in shots:
		for l: Dictionary in s["lines"]:
			for f: Variant in l.get("set", []):
				out.append(String(f))
	return out


func play(from := 0.0) -> void:
	playing = true
	seek(from)


## Skips to the end: the scene's flags all set, as if it had played.
func skip() -> void:
	if _done:
		return
	t = length
	_finish(true)


func _finish(skipped: bool) -> void:
	_done = true
	playing = false
	if state != null:
		for f in flags_set():
			state.flags[f] = true
		state.seen_scenes[String(data.get("id", ""))] = true
	finished.emit(skipped)


func shot_at(time: float) -> int:
	for i in shots.size():
		if time < float(shots[i]["end"]) or i == shots.size() - 1:
			return i
	return -1


## The line on screen at a time ({} if none) and the phone's thread so far.
func line_at(time: float) -> Dictionary:
	var i := shot_at(time)
	if i < 0:
		return {}
	for l: Dictionary in shots[i]["lines"]:
		if String(l.get("kind", "say")) == "say" and time >= float(l["at"]) and time < float(l["at"]) + float(l["hold"]):
			return l
	return {}


func phone_at(time: float) -> Dictionary:
	var i := shot_at(time)
	if i < 0:
		return {}
	var from := ""
	var msgs: Array = []
	var any := false
	for l: Dictionary in shots[i]["lines"]:
		var kind := String(l.get("kind", "say"))
		if kind == "phone":
			from = String(l.get("from", l.get("text", "")))
			any = true
		elif kind == "text":
			any = true
			if time >= float(l["at"]):
				msgs.append({"text": String(l.get("text", "")), "mine": bool(l.get("mine", false))})
	return {"from": from, "messages": msgs} if any else {}


func _process(delta: float) -> void:
	if not playing or _done:
		return
	var holding := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_ESCAPE)
	skip_held = skip_held + delta if holding else 0.0
	if skip_held >= StorySubtitles.SKIP_HOLD:
		skip()
		return
	seek(t + delta)
	if t >= length:
		_finish(false)


func seek(time: float) -> void:
	t = clampf(time, 0.0, length)
	var i := shot_at(t)
	if i < 0:
		return
	if i != _shot:
		_enter(i)
	_pose(t - float(shots[i]["start"]))


# --- a shot ---------------------------------------------------------------------------------

func _enter(i: int) -> void:
	_shot = i
	var s: Dictionary = shots[i]
	var track := String(s.get("track", data.get("track", "")))
	if with_stage and not track.is_empty() and track != _stage_track:
		_build_stage(track)
	for c: Dictionary in _cars.values():
		(c["node"] as Node).queue_free()
	_cars.clear()
	for p in _people:
		p.queue_free()
	_people.clear()
	for n in _props.get_children():
		n.queue_free()
	_anchor = _road_xf(float(s.get("at", data.get("at", 0.5))), float(s.get("left", 0.0)), float(s.get("ahead", 0.0)))
	for c: Dictionary in s.get("cars", []):
		_add_car(c)
	for p: Dictionary in s.get("people", []):
		var person := StoryPerson.new()
		add_child(person)
		person.setup(p, _anchor, func(q: Vector3) -> Vector3: return _ground(_anchor * q))
		_people.append(person)
	for l: Dictionary in s.get("lights", []):
		_add_light(l)
	_set_rain(float(s.get("rain", data.get("rain", 0.0))))


func _build_stage(track: String) -> void:
	if _stage != null:
		_stage.queue_free()
	_stage_track = track
	_challenge = TmTracks.challenge(track)
	_stage = Node3D.new()
	_stage.name = "Stage"
	add_child(_stage)
	if not _challenge.ok():
		push_error("story: %s" % _challenge.error)
		return
	var b := TmMapBuilder.build(_challenge)
	_stage.add_child(b.root)
	TmStage.add_environment(_stage, b)


## A place on the track's racing line: fraction `at` of it, `left` m to its left, `ahead` m on.
func _road_xf(at: float, left: float, ahead: float) -> Transform3D:
	if _challenge == null or not _challenge.ok() or _challenge.path.is_empty():
		return Transform3D(Basis(), Vector3(-left, 0.0, ahead))
	var path := _challenge.path
	var i := clampi(int(at * (path.size() - 1)), 0, path.size() - 1)
	var j := i
	var walked := 0.0
	var step := 1 if ahead >= 0.0 else -1
	var p: Vector3 = path[j]["p"]
	while absf(walked) < absf(ahead) and j + step >= 0 and j + step < path.size():
		var seg := (path[j + step]["p"] as Vector3).distance_to(path[j]["p"])
		if walked + seg >= absf(ahead):
			p = (path[j]["p"] as Vector3).lerp(path[j + step]["p"], (absf(ahead) - walked) / maxf(seg, 0.001))
			walked = absf(ahead)
			break
		walked += seg
		j += step
		p = path[j]["p"]
	var d: Vector3 = (path[j]["dir"] as Vector3).normalized()
	var side := Vector3.UP.cross(d).normalized()          # the line's left (x left, z ahead)
	p += side * left
	var up := Vector3.UP
	if is_inside_tree():
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p - Vector3.UP * 6.0, TmCar.WORLD_MASK)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			p = hit["position"]
			up = hit["normal"]
	var z := (d - up * d.dot(up)).normalized()
	return Transform3D(Basis(up.cross(z), up, z), p)


## A world point dropped onto whatever is under it (the road, a pavement), or left where it is.
func _ground(p: Vector3) -> Vector3:
	if not is_inside_tree():
		return p
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.5, p - Vector3.UP * 8.0, TmCar.WORLD_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


func _add_car(c: Dictionary) -> void:
	var car := TmCarVisual.new()
	car.paint_colour = TmUi.CAR_COLOURS[clampi(int(c.get("colour", 0)), 0, TmUi.CAR_COLOURS.size() - 1)]
	car.model = String(c.get("model", "hyper"))
	car.ghost = bool(c.get("ghost", false))
	car.livery = int(c.get("livery", 0))
	var picks := String(c.get("tuning", "")).split(".", false)
	for k in mini(picks.size(), TmRoadCars.TUNING.size()):
		car.tuning[TmRoadCars.TUNING[k]] = int(picks[k])
	add_child(car)
	if bool(c.get("lights", false)):
		for side in [-1.0, 1.0]:
			var sl := SpotLight3D.new()
			sl.light_color = Color(1.0, 0.93, 0.82)
			sl.light_energy = 4.5
			sl.spot_range = 42.0
			sl.spot_angle = 27.0
			sl.spot_attenuation = 1.4
			sl.spot_angle_attenuation = 1.6
			sl.shadow_enabled = true
			sl.position = Vector3(0.62 * side, 0.15, 1.9)
			sl.rotation = Vector3(deg_to_rad(-4.0), PI, 0.0)    # spot lights shine along -z: turned to face ahead
			car.add_child(sl)
	_cars[String(c.get("id", "car%d" % _cars.size()))] = {"node": car, "spec": c}


func _add_light(l: Dictionary) -> void:
	var colour := Color(String(l.get("colour", "#ffffff")))
	var light: Light3D
	if String(l.get("kind", "omni")) == "spot":
		var s := SpotLight3D.new()
		s.spot_range = float(l.get("range", 20.0))
		s.spot_angle = float(l.get("angle", 30.0))
		light = s
	else:
		var o := OmniLight3D.new()
		o.omni_range = float(l.get("range", 10.0))
		light = o
	light.light_color = colour
	light.light_energy = float(l.get("energy", 3.0))
	light.shadow_enabled = bool(l.get("shadow", true))
	_props.add_child(light)
	var p := _vec(l.get("pos", [0, 3, 0]))
	light.global_position = _anchor * p
	if l.has("look"):
		light.look_at(_anchor * _vec(l["look"]), _anchor.basis.y)


## Rain round the camera: streaks falling through a box that follows it.
func _set_rain(amount: float) -> void:
	if amount <= 0.0:
		if _rain != null:
			_rain.emitting = false
			_rain.visible = false
		return
	if _rain == null:
		_rain = GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(18.0, 1.0, 18.0)
		pm.direction = Vector3(0.08, -1.0, 0.03)
		pm.spread = 2.0
		pm.initial_velocity_min = 14.0
		pm.initial_velocity_max = 18.0
		pm.gravity = Vector3(0.0, -4.0, 0.0)
		pm.particle_flag_align_y = true
		_rain.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.007, 0.42)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.78, 0.84, 1.0, 0.16)
		# each streak fades in and out along its length (no hard ends), and streaks nearer the lens
		# than a few metres fade away (no white bars across the picture)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 1))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 4
		gt.height = 64
		gt.fill_from = Vector2(0.5, 0.0)
		gt.fill_to = Vector2(0.5, 1.0)
		m.albedo_texture = gt
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		m.distance_fade_min_distance = 0.8
		m.distance_fade_max_distance = 5.0
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		q.material = m
		_rain.draw_pass_1 = q
		_rain.lifetime = 1.4
		_rain.preprocess = 1.4
		_rain.visibility_aabb = AABB(Vector3(-25, -30, -25), Vector3(50, 40, 50))
		_rain.local_coords = false
		add_child(_rain)
	_rain.amount = int(7000.0 * clampf(amount, 0.0, 1.0)) + 200
	_rain.emitting = true
	_rain.visible = true


func _pose(local: float) -> void:
	var s: Dictionary = shots[_shot]
	var dur := float(s["end"]) - float(s["start"])
	for id: String in _cars:
		var c: Dictionary = _cars[id]
		var spec: Dictionary = c["spec"]
		var v0 := float(spec.get("speed", 0.0))
		var a := float(spec.get("accel", 0.0))
		var tt := local
		if a < 0.0 and v0 > 0.0:
			tt = minf(local, v0 / -a)                # it stops
		var ahead := float(spec.get("ahead", 0.0)) + v0 * tt + 0.5 * a * tt * tt
		var at := float(s.get("at", data.get("at", 0.5)))
		var xf := _road_xf(at, float(s.get("left", 0.0)) + float(spec.get("left", 0.0)), float(s.get("ahead", 0.0)) + ahead)
		var yaw := deg_to_rad(float(spec.get("yaw", 0.0)))
		var basis := xf.basis * Basis(Vector3.UP, yaw)
		var lift := float(spec.get("lift", 0.0))
		var car := c["node"] as TmCarVisual
		car.global_transform = Transform3D(basis, xf * (Basis(Vector3.UP, yaw) * (TmCarVisual.VIS + Vector3(0.0, lift, 0.0))))
		car.ghost_speed = v0 + a * tt
		c["xf"] = xf
	for p in _people:
		p.pose(local)
	_pose_camera(s, local, dur)
	if _rain != null and camera != null:
		_rain.global_position = camera.global_position + Vector3(0.0, 8.0, 0.0)
	# the 2D layer
	var fade := 0.0
	var fi := float(s.get("fade_in", 0.0))
	var fo := float(s.get("fade_out", 0.0))
	if bool(s.get("black", false)):
		fade = 1.0
	elif fi > 0.0 and local < fi:
		fade = 1.0 - local / fi
	elif fo > 0.0 and local > dur - fo:
		fade = (local - (dur - fo)) / fo
	var card := {}
	if s.has("card"):
		card = (s["card"] as Dictionary).duplicate()
		card["alpha"] = clampf(minf(local / 0.8, (dur - local) / 0.8), 0.0, 1.0)
	if subtitles != null and subtitles.is_inside_tree():
		subtitles.show_state(line_at(t), fade, card, phone_at(t), skip_held / StorySubtitles.SKIP_HOLD,
			float(s.get("bars", data.get("bars", 1.0))))


func _pose_camera(s: Dictionary, local: float, dur: float) -> void:
	var cam: Dictionary = s.get("camera", {})
	var keys: Array = cam.get("keys", [])
	if keys.is_empty():
		keys = [{"u": 0.0, "pos": [4.0, 1.5, 7.0], "look": [0.0, 0.7, 0.0]}]
	var u := local / maxf(dur, 0.001)
	var times: Array[float] = []
	for k: Dictionary in keys:
		times.append(float(k["t"]) / maxf(dur, 0.001) if k.has("t") else float(k.get("u", 0.0)))
	var a: Dictionary = keys[0]
	var b: Dictionary = keys[0]
	var f := 0.0
	for i in keys.size():
		if u >= times[i]:
			a = keys[i]
			b = keys[mini(i + 1, keys.size() - 1)]
			var span := times[mini(i + 1, keys.size() - 1)] - times[i]
			f = clampf((u - times[i]) / span, 0.0, 1.0) if span > 0.0 else 0.0
	f = _ease(f, String(cam.get("ease", "inout")))
	var frame := _anchor
	if cam.has("follow") and _cars.has(String(cam["follow"])):
		frame = _cars[String(cam["follow"])].get("xf", _anchor)
	var pos := _vec(a.get("pos", [4, 1.5, 7])).lerp(_vec(b.get("pos", a.get("pos", [4, 1.5, 7]))), f)
	var look := _vec(a.get("look", [0, 0.7, 0])).lerp(_vec(b.get("look", a.get("look", [0, 0.7, 0]))), f)
	var shake := float(cam.get("shake", 0.0))
	if shake > 0.0:
		pos += Vector3(sin(t * 13.1) + sin(t * 7.3), sin(t * 11.7) * 0.6, sin(t * 5.9)) * shake * 0.5
	camera.global_position = frame * pos
	var target := frame * look
	if not camera.global_position.is_equal_approx(target):
		camera.look_at(target, frame.basis.y)
	var roll := lerpf(float(a.get("roll", 0.0)), float(b.get("roll", a.get("roll", 0.0))), f)
	if roll != 0.0:
		camera.rotate_object_local(Vector3.FORWARD, deg_to_rad(roll))
	camera.fov = lerpf(float(a.get("fov", 40.0)), float(b.get("fov", a.get("fov", 40.0))), f)
	var da: Array = a.get("dof", [])
	var db: Array = b.get("dof", da)
	_attrs.dof_blur_far_enabled = da.size() == 3
	if da.size() == 3:
		if db.size() != 3:
			db = da
		_attrs.dof_blur_far_distance = lerpf(float(da[0]), float(db[0]), f)
		_attrs.dof_blur_far_transition = lerpf(float(da[1]), float(db[1]), f)
		_attrs.dof_blur_amount = lerpf(float(da[2]), float(db[2]), f)


static func _ease(f: float, kind: String) -> float:
	match kind:
		"linear":
			return f
		"in":
			return f * f
		"out":
			return 1.0 - (1.0 - f) * (1.0 - f)
		_:
			return f * f * (3.0 - 2.0 * f)


static func _vec(v: Variant) -> Vector3:
	var a: Array = v if v is Array else [0, 0, 0]
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a.size() >= 3 else Vector3.ZERO
