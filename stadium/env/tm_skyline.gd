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
				_tower_block(towers, blocks, roofs[sector], sector, c, t, _tower_spec(rng, t, ix * 7919 + iz * 104729), rng)
				continue
			var park := t < 0.25 and rng.randf() < 0.06
			if park:
				_park(plazas[sector], c)
				continue
			_lots(blocks, roofs[sector], sector, c, t, rng)
	_add_blocks(root, blocks, false)
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
			shared[style] = TmTower.masonry(style, style.hash() % 997, 3.4, 3.0) if style in MASONRY_STYLES \
				else TmTower.material(style, style.hash() % 997, 3.8, 3.0)
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
	var count := 0
	for c in cells:
		if used.has(c):
			continue
		var d := int(dist.get(c, 99))
		if rng.randf() < (0.15 if d <= 2 else 0.3):
			used[c] = true                             # a plaza
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
		_box(blocks, roofs, 0, r, bh, 0.5, rng)
		_collide(body, r, bh)
	_add_blocks(root, blocks, true)
	TmTower.add_mesh(root, roofs, TmTower.shared("roof"), "Roofs", true)
	return root


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
		"seed": seed, "shadows": false, "podium": rng.randf_range(10.0, 16.0)}


## One of the owner's buildings (TmCityAssets.pick) standing at `at` (its foot's centre).
static func _asset(parent: Node3D, choice: Dictionary, at: Vector2, glass: String, seed: int, shadows: bool) -> void:
	var n := TmCityAssets.building(choice, glass, absi(seed) % 8, shadows)
	n.position = Vector3(at.x, 0.4, at.y)
	parent.add_child(n)


static func _tower(parent: Node3D, spec: Dictionary, at: Vector2, turn := 0) -> void:
	var t := TmTower.build(spec)
	t.position = Vector3(at.x, 0.4, at.y)
	t.rotation.y = turn * PI * 0.5
	parent.add_child(t)


## A block of lower buildings: four lots, each a building inset from the pavement, its height and
## style from the district (glass where it is taller, masonry where it is low).
static func _lots(blocks: Dictionary, roofs: TmTower.Builder, sector: int, c: Vector2, t: float, rng: RandomNumberGenerator) -> void:
	var lot := HALF
	for qx in 2:
		for qz in 2:
			if rng.randf() < 0.08 + 0.1 * (1.0 - t):
				continue                             # an open lot (the plaza shows)
			var lc := c + Vector2((qx - 0.5) * lot, (qz - 0.5) * lot)
			var size := Vector2(lot - rng.randf_range(2.0, 9.0) * 2.0, lot - rng.randf_range(2.0, 9.0) * 2.0)
			var h := 10.0 + (14.0 + 110.0 * t) * pow(rng.randf(), 1.6) + 30.0 * t
			_box(blocks, roofs, sector, Rect2(lc - size * 0.5, size), h, t, rng)


## A tower's block: the tower off its centre, lower wings on the block's free sides.
static func _tower_block(towers: Node3D, blocks: Dictionary, roofs: TmTower.Builder, sector: int, c: Vector2, t: float,
		spec: Dictionary, rng: RandomNumberGenerator) -> void:
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
			_box(blocks, roofs, sector, q, h, t, rng)


## One lower building: a box on a rectangle (with a parapet and, taller, maybe a setback), its
## style from its height and the district (glass where it is taller, masonry where it is low).
static func _box(blocks: Dictionary, roofs: TmTower.Builder, sector: int, r: Rect2, h: float, t: float, rng: RandomNumberGenerator) -> void:
	var glass := h > 45.0 and rng.randf() < 0.35 + 0.6 * t
	var style: String = (GLASS_STYLES[rng.randi() % GLASS_STYLES.size()] if glass
		else MASONRY_STYLES[rng.randi() % MASONRY_STYLES.size()])
	var key := "%s:%d" % [style, sector]
	if not blocks.has(key):
		blocks[key] = TmTower.Builder.new()
	var b: TmTower.Builder = blocks[key]
	var shade := rng.randf_range(0.82, 1.08)
	b.tint = Color(shade, shade * rng.randf_range(0.97, 1.02), shade * rng.randf_range(0.95, 1.03))
	var lc := r.get_center()
	var poly := TmTower.footprint("rect", r.size.x, r.size.y)
	for i in poly.size():
		poly[i] += lc
	# each building its own rooms: its walls' u from its own offset
	var u0 := float(rng.randi() % 4000) * 6.0
	TmTower.walls(b, poly, 0.4, 0.4 + h + 1.2, u0)       # with its parapet
	roofs.tint = Color(rng.randf_range(0.8, 1.15), rng.randf_range(0.8, 1.15), rng.randf_range(0.8, 1.15))
	TmTower.cap(roofs, poly, 0.4 + h)
	# a setback on the taller ones
	if h > 50.0 and rng.randf() < 0.5:
		var top := TmTower.footprint("rect", r.size.x * 0.7, r.size.y * 0.7)
		for i in top.size():
			top[i] += lc
		var h2 := h * rng.randf_range(0.15, 0.4)
		TmTower.walls(b, top, 0.4 + h, 0.4 + h + h2 + 1.2, u0 + 3000.0)
		TmTower.cap(roofs, top, 0.4 + h + h2)


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
