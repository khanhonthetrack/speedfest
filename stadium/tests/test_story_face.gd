extends Node3D
## The cast's faces in cutscenes (StoryFace, PLAN M20-9): blinks come at times fixed by the person
## and leave the eyes open most of the time; a line's text reads as mouth shapes, spoken within its
## subtitle and silent outside it; the shapes reach the character's meshes; the eyes turn the right
## way; in a scene only the speaker on screen moves its mouth, the other looks at it, a voice off
## moves no mouth, and the face is the same whichever order a cutscene seeks in.
## Run: stadium/tools/run.sh res://tests/test_story_face.tscn --headless


func _ready() -> void:
	# blinks
	var shut := 0
	var closed := 0.0
	var again := true
	for k in 1200:                                  # 60 s at 20 Hz
		var t := k * 0.05
		var b := StoryFace.blink_at(t, 1234)
		closed = maxf(closed, b)
		if b > 0.5:
			shut += 1
		again = again and is_equal_approx(b, StoryFace.blink_at(t, 1234))
	var first := func(seed: int) -> float:
		for k in 1000:
			if StoryFace.blink_at(k * 0.01, seed) > 0.5:
				return k * 0.01
		return -1.0
	var other: bool = absf(first.call(99) - first.call(1234)) > 0.05
	TestHooks.check(closed > 0.99 and shut > 5 and shut < 1200 * 0.06 and again, "face_blinks",
		"shut %d of 1200 samples (%.1f%%), fully closed %s" % [shut, shut / 12.0, closed > 0.99])
	TestHooks.check(other, "face_blinks_differ_per_person", "")
	# a line's text as sounds
	var snd := StoryFace.sounds("Gone six. The shop!")
	var keys := snd.map(func(s: Array) -> String: return String(s[0]))
	TestHooks.check(keys.slice(0, 4) == ["g", "o", "n", "e"] and keys.has("th") and keys.has("sh")
		and keys.count("") >= 3, "face_text_to_sounds", str(keys))
	# spoken within the line, silent outside
	var line := {"at": 1.0, "hold": 2.6, "text": "Gone six. You slept in it."}
	var before := StoryFace.mouth_at(0.9, [line])
	var during := StoryFace.mouth_at(1.6, [line])
	var after := StoryFace.mouth_at(3.7, [line])
	var moving := 0
	for k in 40:
		if not StoryFace.mouth_at(1.1 + k * 0.05, [line]).is_empty():
			moving += 1
	TestHooks.check(before.is_empty() and after.is_empty() and not during.is_empty() and moving > 25,
		"face_mouth_within_its_line", "before %s, during %s, after %s; moving %d of 40" % [before, during, after, moving])
	# on a cast member's meshes
	var dee := StoryCast.instance("dee")
	add_child(dee)
	StoryCast.player(dee).play("Idle")
	var face := StoryFace.new(dee, 7)
	var open_jaw := 0.0
	var vis := 0.0
	for k in 30:
		face.pose(1.1 + k * 0.05, [line], null)
		open_jaw = maxf(open_jaw, face.shape("jawOpen"))
		for v in ["viseme_aa", "viseme_O", "viseme_E", "viseme_I", "viseme_SS", "viseme_PP"]:
			vis = maxf(vis, face.shape(v))
	face.pose(5.0, [line], null)
	var rest := face.shape("jawOpen") + face.shape("viseme_O") + face.shape("viseme_aa")
	TestHooks.check(face.has_shape("viseme_aa") and face.has_shape("eyeBlinkLeft") and open_jaw > 0.2 and vis > 0.5 and rest == 0.0,
		"face_shapes_on_the_meshes", "jaw up to %.2f, visemes up to %.2f, at rest %.2f" % [open_jaw, vis, rest])
	# a blink shuts the lids (the body's and the lashes')
	var t_shut := -1.0
	for k in 2000:
		if StoryFace.blink_at(k * 0.01, 7) > 0.99:
			t_shut = k * 0.01
			break
	face.pose(t_shut, [], null)
	var lash := 0.0
	for mi: MeshInstance3D in dee.find_children("lash__*", "MeshInstance3D", true, false):
		var i := mi.find_blend_shape_by_name("eyeBlinkLeft")
		if i >= 0:
			lash = mi.get_blend_shape_value(i)
	TestHooks.check(face.shape("eyeBlinkLeft") > 0.99 and lash > 0.99, "face_blink_shuts_lids_and_lashes", "at %.2f s" % t_shut)
	# the eyes: dee faces +z, her left is +x
	await get_tree().process_frame
	var eyes := (face.eyes_towards(Vector3(2.0, 1.5, 2.0)))
	var left_ok := float(eyes.get("eyeLookOutLeft", 0.0)) > 0.5 and float(eyes.get("eyeLookInRight", 0.0)) > 0.5
	eyes = face.eyes_towards(Vector3(-2.0, 1.5, 2.0))
	var right_ok := float(eyes.get("eyeLookInLeft", 0.0)) > 0.5 and float(eyes.get("eyeLookOutRight", 0.0)) > 0.5
	eyes = face.eyes_towards(Vector3(0.0, 0.3, 1.5))
	var down_ok := float(eyes.get("eyeLookDownLeft", 0.0)) > 0.5
	TestHooks.check(left_ok and right_ok and down_ok, "face_eyes_turn_the_right_way", "left %s right %s down %s" % [left_ok, right_ok, down_ok])
	dee.free()
	await _scene()
	TestHooks.finish()


