"""Corrida V10: an Italian mid-engined V10 wedge: one line from the nose up the windscreen, angular
lamps, three black intakes in the nose, a short cab-forward roof falling over a glass engine
cover, big intakes ahead of the rear wheels, a mesh tail between slim lamps (our own; the class
of car NFS Most Wanted's Blacklist #6 drove)."""
from roadcars._util import circle, ellipse, rect

L = 4.30
SPEC = {
    "id": "corrida", "name": "Corrida V10",
    "length": L, "wheelbase": 2.56, "front_overhang": 0.98, "track": (1.622, 1.592),
    # fitted to a drawing (blueprint_fit.py): the windscreen's foot at 0.85, the roof's glass ending
    # at 3.10 over the engine cover's long slope
    "fit": {"cowl": 0.85, "deck": 3.10},
    "tyre": {"r": (0.3237, 0.330), "w": (0.235, 0.295), "rim_r": 0.2413, "rim": "five", "spokes": 5, "dish": 0.03},
    "body": {
        "floor": 0.12,
        "curves": {
            "top": [(0.0, 0.52), (0.15, 0.56), (0.5, 0.635), (0.98, 0.72), (1.10, 0.75), (2.0, 0.84), (3.0, 0.86), (3.6, 0.90),
                    (4.05, 0.95), (L, 0.92)],
            "edge_x": [(0.0, 0.56), (0.3, 0.68), (0.98, 0.74), (1.2, 0.76), (1.6, 0.78), (2.6, 0.78), (3.2, 0.82), (3.8, 0.80), (L, 0.72)],
            "edge_y": [(0.0, 0.53), (0.15, 0.575), (0.5, 0.65), (0.98, 0.735), (1.2, 0.77), (1.6, 0.80), (2.6, 0.82), (3.2, 0.86),
                       (3.6, 0.89), (4.05, 0.935), (L, 0.905)],
            "sh_x": [(0.0, 0.68), (0.3, 0.84), (0.98, 0.93), (1.5, 0.90), (2.4, 0.885), (3.0, 0.93), (3.54, 0.95), (4.0, 0.93), (L, 0.84)],
            "sh_y": [(0.0, 0.50), (0.3, 0.56), (0.98, 0.66), (1.5, 0.72), (2.4, 0.77), (3.0, 0.81), (3.54, 0.84), (4.0, 0.88), (L, 0.86)],
            "side_x": [(0.0, 0.76), (0.3, 0.88), (0.98, 0.95), (1.5, 0.925), (2.4, 0.905), (3.0, 0.935), (3.54, 0.95), (4.0, 0.935),
                       (L, 0.86)],
            "side_y": [(0.0, 0.40), (0.98, 0.46), (2.4, 0.50), (3.5, 0.55), (L, 0.58)],
            "rk_x": [(0.0, 0.72), (0.4, 0.86), (1.0, 0.89), (2.4, 0.87), (3.5, 0.90), (L, 0.82)],
            "rk_y": [(0.0, 0.20), (1.0, 0.21), (3.4, 0.23), (L, 0.30)],
            "fl_x": [(0.0, 0.62), (0.5, 0.80), (1.0, 0.84), (3.5, 0.84), (L, 0.74)],
            "floor_y": [(0.0, 0.16), (0.5, 0.135), (0.95, 0.125), (3.6, 0.125), (3.95, 0.21), (L, 0.28)],
        },
        "radii": {"edge": 0.025, "sh": 0.025, "side": 0.12, "rk": 0.03, "fl": 0.02},
        "bows": {"edge_sh": 0, "sh_side": 0.024, "side_rk": 0.018, "crown_q": 2.6},
        "front": {"yc": 0.36, "plan": (0.40, 3.5), "top": (0.14, 3.1), "bottom": (0.08, 3.1)},
        "rear": {"yc": 0.62, "plan": (0.22, 3.6), "top": (0.04, 3.5), "bottom": (0.12, 2.9)},
    },
    "cabin": {
        "d0": 0.80, "d1": 3.30,
        "curves": {
            "top": [(0.80, 0.78), (3.30, 1.01)],
            "rail_x": [(0.80, 0.68), (1.5, 0.64), (2.0, 0.58), (2.6, 0.58), (3.0, 0.60), (3.30, 0.64)],
            "base_x": [(0.80, 0.74), (1.2, 0.78), (1.8, 0.79), (2.6, 0.79), (3.0, 0.78), (3.30, 0.75)],
            "crown": 0.04,
        },
        "radii": {"rail": 0.04},
    },
    "arches": {"r": [0.350, 0.356], "lift": 0.007, "shapes": {}},
    "glass": [
        {"plane": "top", "outline": [(-0.70, 0.92), (0.70, 0.92), (0.56, 1.70), (-0.56, 1.70)], "radii": [0.03, 0.03, 0.06, 0.06]},
        {"plane": "side", "outline": [(1.55, 0.83), (1.62, 0.92), (1.75, 1.08), (2.40, 1.115), (2.47, 0.875)],
         "radii": [0.02, 0.05, 0.08, 0.02, 0.02], "mirror": True},
        # the small backlight at the roof's end, and the glass over the engine
        {"plane": "top", "outline": [(-0.47, 2.55), (0.47, 2.55), (0.50, 2.78), (-0.50, 2.78)], "radii": [0.03] * 4},
        {"plane": "top", "outline": [(-0.50, 3.05), (0.50, 3.05), (0.54, 3.62), (-0.54, 3.62)], "radii": [0.04] * 4},
    ],
    "paint": [
        # the black C-pillar behind the side glass
        {"plane": "side", "outline": [(2.45, 0.87), (2.53, 0.875), (2.50, 1.11), (2.42, 1.115)], "radii": [0.005] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": rect(0.53, 0.55, 0.63, 0.57), "radii": [0.008] * 4, "mat": "amber", "mirror": True},
    ],
    "insets": [
        # angular headlights at the corners, two round lamps in each
        {"plane": "front", "ray": (-0.3, -0.15, -1), "outline": [(0.56, 0.52), (0.80, 0.53), (0.86, 0.58), (0.82, 0.78), (0.76, 0.80)],
         "radii": [0.02, 0.02, 0.02, 0.02, 0.02], "depth": 0.045, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("ring", (0.715, 0.617), 0.052, 0.04, "chrome"), ("projector", (0.715, 0.617), 0.038, "proj"),
                      ("ring", (0.75, 0.695), 0.035, 0.027, "chrome"), ("projector", (0.75, 0.695), 0.025, "proj"),
                      ("strip", [(0.60, 0.545), (0.68, 0.555)], 0.012, "led")]},
        # tall dark tail lamps either side of the engine's grille
        {"plane": "rear", "ray": (-0.45, 0, 1), "outline": [(0.48, 0.595), (0.74, 0.59), (0.76, 0.85), (0.72, 0.89), (0.50, 0.905),
                                                             (0.47, 0.87)],
         "radii": [0.02, 0.02, 0.03, 0.03, 0.02, 0.02], "depth": 0.035, "mats": ("lamp", "trim"), "cover": "lens_red", "mirror": True,
         "elements": [("strip", [(0.52, 0.80), (0.71, 0.80)], 0.05, "light"), ("strip", [(0.52, 0.66), (0.71, 0.66)], 0.04, "light")]},
        {"plane": "rear", "outline": rect(-0.25, 0.37, 0.25, 0.47), "radii": [0.02] * 4, "depth": 0.015,
         "mats": ("trim", "trim"), "elements": [("patch", rect(-0.20, 0.38, 0.20, 0.46), [0.01] * 4, "plate", 0.004)]},
        # the pipes' pockets in the bumper
        {"plane": "rear", "outline": [(0.48, 0.35), (0.70, 0.35), (0.72, 0.48), (0.50, 0.48)], "radii": [0.03] * 4, "depth": 0.05,
         "mats": ("trim", "trim"), "mirror": True},
    ],
    "recesses": [
        # three black intakes in the nose
        {"plane": "front", "outline": [(-0.34, 0.225), (0.34, 0.225), (0.34, 0.35), (-0.34, 0.35)], "radii": [0.02] * 4, "depth": 0.10,
         "mats": ("grille", "trim")},
        {"plane": "front", "ray": (-0.3, 0, -1), "outline": [(0.38, 0.20), (0.76, 0.21), (0.79, 0.41), (0.40, 0.40)],
         "radii": [0.02, 0.03, 0.03, 0.02], "depth": 0.12, "mats": ("grille", "trim"), "mirror": True},
        # the big slanted intake ahead of each rear wheel, the one high on the flank behind the glass
        {"plane": "side", "outline": [(2.40, 0.24), (2.80, 0.30), (3.08, 0.72), (2.66, 0.69)], "radii": [0.02, 0.03, 0.03, 0.03],
         "depth": 0.10, "mats": ("grille", "trim"), "mirror": True},
        {"plane": "side", "outline": [(2.58, 0.88), (2.90, 0.90), (2.92, 0.97), (2.62, 0.98)], "radii": [0.015] * 4, "depth": 0.05,
         "mats": ("grille", "trim"), "mirror": True},
        # louvres on the engine cover's flanks
        {"plane": "side", "outline": [(3.67, 0.86), (3.98, 0.875), (3.98, 0.905), (3.67, 0.92)], "radii": [0.01] * 4, "depth": 0.03,
         "mats": ("grille", "trim"), "mirror": True, "bars": {"y": [3.73, 3.79, 3.85, 3.91], "vertical": True, "mat": "paint", "t": 0.012}},
        # the engine's mesh grille between the lamps, the diffuser below
        {"plane": "rear", "outline": [(-0.38, 0.59), (0.38, 0.59), (0.38, 0.77), (-0.38, 0.77)], "radii": [0.03] * 4, "depth": 0.10,
         "mats": ("grille", "trim")},
        {"plane": "rear", "outline": [(-0.63, 0.20), (0.63, 0.20), (0.64, 0.31), (-0.64, 0.31)], "radii": [0.03] * 4, "depth": 0.06,
         "mats": ("grille", "trim"), "bars": {"y": [-0.30, 0.0, 0.30], "vertical": True, "mat": "trim", "t": 0.012}},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.40, 0.82), (1.37, 0.55), (1.42, 0.24), (2.40, 0.24)]},
        {"plane": "top", "line": [(-0.70, 0.80), (-0.72, 0.5), (-0.56, 0.10), (0.56, 0.10), (0.72, 0.5), (0.70, 0.80)], "mirror": False},
    ],
    "splitter": {"d1": 0.5, "reach": 0.04, "y": 0.12, "t": 0.016, "mat": "carbon"},
    "mirrors": [{"base": (0.80, 1.55, 0.84), "size": (0.15, 0.085, 0.12), "reach": 0.06}],
    "exhausts": [{"at": (0.565, 0.42, L - 0.07), "r": 0.045, "length": 0.14}],
    "wipers": {"d": 0.96, "x": [0.36, -0.10], "len": 0.52, "dir": -1},
}
