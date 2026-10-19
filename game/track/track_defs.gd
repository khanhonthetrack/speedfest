class_name TrackDefs
extends RefCounted
## The circuits. A track is a closed loop of waypoints through the city grid; the builder
## (track/track_builder.gd) turns it into road, curbs, neon, barriers, arches and checkpoints, and
## the city generator (city/city_kit.gd) fills everything around it with towers.
##
## Waypoints are [x, y, z] in metres, in driving order, and the loop closes back to the first.
## `widths` overrides the road width at a waypoint (default `width`).
## `zones` mark stretches by waypoint index: elevated (a deck in the air: no buildings under the
## road's own footprint), tunnel (the road runs through a building), boost.
## `pads` place turbo strips, `arches` light gantries, at a waypoint index (+ an optional offset).

const DEFAULT_LAPS := 3

const DEFS := {
	"downtown": {
		"name": "Neon Downtown",
		"blurb": "Two kilometres of wet asphalt through the tower district: a flyover, a tunnel "
			+ "under the Kaiju building and a hairpin behind the arcades.",
		"laps": 3,
		"width": 16.0,
		"grid_heading": 0.0,
		"waypoints": [
			[-260.0, 0.0, -210.0],     #  0 start / finish, heading +X down the main straight
			[-60.0, 0.0, -212.0],      #  1
			[140.0, 0.0, -208.0],      #  2
			[248.0, 0.0, -192.0],      #  3 turn 1, right
			[300.0, 0.0, -118.0],      #  4
			[306.0, 0.0, -18.0],       #  5
			[296.0, 5.0, 72.0],        #  6 the flyover climbs
			[256.0, 10.0, 152.0],      #  7 crest
			[180.0, 10.0, 202.0],      #  8
			[92.0, 5.0, 218.0],        #  9 down again
			[0.0, 0.0, 216.0],         # 10
			[-62.0, 0.0, 242.0],       # 11 chicane out
			[-132.0, 0.0, 206.0],      # 12 chicane in
			[-212.0, 0.0, 202.0],      # 13
			[-292.0, 0.0, 152.0],      # 14 turn 4, left
			[-312.0, 0.0, 60.0],       # 15
			[-302.0, 0.0, -32.0],      # 16 into the tunnel
			[-332.0, 0.0, -112.0],     # 17 hairpin
			[-320.0, 0.0, -178.0],     # 18
		],
		"widths": {11: 13.5, 12: 13.5, 17: 19.0, 18: 17.0},
		"zones": [
			{"from": 6, "to": 9, "kind": "elevated"},
			{"from": 15, "to": 16, "kind": "tunnel"},
		],
		"pads": [{"at": 1, "offset": 40.0}, {"at": 8, "offset": 10.0}, {"at": 16, "offset": 30.0}],
		"arches": [{"at": 0, "offset": 90.0}, {"at": 4}, {"at": 10, "offset": 20.0}, {"at": 14}],
		"checkpoints": [3, 7, 11, 16],
	},
	"harbour": {
		"name": "Harbour Lights",
		"blurb": "A shorter loop along the docks: one long straight, a banked sweeper and a "
			+ "stop-start section between the warehouses.",
		"laps": 4,
		"width": 15.0,
		"grid_heading": 0.0,
		"waypoints": [
			[-180.0, 0.0, -130.0],     #  0 start / finish
			[0.0, 0.0, -140.0],        #  1
			[150.0, 0.0, -130.0],      #  2
			[215.0, 0.0, -70.0],       #  3
			[220.0, 0.0, 20.0],        #  4 sweeper
			[170.0, 0.0, 95.0],        #  5
			[80.0, 0.0, 120.0],        #  6
			[-10.0, 0.0, 100.0],       #  7 stop-start
			[-60.0, 0.0, 140.0],       #  8
			[-140.0, 0.0, 130.0],      #  9
			[-205.0, 0.0, 70.0],       # 10
			[-215.0, 0.0, -30.0],      # 11
		],
		"widths": {7: 13.0, 8: 13.0},
		"zones": [],
		"pads": [{"at": 1, "offset": 20.0}, {"at": 10}],
		"arches": [{"at": 0, "offset": 70.0}, {"at": 5}],
		"checkpoints": [3, 7, 10],
	},
}

const IDS: Array[String] = ["downtown", "harbour"]


static func has(id: String) -> bool:
	return DEFS.has(id)


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["downtown"])


static func name_of(id: String) -> String:
	return String(get_def(id)["name"])


static func laps_of(id: String) -> int:
	return int(get_def(id).get("laps", DEFAULT_LAPS))


## Build the centreline. Control points get Catmull-Rom tangents, so the loop is smooth and the
## waypoints are exactly on the racing line.
static func build_path(id: String) -> TrackPath:
	var d := get_def(id)
	var pts: Array = d["waypoints"]
	var n := pts.size()
	var curve := Curve3D.new()
	for i in n:
		var p := _v(pts[i])
		var prev := _v(pts[(i - 1 + n) % n])
		var next := _v(pts[(i + 1) % n])
		var tangent := (next - prev) * 0.25
		curve.add_point(p, -tangent, tangent)
	# close the loop back onto the first point
	curve.add_point(_v(pts[0]), -(_v(pts[1]) - _v(pts[n - 1])) * 0.25, Vector3.ZERO)
	var path := TrackPath.new(curve, true, float(d.get("width", 16.0)))
	# width profile from the per-waypoint overrides
	var widths: Dictionary = d.get("widths", {})
	if not widths.is_empty():
		var prof: Array = []
		for i in n:
			prof.append([path.point_offset(i), float(widths.get(i, d.get("width", 16.0)))])
		prof.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		path.set_width_profile(prof)
	var zones: Array = []
	for z: Dictionary in d.get("zones", []):
		zones.append({"from": path.point_offset(int(z["from"])), "to": path.point_offset(int(z["to"])),
			"kind": String(z["kind"])})
	path.zones = zones
	return path


## Distance along the path for a {"at": waypoint, "offset": metres} feature entry.
static func feature_distance(path: TrackPath, entry: Dictionary) -> float:
	return path.point_offset(int(entry.get("at", 0))) + float(entry.get("offset", 0.0))


static func _v(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
