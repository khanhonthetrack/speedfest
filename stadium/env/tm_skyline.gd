class_name TmSkyline
extends RefCounted
## The city around the Stadium (our own; TMNF has none: the owner's ask for tall, realistic
## buildings, for strong PCs): a street grid on the plain below the Stadium's edge, skyscraper
## districts (TmTower) whose tops rise over the stands (supertalls behind the grandstands, where the
## roofs hide all but the tallest; downtowns past the low terraces at the ends), and blocks of
## lower glass and masonry buildings in between, thinning out to the city's rim.
##
## Coordinates: the Stadium's (Godot axes centred on the field), y up from the plain (TmStadiumBuild
## BOTTOM). TmStage places it under the Stadium on 32 x 32 maps. The layout is fixed (one seed), so
## every player sees the same city. The lower blocks are merged per style and sector (a few dozen
## draws); the towers are their own nodes (podium, facade, roof, plant, mast, light).

const FAR := 9000.0             ## game cameras' far plane (m): the city's farthest towers show
const PITCH := 150.0            ## m, block to block
const STREET := 26.0            ## m, kerb to kerb
const RADIUS := 5200.0          ## m, the city's rim
const SECTORS := 12             ## the merged blocks, cut by angle (so whole sectors are culled)
const LAYER := 2                ## the city's render layer (lit by the moon, not the floodlights)
const ASSET_SHARE := 0.6        ## of the towers, this share are the owner's buildings when one fits
const STOREFRONT := 5.6         ## m: the lower buildings' base storey (from the plaza, 0.4 m up; no shops)
const SEED := 20261020
const HALF := (PITCH - STREET) * 0.5 - 4.5     ## a block's half width inside its pavements (m)
## The skyscraper districts: centre (x, z), radius (m), strength (0..1: how tall).
const DISTRICTS := [
	[Vector2(2450.0, 200.0), 900.0, 1.0],     # downtown past one end
	[Vector2(-2350.0, -300.0), 800.0, 0.95],  # and past the other
	[Vector2(250.0, 1800.0), 700.0, 0.85],    # behind a grandstand
	[Vector2(-450.0, -1750.0), 650.0, 0.85],  # behind the other
	[Vector2(2300.0, 1900.0), 600.0, 0.7],
	[Vector2(-2200.0, 1800.0), 550.0, 0.6],
	[Vector2(2100.0, -1900.0), 500.0, 0.6],
	[Vector2(-2000.0, -1850.0), 450.0, 0.5],
]
## The landmarks: hand-placed supertalls (their tops clear the grandstands' roofs from the field).
const LANDMARKS := [
	{"at": Vector2(150.0, 1500.0), "height": 820.0, "w": 86.0, "d": 86.0, "shape": "chamfer", "glass": "silver",
		"crown": "spire", "tiers": [[0.4, 1.0], [0.65, 0.84], [0.85, 0.68], [1.0, 0.5]]},
	{"at": Vector2(-300.0, -1500.0), "height": 760.0, "w": 82.0, "d": 82.0, "shape": "circle", "glass": "blue",
		"crown": "spire", "tiers": [[0.55, 1.0], [0.82, 0.8], [1.0, 0.6]]},
	{"at": Vector2(750.0, 1650.0), "height": 640.0, "w": 76.0, "d": 66.0, "shape": "rounded", "glass": "dark",
		"crown": "slant", "tiers": [[0.7, 1.0], [1.0, 0.85]]},
	{"at": Vector2(-900.0, -1650.0), "height": 620.0, "w": 74.0, "d": 74.0, "shape": "octagon", "glass": "green",
		"crown": "ring", "fins": 4, "tiers": [[0.6, 1.0], [0.85, 0.86], [1.0, 0.74]]},
	{"at": Vector2(-450.0, 1650.0), "height": 560.0, "w": 68.0, "d": 68.0, "shape": "rect", "glass": "bronze",
		"crown": "flat", "fins": 2, "tiers": [[0.55, 1.0], [0.85, 0.82], [1.0, 0.66]]},
	{"at": Vector2(500.0, -1600.0), "height": 540.0, "w": 70.0, "d": 62.0, "shape": "chamfer", "glass": "silver",
		"crown": "slant", "tiers": [[0.65, 1.0], [1.0, 0.8]]},
	{"at": Vector2(2100.0, 150.0), "height": 680.0, "w": 84.0, "d": 74.0, "shape": "chamfer", "glass": "blue",
		"crown": "spire", "tiers": [[0.45, 1.0], [0.75, 0.8], [1.0, 0.6]]},
	{"at": Vector2(-2050.0, -300.0), "height": 640.0, "w": 80.0, "d": 80.0, "shape": "rect", "glass": "dark",
		"crown": "flat", "fins": 3, "tiers": [[0.5, 1.0], [0.8, 0.82], [1.0, 0.66]]},
]
const GLASS_STYLES := ["blue", "green", "silver", "dark", "bronze"]
const MASONRY_STYLES := ["stone", "brick", "concrete", "white"]

const FIELD_TOWERS := 40         ## a city track's towers on the field, at most
const FIELD_INSET := 4.0         ## a field building's pavement inside its cells (m)

static var _ground_mat: ShaderMaterial
static var _paving: ShaderMaterial


static var _task := -1


