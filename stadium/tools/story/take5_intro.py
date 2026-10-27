"""(Kept in the repo: regenerates take five's scene from take four's, `git show 131d50f:stadium/story/scenes/<file>`.)
Take five's opening (docs/CINEMATICS.md, first pass items 3 and 6): the yard on a dark, wet quay
("bare": "set": the docks set's props, the city across the water), lit on purpose (the stage's truss,
sodium masts with black between, a cool backlight over the auction, a fire), and re-cut: the city,
a pass down a container canyon, the yard at eye level, Gus and Kit in medium close-up, Lot 47 in
four different moves under softboxes; the later shots keep their cutting, on the new set and light.
    python3 intro.py <take4 c01_open.json> <out.json>"""
import copy, json, math, sys

src = json.load(open(sys.argv[1]))
old = {s["id"]: s for s in src["shots"]}
ids = [s["id"] for s in src["shots"]]
later = src["shots"][ids.index("phone"):]

# --- the set -----------------------------------------------------------------------------------
props = [{"kind": "quay", "rect": [-420, -150, 64, 420], "edges": ["x1", "z0"], "water": 700,
          "paint": [[-11, -6, -11, 30, 0.15, "#d9a31e"], [11, -6, 11, 30, 0.15, "#d9a31e"],
                    [-11, -6, 11, -6, 0.15, "#d9a31e"], [-5.25, -0.6, -5.25, 4.8, 0.1, "#c8c8c0"],
                    [-1.75, -0.6, -1.75, 4.8, 0.1, "#c8c8c0"], [1.75, -0.6, 1.75, 4.8, 0.1, "#c8c8c0"],
                    [5.25, -0.6, 5.25, 4.8, 0.1, "#c8c8c0"], [-40, 60, 40, 60, 0.2, "#d9a31e"]]}]
for p in src["props"]:
    q = copy.deepcopy(p)
    if q["kind"] == "mast":
        q["colour"] = "#ff9d3c"
        q["energy"] = 14.0
    if q["kind"] == "pole":
        q["colour"] = "#cfd8ff"
        q["energy"] = 8.0
    props.append(q)
props += [
    {"kind": "sts_crane", "pos": [64, 0, -70], "height": 40, "outreach": 48},
    {"kind": "sts_crane", "pos": [64, 0, -15], "height": 40, "outreach": 48, "colour": "#c8c8c4"},
    {"kind": "sts_crane", "pos": [64, 0, 55], "height": 40, "outreach": 48},
    {"kind": "warehouse", "pos": [-25, 0, 88], "size": [60, 10, 26], "doors": 5, "lit": [1, 3]},
    {"kind": "warehouse", "pos": [-100, 0, 88], "size": [60, 10, 26], "doors": 5, "lit": [2], "colour": "#3f4a52"},
    {"kind": "portacabin", "pos": [-13, 0, -7], "yaw": 25, "sign": "PELL SALVAGE"},
    {"kind": "stage", "pos": [0, 0, -3.6], "size": [5, 2.4], "height": 0.5, "energy": 4.5},
    {"kind": "barrel", "pos": [5.6, 0, 12.6]},
    {"kind": "fence", "from": [-30, 60], "to": [30, 60], "height": 2.6},
]
RIG = [  # the yard's own light, besides the props' (masts, poles, the truss, the fire)
    {"kind": "spot", "pos": [0.0, 14.0, -12.0], "look": [0.0, 0.0, 6.0], "colour": "#9fb4ff", "energy": 9.0, "range": 40.0,
     "angle": 50.0},
]
CAR_SHINE = [  # softboxes over and beside Lot 47 (the car stands at z 2), seen only in its paint
    {"kind": "softbox", "pos": [0.0, 5.0, 2.0], "look": [0.0, 0.0, 2.0], "size": [1.2, 7.0], "energy": 1.6},
    {"kind": "softbox", "pos": [4.5, 2.0, 2.0], "look": [0.0, 0.8, 2.0], "size": [7.0, 0.7], "energy": 3.0},
    {"kind": "softbox", "pos": [-4.5, 2.0, 2.0], "look": [0.0, 0.8, 2.0], "size": [7.0, 0.7], "energy": 3.0},
]
PROBE = {"pos": [0.0, 2.0, 2.0], "size": [18.0, 9.0, 18.0]}
ENV = {"height_fog": [3.0, 0.04]}


