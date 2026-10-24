extends Node3D
## The cast's faces in cutscenes (StoryFace, PLAN M20-9): blinks come at times fixed by the person
## and leave the eyes open most of the time; a line's text reads as mouth shapes, spoken within its
## subtitle (never past it) and silent outside it; the shapes reach the character's meshes (the
## body's lids, the lashes); the eyes turn the right way for a body turned any way and from a head
## the clip has tipped; in a scene of two shots (scene time is not shot time) only the speaker on
## screen moves its mouth, the other looks at it, a voice off moves no mouth and draws no eyes, a
## look at the camera follows the moving camera, and every shape is the same whichever way a
## cutscene seeks to a moment.
## Run: stadium/tools/run.sh res://tests/test_story_face.tscn --headless

const MOUTH := ["jawOpen", "viseme_aa", "viseme_O", "viseme_E", "viseme_I", "viseme_U", "viseme_SS", "viseme_PP",
	"viseme_FF", "viseme_TH", "viseme_DD", "viseme_kk", "viseme_CH", "viseme_nn", "viseme_RR"]
const EYES := ["eyeLookInLeft", "eyeLookOutLeft", "eyeLookInRight", "eyeLookOutRight", "eyeLookUpLeft",
	"eyeLookUpRight", "eyeLookDownLeft", "eyeLookDownRight"]


func _ready() -> void:
	# blinks
	var shut := 0
	var closed := 0.0
	for k in 1200:                                  # 60 s at 20 Hz
		var b := StoryFace.blink_at(k * 0.05, 1234)
		closed = maxf(closed, b)
		if b > 0.5:
			shut += 1
	var first := func(seed: int) -> float:
		for k in 1000:
			if StoryFace.blink_at(k * 0.01, seed) > 0.5:
				return k * 0.01
		return -1.0
	TestHooks.check(closed > 0.99 and shut > 5 and shut < 1200 * 0.06, "face_blinks",
		"shut %d of 1200 samples (%.1f%%), fully closed %s" % [shut, shut / 12.0, closed > 0.99])
	TestHooks.check(absf(first.call(99) - first.call(1234)) > 0.05, "face_blinks_differ_per_person", "")
	# a line's text as sounds
	var snd := StoryFace.sounds("Gone six. The shop!")
	var keys := snd.map(func(s: Array) -> String: return String(s[0]))
	TestHooks.check(keys.slice(0, 4) == ["g", "o", "n", "e"] and keys.has("th") and keys.has("sh")
		and keys.count("") >= 3, "face_text_to_sounds", str(keys))
	# spoken within the line, silent outside; never past its subtitle
	var line := {"at": 1.0, "hold": 2.6, "text": "Gone six. You slept in it."}
	var before := StoryFace.mouth_at(0.9, [line])
	var during := StoryFace.mouth_at(1.6, [line])
	var after := StoryFace.mouth_at(3.7, [line])
	var moving := 0
	for k in 40:
		if not StoryFace.mouth_at(1.1 + k * 0.05, [line]).is_empty():
			moving += 1
	var short := {"at": 1.0, "hold": 1.0, "text": "Gone six you slept in it"}      # 2.2 s of speech in 1 s
	TestHooks.check(before.is_empty() and after.is_empty() and not during.is_empty() and moving > 25
		and StoryFace.mouth_at(1.9, [short]).is_empty() and not StoryFace.mouth_at(1.4, [short]).is_empty(),
		"face_mouth_within_its_line", "before %s, during %s, after %s; moving %d of 40" % [before, during, after, moving])
	# on a cast member's meshes
	var dee := StoryCast.instance("dee")
	add_child(dee)
	var ap := StoryCast.player(dee)
	ap.play("Idle")
	ap.seek(1.0, true)
	var face := StoryFace.new(dee, 7)
	var open_jaw := 0.0
	var vis := 0.0
	for k in 30:
		face.pose(1.1 + k * 0.05, [line], null)
		open_jaw = maxf(open_jaw, face.shape("jawOpen"))
		for v in MOUTH.slice(1):
			vis = maxf(vis, face.shape(v))
	face.pose(5.0, [line], null)
	var rest := 0.0
	for v in MOUTH:
		rest += face.shape(v)
	TestHooks.check(face.has_shape("viseme_aa") and face.has_shape("eyeBlinkLeft") and open_jaw > 0.2 and vis > 0.5 and rest == 0.0,
		"face_shapes_on_the_meshes", "jaw up to %.2f, visemes up to %.2f, at rest %.2f" % [open_jaw, vis, rest])
	# a blink shuts the lids: the body's own and the lashes'
	var t_shut := -1.0
	for k in 2000:
		if StoryFace.blink_at(k * 0.01, 7) > 0.99:
			t_shut = k * 0.01
			break
	face.pose(t_shut, [], null)
	var lids := {"skin__": 0.0, "lash__": 0.0}
	for part in lids:
		for mi: MeshInstance3D in dee.find_children(part + "*", "MeshInstance3D", true, false):
			var i := mi.find_blend_shape_by_name("eyeBlinkLeft")
			if i >= 0:
				lids[part] = mi.get_blend_shape_value(i)
	TestHooks.check(lids["skin__"] > 0.99 and lids["lash__"] > 0.99, "face_blink_shuts_lids_and_lashes", "at %.2f s: %s" % [t_shut, lids])
	# the eyes: dee faces +z, her left is +x; then turned to face +x (her left is -z); then her head
	# tipped down by a crouch: a point at her eye level straight ahead is up for her eyes
	var head := _head(dee)
	var e := face.eyes_towards(head + Vector3(2.0, 0.0, 2.0))
	var left_ok := float(e.get("eyeLookOutLeft", 0.0)) > 0.5 and float(e.get("eyeLookInRight", 0.0)) > 0.5
	e = face.eyes_towards(head + Vector3(-2.0, 0.0, 2.0))
	var right_ok := float(e.get("eyeLookInLeft", 0.0)) > 0.5 and float(e.get("eyeLookOutRight", 0.0)) > 0.5
	e = face.eyes_towards(head + Vector3(0.0, -1.3, 1.5))
	var down_ok := float(e.get("eyeLookDownLeft", 0.0)) > 0.5
	dee.rotation.y = PI / 2.0
	head = _head(dee)
	var ahead := face.eyes_towards(head + Vector3(3.0, 0.0, 0.0))
	var aside := 0.0
	for k in ["eyeLookInLeft", "eyeLookOutLeft", "eyeLookInRight", "eyeLookOutRight"]:
		aside = maxf(aside, float(ahead.get(k, 0.0)))
	var turned_ok := aside < 0.2 and float(face.eyes_towards(head + Vector3(2.0, 0.0, -2.0)).get("eyeLookOutLeft", 0.0)) > 0.5
	# behind her: no flip from one side to the other
	var behind_l := face.eyes_towards(head + Vector3(-3.0, 0.0, 0.05))
	var behind_r := face.eyes_towards(head + Vector3(-3.0, 0.0, -0.05))
	var no_flip := float(behind_l.get("eyeLookOutLeft", 0.0)) + float(behind_l.get("eyeLookInLeft", 0.0)) < 0.05 \
		and float(behind_r.get("eyeLookOutLeft", 0.0)) + float(behind_r.get("eyeLookInLeft", 0.0)) < 0.05
	dee.rotation.y = 0.0
	ap.play("Crouch_Idle")
	ap.seek(1.0, true)
	head = _head(dee)
	var tipped := float(face.eyes_towards(head + Vector3(0.0, 0.0, 3.0)).get("eyeLookUpLeft", 0.0))
	TestHooks.check(left_ok and right_ok and down_ok and turned_ok and no_flip and tipped > 0.6, "face_eyes_turn_the_right_way",
		"left %s right %s down %s, turned body %s (aside %.2f), behind %s, crouched head looks up %.2f" % [
		left_ok, right_ok, down_ok, turned_ok, aside, no_flip, tipped])
	dee.free()
	await _scene()
	TestHooks.finish()