## Builds the city on a worker thread and adds it under `holder` when it is done (a race loads
## without waiting for it; it appears a moment later). The materials every building shares are
## made here first, on the main thread; leaving the scene waits for a build still running.
static func build_async(holder: Node3D) -> void:
	TmTower.shared("roof")
	TmTower.shared("plant")
	TmTower.shared("steel")
	TmTower.shared("beacon")
	_grass()
	TmMaterials.get_material("concrete")
	TmCityAssets.catalogue()
	TmCitySigns._screen_material()
	for c in TmNeon.COLOURS.size():
		TmNeon.material(c, TmStadiumEnv.night)
	wait()
	if TestHooks.has_arg("shot"):
		holder.add_child(build())          # a screenshot shows the city whatever the frame count
		return
	var ref: WeakRef = weakref(holder)
	_task = WorkerThreadPool.add_task(func() -> void:
		var city := build()
		_attach.call_deferred(ref, city), false, "city")
	holder.tree_exiting.connect(wait)


static func _attach(ref: WeakRef, city: Node3D) -> void:
	wait()
	var h: Node3D = ref.get_ref()
	if h == null or not is_instance_valid(h) or not h.is_inside_tree():
		city.free()
		return
	h.add_child(city)


## Waits for a city still being built (TmSkyline.build_async).
static func wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## The whole city as one node (its origin at the plain under the field's centre).
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Skyline"
	_ground(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var taken := {}           # cells a landmark stands on
	var towers := Node3D.new()
	towers.name = "Towers"
	root.add_child(towers)
	var k := 0
	for spec: Dictionary in LANDMARKS:
		var cell := _cell_of(spec["at"])
		var s := spec.duplicate()
		s["seed"] = 101 + k * 37
		s["shadows"] = false
		s["podium"] = 18.0
		s["bay"] = 4.5
		s["neon"] = [TmNeon.CYAN, TmNeon.MAGENTA, TmNeon.VIOLET, TmNeon.ICE][k % 4]
		s["neon_r"] = 0.9
		_tower(towers, s, Vector2(cell) * PITCH)
		taken[cell] = true
		k += 1
	# the blocks, merged per style and sector
	var blocks := {}          # "style:sector" -> TmTower.Builder
	var roofs := []           # per sector
	var plazas := []          # per sector: the parks' grass
	for i in SECTORS:
		roofs.append(TmTower.Builder.new())
		plazas.append(TmTower.Builder.new())
	var neon := TmNeon.Tubes.new()       # the lower blocks' neon (crowns, near the Stadium)
	neon.night = TmStadiumEnv.night
	neon.sides = 4
	var n := int(ceil(RADIUS / PITCH))
	for ix in range(-n, n + 1):
		for iz in range(-n, n + 1):
			var c := Vector2(ix * PITCH, iz * PITCH)
			if _inside(c) or c.length() > RADIUS - PITCH * 0.5:
				continue
			var key := Vector2i(ix, iz)
			var t := _tall(c) * (0.85 + rng.randf() * 0.3)
			if taken.has(key):
				continue
			var sector := _sector(c)
			if t > 0.42 and rng.randf() < 0.2 + 0.5 * t:
				_tower_block(towers, blocks, roofs[sector], sector, c, t, _tower_spec(rng, t, ix * 7919 + iz * 104729), rng, neon)
				continue
			var park := t < 0.25 and rng.randf() < 0.06
			if park:
				_park(plazas[sector], c)
				continue
			_lots(blocks, roofs[sector], sector, c, t, rng, neon)
	_add_blocks(root, blocks, false)
	if not neon.is_empty():
		root.add_child(neon.build("CityNeon"))
	for i in SECTORS:
		TmTower.add_mesh(root, roofs[i], TmTower.shared("roof"), "Roofs_%d" % i, false)
		TmTower.add_mesh(root, plazas[i], _grass(), "Parks_%d" % i, false)
	_layer(root)
	return root


## Puts the city on its own render layer (LAYER): the Stadium's floodlights don't reach it.
static func _layer(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = LAYER
	for c in n.get_children():
		_layer(c)


## The merged lower buildings' meshes, one per style and sector ("style:sector" -> builder).
static func _add_blocks(root: Node3D, blocks: Dictionary, shadows: bool) -> void:
	var shared := {}
	for key: String in blocks:
		var style := key.get_slice(":", 0)
		if not shared.has(style):
			var mat := TmTower.masonry(style, style.hash() % 997, 3.4, 3.0) if style in MASONRY_STYLES \
				else TmTower.material(style, style.hash() % 997, 3.8, 3.0)
			mat.set_shader_parameter("storefront", STOREFRONT)      # the base storey (dark glass, LED line)
			shared[style] = mat
		TmTower.add_mesh(root, blocks[key], shared[style], "Blocks_" + key.replace(":", "_"), shadows)


## A city track's towers on the field (track spec "scenery": "city"): buildings on the cells
## around the road, none on a cell a block of the track touches (its meshes' bounds) or under the
## line a car flies over a jump; 2 x 2 cells lots with a tower (at most FIELD_TOWERS), single cells
## with a lower building, some left as plazas. Inset FIELD_INSET from their cells, so the nearest
## walls stand a pavement off the road's cell. With collision (a car that leaves the road hits them),
## shadows, and lights at night. One layout per track (seeded by its uid). Godot coordinates of the
## map (TMNF x negated), on its ground (TmMapBuilder.GROUND_Y).
static func field(builder: TmMapBuilder) -> Node3D:
	var root := Node3D.new()
	root.name = "FieldCity"
	root.position = Vector3(0.0, TmMapBuilder.GROUND_Y, 0.0)
	var ch := builder.challenge
	var nx := ch.size.x
	var nz := ch.size.z
	var busy := track_cells(builder)
	var dist := _distances(busy, nx, nz)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ch.uid)
	var cells: Array[Vector2i] = []
	for cz in nz:
		for cx in nx:
			if int(dist.get(Vector2i(cx, cz), 99)) >= 1:
				cells.append(Vector2i(cx, cz))
	for i in range(cells.size() - 1, 0, -1):     # shuffled by the track's own seed
		var j := rng.randi() % (i + 1)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	var towers := Node3D.new()
	towers.name = "Towers"
	root.add_child(towers)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", 0)
	root.add_child(body)
	var blocks := {}
	var roofs := TmTower.Builder.new()
	var used := {}
	var plazas: Array[Vector2i] = []
	var boards := []
	var blades := []
	var neon := TmNeon.Tubes.new()
	neon.night = TmStadiumEnv.night
	var count := 0
	for c in cells:
		if used.has(c):
			continue
		var d := int(dist.get(c, 99))
		if rng.randf() < (0.15 if d <= 2 else 0.3):
			used[c] = true                             # a plaza
			plazas.append(c)
			continue
		var lot := [c, c + Vector2i(1, 0), c + Vector2i(0, 1), c + Vector2i(1, 1)]
		var fits := count < FIELD_TOWERS and rng.randf() < 0.5
		for q: Vector2i in lot:
			fits = fits and q.x < nx and q.y < nz and int(dist.get(q, 0)) >= 1 and not used.has(q)
		if fits:
			for q: Vector2i in lot:
				used[q] = true
			var at := Vector2(-(c.x + 1) * 32.0, (c.y + 1) * 32.0)     # the lot's centre (Godot x, z)
			var room := 64.0 - FIELD_INSET * 2.0
			var h := rng.randf_range(110.0, 330.0) * (1.0 if d > 2 else 0.75)
			var w := minf(h / rng.randf_range(6.0, 8.0), room / 1.18)
			var spec := _tower_spec(rng, 0.6, c.x * 7919 + c.y * 104729 + 17)
			spec["height"] = h
			spec["w"] = w
			spec["d"] = minf(w * rng.randf_range(0.8, 1.05), room / 1.25)
			spec["shadows"] = true
			spec["podium"] = rng.randf_range(8.0, 12.0)
			spec["neon"] = spec.get("neon", TmNeon.pick(hash(int(spec["seed"]) * 13 + 5), 1.0))     # every field tower
			spec["neon_r"] = 0.16
			var turn := absi(int(spec["seed"])) % 4
			var asset := TmCityAssets.pick(rng, Vector2(room, room), h) if rng.randf() < ASSET_SHARE else {}
			if not asset.is_empty():
				var sz: Vector3 = asset["size"]
				_asset(towers, asset, at, String(spec["glass"]), int(spec["seed"]), true)
				var ae := Vector2(sz.x, sz.z) * 0.45                       # a little inside its outline
				_collide(body, Rect2(at - ae, ae * 2.0), sz.y)
				count += 1
				continue
			_tower(towers, spec, at, turn)
			var e := Vector2(float(spec["w"]) * 0.59, float(spec["d"]) * 0.625)
			if turn % 2 == 1:
				e = Vector2(e.y, e.x)
			_collide(body, Rect2(at - e, e * 2.0), float(spec["podium"]))
			var shrink := 0.86 if String(spec["shape"]) in ["circle", "octagon", "rounded"] else 1.0
			var te := Vector2(float(spec["w"]), float(spec["d"])) * 0.5 * shrink
			if turn % 2 == 1:
				te = Vector2(te.y, te.x)
			_collide(body, Rect2(at - te, te * 2.0), h)
			count += 1
			continue
		used[c] = true
		var x0 := -(c.x + 1) * 32.0 + FIELD_INSET + rng.randf_range(0.0, 3.0)
		var x1 := -c.x * 32.0 - FIELD_INSET - rng.randf_range(0.0, 3.0)
		var z0 := c.y * 32.0 + FIELD_INSET + rng.randf_range(0.0, 3.0)
		var z1 := (c.y + 1) * 32.0 - FIELD_INSET - rng.randf_range(0.0, 3.0)
		var r := Rect2(x0, z0, x1 - x0, z1 - z0)
		var bh := rng.randf_range(16.0, 45.0) if d <= 1 else rng.randf_range(20.0, 90.0)
		# by the road, a third of them one of the owner's City Street buildings (brick, lit windows,
		# their own signs) when one fits the lot (picked by the cell's hash)
		var hv := hash(c * 31 + Vector2i(7, 3))
		if d <= 2 and absi(hv) % 100 < 35:
			var prng := RandomNumberGenerator.new()
			prng.seed = hv
			var st := TmCityAssets.pick(prng, r.size, clampf(bh, 10.0, 34.0), "street")
			if not st.is_empty():
				var ssz: Vector3 = st["size"]
				var sat := r.get_center()
				_asset(towers, st, sat, "", 0, true)
				_collide(body, Rect2(sat - Vector2(ssz.x, ssz.z) * 0.45, Vector2(ssz.x, ssz.z) * 0.9), ssz.y)
				continue
		_box(blocks, roofs, 0, r, bh, 0.5, rng, true, neon, d <= 2)
		_collide(body, r, bh)
		# beside the road: a billboard on the roof facing it, or a neon sign out from the facade
		var way := _road_way(c, busy)
		if d == 1 and way != Vector2.ZERO:
			var mid := r.get_center()
			var along_x := absf(way.x) > 0.5
			var half := (r.size.x if along_x else r.size.y) * 0.5
			var side := (r.size.y if along_x else r.size.x) * 0.5
			var roll := rng.randf()
			if roll < 0.25 and side * 2.0 > TmCitySigns.BOARD.x + 1.0:
				boards.append([Vector3(mid.x, 0.4 + bh, mid.y) + Vector3(way.x, 0.0, way.y) * (half - 1.5), way])
			elif roll < 0.85 and bh > STOREFRONT + 9.0:
				var t := Vector2(-way.y, way.x) * (side - 1.6) * (1.0 if rng.randf() < 0.5 else -1.0)
				var h := rng.randf_range(6.0, minf(11.0, bh - STOREFRONT - 2.0))
				var foot := mid + way * half + t
				blades.append([Vector3(foot.x, 0.4 + STOREFRONT + 0.6 + h, foot.y), way, h])
	_add_blocks(root, blocks, true)
	TmTower.add_mesh(root, roofs, TmTower.shared("roof"), "Roofs", true)
	root.add_child(_street_trees(ch, cells, busy, plazas, body, rng))
	root.add_child(TmCitySigns.billboards(boards))
	root.add_child(TmCitySigns.blades(blades, rng))
	if not neon.is_empty():
		root.add_child(neon.build("FieldNeon"))
	_layer(root)          # the city's light: the moon and the street lights, not the floodlights
	return root


## Street trees and lights on a city track's field: trees in a row along the pavement where a cell meets the
## track's (2.2 m in from the edge, about every 10 m) and four to a plaza; none within a building
## (and 1.5 m round it), within 8 m of the car's line, or nearer than 7 m to another. Each trunk
## collides (a car that leaves the road can hit it). A street light (TmStreetLights) between them
## every cell, 1.2 m from the edge, its arm over the road.
static func _street_trees(ch: TmChallenge, cells: Array[Vector2i], busy: Dictionary, plazas: Array[Vector2i],
		body: StaticBody3D, rng: RandomNumberGenerator) -> Node3D:
	var boxes: Array[Rect2] = []
	for cs in body.get_children():
		var sz := ((cs as CollisionShape3D).shape as BoxShape3D).size
		var at := (cs as Node3D).position
		boxes.append(Rect2(at.x - sz.x * 0.5 - 1.5, at.z - sz.z * 0.5 - 1.5, sz.x + 3.0, sz.z + 3.0))
	var line := PackedVector2Array()
	for pt: Dictionary in ch.path:
		var p: Vector3 = pt["p"]
		line.append(Vector2(p.x, p.z))
	var spots: Array[Vector2] = []
	var lamp_spots := []                 # [foot, the way to the road]
	for c in cells:
		var cc := Vector2(-(c.x + 0.5) * 32.0, (c.y + 0.5) * 32.0)
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not busy.has(c + dir):
				continue
			var nc := Vector2(-(c.x + dir.x + 0.5) * 32.0, (c.y + dir.y + 0.5) * 32.0)
			var inward := (cc - nc).normalized()
			var along := Vector2(-inward.y, inward.x)
			var mid := (cc + nc) * 0.5 + inward * 2.2
			for k: float in [-10.0, 0.0, 10.0]:
				spots.append(mid + along * (k + rng.randf_range(-1.5, 1.5)))
			lamp_spots.append([(cc + nc) * 0.5 + inward * 1.2 + along * 5.0, -inward, c + dir])
	for c in plazas:
		var cc := Vector2(-(c.x + 0.5) * 32.0, (c.y + 0.5) * 32.0)
		for q: Vector2 in [Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]:
			spots.append(cc + q + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)))
	var feet := []
	var placed: Array[Vector2] = []
	for p in spots:
		var ok := true
		for b in boxes:
			if b.has_point(p):
				ok = false
				break
		for q in line:
			if not ok or p.distance_squared_to(q) < 64.0:
				ok = false
				break
		for q in placed:
			if not ok or p.distance_squared_to(q) < 49.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		feet.append(Transform3D(Basis(), Vector3(p.x, 0.02, p.y)))
		_collide(body, Rect2(p - Vector2(0.3, 0.3), Vector2(0.6, 0.6)), 4.0)
	var root := Node3D.new()
	root.name = "Street"
	root.add_child(TmTrees.planting(feet, rng, true, 1200.0))
	# where the track turns (its line's radius under 100 m): traffic lights there, not street lights
	var turns := {}
	for pt: Dictionary in ch.path:
		var r := float(pt.get("r", 0.0))
		if r > 0.0 and r < 100.0:
			var p: Vector3 = pt["p"]
			turns[Vector2i(floori(-p.x / 32.0), floori(p.z / 32.0))] = true
	# street lights between the trees, their arms over the road, 7 m clear of the car's line
	var lamps := []
	var signals := []
	for ls: Array in lamp_spots:
		var p: Vector2 = ls[0]
		var to_road: Vector2 = ls[1]
		var ok := true
		for b in boxes:
			if b.has_point(p):
				ok = false
				break
		for q in line:
			if not ok or p.distance_squared_to(q) < 49.0:
				ok = false
				break
		if ok:
			var at := Vector3(p.x, 0.02, p.y)
			if turns.has(ls[2]) and signals.size() < 24:
				# facing the road: its faces (+z) towards it
				signals.append(Transform3D(Basis.looking_at(-Vector3(to_road.x, 0.0, to_road.y)), at))
			else:
				lamps.append(Transform3D(Basis.looking_at(Vector3(to_road.x, 0.0, to_road.y)), at))
			_collide(body, Rect2(p - Vector2(0.15, 0.15), Vector2(0.3, 0.3)), TmStreetLights.HEIGHT)
	root.add_child(TmStreetLights.row(lamps, TmStadiumEnv.night, 1 + absi(hash(ch.uid)) % TmStreetLights.LAMPS))
	root.add_child(TmStreetLights.traffic(signals))
	return root


