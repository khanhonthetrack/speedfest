class_name StoryScene
extends Node3D
## Plays one cutscene from data (story/scenes/<id>.json; PLAN M20-3). A scene is a list of shots on
## our own tracks; everything in a shot is a function of the scene's time (seek(t)): the camera
## between its keys, cars standing or driving along the track's line, people playing their clips
## (StoryPerson), lights, rain, and the 2D layer (StorySubtitles: bars, subtitles, fades, title
## cards, a phone's texts). So a scene seeks to any frame (story/story_lab.tscn screenshots it), is
## skippable at any frame, never touches a race's simulation, and plays the same headless.
##
## Scene: {"id", "chapter", "title", "track" (default for its shots), "at" (default anchor), "grade",
##   "set": [flags the scene sets when it ends or is skipped], "shots": [shot, ...]}
## Shot: {"id", "if" (StoryState.holds: the shot plays only then), "track", "at" (fraction of the
##   track's racing line where the shot's anchor stands), "bare": true (also the scene's: the track
##   left out, its road, barriers, checkpoints and the neon along them; the place stays) or "set"
##   (the field's towers too, the shot on a level deck SET_DECK up: a set of props stands there),
##   "left", "ahead" (m off that point), "dur" (s; default: as long as its lines need, "lead"
##   before the first and "tail" after the last), "min" (s, default 2.5),
##   "camera": {"keys": [{"u" (0..1 of the shot) | "t" (s), "pos": [x, y, z] | a place in the
##     followed car ("driver_head", "mirror": StoryCabin.points), "look": [x, y, z] | a person's id (their face as posed: a close-up stays on the eyes; "look_by":
##     [x, y, z] off it),
##     "fov" (40), "roll" (deg), "dof": [far m, transition m, amount] (blur beyond), "dof_near": [near m,
##     transition m(, amount)] (blur before: a soft foreground; a key with it and one without pull
##     focus), "exposure" (the camera's, eased between keys: a flare whiting out), "eye_light": energy
##     (0.15-0.3: a soft light at the lens on the cast alone, the catchlight in a close-up's eyes)}], "ease": "inout" | "linear" | "in" | "out" (at every key), "path": "spline" (one smooth
##     move through every key, eased once over the shot: the keys' "u" are along it), "follow": a car's
##     id (its frame instead of the anchor's), "handheld": deg (a shoulder camera's slow wander of its
##     aim, the same at a given frame however it is reached), "shake": m (a jolt)},
##   "cars": [{"id", "model" (TmCarVisual.model: a road car's id, "hyper", "" the open-wheeler),
##     "livery", "paint" (a livery of its own: a PAINTS name or inline, over "livery"), "colour"
##     (TmUi.CAR_COLOURS index), "tuning": "spoiler.rims.glow.hood", "glow": 0..1 (its underglow
##     dimmed for the shot), "ghost",
##     "left", "ahead" (m from the anchor along the line), "lift", "yaw" (deg), "lights" (headlights:
##     true, or "high": high beams, a hard key 50 m on, glaring into a lens they point at),
##     "speed" (m/s along the line), "accel" (m/s^2; it stops when its speed reaches 0),
##     "cabin": true (StoryCabin: seats, dash, the satnav glowing, the body lined and its glass
##     clear, beaded by the shot's rain or the car's "rain_glass": for shots inside it; "windows_down": ["driver" | "passenger"], those front windows
##     down, or {"driver": [from s, to s]}, wound down then), "dome" (its courtesy light's energy: a passenger lit in the
##     mirror), "finish" (its paint's, over the livery's: TmCarVisual.FINISHES, "gloss" for a car
##     shown off), "from", "to" (s: on screen only then)}],
##   "people": [StoryPerson spec (a cast member's "who", its "speaker", "gaze", "reach" with
##     "reach_car": hands on a car of the shot), plus "car": a car's
##     id and "seat": "driver" | "passenger" | "rear" (seated in it, moving with it; or "pos" in its
##     road frame; anyone's own seat rests where the Mannequin's would, a seat under a low roof
##     lowered as far as its tallest sitter needs), "from", "to"], "lights": [{"kind": "omni" | "spot",
##     "pos", "look", "colour", "energy", "range", "angle", "shadow" (default on), "car": a car's id
##     (riding in it: pos and look in its road frame), "look_to" (a spot swept from "look" to it over the
##     shot: light moving over a car's paint); "kind": "softbox" ("size": [w, h], "energy": a bright panel
##     only reflections see)}], "probe": {"pos", "size", "distance", "box"} (a reflection probe for the
##     shot: the softboxes and the set in a car's paint, the city in the harbour), "rain": 0..1 (or keyed [[t, v], ...]: it stops),
##   "fade_in", "fade_out" (s), "black": true (no picture: a title card on black), "card": {"title",
##   "subtitle", "align": "left" (low in the left third, over the picture)},
##   the horror layer (docs/STORY.md, THE PASSENGER): "mirror": {camera keys like "camera", "follow",
##     "rect": [x, y, w, h] (fractions of the screen)} (a rear-view mirror: a second camera, its
##     picture flipped and framed), or {"glass": true, "follow": a car with a cabin} (the cabin's own
##     mirror glass shows what its driver sees in it, from any camera: StoryCabin.reflection), either
##     with "exposure" (its camera's: 1.6 on the glass, 2.4 framed), "glass": 0..1 (rain on the windscreen; keyed as "rain"), "flash": [[at, s], ...]
##     (white frames), "flicker": {"rate", "depth", "from", "to"} (the lights stutter, between those
##     s of the shot: a dome's few frames out as someone appears), "sounds": [{"at", "cue", "db",
##     "pitch"}] (StorySounds: sting, chime, thump, breath, gasp, ring, creak, sub), "ambience": a
##     looping cue or a list of them, each a name or {"cue", "db" (-6), "pitch", "to" (s: it stops
##     there)} (rain, heartbeat, drip, drone, train, engine, wipers: a loop stops at the first cut to a
##     shot that doesn't name it; the train dies away over 1.5 s),
##   "cctv": {"label", "clock": "03:12:04"} (a security camera's grey, grainy picture),
##   "grade": the film finish's look over the scene's own "grade" (StorySubtitles.GRADES: "film", every
##     scene's unless it says otherwise, "night", "dawn", "dream", "none"; or {"preset", "lift",
##     "shadows", "shadows_amount", "highlights", "highlights_amount", "saturation", "contrast",
##     "knee", "grain", "vignette", "halation", "streak", "fringe", "barrel"}),
##   "props": [StoryProps: containers (a stack, or a terminal's block: "containers"), a crane,
##     floodlight poles, high masts, toll booths, a railway viaduct ("viaduct", its "train")] (the scene's own
##     "props" for every shot without any: a yard that stays put round its shots; "props": [] for
##     none), "env": {"fog", "fog_colour", "fog_sky", "height_fog": [m, density], "exposure"} (the
##     night air over the map's own for that shot: haze on a city seen from the air),
##   "lines": [{"id", "speaker", "text", "kind": "say" (a subtitle) | "text" (a message arriving on
##     the phone: "mine" for the player's own) | "phone" (the thread's name: {"from"}), "hold" (s;
##     default from the text's length), "gap" (s before it), "at" (s into the shot, else after the
##     line before), "if" (StoryState.holds), "set": [flags], "voice": true (heard, not seen: off
##     screen, a radio, a phone call; no mouth moves)}]}
## Positions are in the shot's anchor frame: x left, y up, z ahead along the line (menu_art's).

signal finished(skipped: bool)

