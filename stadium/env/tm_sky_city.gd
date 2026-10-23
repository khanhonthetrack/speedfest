class_name TmSkyCity
extends RefCounted
## The Sky maps' city (M19, the owner: "you are really high, between buildings, between
## skyscrapers"): the streets DROP m under the field's level, so the road runs 200-440 m over them;
## on the field, buildings fitted to the road (TmSkyTrack's pieces): one under every rooftop the
## road crosses, one behind every wall it rides and every face it climbs (up to where the road
## curls over its edge), a round tower inside every banked spiral; towers on the free lots beside
## the road rising past it, a few just under it (rooftops to look down on), lower blocks under the
## road; pylons under the raised road; traffic streaming along the streets far below. One layout per
## track (seeded by its uid). Godot axes, the root on the streets (y 0 there).
##
## The lots are 2 x 2 cells (64 m), their buildings inset INSET (12 m streets between them).

const DROP := 200.0              ## m: the streets under the field's level
const STREET_Y := TmMapBuilder.GROUND_Y - DROP
const LOT := 64.0
const INSET := 6.0
const CLEAR := 16.0              ## m: nothing stands closer than this under the road
const FACE_DEPTH := 40.0         ## m: a ridden face's building, back from its face
const MAX_TOWERS := 36
const PYLON := 3.2               ## m square
const SHIP_RISE := 190.0         ## m: the airship flies this much higher than over the City (over the towers)

static var _traffic_mat: ShaderMaterial


static func g2(p: Vector3) -> Vector2:
	return Vector2(-p.x, p.z)


## The Sky field (TmStage puts it on Sky maps).
static func build(builder: TmMapBuilder) -> Node3D:
	var ch := builder.challenge
	var root := Node3D.new()
	root.name = "SkyCity"
	root.position = Vector3(0.0, STREET_Y, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ch.uid)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", 0)
	root.add_child(body)
	var towers := Node3D.new()
	towers.name = "Towers"
	root.add_child(towers)
	var blocks := {}
	var roofs := TmTower.Builder.new()
	var neon := TmNeon.Tubes.new()
	neon.night = TmStadiumEnv.night
	var lows := _clearance(ch)                    # cell (TMNF x, z) -> the lowest road over it (y)
	var near := _road_near(lows)                  # cell -> the highest road within two cells
	var used := {}                                # cells a building of the road's own stands on
	_ground(root, body)
	# the road's own buildings
	for e: Dictionary in ch.extras:
		match String(e["kind"]):
			"roof":
				_roof_building(towers, body, e, rng, used, neon)
			"hub":
				_hub(towers, body, e, rng, used, lows)
	for e: Dictionary in ch.extras:
		if String(e["kind"]) == "ribbon":
			_faces(blocks, roofs, body, e["frames"], ch.extras, rng, used, neon)
	# the lots, nearest the road first (the towers beside it come before the downtown's mix)
	var lots: Array = []
	for lz in 16:
		for lx in 16:
			var cells: Array[Vector2i] = [Vector2i(lx * 2, lz * 2), Vector2i(lx * 2 + 1, lz * 2),
				Vector2i(lx * 2, lz * 2 + 1), Vector2i(lx * 2 + 1, lz * 2 + 1)]
			var d := 99
			for c in cells:
				for dx in range(-3, 4):
					for dz in range(-3, 4):
						if lows.has(c + Vector2i(dx, dz)):
							d = mini(d, maxi(absi(dx), absi(dz)))
			lots.append([d, rng.randf(), lx, lz, cells])
	lots.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var count := 0
	for lot: Array in lots:
		var lx: int = lot[2]
		var lz: int = lot[3]
		var cells: Array[Vector2i] = lot[4]
		var ceiling := INF
		var taken := 0
		var top_near := -INF
		for c in cells:
			ceiling = minf(ceiling, float(lows.get(c, INF)))
			taken += 1 if used.has(c) else 0
			top_near = maxf(top_near, float(near.get(c, -INF)))
		if taken > 0:
			if taken < 4:
				# what's left of a lot beside a road's building: low blocks in its free cells
				for c in cells:
					if not used.has(c):
						_low(blocks, roofs, body, c, float(lows.get(c, INF)), rng, neon)
			continue
		var at := Vector2(-(lx * 2 + 1) * 32.0, (lz * 2 + 1) * 32.0)     # the lot's centre (Godot x, z)
		var room := LOT - INSET * 2.0
		if ceiling < INF:
			# under the road: lower blocks, well under it
			if ceiling - CLEAR - STREET_Y < 14.0 or rng.randf() < 0.12:
				continue
			for c in cells:
				_low(blocks, roofs, body, c, ceiling, rng, neon)
			continue
		if top_near > -INF and count < MAX_TOWERS and rng.randf() < 0.9:
			# beside the road: a tower past it, or (a few) one whose roof lies just under it
			var road_h := top_near - STREET_Y
			var h := road_h + rng.randf_range(30.0, 260.0)
			if rng.randf() < 0.22:
				h = road_h - rng.randf_range(14.0, 55.0)
			_tower(towers, body, at, room, h, rng, count)
			count += 1
			continue
		# further out: the downtown's mix
		if count < MAX_TOWERS and rng.randf() < 0.3:
			_tower(towers, body, at, room, rng.randf_range(220.0, 560.0), rng, count)
			count += 1
		else:
			for c in cells:
				if rng.randf() < 0.8:
					_low(blocks, roofs, body, c, INF, rng, neon)
	_pylons(root, ch, lows, neon)
	TmSkyline._add_blocks(root, blocks, true)
	TmTower.add_mesh(root, roofs, TmTower.shared("roof"), "Roofs", true)
	if not neon.is_empty():
		root.add_child(neon.build("SkyNeon"))
	root.add_child(_traffic())
	TmSkyline._layer(root)
	return root


