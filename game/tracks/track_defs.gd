class_name TrackDefs
extends RefCounted
## Static metadata for the three tracks. Layouts live in res://tracks/defs/<id>.gd.

const IDS: Array[String] = ["downtown", "arena", "coast"]

const DEFS := {
	"downtown": {
		"name": "Neon Downtown",
		"theme": "city",
		"circuit": true,
		"blurb": "Rain-slick night streets, neon signs, an elevated highway and a sodium-lit tunnel.",
		"target_s": 60,
	},
	"arena": {
		"name": "Pulse Arena",
		"theme": "arena",
		"circuit": true,
		"blurb": "A neon stunt stadium: boost pads, a vertical loop, a gap jump and a banked 180.",
		"target_s": 45,
	},
	"coast": {
		"name": "Sunset Coast",
		"theme": "coast",
		"circuit": false,
		"blurb": "A dusk sprint along cliffside highway: fast sweepers, a rock tunnel and a bridge.",
		"target_s": 60,
	},
}

const DURATIONS_S: Array[int] = [180, 300, 420, 600]
const DEFAULT_DURATION_S := 300


static func get_def(track_id: String) -> Dictionary:
	return DEFS.get(track_id, DEFS["arena"])


static func display_name(track_id: String) -> String:
	return get_def(track_id)["name"]


static func theme(track_id: String) -> String:
	return get_def(track_id)["theme"]
