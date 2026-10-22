"""Kaiten R: a four-seat rotary sports coupe with rear-hinged back doors: front fenders bulging up
over a short hood, triangular headlights, a five-sided mouth, a long arching roof and round lamps
under clear tail-lamp glass (our own; the class of car NFS Most Wanted's Blacklist #12 drove)."""
from roadcars._util import circle, ellipse, rect

L = 4.43
SPEC = {
    "id": "kaiten", "name": "Kaiten R",
    "length": L, "wheelbase": 2.70, "front_overhang": 0.835, "track": (1.50, 1.505),
    # fitted to a drawing (blueprint_fit.py): the windscreen's foot at 1.38, the backlight's at 3.98,
    # the wing over 4.0-4.32; the silhouette's top ahead of the cowl is the raised fenders', the
    # hood lies lower between them
    "fit": {"cowl": 1.38, "deck": 3.98, "wing": [4.0, 4.32], "top_add": (-0.045, -0.004), "edge_add": (-0.006, -0.016),
            "hood_add": (-0.05, -0.008)},
    "tyre": {"r": (0.3305, 0.3305), "w": (0.225, 0.225), "rim_r": 0.2286, "rim": "split", "spokes": 5, "dish": 0.03},
    "body": {
        "floor": 0.14,
        "curves": {
            "top": [(0.0, 0.63), (0.15, 0.68), (0.5, 0.74), (0.9, 0.79), (1.3, 0.85), (2.0, 0.90), (3.3, 0.94), (3.75, 0.99),
                    (4.1, 1.0), (L, 0.97)],
            "hood_x": [(0.0, 0.40), (0.3, 0.45), (0.9, 0.48), (1.3, 0.55), (1.6, 0.66), (3.3, 0.68), (3.8, 0.66), (L, 0.60)],
            "hood_y": [(0.0, 0.62), (0.15, 0.67), (0.5, 0.73), (0.9, 0.78), (1.3, 0.84), (1.6, 0.88), (3.3, 0.93), (3.75, 0.98),
                       (4.1, 0.99), (L, 0.96)],
            "edge_x": [(0.0, 0.60), (0.3, 0.68), (0.85, 0.72), (1.3, 0.72), (1.6, 0.76), (3.3, 0.78), (3.8, 0.76), (L, 0.68)],
            "edge_y": [(0.0, 0.64), (0.15, 0.71), (0.5, 0.79), (0.85, 0.82), (1.3, 0.85), (1.6, 0.88), (3.3, 0.925), (3.75, 0.975),
                       (4.1, 0.985), (L, 0.955)],
            "sh_x": [(0.0, 0.68), (0.3, 0.80), (0.85, 0.855), (1.4, 0.85), (2.4, 0.845), (3.3, 0.86), (3.9, 0.85), (L, 0.77)],
            "sh_y": [(0.0, 0.60), (0.3, 0.69), (0.85, 0.77), (1.4, 0.83), (2.2, 0.86), (3.0, 0.90), (3.6, 0.93), (4.1, 0.94),
                     (L, 0.92)],
            "side_x": [(0.0, 0.76), (0.3, 0.84), (0.85, 0.885), (1.4, 0.87), (2.3, 0.862), (3.1, 0.875), (3.55, 0.885), (4.0, 0.865),
                       (L, 0.80)],
            "side_y": [(0.0, 0.48), (0.85, 0.58), (2.2, 0.60), (3.5, 0.64), (L, 0.66)],
            "rk_x": [(0.0, 0.72), (0.4, 0.82), (1.0, 0.835), (3.5, 0.845), (L, 0.77)],
            "rk_y": [(0.0, 0.25), (1.0, 0.25), (3.4, 0.27), (L, 0.36)],
            "fl_x": [(0.0, 0.60), (0.5, 0.76), (1.0, 0.78), (3.5, 0.78), (L, 0.68)],
            "floor_y": [(0.0, 0.20), (0.45, 0.165), (0.8, 0.145), (3.6, 0.145), (4.0, 0.25), (L, 0.32)],
        },
        "radii": {"hood": 0.05, "edge": 0.05, "sh": 0.05, "side": 0.13, "rk": 0.06, "fl": 0.02},
        "bows": {"hood_edge": -0.006, "edge_sh": 0.008, "sh_side": 0.024, "side_rk": 0.018},
        "front": {"yc": 0.44, "plan": (0.40, 2.9), "top": (0.16, 2.9), "bottom": (0.12, 2.9)},
        "rear": {"yc": 0.70, "plan": (0.26, 3.3), "top": (0.06, 3.5), "bottom": (0.16, 2.5)},
    },
    "cabin": {
        "d0": 1.30, "d1": 4.05,
        "curves": {
            "top": [(1.30, 0.90), (4.05, 1.03)],
            "rail_x": [(1.30, 0.62), (1.7, 0.60), (2.2, 0.58), (2.8, 0.585), (3.3, 0.61), (4.05, 0.69)],
            "base_x": [(1.30, 0.67), (1.55, 0.73), (1.9, 0.755), (3.3, 0.76), (3.75, 0.74), (4.05, 0.70)],
            "crown": 0.045,
        },
        "radii": {"rail": 0.06},
    },
    "arches": {"r": [0.357, 0.357], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.66, 1.45), (0.66, 1.45), (0.50, 2.03), (-0.50, 2.03)], "radii": [0.04, 0.04, 0.08, 0.08]},
        # the front doors' glass, the rear-hinged doors' behind it, no pillar between
        {"plane": "side", "outline": [(1.62, 0.91), (1.70, 1.0), (2.1, 1.22), (2.62, 1.285), (2.63, 0.955)],
         "radii": [0.02, 0.05, 0.12, 0.03, 0.02], "mirror": True},
        {"plane": "side", "outline": [(2.70, 0.96), (2.72, 1.26), (3.02, 1.24), (3.12, 1.14), (3.14, 0.975)],
         "radii": [0.02, 0.02, 0.06, 0.06, 0.02], "mirror": True},
        {"plane": "top", "outline": [(-0.50, 3.25), (0.50, 3.25), (0.62, 3.92), (-0.62, 3.92)], "radii": [0.06, 0.06, 0.05, 0.05]},
    ],
    "paint": [
        {"plane": "side", "outline": [(2.625, 0.955), (2.70, 0.96), (2.72, 1.29), (2.64, 1.295)], "radii": [0.005] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(1.50, 0.90), (1.62, 0.91), (1.66, 0.99)], "radii": [0.01] * 3,
         "mat": "gloss_black", "mirror": True, "cabin": True},
    ],
    "insets": [
        # swept headlights on the fenders' fronts, a projector in each
        {"plane": "front", "ray": (-0.35, -0.3, -1), "outline": [(0.45, 0.60), (0.60, 0.605), (0.78, 0.62), (0.82, 0.66), (0.81, 0.745),
                                                                   (0.72, 0.755), (0.55, 0.69)],
         "radii": [0.02, 0.04, 0.04, 0.03, 0.04, 0.05, 0.04], "depth": 0.05, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("ring", (0.627, 0.667), 0.058, 0.046, "chrome"), ("projector", (0.627, 0.667), 0.045, "proj"),
                      ("strip", [(0.50, 0.615), (0.70, 0.627)], 0.012, "amber")]},
        # clear tail lamps with two round lamps each
        {"plane": "rear", "ray": (-0.45, 0, 1), "outline": [(0.40, 0.77), (0.72, 0.775), (0.75, 0.82), (0.73, 0.89), (0.66, 0.905),
                                                             (0.43, 0.90), (0.40, 0.86)],
         "radii": [0.02, 0.04, 0.03, 0.04, 0.03, 0.02, 0.02], "depth": 0.04, "mats": ("lamp", "trim"), "cover": "lens", "mirror": True,
         "elements": [("ring", (0.505, 0.835), 0.058, 0.04, "light"), ("ring", (0.62, 0.835), 0.058, 0.04, "light"),
                      ("disc", (0.505, 0.835), 0.02, "light"), ("disc", (0.62, 0.835), 0.02, "light")]},
        {"plane": "rear", "outline": rect(-0.35, 0.48, 0.35, 0.67), "radii": [0.04] * 4, "depth": 0.02,
         "mats": ("paint", "paint"), "elements": [("patch", rect(-0.175, 0.50, 0.175, 0.645), [0.01] * 4, "plate", 0.004)]},
    ],
    "recesses": [
        # the five-sided mouth, its flanking intakes with slats
        {"plane": "front", "outline": [(-0.45, 0.555), (0.45, 0.555), (0.38, 0.43), (0.18, 0.33), (0.0, 0.305), (-0.18, 0.33),
                                       (-0.38, 0.43)],
         "radii": [0.03, 0.03, 0.06, 0.08, 0.1, 0.08, 0.06], "depth": 0.10, "mats": ("grille", "trim")},
        {"plane": "front", "outline": [(0.55, 0.36), (0.80, 0.33), (0.81, 0.54), (0.58, 0.53)], "radii": [0.03, 0.04, 0.04, 0.03],
         "depth": 0.07, "mats": ("grille", "trim"), "mirror": True, "bars": {"y": [0.42, 0.48], "mat": "trim", "t": 0.012}},
        # a vent behind each front wheel
        {"plane": "side", "outline": [(1.22, 0.64), (1.38, 0.64), (1.40, 0.68), (1.25, 0.70)], "radii": [0.015] * 4, "depth": 0.02,
         "mats": ("grille", "trim"), "mirror": True},
        # the rear's dark lower band and the pockets round the pipes
        {"plane": "rear", "outline": rect(-0.74, 0.235, 0.74, 0.30), "radii": [0.02] * 4, "depth": 0.04, "mats": ("trim", "trim")},
        {"plane": "rear", "outline": [(0.52, 0.26), (0.76, 0.26), (0.76, 0.39), (0.54, 0.39)], "radii": [0.04] * 4, "depth": 0.05,
         "mats": ("trim", "trim"), "mirror": True},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.47, 0.90), (1.45, 0.6), (1.48, 0.30), (2.63, 0.30), (2.63, 0.955)]},
        {"plane": "side", "line": [(2.66, 0.30), (3.0, 0.30), (3.08, 0.5), (3.12, 0.7), (3.15, 0.96)]},
        {"plane": "top", "line": [(-0.66, 1.33), (-0.62, 0.6), (-0.52, 0.15), (0.52, 0.15), (0.62, 0.6), (0.66, 1.33)], "mirror": False},
        {"plane": "top", "line": [(-0.62, 4.00), (-0.64, 4.36)], "mirror": False},
        {"plane": "top", "line": [(0.62, 4.00), (0.64, 4.36)], "mirror": False},
        {"plane": "rear", "line": [(-0.40, 0.92), (-0.40, 0.75), (0.40, 0.75), (0.40, 0.92)], "mirror": False},
        {"plane": "side", "line": circle(3.52, 0.91, 0.07, 24), "closed": True, "mirror": False},
    ],
    "splitter": {"d1": 0.42, "reach": 0.03, "y": 0.20, "t": 0.016, "mat": "trim"},
    "wings": [{"span": 0.72, "chord": 0.24, "d": 4.04, "y": 1.07, "pitch": 0.10,
               "uprights": [{"x": 0.60, "outline": [(4.08, 0.98), (4.24, 0.98), (4.22, 1.07), (4.12, 1.08)], "radii": [0, 0, 0.03, 0.03]}]}],
    "handles": [(2.40, 0.78)],
    "mirrors": [{"base": (0.77, 1.60, 0.90), "size": (0.16, 0.10, 0.12), "reach": 0.04}],
    "exhausts": [{"at": (0.62, 0.31, L - 0.07), "r": 0.045, "length": 0.14}],
    "wipers": {"d": 1.47, "x": [0.44, -0.08], "len": 0.5, "dir": -1},
}