const DIR := "res://story/scenes"
const READ_CPS := 15.0                 ## subtitle reading speed (characters per second)
const FADE_OUT := ["train"]            ## loops that die away over a cut instead of stopping dead
const SET_DECK := 2.0                  ## m a set's deck stands over the map's ground (water below its edges)
## Liveries a story's cars wear (a car's "paint"): Lot 47 is "black" with grey camouflage "painted by
## hand" (Gus, c01_open), so deep black under soft airbrushed shapes and a hand-drawn pinstripe (red,
## as the calipers: paint, not a reflection).
const PAINTS := {
	"lot47": {"pattern": "brushed", "base": "#050506", "a": "#45484d", "b": "#25272a", "c": "#a3221a",
		"p": [0.5, 0.05, 0.0025, 4.0], "finish": "deep", "rim": "#1a1a1c", "caliper": "#8a1410", "lamps": "bright"},
	# the Mirror's coupe: Vesper's own pearl white, plain (not a police car, not Kit's twin)
	"white": {"pattern": "plain", "base": "#e9eaec", "c": "#cfd8e4", "finish": "pearl"},
}
const SOFTBOX_LAYER := 1 << 19         ## a light's "softbox": drawn for reflections (a shot's "probe"), never to the camera

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
var _eye_light: OmniLight3D            ## a camera key's "eye_light" (rides on the camera)
var _done := false
var _mirror_vp: SubViewport           ## the rear-view mirror's picture (a shot's "mirror")
var _mirror_cam: Camera3D
var _refl_vp: SubViewport             ## the city in the harbour (an env's "reflect"): the camera mirrored in the water
var _refl_cam: Camera3D
var _refl_y := 0.0                    ## the water's height (world) it is mirrored in
var _players := {}                     ## sound cue -> AudioStreamPlayer
var _fired := {}                       ## "shot:index" -> true: the shot's sounds already played
var _last_local := -1.0
var _set_on := false                   ## a shot on a set ("bare": "set"): on its deck, no ground looked for
var _props_key: Variant = null         ## what the props standing were built for (the scene's, at an anchor)
var _lights: Node3D                    ## the shot's own lights (not riding in a car)
var _sweeps: Array = []                ## [light, look from, look to, up]: spots swept across the shot ("look_to")


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
	camera.cull_mask = 0xFFFFF & ~SOFTBOX_LAYER    # softboxes are seen only in reflections
	_attrs = CameraAttributesPractical.new()
	camera.attributes = _attrs
	add_child(camera)
	_props = Node3D.new()
	_props.name = "Props"
	add_child(_props)
	_lights = Node3D.new()
	_lights.name = "Lights"
	add_child(_lights)
	subtitles = StorySubtitles.new()
	add_child(subtitles)
	if with_stage:
		_line_cabins()
	_measure_people()


## Lines every cabin car of the scene now (StoryCabin.fit_car: up to about 2.5 s a model, once, its
## windows' edges cut exactly), so a cut to a shot inside a car doesn't stall.
func _line_cabins() -> void:
	var models := {}
	for s: Dictionary in shots:
		for c: Dictionary in s.get("cars", []):
			if bool(c.get("cabin", false)):
				models[String(c.get("model", "hyper"))] = true
	for m: String in models:
		var car := TmCarVisual.new()
		car.model = m
		add_child(car)
		StoryCabin.fit_car(car)
		car.free()


## Measures the scene's people now (StoryCast.ground for a cast member standing, StoryCast.seated and
## mannequin_seated for anyone in a car: CPU skinning, a fraction of a second each, once per person and
## clip), so a cut to a shot with them doesn't stall.
func _measure_people() -> void:
	var clips := StoryPerson.clip_names()
	var done := {}
	for s: Dictionary in shots:
		var cars := {}
		for c: Dictionary in s.get("cars", []):
			cars[String(c.get("id", ""))] = true
		for p: Dictionary in s.get("people", []):
			var who := String(p.get("who", ""))
			var clip := StoryCast.take(who, String(p.get("clip", "Idle")) if String(p.get("clip", "Idle")) in clips else "Idle")
			var sits := cars.has(String(p.get("car", "")))
			if sits:
				StoryCast.mannequin_seated(self, clip)
			var key := "%s:%s:%s" % [who, clip, sits]
			if who == "" or not StoryCast.has(who) or done.has(key):
				continue
			done[key] = true
			var body := StoryCast.instance(who)
			add_child(body)
			if sits:
				StoryCast.seated(who, body, clip)
			else:
				StoryCast.ground(who, body, clip)
			body.free()


## Times every shot and line, the lines whose conditions fail left out (so a cold, warm or hot
## variant takes the time it needs).
func resolve() -> void:
	shots.clear()
	var at := 0.0
	for s: Dictionary in data.get("shots", []):
		if not state.holds(s.get("if", null)):
			continue                      # a shot for another decision or another tier
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
	if _shot >= 0:
		_set_ambience(ambience_specs(shots[_shot]))   # a shot entered before play (story_lab's held first frame)


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
		# a cut: the camera, cars and people drawn where the new shot puts them, not on their way there
		# (the project interpolates physics: without this, a cut's first frame showed the camera between
		# the two shots, out on the road behind a moving car)
		reset_physics_interpolation()
		return
	_pose(t - float(shots[i]["start"]))


# --- a shot ---------------------------------------------------------------------------------

func _enter(i: int) -> void:
	_shot = i
	var s: Dictionary = shots[i]
	var track := String(s.get("track", data.get("track", "")))
	var bare: Variant = s.get("bare", data.get("bare", false))
	if with_stage and not track.is_empty() and track != _stage_track:
		_build_stage(track)
	_set_bare(bare)
	for c: Dictionary in _cars.values():
		(c["node"] as Node).queue_free()
		if c.has("cabin"):
			(c["cabin"] as Node).queue_free()
	_cars.clear()
	for p in _people:
		p.queue_free()
	_people.clear()
	for n in _lights.get_children():
		n.queue_free()
	_sweeps.clear()
	_anchor = _road_xf(float(s.get("at", data.get("at", 0.5))), float(s.get("left", 0.0)), float(s.get("ahead", 0.0)))
	for c: Dictionary in s.get("cars", []):
		_add_car(c)
	for c: Dictionary in _cars.values():           # rain on a cabin car's glass: the shot's, or its own
		if c.has("cabin"):
			var cs: Dictionary = c["spec"]
			StoryCabin.set_wet(c["node"], float(cs.get("rain_glass", keyed_max(s.get("rain", data.get("rain", 0.0))))))
	var seated := {}                  # car -> seat -> [[person, model, its place], ...]
	for p: Dictionary in s.get("people", []):
		var person := StoryPerson.new()
		add_child(person)
		var spec := p
		var car_id := String(p.get("car", ""))
		if not car_id.is_empty() and _cars.has(car_id):
			# seated in a car: its road frame, no ground under it
			spec = p.duplicate()
			var model := String((_cars[car_id]["spec"] as Dictionary).get("model", "hyper"))
			if p.has("seat"):
				var pt: Vector3 = StoryCabin.points(model).get(String(p["seat"]), Vector3.ZERO)
				spec["pos"] = [pt.x, pt.y, pt.z]
			person.setup(spec, _anchor, Callable())
			person.in_car = car_id
			var q: Array = spec.get("pos", [0.0, 0.0, 0.0])
			var at := Vector3(float(q[0]), float(q[1]), float(q[2]))
			var seat := String(p.get("seat", StoryCabin.seat_at(model, at)))
			((seated.get_or_add(car_id, {}) as Dictionary).get_or_add(seat, []) as Array).append([person, model, at])
		else:
			person.setup(spec, _anchor, func(q: Vector3) -> Vector3: return _ground(_anchor * q))
		_people.append(person)
		if person.face != null:
			person.face.quiet = _quiet()
	# a crown within 5 cm of a low car's roof (taller than the Mannequin, or its head back as it
	# drives): down with the seat, as far as its tallest sitter needs, everyone on it with it
	for car_id: String in seated:
		for seat: String in seated[car_id]:
			var need := 0.0
			for e: Array in seated[car_id][seat]:
				need = maxf(need, -StoryCabin.headroom(String(e[1]), (e[2] as Vector3) + (e[0] as StoryPerson).crown))
			if need <= 0.0:
				continue
			if need > 0.1:
				push_warning("story: the %s's %s seat lowered %.2f m for its tallest (too tall for that car? a hat?)" % [
					seated[car_id][seat][0][1], seat, need])
			for e: Array in seated[car_id][seat]:
				(e[0] as StoryPerson).sink(need)
			if _cars[car_id].has("cabin"):
				(_cars[car_id]["cabin"] as StoryCabin).lower(seat, need)
	for l: Dictionary in s.get("lights", []):
		_add_light(l)
	if s.has("passing") and _cars.has(String((s["passing"] as Dictionary).get("car", ""))):
		_add_passing(s["passing"])
	if s.has("probe"):
		_add_probe(s["probe"])
	# the scene's own props (a yard, a docks set) stay standing over a cut to a shot that keeps them on
	# the same spot: no rebuild, no stall
	var key: Variant = null if s.has("props") else [_anchor, _stage_track, _set_on]
	if key == null or key != _props_key:
		for n in _props.get_children():
			n.queue_free()
		StoryProps.build(_props, s.get("props", data.get("props", [])), _anchor)
	_props_key = key
	_set_rain(keyed_max(s.get("rain", data.get("rain", 0.0))))
	var e: Dictionary = s.get("env", data.get("env", {}))
	_set_env(e)
	_set_sky(keyed_max(s.get("rain", data.get("rain", 0.0))), e.get("sky", {}))
	_set_reflect(float(e.get("reflect", 0.0)))
	if subtitles != null:
		subtitles.set_grade(StorySubtitles.grade_of(data.get("grade"), s.get("grade")))
	_set_mirror(s)
	_set_ambience(ambience_specs(s))