# --- what the road takes ----------------------------------------------------------------------------

static func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / 32.0), floori(p.z / 32.0))


static func _low_at(lows: Dictionary, c: Vector2i, y: float) -> void:
	lows[c] = minf(float(lows.get(c, INF)), y)


## Each cell (TMNF x, z) the road crosses at any height, and the lowest point of it there (TMNF y):
## TMNF's blocks (their level's base), the sky road's deck and slab, rooftops, and a cell's margin
## round the line where it flies (jumps, drops) and under the bot's line at all.
static func _clearance(ch: TmChallenge) -> Dictionary:
	var lows := {}
	for blk: Dictionary in ch.blocks:
		var c: Vector3i = blk["coord"]
		for u: Array in TmUserTracks.units(String(blk["name"]), int(blk["dir"]), bool(blk["ground"])):
			var w: Vector3i = c + (u[0] as Vector3i)
			_low_at(lows, Vector2i(w.x, w.z), w.y * 8.0)
	for e: Dictionary in ch.extras:
		match String(e["kind"]):
			"ribbon":
				for fr: Dictionary in e["frames"]:
					for x: float in [-TmSkyTrack.EDGE, 0.0, TmSkyTrack.EDGE]:
						var p := TmSkyPieces._at(fr, x, -TmSkyPieces.UNDER)
						_low_at(lows, _cell(p), p.y)
			"roof":
				var lo: Vector3 = e["lo"]
				var hi: Vector3 = e["hi"]
				for x in range(floori(lo.x / 32.0 + 0.01), ceili(hi.x / 32.0 - 0.01)):
					for z in range(floori(lo.z / 32.0 + 0.01), ceili(hi.z / 32.0 - 0.01)):
						_low_at(lows, Vector2i(x, z), float(e["y"]) - TmSkyPieces.ROOF_SLAB)
	for line: Array in [ch.path] + ch.alt_paths:
		for pt: Dictionary in line:
			var p: Vector3 = pt["p"]
			var c := Vector2i(floori(-p.x / 32.0), floori(p.z / 32.0))
			var r := 1 if int(pt.get("mode", 0)) == TmTrackBuilder.Drive.BLIND else 0
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					_low_at(lows, c + Vector2i(dx, dz), p.y - 6.0)
	return lows