## The way (Godot x, z; a unit along an axis) from cell c to a neighbouring cell of the track's,
## or zero when none touches it along a side.
static func _road_way(c: Vector2i, busy: Dictionary) -> Vector2:
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if busy.has(c + dir):
			return Vector2(-dir.x, dir.y)            # TMNF x is Godot -x
	return Vector2.ZERO


## The map cells (TMNF x, z) a track takes: every cell its blocks' meshes cover (their bounds) and
## those under its line, with a cell's margin round a jump's flight (the car may drift there) and
## round the start and two cells behind it (where the start's cameras stand).
static func track_cells(builder: TmMapBuilder) -> Dictionary:
	var busy := {}
	var blocks := builder.root.get_node_or_null("Blocks")
	if blocks != null:
		_mark(blocks, builder.root.transform * (blocks as Node3D).transform, busy)
	if builder.has_start:
		# the start's surroundings and two cells behind it: the start's cameras look from there
		var s := builder.start
		for k in 3:
			var p := s.origin - s.basis.z * 32.0 * k
			var c := Vector2i(floori(-p.x / 32.0), floori(p.z / 32.0))
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					busy[c + Vector2i(dx, dz)] = true
	for pt: Dictionary in builder.challenge.path:
		var p: Vector3 = pt["p"]
		var c := Vector2i(floori(-p.x / 32.0), floori(p.z / 32.0))
		var r := 1 if int(pt.get("mode", 0)) == TmTrackBuilder.Drive.BLIND else 0
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				busy[c + Vector2i(dx, dz)] = true
	return busy


