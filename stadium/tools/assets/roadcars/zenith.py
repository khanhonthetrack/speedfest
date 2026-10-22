"""Zenith TT: a long-nosed, bubble-roofed twin-turbo grand tourer of the 1990s with a hoop wing
and four round tail lamps (our own; the class of car NFS Most Wanted's Blacklist #13 drove)."""

from roadcars._util import circle, ellipse, rect

L = 4.52
SPEC = {
    "id": "zenith", "name": "Zenith TT",
    "length": L, "wheelbase": 2.55, "front_overhang": 1.04, "track": (1.52, 1.525),
    # the hood's, glasshouse's and deck's lines and the plan measured on a blueprint drawing
    # (blueprint_fit.py curves -> roadcars/profiles/zenith.json): the windscreen's foot at 1.55, the
    # backlight's at 3.95, the wing over 3.97-4.42
    "fit": {"cowl": 1.55, "deck": 3.95, "wing": [3.97, 4.42]},
    "tyre": {"r": (0.327, 0.327), "w": (0.245, 0.275), "rim_r": 0.2415, "rim": "five", "spokes": 5, "dish": 0.03},
    "body": {
        "floor": 0.13,
        "curves": {
            "top": [(0.0, 0.59), (0.2, 0.665), (0.5, 0.73), (1.0, 0.80), (1.5, 0.855), (1.7, 0.875), (2.5, 0.89),
                    (3.0, 0.92), (3.55, 0.965), (3.9, 0.985), (4.3, 0.985), (L, 0.965)],
            "edge_x": [(0.0, 0.50), (0.3, 0.60), (0.8, 0.65), (1.3, 0.66), (1.6, 0.68), (2.5, 0.72), (3.5, 0.72), (4.0, 0.70), (L, 0.64)],
            "edge_y": [(0.0, 0.60), (0.3, 0.685), (0.8, 0.77), (1.3, 0.825), (1.6, 0.86), (2.5, 0.885), (3.5, 0.955),
                       (4.0, 0.975), (L, 0.955)],
            "sh_x": [(0.0, 0.60), (0.3, 0.74), (0.7, 0.82), (1.0, 0.845), (1.5, 0.84), (2.2, 0.83), (3.0, 0.86), (3.4, 0.875),
                     (3.9, 0.86), (4.3, 0.82), (L, 0.75)],
            "sh_y": [(0.0, 0.56), (0.3, 0.64), (0.7, 0.72), (1.0, 0.755), (1.5, 0.80), (2.2, 0.84), (3.0, 0.88), (3.4, 0.91),
                     (3.9, 0.93), (4.3, 0.93), (L, 0.91)],
            "side_x": [(0.0, 0.70), (0.3, 0.82), (0.7, 0.875), (1.0, 0.885), (1.4, 0.875), (2.0, 0.87), (2.7, 0.885),
                       (3.3, 0.905), (3.8, 0.895), (4.2, 0.865), (L, 0.80)],
            "side_y": [(0.0, 0.40), (1.0, 0.52), (2.0, 0.50), (3.3, 0.56), (L, 0.56)],
            "rk_x": [(0.0, 0.66), (0.4, 0.80), (1.0, 0.85), (2.0, 0.85), (3.3, 0.87), (4.0, 0.84), (L, 0.76)],
            "rk_y": [(0.0, 0.24), (1.0, 0.22), (2.0, 0.215), (3.3, 0.24), (L, 0.32)],
            "fl_x": [(0.0, 0.55), (0.5, 0.72), (1.0, 0.80), (2.0, 0.80), (3.3, 0.80), (L, 0.66)],
            "floor_y": [(0.0, 0.19), (0.5, 0.16), (0.9, 0.13), (3.6, 0.13), (4.1, 0.19), (L, 0.28)],
        },
        "radii": {"edge": 0.03, "sh": 0.04, "side": 0.10, "rk": 0.04, "fl": 0.02},
        "bows": {"edge_sh": 0.012, "sh_side": 0.03, "side_rk": 0.022},
        "front": {"yc": 0.43, "plan": (0.45, 3.0), "top": (0.16, 3.2), "bottom": (0.10, 3.2)},
        "rear": {"yc": 0.62, "plan": (0.22, 3.6), "top": (0.06, 3.6), "bottom": (0.12, 3.0)},
    },
    "cabin": {
        "d0": 1.47, "d1": 4.03,
        "curves": {
            "top": [(1.47, 0.86), (4.03, 0.97)],
            "rail_x": [(1.47, 0.62), (1.8, 0.60), (2.2, 0.55), (2.6, 0.54), (3.0, 0.56), (3.4, 0.60), (3.8, 0.64), (4.03, 0.66)],
            "base_x": [(1.47, 0.68), (1.75, 0.74), (2.1, 0.77), (3.0, 0.78), (3.5, 0.76), (3.85, 0.72), (4.03, 0.69)],
            "crown": 0.05,
        },
        "radii": {"rail": 0.06},
    },
    "arches": {"r": 0.352, "lift": 0.006},
    "glass": [
        {"plane": "top", "outline": [(-0.64, 1.62), (0.64, 1.62), (0.51, 2.22), (-0.51, 2.22)], "radii": [0.04, 0.04, 0.07, 0.07]},
        {"plane": "side", "outline": [(2.02, 0.875), (2.30, 1.14), (2.60, 1.19), (2.95, 1.17), (3.15, 1.07), (3.22, 0.95), (3.10, 0.88)],
         "radii": [0.02, 0.1, 0.12, 0.1, 0.08, 0.05, 0.03], "mirror": True},
        # the bubble backlight, wrapping down to the deck
        {"plane": "top", "outline": [(-0.52, 3.0), (0.52, 3.0), (0.63, 3.88), (-0.63, 3.88)], "radii": [0.08, 0.08, 0.06, 0.06]},
    ],
    "paint": [
        # the quarter glass's thin frame
        {"plane": "side", "outline": [(2.82, 0.86), (2.86, 0.86), (2.86, 1.21), (2.82, 1.21)], "radii": [0.005] * 4, "mat": "gloss_black",
         "mirror": True, "cabin": True},
        # side markers on the front fenders
        {"plane": "side", "outline": [(1.44, 0.655), (1.52, 0.655), (1.52, 0.685), (1.44, 0.685)], "radii": [0.01] * 4, "mat": "amber",
         "mirror": True},
    ],
    "insets": [
        # headlights on the sloping nose: two round lamps under one glass, the indicator outboard
        {"plane": "front", "ray": (0, -0.35, -1), "outline": [(0.33, 0.635), (0.62, 0.62), (0.72, 0.655), (0.72, 0.715), (0.62, 0.755),
                                                                (0.35, 0.735)],
         "radii": [0.03, 0.04, 0.03, 0.03, 0.04, 0.03], "depth": 0.05, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("projector", (0.42, 0.68), 0.042, "proj"), ("projector", (0.54, 0.68), 0.042, "proj"),
                      ("strip", [(0.63, 0.66), (0.70, 0.675)], 0.02, "amber")]},
        # the tail clusters: three round lamps each in a smoked housing
        {"plane": "rear", "outline": [(0.20, 0.77), (0.62, 0.77), (0.69, 0.80), (0.68, 0.86), (0.22, 0.86)],
         "radii": [0.03, 0.04, 0.03, 0.03, 0.03], "depth": 0.04, "mats": ("trim", "trim"), "cover": "lens_red", "mirror": True,
         "elements": [("ring", (0.30, 0.815), 0.042, 0.026, "light"), ("ring", (0.42, 0.815), 0.042, 0.026, "light"),
                      ("ring", (0.54, 0.815), 0.042, 0.026, "light"), ("disc", (0.42, 0.815), 0.02, "lamp"),
                      ("strip", [(0.61, 0.79), (0.66, 0.83)], 0.02, "amber")]},
        # the plate panel
        {"plane": "rear", "outline": rect(-0.33, 0.57, 0.33, 0.68), "radii": [0.015] * 4, "depth": 0.015, "mats": ("paint", "paint"),
         "elements": [("patch", rect(-0.155, 0.575, 0.155, 0.675), [0.01] * 4, "plate", 0.004)]},
    ],
    "recesses": [
        # the centre intake under the bumper's bar, with slats; an intake each side
        {"plane": "front", "outline": rect(-0.45, 0.35, 0.45, 0.45), "radii": [0.02] * 4, "depth": 0.09, "mats": ("grille", "trim"),
         "bars": {"y": [0.383, 0.417], "mat": "trim", "t": 0.012}},
        {"plane": "front", "outline": rect(0.61, 0.38, 0.73, 0.50), "radii": [0.03] * 4, "depth": 0.06, "mats": ("grille", "trim"),
         "mirror": True, "bars": {"y": [0.42, 0.46], "mat": "trim", "t": 0.01}},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.72, 0.86), (1.63, 0.6), (1.66, 0.30), (2.9, 0.29), (2.98, 0.55), (2.98, 0.87)]},
        {"plane": "top", "line": [(-0.62, 1.52), (-0.70, 0.9), (-0.40, 0.18), (0.40, 0.18), (0.70, 0.9), (0.62, 1.52)], "mirror": False},
        {"plane": "top", "line": [(-0.66, 3.92), (-0.70, 4.35), (0.70, 4.35), (0.66, 3.92)], "mirror": False},
    ],
    "handles": [(2.70, 0.71)],
    "splitter": {"d1": 0.45, "reach": 0.03, "y": 0.15, "t": 0.016, "mat": "trim"},
    "mirrors": [{"base": (0.80, 2.02, 0.88), "size": (0.14, 0.09, 0.12), "reach": 0.05}],
    # the hoop wing: its legs sweep up from the rear quarters
    "wings": [{"span": 0.78, "chord": 0.28, "d": 4.16, "y": 1.20, "pitch": 0.15,
               "uprights": [{"x": 0.72, "t": 0.03, "outline": [(3.92, 0.98), (4.18, 0.98), (4.44, 1.17), (4.30, 1.21)],
                             "radii": [0.03, 0.05, 0.04, 0.05]}]}],
    "exhausts": [{"at": (-0.56, 0.28, L - 0.06), "r": 0.045, "length": 0.14, "mirror": False}],
    "wipers": {"d": 1.66, "x": [0.40, -0.12], "len": 0.48, "dir": -1},
}