## The moments no one blinks: round every cut (no shot opens or closes on shut eyes).
func _quiet() -> Array:
	var out := []
	for sh: Dictionary in shots:
		var c := float(sh.get("start", 0.0))
		out.append([c - 0.12, c + 0.4])
	return out


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
	var city := _stage.get_node_or_null("City")
	if city != null:
		city.child_entered_tree.connect(func(_n: Node) -> void: _recapture.call_deferred())


## The shot's reflection probes captured again: the city round the stage is built on a worker thread
## and lands a moment after it (TmSkyline.build_async), so a probe captured before then had an empty
## horizon in it (the harbour black under the city across it).
func _recapture() -> void:
	for n in _lights.get_children():
		if n is ReflectionProbe:
			(n as ReflectionProbe).position.y += 0.001          # moved: captured once more


## "env": the stage's night air for a shot, over the map's own (TmStadiumEnv): "fog" (its density),
## "fog_colour", "fog_sky" (how far it veils the sky: a horizon lost in the city's glow), "height_fog":
## [height m, density] (low roofs sunk in haze), "vol_fog" (the volumetric fog's density, where the
## quality has it: the towers' lights bloom in wet air), "city_lit" (the share of the city's rooms lit,
## over the night's 0.3), "city_led" (its storefront lines and neon avenues, 0..1), "city_glow" (how
## bright its lit rooms are, 1: an aerial's 2-3, lit windows as a lens sees them), "exposure" (the
## camera's), "sky" (_set_sky), "reflect" (_set_reflect: the city in the harbour), "ssr": false (no
## screen-space reflections: a long lens's puddles without their stair-steps).
## A shot without a key has the map's own back.
func _set_env(e: Dictionary) -> void:
	var env := _environment()
	if env != null:
		if not env.has_meta("story_base"):
			env.set_meta("story_base", {"fog": env.fog_density, "fog_colour": env.fog_light_color,
				"fog_sky": env.fog_sky_affect, "height": env.fog_height, "height_density": env.fog_height_density,
				"vol_fog": env.volumetric_fog_density, "ssr": env.ssr_enabled})
		var base: Dictionary = env.get_meta("story_base")
		var hf: Array = e.get("height_fog", [base["height"], base["height_density"]])
		env.fog_density = float(e.get("fog", base["fog"]))
		env.fog_light_color = Color(String(e["fog_colour"])) if e.has("fog_colour") else base["fog_colour"]
		env.fog_sky_affect = float(e.get("fog_sky", base["fog_sky"]))
		env.fog_height = float(hf[0])
		env.fog_height_density = float(hf[1])
		if env.volumetric_fog_enabled:
			env.volumetric_fog_density = float(e.get("vol_fog", base["vol_fog"]))
		env.ssr_enabled = bool(base["ssr"]) and bool(e.get("ssr", true))
	if e.has("city_lit"):             # over _set_bare's: the share of the city's rooms lit (dawn: few)
		RenderingServer.global_shader_parameter_set(&"tm_city_lit", float(e["city_lit"]))
	if e.has("city_led"):
		RenderingServer.global_shader_parameter_set(&"tm_city_led", float(e["city_led"]))
	RenderingServer.global_shader_parameter_set(&"tm_city_glow", float(e.get("city_glow", 1.0)))
	_attrs.exposure_multiplier = float(e.get("exposure", 1.0))


## The night sky over a shot: in rain no stars, a low overcast lit from under by the city (warm and
## dim); "sky": {"stars", "cloud_cover", "cloud_lo", "cloud_hi", "zenith" and "horizon" (colours: the
## gradient between them, a first light low in the east)} over that. A dry shot without the key has
## the map's own sky back.
func _set_sky(rain: float, k: Dictionary) -> void:
	var env := _environment()
	if env == null or env.sky == null or not env.sky.sky_material is ShaderMaterial:
		return
	var m := env.sky.sky_material as ShaderMaterial
	var keys := ["stars", "cloud_cover", "cloud_lo", "cloud_hi", "stops"]
	if not m.has_meta("story_base"):
		var base := {}
		for key: String in keys:
			var v: Variant = m.get_shader_parameter(key)    # (null where the material keeps the shader's)
			base[key] = v if v != null else RenderingServer.shader_get_parameter_default(m.shader.get_rid(), key)
		m.set_meta("story_base", base)
	var want: Dictionary = (m.get_meta("story_base") as Dictionary).duplicate()
	if rain > 0.0:
		want.merge({"stars": 0.0, "cloud_cover": 0.08, "cloud_lo": "#0c0910", "cloud_hi": "#3c2632"}, true)
	want.merge(k, true)
	if k.has("zenith") and k.has("horizon"):
		# the sky's gradient from the zenith down to the horizon, the horizon's colour hugging it (dawn)
		var top := Color(String(k["zenith"])).srgb_to_linear()
		var low := Color(String(k["horizon"])).srgb_to_linear()
		var stops := PackedVector3Array()
		for i in 17:
			var c := top.lerp(low, pow(i / 16.0, 2.6))
			stops.append(Vector3(c.r, c.g, c.b))
		want["stops"] = stops
	for key: String in keys:
		var v: Variant = want[key]
		if v is String:
			var c := Color(String(v)).srgb_to_linear()
			v = Vector3(c.r, c.g, c.b)
		elif v is int:
			v = float(v)
		if v != null:
			m.set_shader_parameter(key, v)


func _environment() -> Environment:
	var we: WorldEnvironment = _stage.find_child("Environment", true, false) as WorldEnvironment if _stage != null else null
	return we.environment if we != null else null


func _exit_tree() -> void:
	# a set's city back to the map's (the globals outlive the scene)
	RenderingServer.global_shader_parameter_set(&"tm_city_led", 1.0)
	RenderingServer.global_shader_parameter_set(&"tm_city_lit", 0.3)
	RenderingServer.global_shader_parameter_set(&"tm_city_glow", 1.0)


## "bare": the place without its track (a yard on a race map): the road, barriers, checkpoints and
## the neon along them hidden and their collision off, the ground, the city and the light left; the
## track's line still places the shot (its anchor drops onto the ground). A switch, not a rebuild,
## so a cut between a bare shot and one on the track never stalls. "bare": "set" also hides the
## towers on the field (a City map's) and stands the shot on a deck SET_DECK over the map's ground,
## level (no ground under it is looked for): a set built of props (StoryProps "quay": the deck, its
## edges, the water below them) stands there instead.
func _set_bare(bare: Variant) -> void:
	_set_on = bare is String and String(bare) == "set"
	# the city round a set: no neon avenues or storefront LED lines (a dark port town), more rooms lit
	RenderingServer.global_shader_parameter_set(&"tm_city_led", 0.0 if _set_on else 1.0)
	RenderingServer.global_shader_parameter_set(&"tm_city_lit", 0.42 if _set_on else 0.3)
	if _stage == null:
		return
	var off := _set_on or (bare is bool and bool(bare))
	for n in _stage.find_children("*", "", true, false):
		if String(n.name) == "FieldCity":
			(n as Node3D).visible = not _set_on
			for body in n.find_children("*", "CollisionObject3D", true, false):
				var fc := body as CollisionObject3D
				if not fc.has_meta("layer"):
					fc.set_meta("layer", fc.collision_layer)
				fc.collision_layer = 0 if _set_on else int(fc.get_meta("layer"))
			continue
		if not String(n.name) in ["Blocks", "RoadDecals", "NeonLights"]:
			continue
		(n as Node3D).visible = not off
		for body in n.find_children("*", "CollisionObject3D", true, false):
			var co := body as CollisionObject3D
			if not co.has_meta("layer"):
				co.set_meta("layer", co.collision_layer)
			co.collision_layer = 0 if off else int(co.get_meta("layer"))


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
	if _set_on:
		p.y = TmMapBuilder.GROUND_Y + SET_DECK         # a set's deck: level, whatever is under it
	elif is_inside_tree():
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p - Vector3.UP * 6.0, TmCar.WORLD_MASK)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			p = hit["position"]
			up = hit["normal"]
	var z := (d - up * d.dot(up)).normalized()
	return Transform3D(Basis(up.cross(z), up, z), p)