## A scene: Dee speaks, Kit (facing the camera, Dee to her left) looks at her; then a voice off.
func _scene() -> void:
	var d := {"id": "face_test", "shots": [{"id": "talk", "dur": 9.0, "people": [
		{"id": "dee", "who": "dee", "clip": "Idle_Talking", "pos": [0.8, 0.0, 0.0], "face": -90},
		{"id": "kit", "who": "kit", "clip": "Idle", "pos": [-0.8, 0.0, 0.0], "face": 0}],      # Dee to her left
		"camera": {"keys": [{"u": 0, "pos": [0.0, 1.5, 4.0], "look": [0.0, 1.4, 0.0]}]},
		"lines": [{"speaker": "Dee", "text": "Gone six. You slept in it.", "at": 1.0, "hold": 3.0},
			{"speaker": "Kit", "text": "Who is calling at this hour?", "at": 5.0, "hold": 3.0, "voice": true}]}]}
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, StoryState.new(), false)
	sc.seek(0.0)
	var dee: StoryPerson
	var kit: StoryPerson
	for n in sc.find_children("*", "", true, false):
		if n is StoryPerson and (n as StoryPerson).who == "dee":
			dee = n
		elif n is StoryPerson and (n as StoryPerson).who == "kit":
			kit = n
	TestHooks.check(dee != null and kit != null and dee.face != null and kit.face != null and dee.speaks("Dee")
		and not dee.speaks("Kit") and kit.speaks("kit"), "face_scene_people", "%s %s" % [dee, kit])
	if dee == null or kit == null:
		return
	var mouth := func(p: StoryPerson) -> float:
		return p.face.shape("jawOpen") + p.face.shape("viseme_aa") + p.face.shape("viseme_O") + p.face.shape("viseme_E") + p.face.shape("viseme_I") + p.face.shape("viseme_SS")
	var dee_talks := 0.0
	var kit_quiet := 0.0
	var kit_looks := 0.0
	for k in 20:
		sc.seek(1.2 + k * 0.08)
		dee_talks = maxf(dee_talks, mouth.call(dee))
		kit_quiet = maxf(kit_quiet, mouth.call(kit))
		kit_looks = maxf(kit_looks, minf(kit.face.shape("eyeLookOutLeft"), kit.face.shape("eyeLookInRight")))
	var voice_off := 0.0
	for k in 20:
		sc.seek(5.2 + k * 0.1)
		voice_off = maxf(voice_off, mouth.call(kit) + mouth.call(dee))
	TestHooks.check(dee_talks > 0.3 and kit_quiet == 0.0 and voice_off == 0.0, "face_only_the_speaker_talks",
		"Dee up to %.2f, Kit %.2f while Dee speaks; a voice off moves %.2f" % [dee_talks, kit_quiet, voice_off])
	TestHooks.check(kit_looks > 0.5, "face_listener_looks_at_speaker", "Kit's eyes to her left %.2f" % kit_looks)
	# the same face whichever way the scene seeks to it
	sc.seek(2.1)
	var a := [mouth.call(dee), dee.face.shape("eyeBlinkLeft"), kit.face.shape("eyeLookOutLeft")]
	sc.seek(7.0)
	sc.seek(0.2)
	sc.seek(2.1)
	var b := [mouth.call(dee), dee.face.shape("eyeBlinkLeft"), kit.face.shape("eyeLookOutLeft")]
	TestHooks.check(str(a) == str(b), "face_seek_order_free", "%s vs %s" % [a, b])
	sc.queue_free()