static func _mark(n: Node, xf: Transform3D, busy: Dictionary) -> void:
	for ch in n.get_children():
		if not ch is Node3D:
			continue
		var cx: Transform3D = xf * (ch as Node3D).transform
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh != null:
			var box := cx * (ch as MeshInstance3D).get_aabb()
			# shrunk a hair so a block's bounds on a cell's edge don't take its neighbour
			for gx in range(floori((-box.end.x + 0.5) / 32.0), floori((-box.position.x - 0.5) / 32.0) + 1):
				for gz in range(floori((box.position.z + 0.5) / 32.0), floori((box.end.z - 0.5) / 32.0) + 1):
					busy[Vector2i(gx, gz)] = true
		_mark(ch, cx, busy)


## Each cell's distance (in cells, diagonals counting one) to the nearest busy one.
static func _distances(busy: Dictionary, nx: int, nz: int) -> Dictionary:
	var dist := {}
	var front: Array[Vector2i] = []
	for c: Vector2i in busy:
		dist[c] = 0
		front.append(c)
	while not front.is_empty():
		var next: Array[Vector2i] = []
		for c in front:
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var q := c + Vector2i(dx, dz)
					if q.x < 0 or q.y < 0 or q.x >= nx or q.y >= nz or dist.has(q):
						continue
					dist[q] = int(dist[c]) + 1
					next.append(q)
		front = next
	return dist


