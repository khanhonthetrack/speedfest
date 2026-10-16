class_name TmTriggers
extends RefCounted
## Waypoint triggers of the Stadium blocks: the thin gate-shaped slab (0.4 m thick) a car passes
## through to take a checkpoint, the finish or a lap. Measured from TMNF's trigger solids; we keep
## only our own description of each: the slab's mid-plane and the outline of its cross-section
## (block-local TMNF metres: (x, y) for a vertical gate across the block at z = plane, (x, z) for
## a horizontal ring at y = plane).
##
## A car takes a trigger when its centre of mass crosses the mid-plane inside the outline between
## two ticks (crossed()), in either direction.

const ROAD := [[3.0, 1.0], [30.0, 1.0], [30.0, 1.95], [26.66, 5.08], [19.4, 7.81], [12.6, 7.81], [5.33, 5.08], [3.0, 2.89]]
const ROAD_UP := [[3.0, 5.26], [30.0, 5.26], [30.0, 5.95], [26.66, 9.09], [19.4, 11.82], [12.6, 11.82], [5.33, 9.08], [3.0, 6.89]]
const ROAD_DOWN := [[2.13, 5.26], [29.13, 5.26], [29.13, 6.89], [26.81, 9.08], [19.54, 11.82], [12.73, 11.82], [5.47, 9.09], [2.13, 5.95]]
const ROAD_LEFT := [[3.0, 8.57], [30.0, 1.76], [30.0, 2.71], [26.66, 6.69], [19.4, 11.25], [12.6, 12.96], [5.33, 12.06], [3.0, 10.45]]
const ROAD_RIGHT := [[2.0, 1.71], [29.0, 8.51], [29.0, 10.4], [26.67, 12.01], [19.4, 12.91], [12.6, 11.19], [5.34, 6.63], [2.0, 2.66]]
const DIRT := [[2.06, -1.15], [30.0, -1.15], [30.0, 3.49], [26.66, 6.29], [19.4, 8.89], [12.6, 8.89], [5.33, 6.16], [2.06, 3.48]]
const DIRT_HIGH := [[3.79, 6.31], [28.27, 6.31], [28.27, 7.55], [25.86, 10.36], [19.4, 13.63], [12.6, 13.63], [6.14, 10.22], [3.79, 7.55]]
const GRASS := [[3.0, -0.33], [29.1, -0.33], [30.0, 1.95], [26.66, 5.08], [19.4, 7.81], [12.6, 7.81], [5.33, 5.08], [2.29, 1.4]]
const PLATFORM := [[1.82, 7.93], [30.18, 7.93], [28.64, 9.74], [26.31, 11.04], [22.73, 12.52], [18.34, 13.47], [13.66, 13.47], [9.27, 12.52], [5.7, 11.04], [3.36, 9.74]]
const PLATFORM_TILT := [[1.82, 23.02], [3.36, 24.06], [5.7, 24.19], [9.27, 23.88], [13.66, 22.63], [18.34, 20.3], [22.73, 17.15], [26.31, 13.88], [28.64, 11.42], [30.18, 8.84]]
const PLATFORM_Z := 15.88
const RING_R := 13.26           ## ring triggers: 18-gons of this radius

## block id -> [axis ("z" or "y"), plane, outline, outline y offset, mirror x]
const TRIGGERS := {
	"StadiumRoadMainCheckpoint": ["z", 16.0, ROAD, 0.0, false],
	"StadiumRoadMainStartFinishLine": ["z", 16.0, ROAD, 0.0, false],
	"StadiumRoadMainFinishLine": ["z", 12.0, ROAD, 0.0, false],
	"StadiumRoadMainCheckpointUp": ["z", 16.0, ROAD_UP, 0.0, false],
	"StadiumRoadMainCheckpointDown": ["z", 16.0, ROAD_DOWN, 0.0, false],
	"StadiumRoadMainCheckpointLeft": ["z", 16.0, ROAD_LEFT, 0.0, false],
	"StadiumRoadMainCheckpointRight": ["z", 16.0, ROAD_RIGHT, 0.0, false],
	"StadiumRoadDirtCheckpoint": ["z", 16.0, DIRT, 0.0, false],
	"StadiumRoadDirtHighCheckpoint": ["z", 16.0, DIRT_HIGH, 0.0, false],
	"StadiumGrassCheckpoint": ["z", 16.0, GRASS, 0.0, false],
	"StadiumPlatformCheckpoint": ["z", PLATFORM_Z, PLATFORM, 0.0, false],
	"StadiumPlatformCheckpointUp": ["z", PLATFORM_Z, PLATFORM, 7.94, false],
	"StadiumPlatformCheckpointDown": ["z", PLATFORM_Z, PLATFORM, 8.06, false],
	"StadiumPlatformCheckpointLeft": ["z", PLATFORM_Z, PLATFORM_TILT, 0.0, false],
	"StadiumPlatformCheckpointRight": ["z", PLATFORM_Z, PLATFORM_TILT, 0.0, true],
	"StadiumCheckpointRingV": ["z", PLATFORM_Z, [16.0, 16.0], 0.0, false],
	"StadiumCheckpointRingHRoad": ["y", 4.0, [16.0, 15.67], 0.0, false],
}

static var _cache := {}


## The trigger of a waypoint block: {axis (2: z, 1: y), plane, outline (PackedVector2Array)}, or
## an empty dictionary when the block has none (the start line).
static func of(block_id: String) -> Dictionary:
	if _cache.has(block_id):
		return _cache[block_id]
	var t := {}
	if TRIGGERS.has(block_id):
		var d: Array = TRIGGERS[block_id]
		var src: Array = d[2]
		var poly := PackedVector2Array()
		if src.size() == 2:
			# a ring: an 18-gon about the centre
			for k in 18:
				var a := TAU * k / 18.0
				poly.append(Vector2(float(src[0]), float(src[1])) + Vector2(cos(a), sin(a)) * RING_R)
		else:
			for p: Array in src:
				var x := float(p[0])
				poly.append(Vector2(32.0 - x if bool(d[4]) else x, float(p[1]) + float(d[3])))
		t = {"axis": 2 if d[0] == "z" else 1, "plane": float(d[1]), "outline": poly}
	_cache[block_id] = t
	return t


## Where a segment a -> b (world) crosses the trigger of a block placed at xf (Godot block-local to
## world): the fraction along the segment in [0, 1], or -1.0 when it doesn't cross it.
static func crossed(trig: Dictionary, xf: Transform3D, a: Vector3, b: Vector3) -> float:
	if trig.is_empty():
		return -1.0
	var inv := xf.affine_inverse()
	# Godot block-local -> TMNF block-local (x negated)
	var la := inv * a
	var lb := inv * b
	la.x = -la.x
	lb.x = -lb.x
	var k: int = trig["axis"]
	var plane: float = trig["plane"]
	var da := la[k] - plane
	var db := lb[k] - plane
	if (da > 0.0) == (db > 0.0) or da == db:
		return -1.0
	var t := da / (da - db)
	var p := la.lerp(lb, t)
	var q := Vector2(p.x, p.y) if k == 2 else Vector2(p.x, p.z)
	return t if Geometry2D.is_point_in_polygon(q, trig["outline"]) else -1.0
