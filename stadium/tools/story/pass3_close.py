"""(Kept in the repo.) The third pass on night 1's close (docs/CINEMATICS.md, "third pass to 7/10"):
edits the committed scene in place, so it runs on take five's c01_close.json and again on its own
output without changing it twice.
    python3 tools/story/pass3_close.py stadium/story/scenes/c01_close.json"""
import copy, json, sys

path = sys.argv[1]
scene = json.load(open(path))
shots = {s["id"]: s for s in scene["shots"]}
ids = [s["id"] for s in scene["shots"]]
KNOCK = ids[ids.index("arch"):]


def car(shot, cid):
    return next((c for c in shot.get("cars", []) if c["id"] == cid), None)


def person(shot, pid):
    return next((p for p in shot.get("people", []) if p["id"] == pid), None)

# Lot 47 on deep-dish rims (a widebody street build's; the turbines read as a toy's)
for shot in scene["shots"]:
    for c in shot.get("cars", []):
        if c.get("paint") == "lot47":
            c["tuning"] = "0.7.6.0"

# the Mirror's coupe in Vesper's pearl white, no underglow (it read as a police car, or as Kit's twin)
for shot in scene["shots"]:
    for c in shot.get("cars", []):
        if c.get("id") == "white":
            c["paint"] = "white"
            c["tuning"] = "0.0.0.0"
            c.pop("finish", None)

# --- the knock at first light ---------------------------------------------------------------------
# the sky a dawn's (a pale warm band low down, steel blue above, a broken overcast), the city's rooms
# mostly dark and its neon off; no lavender fills: the arch's lamp behind Dee is the key (warm, hard,
# shadowed: it rims her and Kit's hair through the open window), the sky through the glass the fill
DAWN_SKY = {"zenith": "#1a2238", "horizon": "#b4927e", "cloud_cover": 0.25, "cloud_lo": "#3a3a48", "cloud_hi": "#9a8c90"}
for sid in KNOCK:
    s = shots[sid]
    env = s.setdefault("env", {})
    env.update({"sky": DAWN_SKY, "city_lit": 0.08, "city_led": 0.0, "exposure": 1.35})
    if sid == "pins":
        continue
    out = []
    for l in s.get("lights", []):
        c = l.get("colour")
        if c == "#a9bce8":
            continue                                   # the lavender fill at the window: gone
        if c == "#9fb8ff" and l.get("car") == "kit":   # the cabin's fill: the sky through the windscreen
            l = {"car": "kit", "kind": "omni", "pos": [0.3, 1.2, 0.55], "colour": "#8fa3c2", "energy": 0.15,
                 "range": 1.3, "shadow": False}
        elif c == "#ffb36b":                           # the arch's lamp: a spot from behind and over Dee
            l = {"kind": "spot", "pos": [3.4, 3.2, -0.8], "look": [0.9, 1.25, 0.0], "colour": "#ffb36b",
                 "energy": 5.0, "angle": 45.0, "range": 9.0}
        elif c == "#9db4e6":                           # the sky over the street: a soft cool fill
            l = dict(l, colour="#8ea2c4", energy=1.4)
        out.append(l)
    s["lights"] = out

# --- the knock re-cut: no face held past about 3 s ----------------------------------------------------
def line(sid, text, lid, speaker, hold=None, **more):
    l = {"id": lid, "speaker": speaker, "text": text}
    if hold is not None:
        l["hold"] = hold
    l.update(more)
    return l


def cam_kit(fov, push=0.03):
    """Kit from the dash, three-quarter frontal, her face held wherever her head goes."""
    key = {"look": "kit_driver", "look_by": [0.0, 0.01, 0.0], "fov": fov, "eye_light": 0.2}
    return {"follow": "kit", "ease": "inout", "handheld": 0.08, "keys": [
        dict(key, u=0, pos=[0.30, 1.04, 0.66], dof=[1.2, 0.6, 0.1]), dict(key, u=1, pos=[0.31, 1.04, 0.66 - push])]}


def cam_dee(fov, x=-0.04):
    """Dee at the window over Kit's soft shoulder, her eyes high in the frame."""
    key = {"look": "dee", "look_by": [0.0, -0.06, 0.0], "fov": fov, "eye_light": 0.2}
    return {"follow": "kit", "ease": "inout", "handheld": 0.1, "keys": [
        dict(key, u=0, pos=[x, 1.15, 0.44], dof_near=[0.5, 0.3, 0.14]), dict(key, u=1, pos=[x + 0.02, 1.15, 0.41])]}


ORDER = ["arch", "knock", "kit_wake", "knock_two", "kit_two", "two_shot", "knock_dee2", "knock_kit2", "knock_dee3",
         "back_seat", "knock_kit3", "mirror_dawn", "knock_dee4", "pins", "knock_kit4", "knock_end"]
if "kit_wake" not in shots:
    for sid in ORDER:
        if sid not in shots:
            sh = copy.deepcopy(shots["knock_two"])
            sh["id"] = sid
            shots[sid] = sh
    scene["shots"] = [x for x in scene["shots"] if x["id"] not in ORDER] + [shots[x] for x in ORDER]
    ids = [x["id"] for x in scene["shots"]]
# the lines, each on its own shot
L = {sid: shots[sid] for sid in ORDER}
old = {l["id"]: l for sid in ORDER for l in shots[sid].get("lines", [])}
L["knock"]["lines"] = [line("knock", "Kit. Kit! Open up.", "c01_close_001", "Dee")]
L["kit_wake"]["lines"] = [line("kit_wake", "What... what time is it?", "c01_close_002", "Kit", 2.2)]
L["knock_two"]["lines"] = [line("knock_two", "Gone six. You slept in it.", "c01_close_003", "Dee", 2.2)]
L["kit_two"]["lines"] = [line("kit_two", "I wasn't sleeping. I was driving.", "c01_close_004", "Kit", 2.4)]
L["two_shot"]["lines"] = [line("two_shot", "There was a white car right behind me.", "c01_close_004b", "Kit", 2.6)]
L["knock_dee2"]["lines"] = [line("knock_dee2", "You were drooling on the wheel.", "c01_close_005", "Dee", 2.2)]
L["knock_kit2"]["lines"] = [line("knock_kit2", "There was someone in the back.", "c01_close_006", "Kit", 2.3)]
L["knock_dee3"]["lines"] = [line("knock_dee3", "There's a parcel shelf back there, and a wet patch.", "c01_close_007", "Dee", 3.0)]
L["back_seat"]["lines"] = [line("back_seat", "You need a new door seal, that's all.", "c01_close_007b", "Dee", 2.5, voice=True)]
L["knock_kit3"]["lines"] = [line("knock_kit3", "I saw her in the mirror.", "c01_close_008", "Kit", 2.0)]
L["mirror_dawn"]["lines"] = [line("mirror_dawn", "She was soaking.", "c01_close_008b", "Kit", 1.8, voice=True)]
L["knock_dee4"]["lines"] = [line("knock_dee4", "Old cars give you bad dreams. They've been places.", "c01_close_009", "Dee", 3.0)]
L["knock_kit4"]["lines"] = [line("knock_kit4", "Wipe it. Please.", "c01_close_011", "Kit", 1.8)]
for sid in ORDER[2:]:
    if sid not in ("pins", "knock_end"):
        L[sid]["lead"], L[sid]["tail"] = 0.2, 0.25
        L[sid].pop("dur", None)
        L[sid]["min"] = 1.8