## Each cell within two of the road: the highest of the road there (TMNF y).
static func _road_near(lows: Dictionary) -> Dictionary:
	var out := {}
	for c: Vector2i in lows:
		var y := float(lows[c])
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				var q := c + Vector2i(dx, dz)
				out[q] = maxf(float(out.get(q, -INF)), y)
	return out


# --- the buildings ---------------------------------------------------------------------------------

## A rectangle (TMNF x/z bounds) as Godot's (x, z) Rect2.
static func _rect_g(lo: Vector3, hi: Vector3) -> Rect2:
	return Rect2(-hi.x, lo.z, hi.x - lo.x, hi.z - lo.z)


static func _mark_used(used: Dictionary, lo: Vector3, hi: Vector3) -> void:
	for x in range(floori(lo.x / 32.0 + 0.01), ceili(hi.x / 32.0 - 0.01)):
		for z in range(floori(lo.z / 32.0 + 0.01), ceili(hi.z / 32.0 - 0.01)):
			used[Vector2i(x, z)] = true


## A rooftop's building: glass walls from the street to under the roof's slab (the roof deck and
## its edge are the road's, TmSkyPieces), lit floors, a neon ring a floor down.
static func _roof_building(towers: Node3D, body: StaticBody3D, e: Dictionary, rng: RandomNumberGenerator,
		used: Dictionary, neon: TmNeon.Tubes) -> void:
	var lo: Vector3 = e["lo"]
	var hi: Vector3 = e["hi"]
	var top := float(e["y"]) - TmSkyPieces.ROOF_SLAB - STREET_Y
	var r := _rect_g(lo, hi)
	_slab(towers, r, top, rng, neon)
	TmSkyline._collide(body, r, top + TmSkyPieces.ROOF_SLAB)
	_mark_used(used, lo, hi)


## A plain building on a rectangle (Godot x, z): glass walls with their rooms, from the street to h.
static func _slab(parent: Node3D, r: Rect2, h: float, rng: RandomNumberGenerator, neon: TmNeon.Tubes, seed := -1) -> void:
	var b := TmTower.Builder.new()
	var poly := TmSkyline._rect(r.get_center(), r.size)
	TmTower.walls(b, poly, 0.0, h, float(rng.randi() % 4000) * 6.0)
	var glass: String = TmSkyline.GLASS_STYLES[rng.randi() % TmSkyline.GLASS_STYLES.size()]
	var mat := TmTower.material(glass, seed if seed >= 0 else rng.randi() % 997, rng.randf_range(3.7, 4.3), 3.0)
	TmTower.add_mesh(parent, b, mat, "Slab", true)
	var col := TmNeon.pick(rng.randi(), 0.9)
	if col >= 0:
		TmNeon.ring(neon, poly, h - 1.0, col, 0.18, 0.25, 0.0)
		TmNeon.ring(neon, poly, 14.0, col, 0.18, 0.25, 0.0)