## A world point dropped onto whatever is under it (the road, a pavement), or left where it is.
func _ground(p: Vector3) -> Vector3:
	if not is_inside_tree() or _set_on:
		return p
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.5, p - Vector3.UP * 8.0, TmCar.WORLD_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


## A car's livery from a scene's "paint" (PAINTS' or inline: colours as "#rrggbb", "p" as [x, y, z, w]).
static func _paint(d: Dictionary) -> Dictionary:
	var out := {}
	for k: String in d:
		var v: Variant = d[k]
		if k == "p" and v is Array:
			var a: Array = v
			out[k] = Vector4(float(a[0]), float(a[1]) if a.size() > 1 else 0.0, float(a[2]) if a.size() > 2 else 0.0, float(a[3]) if a.size() > 3 else 0.0)
		elif v is String and (v as String).begins_with("#"):
			out[k] = Color(v as String)
		else:
			out[k] = v
	return out


func _add_car(c: Dictionary) -> void:
	var car := TmCarVisual.new()
	car.paint_colour = TmUi.CAR_COLOURS[clampi(int(c.get("colour", 0)), 0, TmUi.CAR_COLOURS.size() - 1)]
	car.model = String(c.get("model", "hyper"))
	car.ghost = bool(c.get("ghost", false))
	car.livery = int(c.get("livery", 0))
	var own: Variant = PAINTS.get(c.get("paint", ""), c.get("paint", {}))
	if own is Dictionary and not (own as Dictionary).is_empty():
		car.livery_spec = _paint(own)
	var picks := String(c.get("tuning", "")).split(".", false)
	for k in mini(picks.size(), TmRoadCars.TUNING.size()):
		car.tuning[TmRoadCars.TUNING[k]] = int(picks[k])
	add_child(car)
	var paint := car._mats.get("road_paint", null) as ShaderMaterial    # each car's own (TmCarVisual._road_mat)
	if paint != null and TmCarVisual.FINISHES.has(String(c.get("finish", ""))) and not c.has("paint"):    # (a paint's own finish wins)
		paint.set_shader_parameter("finish", TmCarVisual.FINISHES[String(c["finish"])])
		paint.set_shader_parameter("flakes", 1.0 if String(c["finish"]) in ["metallic", "pearl"] else 0.0)
	if c.has("plate"):
		_letter_plates(car, String(c["plate"]))
	if c.has("glow") and car.find_child("Underglow", false, false) is TmUnderglow:
		(car.find_child("Underglow", false, false) as TmUnderglow).set_strength(float(c["glow"]))
	var lamps: Variant = c.get("lights", false)
	if lamps is String or (lamps is bool and bool(lamps)):
		var high := lamps is String and String(lamps) == "high"
		for side in [-1.0, 1.0]:
			var sl := SpotLight3D.new()
			sl.light_color = Color(1.0, 0.93, 0.82) if not high else Color(0.93, 0.96, 1.0)
			sl.light_energy = 14.0 if high else 4.5
			sl.spot_range = 110.0 if high else 42.0
			sl.spot_angle = 16.0 if high else 27.0
			sl.spot_attenuation = 0.8 if high else 1.4              # high beams carry: a hard key 50 m on
			sl.spot_angle_attenuation = 1.0 if high else 1.6
			sl.shadow_enabled = true
			sl.position = Vector3(0.62 * side, 0.15, 1.9)
			sl.rotation = Vector3(deg_to_rad(-1.0 if high else -4.0), PI, 0.0)   # spot lights shine along -z: turned to face ahead
			car.add_child(sl)
			var glow := MeshInstance3D.new()
			glow.name = "LampGlow"
			glow.mesh = QuadMesh.new()
			glow.material_override = _lamp_glow(high)
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			glow.extra_cull_margin = 4.0
			glow.position = Vector3(0.62 * side, 0.15, 2.25)
			car.add_child(glow)
	var entry := {"node": car, "spec": c}
	if bool(c.get("cabin", false)):
		StoryCabin.fit_car(car)
		var down: Variant = c.get("windows_down", {})
		if down is Array:                              # down already
			var all := {}
			for side: String in down:
				all[side] = true
			down = all
		StoryCabin.open_windows(car, down)
		var pins := int(c.get("pins", state.facts() if state != null else 0))
		var dome: Variant = c.get("dome", 0.0)
		var cabin := StoryCabin.make(car.model, pins, maxf(keyed_max(dome), 0.001) if dome is Array else float(dome))
		if dome is Array and cabin.get_node_or_null("Dome") != null:
			cabin.get_node("Dome").set_meta("keys", dome)      # the dome coming on at a moment of the shot
		add_child(cabin)
		entry["cabin"] = cabin
	_cars[String(c.get("id", "car%d" % _cars.size()))] = entry


## "passing": street lamps going by a car's windows, {"car", "colour", "energy", "range", "every" (s
## between lamps), "phase" (s), "from", "to" (the lamp's way past, in the car's road frame), "until"
## (s: no more lamps after), "shadow"}: one light riding the car, carried from "from" to "to" every
## "every" s, brightest halfway (the pillars' shadows sweep over the faces). A function of the shot's
## time, so a frame is the same however it is reached.
func _add_passing(ps: Dictionary) -> void:
	var c: Dictionary = _cars[String(ps["car"])]
	var light := OmniLight3D.new()
	light.name = "Passing"
	light.light_color = Color(String(ps.get("colour", "#ff9d3c")))
	light.omni_range = float(ps.get("range", 4.0))
	light.shadow_enabled = bool(ps.get("shadow", true))
	var host: Node3D = c.get("cabin", c["node"])
	host.add_child(light)
	var off := Vector3.ZERO if c.has("cabin") else TmCarVisual.VIS + Vector3(0.0, float((c["spec"] as Dictionary).get("lift", 0.0)), 0.0)
	light.set_meta("passing", ps)
	light.set_meta("off", off)
	light.light_energy = float(ps.get("energy", 2.5))


## A passing lamp at `local`: placed along its way, its energy now (0 between lamps and after "until").
func _passing_at(l: Light3D, local: float) -> float:
	var ps: Dictionary = l.get_meta("passing")
	var every := maxf(float(ps.get("every", 1.3)), 0.05)
	var f := fposmod((local + float(ps.get("phase", 0.0))) / every, 1.0)
	l.position = _vec(ps.get("from", [1.9, 2.6, 6.0])).lerp(_vec(ps.get("to", [1.9, 2.6, -6.0])), f) - (l.get_meta("off") as Vector3)
	if ps.has("until") and local - f * every + every * 0.5 > float(ps["until"]):
		return 0.0                     # (this lamp's middle comes after "until": the lamps have ended)
	return float(ps.get("energy", 2.5)) * pow(sin(PI * f), 2.0)


