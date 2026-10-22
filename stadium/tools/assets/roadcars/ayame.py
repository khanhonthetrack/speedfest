"""Ayame 300: a compact rear-drive sports sedan of the early 2000s: two big round lamps under each
headlight's glass, a small grille with one bar, four doors, a short trunk and clear tail lamps with
chrome rings and red circles (our own; the class of car NFS Most Wanted's Blacklist #14 drove)."""
from roadcars._util import circle, ellipse, rect

L = 4.485
SPEC = {
    "id": "ayame", "name": "Ayame 300",
    "length": L, "wheelbase": 2.670, "front_overhang": 0.80, "track": (1.495, 1.485),
    # fitted to a drawing (blueprint_fit.py): the windscreen's foot at 1.25, the backlight's at 3.95
    "fit": {"cowl": 1.25, "deck": 3.95},
    "tyre": {"r": (0.32, 0.322), "w": (0.225, 0.245), "rim_r": 0.2286, "rim": "star", "spokes": 6, "dish": 0.05},
    "body": {
        "floor": 0.155,
        "curves": {
            "top": [(0.0, 0.70), (0.15, 0.76), (0.5, 0.83), (0.85, 0.88), (1.15, 0.925), (2.0, 0.96), (3.2, 0.98), (3.55, 1.02),
                    (4.0, 1.04), (4.35, 1.03), (L, 1.0)],
            "edge_x": [(0.0, 0.55), (0.3, 0.62), (0.85, 0.645), (1.15, 0.68), (1.5, 0.765), (3.2, 0.775), (3.7, 0.745), (4.2, 0.71),
                       (L, 0.65)],
            "edge_y": [(0.0, 0.68), (0.15, 0.74), (0.5, 0.81), (0.85, 0.86), (1.15, 0.905), (1.5, 0.93), (3.0, 0.96), (3.55, 1.0),
                       (4.0, 1.02), (4.35, 1.01), (L, 0.98)],
            "sh_x": [(0.0, 0.66), (0.3, 0.79), (0.8, 0.845), (1.2, 0.85), (2.5, 0.85), (3.3, 0.855), (3.9, 0.84), (4.3, 0.81), (L, 0.76)],
            "sh_y": [(0.0, 0.66), (0.3, 0.73), (0.8, 0.82), (1.2, 0.87), (2.0, 0.895), (3.0, 0.92), (3.6, 0.95), (4.2, 0.97),
                     (L, 0.955)],
            "side_x": [(0.0, 0.75), (0.3, 0.83), (0.8, 0.86), (2.0, 0.855), (3.4, 0.86), (4.0, 0.85), (L, 0.79)],
            "side_y": [(0.0, 0.50), (1.0, 0.64), (2.2, 0.64), (3.5, 0.68), (L, 0.70)],
            "rk_x": [(0.0, 0.72), (0.4, 0.82), (1.0, 0.832), (3.4, 0.842), (L, 0.77)],
            "rk_y": [(0.0, 0.28), (1.0, 0.275), (3.4, 0.29), (L, 0.38)],
            "fl_x": [(0.0, 0.60), (0.5, 0.74), (1.0, 0.77), (3.5, 0.77), (L, 0.68)],
            "floor_y": [(0.0, 0.22), (0.45, 0.18), (0.8, 0.16), (3.7, 0.16), (4.1, 0.27), (L, 0.35)],
        },
        "radii": {"edge": 0.04, "sh": 0.045, "side": 0.13, "rk": 0.06, "fl": 0.02},
        "bows": {"edge_sh": 0.005, "sh_side": 0.024, "side_rk": 0.018},
        "front": {"yc": 0.50, "plan": (0.36, 3.1), "top": (0.14, 2.9), "bottom": (0.12, 2.9)},
        "rear": {"yc": 0.74, "plan": (0.28, 3.3), "top": (0.06, 3.5), "bottom": (0.16, 2.5)},
    },
    "cabin": {
        "d0": 1.17, "d1": 4.03,
        "curves": {
            "top": [(1.17, 0.88), (4.03, 1.02)],
            "rail_x": [(1.17, 0.64), (1.6, 0.62), (2.0, 0.60), (2.9, 0.605), (3.4, 0.63), (4.03, 0.69)],
            "base_x": [(1.17, 0.69), (1.45, 0.75), (1.75, 0.765), (3.2, 0.765), (3.7, 0.74), (4.03, 0.70)],
            "crown": 0.045,
        },
        "radii": {"rail": 0.06},
    },
    "arches": {"r": [0.346, 0.348], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.64, 1.32), (0.64, 1.32), (0.50, 1.98), (-0.50, 1.98)], "radii": [0.04, 0.04, 0.07, 0.07]},
        # four doors' glass, a slim fixed pane behind the rear one
        {"plane": "side", "outline": [(1.62, 0.895), (1.72, 1.04), (2.0, 1.245), (2.42, 1.28), (2.38, 0.915)],
         "radii": [0.02, 0.06, 0.1, 0.02, 0.02], "mirror": True},
        {"plane": "side", "outline": [(2.53, 0.92), (2.57, 1.275), (3.0, 1.275), (3.06, 1.255), (3.05, 0.96)],
         "radii": [0.02, 0.02, 0.06, 0.02, 0.02], "mirror": True},
        {"plane": "side", "outline": [(3.12, 0.962), (3.13, 1.235), (3.28, 1.10), (3.39, 0.98)], "radii": [0.02, 0.03, 0.05, 0.03],
         "mirror": True},
        {"plane": "top", "outline": [(-0.52, 3.30), (0.52, 3.30), (0.62, 3.86), (-0.62, 3.86)], "radii": [0.06, 0.06, 0.05, 0.05]},
    ],
    "paint": [
        {"plane": "side", "outline": [(2.37, 0.91), (2.53, 0.92), (2.57, 1.29), (2.43, 1.29)], "radii": [0.01] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(3.04, 0.958), (3.125, 0.962), (3.14, 1.25), (3.06, 1.262)], "radii": [0.005] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(1.50, 0.885), (1.63, 0.895), (1.69, 1.0)], "radii": [0.01] * 3,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(1.16, 0.61), (1.25, 0.612), (1.25, 0.632), (1.16, 0.63)], "radii": [0.009] * 4, "mat": "amber",
         "mirror": True},
    ],
    "insets": [
        # headlights: a small and a big round lamp in chrome bezels under one clear glass
        {"plane": "front", "ray": (-0.3, -0.2, -1), "outline": [(0.40, 0.60), (0.44, 0.535), (0.78, 0.535), (0.82, 0.58), (0.81, 0.70),
                                                                 (0.62, 0.705), (0.50, 0.675)],
         "radii": [0.03, 0.03, 0.05, 0.05, 0.05, 0.05, 0.03], "depth": 0.06, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("ring", (0.48, 0.615), 0.058, 0.044, "chrome"), ("projector", (0.48, 0.615), 0.04, "proj"),
                      ("ring", (0.625, 0.62), 0.078, 0.062, "chrome"), ("projector", (0.625, 0.62), 0.055, "proj"),
                      ("strip", [(0.72, 0.56), (0.79, 0.575)], 0.016, "amber")]},
        # round fog lamps in grilled pods
        {"plane": "front", "outline": [(0.47, 0.285), (0.75, 0.285), (0.76, 0.40), (0.48, 0.40)], "radii": [0.03, 0.04, 0.04, 0.03],
         "depth": 0.04, "mats": ("grille", "trim"), "mirror": True,
         "elements": [("ring", (0.675, 0.343), 0.05, 0.038, "chrome"), ("projector", (0.675, 0.343), 0.036, "proj")]},
        # clear tail lamps with red rings: one in each quarter (wrapping round), one in the lid
        {"plane": "rear", "ray": (-0.45, 0, 1), "outline": [(0.50, 0.70), (0.72, 0.69), (0.78, 0.74), (0.77, 0.86), (0.70, 0.90),
                                                             (0.52, 0.90), (0.48, 0.82)],
         "radii": [0.03, 0.04, 0.04, 0.04, 0.04, 0.04, 0.03], "depth": 0.045, "mats": ("lamp", "trim"), "cover": "lens", "mirror": True,
         "elements": [("ring", (0.595, 0.805), 0.08, 0.056, "light"), ("disc", (0.595, 0.805), 0.03, "amber"),
                      ("strip", [(0.53, 0.718), (0.74, 0.712)], 0.018, "light")]},
        {"plane": "rear", "outline": circle(0.385, 0.80, 0.066, 28), "depth": 0.035, "mats": ("lamp", "trim"), "cover": "lens",
         "mirror": True, "elements": [("ring", (0.385, 0.80), 0.06, 0.04, "light"), ("disc", (0.385, 0.80), 0.022, "lamp")]},
        {"plane": "rear", "outline": rect(-0.29, 0.66, 0.29, 0.87), "radii": [0.03] * 4, "depth": 0.02,
         "mats": ("paint", "paint"), "elements": [("patch", rect(-0.20, 0.685, 0.20, 0.815), [0.01] * 4, "plate", 0.004)]},
    ],
    "recesses": [
        # the small grille with chrome slats, the honeycomb mouth below
        {"plane": "front", "ray": (0, -0.2, -1), "outline": [(-0.30, 0.52), (0.30, 0.52), (0.36, 0.655), (-0.36, 0.655)],
         "radii": [0.03] * 4, "depth": 0.06, "mats": ("grille", "trim"), "bars": {"y": [0.56, 0.60], "mat": "chrome", "t": 0.008}},
        {"plane": "front", "outline": [(-0.40, 0.275), (0.40, 0.275), (0.42, 0.40), (-0.42, 0.40)], "radii": [0.04] * 4,
         "depth": 0.08, "mats": ("grille", "trim")},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.40, 0.885), (1.34, 0.62), (1.38, 0.28), (2.45, 0.28), (2.44, 0.6), (2.40, 0.912)]},
        {"plane": "side", "line": [(2.45, 0.28), (3.08, 0.28), (3.14, 0.45), (3.30, 0.62), (3.40, 0.85), (3.42, 0.98)]},
        {"plane": "top", "line": [(-0.68, 1.20), (-0.70, 0.6), (-0.60, 0.13), (0.60, 0.13), (0.70, 0.6), (0.68, 1.20)], "mirror": False},
        {"plane": "top", "line": [(-0.66, 3.95), (-0.62, 4.40)], "mirror": False},
        {"plane": "top", "line": [(0.66, 3.95), (0.62, 4.40)], "mirror": False},
        {"plane": "rear", "line": [(-0.49, 0.99), (-0.49, 0.64), (0.49, 0.64), (0.49, 0.99)], "mirror": False},
        {"plane": "side", "line": rect(3.53, 0.79, 3.71, 0.92), "closed": True, "mirror": False},
    ],
    "solids": [
        # a small lip spoiler on the trunk's edge
        {"outline": [(4.22, 1.0), (4.42, 0.98), (4.44, 1.01), (4.25, 1.025)], "radii": [0.01, 0.01, 0.01, 0.02], "axis": "x",
         "a0": -0.60, "a1": 0.60, "mat": "paint"},
    ],
    "handles": [(2.27, 0.82), (3.24, 0.86)],
    "mirrors": [{"base": (0.78, 1.62, 0.93), "size": (0.16, 0.105, 0.12), "reach": 0.04}],
    "exhausts": [{"at": (-0.47, 0.27, L - 0.08), "r": 0.05, "length": 0.15, "mirror": False}],
    "wipers": {"d": 1.33, "x": [0.44, -0.08], "len": 0.5, "dir": -1},
}