def people(gus_on_stage=True):
    out = copy.deepcopy(old["yard"]["people"])
    for p in out:
        if p["id"] == "gus" and gus_on_stage:
            p["pos"] = [0.0, 0.5, -2.6]
    return out


def base(sid, camera, **kw):
    s = {"id": sid, "track": "H01", "at": 0.03, "rain": 0.75, "ambience": "rain", "env": copy.deepcopy(ENV),
         "cars": copy.deepcopy(old["yard"]["cars"]), "people": people(), "lights": copy.deepcopy(RIG), "camera": camera}
    s.update(kw)
    return s


def line(lid, text, speaker="Gus", **kw):
    l = {"id": lid, "speaker": speaker, "text": text}
    l.update(kw)
    return l


def orbit(r, h, deg, centre=(0.0, 0.0)):
    a = math.radians(deg)
    return [round(centre[0] + r * math.sin(a), 3), h, round(centre[1] + r * math.cos(a), 3)]


shots = []
# 1. the city across the water, the title in the left third
city = copy.deepcopy(old["city"])
city["dur"] = 4.0
city["env"] = {"fog": 0.0006, "fog_colour": "#1c1020", "fog_sky": 0.4}
city["camera"] = {"ease": "linear", "keys": [
    {"u": 0, "pos": [150.0, 32.0, -60.0], "look": [520.0, 70.0, 140.0], "fov": 40, "roll": 4.0},
    {"u": 1, "pos": [140.0, 26.0, -46.0], "look": [520.0, 60.0, 150.0], "fov": 40, "roll": 0.0}], "handheld": 0.3}
city["lights"] = []
shots.append(city)
# 2. down a canyon of containers, low, the height fog lying in it
shots.append(base("canyon", {"ease": "inout", "handheld": 0.3, "keys": [
    {"u": 0, "pos": [-46.0, 7.0, -66.5], "look": [10.0, 4.0, -66.5], "fov": 30},
    {"u": 1, "pos": [-14.0, 6.0, -66.5], "look": [40.0, 3.0, -64.0], "fov": 30}]}, dur=3.5, people=[]))
# 3. the yard at eye level, behind the crowd, their backs soft in front
shots.append(base("yard", {"ease": "inout", "handheld": 0.2, "keys": [
    {"u": 0, "pos": [-1.6, 1.62, 13.6], "look": [0.2, 1.3, 0.0], "fov": 34, "dof_near": [2.2, 1.2, 0.1], "dof": [18.0, 8.0, 0.1]},
    {"u": 1, "pos": [-1.2, 1.62, 13.0], "look": [0.2, 1.3, 0.0], "fov": 34}]},
    lines=[line("c01_open_001", "Lot forty-six, no reserve, gone to the gentleman at the back for twelve hundred.")]))
# 4. Gus on the stage, from a little below
shots.append(base("gus", {"ease": "inout", "handheld": 0.15, "keys": [
    {"u": 0, "pos": [0.75, 1.8, 0.5], "look": [0.0, 2.05, -2.6], "fov": 30, "dof": [5.0, 4.0, 0.1]},
    {"u": 1, "pos": [0.65, 1.8, 0.3], "look": [0.0, 2.05, -2.6], "fov": 30}]},
    lines=[line("c01_open_001b", "Lot forty-seven.")], lead=0.4, tail=0.6))
# 5. Kit in the crowd: the eyes on the car
shots.append(base("kit_mcu", {"ease": "inout", "handheld": 0.15, "keys": [
    {"u": 0, "pos": [0.12, 1.6, 9.7], "look": [0.4, 1.57, 11.2], "fov": 30, "dof": [3.0, 3.0, 0.12]},
    {"u": 1, "pos": [0.16, 1.6, 9.85], "look": [0.4, 1.57, 11.2], "fov": 30}]}, dur=2.0))