## A lit headlamp's glare as the lens sees it: a hot core, a soft halo and a thin horizontal streak,
## facing the camera, as bright as the lamp points at it (nothing from the side or behind); the
## bloom does the rest. High beams: bigger and far brighter (a car on Kit's bumper blinds her).
## A car's number plates lettered (a story car's "plate"): its text in black across each plate the
## body carries (its "road_plate" surfaces, the front's and the back's, found in its own meshes), the
## plates an aged off-white rather than a blank glowing panel.
func _letter_plates(car: TmCarVisual, text: String) -> void:
	var pm := car._mats.get("road_plate", null) as StandardMaterial3D
	if pm == null:
		return
	pm.albedo_color = Color(0.6, 0.6, 0.57)
	var ends := {1: AABB(), -1: AABB()}
	var seen := {1: false, -1: false}
	for mi: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var to_car := car.global_transform.affine_inverse() * mi.global_transform
		for k in mi.mesh.get_surface_count():
			if mi.get_active_material(k) != pm:
				continue
			for v: Vector3 in mi.mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX]:
				var p := to_car * v
				var e := 1 if p.z > 0.0 else -1
				ends[e] = AABB(p, Vector3.ZERO) if not seen[e] else (ends[e] as AABB).expand(p)
				seen[e] = true
	for e: int in [1, -1]:
		var box: AABB = ends[e]
		if not seen[e] or box.size.x < 0.1:
			continue
		var l := Label3D.new()
		l.text = text
		l.font_size = 48
		l.pixel_size = box.size.y * 0.55 / 48.0
		l.modulate = Color(0.04, 0.04, 0.045)
		l.outline_size = 0
		l.shaded = true
		l.double_sided = false
		l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		l.position = box.get_center() + Vector3(0.0, 0.0, (box.size.z * 0.5 + 0.004) * e)
		l.rotation.y = 0.0 if e > 0 else PI          # (a Label3D reads from +z)
		car.add_child(l)


static func _lamp_glow(high: bool) -> ShaderMaterial:
	var key := "high" if high else "low"
	if not _glows.has(key):
		if _glow_shader == null:
			_glow_shader = Shader.new()
			_glow_shader.code = LAMP_GLOW
		var m := ShaderMaterial.new()
		m.shader = _glow_shader
		m.set_shader_parameter("energy", 9.0 if high else 2.5)
		m.set_shader_parameter("size", 0.75 if high else 0.35)
		_glows[key] = m
	return _glows[key]


static var _glows := {}
static var _glow_shader: Shader
const LAMP_GLOW := """shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, ambient_light_disabled;
uniform vec3 colour : source_color = vec3(1.0, 0.96, 0.9);
uniform float energy = 2.5;
uniform float size = 0.35;
varying float facing;
void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - centre;
	float d = max(length(to_cam), 0.01);
	facing = max(dot(to_cam / d, normalize(MODEL_MATRIX[2].xyz)), 0.0);   // the car's nose is its +z
	float s = size * (0.35 + 0.65 * facing) * max(1.0, d * 0.02);         // a few pixels however far
	vec3 w = centre + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * s * 2.0 + to_cam / d * 0.3;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r2 = dot(q, q);
	float glare = exp(-r2 * 22.0) + exp(-r2 * 4.0) * 0.22 + exp(-abs(q.y) * 45.0) * exp(-abs(q.x) * 2.2) * 0.3;
	ALBEDO = vec3(0.0);
	ROUGHNESS = 1.0;
	EMISSION = colour * energy * glare * facing * facing * facing;
}
"""


func _add_light(l: Dictionary) -> void:
	var colour := Color(String(l.get("colour", "#ffffff")))
	if String(l.get("kind", "omni")) == "softbox":
		_add_softbox(l, colour)
		return
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
	light.light_energy = keyed_max(l.get("energy", 3.0))
	if l.get("energy") is Array:
		light.set_meta("keys", l["energy"])          # (_flicker eases it over the shot)
	light.shadow_enabled = bool(l.get("shadow", true))
	var p := _vec(l.get("pos", [0, 3, 0]))
	var car_id := String(l.get("car", ""))
	if _cars.has(car_id):
		# riding in the car (its road frame), so it stays with it as it drives; without a cabin it rides
		# on the car body's node, which stands at VIS (+ lift) over the road frame
		var c: Dictionary = _cars[car_id]
		var host: Node3D = c.get("cabin", c["node"])
		var off := Vector3.ZERO if c.has("cabin") else TmCarVisual.VIS + Vector3(0.0, float((c["spec"] as Dictionary).get("lift", 0.0)), 0.0)
		host.add_child(light)
		light.position = p - off
		if l.has("look"):
			light.look_at(host.global_transform * (_vec(l["look"]) - off), host.global_basis.y)
		return
	_lights.add_child(light)
	light.global_position = _anchor * p
	if l.has("look"):
		light.look_at(_anchor * _vec(l["look"]), _anchor.basis.y)
		if l.has("look_to"):
			_sweeps.append([light, _anchor * _vec(l["look"]), _anchor * _vec(l["look_to"]), _anchor.basis.y])


## A photographer's softbox for a car's paint: a bright panel ("size": [w, h] m, facing "look") on a
## layer only a reflection probe sees (the shot's "probe"), so long highlights run down the bodywork
## and nothing shows in the picture; it lights nothing itself.
func _add_softbox(l: Dictionary, colour: Color) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	var sz: Array = l.get("size", [4.0, 1.0])
	q.size = Vector2(float(sz[0]), float(sz[1]))
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour * float(l.get("energy", 3.0))
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.layers = SOFTBOX_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_lights.add_child(mi)
	mi.global_position = _anchor * _vec(l.get("pos", [0, 3, 0]))
	if l.has("look"):
		var to := _anchor * _vec(l["look"])
		var up := _anchor.basis.y if absf((to - mi.global_position).normalized().dot(_anchor.basis.y)) < 0.98 else _anchor.basis.z
		mi.look_at(to, up)
		mi.rotate_object_local(Vector3.UP, PI)          # a quad faces +z; look_at points -z at the car


## A shot's "probe": {"pos", "size"} (the anchor frame): a reflection probe captured once, so a car's
## paint shows the yard and the softboxes round it (the night's own reflections are SSR's and the sky's).
## "box": false for a far one (no box projection: the city across the harbour in its water, at
## "distance" up to the downtown's 2.5 km).
func _add_probe(pr: Dictionary) -> void:
	var probe := ReflectionProbe.new()
	var sz: Array = pr.get("size", [24.0, 10.0, 24.0])
	probe.size = Vector3(float(sz[0]), float(sz[1]), float(sz[2]))
	probe.box_projection = bool(pr.get("box", true))
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.max_distance = float(pr.get("distance", 200.0))
	probe.intensity = float(pr.get("intensity", 1.0))
	probe.cull_mask = 0xFFFFF
	_lights.add_child(probe)
	probe.global_transform = Transform3D(_anchor.basis, _anchor * _vec(pr.get("pos", [0, 2, 0])))


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
		pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT     # (a cabin's RainShield)
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
		car.visible = _on_screen(spec, local)
		c["xf"] = Transform3D(basis, xf.origin)
		StoryCabin.wind(car, local)
		if c.has("cabin"):
			(c["cabin"] as Node3D).global_transform = c["xf"]
	for p in _people:
		if not p.in_car.is_empty() and _cars.has(p.in_car):
			p.rebase(_cars[p.in_car]["xf"])
		var rc := String(p.spec.get("reach_car", ""))
		p.reach_frame = _cars[rc]["xf"] if _cars.has(rc) else null
		p.pose(local)
		p.visible = _on_screen(p.spec, local)
	StoryProps.pose(_props, local, t)
	for sw: Array in _sweeps:
		(sw[0] as Light3D).look_at((sw[1] as Vector3).lerp(sw[2], _ease(clampf(local / maxf(dur, 0.001), 0.0, 1.0), "inout")), sw[3])
	_aim(s.get("camera", {}), camera, _attrs, local, dur)
	_aim_reflection()
	if _mirror_cam != null and s.has("mirror"):
		if _glass() != null:
			_aim_glass(_glass())
		else:
			_aim(s["mirror"], _mirror_cam, null, local, dur)
	# the faces after the people and the cameras: a look at the camera is at this frame's camera
	for p in _people:
		if p.face != null and p.visible:
			p.face.pose(t, _lines_of(p, s), _gaze_of(p, s))
	_flicker(s, local)
	if _rain != null:                  # keyed rain: fewer drops (the ones falling finish their fall)
		var rk: Variant = s.get("rain", data.get("rain", 0.0))
		_rain.amount_ratio = clampf(keyed(rk, local) / maxf(keyed_max(rk), 0.001), 0.0, 1.0) if rk is Array else 1.0
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
		subtitles.set_glass(keyed(s.get("glass", 0.0), local), t)
		subtitles.set_cctv(s.get("cctv", {}), local, t)
		var flash := 0.0
		for f: Array in s.get("flash", []):
			var d := local - float(f[0])
			if d >= 0.0 and d < float(f[1]):
				flash = maxf(flash, 1.0 - d / float(f[1]))
		subtitles.set_flash(flash)
	if playing:
		_sounds(s, local)
		for a: Dictionary in ambience_specs(s):         # a loop that stops partway into its shot ("to")
			var p: AudioStreamPlayer = _players.get(String(a["cue"]), null)
			if a.has("to") and local >= float(a["to"]) and p != null and p.playing:
				p.stop()
	_last_local = local