## A spiral's round tower, inside the banked road (clear of its low inner edge), from the street to
## past its top.
static func _hub(towers: Node3D, body: StaticBody3D, e: Dictionary, rng: RandomNumberGenerator, used: Dictionary,
		lows: Dictionary) -> void:
	var c: Vector3 = e["c"]
	if float(e["bank"]) > deg_to_rad(70.0):
		return                 # a wall round the inside of a ring: its building is outside it
	var key := Vector2i(roundi(c.x), roundi(c.z))
	if used.has(key):
		return                 # (each quarter of a spiral adds one: one tower)
	used[key] = true
	var rad := float(e["r"]) - TmSkyTrack.EDGE - 5.0
	if rad < 10.0:
		return
	# the tower's top: past the spiral's highest point
	var h := float(e["hi"]) - STREET_Y + rng.randf_range(60.0, 220.0)
	var spec := TmSkyline._tower_spec(rng, 0.8, absi(key.x * 7919 + key.y * 104729))
	spec["height"] = h
	spec["w"] = rad * 2.0 / 1.18
	spec["d"] = rad * 2.0 / 1.25
	spec["shape"] = "circle"
	spec["tiers"] = [[1.0, 1.0]]
	spec["crown"] = "spire"
	spec["podium"] = 8.0
	spec["shadows"] = true
	spec["neon"] = TmNeon.pick(rng.randi(), 1.0)
	spec["neon_full"] = true
	spec["screen"] = false
	var at := g2(c)
	TmSkyline._tower(towers, spec, at, 0)
	var half := Vector2(rad, rad) * 0.7
	TmSkyline._collide(body, Rect2(at - half, half * 2.0), h)
	for dx in range(-1, 1):
		for dz in range(-1, 1):
			used[_cell(c + Vector3(dx * 32.0 + 16.0, 0.0, dz * 32.0 + 16.0))] = true


## The buildings behind the sky road where it rides a wall or climbs a face: each run of frames
## whose deck stands near upright (its up within 50 degrees of level), facing along an axis, gets a
## building whose face stands just behind the deck's slab, FACE_DEPTH m deep, as wide as the deck
## spans along it; up past the wall (a tower going on up), or, where the road curls over its
## top or something else passes over it, to just under that.
static func _faces(blocks: Dictionary, roofs: TmTower.Builder, body: StaticBody3D, frames: Array, extras: Array,
		rng: RandomNumberGenerator, used: Dictionary, neon: TmNeon.Tubes) -> void:
	var runs: Array = []
	var cur: Array = []
	for fr: Dictionary in frames:
		var u: Vector3 = fr["u"]
		if absf(u.y) < 0.64:
			cur.append(fr)
		elif not cur.is_empty():
			runs.append(cur)
			cur = []
	if not cur.is_empty():
		runs.append(cur)
	for run: Array in runs:
		if run.size() < 4:
			continue
		var n := Vector3.ZERO
		for fr: Dictionary in run:
			n += fr["u"] as Vector3
		n.y = 0.0
		n = n.normalized()
		var h := TmSkyTrack._axis(n)
		if h < 0:
			# not along an axis: snap it if it's close
			for k in 4:
				if TmTrackBuilder.vec(k).dot(n) > 0.9:
					h = k
		if h < 0:
			continue
		n = TmTrackBuilder.vec(h)
		var a := Vector3(n.z, 0.0, -n.x)               # along the face
		var plane := INF
		var amin := INF
		var amax := -INF
		var ytop := -INF
		for fr: Dictionary in run:
			for x: float in [-TmSkyTrack.EDGE, TmSkyTrack.EDGE]:
				var p := TmSkyPieces._at(fr, x, -TmSkyPieces.UNDER)
				plane = minf(plane, p.dot(n))
				amin = minf(amin, p.dot(a))
				amax = maxf(amax, p.dot(a))
				ytop = maxf(ytop, p.y)
		plane -= 0.4
		amin -= 3.0
		amax += 3.0
		# the footprint in TMNF metres: from the plane back FACE_DEPTH along -n
		var c0 := n * plane + a * amin
		var c1 := n * (plane - FACE_DEPTH) + a * amax
		var lo := Vector3(minf(c0.x, c1.x), 0.0, minf(c0.z, c1.z))
		var hi := Vector3(maxf(c0.x, c1.x), 0.0, maxf(c0.z, c1.z))
		# what passes over it: the road elsewhere (not this run's frames), rooftops
		var limit := INF
		for e: Dictionary in extras:
			if String(e["kind"]) == "ribbon":
				for fr: Dictionary in e["frames"]:
					if fr in run:
						continue
					for x: float in [-TmSkyTrack.EDGE, 0.0, TmSkyTrack.EDGE]:
						var p := TmSkyPieces._at(fr, x, -TmSkyPieces.UNDER)
						if p.x > lo.x + 0.5 and p.x < hi.x - 0.5 and p.z > lo.z + 0.5 and p.z < hi.z - 0.5:
							limit = minf(limit, p.y - 0.6)
			elif String(e["kind"]) == "roof":
				var rl: Vector3 = e["lo"]
				var rh: Vector3 = e["hi"]
				if rl.x < hi.x and rh.x > lo.x and rl.z < hi.z and rh.z > lo.z:
					limit = minf(limit, float(e["y"]) - TmSkyPieces.ROOF_SLAB)
		var top := ytop + rng.randf_range(40.0, 220.0) if limit == INF else limit
		top = minf(top, maxf(limit, ytop + 4.0)) if limit < INF else top
		var r := _rect_g(lo, hi)
		_slab(body.get_parent().get_node("Towers"), r, top - STREET_Y, rng, neon)
		TmSkyline._collide(body, r, top - STREET_Y)
		_mark_used(used, lo + Vector3(1.0, 0.0, 1.0), hi - Vector3(1.0, 0.0, 1.0))


