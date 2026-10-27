"""(Kept in the repo: regenerates take five's scene from take four's, `git show 131d50f:stadium/story/scenes/<file>`; the Mirror: take5_mirror.py, then take5_mirror2.py, then take5_knock.py.)
Take five's Mirror (docs/CINEMATICS.md, first pass item 4): replaces c01_close's dream (the shots
before "black") with a re-cut: new angles (outside tracking, the profile through the passenger
window, the coupe low on a long lens, the rear window, Kit's eyes, the empty seat, the ear), shots
shortening towards the whiteout, the ghost on screen about a second, no zoom inside a shot.
    python3 mirror.py <take4 c01_close.json> <out.json>"""
import copy, json, sys

src = json.load(open(sys.argv[1]))
old = {s["id"]: s for s in src["shots"]}
i_black = [s["id"] for s in src["shots"]].index("black")
rest = src["shots"][i_black:]

KIT_CAR = {"id": "kit", "model": "nemesis", "livery": 1, "tuning": "0.5.6.0", "lights": True, "cabin": True,
           "speed": 20.0, "ahead": 0.0, "finish": "gloss"}
WHITE = {"id": "white", "model": "nemesis", "livery": 2, "tuning": "0.0.6.0", "lights": True}
CABIN_LIGHT = {"car": "kit", "kind": "omni", "pos": [0.05, 1.0, 0.75], "colour": "#9fb8ff", "energy": 0.5, "range": 1.6,
               "shadow": False}
DASH_GLOW = {"car": "kit", "kind": "omni", "pos": [0.32, 0.93, 0.55], "colour": "#7fa0ff", "energy": 0.8, "range": 1.0,
             "shadow": False}           # the instruments' glow under Kit's face
DASH = [0.12, 1.0, 0.88]          # the dash camera, looking back at Kit
KIT_HEAD = [0.37, 1.07, 0.15]
MIRROR = [0.0, 1.131, 0.512]
OVER = [0.35, 1.2, -0.55]         # over the shoulder, at the mirror
UNEASY = {"browInnerUp": 0.35, "jawOpen": 0.03, "browDownLeft": 0.08, "browDownRight": 0.08,
          "mouthFrownLeft": 0.12, "mouthFrownRight": 0.12}
AFRAID = {"browInnerUp": 0.65, "jawOpen": 0.1, "browDownLeft": 0.15, "browDownRight": 0.15,
          "mouthFrownLeft": 0.25, "mouthFrownRight": 0.25}
TERROR = {"browInnerUp": 0.95, "jawOpen": 0.22, "browDownLeft": 0.2, "browDownRight": 0.2,
          "mouthFrownLeft": 0.35, "mouthFrownRight": 0.35}
GLANCE = {"Neck": [0, -6, 0], "Head": [-5, -12, 0]}       # eyes up to the mirror
AHEAD = {"Neck": [0, 0, 0], "Head": [0, 0, 0]}
# the look back as a body move: the spine, chest and neck turn with the head (the audit's)
BACK = {"Spine": [0, -10, 0], "Chest": [0, -12, 0], "UpperChest": [0, -14, 0], "Neck": [2, -25, 0], "Head": [4, -32, 5]}
FRONT = {"Spine": [0, 0, 0], "Chest": [0, 0, 0], "UpperChest": [0, 0, 0], "Neck": [0, 0, 0], "Head": [0, 0, 0]}


def key(t, pose):
    k = {"t": t}
    k.update(copy.deepcopy(pose))
    return k


def kit(shapes=None, looks=None, bend=None, **kw):
    p = {"id": "kit_driver", "car": "kit", "seat": "driver", "clip": "Driving", "who": "kit"}
    if shapes:
        p["shapes"] = shapes
    if looks:
        p["looks"] = looks
    if bend:
        p["bend"] = bend
    p.update(kw)
    return p


def ghost(**kw):
    p = {"id": "passenger", "car": "kit", "clip": "Sitting_Idle", "rate": 0.0, "look": "drowned", "who": "passenger",
         "blink": False, "shapes": {"jawOpen": 0.12}, "pos": [0.0, -0.06, -0.349], "gaze": "kit_driver",
         "bend": [{"t": 0.0, "Neck": [6, 0, 0], "Head": [16, 0, 0]}]}
    p.update(kw)
    return p