## A person's own spoken lines in the shot (subtitles it says on screen: not texts, not a voice off).
func _lines_of(p: StoryPerson, s: Dictionary) -> Array:
	var out := []
	for l: Dictionary in s.get("lines", []):
		if String(l.get("kind", "say")) == "say" and not bool(l.get("voice", false)) and p.speaks(String(l.get("speaker", ""))):
			out.append(l)
	return out


## Where a person looks: its "gaze" (the camera, the mirror, or a person), else whoever else is speaking on screen
## (a voice off draws no eyes: it is heard, not seen).
func _gaze_of(p: StoryPerson, s: Dictionary) -> Variant:
	var g := String(p.spec.get("gaze", ""))
	var local := t - float(s.get("start", 0.0))
	for lk: Array in p.spec.get("looks", []):
		if local >= float(lk[0]) and local < float(lk[1]):
			g = String(lk[2])
	if g == "camera" and camera != null:
		return camera.global_position
	if g == "mirror" and _glass() != null:
		return _glass().mirror_glass.global_position
	if g == "mirror" and not s.has("mirror") and _cars.has(p.in_car) and _cars[p.in_car].has("cabin"):
		return (_cars[p.in_car]["cabin"] as StoryCabin).mirror_glass.global_position
	if g == "mirror" and _mirror_cam != null and s.has("mirror"):
		return _mirror_cam.global_position
	if g == "ahead":
		return null
	if g == "rear" and _cars.has(p.in_car) and _cars[p.in_car].has("cabin"):
		# the back seat, where a passenger's face would be (a look back over the shoulder)
		var cab := _cars[p.in_car]["cabin"] as StoryCabin
		return cab.global_transform * (cab.rear_seat + Vector3(0.0, StoryCabin.CROWN.x - 0.2, 0.0))
	if g != "":
		for q in _people:
			if String(q.spec.get("id", "")) == g and q != p:
				return q.eyes_point()
	var l := line_at(t)
	if not l.is_empty() and String(l.get("kind", "say")) == "say" and not bool(l.get("voice", false)) \
			and not p.speaks(String(l.get("speaker", ""))):
		for q in _people:
			if q != p and q.visible and q.speaks(String(l.get("speaker", ""))):
				return q.eyes_point()
	return null


## Puts a camera where a shot's camera (or mirror) keys say at this moment: between two keys, eased
## at each ("ease"), or along one smooth path through all of them eased once over the shot ("path":
## "spline"); a hand-held camera's drift on top ("handheld"); the depth of field's far and near blur.
## A camera key's "look" in its frame: a point, or a person's id (that person's face as posed now: a
## close-up that stays on the eyes however the head turns), "look_by": [x, y, z] off it (in the frame:
## the face put high in the picture).
func _look_at(key: Dictionary, frame: Transform3D) -> Vector3:
	var v: Variant = key.get("look", [0, 0.7, 0])
	var by := _vec(key.get("look_by", [0, 0, 0]))
	if v is String:
		for p in _people:
			if String(p.spec.get("id", "")) == String(v):
				return frame.affine_inverse() * p.face_point() + by
		push_warning("story: no one called %s to look at" % v)
		return Vector3(0.0, 0.7, 0.0)
	return _vec(v) + by


func _aim(cam: Dictionary, which: Camera3D, attrs: CameraAttributesPractical, local: float, dur: float) -> void:
	var keys: Array = cam.get("keys", [])
	if keys.is_empty() and cam.has("pos"):
		keys = [cam]
	if keys.is_empty():
		keys = [{"u": 0.0, "pos": [4.0, 1.5, 7.0], "look": [0.0, 0.7, 0.0]}]
	var u := clampf(local / maxf(dur, 0.001), 0.0, 1.0)
	var spline := String(cam.get("path", "")) == "spline"
	if spline:
		u = _ease(u, String(cam.get("ease", "inout")))   # one ease over the whole move; the keys are along it
	var times: Array[float] = []
	for k: Dictionary in keys:
		times.append(float(k["t"]) / maxf(dur, 0.001) if k.has("t") else float(k.get("u", 0.0)))
	var i0 := 0
	var f := 0.0
	for i in keys.size():
		if u >= times[i]:
			i0 = i
			var span := times[mini(i + 1, keys.size() - 1)] - times[i]
			f = clampf((u - times[i]) / span, 0.0, 1.0) if span > 0.0 else 0.0
	var i1 := mini(i0 + 1, keys.size() - 1)
	var a: Dictionary = keys[i0]
	var b: Dictionary = keys[i1]
	if not spline:
		f = _ease(f, String(cam.get("ease", "inout")))
	var frame := _anchor
	var model := ""
	if cam.has("follow") and _cars.has(String(cam["follow"])):
		frame = _cars[String(cam["follow"])].get("xf", _anchor)
		model = String((_cars[String(cam["follow"])]["spec"] as Dictionary).get("model", "hyper"))
	var pos: Vector3
	var look: Vector3
	if spline and keys.size() > 2:
		var kp := func(i: int) -> Vector3: return _at((keys[clampi(i, 0, keys.size() - 1)] as Dictionary).get("pos", [4, 1.5, 7]), model)
		var kl := func(i: int) -> Vector3: return _look_at(keys[clampi(i, 0, keys.size() - 1)], frame)
		pos = _catmull(kp.call(i0 - 1), kp.call(i0), kp.call(i1), kp.call(i1 + 1), f)
		look = _catmull(kl.call(i0 - 1), kl.call(i0), kl.call(i1), kl.call(i1 + 1), f)
	else:
		pos = _at(a.get("pos", [4, 1.5, 7]), model).lerp(_at(b.get("pos", a.get("pos", [4, 1.5, 7])), model), f)
		look = _look_at(a, frame).lerp(_look_at(b if b.has("look") else a, frame), f)
	var shake := float(cam.get("shake", 0.0))
	if shake > 0.0:
		pos += Vector3(sin(t * 13.1) + sin(t * 7.3), sin(t * 11.7) * 0.6, sin(t * 5.9)) * shake * 0.5
	which.global_position = frame * pos
	var target := frame * look
	if not which.global_position.is_equal_approx(target):
		which.look_at(target, frame.basis.y)
	var roll := lerpf(float(a.get("roll", 0.0)), float(b.get("roll", a.get("roll", 0.0))), f)
	if roll != 0.0:
		which.rotate_object_local(Vector3.FORWARD, deg_to_rad(roll))
	var held := float(cam.get("handheld", 0.0))
	if held > 0.0:
		# a camera on a shoulder: a slow wander of its aim (0.5-1.5 Hz), a function of the scene's time
		# and the shot, so a frame is the same however it is reached
		var seed := float(hash(String(shots[_shot].get("id", ""))) % 997) if _shot >= 0 and _shot < shots.size() else 0.0
		var d := handheld(t, seed) * held
		which.rotate_object_local(Vector3.UP, deg_to_rad(d.x))
		which.rotate_object_local(Vector3.RIGHT, deg_to_rad(d.y))
		which.rotate_object_local(Vector3.FORWARD, deg_to_rad(d.z))
	which.fov = lerpf(float(a.get("fov", 40.0)), float(b.get("fov", a.get("fov", 40.0))), f)
	if attrs == null:
		return
	# "eye_light": a small soft light at the lens that lights the cast alone, for the catchlight in a
	# close-up's eyes and a touch on the face (the film's eye light)
	var eye := lerpf(float(a.get("eye_light", 0.0)), float(b.get("eye_light", a.get("eye_light", 0.0))), f)
	if eye > 0.0 and _eye_light == null:
		_eye_light = OmniLight3D.new()
		_eye_light.light_color = Color(1.0, 0.97, 0.92)
		_eye_light.light_specular = 2.0
		_eye_light.shadow_enabled = false
		_eye_light.light_cull_mask = StoryPerson.CAST_LAYER
		_eye_light.position = Vector3(0.0, -0.03, 0.0)
		which.add_child(_eye_light)
	if _eye_light != null:
		_eye_light.visible = eye > 0.0
		_eye_light.light_energy = eye
		_eye_light.omni_range = which.global_position.distance_to(target) + 0.6
	if a.has("exposure") or b.has("exposure"):        # a flare of light: the exposure keyed (else the shot's "env")
		attrs.exposure_multiplier = lerpf(float(a.get("exposure", b.get("exposure", 1.0))), float(b.get("exposure", a.get("exposure", 1.0))), f)
	# depth of field: "dof" [far m, transition m, amount] blurs beyond, "dof_near" [near m, transition m
	# (, amount)] before; a key without one keeps the key's before it, and from a key without any to one
	# with it the blur comes in (far from 2 km, near from 0): a pull of focus
	var fa: Array = a.get("dof", [])
	var fb: Array = b.get("dof", fa)
	var na: Array = a.get("dof_near", [])
	var nb: Array = b.get("dof_near", na)
	attrs.dof_blur_far_enabled = fa.size() >= 2 or fb.size() >= 2
	attrs.dof_blur_near_enabled = na.size() >= 2 or nb.size() >= 2
	if attrs.dof_blur_far_enabled:
		attrs.dof_blur_far_distance = lerpf(float(fa[0]) if fa.size() >= 2 else 2000.0, float(fb[0]) if fb.size() >= 2 else 2000.0, f)
		attrs.dof_blur_far_transition = lerpf(float(fa[1]) if fa.size() >= 2 else 1.0, float(fb[1]) if fb.size() >= 2 else 1.0, f)
	if attrs.dof_blur_near_enabled:
		attrs.dof_blur_near_distance = lerpf(float(na[0]) if na.size() >= 2 else 0.0, float(nb[0]) if nb.size() >= 2 else 0.0, f)
		attrs.dof_blur_near_transition = lerpf(float(na[1]) if na.size() >= 2 else 0.01, float(nb[1]) if nb.size() >= 2 else 0.01, f)
	var amt := func(far: Array, near: Array) -> float:
		return float(far[2]) if far.size() == 3 else (float(near[2]) if near.size() == 3 else -1.0)
	var aa: float = amt.call(fa, na)
	var ab: float = amt.call(fb, nb)
	if aa >= 0.0 or ab >= 0.0:
		attrs.dof_blur_amount = lerpf(aa if aa >= 0.0 else ab, ab if ab >= 0.0 else aa, f)


