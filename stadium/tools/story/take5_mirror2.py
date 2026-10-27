"""(Kept in the repo: regenerates take five's scene from take four's, `git show 131d50f:stadium/story/scenes/<file>`; the Mirror: take5_mirror.py, then take5_mirror2.py, then take5_knock.py.)
Take five's Mirror, round two (the first critic round's notes): the dream off the race track (a wet
city street between the towers, lamp posts, no barriers or neon strips), rain on the glass until she
appears, Kit short-lit from the window (the neon outside is the key, a rim on the hair, a low fill in
the dark), the white coupe made to read (its own light, Kit's tail lights on its bonnet), cameras
varied (fewer from the dash, a true match cut between the white mirror and the empty one), the ghost
under a cold light only she has.
    python3 mirror2.py <c01_close from mirror.py> <out.json>"""
import copy, json, sys

d = json.load(open(sys.argv[1]))
shots = d["shots"]
black = [s["id"] for s in shots].index("black")
dream = shots[:black]

KEY = {"car": "kit", "kind": "omni", "pos": [0.85, 1.2, 0.2], "colour": "#ff6fb0", "energy": 1.0, "range": 1.5}
FILL = {"car": "kit", "kind": "omni", "pos": [-0.3, 0.9, -0.4], "colour": "#2a3560", "energy": 0.25, "range": 1.6, "shadow": False}
RIM = {"car": "kit", "kind": "omni", "pos": [0.45, 1.38, -0.35], "colour": "#7fb0ff", "energy": 0.6, "range": 0.9, "shadow": False}
TAIL = {"car": "kit", "kind": "omni", "pos": [0.0, 0.9, -3.6], "colour": "#ff2a2a", "energy": 3.0, "range": 9.0, "shadow": False}
GHOST = {"car": "kit", "kind": "omni", "pos": [0.0, 0.78, -0.25], "colour": "#9fd8c8", "energy": 0.6, "range": 0.6, "shadow": False}
WHITE_LIGHTS = [{"car": "white", "kind": "omni", "pos": [0.6, 0.7, 2.2], "colour": "#f2f4ff", "energy": 8.0, "range": 3.0, "shadow": False},
                {"car": "white", "kind": "omni", "pos": [-0.6, 0.7, 2.2], "colour": "#f2f4ff", "energy": 8.0, "range": 3.0, "shadow": False},
                {"car": "white", "kind": "omni", "pos": [0.0, 1.7, 1.2], "colour": "#c8d4ff", "energy": 2.5, "range": 4.0, "shadow": False}]
HEADLIGHTS = [{"car": "kit", "kind": "spot", "pos": [s * 0.6, 0.65, 2.3], "look": [s * 0.6, 0.0, 14.0], "colour": "#e8eeff",
               "energy": 6.0, "angle": 28.0, "range": 25.0, "shadow": False} for s in (1.0, -1.0)]
# the street: wet asphalt over the field's paving along the line, lamp posts down both kerbs
STREET = [{"kind": "quay", "pos": [0.0, 0.012, 0.0], "rect": [-60.0, -160.0, 60.0, 260.0], "walls": False,
           "paint": [[-5.5, -160.0, -5.5, 260.0, 0.15, "#c8c8c0"], [5.5, -160.0, 5.5, 260.0, 0.15, "#c8c8c0"],
                     [0.0, -160.0, 0.0, 260.0, 0.12, "#d9a31e"]]}]
for z in range(-150, 260, 26):
    for x, yaw in ((7.5, 90.0), (-7.5, -90.0)):
        STREET.append({"kind": "pole", "pos": [x, 0.0, float(z)], "yaw": yaw, "height": 8.0, "colour": "#ffb36b", "energy": 5.0,
                       "shadow": False})


def cam(keys, **kw):
    c = {"follow": "kit", "ease": "inout", "keys": keys}
    c.update(kw)
    return c


def person(s, pid):
    return next((p for p in s.get("people", []) if p.get("id") == pid), None)


