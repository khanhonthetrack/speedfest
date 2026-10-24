class_name StoryFace
extends RefCounted
## A cast member's face in a cutscene (PLAN M20-9): blinks, a mouth that moves with its own lines,
## eyes on whoever it looks at. Like everything in a scene, a function of the scene's time (pose),
## so a cutscene seeks to any frame and plays the same headless. Drives the face shapes the cast is
## built with (tools/cast/blender/gen_char.py: ARKit blinks and gaze, Meta's visemes, the jaw).
##
## The mouth: a line's text read as mouth shapes (letters to visemes: "th" TH, "ch"/"sh" CH, a
## vowel its own shape, p/b/m closed), spread over the time the line is spoken (its subtitle's
## hold, at most a natural pace), each shape easing into the next, the jaw open on the vowels.
## Blinks: every 2-5.5 s at times fixed by the person's seed, 0.22 s each.
## The eyes: towards a point in the world, within what eyes can turn (30 degrees aside, 25 up and down).

const BLINK := 0.22                     ## s: closing 0.06, shut 0.04, opening 0.12
const PACE := 13.0                      ## mouth shapes per second at most (natural speech)
const EYE_SIDE := 30.0                  ## degrees the eyes turn to the side at full shape
const EYE_UPDOWN := 25.0
## a letter's mouth shape, its weight and how open the jaw is
const SHAPE := {
	"a": ["viseme_aa", 0.85, 0.45], "e": ["viseme_E", 0.8, 0.3], "i": ["viseme_I", 0.8, 0.18],
	"y": ["viseme_I", 0.6, 0.15], "o": ["viseme_O", 0.85, 0.38], "u": ["viseme_U", 0.8, 0.2],
	"w": ["viseme_U", 0.7, 0.12], "p": ["viseme_PP", 0.9, 0.0], "b": ["viseme_PP", 0.9, 0.0],
	"m": ["viseme_PP", 0.85, 0.0], "f": ["viseme_FF", 0.85, 0.05], "v": ["viseme_FF", 0.8, 0.05],
	"th": ["viseme_TH", 0.8, 0.1], "t": ["viseme_DD", 0.7, 0.12], "d": ["viseme_DD", 0.7, 0.12],
	"l": ["viseme_nn", 0.6, 0.12], "n": ["viseme_nn", 0.7, 0.1], "k": ["viseme_kk", 0.7, 0.15],
	"g": ["viseme_kk", 0.7, 0.15], "c": ["viseme_kk", 0.7, 0.15], "q": ["viseme_kk", 0.7, 0.15],
	"x": ["viseme_kk", 0.6, 0.12], "ch": ["viseme_CH", 0.85, 0.12], "sh": ["viseme_CH", 0.85, 0.1],
	"j": ["viseme_CH", 0.8, 0.12], "s": ["viseme_SS", 0.75, 0.08], "z": ["viseme_SS", 0.7, 0.08],
	"r": ["viseme_RR", 0.7, 0.12], "ph": ["viseme_FF", 0.85, 0.05],
}
## how long each sound lasts, against a consonant's 1.0
const VOWEL := 1.4
const GAP := 0.6                        ## between words
const STOP := 2.2                       ## at , . ? ! ; :

var root: Node3D
var seed := 0
var _shapes := {}                       ## shape -> [[MeshInstance3D, index], ...]


func _init(body: Node3D, person_seed: int) -> void:
	root = body
	seed = person_seed
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var am := mi.mesh as ArrayMesh
		if am == null:
			continue
		for k in am.get_blend_shape_count():
			(_shapes.get_or_add(String(am.get_blend_shape_name(k)), []) as Array).append([mi, k])


func has_shape(name: String) -> bool:
	return _shapes.has(name)


func set_shape(name: String, value: float) -> void:
	for pair: Array in _shapes.get(name, []):
		(pair[0] as MeshInstance3D).set_blend_shape_value(pair[1], value)


func shape(name: String) -> float:
	var pairs: Array = _shapes.get(name, [])
	return (pairs[0][0] as MeshInstance3D).get_blend_shape_value(pairs[0][1]) if not pairs.is_empty() else 0.0


## The face at scene time t: lines = this person's own spoken lines [{at, hold, text}] (scene time),
## gaze = a world point to look at, or null (straight ahead).
func pose(t: float, lines: Array, gaze: Variant) -> void:
	var b := blink_at(t, seed)
	set_shape("eyeBlinkLeft", b)
	set_shape("eyeBlinkRight", b)
	var m := mouth_at(t, lines)
	for v in SHAPE.values():
		set_shape(v[0], float(m.get(v[0], 0.0)))
	set_shape("jawOpen", float(m.get("jawOpen", 0.0)))
	var eyes := {}
	if gaze is Vector3:
		eyes = eyes_towards(gaze)
	for k in ["eyeLookInLeft", "eyeLookOutLeft", "eyeLookInRight", "eyeLookOutRight", "eyeLookUpLeft",
			"eyeLookUpRight", "eyeLookDownLeft", "eyeLookDownRight"]:
		set_shape(k, float(eyes.get(k, 0.0)))