## A collision box over a rectangle (Godot x, z) from the ground to h.
static func _collide(body: StaticBody3D, r: Rect2, h: float) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(r.size.x, h, r.size.y)
	cs.shape = box
	cs.position = Vector3(r.get_center().x, h * 0.5, r.get_center().y)
	body.add_child(cs)


## The paved field of a city track (TmMapBuilder: instead of the grass).
static func paving() -> ShaderMaterial:
	if _paving == null:
		_paving = ShaderMaterial.new()
		_paving.shader = preload("res://env/tm_city_paving.gdshader")
	return _paving


## A cell's index (the cell a point is in).
static func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / PITCH), roundi(p.y / PITCH))


## The block at c touches the Stadium (its edge and a street's margin).
static func _inside(c: Vector2) -> bool:
	var e := TmStadiumBuild.EDGE + Vector2(60.0, 60.0)
	return absf(c.x) - PITCH * 0.5 < e.x and absf(c.y) - PITCH * 0.5 < e.y


## How tall the city is here (0: low-rise, 1: the highest district's heart).
static func _tall(p: Vector2) -> float:
	var t := 0.0
	for d: Array in DISTRICTS:
		var r: float = d[1]
		t = maxf(t, float(d[2]) * exp(-(p - (d[0] as Vector2)).length_squared() / (r * r)))
	return t


static func _sector(p: Vector2) -> int:
	return clampi(int((atan2(p.y, p.x) + PI) / TAU * SECTORS), 0, SECTORS - 1)