# the knock: the raps, "open up", the glass down, her hands on the ledge, in that order, then the cut
kn = shots["knock"]
kn["lead"], kn["tail"] = 1.9, 0.3
kn.pop("dur", None)
kn["dur"] = 4.8
kn["cars"][0]["windows_down"] = {"driver": [2.6, 4.0]}
dee = person(kn, "dee")
for r in dee["reach"]:
    r["t"] = {5.2: 3.9, 5.8: 4.4}.get(r["t"], r["t"])
# Kit: her face to the dash camera, her eyes to Dee (a sideways look) or ahead (what she saw)
KIT_BEND = [{"t": 0.0, "Neck": [2, 6, 0], "Head": [4, 10, 0]}]
UNEASY = {"browInnerUp": 0.45, "jawOpen": 0.04, "browDownLeft": 0.05, "browDownRight": 0.05, "mouthFrownLeft": 0.15, "mouthFrownRight": 0.15}
AFRAID = {"browInnerUp": 0.85, "jawOpen": 0.09, "mouthFrownLeft": 0.25, "mouthFrownRight": 0.25}
for sid, fov, gaze, looks, face in [("kit_wake", 32, "dee", None, {"browInnerUp": 0.2, "eyeSquintLeft": 0.35, "eyeSquintRight": 0.35}),
                                    ("kit_two", 30, "dee", [[1.2, 2.4, "ahead"]], UNEASY),
                                    ("knock_kit2", 27, "ahead", [[1.9, 2.8, "dee"]], AFRAID),
                                    ("knock_kit3", 26, "ahead", None, AFRAID),
                                    ("knock_kit4", 24, "dee", None, dict(AFRAID, browInnerUp=0.75))]:
    sh = shots[sid]
    sh["camera"] = cam_kit(fov)
    k = person(sh, "kit_driver")
    k["gaze"], k["bend"], k["shapes"] = gaze, KIT_BEND, face
    if looks:
        k["looks"] = looks
    else:
        k.pop("looks", None)
for sid, fov, x in [("knock_two", 32, -0.04), ("knock_dee2", 30, -0.02), ("knock_dee3", 27, -0.05), ("knock_dee4", 26, -0.03)]:
    shots[sid]["camera"] = cam_dee(fov, x)
# "Old cars ... places.": her eyes go down to the dash at the end (the pins next)
d4 = person(shots["knock_dee4"], "dee")
lean = copy.deepcopy(person(shots["knock_two"], "dee")["bend"][0])
down = dict(copy.deepcopy(lean), t=3.4, Neck=[-8, 0, 0], Head=[-2, 0, 0])
d4["bend"] = [dict(lean, t=0.0), dict(copy.deepcopy(lean), t=2.8), down]
d4["looks"] = [[2.9, 4.0, "ahead"]]
# the two-shot: outside, over Dee's shoulder, Kit through the open window
shots["two_shot"]["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.1, "keys": [
    {"u": 0, "pos": [2.45, 1.5, 0.95], "look": [0.45, 1.05, -0.1], "fov": 30, "dof_near": [1.0, 0.5, 0.12]},
    {"u": 1, "pos": [2.35, 1.48, 0.85], "look": [0.45, 1.05, -0.1], "fov": 30}]}
# the back seat where she sat, empty, while Dee explains it away
shots["back_seat"]["camera"] = {"follow": "kit", "ease": "inout", "keys": [
    {"u": 0, "pos": [-0.15, 1.2, 0.05], "look": [0.0, 0.62, -0.85], "fov": 36, "dof": [1.4, 0.5, 0.1]},
    {"u": 1, "pos": [-0.14, 1.19, -0.05], "look": [0.0, 0.62, -0.85], "fov": 36}]}
# the mirror at dawn: the back seat in it, empty
md = shots["mirror_dawn"]
md["camera"] = {"follow": "kit", "ease": "inout", "keys": [
    {"u": 0, "pos": [0.3, 1.17, -0.25], "look": [0.0, 1.131, 0.512], "fov": 13},
    {"u": 1, "pos": [0.295, 1.168, -0.21], "look": [0.0, 1.131, 0.512], "fov": 13}]}
md["mirror"] = {"glass": True, "follow": "kit", "exposure": 2.0}
person(md, "kit_driver")["gaze"] = "mirror"
# the pins: from one pin out to all nine, the screen above the subtitles
pn = shots["pins"]
pn["camera"] = {"follow": "kit", "ease": "inout", "keys": [
    {"u": 0, "pos": [0.1, 0.96, 0.44], "look": [0.0, 0.84, 0.7], "fov": 12},
    {"u": 1, "pos": [0.16, 1.0, 0.34], "look": [0.0, 0.84, 0.7], "fov": 24}]}
# the wide at the end: from the passenger's side ahead (Dee stays screen right), craning up off the car
# to the ARCH 9 lettering on the viaduct's face in the first light
shots["knock_end"]["camera"] = {"path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": [-3.0, 1.3, 3.6], "look": [1.0, 1.1, 0.3], "fov": 40},
    {"u": 0.6, "pos": [-3.8, 2.6, 5.0], "look": [3.0, 3.5, 0.4], "fov": 40},
    {"u": 1.0, "pos": [-4.5, 4.2, 6.2], "look": [5.6, 6.0, 0.5], "fov": 40}]}
# the arch: craning down from the lettering to the car's tail as Dee crosses to it (the car the foreground)
shots["arch"]["camera"] = {"path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": [-9.0, 5.5, -7.5], "look": [4.5, 5.0, 0.5], "fov": 42},
    {"u": 0.6, "pos": [-6.0, 2.4, -5.8], "look": [3.6, 2.4, 0.5], "fov": 42},
    {"u": 1.0, "pos": [-4.0, 1.05, -4.6], "look": [2.2, 1.25, 0.3], "fov": 42}]}