def cam(keys, follow="kit", **kw):
    c = {"follow": follow, "ease": "inout", "keys": keys}
    c.update(kw)
    return c


def drive(sid, dur, camera, people, white=None, **kw):
    cars = [copy.deepcopy(KIT_CAR)]
    if white is not None:
        w = copy.deepcopy(WHITE)
        w["speed"], w["ahead"] = white
        cars.append(w)
    s = {"id": sid, "track": "H01", "at": 0.15, "dur": dur, "rain": 0.8, "glass": 0.0, "ambience": "rain",
         "cars": cars, "people": people, "lights": [copy.deepcopy(CABIN_LIGHT), copy.deepcopy(DASH_GLOW)], "camera": camera}
    s.update(kw)
    return s


shots = []
# 1. asleep under the arch: the dash camera eases in on Kit (a move, not a zoom)
a = copy.deepcopy(old["asleep"])
a["dur"] = 3.0
a["props"].append({"kind": "quay", "pos": [0.0, 0.012, 0.0], "rect": [-40.0, -40.0, 5.6, 40.0], "walls": False, "wetness": 0.8})
a["camera"] = cam([{"u": 0, "pos": DASH, "look": [0.22, 1.05, 0.0], "fov": 42},
                   {"u": 1, "pos": [0.15, 1.02, 0.76], "look": [0.24, 1.05, 0.0], "fov": 42}])
for p in a["people"]:
    p["bend"] = [{"t": 0.0, "Neck": [6, 0, -4], "Head": [10, 0, -12]}, {"t": 2.4, "Neck": [6, 0, -4], "Head": [10, 0, -12]},
                 {"t": 3.0, "Neck": [2, 0, -2], "Head": [4, 0, -4]}]
shots.append(a)
# 2. the dream: outside, low at the front wing, the car tracking through the rain, Kit at the wheel
shots.append(drive("dream_road", 3.2, cam([{"u": 0, "pos": [3.6, 1.05, 6.8], "look": [0.1, 0.8, 0.2], "fov": 32},
                                            {"u": 1, "pos": [3.2, 1.0, 5.6], "look": [0.1, 0.85, 0.0], "fov": 32}],
                                           handheld=0.35),
                   [kit()], white=[25.5, -110.0]))
# 3. Kit in profile through the passenger window; the eyes go up to the mirror
# Kit in profile from the passenger seat, the street sliding past the driver's window behind
shots.append(drive("profile", 2.6, cam([{"u": 0, "pos": [-0.36, 1.08, 0.24], "look": [0.37, 1.07, 0.15], "fov": 32},
                                         {"u": 1, "pos": [-0.33, 1.08, 0.2], "look": [0.37, 1.07, 0.15], "fov": 32}], handheld=0.25),
                   [kit(UNEASY, [[1.1, 2.2, "mirror"]], [key(0.9, AHEAD), key(1.2, GLANCE), key(2.1, GLANCE), key(2.45, AHEAD)])],
                   white=[25.4, -94.0]))
# 4. the mirror: headlights, far back
shots.append(drive("mirror_far", 2.0, cam([{"u": 0, "pos": OVER, "look": [0.21, 1.095, 0.435], "fov": 26},
                                            {"u": 1, "pos": [0.33, 1.19, -0.45], "look": [0.2, 1.1, 0.44], "fov": 26}]),
                   [kit(UNEASY, [[0.0, 2.0, "mirror"]], [key(0.0, GLANCE)])], white=[25.3, -84.0],
                   mirror={"glass": True, "follow": "kit"}))
# 5. the white coupe from the road, low on a long lens: the gap looks short
shots.append(drive("coupe_low", 2.2, cam([{"u": 0, "pos": [-1.3, 0.4, -5.5], "look": [-0.4, 0.7, -60.0], "fov": 18},
                                           {"u": 1, "pos": [-1.25, 0.42, -5.2], "look": [-0.4, 0.75, -60.0], "fov": 18}],
                                          handheld=0.4),
                   [kit()], white=[26.0, -62.0]))
