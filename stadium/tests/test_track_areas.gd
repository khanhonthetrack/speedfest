extends Node
## The track builder's surfaces beyond the road (TmTrackAreas; docs/research/m9_campaign.md): a
## circuit lane, a wide circuit, a walled wide platform with a turbo row, a one-cell platform gate,
## slopes, dirt road. Each lays out; every circuit plate is closed by its neighbours or a border
## facing it; walled platform edges have their walls; plates join their neighbours; slopes climb
## 2 levels a block plus the ends; a gate on a wide lane is refused; a lap race closes onto its
## start/finish line; and the bot drives the three tracks to the finish through every checkpoint
## (and lap), the turbo row boosting it.

const SIDE := TmTrackBuilder.SIDE
const AREAS := {"name": "Areas", "start": [4, 4, 1, 0], "pieces": [["start"], ["s", 1],
	["circuit", 1], ["s", 2], ["cp"], ["s", 1], ["gt", 2, "r"], ["s", 1], ["up"], ["s", 1],
	["circuit", 3], ["s", 2], ["gt", 3, "l"], ["s", 1],
	["platform", 3, "walls"], ["s", 1], ["turbo"], ["s", 2], ["gt", 3, "l"], ["s", 2],
	["platform", 1], ["s", 1], ["cp"], ["s", 1],
	["road"], ["s", 2], ["finish"]]}
const DIRT := {"name": "Dirt", "start": [16, 1, 2, 0], "pieces": [["start"], ["s", 1], ["dirt"], ["s", 2], ["cp"],
	["s", 1], ["gt", 2, "r"], ["s", 2], ["r"], ["s", 1], ["road"], ["s", 2], ["finish"]]}
const LAPS := {"name": "Laps", "start": [10, 1, 10, 0], "laps": 2, "pieces": [["start"], ["s", 2], ["cp"], ["gt", 3, "r"],
	["s", 2], ["gt", 3, "r"], ["s", 8], ["gt", 3, "r"], ["s", 2], ["gt", 3, "r"], ["s", 4], ["close"]]}


func _ready() -> void:
	TestHooks.args["records"] = "user://test_records_areas"   # its own: tests may run side by side
	TmRecords.clear()
	var b := TmTrackBuilder.build(AREAS)
	TestHooks.check(b.errors.is_empty() and b.checkpoints == 2, "areas_lay_out", "; ".join(b.errors))
	_circuit_closed(b)
	_platform(b)
	_slopes()
	var wide := TmTrackBuilder.build({"start": [4, 4, 1, 0], "pieces": [["start"], ["s", 1], ["platform", 3], ["s", 1], ["cp"]]})
	TestHooks.check(not wide.errors.is_empty() and String(wide.errors[0]).contains("one-cell lane"), "areas_gate_needs_one_cell",
		str(wide.errors))
	var d := TmTrackBuilder.build(DIRT)
	var dirt := d.blocks.filter(func(x: Dictionary) -> bool: return String(x["name"]).begins_with("StadiumRoadDirt"))
	var joins := dirt.filter(func(x: Dictionary) -> bool: return String(x["name"]) == "StadiumRoadDirtToRoad")
	TestHooks.check(d.errors.is_empty() and dirt.size() >= 8 and joins.size() == 2
		and dirt.all(func(x: Dictionary) -> bool: return bool(x["ground"])), "areas_dirt_road",
		"%s, %d dirt blocks, %d joins" % [d.errors, dirt.size(), joins.size()])
	var lap := TmTrackBuilder.build(LAPS)
	var open := LAPS.duplicate(true)
	(open["pieces"] as Array).pop_back()
	var unclosed := TmTrackBuilder.build(open)
	var ch := TmTrackBuilder.challenge(LAPS)
	TestHooks.check(lap.errors.is_empty() and ch.lap_race and ch.nb_laps == 2 and not unclosed.errors.is_empty()
		and lap.blocks.filter(func(x: Dictionary) -> bool: return String(x["name"]) == "StadiumRoadMainStartFinishLine").size() == 1,
		"areas_lap_race", "%s / %s" % [lap.errors, unclosed.errors])
	await _drive("TEST_AREAS", AREAS, true)
	await _drive("TEST_DIRT", DIRT, false)
	await _drive("TEST_LAPS", LAPS, false)
	TmRecords.clear()
	TestHooks.finish()