# Dee's hair and coat damp from the rain
for sid in ORDER:
    d = person(shots[sid], "dee")
    if d:
        d["wet"] = 0.4

# --- the knock's body (the scene design): a standing knock, the bend into the window, a living lean -
import math

C_GLASS = [0.70, 1.075, -0.02]            # the knuckles' mark on the glass, at Kit's head height
GLASS_OUT = [0.907, 0.422, 0.0]           # the glass's outward normal (it leans in 25 degrees)
BRACE_L = {"at": [0.85, 0.874, 0.32], "palm": [-0.35, -0.94, 0], "fingers": [-0.94, 0.25, 0.25], "fist": 0.25,
           "elbow": [0.5, -0.6, 0.6]}
SILL_R = {"at": [0.86, 0.879, -0.12], "palm": [-0.35, -0.94, 0], "fingers": [-0.25, 0, 0.97], "fist": 0.3,
          "elbow": [0.6, -0.6, -0.5]}          # the forearm along the door's top
ROOF_L = {"at": [0.62, 1.252, 0.30], "palm": [-0.25, -0.97, 0], "fingers": [-0.69, 0.18, 0.70], "fist": 0.2,
          "elbow": [0.35, -0.55, 0.75]}        # a hand up on the roof's edge, peering in
TALK_HANDS = {"LeftHand": {"at": [0.82, 0.885, 0.30], "palm": [-0.35, -0.94, 0], "fingers": [-0.94, 0.2, 0.22], "fist": 0.35,
                           "elbow": [0.85, -0.35, 0.40]},
              "RightHand": {"at": [0.82, 0.892, -0.06], "palm": [-0.35, -0.94, 0], "fingers": [-0.94, 0.2, -0.30], "fist": 0.45,
                            "elbow": [0.85, -0.35, -0.40]}}
KNOCK_A = {"Hips": [26, 0, 0], "LeftUpperLeg": [-36, 0, 0], "RightUpperLeg": [-36, 0, 0], "LeftLowerLeg": [20, 0, 0],
           "RightLowerLeg": [20, 0, 0], "LeftFoot": [-10, 0, 0], "RightFoot": [-10, 0, 0], "Spine": [6, 0, 0], "Chest": [4, 0, 0],
           "UpperChest": [2, 0, 0], "Neck": [-6, 0, 0], "Head": [-4, 4, 0]}
KNOCK_B = dict(KNOCK_A, Hips=[28, 0, 0], LeftUpperLeg=[-38, 0, 0], RightUpperLeg=[-38, 0, 0], Head=[-4, 4, 6])
PEER = {"Hips": [38, 0, 0], "LeftUpperLeg": [-46, 0, 0], "RightUpperLeg": [-32, 0, 0], "LeftLowerLeg": [16, 0, 0],
        "RightLowerLeg": [4, 0, 0], "LeftFoot": [-8, 0, 0], "RightFoot": [-10, 0, 0], "Spine": [8, 0, 0], "Chest": [9, 0, 0],
        "UpperChest": [8, 0, -2], "Neck": [-8, 3, 0], "Head": [-24, 5, 7], "LeftShoulder": [0, -6, 8], "RightShoulder": [0, 4, -3]}
TALK = dict(PEER, UpperChest=[8, 0, 0], Neck=[-8, 0, 0], Head=[-24, 0, 0], LeftShoulder=[0, -5, 4], RightShoulder=[0, 5, -4])
TALK_A = dict(TALK, UpperChest=[8, 0, -1.5], Neck=[-8, 3, 0], Head=[-24, 5, 6], RightShoulder=[0, 5, -7], LeftShoulder=[0, -5, 2])
TALK_B = dict(TALK, UpperChest=[8, 0, 1.5], Neck=[-7, -2, 0], Head=[-23, -3, 2], LeftShoulder=[0, -5, 7], RightShoulder=[0, 5, -2])


def key(t, pose, **over):
    return dict(copy.deepcopy(pose), t=t, **copy.deepcopy(over))


def rap(t, off, up, ease=None):
    """The right fist at the glass (off: m out from it; up: degrees the fingers point above its normal)."""
    a = math.radians(205 - up)
    f = [math.cos(a), math.sin(a), 0.0]
    n = [-math.sin(a), math.cos(a), 0.0]
    at = [round(C_GLASS[i] + GLASS_OUT[i] * off - 0.053 * f[i] - 0.024 * n[i], 4) for i in range(3)]
    k = {"t": t, "RightHand": {"at": at, "palm": [round(x, 4) for x in n], "fingers": [round(x, 4) for x in f], "fist": 0.85,
                              "elbow": [0.35, -0.75, -0.55]}, "LeftHand": copy.deepcopy(BRACE_L)}
    if ease:
        k["ease"] = ease
    return k


def raps(spec):
    """[(t, off, up), ...]: a contact (off 0) arrives at speed, the key after it leaves fast."""
    out, after = [], False
    for t, off, up in spec:
        out.append(rap(t, off, up, "in" if off == 0 else ("out" if after else None)))
        after = off == 0
    return out


KIT_ASLEEP = [{"t": 0, "Neck": [6, 0, -4], "Head": [10, 0, -12]}]
DEE_BASE = {"id": "dee", "who": "dee", "clip": "Stand", "face": -90, "gaze": "kit_driver", "reach_car": "kit", "wet": 0.4,
            "breathe": [1.2, 3.6]}


def dee_spec(**kw):
    d = copy.deepcopy(DEE_BASE)
    d.update(copy.deepcopy(kw))
    return d


def set_dee(sh, spec):
    sh["people"] = [p for p in sh["people"] if p["id"] != "dee"] + [spec]


# the insert (new): three quick raps on the sound, the knuckles sharp at the glass, Kit asleep soft
# beside them, Dee's face cut off by the roof
if "knock_ins" not in shots:
    ins = copy.deepcopy(shots["knock"])
    ins["id"] = "knock_ins"
    scene["shots"].insert([x["id"] for x in scene["shots"]].index("knock"), ins)
    shots["knock_ins"] = ins
ins = shots["knock_ins"]
for k_ in ("lines", "fade_in", "lead", "tail"):
    ins.pop(k_, None)
ins["dur"] = 1.5
ins["sounds"] = [{"at": 0.32, "cue": "thump", "pitch": 1.5, "db": -3}, {"at": 0.49, "cue": "thump", "pitch": 1.5, "db": -3},
                 {"at": 0.66, "cue": "thump", "pitch": 1.5, "db": -3}]