def lights(s, extra, cut=True):
    """The shot's lights with the dash and cabin fills cut down and `extra` added."""
    out = []
    for l in s.get("lights", []):
        l = copy.deepcopy(l)
        if cut and l.get("car") == "kit" and l.get("kind") == "omni" and l.get("colour") in ("#7fa0ff", "#9fb8ff", "#8a6bff"):
            l["energy"] = min(float(l["energy"]), 0.25)
        out.append(l)
    return out + copy.deepcopy(extra)


for s in dream:
    sid = s["id"]
    if sid != "asleep":
        s["bare"] = True
        s["props"] = copy.deepcopy(STREET)
    if sid == "rear_window":
        s["glass"] = 0.6        # (only looking out through glass with no face in frame: drops over a face read as a glitch)
    white = next((c for c in s.get("cars", []) if c["id"] == "white"), None)
    extra = [KEY, FILL, RIM] if sid not in ("asleep", "she_is_there", "hit") else []
    if white is not None:
        extra = extra + WHITE_LIGHTS
    if sid == "asleep":
        s["glass"] = 0.6
        s["camera"] = cam([{"u": 0, "pos": [0.04, 0.92, 1.02], "look": [0.3, 1.1, 0.0], "fov": 38},
                           {"u": 1, "pos": [0.15, 1.0, 0.7], "look": [0.3, 1.1, 0.0], "fov": 38}])
        s["lights"] = lights(s, [{"car": "kit", "kind": "omni", "pos": [0.85, 1.25, 0.35], "colour": "#ff7ab8", "energy": 1.2, "range": 1.6},
                                 RIM, FILL])
        continue
    if sid == "dream_road":
        s["camera"] = cam([{"u": 0, "pos": [3.0, 0.32, 6.4], "look": [0.1, 0.9, 0.0], "fov": 30, "dof_near": [0.8, 0.4, 0.12]},
                           {"u": 1, "pos": [2.7, 0.3, 5.4], "look": [0.1, 0.9, 0.0], "fov": 30}], handheld=0.35)
        extra = HEADLIGHTS + [{"car": "kit", "kind": "omni", "pos": [-2.5, 2.4, -2.5], "colour": "#ff4fa0", "energy": 4.0, "range": 7.0}] + WHITE_LIGHTS
        white["ahead"] = -60.0
    elif sid == "profile":
        s["dur"] = 1.8
        s["camera"] = cam([{"u": 0, "pos": [-0.36, 0.98, 0.24], "look": [0.37, 1.13, 0.15], "fov": 32},
                           {"u": 1, "pos": [-0.33, 0.98, 0.2], "look": [0.37, 1.13, 0.15], "fov": 32}], handheld=0.25)
        p = person(s, "kit_driver")
        p["looks"] = [[0.4, 1.3, "mirror"]]
        p["bend"] = [{"t": 0.3, "Neck": [0, 0, 0], "Head": [0, 0, 0]}, {"t": 0.5, "Neck": [0, -6, 0], "Head": [0, -12, 0]},
                     {"t": 1.2, "Neck": [0, -6, 0], "Head": [0, -12, 0]}, {"t": 1.5, "Neck": [0, 0, 0], "Head": [0, 0, 0]}]
        extra = [{"car": "kit", "kind": "omni", "pos": [0.95, 1.15, 0.25], "colour": "#ff5aa8", "energy": 1.0, "range": 1.4}, FILL] + WHITE_LIGHTS
    elif sid == "mirror_far":
        s["camera"] = cam([{"u": 0, "pos": [0.3, 1.17, -0.25], "look": [0.0, 1.131, 0.512], "fov": 24, "dof_near": [0.3, 0.2, 0.1]},
                           {"u": 1, "pos": [0.29, 1.165, -0.19], "look": [0.0, 1.131, 0.512], "fov": 24}])
        white["ahead"] = -40.0
        extra = [FILL, {"car": "kit", "kind": "omni", "pos": [0.2, 1.42, -0.1], "colour": "#ff5fa8", "energy": 0.5, "range": 0.7,
                        "shadow": False}] + WHITE_LIGHTS
    elif sid == "coupe_low":
        s["camera"] = cam([{"u": 0, "pos": [-0.95, 0.28, -2.6], "look": [-0.4, 1.6, -60.0], "fov": 18, "dof_near": [1.0, 0.5, 0.15]},
                           {"u": 1, "pos": [-0.92, 0.29, -2.5], "look": [-0.4, 1.6, -60.0], "fov": 18}], handheld=0.4)
        extra = [TAIL] + WHITE_LIGHTS
    elif sid == "closer":
        s["camera"] = cam([{"u": 0, "pos": [-0.25, 1.1, 0.55], "look": [0.37, 1.08, -0.15], "fov": 32},
                           {"u": 1, "pos": [-0.22, 1.1, 0.5], "look": [0.37, 1.08, -0.15], "fov": 32}])
    elif sid == "rear_window":
        s["camera"] = cam([{"u": 0, "pos": [0.02, 1.18, -0.05], "look": [-0.05, 1.0, -16.0], "fov": 20, "dof_near": [0.9, 0.4, 0.12]},
                           {"u": 1, "pos": [0.02, 1.18, -0.12], "look": [-0.05, 1.0, -16.0], "fov": 20, "dof_near": [0.9, 0.4, 0.12]}],
                          handheld=0.3)
        extra = [TAIL, FILL] + WHITE_LIGHTS
    elif sid == "glare":
        s["camera"] = cam([{"u": 0, "pos": [-0.28, 1.05, 0.4], "look": [0.37, 1.12, -0.2], "fov": 30}], handheld=0.6)
        s["lights"] = [l for l in s["lights"] if not (l.get("kind") == "spot")]
        extra = [{"car": "kit", "kind": "spot", "pos": [0.05, 1.22, -3.0], "look": [0.35, 1.12, 0.1], "colour": "#eef2ff",
                  "energy": 12.0, "angle": 22.0, "range": 9.0}, FILL] + WHITE_LIGHTS
        p = person(s, "kit_driver")
        p["looks"] = [[0.0, 1.1, "ahead"], [1.2, 1.5, "mirror"]]
        p["shapes"] = dict(p.get("shapes", {}), eyeSquintLeft=0.9, eyeSquintRight=0.9, browDownLeft=0.5, browDownRight=0.5)
        p["bend"] = [{"t": 0.0, "Head": [0, 0, 0]}, {"t": 0.3, "Head": [0, 18, 0]}, {"t": 1.0, "Head": [0, 18, 0]},
                     {"t": 1.3, "Neck": [0, -6, 0], "Head": [-5, -12, 0]}]
    elif sid in ("whiteout", "empty_road"):
        mk = [{"u": 0, "pos": [0.3, 1.15, -0.1], "look": [0.0, 1.131, 0.512], "fov": 16}]
        if sid == "whiteout":
            mk = [{"u": 0, "pos": [0.3, 1.15, -0.1], "look": [0.0, 1.131, 0.512], "fov": 16, "exposure": 1.0},
                  {"t": 0.3, "pos": [0.3, 1.15, -0.1], "look": [0.0, 1.131, 0.512], "fov": 16, "exposure": 1.0},
                  {"t": 0.7, "pos": [0.3, 1.15, -0.08], "look": [0.0, 1.131, 0.512], "fov": 16, "exposure": 4.0}]
            extra = [FILL] + WHITE_LIGHTS
        else:
            extra = [FILL, dict(TAIL, energy=2.0), {"car": "kit", "kind": "omni", "pos": [0.2, 1.42, -0.1], "colour": "#ff5fa8",
                                                     "energy": 0.5, "range": 0.7, "shadow": False}]
        s["camera"] = cam(mk, ease="in" if sid == "whiteout" else "inout", handheld=0.4)
    elif sid == "breath_out":
        s["camera"] = cam([{"u": 0, "pos": [-0.45, 1.12, 0.6], "look": [0.35, 1.0, -0.2], "fov": 40},
                           {"u": 1, "pos": [-0.47, 1.12, 0.74], "look": [0.35, 1.0, -0.2], "fov": 40}])
        s["cars"][0]["dome"] = 0.25
        extra = [FILL, {"car": "kit", "kind": "omni", "pos": [0.0, 1.28, -0.1], "colour": "#ffd9a8", "energy": 0.4, "range": 1.2}]
        p = person(s, "kit_driver")
        p["gaze"] = "ahead"
    elif sid == "she_is_there":
        s["camera"] = cam([{"u": 0, "pos": [0.3, 1.17, -0.15], "look": [0.0, 1.131, 0.512], "fov": 18},
                           {"u": 1, "pos": [0.295, 1.168, -0.11], "look": [0.0, 1.131, 0.512], "fov": 18}])
        s["cars"][0]["dome"] = 0.0
        extra = [GHOST]
        g = person(s, "passenger")
        g["bend"] = [{"t": 0.0, "Neck": [0, 0, 0], "Head": [-6, 0, 0]}]
        g["gaze"] = "mirror"
    elif sid == "eyes":
        s["camera"] = cam([{"u": 0, "pos": [0.22, 1.125, 0.43], "look": [0.37, 1.12, 0.16], "fov": 18},
                           {"u": 1, "pos": [0.225, 1.125, 0.42], "look": [0.37, 1.12, 0.16], "fov": 18}])
        extra = [{"car": "kit", "kind": "spot", "pos": [0.21, 1.1, 0.43], "look": [0.37, 1.12, 0.16], "colour": "#d8e4ff",
                  "energy": 1.5, "angle": 10.0, "range": 1.0, "shadow": False}, FILL]
        p = person(s, "kit_driver")
        p["shapes"] = dict(p.get("shapes", {}), jawOpen=0.12, mouthFrownLeft=0.15, mouthFrownRight=0.15)
    elif sid == "look_back":
        s["camera"]["keys"][0]["look"] = [0.3, 1.07, 0.15]
        s["camera"]["keys"][1]["look"] = [0.3, 1.07, 0.15]
        s["cars"][0]["dome"] = 0.2
        extra = [FILL, {"car": "kit", "kind": "omni", "pos": [0.1, 1.28, -0.15], "colour": "#cfe0ff", "energy": 0.5, "range": 0.9},
                 {"car": "kit", "kind": "omni", "pos": [0.85, 1.2, 0.3], "colour": "#ff4fa0", "energy": 0.6, "range": 1.0, "shadow": False}]
    elif sid == "dead_air":
        s["camera"] = cam([{"u": 0, "pos": [0.45, 1.1, 0.6], "look": [-0.35, 0.92, -0.1], "fov": 34}])
        extra = [FILL, {"car": "kit", "kind": "omni", "pos": [-0.35, 1.25, 0.1], "colour": "#9fb8ff", "energy": 1.2, "range": 1.0}]
    elif sid == "hit":
        # Kit's eyes, turned back: her face right there in the lens, lit from under (the camera in front of
        # Kit's face, looking where Kit looks, so Kit isn't in it)
        s["camera"] = cam([{"u": 0, "pos": [0.27, 1.0, 0.34], "look": [0.02, 1.06, -0.05], "fov": 36},
                           {"t": 0.15, "pos": [0.24, 1.0, 0.29], "look": [0.02, 1.06, -0.05], "fov": 36}], ease="out", handheld=0.8)
        s["cars"][0]["dome"] = 0.35
        for l in s["lights"]:
            if l.get("colour") == "#c4d4ff":
                l["energy"] = 0.7
        extra = [{"car": "kit", "kind": "omni", "pos": [0.05, 0.8, 0.12], "colour": "#9fd8c8", "energy": 1.2, "range": 0.6, "shadow": False}]
        g = person(s, "passenger")
        g["gaze"] = "camera"            # her face to the lens, beside Kit's: a stare at us
        g["bend"] = [{"t": 0.0, "Spine": [18, 4, -4], "Chest": [8, 0, -2], "Neck": [-15, 0, 0], "Head": [-25, -15, -4]},
                     {"t": 0.12, "Spine": [21, 4, -5], "Chest": [8, 0, -2], "Neck": [-15, 0, 0], "Head": [-25, -15, -4]}]
        k = person(s, "kit_driver")
        k["bend"] = [{"t": 0.0, "Chest": [3, 0, 0]}, {"t": 0.05, "Chest": [-3, 0, 0], "Head": [0, -15, 0]}]
    s["lights"] = lights(s, extra, cut=sid not in ("hit",))

json.dump(d, open(sys.argv[2], "w"), indent="\t")
print("Mirror round two: %d shots, %.1f s before the black" % (len(dream), sum(float(x["dur"]) for x in dream)))