## A hand-held camera's wander at scene time `time` (degrees of yaw, pitch, roll for 1 degree of
## "handheld"): smooth noise in two octaves, about 0.5-1.5 Hz, the roll half as much; `seed` sets the shot apart.
static func handheld(time: float, seed: float) -> Vector3:
	var out := Vector3.ZERO
	for axis in 3:
		var o := seed * 13.7 + float(axis) * 101.3
		out[axis] = _noise1(time * 0.7 + o) * 0.7 + _noise1(time * 1.6 + o + 47.0) * 0.3
	out.z *= 0.5
	return out


## Smooth 1D value noise in -1..1 (eased between a random value at each integer).
static func _noise1(x: float) -> float:
	var i := floorf(x)
	var fr := x - i
	var h0 := fposmod(sin(i * 127.1 + 311.7) * 43758.5453, 1.0) * 2.0 - 1.0
	var h1 := fposmod(sin((i + 1.0) * 127.1 + 311.7) * 43758.5453, 1.0) * 2.0 - 1.0
	return lerpf(h0, h1, fr * fr * (3.0 - 2.0 * fr))


## A Catmull-Rom curve through p1 (f = 0) and p2 (f = 1), shaped by the points either side.
static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, f: float) -> Vector3:
	return p1.cubic_interpolate(p2, p0, p3, f)


## A car or a person with "from" / "to" is on screen only between them (shot seconds).
static func _on_screen(spec: Dictionary, local: float) -> bool:
	return local >= float(spec.get("from", -1.0e9)) and local < float(spec.get("to", 1.0e9))


## The shot's rear-view mirror: a second camera into a picture the 2D layer frames and flips.
func _set_mirror(s: Dictionary) -> void:
	if not s.has("mirror"):
		if subtitles != null:
			subtitles.show_mirror(null, Rect2())
		if _mirror_vp != null:
			_mirror_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED     # (a second render a frame)
		return
	var r: Array = (s["mirror"] as Dictionary).get("rect", [0.3, 0.06, 0.4, 0.2])
	var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var glass := bool((s["mirror"] as Dictionary).get("glass", false))
	if _mirror_vp == null:
		_mirror_vp = SubViewport.new()
		_mirror_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_mirror_vp)
		_mirror_cam = Camera3D.new()
		_mirror_cam.far = TmSkyline.FAR
		_mirror_cam.cull_mask &= ~(1 << (StoryCabin.MIRROR_LAYER - 1)) & ~SOFTBOX_LAYER   # a mirror doesn't see itself
		var ma := CameraAttributesPractical.new()
		ma.exposure_multiplier = 2.4            # a mirror shot reads the dark car behind and the back seat
		_mirror_cam.attributes = ma
		_mirror_vp.add_child(_mirror_cam)
		_mirror_cam.current = true
	_mirror_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600, 900)
	_mirror_vp.size = Vector2i(maxi(64, int(vs.x * rect.size.x)), maxi(32, int(vs.y * rect.size.y)))
	(_mirror_cam.attributes as CameraAttributesPractical).exposure_multiplier = float((s["mirror"] as Dictionary).get("exposure", 1.6 if glass else 2.4))
	_mirror_cam.near = 0.05
	if glass and _glass() != null:
		# the picture on the cabin's own glass (what the driver sees in it), not on the screen
		var w := 1024
		_mirror_vp.size = Vector2i(w, int(w * StoryCabin.GLASS.y / StoryCabin.GLASS.x))
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.albedo_texture = _mirror_vp.get_texture()
		gm.albedo_color = Color(0.85, 0.85, 0.85)               # a mirror gives back a little less
		gm.uv1_scale = Vector3(-1.0, 1.0, 1.0)                  # the camera's picture, mirrored
		gm.uv1_offset = Vector3(1.0, 0.0, 0.0)
		_glass().mirror_glass.material_override = gm
		if subtitles != null:
			subtitles.show_mirror(null, Rect2())
		return
	if subtitles != null:
		subtitles.show_mirror(_mirror_vp.get_texture(), rect)


## "reflect": scale (an env's: 0.5, half the screen's size): the city in the props' water, a planar
## reflection: a second camera mirrored in the water's plane renders the city's layer alone (nothing
## under the water: the quay's walls, the yard) without the expensive effects, and the water's shader
## shows it, rippled and smeared down in streaks as lights on a harbour are, by its Fresnel. Shots
## without it: off (no second render).
func _set_reflect(scale: float) -> void:
	var waters := _props.find_children("Water", "MeshInstance3D", true, false)
	if scale <= 0.0 or waters.is_empty() or camera == null:
		if _refl_vp != null:
			_refl_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		for w: Node in waters:
			((w as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("refl_on", 0.0)
		return
	if _refl_vp == null:
		_refl_vp = SubViewport.new()
		_refl_vp.use_hdr_2d = RenderingServer.get_current_rendering_method() != "gl_compatibility"
		add_child(_refl_vp)
		_refl_cam = Camera3D.new()
		_refl_cam.cull_mask = TmSkyline.LAYER
		_refl_vp.add_child(_refl_cam)
		_refl_cam.current = true
	var env := _environment()
	if env != null:
		var re := env.duplicate() as Environment
		re.tonemap_mode = Environment.TONE_MAPPER_LINEAR    # the main camera tones it, once, as the water's light
		re.tonemap_exposure = 1.0
		re.glow_enabled = false
		re.ssr_enabled = false
		re.ssao_enabled = false
		re.ssil_enabled = false
		re.sdfgi_enabled = false
		re.volumetric_fog_enabled = false
		_refl_cam.environment = re
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600, 900)
	_refl_vp.size = Vector2i(maxi(64, int(vs.x * scale)), maxi(36, int(vs.y * scale)))
	_refl_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_refl_y = (waters[0] as Node3D).global_position.y
	for w: Node in waters:
		var m := (w as MeshInstance3D).material_override as ShaderMaterial
		m.set_shader_parameter("refl_tex", _refl_vp.get_texture())
		m.set_shader_parameter("refl_on", 1.0)
		m.set_shader_parameter("refl_gain", 1.0 if _refl_vp.use_hdr_2d else 1.5)


## The reflection's camera: the shot's camera mirrored in the water (its picture the reflection upside
## down; the water's shader reads it flipped).
func _aim_reflection() -> void:
	if _refl_cam == null or _refl_vp.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return
	var ct := camera.global_transform
	var mb := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1)) * ct.basis
	_refl_cam.global_transform = Transform3D(Basis(mb.x, -mb.y, mb.z), Vector3(ct.origin.x, 2.0 * _refl_y - ct.origin.y, ct.origin.z))
	_refl_cam.fov = camera.fov
	_refl_cam.near = camera.near
	_refl_cam.far = camera.far
	_refl_cam.keep_aspect = camera.keep_aspect