ins["camera"] = {"follow": "kit", "handheld": 0.06, "keys": [
    {"u": 0, "pos": [0.22, 1.07, 0.62], "look": [0.75, 1.10, 0.02], "fov": 34, "dof_near": [0.62, 0.12, 0.14], "dof": [1.05, 0.3, 0.08],
     "eye_light": 0.25},
    {"u": 1, "pos": [0.22, 1.07, 0.59], "look": [0.75, 1.10, 0.02], "fov": 34, "eye_light": 0.25}]}
ins["cars"][0]["windows_down"] = {"driver": [9.0, 10.0]}       # the glass its own wound piece, still up
ki = person(ins, "kit_driver")
ki.update({"rate": 0.0, "bend": KIT_ASLEEP, "gaze": "ahead", "breathe": [1.4, 4.6],
           "shapes": [{"t": 0, "eyeBlinkLeft": 1, "eyeBlinkRight": 1, "jawOpen": 0.06}]})
ki.pop("looks", None)
set_dee(ins, dee_spec(pos=[1.42, 0, 0.10], lift=-0.012, bend=[key(0, KNOCK_A), key(1.2, KNOCK_B)],
                      reach=raps([(0.0, 0.08, 22), (0.24, 0.045, 24), (0.32, 0, 12), (0.405, 0.04, 22), (0.49, 0, 12),
                                  (0.575, 0.04, 22), (0.66, 0, 12), (0.78, 0.035, 18), (1.5, 0.045, 20)])))
for l in ins["lights"]:
    if l.get("colour") == "#ffb36b":
        l["look"] = [1.0, 1.15, -0.02]                         # the arch's lamp rims the fist and forearm
# the knock: harder raps, Kit startles, the fist drops, Dee bends down into the window with a hand up
# on the roof, says her line, and the glass starts down
kn = shots["knock"]
kn.pop("fade_in", None)
kn["dur"], kn["lead"], kn["tail"] = 2.9, 0.9, 0.3
kn["lines"] = [line("knock", "Kit. Kit! Open up.", "c01_close_001", "Dee", 1.6)]
kn["sounds"] = [{"at": 0.18, "cue": "thump", "pitch": 1.35, "db": 0}, {"at": 0.36, "cue": "thump", "pitch": 1.35, "db": 0},
                {"at": 0.42, "cue": "breath", "db": -10}]
kn["cars"][0]["windows_down"] = {"driver": [2.1, 3.4]}
kn["camera"] = {"follow": "kit", "handheld": 0.1, "keys": [
    {"u": 0, "pos": [-0.20, 1.08, 0.57], "look": [0.80, 1.16, 0.02], "fov": 36, "dof_near": [0.85, 0.2, 0.1], "eye_light": 0.2},
    {"u": 1, "pos": [-0.19, 1.08, 0.54], "look": [0.80, 1.16, 0.02], "fov": 36, "eye_light": 0.2}]}
kk = person(kn, "kit_driver")
kk.update({"rate": 0.0, "gaze": "dee", "looks": [[0, 0.5, "ahead"]],
           "bend": [{"t": 0, "Neck": [6, 0, -4], "Head": [10, 0, -12]}, {"t": 0.40, "Neck": [6, 0, -4], "Head": [10, 0, -12]},
                    {"t": 0.72, "Neck": [0, 8, 0], "Head": [-2, 14, 0]}],
           "shapes": [{"t": 0, "eyeBlinkLeft": 1, "eyeBlinkRight": 1}, {"t": 0.40, "eyeBlinkLeft": 1, "eyeBlinkRight": 1},
                      {"t": 0.50, "browInnerUp": 0.45, "eyeSquintLeft": 0.3, "eyeSquintRight": 0.3}]})
set_dee(kn, dee_spec(pos=[1.42, 0, 0.10], lift=[[0, -0.012], [0.55, -0.012], [1.25, -0.008]],
                     bend=[key(0, KNOCK_B), key(0.55, KNOCK_B), key(1.25, PEER), key(2.2, PEER, Head=[-22, 7, 9])],
                     reach=raps([(0, 0.045, 20), (0.09, 0.07, 28), (0.18, 0, 12), (0.27, 0.065, 27), (0.36, 0, 12), (0.47, 0.04, 20)])
                     + [{"t": 0.62, "RightHand": SILL_R, "LeftHand": BRACE_L}, {"t": 1.15, "RightHand": SILL_R, "LeftHand": ROOF_L},
                        {"t": 2.9, "RightHand": SILL_R, "LeftHand": ROOF_L}]))
# the glass goes on down through Kit's line (the knock's span, carried over the cut)
shots["kit_wake"]["cars"][0]["windows_down"] = {"driver": [-0.8, 0.5]}
# Dee in every dialogue shot: one place, a rounded back over her hands, the head forward, breathing,
# her weight shifting every 1.5 s; one re-grip in a longer shot
LINE_BEATS = {
    "knock_two": {"bend": [key(0, TALK_A), key(1.0, TALK_A), key(1.15, TALK_A, Head=[-24, 10, 6]), key(1.3, TALK_A, Head=[-24, 1, 6]),
                           key(1.45, TALK_A, Head=[-24, 8, 6]), key(1.6, TALK_A), key(3.0, TALK_B)],
                  "shapes": [{"t": 0.9, "mouthSmileLeft": 0}, {"t": 1.2, "mouthSmileLeft": 0.3, "mouthSmileRight": 0.1}]},
    "knock_dee2": {"bend": [key(0, TALK_B, Head=[-16, 0, 0]), key(0.4, TALK_B, Head=[-16, 0, 0]), key(0.8, TALK_B, Head=[-24, 0, 8]),
                            key(2.4, TALK_A)],
                   "looks": [[0, 0.5, "ahead"]], "shapes": [{"t": 0.7, "mouthSmileLeft": 0}, {"t": 0.8, "mouthSmileLeft": 0.25, "mouthSmileRight": 0.25}]},
    "knock_dee3": {"bend": [key(0, TALK_A), key(0.55, TALK_A, Neck=[-8, -8, 0], Head=[-24, -18, 0]),
                            key(1.2, TALK_A, Neck=[-8, -8, 0], Head=[-24, -18, 0]), key(1.55, TALK_A), key(3.0, TALK_B)],
                   "looks": [[0.45, 1.3, "ahead"]]},
}
for i, sid in enumerate(["kit_wake", "knock_two", "kit_two", "two_shot", "knock_dee2", "knock_kit2", "knock_dee3", "back_seat",
                         "knock_kit3", "mirror_dawn", "knock_dee4", "pins", "knock_kit4"]):
    sh = shots[sid]
    if sid == "pins":
        continue
    first, second = (TALK_A, TALK_B) if i % 2 == 0 else (TALK_B, TALK_A)
    d = dee_spec(pos=[1.58, 0, 0.10], lift=-0.008, bend=[key(0, first), key(1.5, second), key(3.0, first)],
                 reach=[dict(copy.deepcopy(TALK_HANDS), t=0)])
    regrip = copy.deepcopy(TALK_HANDS)
    regrip["RightHand"]["at"][2], regrip["RightHand"]["fist"] = -0.03, 0.55
    d["reach"] += [dict(copy.deepcopy(TALK_HANDS), t=1.1), dict(regrip, t=1.4), dict(copy.deepcopy(regrip), t=9.0)]
    d.update(copy.deepcopy(LINE_BEATS.get(sid, {})))
    if sid == "knock_dee4":                    # her eyes down to the dash at the end (the pins next)
        d["bend"] = [key(0, first), key(1.5, second), key(2.8, second), key(3.4, second, Neck=[-2, 0, 0], Head=[-6, 0, 0])]
        d["looks"] = [[2.9, 4.0, "ahead"]]
    set_dee(sh, d)
