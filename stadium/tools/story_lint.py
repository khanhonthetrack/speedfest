#!/usr/bin/env python3
"""Lints a cutscene's camera work against the quality gate (docs/CINEMATICS.md) before any still
or render: every shot's length and camera setup, zooms inside a shot, cuts back and forth between
the same two cameras, how long the ghost is on screen, and how much the shots' lengths vary.

    stadium/tools/story_lint.py c01_close [c01_open ...] [--ghost=passenger] [--timeline=<file>]

A scene is an id (story/scenes/<id>.json) or a path. Shot times come from the story lab's timeline
(story_lab.tscn --no_stage, headless, a few seconds), or --timeline=<a saved one>. Prints a line a
shot and the scene's figures; FAIL lines break the gate (exit 1), WARN lines are for the critic."""
import json, math, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
STADIUM = os.path.dirname(HERE)
ZOOM_FOV = 3.0          # a fov change over this ...
ZOOM_MOVE = 0.1         # ... with the camera moving less than this (m) is a zoom
MAX_ALTERNATING = 4     # cuts in a row between the same two setups
GHOST_MAX = 1.5         # s the ghost may be on screen in a scene
CLOSE_FOV = 24.0        # a lens this long on a person is a close-up ...
CLOSE_MAX = 1.5         # ... held this long at most
LONG_HOLD = 6.0         # s: a shot this long had better be carrying lines
MIN_SD = 1.0            # s: shot lengths across a scene vary at least this much
MIN_SETUPS = 6          # camera setups in a scene over 30 s


def timeline(scene, path):
    """The scene's shot times: `scene` an id or a scene file's path; `path` a saved timeline."""
    if path:
        text = open(path).read()
    else:
        which = "--file=" + os.path.abspath(scene) if scene.endswith(".json") else "--scene=" + scene
        cmd = [os.path.join(HERE, "run.sh"), "res://story/story_lab.tscn", "--headless", "--",
               which, "--no_stage", "--frames=2"]
        text = subprocess.run(cmd, capture_output=True, text=True, timeout=600, stdin=subprocess.DEVNULL).stdout
    out = []
    for m in re.finditer(r"^SHOT (\S+) ([\d.]+)-([\d.]+) s", text, re.M):
        out.append((m.group(1), float(m.group(2)), float(m.group(3))))
    return out


def vec(v):
    return v if isinstance(v, str) else tuple(float(x) for x in v)


def keys_of(cam):
    keys = cam.get("keys", [])
    if not keys and "pos" in cam:
        keys = [cam]
    return keys


def dist(a, b):
    if isinstance(a, str) or isinstance(b, str):
        return 0.0 if a == b else 99.0
    return math.dist(a, b)


def direction(k):
    p, l = vec(k.get("pos", [4, 1.5, 7])), vec(k.get("look", [0, 0.7, 0]))
    if isinstance(p, str) or isinstance(l, str):      # a place in the car, a person's face: not known here
        return None
    d = [l[i] - p[i] for i in range(3)]
    n = math.sqrt(sum(x * x for x in d)) or 1.0
    return [x / n for x in d]


def same_setup(a, b):
    """Two shots' cameras are one setup: same frame, the first key within 0.3 m, aimed within 10
    degrees, the lens within 4 degrees."""
    if a["frame"] != b["frame"]:
        return False
    if dist(a["pos"], b["pos"]) > 0.3 or abs(a["fov"] - b["fov"]) > 4.0:
        return False
    if a["dir"] is None or b["dir"] is None:
        return a["dir"] is None and b["dir"] is None
    return sum(x * y for x, y in zip(a["dir"], b["dir"])) > math.cos(math.radians(10))


