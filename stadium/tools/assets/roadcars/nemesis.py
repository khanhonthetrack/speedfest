"""Nemesis GT: a widened, lowered German-style sports coupe on its homologation kit: a hood with a
power dome and two vents, twin round lamps with halo rings under each headlight's glass, a pair of
grilles over a full-width mouth and splitter, flared arches, a gill behind each front wheel, a
wing on two struts and quad pipes (our own; the class of car NFS Most Wanted's hero drove)."""
from roadcars._util import circle, ellipse, rect

L = 4.49
SPEC = {
    "id": "nemesis", "name": "Nemesis GT",
    "length": L, "wheelbase": 2.73, "front_overhang": 0.80, "track": (1.54, 1.56),
    # fitted to a drawing (blueprint_fit.py): the windscreen's foot at 1.27, the backlight's at 3.95
    "fit": {"cowl": 1.27, "deck": 3.95},
    "tyre": {"r": (0.321, 0.327), "w": (0.265, 0.285), "rim_r": 0.2413, "rim": "mesh", "spokes": 10, "dish": 0.03},
    "body": {
        "floor": 0.13,
        "curves": {
            "top": [(0.0, 0.66), (0.15, 0.71), (0.5, 0.78), (0.9, 0.835), (1.28, 0.875), (2.0, 0.90), (3.2, 0.95), (3.62, 0.99),
                    (4.0, 1.0), (4.35, 0.99), (L, 0.96)],
            "edge_x": [(0.0, 0.55), (0.3, 0.62), (0.9, 0.65), (1.28, 0.68), (1.6, 0.76), (3.3, 0.77), (3.8, 0.75), (4.3, 0.72), (L, 0.66)],
            "edge_y": [(0.0, 0.63), (0.15, 0.68), (0.5, 0.75), (0.9, 0.80), (1.28, 0.845), (1.6, 0.875), (3.0, 0.915), (3.62, 0.965),
                       (4.0, 0.975), (4.35, 0.965), (L, 0.935)],
            "sh_x": [(0.0, 0.70), (0.3, 0.82), (0.8, 0.875), (1.3, 0.86), (2.4, 0.855), (3.3, 0.875), (3.9, 0.86), (4.3, 0.83), (L, 0.77)],
            "sh_y": [(0.0, 0.60), (0.3, 0.67), (0.8, 0.75), (1.3, 0.82), (2.0, 0.85), (3.0, 0.88), (3.6, 0.91), (4.2, 0.925),
                     (L, 0.91)],
            "side_x": [(0.0, 0.78), (0.3, 0.87), (0.8, 0.92), (1.3, 0.892), (2.0, 0.88), (2.8, 0.89), (3.53, 0.925), (4.0, 0.91),
                       (L, 0.84)],
            "side_y": [(0.0, 0.45), (0.8, 0.55), (2.2, 0.58), (3.5, 0.60), (L, 0.62)],
            "rk_x": [(0.0, 0.74), (0.4, 0.86), (0.8, 0.89), (1.3, 0.86), (2.8, 0.86), (3.5, 0.89), (L, 0.80)],
            "rk_y": [(0.0, 0.22), (1.0, 0.23), (3.4, 0.25), (L, 0.34)],
            "fl_x": [(0.0, 0.62), (0.5, 0.78), (1.0, 0.80), (3.5, 0.80), (L, 0.70)],
            "floor_y": [(0.0, 0.17), (0.4, 0.15), (0.8, 0.135), (3.7, 0.135), (4.1, 0.24), (L, 0.31)],
        },
        "radii": {"edge": 0.04, "sh": 0.05, "side": 0.13, "rk": 0.05, "fl": 0.02},
        "bows": {"edge_sh": 0.006, "sh_side": 0.024, "side_rk": 0.018, "crown_q": 2.4},
        "front": {"yc": 0.42, "plan": (0.40, 3.1), "top": (0.18, 2.9), "bottom": (0.08, 3.1)},
        "rear": {"yc": 0.68, "plan": (0.28, 3.3), "top": (0.06, 3.5), "bottom": (0.18, 2.5)},
    },
    "cabin": {
        "d0": 1.20, "d1": 4.02,
        "curves": {
            "top": [(1.20, 0.86), (4.02, 0.975)],
            "rail_x": [(1.20, 0.63), (1.6, 0.61), (2.1, 0.585), (2.6, 0.59), (3.1, 0.61), (3.5, 0.64), (4.02, 0.69)],
            "base_x": [(1.20, 0.68), (1.5, 0.745), (1.9, 0.765), (3.2, 0.77), (3.6, 0.75), (4.02, 0.71)],
            "crown": 0.045,
        },
        "radii": {"rail": 0.06},
    },
    "arches": {"r": [0.347, 0.353], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.64, 1.33), (0.64, 1.33), (0.52, 1.98), (-0.52, 1.98)], "radii": [0.04, 0.04, 0.07, 0.07]},
        # no B-pillar: the door glass meets the quarter glass at a thin seal
        {"plane": "side", "outline": [(1.56, 0.88), (1.62, 0.97), (2.0, 1.22), (2.45, 1.275), (2.75, 1.265), (2.68, 0.895)],
         "radii": [0.02, 0.05, 0.12, 0.06, 0.02, 0.02], "mirror": True},
        {"plane": "side", "outline": [(2.74, 0.90), (2.80, 1.26), (3.10, 1.235), (3.35, 1.10), (3.45, 0.93)],
         "radii": [0.02, 0.03, 0.1, 0.06, 0.03], "mirror": True},
        {"plane": "top", "outline": [(-0.48, 3.32), (0.48, 3.32), (0.58, 3.90), (-0.58, 3.90)], "radii": [0.06, 0.06, 0.05, 0.05]},
    ],
    "paint": [
        {"plane": "side", "outline": [(2.675, 0.89), (2.745, 0.895), (2.805, 1.27), (2.745, 1.27)], "radii": [0.005] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(1.45, 0.87), (1.56, 0.88), (1.60, 0.96)], "radii": [0.01] * 3,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(1.20, 0.482), (1.33, 0.484), (1.33, 0.50), (1.20, 0.498)], "radii": [0.008] * 4, "mat": "amber",
         "mirror": True},
    ],
    "insets": [
        # headlights: twin round lamps with halo rings under one glass, wrapping round the corner
        {"plane": "front", "ray": (-0.3, -0.2, -1), "outline": [(0.31, 0.555), (0.70, 0.55), (0.75, 0.585), (0.74, 0.64), (0.66, 0.668),
                                                                 (0.38, 0.668), (0.31, 0.63)],
         "radii": [0.03, 0.04, 0.04, 0.04, 0.04, 0.04, 0.03], "depth": 0.05, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("projector", (0.40, 0.61), 0.042, "proj"), ("projector", (0.56, 0.61), 0.044, "proj"),
                      ("ring", (0.40, 0.61), 0.058, 0.05, "led", 0.012), ("ring", (0.56, 0.61), 0.06, 0.052, "led", 0.012),
                      ("strip", [(0.66, 0.575), (0.73, 0.59)], 0.014, "amber")]},
        # fog lamps in the bumper's side intakes
        {"plane": "front", "outline": [(0.39, 0.28), (0.64, 0.28), (0.66, 0.40), (0.41, 0.40)], "radii": [0.03, 0.04, 0.04, 0.03],
         "depth": 0.05, "mats": ("grille", "trim"), "mirror": True,
         "elements": [("ring", (0.58, 0.34), 0.05, 0.038, "chrome"), ("projector", (0.58, 0.34), 0.037, "proj")]},
        # L-shaped tail lamps: the quarter's part and the lid's part
        {"plane": "rear", "ray": (-0.5, 0, 1), "outline": [(0.32, 0.68), (0.70, 0.665), (0.98, 0.64), (0.98, 0.80), (0.70, 0.85),
                                                            (0.60, 0.86), (0.53, 0.795), (0.34, 0.79)],
         "radii": [0.02, 0.04, 0.03, 0.04, 0.03, 0.02, 0.02, 0.02], "depth": 0.035, "mats": ("lamp", "trim"), "cover": "lens_red",
         "mirror": True,
         "elements": [("strip", [(0.36, 0.735), (0.66, 0.735)], 0.03, "light"), ("strip", [(0.60, 0.78), (0.68, 0.80)], 0.026, "light"),
                      ("strip", [(0.40, 0.70), (0.50, 0.70)], 0.014, "lamp")]},
        {"plane": "rear", "outline": rect(-0.27, 0.665, 0.27, 0.84), "radii": [0.03] * 4, "depth": 0.018,
         "mats": ("paint", "paint"), "elements": [("patch", rect(-0.20, 0.69, 0.20, 0.81), [0.01] * 4, "plate", 0.004)]},
    ],
    "recesses": [
        # two upright grilles, wider at their feet, with slats; the central mouth under the bumper's bar
        {"plane": "front", "ray": (0, -0.2, -1), "outline": [(0.02, 0.525), (0.235, 0.525), (0.22, 0.65), (0.17, 0.668), (0.035, 0.66)],
         "radii": [0.03, 0.03, 0.04, 0.03, 0.03], "depth": 0.06, "mats": ("grille", "trim"), "mirror": True,
         "bars": {"y": [0.06, 0.09, 0.12, 0.15, 0.18], "vertical": True, "mat": "chrome", "t": 0.008}},
        {"plane": "front", "outline": [(-0.33, 0.24), (0.33, 0.24), (0.36, 0.41), (-0.36, 0.41)], "radii": [0.05, 0.05, 0.04, 0.04],
         "depth": 0.10, "mats": ("grille", "trim")},
        # vents in the hood, by the windscreen
        {"plane": "top", "outline": [(0.10, 0.95), (0.40, 1.00), (0.40, 1.07), (0.10, 1.02)], "radii": [0.02] * 4, "depth": 0.04,
         "mats": ("grille", "trim"), "mirror": True},
        # a gill behind each front wheel
        {"plane": "side", "outline": [(1.12, 0.635), (1.38, 0.64), (1.40, 0.685), (1.14, 0.69)], "radii": [0.012] * 4, "depth": 0.02,
         "mats": ("grille", "trim"), "mirror": True, "bars": {"y": [0.652, 0.67], "mat": "chrome", "t": 0.004}},
        # the rear diffuser between the pipes
        {"plane": "rear", "outline": [(-0.60, 0.25), (0.60, 0.25), (0.62, 0.36), (-0.62, 0.36)], "radii": [0.03] * 4, "depth": 0.05,
         "mats": ("trim", "trim")},
    ],
    "solids": [
        # side skirts
        {"outline": [(1.15, 0.13), (3.15, 0.13), (3.15, 0.20), (1.15, 0.20)], "axis": "x", "a0": 0.80, "a1": 0.885, "mat": "carbon",
         "radii": [0.01, 0.01, 0.02, 0.02], "mirror": True},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.45, 0.87), (1.42, 0.6), (1.46, 0.26), (2.64, 0.26), (2.68, 0.6), (2.70, 0.895)]},
        {"plane": "top", "line": [(-0.70, 1.22), (-0.70, 0.6), (-0.60, 0.14), (0.60, 0.14), (0.70, 0.6), (0.70, 1.22)], "mirror": False},
        {"plane": "top", "line": [(-0.60, 3.98), (-0.62, 4.40)], "mirror": False},
        {"plane": "top", "line": [(0.60, 3.98), (0.62, 4.40)], "mirror": False},
        {"plane": "rear", "line": [(-0.60, 0.97), (-0.43, 0.64), (0.43, 0.64), (0.60, 0.97)], "mirror": False},
    ],
    "splitter": {"d1": 0.45, "reach": 0.05, "y": 0.11, "t": 0.018},
    "wings": [{"span": 0.80, "chord": 0.26, "d": 4.12, "y": 1.13, "pitch": 0.12, "mat": "carbon",
               "plates": {"outline": [(4.06, 1.06), (4.42, 1.06), (4.42, 1.20), (4.10, 1.20)], "t": 0.01, "radii": [0.01] * 4},
               "uprights": [{"x": 0.42, "outline": [(4.20, 0.96), (4.36, 0.96), (4.34, 1.13), (4.26, 1.14)], "radii": [0, 0, 0.02, 0.02],
                             "mat": "carbon"}]}],
    "handles": [(2.52, 0.79)],
    "mirrors": [{"base": (0.78, 1.66, 0.88), "size": (0.15, 0.09, 0.12), "reach": 0.04}],
    "exhausts": [{"at": (0.25, 0.28, L - 0.06), "r": 0.032, "length": 0.14}, {"at": (0.32, 0.28, L - 0.06), "r": 0.032, "length": 0.14}],
    "wipers": {"d": 1.34, "x": [0.44, -0.08], "len": 0.5, "dir": -1},
}