# the end: she pushes off the door (the hips lead, the back follows), stands looking down at Kit, then
# up the street on "let's see where they go first"
ke = shots["knock_end"]
set_dee(ke, dee_spec(pos=[1.58, 0, 0.10], lift=[[0.9, -0.008], [1.45, 0.0]],
                     reach=[dict(copy.deepcopy(TALK_HANDS), t=0.9),
                            {"t": 1.12, "LeftHand": dict(TALK_HANDS["LeftHand"], at=[0.82, 0.873, 0.30]),
                             "RightHand": dict(TALK_HANDS["RightHand"], at=[0.82, 0.880, -0.06])}, {"t": 1.35}],
                     bend=[key(0.9, TALK), {"t": 1.45, "Hips": [18, 0, 0], "Spine": [8, 0, 0], "Chest": [9, 0, 0], "UpperChest": [8, 0, 0],
                                            "Neck": [2, 0, 0], "Head": [6, 0, 0]},
                           {"t": 1.8, "Hips": [4, 0, 0], "Neck": [10, 0, 0], "Head": [12, 0, 0]},
                           {"t": 2.7, "Hips": [4, 0, 0], "Neck": [10, 0, 0], "Head": [12, 0, 0]},
                           {"t": 3.2, "Neck": [4, 14, 0], "Head": [2, 18, 0]}]))
# the back seat and the mirror at dawn: the first light through the rear window on the bench (it was
# black), the mirror a stop brighter
DAWN_REAR = {"id": "dawn_rear", "car": "kit", "kind": "omni", "pos": [0.0, 1.18, -1.15], "colour": "#9aaccc", "energy": 0.6,
             "range": 1.6, "shadow": False}
for sid in ["back_seat", "mirror_dawn"]:
    sh = shots[sid]
    sh["lights"] = [l for l in sh["lights"] if l.get("id") != "dawn_rear"] + [dict(DAWN_REAR)]
shots["mirror_dawn"]["mirror"]["exposure"] = 3.2
# the arch: she crosses from her arch and is just short of the car as the cut lands on the first rap
for p_ in shots["arch"]["people"]:
    if p_["id"] == "dee":
        p_["path"], p_["walk_at"], p_["gaze"] = [[5.9, 0.9], [1.6, 0.15]], 0.0, ""

# --- the Mirror -----------------------------------------------------------------------------------
MIRROR = ids[:ids.index("black") + 1]
# the coupe closes in on high beams: the chase's key from the low reverse to the whiteout (a hard
# white light through the rear window, round Kit's hair, flaring the glass); the faked glare spots go
for sid in ["coupe_low", "closer", "rear_window", "glare", "whiteout"]:
    sh = shots[sid]
    if car(sh, "white"):
        car(sh, "white")["lights"] = "high"
    sh["lights"] = [l for l in sh["lights"] if not (l.get("car") == "kit" and l.get("colour") == "#eef2ff")]
# Kit's own tail lights a glow on the coupe's nose, not a red wash over the frame
for sid, e in [("rear_window", 0.9), ("empty_road", 0.6)]:
    for l in shots[sid]["lights"]:
        if l.get("colour") == "#ff2a2a":
            l["energy"] = e
# faces: no lavender fill from the dash's middle; the dash's own glow the key (cool, from low ahead)
for sid in MIRROR:
    sh = shots[sid]
    if not person(sh, "kit_driver"):
        continue
    out = []
    for l in sh.get("lights", []):
        if l.get("car") == "kit" and l.get("colour") == "#9fb8ff" and l.get("pos") == [0.05, 1.0, 0.75]:
            continue
        if l.get("car") == "kit" and l.get("colour") == "#7fa0ff":
            l = dict(l, colour="#6fa8ff", energy=0.35)
        out.append(l)
    sh["lights"] = out
# the mirror's inserts: the glass fills the frame, its picture a stop over the street ahead
for sid in ["mirror_far", "whiteout", "she_is_there"]:
    sh = shots[sid]
    for k in sh["camera"]["keys"]:
        k["fov"] = 13
    sh["mirror"]["exposure"] = 3.2
car(shots["mirror_far"], "white")["ahead"] = -25.0
# the road empty: the rear window's own camera again, the coupe gone (a match cut: read in half a second)
er = shots["empty_road"]
er["camera"] = copy.deepcopy(shots["rear_window"]["camera"])
er.pop("mirror", None)
er["glass"] = 0.6
# she is there: the dome stutters for a few frames and she is in the back, under its cold light
sh = shots["she_is_there"]
sh["flicker"] = {"rate": 14.0, "depth": 0.9, "from": 0.8, "to": 0.93}
person(sh, "passenger")["from"] = 0.86
if not any(l.get("id") == "back_top" for l in sh["lights"]):
    sh["lights"].append({"id": "back_top", "car": "kit", "kind": "omni", "pos": [0.0, 1.22, -0.75], "colour": "#b8ccff",
                         "energy": 0.45, "range": 1.1, "shadow": False})
# her eyes: the close-up on her face, both eyes high in the frame
for k in shots["eyes"]["camera"]["keys"]:
    k["look"] = "kit_driver"
    k["look_by"] = [0.0, -0.03, 0.0]
    k["fov"] = 16
# the empty seat's dead air cut; the look back held into the hit
if "dead_air" in shots:
    scene["shots"].remove(shots.pop("dead_air"))
