extends Node
## Tyre marks (race/tm_tyre_marks.gd): a sliding wheel lays a mark of its surface's kind (rubber on
## the road, grooves in dirt, torn turf on grass, none on ice), one segment per SEG metres, joined
## end to end; a wheel that grips or leaves the ground lays none; a jump (respawn) starts a new
## mark; the oldest are reused once a kind's capacity is down; clear() wipes them. In a race the bot
## lays none while it pulls away and some by the finish (it brakes hard into corners). The smoke: a
## sliding wheel's puffs come from the stretch it just covered (one plume, not a trail of dots).

const T := preload("res://core/tm_tuning.gd")


func _ready() -> void:
	_kinds()
	_lays()
	_smoke()
	await _race()
	TestHooks.finish()


func _kinds() -> void:
	var k := TmTyreMarks.kind_of
	TestHooks.check(k.call(T.Surface.ASPHALT) == "rubber" and k.call(T.Surface.CONCRETE) == "rubber"
		and k.call(T.Surface.DIRT) == "dirt" and k.call(T.Surface.DIRT_ROAD) == "dirt" and k.call(T.Surface.GRASS) == "grass"
		and k.call(T.Surface.ICE) == "", "marks_kind_by_surface")


## A car standing in for a driven one: its body's wheel fields set by hand each tick.
func _lays() -> void:
	var car := TmCar.new()
	car.set_physics_process(false)
	add_child(car)
	var marks := TmTyreMarks.new()
	marks.smoke = false
	marks.car = car
	add_child(marks)
	marks.set_physics_process(false)
	var b := car.body
	b.lin_vel = Vector3(0, 0, 20)
	var drive := func(ticks: int, sliding: bool, contact: bool, surface: int, z0: float) -> void:
		for t in ticks:
			for i in 4:
				b.wheel_contact[i] = contact
				car.model.sliding[i] = sliding
				b.wheel_surface[i] = surface
				b.wheel_hit_n[i] = Vector3.UP
				b.wheel_hit_pos[i] = Vector3(float(i) - 1.5, 0, z0 + 0.2 * t)
			marks._physics_process(0.01)
	drive.call(50, false, true, T.Surface.ASPHALT, 0.0)                  # 10 m gripping
	TestHooks.check(marks.laid("rubber") == 0, "marks_none_while_gripping", "%d laid" % marks.laid("rubber"))
	drive.call(50, true, true, T.Surface.ASPHALT, 10.0)                  # 10 m sliding: 25 per wheel
	var rubber := marks.laid("rubber")         # a segment every 0.4-0.6 m (ticks of 0.2 m)
	TestHooks.check(rubber >= 4 * 16 and rubber <= 4 * 25, "marks_laid_while_sliding", "%d segments" % rubber)
	drive.call(30, true, false, T.Surface.ASPHALT, 20.0)                 # in the air
	TestHooks.check(marks.laid("rubber") == rubber, "marks_none_in_the_air")
	drive.call(50, true, true, T.Surface.DIRT, 30.0)
	drive.call(50, true, true, T.Surface.GRASS, 40.0)
	drive.call(50, true, true, T.Surface.ICE, 50.0)
	TestHooks.check(marks.laid("dirt") >= 4 * 16 and marks.laid("grass") >= 4 * 16 and marks.laid("rubber") == rubber,
		"marks_kind_follows_the_surface", "dirt %d grass %d" % [marks.laid("dirt"), marks.laid("grass")])
	# segments join end to end: each starts where the wheel's one before ended, metres run on
	var w0 := marks.recent.filter(func(r: Array) -> bool: return int(r[0]) == 0)
	var joined := w0.size() >= 4
	for j in range(1, w0.size()):
		joined = joined and absf(float(w0[j][2]) - float(w0[j - 1][3])) < 0.0001 and float(w0[j][3]) > float(w0[j][2])
	TestHooks.check(joined, "marks_segments_join", str(w0.slice(0, 3)))
	# a jump of more than JUMP metres (a respawn) ends the mark: no segment across it
	var before := marks.laid("dirt")
	drive.call(1, true, true, T.Surface.DIRT, 500.0)
	TestHooks.check(marks.laid("dirt") == before, "marks_no_segment_across_a_respawn")
	# the ring: capacity kept, the oldest reused
	var cap: int = TmTyreMarks.KINDS["grass"][1]
	drive.call(cap, true, true, T.Surface.GRASS, 600.0)
	var g: MultiMesh = marks._mm["grass"]
	TestHooks.check(g.visible_instance_count == cap and marks.laid("grass") > cap, "marks_ring_reuses_the_oldest",
		"%d visible, %d laid" % [g.visible_instance_count, marks.laid("grass")])
	marks.clear()
	TestHooks.check(g.visible_instance_count == 0 and marks.laid("grass") == 0, "marks_clear")
	marks.queue_free()
	car.queue_free()