# 6. closer: Kit checks the mirror, then looks back over the shoulder, the camera easing in
c = old["closer"]["people"][0]
shots.append(drive("closer", 2.5, cam([{"u": 0, "pos": DASH, "look": [0.22, 1.05, 0.0], "fov": 40},
                                        {"u": 1, "pos": [0.14, 1.01, 0.76], "look": [0.24, 1.05, 0.0], "fov": 40}]),
                   [kit(AFRAID, [[0.2, 0.7, "mirror"], [1.0, 1.9, "rear"], [2.1, 2.5, "mirror"]],
                        [key(0.0, AHEAD), key(0.25, GLANCE), key(0.65, GLANCE), key(0.85, FRONT), key(1.15, BACK),
                         key(1.75, BACK), key(2.05, FRONT), key(2.35, GLANCE)])],
                   white=[26.7, -48.0]))
# 7. the rear window filling with headlights, the empty back seat soft in front of it
shots.append(drive("rear_window", 1.5, cam([{"u": 0, "pos": [0.02, 1.08, 0.0], "look": [-0.05, 1.22, -3.0], "fov": 20,
                                              "dof_near": [0.9, 0.4, 0.12]},
                                             {"u": 1, "pos": [0.02, 1.08, -0.1], "look": [-0.05, 1.22, -3.0], "fov": 20}],
                                            handheld=0.3),
                   [kit(AFRAID)], white=[26.0, -16.0]))
# 8. glare: light floods the cabin from behind, Kit squints
g = copy.deepcopy(old["glare"])
g["dur"] = 1.5
g["camera"] = cam([{"u": 0, "pos": DASH, "look": [0.22, 1.05, 0.0], "fov": 42}], handheld=0.6)
g["cars"][1]["ahead"] = -13.0
shots.append(g)
# 9. whiteout: the mirror burns white (the exposure flares over 0.4 s, the 2D flash only the last frames)
w = copy.deepcopy(old["whiteout"])
w["dur"] = 0.8
w["camera"] = cam([{"u": 0, "pos": OVER, "look": [0.0, 1.131, 0.512], "fov": 14, "exposure": 1.0},
                   {"t": 0.3, "pos": OVER, "look": [0.0, 1.131, 0.512], "fov": 14, "exposure": 1.0},
                   {"t": 0.7, "pos": [0.35, 1.2, -0.5], "look": [0.0, 1.131, 0.512], "fov": 14, "exposure": 8.0}],
                  ease="in", handheld=0.5)
w["flash"] = [[0.72, 0.08]]
w["sounds"] = [{"at": 0.7, "cue": "thump", "db": -3.0}]
w["cars"][1]["ahead"] = -7.0
shots.append(w)
# 10. the mirror again: the road behind empty
e = copy.deepcopy(old["empty_road"])
e["dur"] = 1.4
e["camera"] = cam([{"u": 0, "pos": OVER, "look": [0.21, 1.095, 0.435], "fov": 24}], handheld=0.3)
e["flash"] = [[0.0, 0.5]]
for p in e["people"]:
    p["bend"] = [key(0.0, GLANCE), key(1.0, GLANCE), key(1.4, AHEAD)]
    p["looks"] = [[0.0, 1.0, "mirror"]]
shots.append(e)
# 11. breath out: Kit sinks back, the drip starts
b = copy.deepcopy(old["breath_out"])
b["dur"] = 2.5
b["camera"] = cam([{"u": 0, "pos": [0.1, 1.02, 0.8], "look": [0.24, 1.04, 0.0], "fov": 36},
                   {"u": 1, "pos": [0.12, 1.03, 0.72], "look": [0.25, 1.04, 0.0], "fov": 36}])
b["sounds"] = [{"at": 0.2, "cue": "breath"}, {"at": 1.6, "cue": "drip", "db": -10.0}]
shots.append(b)
# 12. she is there: the mirror at a fixed lens, the back seat dim; she shows in its last half second
s = copy.deepcopy(old["she_is_there"])
s["dur"] = 1.4
s["camera"] = cam([{"u": 0, "pos": OVER, "look": [0.21, 1.095, 0.435], "fov": 26},
                   {"u": 1, "pos": [0.34, 1.195, -0.5], "look": [0.2, 1.1, 0.44], "fov": 26}])
