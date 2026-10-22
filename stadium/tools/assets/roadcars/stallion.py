"""Stallion GT: a retro American muscle fastback of the mid 2000s: a long hood with a power bulge, a
shark nose leaning forward over a wide mesh grille with round lamps in it, a short roof falling to
a long backlight, a scoop ahead of each rear wheel, three upright tail-lamp bars a side (our own;
the class of car NFS Most Wanted's Blacklist #8 and #1 drove)."""
from roadcars._util import circle, ellipse, rect

L = 4.765
SPEC = {
    "id": "stallion", "name": "Stallion GT",
    "length": L, "wheelbase": 2.72, "front_overhang": 0.93, "track": (1.58, 1.59),
    "tyre": {"r": (0.34, 0.34), "w": (0.245, 0.275), "rim_r": 0.2413, "rim": "five", "spokes": 5, "dish": 0.035},
    "body": {
        "floor": 0.155,
        "curves": {
            "top": [(0.0, 0.80), (0.12, 0.83), (0.5, 0.88), (1.0, 0.935), (1.5, 0.97), (1.80, 0.99), (2.5, 1.02), (3.5, 1.04),
                    (3.85, 1.065), (4.4, 1.075), (L, 1.04)],
            "edge_x": [(0.0, 0.58), (0.3, 0.66), (1.0, 0.70), (1.75, 0.74), (2.1, 0.80), (3.5, 0.81), (4.0, 0.79), (4.5, 0.76), (L, 0.70)],
            "edge_y": [(0.0, 0.78), (0.12, 0.805), (0.5, 0.855), (1.0, 0.905), (1.5, 0.94), (1.8, 0.96), (2.5, 0.99), (3.5, 1.02),
                       (3.85, 1.045), (4.4, 1.055), (L, 1.02)],
            "sh_x": [(0.0, 0.74), (0.3, 0.86), (1.0, 0.90), (1.8, 0.895), (2.6, 0.89), (3.4, 0.90), (4.0, 0.89), (4.5, 0.86), (L, 0.80)],
            "sh_y": [(0.0, 0.74), (0.3, 0.79), (1.0, 0.86), (1.8, 0.92), (2.6, 0.95), (3.4, 0.98), (4.0, 1.0), (4.5, 1.0), (L, 0.98)],
            "side_x": [(0.0, 0.82), (0.3, 0.91), (1.0, 0.935), (1.8, 0.925), (2.6, 0.92), (3.3, 0.935), (3.7, 0.94), (4.3, 0.925),
                       (L, 0.86)],
            "side_y": [(0.0, 0.58), (1.0, 0.70), (2.6, 0.70), (3.6, 0.74), (L, 0.76)],
            "rk_x": [(0.0, 0.76), (0.4, 0.88), (1.0, 0.895), (3.6, 0.905), (L, 0.83)],
            "rk_y": [(0.0, 0.27), (1.0, 0.27), (3.6, 0.29), (L, 0.38)],
            "fl_x": [(0.0, 0.62), (0.5, 0.80), (1.0, 0.82), (3.6, 0.82), (L, 0.72)],
            "floor_y": [(0.0, 0.21), (0.5, 0.18), (0.95, 0.16), (3.9, 0.16), (4.3, 0.27), (L, 0.34)],
        },
        "radii": {"edge": 0.04, "sh": 0.04, "side": 0.13, "rk": 0.05, "fl": 0.02},
        "bows": {"edge_sh": 0.004, "sh_side": 0.024, "side_rk": 0.018, "crown_q": 1.7},
        "front": {"yc": 0.70, "plan": (0.34, 3.5), "top": (0.08, 2.9), "bottom": (0.30, 2.5)},
        "rear": {"yc": 0.80, "plan": (0.22, 3.6), "top": (0.05, 3.5), "bottom": (0.20, 2.5)},
    },
    "cabin": {
        "d0": 1.74, "d1": 3.96,
        "curves": {
            "top": [(1.74, 0.975), (1.9, 1.07), (2.1, 1.20), (2.35, 1.34), (2.55, 1.40), (2.85, 1.415), (3.05, 1.40), (3.3, 1.32),
                    (3.6, 1.20), (3.85, 1.10), (3.96, 1.05)],
            "rail_x": [(1.74, 0.66), (2.1, 0.65), (2.5, 0.62), (3.0, 0.625), (3.4, 0.66), (3.96, 0.72)],
            "base_x": [(1.74, 0.74), (2.05, 0.80), (2.4, 0.815), (3.4, 0.81), (3.8, 0.79), (3.96, 0.76)],
            "crown": 0.045,
        },
        "radii": {"rail": 0.05},
    },
    "arches": {"r": [0.366, 0.366], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.66, 1.80), (0.66, 1.80), (0.57, 2.50), (-0.57, 2.50)], "radii": [0.04, 0.04, 0.06, 0.06]},
        {"plane": "side", "outline": [(1.95, 0.985), (2.45, 1.36), (2.95, 1.39), (3.10, 1.36), (3.10, 1.0)],
         "radii": [0.03, 0.08, 0.05, 0.02, 0.02], "mirror": True},
        {"plane": "side", "outline": [(3.20, 1.01), (3.20, 1.33), (3.50, 1.15), (3.55, 1.03)], "radii": [0.02, 0.03, 0.04, 0.02],
         "mirror": True},
        {"plane": "top", "outline": [(-0.58, 3.12), (0.58, 3.12), (0.68, 3.88), (-0.68, 3.88)], "radii": [0.05, 0.05, 0.04, 0.04]},
    ],
    "paint": [
        {"plane": "side", "outline": [(3.09, 0.99), (3.21, 0.99), (3.21, 1.39), (3.09, 1.39)], "radii": [0.01] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
    ],
    "insets": [
        # headlights at the grille's ends: a projector and a reflector each
        {"plane": "front", "ray": (-0.3, 0, -1), "outline": [(0.56, 0.645), (0.84, 0.66), (0.89, 0.70), (0.87, 0.78), (0.60, 0.775)],
         "radii": [0.03, 0.04, 0.03, 0.03, 0.03], "depth": 0.06, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("projector", (0.66, 0.715), 0.045, "proj"), ("projector", (0.79, 0.72), 0.04, "proj"),
                      ("strip", [(0.62, 0.665), (0.86, 0.675)], 0.012, "amber")]},
        # tail lamps: three upright bars a side in a dark panel
        {"plane": "rear", "ray": (-0.2, 0, 1), "outline": rect(0.40, 0.80, 0.84, 0.98), "radii": [0.02] * 4, "depth": 0.035,
         "mats": ("trim", "trim"), "cover": "lens_red", "mirror": True,
         "elements": [("strip", [(0.48, 0.82), (0.48, 0.96)], 0.07, "light"), ("strip", [(0.62, 0.82), (0.62, 0.96)], 0.07, "light"),
                      ("strip", [(0.76, 0.82), (0.76, 0.96)], 0.07, "light")]},
        {"plane": "rear", "outline": rect(-0.27, 0.80, 0.27, 0.95), "radii": [0.01] * 4, "depth": 0.02,
         "mats": ("trim", "trim"), "elements": [("patch", rect(-0.255, 0.81, 0.255, 0.94), [0.01] * 4, "plate", 0.004)]},
        # round fog lamps inside the grille, at its ends
        {"plane": "front", "outline": circle(0.45, 0.705, 0.05, 32), "depth": 0.03, "mats": ("trim", "trim"), "mirror": True,
         "elements": [("projector", (0.45, 0.705), 0.036, "proj")]},
    ],
    "recesses": [
        # the wide grille under the leaning nose, the lower mouth
        {"plane": "front", "outline": [(-0.52, 0.64), (0.52, 0.64), (0.54, 0.78), (-0.54, 0.78)], "radii": [0.03] * 4, "depth": 0.07,
         "mats": ("grille", "trim")},
        {"plane": "front", "outline": [(-0.60, 0.26), (0.60, 0.26), (0.56, 0.46), (-0.56, 0.46)], "radii": [0.05] * 4, "depth": 0.10,
         "mats": ("grille", "trim")},
        # the side scoops ahead of the rear wheels, with slats
        {"plane": "side", "outline": [(2.95, 0.52), (3.22, 0.54), (3.30, 0.62), (3.28, 0.76), (2.95, 0.78)],
         "radii": [0.02, 0.03, 0.04, 0.03, 0.02], "depth": 0.04, "mats": ("inlet", "trim"), "mirror": True,
         "bars": {"y": [0.585, 0.64, 0.695], "mat": "paint", "t": 0.02, "at": 0.4}},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.92, 0.99), (1.90, 0.6), (1.95, 0.29), (3.12, 0.30), (3.16, 0.7), (3.14, 1.0)]},
        {"plane": "top", "line": [(-0.72, 1.72), (-0.76, 0.8), (-0.62, 0.12), (0.62, 0.12), (0.76, 0.8), (0.72, 1.72)], "mirror": False},
        {"plane": "top", "line": [(-0.72, 3.92), (-0.76, 4.62), (0.76, 4.62), (0.72, 3.92)], "mirror": False},
    ],
    "splitter": {"d1": 0.5, "reach": 0.03, "y": 0.16, "t": 0.016, "mat": "trim"},
    "wings": [{"span": 0.78, "chord": 0.20, "d": 4.42, "y": 1.16, "pitch": 0.08,
               "uprights": [{"x": 0.62, "outline": [(4.40, 1.06), (4.62, 1.06), (4.58, 1.15), (4.46, 1.16)], "radii": [0, 0, 0.03, 0.03]}]}],
    "handles": [(2.9, 0.89)],
    "mirrors": [{"base": (0.82, 2.0, 0.99), "size": (0.17, 0.11, 0.13), "reach": 0.04}],
    "exhausts": [{"at": (0.62, 0.28, L - 0.07), "r": 0.048, "length": 0.15}],
    "wipers": {"d": 1.83, "x": [0.46, -0.08], "len": 0.54, "dir": -1},
}
