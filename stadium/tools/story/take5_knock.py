"""(Kept in the repo: regenerates take five's scene from take four's, `git show 131d50f:stadium/story/scenes/<file>`; the Mirror: take5_mirror.py, then take5_mirror2.py, then take5_knock.py.)
Take five's knock (docs/CINEMATICS.md, first pass item 5): Dee leaning in at the window, her hands on
its frame (owner, 27 Oct: "Cant you let Dee lean and put hands on the window? It is more realistic i
think"; take five crouched her), eyes at Kit's height, her head outside the glass; Kit breathing; coverage that opens on a two-shot and tightens
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
KIT_CAR = {"id": "kit", "model": "nemesis", "livery": 1, "tuning": "0.5.6.0", "cabin": True, "finish": "gloss",
           "windows_down": ["driver"]}         # Kit winds it down in the first shot (WINDING)
KIT_HEAD = [0.37, 1.07, 0.15]
DEE_FACE = [0.98, 1.15, 0.1]               # where her eyes are, leaning in at the window (the car's frame)
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
TO_DEE = {"Neck": [6, 22, 0], "Head": [8, 30, 0]}      # (26 degrees left Kit looking at the window frame)


def kit(bend=None, **kw):
    p = {"id": "kit_driver", "car": "kit", "seat": "driver", "clip": "Driving", "who": "kit", "rate": 0.12, "start": 0.0,
         "gaze": "dee", "breathe": [1.0, 4.2], "shapes": copy.deepcopy(TIRED),
         "bend": bend or [dict({"t": 0.0}, **copy.deepcopy(TO_DEE))]}
    p.update(kw)
    return p


# Dee leans in at the driver's window from standing: hinged at the hips, the knees a little bent under
# her (her feet kept flat), a little more up the back, her head brought up to look in at Kit. She
# knocks with the window up, her other hand on the door; Kit winds it down (WINDING) and she leans on
# the door with both hands on the window's ledge. The coupe measured (raycast through nemesis.glb; the
# car's frame, x out to its left): the door's top at x 0.82 at y 0.883 (z 0.4) to 0.895 (z -0.2),
# falling outwards 0.35 in 1 (at x 0.85 y 0.867); the side glass from y 0.90 (x 0.77) to 1.25 (x 0.63),
# at y 1.08 x 0.695, facing out (0.907, 0.422); Dee is 1.60 m, her pelvis at 0.83. The marks are where
# a palm's skin lands (StoryPerson.PALM_HALF puts its bones off it).
KNEE = 22                                      # degrees the knees come forward (the shins back twice that)
# (_bend turns a bone about the body's x in its own place: + tips an upright bone forwards and a hanging
# one's end backwards, so the thighs come forward with less than the hips' -46 and the shins go back)
LEAN = {"Hips": [46, 0, 0], "LeftUpperLeg": [-46 - KNEE, 0, 0], "RightUpperLeg": [-46 - KNEE, 0, 0],
        "LeftLowerLeg": [2 * KNEE, 0, 0], "RightLowerLeg": [2 * KNEE, 0, 0], "LeftFoot": [-KNEE, 0, 0],
        "RightFoot": [-KNEE, 0, 0], "Spine": [8, 0, 0], "Chest": [5, 0, 0], "UpperChest": [3, 0, 0],
        "Neck": [-16, 0, 0], "Head": [-18, 0, 0]}
SINK = -0.058                                  # the bent knees bring the hips down (her feet stay on the ground)
DOOR_IN = [-0.35, -0.94, 0.0]                  # the way into the door's top (it falls outwards)
GLASS_IN = [-0.907, -0.422, 0.0]               # the way into the side glass
GLASS_UP = [-0.422, 0.907, 0.0]                # up along it


def door_top(x, z):
    """The door's top under the window at x (0.80-0.86) and z: its height, as measured."""
    y_at = {0.42: 0.883, 0.4: 0.883, -0.2: 0.895}[z]          # at x 0.82
    return [x, round(y_at - 0.35 * (x - 0.82), 4), z]


def on_ledge(z, fingers, x=0.82):
    """A palm on the door's top, where the window winds into it."""
    return {"at": door_top(x, z), "palm": DOOR_IN, "fingers": fingers}


def hands(t, **over):
    """Both hands on the window's ledge, either side of her (her left: the car's front), fingers into the car."""
    k = {"t": t, "LeftHand": on_ledge(0.4, [-0.94, 0.2, 0.25]), "RightHand": on_ledge(-0.2, [-0.94, 0.2, -0.25])}
    k.update(over)
    return k


def up_hands(t, right=None):
    """The window up: the left hand on the door's top outside the glass, its fingertips at the glass's
    foot; the right too, or as given."""
    return {"t": t, "LeftHand": on_ledge(0.4, [-0.94, 0.25, 0.25], 0.85),
            "RightHand": right or on_ledge(-0.2, [-0.94, 0.25, -0.25], 0.85)}


GLASS_OUT = [0.907, 0.422, 0.0]
FIST_DOWN = [0.422, -0.907, 0.0]               # a knocking fist's palm: down and towards her