## A skyscraper for a district's block: taller towards its heart.
static func _tower_spec(rng: RandomNumberGenerator, t: float, seed: int) -> Dictionary:
	var h := (130.0 + 470.0 * pow(t, 1.2)) * rng.randf_range(0.75, 1.15)
	var w := clampf(h / rng.randf_range(6.0, 8.5), 30.0, 80.0)   # real towers' slenderness
	var shape: String = TmTower.SHAPES[rng.randi() % TmTower.SHAPES.size()]
	var tiers := [[1.0, 1.0]]
	if h > 260.0:
		tiers = [[rng.randf_range(0.45, 0.65), 1.0], [rng.randf_range(0.75, 0.9), 0.84], [1.0, 0.68]]
	elif h > 170.0 and rng.randf() < 0.6:
		tiers = [[rng.randf_range(0.6, 0.8), 1.0], [1.0, 0.82]]
	var crowns := ["flat", "flat", "spire", "slant", "ring"]
	if shape == "circle" or shape == "rounded":
		crowns = ["flat", "spire", "ring"]
	return {"height": h, "w": w, "d": w * rng.randf_range(0.75, 1.1), "shape": shape,
		"glass": GLASS_STYLES[rng.randi() % GLASS_STYLES.size()], "crown": crowns[rng.randi() % crowns.size()],
		"fins": [0, 0, 2, 3, 4][rng.randi() % 5], "floor": rng.randf_range(3.7, 4.3), "tiers": tiers,
		"bay": 3.0 if w < 50.0 else 4.5,
		"seed": seed, "shadows": false, "podium": rng.randf_range(10.0, 16.0)}.merged(_tower_neon(seed))


## A tower's neon (spec "neon", "neon_r", "neon_full"; TmTower.build): three quarters of them, by
## their seed, thick enough to read from the field 1-3 km off; a third of those down their whole height.
static func _tower_neon(seed: int) -> Dictionary:
	var col := TmNeon.pick(hash(seed * 7 + 3), 0.75)
	var out := {"screen": absi(hash(seed * 17 + 9)) % 100 < 22}
	if col >= 0:
		out.merge({"neon": col, "neon_r": 0.9, "neon_full": absi(hash(seed * 11 + 1)) % 3 == 0})
	return out


## One of the owner's buildings (TmCityAssets.pick) standing at `at` (its foot's centre).
static func _asset(parent: Node3D, choice: Dictionary, at: Vector2, glass: String, seed: int, shadows: bool) -> void:
	var n := TmCityAssets.building(choice, glass, absi(seed) % 8, shadows)
	n.position = Vector3(at.x, 0.4, at.y)
	parent.add_child(n)


static func _tower(parent: Node3D, spec: Dictionary, at: Vector2, turn := 0) -> void:
	var t := TmTower.build(spec)
	t.position = Vector3(at.x, 0.4, at.y)
	t.rotation.y = turn * PI * 0.5
	if bool(spec.get("screen", false)):
		_tower_screen(t, spec, at, turn)
	parent.add_child(t)


## A big LED screen on a tower's face (M14: the skyline alive): on the face that looks most towards
## the Stadium (the city's centre), up its first tier, as wide as 70% of the face (at most 64 m).
static func _tower_screen(t: Node3D, spec: Dictionary, at: Vector2, turn: int) -> void:
	var w := float(spec.get("w", 44.0))
	var d := float(spec.get("d", 36.0))
	var height := float(spec.get("height", 240.0))
	var podium := float(spec.get("podium", 12.0))
	var tiers: Array = spec.get("tiers", [[1.0, 1.0]])
	var to_centre := Vector3(-at.x, 0.0, -at.y).normalized()
	var rot := Basis(Vector3.UP, turn * PI * 0.5)
	var best := Vector3.FORWARD
	var dot := -2.0
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var k := (rot * n).dot(to_centre)
		if k > dot:
			dot = k
			best = n
	var half := (w if absf(best.x) > 0.5 else d) * 0.5
	var across := d if absf(best.x) > 0.5 else w
	if String(spec.get("shape", "rect")) in ["circle", "rounded", "octagon"]:
		half *= 1.02
	var top := podium + (height - podium) * float(tiers[0][0])
	var size := minf(across * 0.7, 64.0)
	var y := top - size * 0.25 - 10.0
	if y - size * 0.25 < podium + 8.0:
		return
	var s := TmCitySigns.facade_screen(size, absi(int(spec.get("seed", 0))))
	s.transform = Transform3D(Basis.looking_at(-best), best * (half + 0.8) + Vector3(0.0, y, 0.0)) * Transform3D().scaled(Vector3.ONE * size)
	t.add_child(s)


## A block of lower buildings: four lots, each a building inset from the pavement, its height and
## style from the district (glass where it is taller, masonry where it is low).
static func _lots(blocks: Dictionary, roofs: TmTower.Builder, sector: int, c: Vector2, t: float, rng: RandomNumberGenerator,
		neon: TmNeon.Tubes = null) -> void:
	var lot := HALF
	for qx in 2:
		for qz in 2:
			if rng.randf() < 0.08 + 0.1 * (1.0 - t):
				continue                             # an open lot (the plaza shows)
			var lc := c + Vector2((qx - 0.5) * lot, (qz - 0.5) * lot)
			var size := Vector2(lot - rng.randf_range(2.0, 9.0) * 2.0, lot - rng.randf_range(2.0, 9.0) * 2.0)
			var h := 10.0 + (14.0 + 110.0 * t) * pow(rng.randf(), 1.6) + 30.0 * t
			_box(blocks, roofs, sector, Rect2(lc - size * 0.5, size), h, t, rng, false, neon if lc.length() < 1800.0 else null)