## The shot's mirror on a cabin's glass ("mirror": {"glass": true, "follow": a car}): that car's
## cabin, or null (a flat mirror on the screen, or none).
func _glass() -> StoryCabin:
	if _shot < 0 or _shot >= shots.size():
		return null
	var m: Dictionary = (shots[_shot] as Dictionary).get("mirror", {})
	if not bool(m.get("glass", false)) or not _cars.has(String(m.get("follow", ""))):
		return null
	return _cars[String(m["follow"])].get("cabin", null) as StoryCabin


## The glass mirror's camera: the driver's eyes reflected in the glass (StoryCabin.reflection).
func _aim_glass(cabin: StoryCabin) -> void:
	var r := cabin.reflection()
	var xf := cabin.global_transform
	_mirror_cam.global_position = xf * (r["pos"] as Vector3)
	_mirror_cam.look_at(xf * (r["look"] as Vector3), xf.basis.y)
	_mirror_cam.fov = float(r["fov"])
	_mirror_cam.near = float(r["near"])


## "flicker": every light of the shot (its props and the cars' cabins) stutters.
func _flicker(s: Dictionary, local: float) -> void:
	var fl: Dictionary = s.get("flicker", {})
	var lights: Array = _props.find_children("*", "Light3D", true, false) + _lights.find_children("*", "Light3D", true, false)
	for c: Dictionary in _cars.values():
		if c.has("cabin"):
			lights.append_array((c["cabin"] as Node).find_children("*", "Light3D", true, false))
	for l: Light3D in lights:
		if l.has_meta("fire"):
			continue                  # a fire keeps its own flicker (StoryProps.pose)
		if not l.has_meta("energy"):
			l.set_meta("energy", l.light_energy)
		var base := keyed(l.get_meta("keys"), local) if l.has_meta("keys") else float(l.get_meta("energy"))
		if l.has_meta("passing"):
			base = _passing_at(l, local)
		if fl.is_empty() or local < float(fl.get("from", -1.0e9)) or local >= float(fl.get("to", 1.0e9)):
			l.light_energy = base
			continue
		var rate := float(fl.get("rate", 9.0))
		var n := sin(local * rate * 6.1) * sin(local * rate * 2.3 + 1.7)
		l.light_energy = base * (1.0 - float(fl.get("depth", 0.8)) * (1.0 if n > 0.35 else 0.0))


## A shot's sounds, each once, as the playing scene passes its moment.
func _sounds(s: Dictionary, local: float) -> void:
	var list: Array = s.get("sounds", [])
	for k in list.size():
		var key := "%d:%d" % [_shot, k]
		var at := float((list[k] as Dictionary).get("at", 0.0))
		if _fired.has(key) or local < at or _last_local > at + 0.25:
			continue
		_fired[key] = true
		var cue := String(list[k]["cue"])
		# each its own player: one cue twice in a shot (her breath after Kit's) doesn't cut itself off
		_play(cue, float(list[k].get("db", 0.0)), float(list[k].get("pitch", 1.0)), "%s#%d" % [cue, k])


## key: the player's name (the cue itself for a loop; a one-shot sound's own).
func _play(cue: String, db := 0.0, pitch := 1.0, key := "") -> AudioStreamPlayer:
	var stream := StorySounds.get_stream(cue)
	if stream == null:
		return null
	key = cue if key.is_empty() else key
	var p: AudioStreamPlayer = _players.get(key, null)
	if p == null:
		p = AudioStreamPlayer.new()
		add_child(p)
		_players[key] = p
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()
	return p


## A shot's looping sounds (rain on the roof, a heartbeat, water dripping), only while the scene
## plays: a loop the next shot doesn't name stops at the cut; one it names again plays on, at this
## shot's level and pitch.
func _set_ambience(specs: Array) -> void:
	var cues := specs.map(func(a: Dictionary) -> String: return String(a["cue"]))
	for name: String in _players:
		if StorySounds.loops(name) and not name in cues:
			var p := _players[name] as AudioStreamPlayer
			if name in FADE_OUT and p.playing and is_inside_tree():
				# a train passing on over a cut dies away; it isn't cut dead
				if not p.has_meta("fading"):
					p.set_meta("fading", true)
					var tw := create_tween()
					tw.tween_property(p, "volume_db", -40.0, 1.5)
					tw.tween_callback(func() -> void:
						p.stop()
						p.remove_meta("fading"))
			elif not p.has_meta("fading"):
				p.stop()
	for a: Dictionary in specs:
		if not playing:
			continue
		var cue := String(a["cue"])
		var db := float(a.get("db", -6.0))
		var pitch := float(a.get("pitch", 1.0))
		var p: AudioStreamPlayer = _players.get(cue, null)
		if p == null or not p.playing:
			_play(cue, db, pitch)
		elif not p.has_meta("fading"):
			p.volume_db = db
			p.pitch_scale = pitch


## A shot's "ambience": a looping cue, or a list of them (the cues' names).
static func ambience(s: Dictionary) -> Array:
	return ambience_specs(s).map(func(a: Dictionary) -> String: return String(a["cue"]))


## A shot's "ambience" as entries: each a cue's name or {"cue", "db" (its level: -6), "pitch", "to"
## (s into the shot it stops at: the rain stopping in the headlights)}.
static func ambience_specs(s: Dictionary) -> Array:
	var a: Variant = s.get("ambience", "")
	var out: Array = []
	for c: Variant in (a if a is Array else [a]):
		var d: Dictionary = c if c is Dictionary else {"cue": String(c)}
		if not String(d.get("cue", "")).is_empty():
			out.append(d)
	return out


## A number keyed over a shot's time: a plain number, or [[t, v], ...] eased between keys (smoothstep)
## and held before the first and after the last (a light coming up, the rain stopping).
static func keyed(v: Variant, t: float) -> float:
	if not v is Array:
		return float(v)
	var keys: Array = v
	if keys.is_empty():
		return 0.0
	var out := float((keys[0] as Array)[1])
	for i in keys.size():
		var k: Array = keys[i]
		if t >= float(k[0]):
			out = float(k[1])
			if i + 1 < keys.size():
				var n: Array = keys[i + 1]
				var span := float(n[0]) - float(k[0])
				var f := clampf((t - float(k[0])) / span, 0.0, 1.0) if span > 0.0 else 1.0
				out = lerpf(float(k[1]), float(n[1]), f * f * (3.0 - 2.0 * f))
	return out


## The largest value a keyed number reaches (a light built at its brightest, then keyed down).
static func keyed_max(v: Variant) -> float:
	if not v is Array:
		return float(v)
	var m := 0.0
	for k: Array in v:
		m = maxf(m, float(k[1]))
	return m


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


## A camera key's place: [x, y, z], or the name of a place in the followed car (StoryCabin.points:
## "driver_head", "mirror"), so a shot from the seat or in the mirror fits any car.
static func _at(v: Variant, model: String) -> Vector3:
	if v is String:
		return StoryCabin.points(model if not model.is_empty() else "hyper").get(v, Vector3.ZERO)
	return _vec(v)


static func _vec(v: Variant) -> Vector3:
	var a: Array = v if v is Array else [0, 0, 0]
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a.size() >= 3 else Vector3.ZERO
