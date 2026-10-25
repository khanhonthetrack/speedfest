extends Node
## The cast seated in the cars (PLAN M20-9): StoryCabin is laid out for the 1.83 m Mannequin, and
## people of other heights sit by their own bodies (StoryCast.seated: the lowest of the hips and
## thighs, the back of them, the crown, in the clip):
## - the measure itself: the Mannequin's seat a little into the cushion (its layout), its crown in
##   Sitting_Idle where the layout's StoryCabin.CROWN says; every measure finite;
## - everyone (every cast member and the Mannequin) in every seat of every road car, the drivers
##   driving (their heads further back), counted: their seat as deep in the cushion and as far back
##   as the Mannequin's in that clip, their crown under the roof; a seat lowered only where a crown
##   would come within 5 cm of the roof, then as far as its tallest sitter needs (two on one seat, and
##   people put in a car by "pos" alone, in the car with the least headroom), its back, headrest and
##   (the driver's) wheel with it;
## - the bodies as skinned in the shot (not the measure): every crown clear of its roof, where the
##   measure put it, and what each one sits on resting on its cushion.

const CUSHION := 0.06                   ## half a cushion's thickness (StoryCabin._build)
const BUILT := 0.42                     ## a cushion's middle over the Mannequin's root
const SEATS := ["driver", "passenger", "rear"]