## A tower's block: the tower off its centre, lower wings on the block's free sides.
static func _tower_block(towers: Node3D, blocks: Dictionary, roofs: TmTower.Builder, sector: int, c: Vector2, t: float,
		spec: Dictionary, rng: RandomNumberGenerator, neon: TmNeon.Tubes = null) -> void:
	var turn := absi(int(spec["seed"])) % 4
	var e := Vector2(float(spec["w"]) * 0.59, float(spec["d"]) * 0.625)   # the podium's half extents
	if turn % 2 == 1:
		e = Vector2(e.y, e.x)
	# one of the owner's buildings when one fits (TmCityAssets), else ours
	var asset := TmCityAssets.pick(rng, Vector2(HALF, HALF) * 2.0 - Vector2(8.0, 8.0), float(spec["height"])) \
		if rng.randf() < ASSET_SHARE else {}
	if not asset.is_empty():
		var sz: Vector3 = asset["size"]
		e = Vector2(sz.x, sz.z) * 0.5
	var room := Vector2(maxf(HALF - e.x, 0.0), maxf(HALF - e.y, 0.0))
	var at := c + Vector2(rng.randf_range(-room.x, room.x), rng.randf_range(-room.y, room.y)) * 0.8
	if asset.is_empty():
		_tower(towers, spec, at, turn)
	else:
		_asset(towers, asset, at, String(spec["glass"]), int(spec["seed"]), bool(spec.get("shadows", false)))
	# the wings: west and east strips the block's depth, north and south ones between them
	var gap := 6.0
	var lo := c - Vector2(HALF, HALF)
	var hi := c + Vector2(HALF, HALF)
	var o0 := at - e - Vector2(gap, gap)
	var o1 := at + e + Vector2(gap, gap)
	var strips := [Rect2(lo.x, lo.y, o0.x - lo.x, hi.y - lo.y), Rect2(o1.x, lo.y, hi.x - o1.x, hi.y - lo.y),
		Rect2(maxf(o0.x, lo.x), lo.y, minf(o1.x, hi.x) - maxf(o0.x, lo.x), o0.y - lo.y),
		Rect2(maxf(o0.x, lo.x), o1.y, minf(o1.x, hi.x) - maxf(o0.x, lo.x), hi.y - o1.y)]
	for r: Rect2 in strips:
		if r.size.x < 14.0 or r.size.y < 14.0 or rng.randf() < 0.2:
			continue
		# a long strip: two buildings
		var parts: Array[Rect2] = [r]
		var along_y := r.size.y > r.size.x
		var span := r.size.y if along_y else r.size.x
		if span > 70.0:
			var cut := span * rng.randf_range(0.35, 0.65)
			if along_y:
				parts = [Rect2(r.position, Vector2(r.size.x, cut - 3.0)), Rect2(r.position + Vector2(0.0, cut + 3.0), Vector2(r.size.x, span - cut - 3.0))]
			else:
				parts = [Rect2(r.position, Vector2(cut - 3.0, r.size.y)), Rect2(r.position + Vector2(cut + 3.0, 0.0), Vector2(span - cut - 3.0, r.size.y))]
		for q in parts:
			var h := 14.0 + (20.0 + 50.0 * t) * rng.randf()
			_box(blocks, roofs, sector, q, h, t, rng, false, neon if c.length() < 1800.0 else null)


## One lower building: a box on a rectangle (with a parapet and, taller, maybe a setback), its
## style from its height and the district (glass where it is taller, masonry where it is low).
static func _box(blocks: Dictionary, roofs: TmTower.Builder, sector: int, r: Rect2, h: float, t: float, rng: RandomNumberGenerator,
		modern := false, neon: TmNeon.Tubes = null, near := false) -> void:
	var glass := (h > 45.0 and rng.randf() < 0.35 + 0.6 * t) or (modern and rng.randf() < 0.4)
	var style: String = (GLASS_STYLES[rng.randi() % GLASS_STYLES.size()] if glass
		else MASONRY_STYLES[rng.randi() % MASONRY_STYLES.size()])
	if modern and style in ["brick", "stone"] and rng.randf() < 0.7:
		style = ["concrete", "white"][rng.randi() % 2]      # a modern street: mostly panels and glass
	var key := "%s:%d" % [style, sector]
	if not blocks.has(key):
		blocks[key] = TmTower.Builder.new()
	var b: TmTower.Builder = blocks[key]
	var shade := rng.randf_range(0.82, 1.08)
	b.tint = Color(shade, shade * rng.randf_range(0.97, 1.02), shade * rng.randf_range(0.95, 1.03))
	var lc := r.get_center()
	var poly := _rect(lc, r.size)
	# each building its own rooms: its walls' u from its own offset
	var u0 := float(rng.randi() % 4000) * 6.0
	TmTower.walls(b, poly, 0.4, 0.4 + h, u0)
	_crown_band(b, roofs, lc, r.size, 0.4 + h, glass, rng)
	var roof_y := 0.4 + h
	var roof := r.size
	# a setback on the taller ones, standing on the roof
	if h > 50.0 and rng.randf() < 0.5:
		roof = r.size * 0.7
		var h2 := h * rng.randf_range(0.15, 0.4)
		TmTower.walls(b, _rect(lc, roof), roof_y, roof_y + h2, u0 + 3000.0)
		roof_y += h2
		_crown_band(b, roofs, lc, roof, roof_y, glass, rng)
	_roof_clutter(roofs, lc, roof, roof_y, h, glass, rng)
	if neon != null:
		_box_neon(neon, r, h, near)