## How shut the eyes are at time t (0 open .. 1 shut): blinks at times fixed by the seed.
static func blink_at(t: float, person_seed: int) -> float:
	var start := 0.3 + 1.7 * _rand(person_seed, 0)
	var k := 1
	while start + BLINK < t:
		start += 2.0 + 3.5 * _rand(person_seed, k)
		k += 1
	var d := t - start
	if d < 0.0 or d > BLINK:
		return 0.0
	if d < 0.06:
		return smoothstep(0.0, 0.06, d)
	if d < 0.10:
		return 1.0
	return 1.0 - smoothstep(0.10, BLINK, d)


static func _rand(s: int, k: int) -> float:
	var x := sin(float(s) * 12.9898 + float(k) * 78.233) * 43758.5453
	return x - floorf(x)


## A line's text as sounds: [[letter key or "" (mouth at rest), length], ...].
static func sounds(text: String) -> Array:
	var out := []
	var s := text.to_lower()
	var i := 0
	while i < s.length():
		var two := s.substr(i, 2)
		var c := s[i]
		if two in ["th", "ch", "sh", "ph"]:
			out.append([two, 1.0])
			i += 2
			continue
		if SHAPE.has(c):
			out.append([c, VOWEL if c in "aeiouy" else 1.0])
		elif c in ",.?!;:":
			out.append(["", STOP])
		elif c == " " or c == "-":
			out.append(["", GAP])
		# h and the rest: no shape of their own (the neighbours carry them)
		i += 1
	return out


## The mouth's shapes at time t over a person's lines: {viseme: weight, "jawOpen": j}.
static func mouth_at(t: float, lines: Array) -> Dictionary:
	for l: Dictionary in lines:
		var at := float(l["at"]) + 0.08
		var snd := sounds(String(l.get("text", "")))
		var total := 0.0
		for s: Array in snd:
			total += float(s[1])
		if total <= 0.0:
			continue
		# spoken at a natural pace, within the subtitle's time
		var speak := minf(float(l["hold"]) - 0.25, total / PACE * 1.1)
		if t < at or t > at + speak or speak <= 0.0:
			continue
		var u := (t - at) / speak * total
		var acc := 0.0
		for n in snd.size():
			var dur := float(snd[n][1])
			if u <= acc + dur or n == snd.size() - 1:
				var f := clampf((u - acc) / dur, 0.0, 1.0)
				var out := _weights(String(snd[n][0]), 1.0)
				# ease into the next sound over the last third of this one
				if f > 0.66 and n + 1 < snd.size():
					var g := smoothstep(0.66, 1.0, f)
					out = _mix(_weights(String(snd[n][0]), 1.0 - g), _weights(String(snd[n + 1][0]), g))
				# and out of the first and into silence at the ends
				var edge := clampf(minf(t - at, at + speak - t) / 0.08, 0.0, 1.0)
				for k in out:
					out[k] = float(out[k]) * edge
				return out
			acc += dur
	return {}


static func _weights(key: String, w: float) -> Dictionary:
	if key == "" or not SHAPE.has(key):
		return {}
	var s: Array = SHAPE[key]
	return {s[0]: float(s[1]) * w, "jawOpen": float(s[2]) * w}


static func _mix(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for k in b:
		out[k] = float(out.get(k, 0.0)) + float(b[k])
	return out


## The eye shapes that look at a world point, from between the eyes, in the head's frame: the eyes
## turn inside the head, and the clips turn the head (Crouch_Idle tips it 45 degrees down, Sitting_Idle
## and Driving turn it 11 aside). The head's frame is the body's (it faces +z, its left is +x) turned
## as the head turned from its rest. Past what eyes reach (90 degrees aside) they drift back to the
## middle, so a target passing behind the head never flips them from one side to the other.
func eyes_towards(target: Vector3) -> Dictionary:
	var sk := StoryCast.skeleton(root)
	if sk == null:
		return {}
	var i := sk.find_bone("Head")
	if i < 0:
		return {}
	var hp := sk.get_bone_global_pose(i)
	var head := (sk.global_transform * hp).origin + root.global_basis.y.normalized() * 0.07
	var turn := (hp.basis * sk.get_bone_global_rest(i).basis.inverse()).orthonormalized()
	var d := turn.inverse() * (root.global_basis.orthonormalized().inverse() * (target - head))
	if d.length() < 0.05:
		return {}
	var side := rad_to_deg(atan2(d.x, d.z))                     # + : to its left
	var up := rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
	var reach := clampf((120.0 - absf(side)) / 30.0, 0.0, 1.0)
	var h := clampf(absf(side) / EYE_SIDE, 0.0, 1.0) * reach
	var v := clampf(absf(up) / EYE_UPDOWN, 0.0, 1.0) * reach
	var out := {}
	if side > 0.0:              # to its left: the left eye looks out, the right eye in
		out["eyeLookOutLeft"] = h
		out["eyeLookInRight"] = h
	else:
		out["eyeLookInLeft"] = h
		out["eyeLookOutRight"] = h
	if up > 0.0:
		out["eyeLookUpLeft"] = v
		out["eyeLookUpRight"] = v
	else:
		out["eyeLookDownLeft"] = v
		out["eyeLookDownRight"] = v
	return out