## Every side of every circuit plate meets the lane (plates, gates, joins, slopes) or a border.
func _circuit_closed(b: TmTrackBuilder) -> void:
	var open := []
	var plates := 0
	var facing := 0
	for blk: Dictionary in b.blocks:
		var c: Vector3i = blk["coord"]
		var id := String(blk["name"])
		if id == "StadiumCircuitBase":
			plates += 1
			for s in 4:
				var n := b.occupant(c + SIDE[s])
				if not (n.begins_with("StadiumCircuit") or n.begins_with("StadiumPlatform")):
					open.append([c, s, n])
		elif id == "StadiumCircuitBorderStraight":
			var n := b.occupant(c + SIDE[int(blk["dir"])])
			if not (n.begins_with("StadiumCircuit") or n.begins_with("StadiumPlatform")) or n.begins_with("StadiumCircuitBorder"):
				facing += 1
	TestHooks.check(plates >= 10 and open.is_empty(), "areas_circuit_closed", "%d plates, open: %s" % [plates, open.slice(0, 4)])
	TestHooks.check(facing == 0, "areas_borders_face_the_circuit", "%d borders face away" % facing)


## The walled wide platform: walls over its open edges; a middle plate is a straight (or a cross).
func _platform(b: TmTrackBuilder) -> void:
	var missing := 0
	var plates := 0
	var crosses := 0
	for blk: Dictionary in b.blocks:
		if String(blk["name"]) != "StadiumPlatformRoad":
			continue
		plates += 1
		var c: Vector3i = blk["coord"]
		if int(blk["flags"]) & 63 == 5:
			crosses += 1
		if not b.areas.walled.has(c):
			continue
		for s in 4:
			var n := b.occupant(c + SIDE[s])
			if n.is_empty() and b.occupant(c + SIDE[s] + Vector3i(0, 1, 0)) != "StadiumPlatformWallBorder" \
					and TmTrackBuilder.inside(c + SIDE[s]):
				missing += 1
	var turbos := b.blocks.filter(func(x: Dictionary) -> bool: return String(x["name"]) == "StadiumPlatformTurbo").size()
	TestHooks.check(plates >= 12 and crosses >= 1 and missing == 0 and turbos == 3, "areas_platform",
		"%d plates (%d inner), %d edges without a wall, %d turbos" % [plates, crosses, missing, turbos])


## A slope up: platform and circuit, 2 levels a straight plus one at each end.
func _slopes() -> void:
	var ok := true
	var got := []
	for kind: String in ["platform", "circuit"]:
		for n in [0, 2]:
			var b := TmTrackBuilder.build({"start": [4, 4, 1, 0], "pieces": [["start"], ["s", 1], [kind, 1], ["s", 1],
				["climb", n] if n > 0 else ["up"], ["s", 1]]})
			var top := b.cell.y
			got.append("%s %d: %d %s" % [kind, n, top, b.errors])
			ok = ok and b.errors.is_empty() and top == 3 + 2 * n + 2
			var down := TmTrackBuilder.build({"start": [4, 9, 1, 0], "pieces": [["start"], ["s", 1], [kind, 1], ["s", 1],
				["dive", n] if n > 0 else ["down"], ["s", 1]]})
			got.append("down %d %s" % [down.cell.y, down.errors])
			ok = ok and down.errors.is_empty() and down.cell.y == 8 - 2 * n - 2
	TestHooks.check(ok, "areas_slopes", str(got))


## The bot drives a spec to the finish through every checkpoint (turbo: a turbo pad boosts it).
func _drive(id: String, spec: Dictionary, turbo: bool) -> void:
	var s := spec.duplicate(true)
	s["id"] = id
	TmTracks.has(id)                      # loads the tracks, then adds this one
	TmTracks._specs[id] = s
	TestHooks.args["track"] = id
	TestHooks.args["bot"] = true
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	while not scene.ready_to_race:
		await get_tree().physics_frame
	var race: TmRace = scene.race
	var boosted := false
	while race.state != TmRace.State.FINISHED and race.time_ms < 90000 and scene.bot.failed.is_empty():
		await get_tree().physics_frame
		boosted = boosted or scene.car.model.turbo_until_ms > scene.car.now_ms
	TestHooks.check(race.state == TmRace.State.FINISHED and race.splits.size() == race.laps * (race.checkpoint_count + 1)
		and (boosted or not turbo), "areas_bot_finishes_%s" % id.to_lower(), "%s, %d ms, %d splits, turbo %s" % [scene.bot.failed,
		race.finish_ms, race.splits.size(), boosted])
	TmTracks._specs.erase(id)
	TestHooks.args.erase("bot")
	TestHooks.args.erase("track")
	scene.queue_free()
	await get_tree().physics_frame