shots["look_back"]["dur"] = 1.6
# quicker: the closing-in, the profile, the black after the sting
shots["closer"]["dur"] = 1.5
person(shots["closer"], "kit_driver")["looks"] = [[0.15, 0.6, "mirror"], [0.8, 1.5, "rear"]]
pr = shots["profile"]
pr["dur"] = 1.4
kd = person(pr, "kit_driver")
kd["looks"] = [[0.3, 1.1, "mirror"]]
kd["bend"] = [{"t": 0.2, "Neck": [0, 0, 0], "Head": [0, 0, 0]}, {"t": 0.4, "Neck": [0, -6, 0], "Head": [0, -12, 0]},
              {"t": 1.0, "Neck": [0, -6, 0], "Head": [0, -12, 0]}, {"t": 1.3, "Neck": [0, 0, 0], "Head": [0, 0, 0]}]
shots["black"]["dur"] = 1.2
# an eye light on Kit's faces (a catchlight, a touch of neutral on the skin)
for sid, e in [("asleep", 0.12), ("profile", 0.12), ("closer", 0.15), ("glare", 0.1), ("breath_out", 0.12),
               ("eyes", 0.2), ("look_back", 0.15)]:
    for k in shots[sid]["camera"]["keys"]:
        k["eye_light"] = e

# --- the Mirror's scare (the scene design: suspense before the surprise, each sighting closer) -------
# a glimpse of her in the back seat as the high beams flare the rear window; the road and the seat
# empty; a dark road where every rhythm stops; the false calm, in which she rises behind Kit and lays
# a hand on her headrest; in the mirror, closer, revealed by the dome's light; Kit turns round to
# nobody and back to the road, and she is at Kit's ear. Real silence before the sting.
GHOST = {"id": "passenger", "car": "kit", "clip": "Sitting_Idle", "rate": 0.0, "look": "drowned", "who": "passenger",
         "blink": False}
HAND = {"at": [0.24, 1.03, -0.27], "palm": [0, -1, 0.2], "fingers": [0.15, -0.4, 1.0], "fist": 0.35}
DREAD_ENV = {"city_lit": 0.05, "city_led": 0.0}


def ghost(sh, **kw):
    """The passenger in a shot, spelled out whole (the same file however often this runs)."""
    g = person(sh, "passenger")
    if g is None:
        g = {}
        sh.setdefault("people", []).append(g)
    g.clear()
    g.update(copy.deepcopy(GHOST))
    g.update(copy.deepcopy(kw))
    return g


def lights_without(sh, *colours):
    sh["lights"] = [l for l in sh.get("lights", []) if l.get("colour") not in colours]


def hold(sh, handheld=0.0):
    sh["camera"]["handheld"] = handheld


# asleep: the plant (water dripping somewhere in the parked car), a cool key from the window
sh = shots["asleep"]
sh["fade_in"], sh["glass"] = 0.6, 0.3
sh["ambience"] = [{"cue": "rain", "db": -10}]
sh["sounds"] = [{"at": 1.6, "cue": "drip", "db": -22}]
lights_without(sh, "#ff7ab8")
if not any(l.get("id") == "window_key" for l in sh["lights"]):
    sh["lights"].append({"id": "window_key", "car": "kit", "kind": "spot", "pos": [1.1, 1.3, 0.3], "look": [0.37, 1.09, 0.17],
                         "colour": "#8fb0d8", "energy": 1.2, "angle": 35, "range": 2.0})
# the dream's road: the coupe two blazing points far back; an engine under the rain
sh = shots["dream_road"]
car(sh, "white")["ahead"], car(sh, "white")["lights"] = -45.0, "high"
hold(sh, 0.08)
sh["ambience"] = [{"cue": "engine", "db": -10}, {"cue": "rain", "db": -12}]
# sodium lamps going by over her face (the car's speed), the wipers
LAMPS = {"car": "kit", "colour": "#ff9d3c", "energy": 2.5, "range": 4.0, "every": 1.3, "phase": 0.4,
         "from": [1.9, 2.6, 6.0], "to": [1.9, 2.6, -6.0], "shadow": True}
for sid in ["profile", "closer"]:
    shots[sid]["passing"] = dict(LAMPS)
    shots[sid]["ambience"] = [{"cue": "engine", "db": -10}, {"cue": "rain", "db": -12}, {"cue": "wipers", "db": -16}]
shots["closer"]["ambience"].append({"cue": "heartbeat", "db": -16})
car(shots["profile"], "white")["lights"] = "high"
# the mirror far: the empty back seat under a passing light, the coupe's lights in the glass
sh = shots["mirror_far"]
sh["dur"] = 1.4
sh["passing"] = dict(LAMPS, phase=-0.05)
hold(sh, 0.0)
# the low reverse: Kit's rear quarter soft in the foreground, the coupe's beams on a long lens
sh = shots["coupe_low"]
sh["dur"] = 2.0
sh["camera"]["keys"] = [{"u": 0, "pos": [-1.05, 0.45, -2.3], "look": [-0.4, 1.6, -60.0], "fov": 18, "dof_near": [1.0, 0.5, 0.15]},
                        {"u": 1, "pos": [-1.02, 0.46, -2.2], "look": [-0.4, 1.6, -60.0], "fov": 18, "dof_near": [1.0, 0.5, 0.15]}]
hold(sh, 0.1)
# THE GLIMPSE: for six frames, as the beams flare the rear window, a head and shoulders in the back
sh = shots["rear_window"]
sh["dur"] = 1.4
sh["camera"]["keys"] = [
    {"u": 0, "pos": [0.02, 1.16, 0.42], "look": [-0.03, 1.02, -16.0], "fov": 20, "dof_near": [1.1, 0.5, 0.12], "exposure": 1.0},
    {"t": 1.1, "pos": [0.02, 1.16, 0.39], "look": [-0.03, 1.02, -16.0], "fov": 20, "exposure": 1.0},
    {"t": 1.18, "pos": [0.02, 1.16, 0.385], "look": [-0.03, 1.02, -16.0], "fov": 20, "exposure": 1.5},
    {"u": 1, "pos": [0.02, 1.16, 0.38], "look": [-0.03, 1.02, -16.0], "fov": 20, "exposure": 1.1}]
