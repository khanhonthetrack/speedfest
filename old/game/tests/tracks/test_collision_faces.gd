extends Node3D
## Every road collision triangle must face the side cars come from (deck up, barriers inward). The
## trimesh keeps backface collision on as a safety net, but correct winding is what keeps a car
## pressed into the deck (e.g. 27 g in a loop) from being pushed out the wrong side. Rays that
## ignore back faces:
##   deck:     from 1.5 m above the road down along -normal, at 3 lateral offsets, every 3 m
##             (gaps excluded) -> must hit the deck within 2 m.
##   barriers: where a wall is built on a side, from 0.8 m above the road centre sideways -> must
##             hit the barrier before 6 m past the road edge.
## Args: --track=all|<id>

func _ready() -> void:
	var which: String = TestHooks.arg("track", "all")
	var ids: Array = TrackDefs.IDS if which == "all" else [which]
	for id in ids:
		var track := Track.build(id, false)
		add_child(track)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(track, id)
		track.queue_free()
		await get_tree().physics_frame
	TestHooks.finish()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.hit_back_faces = false
	q.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(q)


func _check(track: Track, id: String) -> void:
	var path := track.path
	var data := track.data
	var gaps: Array = data["gaps"]
	var loops: Array = []
	for l in data["loops"]:
		loops.append([l["from"], l["to"]])
	var deck_n := 0
	var deck_miss: Array = []
	var wall_n := 0
	var wall_miss: Array = []
	var d := 5.0
	while d < path.length - 5.0:
		if TrackBuilder.in_ranges(d, gaps, 3.0):
			d += 3.0
			continue
		var f := path.sample_transform(d)
		var hw := path.width_at(d) * 0.5
		for lat in [-hw * 0.6, 0.13, hw * 0.6]:
			var from: Vector3 = f.origin + f.basis.y * 1.5 + f.basis.x * float(lat)
			deck_n += 1
			if _ray(from, from - f.basis.y * 3.5).is_empty():
				deck_miss.append("%.0f/%.1f" % [d, lat])
		# barriers (not in loops, where the builder leaves them out)
		if not TrackBuilder.in_ranges(d, loops, 3.0):
			var mode := TrackBuilder.wall_mode_at(data, d)
			for side in [1.0, -1.0]:
				var on: bool = mode == "both" or (mode == "right" and side > 0.0) or (mode == "left" and side < 0.0)
				if not on:
					continue
				var from: Vector3 = f.origin + f.basis.y * 0.8
				wall_n += 1
				if _ray(from, from + f.basis.x * side * (hw + 6.0)).is_empty():
					wall_miss.append("%.0f%s" % [d, "R" if side > 0.0 else "L"])
		d += 3.0
	print("%s deck rays=%d miss=%d %s | wall rays=%d miss=%d %s" % [id, deck_n, deck_miss.size(), str(deck_miss.slice(0, 8)), wall_n, wall_miss.size(), str(wall_miss.slice(0, 8))])
	TestHooks.check(deck_n > minf(300.0, path.length * 0.5) and deck_miss.is_empty(), id + "_deck_faces_up", "%d of %d miss: %s" % [deck_miss.size(), deck_n, str(deck_miss.slice(0, 8))])
	# a few misses can be legit openings (barrier gaps at ramps); more means flipped faces
	TestHooks.check(wall_n > 50 and wall_miss.size() <= wall_n / 50, id + "_barrier_faces_in", "%d of %d miss: %s" % [wall_miss.size(), wall_n, str(wall_miss.slice(0, 8))])