def lint(arg, ghosts, tl_path):
    path = arg if arg.endswith(".json") else os.path.join(STADIUM, "story", "scenes", arg + ".json")
    d = json.load(open(path))
    times = {sid: (a, b) for sid, a, b in timeline(arg, tl_path)}
    fails, warns, setups, seq, lengths = [], [], [], [], []
    shot_warns = 0
    ghost_time = 0.0
    print("SCENE %s" % d.get("id", arg))
    for s in d.get("shots", []):
        sid = s.get("id", "?")
        if sid not in times:
            continue                          # a variant the default save doesn't play
        start, end = times[sid]
        dur = end - start
        flags = []
        if s.get("black"):
            print("  %-16s %6.2f-%6.2f %5.2f s  black" % (sid, start, end, dur))
            continue
        lengths.append(dur)
        cam = s.get("camera", {})
        keys = keys_of(cam)
        k0 = keys[0] if keys else {"pos": [4, 1.5, 7]}
        me = {"frame": cam.get("follow", ""), "pos": vec(k0.get("pos", [4, 1.5, 7])),
              "fov": float(k0.get("fov", 40)), "dir": direction(k0)}
        idx = next((i for i, o in enumerate(setups) if same_setup(o, me)), None)
        if idx is None:
            setups.append(me)
            idx = len(setups) - 1
        seq.append(idx)
        fovs = [float(k.get("fov", 40)) for k in keys] or [40.0]
        for a, b in zip(keys, keys[1:]):
            dfov = abs(float(b.get("fov", a.get("fov", 40))) - float(a.get("fov", 40)))
            moved = dist(vec(a.get("pos", [4, 1.5, 7])), vec(b.get("pos", a.get("pos", [4, 1.5, 7]))))
            if dfov > ZOOM_FOV and moved < ZOOM_MOVE:
                flags.append("FAIL zoom inside the shot (fov %.1f to %.1f, the camera moving %.2f m)" % (
                    float(a.get("fov", 40)), float(b.get("fov", a.get("fov", 40))), moved))
        people = s.get("people", [])
        if min(fovs) <= CLOSE_FOV and people and dur > CLOSE_MAX:
            flags.append("WARN a close-up (fov %.0f) held %.1f s (%.1f at most)" % (min(fovs), dur, CLOSE_MAX))
        if dur > LONG_HOLD and len(s.get("lines", [])) * 3.0 < dur:
            flags.append("WARN held %.1f s with %d lines" % (dur, len(s.get("lines", []))))
        if len(keys) <= 1 and not cam.get("shake") and not cam.get("handheld"):
            flags.append("WARN locked off (one key, no handheld)")
        for p in people:
            if p.get("who") in ghosts:
                a = max(0.0, float(p.get("from", 0.0)))
                b = min(dur, float(p.get("to", dur)))
                if b > a:
                    ghost_time += b - a
                    flags.append("ghost on screen %.1f s" % (b - a))
        for f in flags:
            if f.startswith("FAIL"):
                fails.append("%s: %s" % (sid, f[5:]))
            elif f.startswith("WARN"):
                shot_warns += 1
        print("  %-16s %6.2f-%6.2f %5.2f s  setup %-2d fov %s  %s" % (
            sid, start, end, dur, idx + 1, "%.0f" % fovs[0] if len(set(fovs)) == 1 else "%.0f-%.0f" % (fovs[0], fovs[-1]),
            "; ".join(flags)))
    # cuts back and forth between the same two setups
    run, worst, worst_at = 1, 1, 0
    for i in range(2, len(seq)):
        if seq[i] == seq[i - 2] and seq[i] != seq[i - 1]:
            run += 1
            if run > worst:
                worst, worst_at = run, i
        else:
            run = 1
    cuts = worst if worst > 1 else 0
    if cuts > MAX_ALTERNATING:
        fails.append("%d cuts in a row between setups %d and %d (%d at most)" % (
            cuts, seq[worst_at] + 1, seq[worst_at - 1] + 1, MAX_ALTERNATING))
    if ghost_time > GHOST_MAX:
        fails.append("the ghost on screen %.1f s (%.1f at most)" % (ghost_time, GHOST_MAX))
    n = len(lengths)
    mean = sum(lengths) / n if n else 0.0
    sd = math.sqrt(sum((x - mean) ** 2 for x in lengths) / n) if n else 0.0
    if n > 4 and sd < MIN_SD:
        warns.append("shot lengths vary by %.2f s (sd; %.1f wanted)" % (sd, MIN_SD))
    total = sum(lengths)
    if total > 30.0 and len(setups) < MIN_SETUPS:
        warns.append("%d camera setups in %.0f s (%d wanted)" % (len(setups), total, MIN_SETUPS))
    print("  %d shots, %d setups, shot length mean %.2f s sd %.2f s, longest run of alternating cuts %d, ghost %.1f s, %d shot warnings" % (
        n, len(setups), mean, sd, cuts, ghost_time, shot_warns))
    for w in warns:
        print("  WARN " + w)
    for f in fails:
        print("  FAIL " + f)
    return len(fails)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    ghosts = set(opts.get("ghost", "passenger").split(","))
    if not args:
        print(__doc__)
        sys.exit(2)
    fails = sum(lint(a, ghosts, opts.get("timeline")) for a in args)
    print("LINT_FAIL %d" % fails if fails else "LINT_OK")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