hold(sh, 0.15)
ghost(sh, pos=[-0.16, -0.06, -0.349], gaze="camera", bend=[{"t": 0, "Neck": [8, 0, 0], "Head": [14, 0, 10]}], **{"from": 1.12, "to": 1.22})
sh["ambience"] = [{"cue": "engine", "db": -10}, {"cue": "heartbeat", "db": -12}]
# the glare: a slash of the beams across her eyes from the mirror, growing; a wince, not a cry
sh = shots["glare"]
sh["dur"] = 1.2
k = person(sh, "kit_driver")
k["looks"] = [[0.0, 0.8, "ahead"], [0.8, 1.2, "mirror"]]
k["shapes"] = {"eyeSquintLeft": 0.6, "eyeSquintRight": 0.6, "browDownLeft": 0.6, "browDownRight": 0.6, "jawOpen": 0.0,
               "mouthFrownLeft": 0.3, "mouthFrownRight": 0.3}
if not any(l.get("id") == "slash" for l in sh["lights"]):
    sh["lights"].append({"id": "slash", "car": "kit", "kind": "spot", "pos": [0.0, 1.13, 0.5], "look": [0.37, 1.09, 0.17],
                         "colour": "#eef2ff", "angle": 4.0, "range": 1.2, "energy": [[0, 1.0], [1.2, 8.0]], "shadow": False})
k0 = dict(sh["camera"]["keys"][0], u=0, exposure=1.0)
k0.pop("t", None)
sh["camera"]["keys"] = [k0, dict(k0, u=1, exposure=1.4)]
sh["ambience"] = [{"cue": "engine", "db": -9}, {"cue": "heartbeat", "db": -9, "pitch": 1.3}, {"cue": "wipers", "db": -16}]
# the whiteout: the bumper's hit, the false scare; every loop dies at the flash
sh = shots["whiteout"]
sh["sounds"] = [{"at": 0.7, "cue": "thump", "db": -3}, {"at": 0.7, "cue": "sub", "db": -2}]
sh["ambience"] = []
# the empty road and seat (the same camera as the glimpse), the ears ringing, the world muffled
sh = shots["empty_road"]
sh["dur"] = 1.2
sh["camera"] = copy.deepcopy(shots["rear_window"]["camera"])
for kk in sh["camera"]["keys"]:
    kk["exposure"] = 1.0
sh["sounds"] = [{"at": 0.0, "cue": "ring", "db": -12}]
sh["ambience"] = [{"cue": "engine", "db": -22}, {"cue": "rain", "db": -20}]
# a dark road (new): from the back seat, Kit's shoulder soft; the lamps end, the rain stops in the
# headlights, the wipers stop: every rhythm drops out; the drone begins under it
if "dark_road" not in shots:
    dr = copy.deepcopy(shots["empty_road"])
    dr["id"] = "dark_road"
    scene["shots"].insert([x["id"] for x in scene["shots"]].index("empty_road") + 1, dr)
    shots["dark_road"] = dr
sh = shots["dark_road"]
sh["dur"] = 1.8
sh.pop("flash", None)
sh["sounds"] = []
sh["camera"] = {"follow": "kit", "handheld": 0.15, "keys": [
    {"u": 0, "pos": [-0.14, 1.07, -0.5], "look": [0.3, 1.0, 4.0], "fov": 30, "dof_near": [0.55, 0.3, 0.12]},
    {"u": 1, "pos": [-0.13, 1.07, -0.46], "look": [0.3, 1.0, 4.0], "fov": 30, "dof_near": [0.55, 0.3, 0.12]}]}
sh["rain"], sh["glass"] = [[0, 0.6], [0.6, 0.0]], 0.3
sh["passing"] = dict(LAMPS, until=0.9)
sh["ambience"] = [{"cue": "engine", "db": -20}, {"cue": "rain", "db": -18, "to": 0.6}, {"cue": "wipers", "db": -18, "to": 0.9},
                  {"cue": "drone", "db": -15}]
sh["people"] = [p for p in sh["people"] if p["id"] != "passenger"]
# the false calm: Kit lets go, eyes closed, head back; behind her, soft and dark, a wet head rises
# into the gap and a pale hand settles on the corner of her headrest; leather creaks; her eyes open
sh = shots["breath_out"]
sh["dur"] = 3.2
sh["camera"] = {"follow": "kit", "keys": [
    {"u": 0, "pos": [0.04, 0.99, 0.82], "look": [0.2, 1.06, -0.12], "fov": 32, "dof": [1.0, 0.4, 0.1], "eye_light": 0.15},
    {"u": 1, "pos": [0.045, 0.99, 0.80], "look": [0.2, 1.06, -0.12], "fov": 32, "dof": [1.0, 0.4, 0.1], "eye_light": 0.15}]}
k = person(sh, "kit_driver")
k["blink"] = False
k["breathe"] = [2.0, 3.0]
k["bend"] = [{"t": 0}, {"t": 0.25, "Spine": [10, 0, 0], "Chest": [12, 0, 0]},
             {"t": 1.0, "Spine": [8, 0, 0], "Chest": [10, 0, 0], "Head": [-6, 0, 0]},
             {"t": 3.0, "Spine": [8, 0, 0], "Chest": [10, 0, 0], "Head": [-6, 0, 0]},
             {"t": 3.15, "Spine": [2, 0, 0], "Neck": [0, -6, 0], "Head": [-5, -12, 0]}]
k["shapes"] = [{"t": 0, "browInnerUp": 0.35}, {"t": 0.9, "eyeBlinkLeft": 1, "eyeBlinkRight": 1, "browInnerUp": 0.1},
               {"t": 2.95, "eyeBlinkLeft": 1, "eyeBlinkRight": 1}, {"t": 3.02, "eyeBlinkLeft": 0, "eyeBlinkRight": 0, "browInnerUp": 0.6}]
k["looks"] = [[3.08, 3.2, "mirror"]]
ghost(sh, pos=[0.0, -0.06, -0.38], lift=[[2.7, -0.45], [3.15, 0.0]], reach_car="kit",
      bend=[{"t": 2.7, "Neck": [15, 0, 0], "Head": [25, 0, 0]}, {"t": 3.2, "Neck": [-2, 0, 0], "Head": [12, 0, 10]}],
      reach=[{"t": 2.9}, {"t": 3.15, "LeftHand": HAND}], **{"from": 2.75})
lights_without(sh, "#2a3560", "#ffd9a8")
for l in sh["lights"]:
    if l.get("colour") == "#6fa8ff":
        l["energy"] = 0.45
if not any(l.get("id") == "rear_rim" for l in sh["lights"]):
    sh["lights"].append({"id": "rear_rim", "car": "kit", "kind": "omni", "pos": [0.0, 1.2, -0.95], "colour": "#8fa6c8",
                         "energy": 0.35, "range": 0.8, "shadow": False})
