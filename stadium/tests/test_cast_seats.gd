extends Node
## The cast seated in the cars (PLAN M20-9): StoryCabin is laid out for the 1.83 m Mannequin, and
## people of other heights sit by their own bodies (StoryCast.seated: the lowest of the hips and
## thighs, the back of them, the crown, in the clip):
## - the measure itself: the Mannequin's seat a little into the cushion (its layout), its crown in
##   Sitting_Idle where the layout's StoryCabin.CROWN says;
## - every cast member and the Mannequin in every road car, in every seat (Gus, the tallest, in front
##   and behind; the drivers in Driving, their heads further back): their seat rests on the cushion
##   as deep and as far back as the Mannequin's in that clip, their crown under the roof; a seat is
##   lowered only where a crown would come within 5 cm of the roof, then just that far, the sitter
##   with it;
## - the bodies as skinned in the shot (not the measure): every crown clear of its roof, where the
##   measure put it.

const CUSHION := 0.06                   ## half a cushion's thickness (StoryCabin._build)
const BUILT := 0.42                     ## a cushion's middle over the Mannequin's root


func _ready() -> void:
	var mannequin := (load(StoryPerson.GLB) as PackedScene).instantiate() as Node3D
	add_child(mannequin)
	var ok := true
	var said: Array[String] = []
	for clip in ["Sitting_Idle", "Driving"]:
		var m := StoryCast.mannequin_seated(self, clip)
		var seat: Vector2 = m["seat"]
		var crown: Vector2 = m["crown"]
		# on the cushion (its top 0.48 m over the root), 0-3 cm into it, the pelvis behind the feet
		ok = ok and seat.x > BUILT + CUSHION - 0.03 and seat.x < BUILT + CUSHION and seat.y < -0.25
		if clip == "Sitting_Idle":
			ok = ok and absf(crown.x - StoryCabin.CROWN.x) < 0.015 and absf(crown.y - StoryCabin.CROWN.y) < 0.05
		said.append("%s: seat %s, crown %s" % [clip, seat, crown])
	TestHooks.check(ok, "seats_mannequin_measured", "; ".join(said) + " (the layout's crown %s)" % StoryCabin.CROWN)
	mannequin.free()
	var ids := StoryCast.ids()
	var cars: Array = []
	var people: Array = []
	var order := Array(ids)
	order.sort_custom(func(a: String, b: String) -> bool:
		return float(StoryCast.meta(a).get("height", 0.0)) > float(StoryCast.meta(b).get("height", 0.0)))
	order = order.slice(0, 2) + [""] + order.slice(2)      # the Mannequin (1.83 m) among them
	# each car three times over: the tallest driving, beside, then behind, the rest round the seats
	var k := 0
	for c: Array in TmRoadCars.CARS:
		for row in 3:
			var id := "c%d" % k
			cars.append({"id": id, "model": String(c[0]), "left": 3.0 * k, "cabin": true})
			var seats: Array = [["driver", "passenger", "rear"], ["passenger", "rear", "driver"], ["rear", "driver", "passenger"]][row]
			for n in mini(order.size(), 3):
				var clip := "Driving" if seats[n] == "driver" else "Sitting_Idle"
				var who := String(order[n])
				people.append({"id": "%s_%s" % [id, who if who != "" else "mannequin"], "who": who, "car": id,
					"seat": seats[n], "clip": clip})
			k += 1
	var d := {"id": "seats_test", "shots": [{"id": "all", "dur": 2.0, "cars": cars, "people": people,
		"camera": {"keys": [{"u": 0, "pos": [0.0, 3.0, -6.0], "look": [0.0, 1.0, 0.0]}]}}]}
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, StoryState.new(), false)
	sc.seek(0.5)
	var bad_seat: Array[String] = []
	var bad_roof: Array[String] = []
	var bad_drop: Array[String] = []
	var lowered := 0
	var drops: Array[String] = []
	for p: Dictionary in people:
		var who := String(p["who"])
		var label := who if who != "" else "Mannequin"
		var person := _find(sc, String(p["id"]))
		var entry: Dictionary = sc._cars[String(p["car"])]
		var cabin := entry["cabin"] as StoryCabin
		var model := String((entry["spec"] as Dictionary)["model"])
		var seat := String(p["seat"])
		var at: Vector3 = StoryCabin.points(model)[seat]
		var body := person._body
		var road := cabin.global_transform.affine_inverse() * body.global_transform
		var m := StoryCast.seated(who, body, String(p["clip"])) if who != "" else StoryCast.mannequin_seated(self, String(p["clip"]))
		var ref := StoryCast.mannequin_seated(self, String(p["clip"]))
		var s := road * Vector3(0.0, (m["seat"] as Vector2).x, (m["seat"] as Vector2).y)
		var top := road * Vector3(0.0, (m["crown"] as Vector2).x, (m["crown"] as Vector2).y)
		var cushion := (cabin._seats[seat][0] as Node3D).position.y + CUSHION
		var drop := float(cabin._drops.get(seat, 0.0))
		# as deep in the cushion and as far back as the Mannequin
		var deep := (s.y - cushion) - ((ref["seat"] as Vector2).x - BUILT - CUSHION)
		var back := s.z - (at.z + (ref["seat"] as Vector2).y)
		if absf(deep) > 0.004 or absf(back) > 0.004:
			bad_seat.append("%s %s %s: %.3f deeper, %.3f further back than the Mannequin" % [model, seat, label, -deep, -back])
		var room := StoryCabin.line(TmRoadCars.manifest(model), "top", top.z) - top.y
		if room < 0.045:
			bad_roof.append("%s %s %s: crown %.3f under the roof" % [model, seat, label, room])
		# lowered only where it must be, and then to 5 cm
		if drop > 0.0:
			lowered += 1
			drops.append("%s %s %s %.3f" % [model, seat, label, drop])
			if absf(room - 0.05) > 0.003:
				bad_drop.append("%s %s %s lowered %.3f, its crown %.3f under the roof" % [model, seat, label, drop, room])
		elif room < 0.0499:
			bad_drop.append("%s %s %s not lowered, crown %.3f under the roof" % [model, seat, label, room])
	TestHooks.check(bad_seat.is_empty(), "seats_on_the_cushion", "; ".join(bad_seat))
	TestHooks.check(bad_roof.is_empty(), "seats_under_the_roof", "; ".join(bad_roof))
	TestHooks.check(bad_drop.is_empty(), "seats_lowered_only_as_needed", "%d lowered; %s" % [lowered, "; ".join(bad_drop)])
	print("SEATS lowered %d of %d: %s" % [lowered, people.size(), ", ".join(drops)])
	# the bodies as they are in the shot, skinned (not the measure): every crown clear of its roof,
	# where the measure put it
	var arrays := {}
	var worst := ""
	var least_skinned := INF
	var off := 0.0
	for p: Dictionary in people:
		var person := _find(sc, String(p["id"]))
		var entry: Dictionary = sc._cars[String(p["car"])]
		var cabin := entry["cabin"] as StoryCabin
		var model := String((entry["spec"] as Dictionary)["model"])
		var mm := TmRoadCars.manifest(model)
		var top := Vector3(0.0, -INF, 0.0)
		var body := person._body
		var sk := StoryCast.skeleton(body)
		var road := cabin.global_transform.affine_inverse() * body.global_transform
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			if mi.skin == null:
				continue
			for i in mi.mesh.get_surface_count():
				var key := "%d:%d" % [mi.mesh.get_instance_id(), i]
				if not arrays.has(key):
					arrays[key] = mi.mesh.surface_get_arrays(i)
				var arr: Array = arrays[key]
				var part := [mi.skin, arr[Mesh.ARRAY_VERTEX], arr[Mesh.ARRAY_BONES], arr[Mesh.ARRAY_WEIGHTS]]
				for v in StoryCast._skinned(sk, body, part, range((part[1] as PackedVector3Array).size())):
					var r := road * v
					if r.y > top.y:
						top = r
		var room := StoryCabin.line(mm, "top", top.z) - top.y
		var who := String(p["who"])
		var m := StoryCast.seated(who, body, String(p["clip"])) if who != "" else StoryCast.mannequin_seated(self, String(p["clip"]))
		off = maxf(off, absf((road * Vector3(0.0, (m["crown"] as Vector2).x, 0.0)).y - top.y))
		if room < least_skinned:
			least_skinned = room
			worst = "%s %s %s" % [model, p["seat"], who if who != "" else "Mannequin"]
	print("SEATS skinned: the least headroom %.3f m (%s); crowns within %.3f m of the measure" % [least_skinned, worst, off])
	TestHooks.check(least_skinned >= 0.035 and off < 0.02, "seats_skinned_crowns_clear",
		"the least headroom %.3f m (%s); crowns up to %.3f m from where the measure put them" % [least_skinned, worst, off])
	sc.queue_free()
	TestHooks.finish()


func _find(sc: Node, id: String) -> StoryPerson:
	for n in sc.find_children("*", "", true, false):
		if n is StoryPerson and String((n as StoryPerson).spec.get("id", "")) == id and not n.is_queued_for_deletion():
			return n
	return null