## The smoke's emitter: on while a wheel slides, its box along the wheel's last two ticks of travel
## (puffs spread over the road it covered at any speed), off once the wheel grips.
func _smoke() -> void:
	var car := TmCar.new()
	car.set_physics_process(false)
	add_child(car)
	var marks := TmTyreMarks.new()
	marks.car = car
	add_child(marks)
	marks.set_physics_process(false)
	var b := car.body
	b.lin_vel = Vector3(0, 0, 40)
	var drive := func(ticks: int, sliding: bool, z0: float) -> void:
		for t in ticks:
			for i in 4:
				b.wheel_contact[i] = true
				car.model.sliding[i] = sliding
				b.wheel_surface[i] = T.Surface.ASPHALT
				b.wheel_hit_n[i] = Vector3.UP
				b.wheel_hit_pos[i] = Vector3(float(i) - 1.5, 0, z0 + 0.4 * t)
			marks._physics_process(0.01)
	drive.call(10, true, 0.0)                  # 40 m/s: 0.4 m a tick, the last contact at z 3.6
	var pf: CPUParticles3D = marks._puffs[0]
	var at := pf.global_position
	TestHooks.check(pf.emitting and absf(pf.emission_box_extents.z - 0.4) < 0.01 and absf(at.z - 3.2) < 0.01
		and absf(at.y - TmTyreMarks.PUFF_RISE) < 0.01, "smoke_spread_along_the_slide",
		"emitting %s, extents %s, at %s" % [pf.emitting, pf.emission_box_extents, at])
	drive.call(1, false, 4.0)
	TestHooks.check(not pf.emitting, "smoke_stops_when_gripping")
	marks.queue_free()
	car.queue_free()


func _race() -> void:
	TestHooks.args["records"] = "user://test_records_marks"
	TestHooks.args["replays"] = "user://test_replays_marks"
	TmRecords.clear()
	TestHooks.args["track"] = "SF01" if TmTracks.has("SF01") else TmTracks.ids()[0]
	TestHooks.args["bot"] = true
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	while not scene.ready_to_race:
		await get_tree().physics_frame
	var race: TmRace = scene.race
	var marks: TmTyreMarks = scene.marks
	while race.time_ms < 1500 and race.state != TmRace.State.FINISHED:
		await get_tree().physics_frame
	var early := marks.laid("rubber") + marks.laid("dirt") + marks.laid("grass")
	TestHooks.check(early == 0, "marks_none_pulling_away", "%d laid in the first 1.5 s" % early)
	while race.state != TmRace.State.FINISHED and race.time_ms < 120000 and scene.bot.failed.is_empty():
		await get_tree().physics_frame
	var total := marks.laid("rubber") + marks.laid("dirt") + marks.laid("grass")
	TestHooks.check(race.state == TmRace.State.FINISHED and total > 0, "marks_laid_in_a_race", "%d segments, %s" % [total, scene.bot.failed])
	scene.restart()
	await get_tree().physics_frame
	TestHooks.check(marks.laid("rubber") == 0, "marks_cleared_on_restart")
	TmRecords.clear()
	scene.queue_free()
	TestHooks.args.erase("bot")
	TestHooks.args.erase("track")