## A lower building's neon (M14), by a hash of its place (the layout's random draws stay as they
## were): a ring under its crown; on many, tubes down its corners to the base; on some, a band
## every three floors. Near the road (a City field) most of them, thin tubes; in the city round the
## Stadium a fifth of the taller ones, crowns only, thick enough to read from the field.
static func _box_neon(neon: TmNeon.Tubes, r: Rect2, h: float, near: bool) -> void:
	var hv := hash(Vector2i(roundi(r.position.x * 10.0), roundi(r.position.y * 10.0)))
	var col := TmNeon.pick(hv, 0.75 if near else (0.2 if h > 25.0 else 0.0))
	if col < 0:
		return
	var poly := _rect(r.get_center(), r.size)
	var top := 0.4 + h - 1.1
	var rad := 0.12 if near else 0.45
	var style := (absi(hv) / 1000) % 4 if near else 2
	var base := 0.4 + STOREFRONT
	TmNeon.ring(neon, poly, top, col, rad, 0.2, top - base if style == 0 or style == 3 else 0.0)
	if style == 1:
		var yb := base + 12.0
		while yb < top - 6.0:
			TmNeon.ring(neon, poly, yb, col, rad, 0.2)
			yb += 12.0


static func _rect(c: Vector2, size: Vector2) -> PackedVector2Array:
	var p := TmTower.footprint("rect", size.x, size.y)
	for i in p.size():
		p[i] += c
	return p


## A building's top edge at y: masonry gets a cornice (a band standing 0.45 m proud, its underside
## and top) and a parapet; glass a plain parapet. Plain walls (no windows) carry the vertex
## colour's alpha 0.3. The roof inside at y.
static func _crown_band(b: TmTower.Builder, roofs: TmTower.Builder, c: Vector2, size: Vector2, y: float, glass: bool,
		rng: RandomNumberGenerator) -> void:
	var inner := _rect(c, size)
	var tint := b.tint
	b.tint.a = 0.3
	if not glass:
		var lip := rng.randf_range(0.3, 0.6)
		var outer := _rect(c, size + Vector2(lip, lip) * 2.0)
		var band := rng.randf_range(0.6, 1.1)
		TmTower.ring_cap(b, outer, inner, y, true)
		TmTower.walls(b, outer, y, y + band)
		TmTower.ring_cap(b, outer, inner, y + band)
		TmTower.walls(b, inner, y + band, y + band + 0.9)
	else:
		TmTower.walls(b, inner, y, y + 1.2)
	b.tint = tint
	TmTower.cap(roofs, inner, y)


## On a roof: a plant room or a lift overrun, units, and on older masonry blocks a water tank.
static func _roof_clutter(roofs: TmTower.Builder, c: Vector2, size: Vector2, y: float, h: float, glass: bool,
		rng: RandomNumberGenerator) -> void:
	if size.x < 12.0 or size.y < 12.0:
		return
	var tint := roofs.tint
	for k in 1 + rng.randi() % 3:
		var bs := Vector2(rng.randf_range(3.0, minf(12.0, size.x * 0.4)), rng.randf_range(3.0, minf(10.0, size.y * 0.4)))
		var at := c + Vector2(rng.randf_range(-1.0, 1.0) * (size.x * 0.5 - bs.x * 0.5 - 1.5),
			rng.randf_range(-1.0, 1.0) * (size.y * 0.5 - bs.y * 0.5 - 1.5))
		var bh := rng.randf_range(2.2, 4.5)
		var g := rng.randf_range(0.75, 1.05)
		roofs.tint = Color(g, g, g * 1.02)
		var p := _rect(at, bs)
		TmTower.walls(roofs, p, y, y + bh)
		TmTower.cap(roofs, p, y + bh)
	if not glass and h < 70.0 and rng.randf() < 0.45:
		# a timber water tank on steel legs
		var at := c + Vector2(rng.randf_range(-0.25, 0.25) * size.x, rng.randf_range(-0.25, 0.25) * size.y)
		var legs := 3.5
		roofs.tint = Color(0.35, 0.33, 0.32)
		for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var lp := _rect(at + q * 1.6, Vector2(0.25, 0.25))
			TmTower.walls(roofs, lp, y, y + legs)
		roofs.tint = Color(0.62, 0.45, 0.32)
		var tank := TmTower.footprint("octagon", 3.9, 3.9)
		for i in tank.size():
			tank[i] += at
		TmTower.walls(roofs, tank, y + legs, y + legs + 4.0)
		roofs.tint = Color(0.40, 0.30, 0.22)
		var cone := TmTower.footprint("octagon", 4.1, 4.1)
		for i in cone.size():
			cone[i] += at
		TmTower.cap(roofs, cone, y + legs + 4.0)
	roofs.tint = tint


## A park: the block's lawn (a little above the plaza).
static func _park(b: TmTower.Builder, c: Vector2) -> void:
	var poly := TmTower.footprint("rect", HALF * 2.0, HALF * 2.0)
	for i in poly.size():
		poly[i] += c
	TmTower.cap(b, poly, 0.45)


static func _grass() -> Material:
	return TmMaterials.get_material("grass")


## The ground: one disc with the street grid (tm_city_ground), a little above the plain.
static func _ground(root: Node3D) -> void:
	if _ground_mat == null:
		_ground_mat = ShaderMaterial.new()
		_ground_mat.shader = preload("res://env/tm_city_ground.gdshader")
		_ground_mat.set_shader_parameter("pitch", PITCH)
		_ground_mat.set_shader_parameter("street", STREET)
		_ground_mat.set_shader_parameter("radius", RADIUS)
	var b := TmTower.Builder.new()
	var rim := RADIUS + 400.0
	var poly := PackedVector2Array()
	for k in 48:
		var a := k * TAU / 48.0
		poly.append(Vector2(cos(a), sin(a)) * rim)
	TmTower.cap(b, poly, 0.3)
	TmTower.add_mesh(root, b, _ground_mat, "Ground", false)
