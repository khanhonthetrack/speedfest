"""(Kept in the repo: regenerates take five's scene from take four's, `git show 131d50f:stadium/story/scenes/<file>`.)
Take five's knock (docs/CINEMATICS.md, first pass item 5): Dee crouched at the window, eyes at Kit's
height, her head outside the glass; Kit breathing; coverage that opens on a two-shot and tightens
(singles over the shoulder, a push on "I saw her in the mirror"), the pins insert pushed in, a wide to
end on; dawn ("Gone six"): a cool key from the arch's mouth, a warm rim from the arch's bulb.
    python3 knock.py <c01_close.json> <out.json>"""
import copy, json, sys

src = json.load(open(sys.argv[1]))
ids = [s["id"] for s in src["shots"]]
old = {s["id"]: s for s in src["shots"]}
head = src["shots"][:ids.index("arch")]

VIADUCT = [{"kind": "viaduct", "pos": [5.6, 0.0, 0.5], "yaw": -90.0, "arches": 7},
           {"kind": "quay", "pos": [0.0, 0.012, 0.0], "rect": [-40.0, -40.0, 5.6, 40.0], "walls": False, "wetness": 0.8}]
KIT_CAR = {"id": "kit", "model": "nemesis", "livery": 1, "tuning": "0.5.6.0", "cabin": True, "finish": "gloss"}
KIT_HEAD = [0.37, 1.07, 0.15]
DEE_FACE = [1.42, 1.1, 0.12]               # where her eyes are, crouched at the window
DAWN = [
    # first light from the street ahead on the driver's side: Kit's face and Dee's, not the roof inside
    {"kind": "spot", "pos": [5.5, 2.4, 3.5], "look": [0.5, 1.05, 0.1], "colour": "#9db4e6", "energy": 3.5, "range": 14.0,
     "angle": 34.0},
    {"kind": "omni", "pos": [3.6, 2.6, 0.4], "colour": "#ffb36b", "energy": 2.2, "range": 6.0},
    {"car": "kit", "kind": "omni", "pos": [0.05, 1.0, 0.75], "colour": "#9fb8ff", "energy": 0.3, "range": 1.6, "shadow": False},
    {"car": "kit", "kind": "omni", "pos": [0.75, 1.3, -0.1], "colour": "#a9bce8", "energy": 0.35, "range": 1.2, "shadow": False},
]
TIRED = {"browInnerUp": 0.35, "jawOpen": 0.03, "browDownLeft": 0.08, "browDownRight": 0.08,
         "mouthFrownLeft": 0.12, "mouthFrownRight": 0.12}
TO_DEE = {"Neck": [0, 10, 0], "Head": [-3, 16, 0]}


def kit(bend=None, **kw):
    p = {"id": "kit_driver", "car": "kit", "seat": "driver", "clip": "Driving", "who": "kit", "rate": 0.12, "start": 0.0,
         "gaze": "dee", "breathe": [1.0, 4.2], "shapes": copy.deepcopy(TIRED),
         "bend": bend or [dict({"t": 0.0}, **copy.deepcopy(TO_DEE))]}
    p.update(kw)
    return p


def dee(**kw):
    # crouched at the driver's window: the crouch tips her head 45 degrees down, brought back up to
    # look in level with Kit
    # (lifted 32 cm, a film set's apple box: the crouch alone put her eyes under the sill of this low
    # coupe; her feet are below the door in every shot she crouches in, and she stands for the wide)
    p = {"id": "dee", "who": "dee", "clip": "Crouch_Idle", "pos": [1.62, 0.0, 0.1], "lift": 0.32, "face": -90, "gaze": "kit_driver",
         "bend": [{"t": 0.0, "Neck": [-18, 0, 0], "Head": [-22, 0, 0]}]}
    p.update(kw)
    return p


def shot(sid, camera, people, lines=None, **kw):
    s = {"id": sid, "track": "H01", "at": 0.62, "bare": True, "rain": 0.5, "ambience": "rain", "grade": "dawn",
         "lead": 0.3, "tail": 0.45, "cars": [copy.deepcopy(KIT_CAR)], "people": people, "lights": copy.deepcopy(DAWN),
         "props": copy.deepcopy(VIADUCT), "camera": camera}
    if lines is not None:
        s["lines"] = lines
    s.update(kw)
    return s


def lines_of(*sids):
    out = []
    for sid in sids:
        out += copy.deepcopy(old[sid].get("lines", []))
    return out


def follow(keys, **kw):
    c = {"follow": "kit", "ease": "inout", "keys": keys}
    c.update(kw)
    return c


shots = []
# the arch at first light: the camera cranes down from 6 m as Dee walks out to the car
arch = copy.deepcopy(old["arch"])
arch["grade"] = "dawn"
arch["camera"] = {"path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": [-15.0, 6.0, -10.0], "look": [3.0, 2.6, 1.0], "fov": 50},
    {"u": 0.6, "pos": [-14.2, 2.6, -9.4], "look": [3.2, 1.6, 1.0], "fov": 50},
    {"u": 1.0, "pos": [-13.6, 1.4, -9.0], "look": [2.8, 1.2, 0.8], "fov": 50}]}
arch["people"] = [{"id": "dee", "who": "dee", "clip": "Walk", "pos": [4.6, 0.0, 0.6], "path": [[4.6, 0.6], [1.9, 0.2]],
                   "walk_at": 0.8, "gaze": ""}]
