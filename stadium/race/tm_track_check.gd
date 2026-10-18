class_name TmTrackCheck
extends RefCounted
## Whether a track (TmChallenge) can be raced here, without building it: every block is a known
## Stadium block whose shape we recreate (TmBlockLib), and it has a start and a finish (or a
## start/finish line for a lap race). Used by the compatibility test (community tracks from
## TrackMania Exchange) and before racing a downloaded track.
##
## check() -> {ok (bool), raceable (bool), modded (a TMUnlimiter track, or blocks that aren't TMNF
##             Stadium blocks), why (String), missing ({shape or "?block": count}),
##             blocks (int), starts, finishes, checkpoints, lines (int)}


static func check(ch: TmChallenge, lib: TmBlockLib) -> Dictionary:
	var out := {"ok": false, "raceable": false, "modded": false, "why": "", "missing": {}, "blocks": 0,
		"starts": 0, "finishes": 0, "checkpoints": 0, "lines": 0}
	var missing: Dictionary = out["missing"]
	if not ch.ok():
		out["why"] = ch.error
		return out
	if ch.unlimiter:
		out["why"] = "a TMUnlimiter track: its blocks are in TMUnlimiter's own format"
		out["modded"] = true
		return out
	for blk: Dictionary in ch.blocks:
		var flags := int(blk["flags"])
		if flags == 0xFFFFFFFF:
			continue
		out["blocks"] += 1
		var id := String(blk["name"])
		var entry := TmBlockCatalogue.info(id)
		if entry.is_empty():
			missing["?" + id] = int(missing.get("?" + id, 0)) + 1
			out["modded"] = true    # custom blocks or another environment's (a modded track)
			continue
		var ground := bool(blk["ground"])
		var shape := TmBlockCatalogue.shape_name(entry, ground, flags & 0x3F, (flags >> 6) & 0x3F)
		if not shape.is_empty() and not lib.handles(shape):
			missing[shape] = int(missing.get(shape, 0)) + 1
		match int(entry.get("waypoint", TmBlockCatalogue.Waypoint.NONE)):
			TmBlockCatalogue.Waypoint.START:
				out["starts"] += 1
			TmBlockCatalogue.Waypoint.FINISH:
				out["finishes"] += 1
			TmBlockCatalogue.Waypoint.CHECKPOINT:
				out["checkpoints"] += 1
			TmBlockCatalogue.Waypoint.START_FINISH:
				out["lines"] += 1
	var has_start: bool = out["starts"] > 0 or out["lines"] > 0
	var has_finish: bool = out["finishes"] > 0 or out["lines"] > 0
	out["raceable"] = has_start and has_finish
	if not has_start:
		out["why"] = "no start block"
	elif not has_finish:
		out["why"] = "no finish block"
	elif not missing.is_empty():
		out["why"] = "%d block shapes not recreated" % missing.size()
	out["ok"] = out["raceable"] and missing.is_empty()
	return out