## A tower on a lot (its centre `at`, Godot x, z), `room` m across, h tall (from the street).
static func _tower(towers: Node3D, body: StaticBody3D, at: Vector2, room: float, h: float, rng: RandomNumberGenerator,
		k: int) -> void:
	var spec := TmSkyline._tower_spec(rng, 0.9, absi(int(at.x) * 7919 + int(at.y) * 104729 + k))
	spec["height"] = h
	var w := minf(h / rng.randf_range(6.0, 9.0), room / 1.18)
	spec["w"] = w
	spec["d"] = minf(w * rng.randf_range(0.8, 1.05), room / 1.25)
	spec["shadows"] = true
	spec["neon"] = spec.get("neon", TmNeon.pick(hash(int(spec["seed"]) * 13 + 5), 1.0))
	spec["neon_r"] = 0.3
	var turn := absi(int(spec["seed"])) % 4
	TmSkyline._tower(towers, spec, at, turn)
	var e := Vector2(float(spec["w"]) * 0.59, float(spec["d"]) * 0.625)
	if turn % 2 == 1:
		e = Vector2(e.y, e.x)
	TmSkyline._collide(body, Rect2(at - e, e * 2.0), h)


## A lower block on a cell, under `ceiling` (TMNF y; INF: none) by CLEAR.
static func _low(blocks: Dictionary, roofs: TmTower.Builder, body: StaticBody3D, c: Vector2i, ceiling: float,
		rng: RandomNumberGenerator, neon: TmNeon.Tubes) -> void:
	var hmax := 140.0 if ceiling == INF else ceiling - CLEAR - STREET_Y
	if hmax < 12.0:
		return
	var h := minf(rng.randf_range(18.0, 110.0), hmax)
	var x0 := -(c.x + 1) * 32.0 + 3.0 + rng.randf_range(0.0, 2.0)
	var x1 := -c.x * 32.0 - 3.0 - rng.randf_range(0.0, 2.0)
	var z0 := c.y * 32.0 + 3.0 + rng.randf_range(0.0, 2.0)
	var z1 := (c.y + 1) * 32.0 - 3.0 - rng.randf_range(0.0, 2.0)
	var r := Rect2(x0, z0, x1 - x0, z1 - z0)
	TmSkyline._box(blocks, roofs, 0, r, h, 0.7, rng, true, neon, true)
	TmSkyline._collide(body, r, h)


