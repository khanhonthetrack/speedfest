"""Umbra GTS: a rounded front-drive sport coupe of the mid 2000s: a narrow slot over a wide low
mouth, almond headlights sweeping up the fenders, a dome roof falling to a hatch, the belt kicking
up over muscular rear haunches, a full-width tail-lamp band (our own; the class of car NFS Most
Wanted's Blacklist #11 drove)."""
from roadcars._util import circle, ellipse, rect

L = 4.565
SPEC = {
    "id": "umbra", "name": "Umbra GTS",
    "length": L, "wheelbase": 2.575, "front_overhang": 0.98, "track": (1.57, 1.565),
    "tyre": {"r": (0.334, 0.334), "w": (0.235, 0.235), "rim_r": 0.2413, "rim": "turbine", "spokes": 7, "dish": 0.03},
    "body": {
        "floor": 0.14,
        "curves": {
            "top": [(0.0, 0.62), (0.2, 0.69), (0.6, 0.78), (1.0, 0.85), (1.32, 0.90), (2.0, 0.94), (3.2, 0.98), (3.75, 1.02),
                    (4.2, 1.04), (L, 1.0)],
            "edge_x": [(0.0, 0.52), (0.3, 0.62), (0.9, 0.67), (1.3, 0.70), (1.7, 0.77), (3.3, 0.78), (3.9, 0.75), (4.3, 0.71), (L, 0.64)],
            "edge_y": [(0.0, 0.61), (0.2, 0.675), (0.6, 0.77), (1.0, 0.835), (1.32, 0.88), (1.7, 0.90), (3.0, 0.96), (3.75, 1.0),
                       (4.2, 1.015), (L, 0.98)],
            "sh_x": [(0.0, 0.64), (0.3, 0.80), (0.9, 0.88), (1.4, 0.87), (2.4, 0.86), (3.3, 0.88), (3.8, 0.89), (4.3, 0.84), (L, 0.76)],
            "sh_y": [(0.0, 0.58), (0.3, 0.66), (0.9, 0.78), (1.4, 0.84), (2.0, 0.87), (2.8, 0.91), (3.4, 0.96), (3.9, 0.985),
                     (4.3, 0.98), (L, 0.95)],
            "side_x": [(0.0, 0.74), (0.3, 0.86), (0.9, 0.915), (1.4, 0.90), (2.2, 0.89), (3.0, 0.905), (3.55, 0.918), (4.1, 0.89),
                       (L, 0.80)],
            "side_y": [(0.0, 0.45), (0.9, 0.58), (2.2, 0.60), (3.5, 0.66), (L, 0.66)],
            "rk_x": [(0.0, 0.70), (0.4, 0.84), (1.0, 0.86), (3.4, 0.87), (L, 0.78)],
            "rk_y": [(0.0, 0.24), (1.0, 0.25), (3.4, 0.27), (L, 0.36)],
            "fl_x": [(0.0, 0.58), (0.5, 0.76), (1.0, 0.80), (3.5, 0.80), (L, 0.68)],
            "floor_y": [(0.0, 0.19), (0.5, 0.16), (0.95, 0.145), (3.7, 0.145), (4.1, 0.25), (L, 0.32)],
        },
        "radii": {"edge": 0.05, "sh": 0.05, "side": 0.13, "rk": 0.06, "fl": 0.02},
        "bows": {"edge_sh": 0.008, "sh_side": 0.024, "side_rk": 0.018},
        "front": {"yc": 0.42, "plan": (0.46, 2.9), "top": (0.20, 2.9), "bottom": (0.12, 2.9)},
        "rear": {"yc": 0.70, "plan": (0.26, 3.3), "top": (0.08, 3.3), "bottom": (0.18, 2.5)},
    },
    "cabin": {
        "d0": 1.30, "d1": 4.12,
        "curves": {
            "top": [(1.30, 0.905), (1.5, 1.03), (1.75, 1.18), (2.0, 1.29), (2.3, 1.345), (2.6, 1.358), (2.9, 1.335), (3.2, 1.28),
                    (3.5, 1.20), (3.8, 1.12), (4.0, 1.07), (4.12, 1.04)],
            "rail_x": [(1.30, 0.63), (1.7, 0.61), (2.2, 0.585), (2.7, 0.59), (3.2, 0.61), (3.7, 0.64), (4.12, 0.68)],
            "base_x": [(1.30, 0.68), (1.55, 0.75), (1.9, 0.78), (3.2, 0.78), (3.7, 0.76), (4.12, 0.70)],
            "crown": 0.05,
        },
        "radii": {"rail": 0.07},
    },
    "arches": {"r": [0.360, 0.360], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.64, 1.38), (0.64, 1.38), (0.55, 2.10), (-0.55, 2.10)], "radii": [0.04, 0.04, 0.08, 0.08]},
        # the door glass, a blacked-out pillar, the quarter glass narrowing to a point
        {"plane": "side", "outline": [(1.52, 0.905), (1.58, 0.97), (2.10, 1.27), (2.70, 1.31), (2.86, 1.30), (2.86, 0.965)],
         "radii": [0.02, 0.05, 0.12, 0.08, 0.02, 0.02], "mirror": True},
        {"plane": "side", "outline": [(2.95, 0.97), (2.95, 1.29), (3.20, 1.24), (3.55, 1.10), (3.64, 1.035), (3.45, 0.995)],
         "radii": [0.02, 0.03, 0.1, 0.06, 0.03, 0.03], "mirror": True},
        # the hatch glass, down to the spoiler
        {"plane": "top", "outline": [(-0.54, 3.05), (0.54, 3.05), (0.64, 4.02), (-0.64, 4.02)], "radii": [0.06, 0.06, 0.05, 0.05]},
    ],
    "insets": [
        # almond headlights sweeping up and back along the fenders
        {"plane": "front", "ray": (-0.45, -0.15, -1), "outline": [(0.36, 0.585), (0.62, 0.595), (0.80, 0.63), (0.86, 0.70),
                                                                    (0.82, 0.745), (0.58, 0.69), (0.38, 0.635)],
         "radii": [0.03, 0.06, 0.05, 0.02, 0.05, 0.05, 0.02], "depth": 0.05, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("projector", (0.50, 0.62), 0.042, "proj"), ("strip", [(0.62, 0.63), (0.80, 0.68)], 0.012, "led"),
                      ("strip", [(0.72, 0.65), (0.84, 0.69)], 0.012, "amber")]},
        # the tail-lamp band across the hatch
        {"plane": "rear", "ray": (-0.3, 0, 1), "outline": [(-0.84, 0.88), (0.84, 0.88), (0.87, 0.93), (0.84, 0.97), (-0.84, 0.97),
                                                             (-0.87, 0.93)],
         "radii": [0.02, 0.03, 0.02, 0.03, 0.02, 0.02], "depth": 0.03, "mats": ("lamp", "trim"), "cover": "lens_red",
         "elements": [("strip", [(-0.80, 0.925), (-0.42, 0.925)], 0.04, "light"), ("strip", [(0.42, 0.925), (0.80, 0.925)], 0.04, "light"),
                      ("strip", [(-0.38, 0.925), (0.38, 0.925)], 0.012, "light")]},
        {"plane": "rear", "outline": rect(-0.27, 0.50, 0.27, 0.65), "radii": [0.01] * 4, "depth": 0.018,
         "mats": ("trim", "trim"), "elements": [("patch", rect(-0.255, 0.51, 0.255, 0.64), [0.01] * 4, "plate", 0.004)]},
        {"plane": "front", "outline": ellipse(0.70, 0.30, 0.06, 0.035, 32), "depth": 0.03, "mats": ("trim", "trim"), "mirror": True,
         "elements": [("projector", (0.70, 0.30), 0.028, "proj")]},
    ],
    "recesses": [
        {"plane": "front", "outline": [(-0.40, 0.555), (0.40, 0.555), (0.36, 0.60), (-0.36, 0.60)], "radii": [0.015] * 4,
         "depth": 0.05, "mats": ("grille", "trim")},
        {"plane": "front", "outline": [(-0.58, 0.20), (0.58, 0.20), (0.52, 0.42), (-0.52, 0.42)], "radii": [0.06, 0.06, 0.06, 0.06],
         "depth": 0.10, "mats": ("grille", "trim")},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.45, 0.90), (1.42, 0.6), (1.47, 0.27), (2.98, 0.28), (3.02, 0.6), (2.96, 0.97)]},
        {"plane": "top", "line": [(-0.70, 1.26), (-0.72, 0.6), (-0.58, 0.18), (0.58, 0.18), (0.72, 0.6), (0.70, 1.26)], "mirror": False},
        {"plane": "rear", "line": [(-0.78, 1.0), (-0.70, 0.80), (0.70, 0.80), (0.78, 1.0)], "mirror": False},
        {"plane": "side", "line": circle(3.78, 0.84, 0.06, 24), "closed": True, "mirror": False},
    ],
    "splitter": {"d1": 0.45, "reach": 0.03, "y": 0.14, "t": 0.016},
    "solids": [
        # the spoiler across the hatch's foot, between the lamps
        {"outline": [(4.12, 1.035), (4.44, 1.015), (4.47, 1.05), (4.18, 1.065)], "radii": [0.01, 0.01, 0.01, 0.03], "axis": "x",
         "a0": -0.66, "a1": 0.66, "mat": "paint"},
    ],
    "handles": [(2.85, 0.83)],
    "mirrors": [{"base": (0.78, 1.50, 0.895), "size": (0.16, 0.10, 0.12), "reach": 0.04}],
    "exhausts": [{"at": (0.60, 0.26, L - 0.08), "r": (0.052, 0.036), "length": 0.14, "mirror": True}],
    "paint": [
        # side markers, rear reflectors
        {"plane": "side", "outline": rect(0.50, 0.535, 0.62, 0.56), "radii": [0.01] * 4, "mat": "amber", "mirror": True},
        {"plane": "rear", "outline": rect(0.56, 0.40, 0.76, 0.43), "radii": [0.012] * 4, "mat": "lens_red", "mirror": True},
        # the blacked-out B-pillar
        {"plane": "side", "outline": [(2.86, 0.965), (2.95, 0.97), (2.95, 1.30), (2.86, 1.30)], "radii": [0.005] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
    ],
    "wipers": {"d": 1.36, "x": [0.44, -0.08], "len": 0.5, "dir": -1},
}