s["cars"][0]["dome"] = 0.12
s["sounds"] = [{"at": 0.9, "cue": "drone", "db": -6.0}]
s["people"] = [kit(UNEASY, [[0.0, 1.4, "ahead"]]), ghost(**{"from": 0.9})]
shots.append(s)
# 13. Kit's eyes, from the mirror: they find her
ey = drive("eyes", 0.8, cam([{"u": 0, "pos": [0.1, 1.12, 0.46], "look": [0.37, 1.115, 0.17], "fov": 20},
                             {"u": 1, "pos": [0.11, 1.12, 0.44], "look": [0.37, 1.115, 0.17], "fov": 20}]),
           [kit(TERROR, [[0.0, 0.8, "mirror"]], [key(0.0, GLANCE)], blink=False)])
ey.update({"rain": 0.0, "ambience": ["drip", "drone"]})
ey["cars"][0]["dome"] = 0.12
shots.append(ey)
# 14. the look back: Kit twists round in the seat
# from the back seat, where she was: Kit turns round into the lens
lb = drive("look_back", 1.2, cam([{"u": 0, "pos": [-0.12, 1.06, -0.5], "look": [0.37, 1.07, 0.15], "fov": 34},
                                  {"u": 1, "pos": [-0.1, 1.06, -0.44], "look": [0.37, 1.07, 0.15], "fov": 34}], handheld=0.5),
           [kit(TERROR, [[0.15, 1.2, "rear"]], [key(0.0, GLANCE), key(0.35, BACK)], blink=False)])
lb.update({"rain": 0.0, "ambience": ["drip", "drone"]})
lb["cars"][0]["dome"] = 0.12
shots.append(lb)
# 15. the empty seat, from Kit's eyes: wet, nobody
es = drive("empty_seat", 0.8, cam([{"u": 0, "pos": [0.12, 1.12, -0.02], "look": [-0.08, 0.62, -0.55], "fov": 40},
                                   {"u": 1, "pos": [0.11, 1.12, -0.05], "look": [-0.08, 0.6, -0.55], "fov": 40}], handheld=0.6),
           [kit(TERROR)])
es.update({"rain": 0.0, "ambience": "drip"})
es["cars"][0]["dome"] = 0.8
es["lights"].append({"car": "kit", "kind": "omni", "pos": [-0.25, 1.2, -0.3], "colour": "#ffb26b", "energy": 2.2, "range": 1.6,
                     "shadow": False})        # a street lamp through the side glass, on the wet seat
# (cut after the stills: the back seat doesn't read in the dark, and the look back is shot from it)
# 16. dead air: Kit turns back to the road, breathing
d = copy.deepcopy(old["dead_air"])
d["dur"] = 1.0
d["camera"] = cam([{"u": 0, "pos": DASH, "look": [0.2, 1.04, 0.0], "fov": 34}], handheld=0.4)
for p in d["people"]:
    p["bend"] = [key(0.0, BACK), key(0.45, FRONT)]
    p["looks"] = [[0.0, 0.3, "rear"]]
shots.append(d)
# 17. the hit: she is at Kit's ear, soft in the foreground; the camera jolts in, no zoom
h = copy.deepcopy(old["hit"])
# from the front: Kit sharp, her face at Kit's ear behind, soft; the camera jolts in
h["camera"] = cam([{"u": 0, "pos": [-0.3, 1.1, 0.6], "look": [0.3, 1.07, 0.05], "fov": 32, "dof": [0.8, 0.3, 0.12]},
                   {"t": 0.15, "pos": [-0.24, 1.1, 0.52], "look": [0.3, 1.07, 0.05], "fov": 32, "dof": [0.75, 0.3, 0.12]}],
                  ease="out", handheld=0.8)
h["camera"].pop("shake", None)
shots.append(h)

# every driving shot: the instruments' glow under Kit's face
for x in shots[1:]:
    if not any(l.get("pos") == DASH_GLOW["pos"] for l in x.get("lights", [])):
        x.setdefault("lights", []).append(copy.deepcopy(DASH_GLOW))

out = copy.deepcopy(src)
out["grade"] = "night"
out["shots"] = shots + rest
json.dump(out, open(sys.argv[2], "w"), indent="\t")
print("Mirror: %d shots, %.1f s before the black" % (len(shots), sum(float(x["dur"]) for x in shots)))