func _ready() -> void:
	var ok := true
	var said: Array[String] = []
	for clip in ["Sitting_Idle", "Driving"]:
		var m := StoryCast.mannequin_seated(self, clip)
		var seat: Vector2 = m.get("seat", Vector2(NAN, NAN))
		var crown: Vector2 = m.get("crown", Vector2(NAN, NAN))
		# on the cushion (its top 0.48 m over the root), 0-3 cm into it, the pelvis behind the feet
		ok = ok and seat.x > BUILT + CUSHION - 0.03 and seat.x < BUILT + CUSHION and seat.y < -0.25
		if clip == "Sitting_Idle":
			ok = ok and absf(crown.x - StoryCabin.CROWN.x) < 0.015 and absf(crown.y - StoryCabin.CROWN.y) < 0.05
		said.append("%s: seat %s, crown %s" % [clip, seat, crown])
	TestHooks.check(ok, "seats_mannequin_measured", "; ".join(said) + " (the layout's crown %s)" % StoryCabin.CROWN)
	# a body that can't be measured (no humanoid skeleton) says so: {} (it then sits as the Mannequin)
	var blank := Node3D.new()
	add_child(blank)
	TestHooks.check(StoryCast.seated("nobody", blank, "Sitting_Idle").is_empty() and StoryCast._seated.has("nobody:Sitting_Idle"),
		"seats_unmeasurable_said", "")
	blank.free()
	var everyone: Array = Array(StoryCast.ids()) + [""]
	var n := everyone.size()
	# the car with the least headroom over the rear bench, for two on one seat and "pos" alone
	var tight := ""
	var least := INF
	for c: Array in TmRoadCars.CARS:
		var r := StoryCabin.headroom(String(c[0]), (StoryCabin.points(String(c[0]))["rear"] as Vector3)
			+ Vector3(0.0, StoryCabin.CROWN.x, StoryCabin.CROWN.y))
		if r < least:
			least = r
			tight = String(c[0])
	var cars: Array = []
	var people: Array = []
	var k := 0
	# each car once per person: row r seats everyone[(r + j) % n] in seat j, so everyone takes every seat
	for c: Array in TmRoadCars.CARS:
		for row in n:
			var id := "c%d" % k
			cars.append({"id": id, "model": String(c[0]), "left": 3.0 * k, "cabin": true})
			for j in mini(n, 3):
				var who := String(everyone[(row + j) % n])
				people.append({"id": "%s_%d" % [id, j], "who": who, "car": id, "seat": SEATS[j],
					"clip": "Driving" if SEATS[j] == "driver" else "Sitting_Idle"})
			k += 1
	# two on one seat (the Mannequin and whoever needs the bench lowest, beside each other), and three
	# put in by "pos" alone; the neediest found by measuring each one (then forgotten, so the scene's
	# own measuring is what the next check sees)
	var tallest := ""
	var most := -INF
	var rear0: Vector3 = StoryCabin.points(tight)["rear"]
	var mref: Vector2 = StoryCast.mannequin_seated(self, "Sitting_Idle")["seat"]
	for who: String in StoryCast.ids():
		var b := StoryCast.instance(who)
		add_child(b)
		var m := StoryCast.seated(who, b, "Sitting_Idle")
		b.free()
		StoryCast._seated.erase(who + ":Sitting_Idle")
		if m.is_empty():
			continue
		var c := rear0 + Vector3(0.0, mref.x - (m["seat"] as Vector2).x + (m["crown"] as Vector2).x,
			mref.y - (m["seat"] as Vector2).y + (m["crown"] as Vector2).y)
		if -StoryCabin.headroom(tight, c) > most:
			most = -StoryCabin.headroom(tight, c)
			tallest = who
	for order in 2:                       # either of them set up first
		var sid := "share%d" % order
		cars.append({"id": sid, "model": tight, "left": 3.0 * (k + 2 + order), "cabin": true})
		for who: String in ([""] + [tallest] if order == 0 else [tallest] + [""]):
			people.append({"id": "%s_%s" % [sid, who], "who": who, "car": sid, "seat": "rear", "clip": "Sitting_Idle"})
	var pts := StoryCabin.points(tight)
	var rear: Vector3 = pts["rear"]
	var drv: Vector3 = pts["driver"]
	cars.append({"id": "loose", "model": tight, "left": 3.0 * (k + 1), "cabin": true})
	people.append({"id": "loose_a", "who": tallest, "car": "loose", "pos": [rear.x + 0.36, rear.y, rear.z], "clip": "Sitting_Idle"})
	people.append({"id": "loose_b", "who": String(everyone[0]), "car": "loose", "pos": [rear.x - 0.36, rear.y, rear.z], "clip": "Sitting_Idle"})
	people.append({"id": "loose_c", "who": tallest, "car": "loose", "pos": [drv.x, drv.y, drv.z], "clip": "Driving"})
	var d := {"id": "seats_test", "shots": [{"id": "all", "dur": 2.0, "cars": cars, "people": people,
		"camera": {"keys": [{"u": 0, "pos": [0.0, 3.0, -6.0], "look": [0.0, 1.0, 0.0]}]}}]}
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, StoryState.new(), false)
	# measured when the scene is set up, not when a shot cuts in (a stall)
	var ahead: Array[String] = []
	for p: Dictionary in people:
		if String(p["who"]) != "" and not StoryCast._seated.has("%s:%s" % [p["who"], p["clip"]]):
			ahead.append("%s:%s" % [p["who"], p["clip"]])
	TestHooks.check(ahead.is_empty(), "seats_measured_ahead", "not measured at setup: %s" % [ahead])
	sc.seek(0.5)
	var built := {}                      # a model -> a fresh cabin's seat parts' places
	var bad_seat: Array[String] = []
	var bad_roof: Array[String] = []
	var bad_drop: Array[String] = []
	var bad_parts: Array[String] = []
	var bad_skin: Array[String] = []
	var rooms := {}                       # car:seat -> the least room of its sitters
	var arrays := {}
	var covered := {}
	var lowered := {}
	var least_skinned := INF
	var worst := ""
	var off := 0.0
	for p: Dictionary in people:
		var who := String(p["who"])
		var label := "%s %s" % [p["id"], who if who != "" else "Mannequin"]
		var person := _find(sc, String(p["id"]))
		var entry: Dictionary = sc._cars[String(p["car"])]
		var cabin := entry["cabin"] as StoryCabin
		var model := String((entry["spec"] as Dictionary)["model"])
		var q: Array = p.get("pos", [])
		var at: Vector3 = StoryCabin.points(model)[p["seat"]] if p.has("seat") else Vector3(float(q[0]), float(q[1]), float(q[2]))
		var seat := String(p.get("seat", StoryCabin.seat_at(model, at)))
		if p.has("seat") and String(p["car"]).begins_with("c"):
			covered["%s|%s|%s" % [who, model, seat]] = true
		var body := person._body
		var road := cabin.global_transform.affine_inverse() * body.global_transform
		var m := StoryCast.seated(who, body, String(p["clip"])) if who != "" else StoryCast.mannequin_seated(self, String(p["clip"]))
		var ref := StoryCast.mannequin_seated(self, String(p["clip"]))
		if not (m.has("seat") and (m["seat"] as Vector2).is_finite() and (m["crown"] as Vector2).is_finite()
				and body.global_position.is_finite()):
			bad_seat.append("%s %s: measured %s, at %s" % [model, label, m, body.global_position])
			continue
		var s := road * Vector3(0.0, (m["seat"] as Vector2).x, (m["seat"] as Vector2).y)
		var top := road * Vector3(0.0, (m["crown"] as Vector2).x, (m["crown"] as Vector2).y)
		var cushion_node := cabin._seats[seat][0] as Node3D
		var cushion := cushion_node.position.y + CUSHION
		var drop := float(cabin._drops.get(seat, 0.0))
		# as deep in the cushion and as far back as the Mannequin (written so that NaN fails)
		var deep := (s.y - cushion) - ((ref["seat"] as Vector2).x - BUILT - CUSHION)
		var back := s.z - (at.z + (ref["seat"] as Vector2).y)
		if not (absf(deep) <= 0.004 and absf(back) <= 0.004):
			bad_seat.append("%s %s %s: %.3f deeper, %.3f further back than the Mannequin" % [model, seat, label, -deep, -back])
		var room := StoryCabin.line(TmRoadCars.manifest(model), "top", top.z) - top.y
		if not (room >= 0.049):
			bad_roof.append("%s %s %s: crown %.3f under the roof" % [model, seat, label, room])
		var key := "%s:%s" % [p["car"], seat]
		rooms[key] = minf(float(rooms.get(key, INF)), room)
		if drop > 0.0:
			lowered[key] = drop
			# every part of the seat went down as far (against a cabin built afresh)
			if not built.has(model):
				var fresh := StoryCabin.make(model)
				var places := {}
				for st: String in SEATS:
					places[st] = (fresh._seats[st] as Array).map(func(nd: Node3D) -> Vector3: return nd.position)
				built[model] = places
				fresh.free()
			var was: Array = built[model][seat]
			var now: Array = cabin._seats[seat]
			for i in now.size():
				if not ((now[i] as Node3D).position.is_equal_approx((was[i] as Vector3) - Vector3(0.0, drop, 0.0))):
					bad_parts.append("%s %s part %d at %s, built %s, lowered %.3f" % [model, seat, i, (now[i] as Node3D).position, was[i], drop])
		# the body as skinned in the shot: its crown, and what it rests on over the cushion (behind its
		# knees: the back of the thighs and the seat, between its sides)
		var sk := StoryCast.skeleton(body)
		var crown_at := Vector3(0.0, -INF, 0.0)
		var low := INF
		var half := (cushion_node.mesh as BoxMesh).size * 0.5
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			if mi.skin == null:
				continue
			for i in mi.mesh.get_surface_count():
				var free := StoryCast.loose(who, mi.mesh.surface_get_material(i))   # a coat's skirt: pressed flat
				var mkey := "%d:%d" % [mi.mesh.get_instance_id(), i]
				if not arrays.has(mkey):
					arrays[mkey] = mi.mesh.surface_get_arrays(i)
				var arr: Array = arrays[mkey]
				var part := [mi.skin, arr[Mesh.ARRAY_VERTEX], arr[Mesh.ARRAY_BONES], arr[Mesh.ARRAY_WEIGHTS]]
				for v in StoryCast._skinned(sk, body, part, range((part[1] as PackedVector3Array).size())):
					var r := road * v
					if r.y > crown_at.y:
						crown_at = r
					if not free and absf(r.x - at.x) < 0.2 and r.z > cushion_node.position.z - half.z and r.z < at.z - 0.15 \
							and r.y > cushion - 0.15 and r.y < cushion + 0.15:
						low = minf(low, r.y)
		var skinned := StoryCabin.line(TmRoadCars.manifest(model), "top", crown_at.z) - crown_at.y
		off = maxf(off, absf(top.y - crown_at.y)) if is_finite(crown_at.y) else INF
		if not (skinned >= least_skinned):
			least_skinned = skinned
			worst = "%s %s %s" % [model, seat, label]
		if not (low >= cushion - 0.035 and low <= cushion + 0.01):
			bad_skin.append("%s %s %s rests %.3f off its cushion" % [model, seat, label, low - cushion])
	# lowered only where it must be, and then as far as the tallest on it needs: 5 cm
	for key: String in rooms:
		var room := float(rooms[key])
		if lowered.has(key) and not (absf(room - 0.05) <= 0.001):
			bad_drop.append("%s lowered %.3f, its tallest's crown %.3f under the roof" % [key, lowered[key], room])
		elif not lowered.has(key) and not (room >= 0.0499):
			bad_drop.append("%s not lowered, a crown %.3f under the roof" % [key, room])
	TestHooks.check(covered.size() == n * 3 * TmRoadCars.CARS.size(), "seats_everyone_everywhere",
		"%d of %d (person, car, seat): %d people, %d cars" % [covered.size(), n * 3 * TmRoadCars.CARS.size(), n, TmRoadCars.CARS.size()])
	TestHooks.check(bad_seat.is_empty(), "seats_on_the_cushion", "; ".join(bad_seat))
	TestHooks.check(bad_roof.is_empty(), "seats_under_the_roof", "; ".join(bad_roof))
	TestHooks.check(bad_drop.is_empty() and lowered.has("share0:rear") and lowered.has("share1:rear") and lowered.has("loose:rear"),
		"seats_lowered_only_as_needed", "%d seats lowered (two on one: %s, %s; by \"pos\": %s); %s" % [lowered.size(),
		lowered.get("share0:rear", "no"), lowered.get("share1:rear", "no"), lowered.get("loose:rear", "no"), "; ".join(bad_drop)])
	# and nothing else moved but those parts, the wheel with the driver's seat: each lowered car's
	# cabin against one built afresh, child by child
	var parts := {"driver": 4, "passenger": 3, "rear": 2}       # cushion, back, headrest; the wheel
	var cars_lowered := {}
	for key: String in lowered:
		(cars_lowered.get_or_add(key.get_slice(":", 0), {}) as Dictionary)[key.get_slice(":", 1)] = lowered[key]
	for car_id: String in cars_lowered:
		var entry: Dictionary = sc._cars[car_id]
		var cabin := entry["cabin"] as StoryCabin
		var fresh := StoryCabin.make(String((entry["spec"] as Dictionary)["model"]))
		var drops: Dictionary = cars_lowered[car_id]
		var moved := 0
		var want := 0
		for st: String in drops:
			want += int(parts[st])
		for i in mini(cabin.get_child_count(), fresh.get_child_count()):
			var a := cabin.get_child(i) as Node3D
			var b := fresh.get_child(i) as Node3D
			if a == null or b == null or a.position.is_equal_approx(b.position):
				continue
			moved += 1
			var dy := b.position.y - a.position.y
			if not drops.values().any(func(dd: float) -> bool: return absf(dd - dy) < 0.0005) or not is_equal_approx(a.position.x, b.position.x) \
					or not is_equal_approx(a.position.z, b.position.z):
				bad_parts.append("%s: child %d (%s) moved %s" % [car_id, i, a.name, b.position - a.position])
		if moved != want:
			bad_parts.append("%s: %d parts moved for %s, not %d" % [car_id, moved, drops, want])
		fresh.free()
	TestHooks.check(bad_parts.is_empty() and not lowered.is_empty(), "seats_lowered_whole", "; ".join(bad_parts.slice(0, 12)))
	var deepest := 0.0
	for key: String in lowered:
		deepest = maxf(deepest, float(lowered[key]))
	print("SEATS %d sitters in %d cars (the least headroom: %s), %d seats lowered, the most %.3f m; skinned: the least headroom %.3f m (%s), crowns within %.3f m of the measure" % [
		people.size(), cars.size(), tight, lowered.size(), deepest, least_skinned, worst, off])
	TestHooks.check(least_skinned >= 0.035 and off < 0.02 and bad_skin.is_empty(), "seats_skinned_on_and_under",
		"the least headroom %.3f m (%s); crowns up to %.3f m from where the measure put them; %s" % [least_skinned, worst, off,
		"; ".join(bad_skin.slice(0, 12)) + (" (+%d)" % (bad_skin.size() - 12) if bad_skin.size() > 12 else "")])
	sc.queue_free()
	TestHooks.finish()


func _find(sc: Node, id: String) -> StoryPerson:
	for nd in sc.find_children("*", "", true, false):
		if nd is StoryPerson and String((nd as StoryPerson).spec.get("id", "")) == id and not nd.is_queued_for_deletion():
			return nd
	return null