sh["env"] = dict(DREAD_ENV)
sh["ambience"] = [{"cue": "drone", "db": -14}, {"cue": "engine", "db": -24}]
sh["sounds"] = [{"at": 0.2, "cue": "breath", "db": -6}, {"at": 1.4, "cue": "drip", "db": -14}, {"at": 2.8, "cue": "creak", "db": -10}]
# she is there: the glass black and empty for a second; the dome stutters on and she is behind the
# headrest, leaning in, one eye through her hair on Kit's in the mirror; no sting yet
sh = shots["she_is_there"]
sh["dur"] = 1.5
car(sh, "kit")["dome"] = [[0, 0.0], [0.97, 0.0], [1.0, 0.3]]
sh["flicker"] = {"rate": 16.0, "depth": 1.0, "from": 0.97, "to": 1.12}
sh["lights"] = [l for l in sh["lights"] if l.get("id") != "back_top"]
for l in sh["lights"]:
    if l.get("colour") == "#9fd8c8":
        l["energy"], l["pos"] = 0.35, [0.06, 0.85, -0.12]
ghost(sh, pos=[0.19, -0.02, -0.30], gaze="mirror", reach_car="kit", shapes={"jawOpen": 0.12},
      bend=[{"t": 0, "Spine": [22, -12, 0], "Chest": [8, 0, 0], "Neck": [-4, -6, 0], "Head": [14, -8, 12]}],
      reach=[{"t": 0.0, "LeftHand": HAND}], **{"from": 1.02})
sh["env"] = dict(DREAD_ENV)
sh["ambience"] = [{"cue": "drone", "db": -12}, {"cue": "drip", "db": -14}]
sh["sounds"] = []
# her eyes: going wide (no squint), a slash of light from the glass across them
sh = shots["eyes"]
sh["dur"] = 0.6
person(sh, "kit_driver")["shapes"] = [{"t": 0, "browInnerUp": 0.6}, {"t": 0.12, "browInnerUp": 0.95, "jawOpen": 0.08}]
lights_without(sh, "#2a3560", "#d8e4ff")
if not any(l.get("id") == "slash" for l in sh["lights"]):
    sh["lights"].append({"id": "slash", "car": "kit", "kind": "spot", "pos": [0.02, 1.13, 0.5], "look": [0.37, 1.09, 0.17],
                         "colour": "#cfe0ff", "angle": 4.0, "range": 1.0, "energy": 2.5, "shadow": False})
sh["env"] = dict(DREAD_ENV)
# the look back: her whole body round to nobody, then back to the road; dead silence; a breath, then
# a second, thinner one that isn't hers
sh = shots["look_back"]
sh["dur"] = 1.5
hold(sh, 0.2)
k = person(sh, "kit_driver")
TURN = {"Spine": [0, -15, 0], "Chest": [0, -18, 0], "UpperChest": [0, -18, 0], "Neck": [2, -25, 0], "Head": [4, -32, 5]}
k["bend"] = [{"t": 0, "Neck": [0, -6, 0], "Head": [-5, -12, 0]}, dict(TURN, t=0.45), dict(TURN, t=1.0), {"t": 1.35}]
k["looks"] = [[0.2, 0.6, "rear"], [0.6, 1.0, "camera"], [1.0, 1.5, "ahead"]]
lights_without(sh, "#2a3560", "#cfe0ff", "#ff4fa0")
car(sh, "kit")["dome"] = 0.2
sh["env"] = dict(DREAD_ENV)
sh["ambience"] = ""
sh["sounds"] = [{"at": 1.05, "cue": "breath", "db": -10}, {"at": 1.3, "cue": "breath", "db": -13, "pitch": 1.35}]
# the hit: Kit faces front, relieved, and the wet face is already at her ear; a one-frame snap of the
# head to the lens, Kit recoiling, the camera lunging; both lit from below by the dash; no flash
sh = shots["hit"]
sh["dur"] = 0.4
sh.pop("flash", None)
sh["camera"] = {"follow": "kit", "ease": "out", "handheld": 1.0, "shake": 0.015, "keys": [
    {"u": 0, "pos": [0.28, 1.05, 0.72], "look": [0.25, 1.07, 0.05], "fov": 30, "dof": [0.95, 0.3, 0.1], "exposure": 1.0},
    {"t": 0.03, "pos": [0.28, 1.05, 0.70], "look": [0.25, 1.07, 0.05], "fov": 30, "exposure": 1.45},
    {"t": 0.12, "pos": [0.27, 1.05, 0.60], "look": [0.24, 1.07, 0.05], "fov": 30, "exposure": 1.05}]}
k = person(sh, "kit_driver")
k["looks"] = [[0, 0.1, "ahead"], [0.1, 0.4, "passenger"]]
k["shapes"] = [{"t": 0, "browInnerUp": 0.4, "jawOpen": 0.05}, {"t": 0.12, "browInnerUp": 0.95, "jawOpen": 0.35}]
k["bend"] = [{"t": 0}, {"t": 0.08, "Chest": [-4, 0, 0], "Neck": [0, 8, 0], "Head": [-3, 10, 0]}]
SNAP0 = {"Spine": [28, -12, 0], "Chest": [12, 0, 0], "UpperChest": [8, 0, 0], "Neck": [-8, -12, 0], "Head": [-14, -10, 16]}
ghost(sh, pos=[0.37, 0.0, -0.45], lift=0.27, gaze="camera",      # (her face at Kit's ear: x 0.24, eye height, 15 cm behind)
      bend=[dict(SNAP0, t=0), dict(SNAP0, t=0.07),
            {"t": 0.085, "Spine": [32, -12, 0], "Chest": [14, 0, 0], "UpperChest": [8, 0, 0], "Neck": [-12, -16, 0], "Head": [-20, -18, 4]}],
      shapes=[{"t": 0, "jawOpen": 0.12}, {"t": 0.15, "jawOpen": 0.5}])
lights_without(sh, "#c4d4ff")
for l in sh["lights"]:
    if l.get("colour") == "#6fa8ff":
        l["energy"] = 0.8
    if l.get("colour") == "#9fd8c8":
        l.update({"pos": [0.12, 0.84, 0.08], "energy": 1.0, "range": 0.45})
car(sh, "kit")["dome"] = 0.0
sh["sounds"] = [{"at": 0, "cue": "sting", "db": 0}, {"at": 0, "cue": "sub", "db": -2}]
# the black: the sting rings out; a single drop of water; Kit gasps awake
sh = shots["black"]
sh["dur"] = 1.4
sh["sounds"] = [{"at": 0.3, "cue": "drip", "db": -14}, {"at": 0.75, "cue": "gasp"}]

json.dump(scene, open(path, "w"), indent="\t")