arch["props"] = copy.deepcopy(VIADUCT)
arch["props"][0]["train"] = [-3.2, 24.0]
arch["lights"] = copy.deepcopy(DAWN[:2]) + [{"kind": "omni", "pos": [-6.0, 6.0, -4.0], "colour": "#8da2cc", "energy": 1.4, "range": 26.0}]
arch.pop("sounds", None)
shots.append(arch)
# the knock: Kit asleep at the wheel, breathing; it wakes at the knuckles on the glass
k = shot("knock", follow([{"u": 0, "pos": [-0.12, 0.98, 0.78], "look": [0.8, 1.12, -0.05], "fov": 40},
                          {"u": 1, "pos": [-0.08, 0.99, 0.7], "look": [0.8, 1.12, -0.05], "fov": 40}]),
         [kit([{"t": 0.0, "Neck": [6, 0, -4], "Head": [10, 0, -12]}, {"t": 0.55, "Neck": [6, 0, -4], "Head": [10, 0, -12]},
               {"t": 1.1, "Neck": [0, 10, 0], "Head": [-3, 16, 0]}], looks=[[0.0, 0.95, "ahead"]], rate=0.0,
              breathe=[1.4, 4.6]), dee()],
         lines_of("knock"), lead=1.9, fade_in=0.4, sounds=[{"at": 0.55, "cue": "thump"}, {"at": 0.9, "cue": "thump"}])
shots.append(k)
# the two-shot from the passenger seat: Kit in profile, Dee at the glass beyond
shots.append(shot("knock_two", follow([{"u": 0, "pos": [-0.45, 0.98, 0.45], "look": [1.2, 1.06, 0.05], "fov": 38},
                                        {"u": 1, "pos": [-0.41, 0.98, 0.41], "look": [1.2, 1.06, 0.05], "fov": 38}],
                                       handheld=0.15),
                  [kit(), dee()], lines_of("knock_dee1", "knock_kit1")))
# singles from inside (the glass hides Kit from outside; behind Kit the headrest blocks Dee): Dee over
# Kit's shoulder from the front, Kit soft at the edge; Kit three-quarter from the dash; both tightening
DEE_1 = follow([{"u": 0, "pos": [-0.05, 1.15, 0.45], "look": DEE_FACE, "fov": 32, "dof_near": [0.5, 0.3, 0.14]},
                {"u": 1, "pos": [-0.03, 1.15, 0.42], "look": DEE_FACE, "fov": 32}], handheld=0.12)
KIT_1 = follow([{"u": 0, "pos": [-0.08, 1.02, 0.68], "look": [0.42, 1.08, 0.08], "fov": 32},
                {"u": 1, "pos": [-0.06, 1.02, 0.65], "look": [0.42, 1.08, 0.08], "fov": 32}], handheld=0.12)
DEE_2 = follow([{"u": 0, "pos": [0.02, 1.14, 0.4], "look": DEE_FACE, "fov": 26, "dof_near": [0.45, 0.25, 0.14]},
                {"u": 1, "pos": [0.04, 1.14, 0.38], "look": DEE_FACE, "fov": 26}], handheld=0.1)
KIT_2 = follow([{"u": 0, "pos": [-0.02, 1.03, 0.6], "look": [0.4, 1.08, 0.1], "fov": 27},
                {"u": 1, "pos": [0.0, 1.03, 0.57], "look": [0.4, 1.08, 0.1], "fov": 27}], handheld=0.1)
shots.append(shot("knock_dee2", DEE_1, [kit(), dee()], lines_of("knock_dee2")))
shots.append(shot("knock_kit2", KIT_1, [kit(), dee()], lines_of("knock_kit2")))
shots.append(shot("knock_dee3", DEE_2, [kit(), dee()], lines_of("knock_dee3")))
push = copy.deepcopy(KIT_2)
push["keys"][1]["pos"] = [0.06, 1.04, 0.5]            # the push on "I saw her in the mirror"
shots.append(shot("knock_kit3", push, [kit(), dee()], lines_of("knock_kit3")))
shots.append(shot("knock_dee4", copy.deepcopy(DEE_2), [kit(), dee()], lines_of("knock_dee4"), tail=0.6))
# the pins: the satnav on a long lens, pushed in over 3 s
pins = copy.deepcopy(old["pins"])
pins["grade"] = "dawn"
pins["dur"] = 3.0
pins["camera"] = follow([{"u": 0, "pos": [0.16, 1.0, 0.34], "look": [0.0, 0.88, 0.7], "fov": 22},
                         {"u": 1, "pos": [0.1, 0.96, 0.44], "look": [0.0, 0.88, 0.7], "fov": 22}])
pins["lights"] = [{"car": "kit", "kind": "omni", "pos": [0.1, 1.0, 0.4], "colour": "#b9a8ff", "energy": 0.6, "range": 1.0,
                   "shadow": False}]
shots.append(pins)
shots.append(shot("knock_kit4", copy.deepcopy(KIT_2), [kit(), dee()], lines_of("knock_kit4"), lead=0.5))
# the end: outside, the camera drawing back and up from the car under the arch
shots.append(shot("knock_end", {"path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": [3.2, 1.3, -4.5], "look": [0.9, 1.0, 0.4], "fov": 40},
    {"u": 1.0, "pos": [4.4, 4.0, -8.0], "look": [1.0, 1.1, 0.6], "fov": 40}]},
    [kit(), {"id": "dee", "who": "dee", "clip": "Stand", "pos": [1.8, 0.0, 0.15], "face": -90, "gaze": "kit_driver"}],
    lines_of("knock_end"), lead=0.8, tail=1.2))

out = copy.deepcopy(src)
out["shots"] = head + shots
json.dump(out, open(sys.argv[2], "w"), indent="\t")
print("knock: %d shots" % len(shots))
