"""Quicksilver: a front-mid-engined supercharged grand tourer of the mid 2000s with an endless hood:
a racing-car beak for a nose between two low intakes, long swept headlights, gills of slats
behind the front wheels, pipes along the sills, a cab right at the back and a short tail with an
air-brake spoiler (our own; the class of car NFS Most Wanted's Blacklist #2 drove)."""
from roadcars._util import circle, ellipse, rect

L = 4.656
SPEC = {
    "id": "quicksilver", "name": "Quicksilver",
    "length": L, "wheelbase": 2.70, "front_overhang": 1.15, "track": (1.638, 1.569),
    # fitted to a drawing (blueprint_fit.py): the windscreen's foot at 1.98, the backlight's at 4.10,
    # the air brake on the measured tail
    "fit": {"cowl": 1.98, "deck": 4.10},
    "tyre": {"r": (0.33, 0.335), "w": (0.245, 0.295), "rim_r": 0.2413, "rim": "turbine", "spokes": 9, "dish": 0.02},
    "body": {
        "floor": 0.13,
        "curves": {
            "top": [(0.0, 0.54), (0.12, 0.59), (0.5, 0.68), (1.15, 0.78), (1.7, 0.85), (2.08, 0.89), (2.8, 0.93), (3.7, 0.95),
                    (4.2, 0.99), (4.5, 1.0), (L, 0.97)],
            "hood_x": [(0.0, 0.16), (0.3, 0.22), (1.0, 0.30), (1.8, 0.36), (2.2, 0.50), (3.7, 0.62), (L, 0.58)],
            "hood_y": [(0.0, 0.53), (0.12, 0.575), (0.5, 0.665), (1.15, 0.765), (1.7, 0.835), (2.08, 0.875), (2.8, 0.915), (3.7, 0.935),
                       (4.2, 0.975), (4.5, 0.985), (L, 0.955)],
            "edge_x": [(0.0, 0.52), (0.3, 0.64), (1.15, 0.74), (1.9, 0.75), (2.4, 0.79), (3.6, 0.81), (4.2, 0.79), (L, 0.72)],
            "edge_y": [(0.0, 0.52), (0.2, 0.60), (0.6, 0.69), (1.15, 0.76), (1.7, 0.82), (2.08, 0.86), (2.8, 0.90), (3.7, 0.925),
                       (4.2, 0.965), (4.5, 0.975), (L, 0.945)],
            "sh_x": [(0.0, 0.66), (0.3, 0.82), (1.15, 0.935), (1.9, 0.90), (2.8, 0.895), (3.5, 0.915), (3.85, 0.925), (4.3, 0.89), (L, 0.80)],
            "sh_y": [(0.0, 0.50), (0.3, 0.59), (1.15, 0.70), (1.9, 0.79), (2.8, 0.84), (3.5, 0.87), (3.85, 0.89), (4.3, 0.92), (L, 0.90)],
            "side_x": [(0.0, 0.74), (0.3, 0.87), (1.15, 0.954), (1.9, 0.925), (2.8, 0.915), (3.5, 0.93), (3.85, 0.94), (4.3, 0.91),
                       (L, 0.84)],
            "side_y": [(0.0, 0.40), (1.15, 0.50), (2.8, 0.54), (3.8, 0.58), (L, 0.60)],
            "rk_x": [(0.0, 0.70), (0.4, 0.85), (1.1, 0.90), (2.8, 0.89), (3.8, 0.90), (L, 0.80)],
            "rk_y": [(0.0, 0.22), (1.0, 0.22), (3.7, 0.25), (L, 0.34)],
            "fl_x": [(0.0, 0.60), (0.5, 0.80), (1.0, 0.84), (3.8, 0.84), (L, 0.72)],
            "floor_y": [(0.0, 0.17), (0.5, 0.145), (1.0, 0.135), (3.95, 0.135), (4.25, 0.24), (L, 0.31)],
        },
        "radii": {"hood": 0.12, "edge": 0.06, "sh": 0.05, "side": 0.13, "rk": 0.05, "fl": 0.02},
        "bows": {"hood_edge": -0.006, "edge_sh": 0.01, "sh_side": 0.024, "side_rk": 0.018, "crown_q": 1.5},
        "front": {"yc": 0.42, "plan": (0.62, 2.5), "top": (0.14, 2.7), "bottom": (0.10, 2.9)},
        "rear": {"yc": 0.68, "plan": (0.28, 3.1), "top": (0.05, 3.5), "bottom": (0.18, 2.5)},
    },
    "cabin": {
        "d0": 1.92, "d1": 4.14,
        "curves": {
            "top": [(1.92, 0.94), (4.14, 1.03)],
            "rail_x": [(1.92, 0.66), (2.4, 0.63), (2.9, 0.60), (3.4, 0.61), (3.8, 0.65), (4.14, 0.70)],
            "base_x": [(1.92, 0.71), (2.3, 0.78), (2.7, 0.795), (3.6, 0.80), (3.95, 0.78), (4.14, 0.74)],
            "crown": 0.05,
        },
        "radii": {"rail": 0.07},
    },
    "arches": {"r": [0.356, 0.361], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.66, 2.04), (0.66, 2.04), (0.55, 2.62), (-0.55, 2.62)], "radii": [0.04, 0.04, 0.08, 0.08]},
        # the gullwing door's glass and a small quarter glass behind it
        {"plane": "side", "outline": [(2.25, 0.91), (2.32, 0.97), (2.62, 1.12), (3.20, 1.15), (3.30, 1.10), (3.32, 0.915)],
         "radii": [0.02, 0.04, 0.12, 0.06, 0.04, 0.02], "mirror": True},
        {"plane": "side", "outline": [(3.40, 0.925), (3.42, 1.06), (3.58, 0.94)], "radii": [0.02, 0.03, 0.02], "mirror": True},
        {"plane": "top", "outline": [(-0.52, 3.52), (0.52, 3.52), (0.58, 4.06), (-0.58, 4.06)], "radii": [0.06, 0.06, 0.05, 0.05]},
    ],
    "paint": [
        {"plane": "side", "outline": [(2.10, 0.90), (2.25, 0.91), (2.30, 0.96)], "radii": [0.01] * 3,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(3.32, 0.915), (3.40, 0.925), (3.42, 1.07), (3.31, 1.11)], "radii": [0.005] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(0.84, 0.425), (0.98, 0.43), (0.98, 0.455), (0.84, 0.45)], "radii": [0.012] * 4, "mat": "amber",
         "mirror": True},
    ],
    "insets": [
        # headlights: two pods a side, each a small lamp over a bigger one
        {"plane": "front", "ray": (-0.2, -0.08, -1), "outline": [(0.47, 0.545), (0.62, 0.535), (0.78, 0.55), (0.80, 0.62), (0.75, 0.68),
                                                                  (0.62, 0.665), (0.52, 0.665), (0.47, 0.61)],
         "radii": [0.03, 0.04, 0.04, 0.04, 0.04, 0.03, 0.04, 0.03], "depth": 0.05, "mats": ("lamp", "lamp"), "cover": "lens",
         "mirror": True,
         "elements": [("ring", (0.555, 0.575), 0.035, 0.026, "chrome"), ("projector", (0.555, 0.575), 0.026, "proj"),
                      ("ring", (0.545, 0.635), 0.022, 0.016, "chrome"), ("projector", (0.545, 0.635), 0.016, "proj"),
                      ("ring", (0.70, 0.585), 0.035, 0.026, "chrome"), ("projector", (0.70, 0.585), 0.026, "proj"),
                      ("ring", (0.705, 0.645), 0.022, 0.016, "chrome"), ("projector", (0.705, 0.645), 0.016, "proj")]},
        # tail lamps: two light bars in a dark housing a side
        {"plane": "rear", "ray": (-0.45, 0, 1), "outline": [(0.55, 0.74), (0.80, 0.75), (0.90, 0.80), (0.91, 0.88), (0.84, 0.94),
                                                             (0.62, 0.93), (0.56, 0.86)],
         "radii": [0.03, 0.04, 0.04, 0.04, 0.04, 0.04, 0.03], "depth": 0.035, "mats": ("lamp", "trim"), "cover": "lens_red",
         "mirror": True,
         "elements": [("strip", [(0.63, 0.86), (0.85, 0.865)], 0.018, "light"), ("strip", [(0.64, 0.81), (0.85, 0.80)], 0.018, "light")]},
        {"plane": "rear", "outline": rect(-0.20, 0.75, 0.20, 0.88), "radii": [0.02] * 4, "depth": 0.015,
         "mats": ("paint", "paint"), "elements": [("patch", rect(-0.18, 0.765, 0.18, 0.865), [0.01] * 4, "plate", 0.004)]},
        # the side pipes, out of the sills under the gills
        {"plane": "side", "outline": ellipse(1.53, 0.20, 0.06, 0.03, 24), "depth": 0.05, "mats": ("trim", "trim"), "mirror": True,
         "elements": [("ring", (1.53, 0.20), 0.055, 0.04, "chrome")]},
        {"plane": "side", "outline": ellipse(1.67, 0.20, 0.06, 0.03, 24), "depth": 0.05, "mats": ("trim", "trim"), "mirror": True,
         "elements": [("ring", (1.67, 0.20), 0.055, 0.04, "chrome")]},
    ],
    "recesses": [
        # the lower mouth either side of the beak's foot, a slot beside the beak
        {"plane": "front", "ray": (-0.2, 0, -1), "outline": [(0.08, 0.25), (0.64, 0.25), (0.68, 0.33), (0.60, 0.40), (0.12, 0.40)],
         "radii": [0.03, 0.04, 0.05, 0.06, 0.04], "depth": 0.12, "mats": ("grille", "trim"), "mirror": True},
        {"plane": "front", "ray": (-0.2, -0.2, -1), "outline": rect(0.16, 0.535, 0.44, 0.555), "radii": [0.008] * 4, "depth": 0.03,
         "mats": ("grille", "trim"), "mirror": True},
        # the hood's two vents near the windscreen
        {"plane": "top", "outline": [(0.20, 1.55), (0.62, 1.48), (0.63, 1.56), (0.21, 1.62)], "radii": [0.02] * 4, "depth": 0.03,
         "mats": ("grille", "trim"), "mirror": True},
        # the gills: a long vent behind each front wheel, slanted slats in it
        {"plane": "side", "outline": [(1.40, 0.57), (1.95, 0.63), (2.06, 0.62), (2.15, 0.30), (1.92, 0.31), (1.52, 0.48)],
         "radii": [0.03, 0.03, 0.03, 0.03, 0.03, 0.05], "depth": 0.04, "mats": ("inlet", "trim"), "mirror": True,
         "bars": {"y": [1.62, 1.72, 1.82, 1.92, 2.02], "vertical": True, "mat": "paint", "t": 0.018, "at": 0.3}},
        # the rear: a vent across under the lamps, the diffuser's fins below
        {"plane": "rear", "outline": [(-0.56, 0.49), (0.56, 0.49), (0.62, 0.53), (0.50, 0.56), (-0.50, 0.56), (-0.62, 0.53)],
         "radii": [0.02] * 6, "depth": 0.04, "mats": ("grille", "trim")},
        {"plane": "rear", "outline": [(-0.62, 0.26), (0.62, 0.26), (0.64, 0.42), (-0.64, 0.42)], "radii": [0.04] * 4, "depth": 0.06,
         "mats": ("trim", "trim"), "bars": {"y": [-0.45, -0.25, 0.0, 0.25, 0.45], "vertical": True, "mat": "trim", "t": 0.012}},
    ],
    "gaps": [
        {"plane": "top", "line": [(-0.74, 1.90), (-0.76, 0.9), (-0.56, 0.12), (0.56, 0.12), (0.76, 0.9), (0.74, 1.90)], "mirror": False},
        {"plane": "side", "line": [(2.18, 0.90), (2.17, 0.6), (2.22, 0.27), (3.25, 0.27), (3.30, 0.6), (3.33, 0.915)]},
        # the beak: one line down each side of the nose's centre
        {"plane": "front", "line": [(0.22, 0.78), (0.10, 0.50), (0.03, 0.42)], "ray": (0, -0.3, -1)},
    ],
    "solids": [
        # the air brake, flush with the tail
        {"outline": [(4.28, 0.985), (4.60, 0.965), (4.62, 0.99), (4.32, 1.005)], "radii": [0.01, 0.01, 0.01, 0.02], "axis": "x",
         "a0": -0.74, "a1": 0.74, "mat": "paint"},
    ],
    "splitter": {"d1": 0.5, "reach": 0.03, "y": 0.13, "t": 0.016, "mat": "carbon"},
    "mirrors": [{"base": (0.80, 2.24, 0.92), "size": (0.15, 0.09, 0.12), "reach": 0.05}],
    "exhausts": [],
    "wipers": {"d": 2.08, "x": [0.42, -0.08], "len": 0.5, "dir": -1},
}
