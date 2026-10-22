"""The rim library for tuning (PLAN M18): nine rim designs at one reference size, scaled by the game
to each car's wheels (TmCarVisual: the radius to the car's rim radius, the width to its tyre's).
Built with roadcar.py's rim maker; the stock rim stays each car's own.

usage: blender -b -P stadium/tools/assets/rims.py -- --out stadium/assets/car/rims.glb
Objects Rim1..Rim9 (TmRoadCars.RIMS), each the +x side's rim centred on its origin (axis x, the
face towards +x), at bead radius REF_R and half width REF_HW; materials rim (the design's finish,
set by the game), rim_lip (polished).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import roadcar as rc

REF_R = 0.24
REF_HW = 0.12
# k: (style, spokes, dish, lip, nuts)
STYLES = {
    1: ("five", 5, 0.035, 0.0, 5),       # five spoke
    2: ("split", 5, 0.03, 0.0, 5),       # split five
    3: ("mesh", 10, 0.03, 0.0, 5),       # mesh
    4: ("multi", 14, 0.02, 0.0, 5),      # multi-spoke
    5: ("turbine", 9, 0.02, 0.0, 5),     # turbine
    6: ("star", 6, 0.05, 0.0, 6),        # star
    7: ("multi", 8, 0.03, 0.045, 5),     # deep dish: a stepped polished lip
    8: ("five", 6, 0.04, 0.0, 6),        # six spoke
    9: ("twist", 5, 0.025, 0.0, 5),      # twisted twin spokes
}


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obs = []
    for k, (style, n, dish, lip, nuts) in STYLES.items():
        t = {"rim": style, "spokes": n, "dish": dish, "lip": lip, "nuts": nuts}
        o = rc.rim_object(t, REF_R, REF_HW, "Rim%d" % k)
        o.data.shade_smooth()
        o.data.set_sharp_from_angle(angle=0.61)
        obs.append(o)
    return obs


if __name__ == "__main__":
    obs = build()
    out = rc.opt("out")
    if out:
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        rc.export_objects(obs, out)
        print("RIMS wrote", out, {o.name: len(o.data.polygons) for o in obs})