def rap(t, off):
    """Her right fist at the glass by Kit's head, its knuckles `off` m out from it (0: on it): the
    fingers curled and pointing into the glass, so the backs of the first finger joints strike it (the
    knuckles 6.5 cm ahead of the palm's middle; the mark is the palm's skin, PALM_HALF under it)."""
    g = [0.686, 1.10, -0.02]                    # the glass at y 1.10
    d = 0.065 + off
    at = [round(g[i] + GLASS_OUT[i] * d + FIST_DOWN[i] * 0.02, 4) for i in range(3)]
    # the elbow out to her right and a little back, so the forearm comes at the glass, not up beside it
    return up_hands(t, {"at": at, "palm": FIST_DOWN, "fingers": GLASS_IN, "fist": 1.0, "elbow": [0.45, -0.25, -1.0]})


def dee(reach=None, bend=None, **kw):
    p = {"id": "dee", "who": "dee", "clip": "Stand", "pos": [1.55, 0.0, 0.1], "lift": SINK, "face": -90,
         "gaze": "kit_driver", "reach_car": "kit", "bend": bend or [dict({"t": 0.0}, **copy.deepcopy(LEAN))],
         "reach": reach or [hands(0.0)]}
    p.update(kw)
    return p


# the knock: two taps of her hand on the glass by Kit's head (the thumps at 0.55 and 0.9 s), the hand
# resting on the glass, then on the door's top by the other; Kit winds the window down as Dee's "Open
# up" ends and Kit answers (3.6-5.0 s: her line runs 1.9-4.0, Kit's 4.3-6.8), and her hands go in over
# the ledge once the glass is down
# two quick raps of her knuckles (the thumps at 0.55 and 0.9 s): 4-5 cm back, 0.12-0.15 s in, a little
# faster out; the fist held a moment by the glass, then down on the door by the other hand
KNOCKING = [rap(0.0, 0.07), rap(0.42, 0.045), rap(0.55, 0.0), rap(0.68, 0.04), rap(0.9, 0.0), rap(1.03, 0.05),
            rap(1.7, 0.06), up_hands(2.5), up_hands(5.2), hands(5.8)]
WINDING = {"driver": [3.6, 5.0]}


DAWN_AIR = {"fog": 0.002, "fog_colour": "#5d6f96", "fog_sky": 0.85, "exposure": 1.35}   # "gone six": a blue-grey sky


def shot(sid, camera, people, lines=None, **kw):
    s = {"id": sid, "track": "H01", "at": 0.62, "bare": True, "rain": 0.5, "ambience": "rain", "grade": "dawn",
         "env": copy.deepcopy(DAWN_AIR),
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
arch["env"] = copy.deepcopy(DAWN_AIR)
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
              breathe=[1.4, 4.6]), dee(reach=copy.deepcopy(KNOCKING), pos=[1.48, 0.0, 0.1])],
         lines_of("knock"), lead=1.9, fade_in=0.4, sounds=[{"at": 0.55, "cue": "thump"}, {"at": 0.9, "cue": "thump"}])
k["cars"][0]["windows_down"] = copy.deepcopy(WINDING)
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
pins["env"] = copy.deepcopy(DAWN_AIR)
pins["dur"] = 3.0
pins["camera"] = follow([{"u": 0, "pos": [0.16, 1.0, 0.34], "look": [0.0, 0.88, 0.7], "fov": 22},
                         {"u": 1, "pos": [0.1, 0.96, 0.44], "look": [0.0, 0.88, 0.7], "fov": 22}])
for c in pins["cars"]:
    if c.get("id") == "kit":
        c["windows_down"] = ["driver"]
pins["lights"] = [{"car": "kit", "kind": "omni", "pos": [0.1, 1.0, 0.4], "colour": "#b9a8ff", "energy": 0.6, "range": 1.0,
                   "shadow": False}]
shots.append(pins)
shots.append(shot("knock_kit4", copy.deepcopy(KIT_2), [kit(), dee()], lines_of("knock_kit4"), lead=0.5))
# the end: outside, the camera drawing back and up from the car under the arch
shots.append(shot("knock_end", {"path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": [3.2, 1.3, -4.5], "look": [0.9, 1.0, 0.4], "fov": 40},
    {"u": 1.0, "pos": [4.4, 4.0, -8.0], "look": [1.0, 1.1, 0.6], "fov": 40}]},
    # she straightens up as she says it, her knees and hips with her (the lift eased back to the ground),
    # still looking down at Kit
    [kit(), dee(bend=[dict({"t": 0.9}, **copy.deepcopy(LEAN)), {"t": 2.3, "Neck": [10, 0, 0], "Head": [14, 0, 0]}],
                reach=[hands(0.9), {"t": 1.9}], lift=[[0.9, SINK], [2.3, 0.0]])],
    lines_of("knock_end"), lead=0.8, tail=1.2))

out = copy.deepcopy(src)
out["shots"] = head + shots
# Lot 47 in its own paint, black with grey camouflage painted by hand (StoryScene.PAINTS)
for sh in out["shots"]:
    for car in sh.get("cars", []):
        if car.get("id") == "kit" and car.get("model") == "nemesis":
            car["paint"] = "lot47"
json.dump(out, open(sys.argv[2], "w"), indent="\t")
print("knock: %d shots" % len(shots))