func _head(p: Node3D) -> Vector3:
	var sk := StoryCast.skeleton(p)
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))).origin + p.global_basis.y.normalized() * 0.07


## Two shots: a wide one (2 s, nobody speaks), then Dee (id d1) speaks, Kit (k1, facing ahead, Dee
## to her left) listens, Gus (g1) looks at the camera, which moves; then a voice off for Kit.
func _scene() -> void:
	var cast := [{"id": "d1", "who": "dee", "clip": "Idle_Talking", "pos": [0.8, 0.0, 0.0], "face": -60},
		{"id": "k1", "who": "kit", "clip": "Idle", "pos": [-0.8, 0.0, 0.0], "face": 0},
		{"id": "g1", "who": "gus", "clip": "Idle", "pos": [0.0, 0.0, -1.6], "face": 0, "gaze": "camera"}]
	var d := {"id": "face_test", "shots": [
		{"id": "wide", "dur": 2.0, "people": cast.duplicate(true),
			"camera": {"keys": [{"u": 0, "pos": [0.0, 2.5, 7.0], "look": [0.0, 1.2, 0.0]}]}},
		{"id": "talk", "dur": 9.0, "people": cast.duplicate(true),
			"camera": {"ease": "linear", "keys": [{"u": 0, "pos": [-0.8, 1.6, 4.0], "look": [0.0, 1.4, -0.5]},
				{"u": 1, "pos": [0.8, 1.6, 4.0], "look": [0.0, 1.4, -0.5]}]},
			"lines": [{"speaker": "Dee", "text": "Gone six. You slept in it.", "at": 1.0, "hold": 3.0},
				{"speaker": "Kit", "text": "Who is calling at this hour?", "at": 5.0, "hold": 3.0, "voice": true}]}]}
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, StoryState.new(), false)
	sc.seek(2.5)
	var dee := _find(sc, "d1")
	var kit := _find(sc, "k1")
	var gus := _find(sc, "g1")
	TestHooks.check(dee != null and kit != null and gus != null and dee.face != null and kit.face != null
		and dee.speaks("Dee") and not dee.speaks("Kit") and kit.speaks("kit") and not gus.speaks("Dee"),
		"face_scene_people", "%s %s %s (speakers by the cast's first names, the ids differ)" % [dee, kit, gus])
	if dee == null or kit == null or gus == null:
		return
	var mouth := func(p: StoryPerson) -> float:
		var s := 0.0
		for k in MOUTH:
			s += p.face.shape(k)
		return s
	var eyes := func(p: StoryPerson) -> float:
		var s := 0.0
		for k in EYES:
			s += p.face.shape(k)
		return s
	# the wide shot: nobody speaks (scene time 1.2 is Dee's line's shot time, not her line's)
	var quiet := 0.0
	for k in 8:
		sc.seek(0.4 + k * 0.2)
		var w_dee := _find(sc, "d1")
		quiet = maxf(quiet, mouth.call(w_dee))
	sc.seek(2.5)
	dee = _find(sc, "d1")
	kit = _find(sc, "k1")
	gus = _find(sc, "g1")
	var dee_talks := 0.0
	var kit_quiet := 0.0
	var kit_looks := 0.0
	for k in 20:
		sc.seek(3.2 + k * 0.08)
		dee_talks = maxf(dee_talks, mouth.call(dee))
		kit_quiet = maxf(kit_quiet, mouth.call(kit))
		kit_looks = maxf(kit_looks, minf(kit.face.shape("eyeLookOutLeft"), kit.face.shape("eyeLookInRight")))
	var voice_off := 0.0
	var dee_eyes_off := 0.0
	for k in 20:
		sc.seek(7.2 + k * 0.1)
		voice_off = maxf(voice_off, mouth.call(kit) + mouth.call(dee))
		dee_eyes_off = maxf(dee_eyes_off, eyes.call(dee))
	TestHooks.check(quiet == 0.0 and dee_talks > 0.3 and kit_quiet == 0.0 and voice_off == 0.0, "face_only_the_speaker_talks",
		"the wide shot %.2f; Dee up to %.2f, Kit %.2f while Dee speaks; a voice off moves %.2f" % [quiet, dee_talks, kit_quiet, voice_off])
	TestHooks.check(kit_looks > 0.5 and dee_eyes_off == 0.0, "face_listener_looks_at_speaker",
		"Kit's eyes to her left %.2f while Dee speaks; Dee's eyes during the voice off %.2f" % [kit_looks, dee_eyes_off])
	# a look at the camera follows it (it moves left to right across the shot)
	sc.seek(2.6)
	var early := gus.face.shape("eyeLookInLeft") - gus.face.shape("eyeLookOutLeft")
	sc.seek(10.4)
	var late := gus.face.shape("eyeLookInLeft") - gus.face.shape("eyeLookOutLeft")
	TestHooks.check(signf(early) != signf(late) and absf(early) > 0.05 and absf(early) < 0.95, "face_looks_at_the_camera",
		"Gus's eyes %.2f at the start, %.2f at the end (+: to his right)" % [early, late])
	# every shape the same at 4.1 s whichever way the scene got there: from mid-line, from after it,
	# from the other shot (the people are made again there)
	var shapes := func() -> Array:
		var out := []
		for id in ["d1", "k1", "g1"]:
			var p := _find(sc, id)
			for k in MOUTH + EYES + ["eyeBlinkLeft"]:
				out.append(snappedf(p.face.shape(k), 0.0001))
		return out
	sc.seek(3.6)
	sc.seek(4.1)
	var a: Array = shapes.call()
	sc.seek(8.5)
	sc.seek(4.1)
	var b: Array = shapes.call()
	sc.seek(0.5)
	sc.seek(4.1)
	var c: Array = shapes.call()
	TestHooks.check(a == b and b == c, "face_seek_order_free", "%s\n%s\n%s" % [a, b, c] if a != b or b != c else "")
	sc.queue_free()


func _find(sc: Node, id: String) -> StoryPerson:
	for n in sc.find_children("*", "", true, false):
		if n is StoryPerson and String((n as StoryPerson).spec.get("id", "")) == id and not n.is_queued_for_deletion():
			return n
	return null