def car_shot(sid, camera, lines, sweep=None, **kw):
    opts = {"lead": 0.3, "tail": 0.4}
    opts.update(kw)
    s = base(sid, camera, lines=lines, probe=copy.deepcopy(PROBE), **opts)
    s["lights"] += copy.deepcopy(CAR_SHINE)
    if sweep:
        s["lights"].append(sweep)
    return s


L = {l["id"]: l for s in src["shots"] for l in s.get("lines", [])}
# 6-10. Lot 47: four different moves
shots.append(car_shot("lot47_nose", {"follow": "kit", "ease": "out", "handheld": 0.15, "keys": [
    {"u": 0, "pos": [2.2, 0.4, 5.2], "look": [0.3, 0.55, 1.4], "fov": 30, "dof": [6.0, 4.0, 0.08]},
    {"u": 1, "pos": [1.5, 0.42, 4.6], "look": [0.2, 0.57, 1.3], "fov": 30}]}, [copy.deepcopy(L["c01_open_002"])]))
shots.append(car_shot("lot47_wheel", {"follow": "kit", "ease": "inout", "keys": [
    {"u": 0, "pos": [1.9, 0.35, 2.6], "look": [0.85, 0.35, 1.3], "fov": 28, "dof": [1.8, 1.0, 0.12]},
    {"u": 1, "pos": [1.95, 0.42, 3.5], "look": [0.85, 0.45, 0.0], "fov": 28, "dof": [3.6, 2.0, 0.1]}]},
    [copy.deepcopy(L["c01_open_002b"])]))
shots.append(car_shot("lot47_orbit", {"follow": "kit", "path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": orbit(5.2, 0.9, 200), "look": [0.0, 0.6, -0.3], "fov": 32},
    {"u": 0.5, "pos": orbit(5.2, 0.95, 212), "look": [0.0, 0.6, -0.3], "fov": 32},
    {"u": 1.0, "pos": orbit(5.2, 1.0, 225), "look": [0.0, 0.6, -0.3], "fov": 32}]}, [copy.deepcopy(L["c01_open_002c"])]))
paint = old["lot47_paint"]["camera"]
shots.append(car_shot("lot47_paint", {"follow": "kit", "ease": "linear", "handheld": 0.12, "keys": [
    dict(paint["keys"][0], fov=26), dict(paint["keys"][1], fov=26)]}, [copy.deepcopy(L["c01_open_003"])]))
shots.append(car_shot("lot47_hero", {"follow": "kit", "ease": "out", "keys": [
    {"u": 0, "pos": [0.0, 0.45, 7.4], "look": [0.0, 0.62, 0.5], "fov": 30, "dof": [9.0, 6.0, 0.06]},
    {"u": 1, "pos": [0.0, 0.5, 6.2], "look": [0.0, 0.64, 0.5], "fov": 30}]}, [copy.deepcopy(L["c01_open_003b"])],
    sweep={"kind": "spot", "pos": [-6.0, 7.0, 6.0], "look": [-2.2, 0.6, 2.0], "look_to": [2.2, 0.6, 2.0],
           "colour": "#e8eeff", "energy": 7.0, "range": 16.0, "angle": 16.0}, tail=0.9))

# the later shots: the same set and light
for s in later:
    s = copy.deepcopy(s)
    s["lights"] = copy.deepcopy(RIG) + [l for l in s.get("lights", []) if l.get("car")]
    s["env"] = copy.deepcopy(ENV)
    for p in s.get("people", []):
        if p.get("id") == "gus":
            p["pos"] = [p["pos"][0], 0.5, p["pos"][2]] if abs(p["pos"][2] + 2.6) < 0.5 else p["pos"]
    shots.append(s)

out = copy.deepcopy(src)
out["bare"] = "set"
out["grade"] = "night"
out["props"] = props
out["shots"] = shots
json.dump(out, open(sys.argv[2], "w"), indent="\t")
print("opening: %d shots" % len(shots))