## Pylons under the raised road: a steel column from the street up to the road's underside under
## every third TMNF road block and every 96 m of level sky road, neon strips up two faces.
static func _pylons(root: Node3D, ch: TmChallenge, lows: Dictionary, neon: TmNeon.Tubes) -> void:
	var b := TmTower.Builder.new()
	var spots := []                       # [Godot (x, z), top (TMNF y)]
	var k := 0
	for blk: Dictionary in ch.blocks:
		var name := String(blk["name"])
		if not name.begins_with("StadiumRoadMain") or name.contains("Slope") or name.contains("GTCurve"):
			continue
		k += 1
		if k % 3 != 1:
			continue
		var c: Vector3i = blk["coord"]
		spots.append([Vector2(-(c.x + 0.5) * 32.0, (c.z + 0.5) * 32.0), c.y * 8.0 + 0.2])
	for e: Dictionary in ch.extras:
		if String(e["kind"]) != "ribbon":
			continue
		var next := 48.0
		for fr: Dictionary in e["frames"]:
			var u: Vector3 = fr["u"]
			if float(fr["s"]) < next or u.y < 0.995:
				continue
			next = float(fr["s"]) + 96.0
			var p := TmSkyPieces._at(fr, 0.0, -TmSkyPieces.UNDER)
			spots.append([g2(p), p.y])
	for sp: Array in spots:
		var at: Vector2 = sp[0]
		var top := float(sp[1]) - STREET_Y
		var poly := TmSkyline._rect(at, Vector2(PYLON, PYLON))
		TmTower.walls(b, poly, 0.0, top)
		for s: float in [-1.0, 1.0]:
			var q := Vector3(at.x + s * (PYLON * 0.5 + 0.1), 0.0, at.y)
			neon.add(PackedVector3Array([q + Vector3.UP * 4.0, q + Vector3.UP * (top - 2.0)]), 0.12, TmNeon.ICE)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.16, 0.17, 0.19)
	steel.metallic = 0.7
	steel.roughness = 0.35
	TmTower.add_mesh(root, b, steel, "Pylons", true)


## The streets under the field: paving with collision (a car that falls lands there).
static func _ground(root: Node3D, body: StaticBody3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Streets"
	var pm := PlaneMesh.new()
	pm.size = Vector2(1024.0 + 160.0, 1024.0 + 160.0)
	mi.mesh = pm
	mi.material_override = TmSkyline.paving()
	mi.position = Vector3(-512.0, 0.05, 512.0)
	root.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1024.0 + 400.0, 2.0, 1024.0 + 400.0)
	cs.shape = box
	cs.position = Vector3(-512.0, -1.0, 512.0)
	body.add_child(cs)


## Traffic far below: streams of headlights and tail lights moving along every street between the
## lots (and on past the map's edge), a shader on thin strips just over the paving.
static func _traffic() -> MeshInstance3D:
	if _traffic_mat == null:
		_traffic_mat = ShaderMaterial.new()
		_traffic_mat.shader = preload("res://env/tm_traffic.gdshader")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var far := 900.0
	for i in 17:
		var k := i * LOT
		for along_x: bool in [true, false]:
			# a strip 9 m wide down the street's middle, u across it, v along it (m)
			var a: Vector3
			var b: Vector3
			if along_x:
				a = Vector3(far, 0.25, k)
				b = Vector3(-1024.0 - far, 0.25, k)
			else:
				a = Vector3(-k, 0.25, -far)
				b = Vector3(-k, 0.25, 1024.0 + far)
			var d := (b - a).normalized()
			var side := Vector3(-d.z, 0.0, d.x) * 4.5
			var len := a.distance_to(b)
			var seed := float(i * 2 + (1 if along_x else 0)) * 0.37
			var q := [a - side, a + side, b + side, b - side]
			var t := [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, len), Vector2(0.0, len)]
			for idx: int in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3.UP)
				st.set_uv(t[idx])
				st.set_uv2(Vector2(seed, 0.0))
				st.add_vertex(q[idx])
	var mi := MeshInstance3D.new()
	mi.name = "Traffic"
	mi.mesh = st.commit()
	mi.material_override = _traffic_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
