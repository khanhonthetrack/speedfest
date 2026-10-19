"""The menus' list icons (M10-5), our own drawings in the manner of TMNF's menu icons: small glossy,
slightly raised symbols in strong colours with a soft drop shadow. A person (solo, profile), a
person with a globe (online), a car (the welcome card), stacked cubes (editors), an exit door (quit), folders (browse), an
arrow (back), a film strip (replays), a gear (options), and a waving checkered flag per campaign
series. Each is a stack of shapes: a mask raised into a height field, lit (light from the upper
left, a sharp highlight), drawn over the ones below. RGBA PNGs in stadium/assets/ui/icon_*.png.
usage: python3 stadium/tools/texgen/menu_icons.py"""
import math
import numpy as np
from PIL import Image, ImageDraw
from texlib import blur, smoothstep, srgb, lerp
from ui import save_rgba

N = 128


def canvas():
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    return (xx + 0.5) / N, (yy + 0.5) / N


def ellipse(cx, cy, rx, ry):
    x, y = canvas()
    d = np.sqrt(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2)
    return smoothstep(1.0 + 1.5 / (N * min(rx, ry)), 1.0 - 1.5 / (N * min(rx, ry)), d)


def poly(points, ss=4):
    img = Image.new('L', (N * ss, N * ss), 0)
    ImageDraw.Draw(img).polygon([(px * N * ss, py * N * ss) for px, py in points], fill=255)
    return np.asarray(img.resize((N, N), Image.LANCZOS)).astype(np.float32) / 255.0


def rrect(x0, y0, x1, y1, r):
    x, y = canvas()
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    dx = np.maximum(np.abs(x - cx) - hx, 0)
    dy = np.maximum(np.abs(y - cy) - hy, 0)
    d = np.sqrt(dx * dx + dy * dy) - r
    return smoothstep(1.5 / N, -1.5 / N, d)


class Icon:
    """Shapes drawn bottom to top, each lit as a raised plate."""

    def __init__(self):
        self.rgb = np.zeros((N, N, 3), np.float32)
        self.alpha = np.zeros((N, N), np.float32)

    def add(self, mask, colour, depth=6.0, gloss=0.55, flat=None):
        """flat: a fixed (light) factor instead of the relief (faces of cubes)."""
        m = np.clip(mask, 0, 1)
        if flat is None:
            hgt = blur(m, 3.0) * depth
            gy, gx = np.gradient(hgt)
            nx, ny, nz = -gx, -gy, np.ones_like(hgt)
            ln = np.sqrt(nx * nx + ny * ny + nz * nz)
            nx, ny, nz = nx / ln, ny / ln, nz / ln
            l = np.array([-0.5, -0.6, 0.62], np.float32)
            l /= np.linalg.norm(l)
            lam = np.clip(nx * l[0] + ny * l[1] + nz * l[2], 0, 1)
            h = l + np.array([0, 0, 1.0], np.float32)
            h /= np.linalg.norm(h)
            spec = np.clip(nx * h[0] + ny * h[1] + nz * h[2], 0, 1) ** 30
            # the gloss: a soft light band over the top of the shape
            ys = np.nonzero(m.max(axis=1) > 0.5)[0]
            y0, y1 = (ys[0], ys[-1]) if len(ys) else (0, N)
            yy = np.mgrid[0:N, 0:N][0].astype(np.float32)
            band = smoothstep(0.55, 0.0, (yy - y0) / max(1.0, y1 - y0)) * gloss
            col = srgb(colour)[None, None, :] * (0.55 + 0.6 * lam)[..., None]
            col = lerp(col, np.ones_like(col), (band * m)[..., None] * 0.55)
            col = col + spec[..., None] * 0.5
        else:
            col = srgb(colour)[None, None, :] * flat * np.ones((N, N, 1), np.float32)
        # a dark edge so the shape reads on any background
        edge = np.clip(m - blur(m, 1.2) * 0.0, 0, 1) * (1.0 - smoothstep(0.0, 0.08, blur(m, 2.0) - 0.5 + 0.08))
        col = col * (1.0 - 0.35 * edge)[..., None]
        self.rgb = lerp(self.rgb, col, m[..., None])
        self.alpha = np.maximum(self.alpha, m)

    def save(self, name):
        # a soft drop shadow under everything
        sh = np.roll(np.roll(blur(self.alpha, 4.0), 5, axis=0), 4, axis=1) * 0.55
        a = np.maximum(self.alpha, sh)
        rgb = self.rgb * (self.alpha / np.maximum(a, 1e-4))[..., None]
        save_rgba(name, rgb, a)


def person(ic, colour, cx=0.5, s=1.0):
    ic.add(rrect(cx - 0.27 * s, 0.50, cx + 0.27 * s, 0.94, 0.17 * s) * (1 - rrect(0, 0.88, 1, 1, 0)), colour, 7)
    ic.add(ellipse(cx, 0.31, 0.17 * s, 0.17 * s), colour, 8)


def cube(ic, x, y, s, colour):
    """An isometric cube, its top face light, left mid, right dark."""
    top = [(x, y), (x + s * 0.87, y + s * 0.5), (x, y + s), (x - s * 0.87, y + s * 0.5)]
    left = [(x - s * 0.87, y + s * 0.5), (x, y + s), (x, y + 2 * s), (x - s * 0.87, y + s * 1.5)]
    right = [(x, y + s), (x + s * 0.87, y + s * 0.5), (x + s * 0.87, y + s * 1.5), (x, y + 2 * s)]
    ic.add(poly(left), colour, flat=0.78)
    ic.add(poly(right), colour, flat=0.55)
    ic.add(poly(top), colour, flat=1.12)


def flag(name, a, b):
    """A waving checkered flag: 6 x 4 squares, the cloth bent by a sine wave."""
    ic = Icon()
    x, y = canvas()
    u = (x - 0.12) / 0.78
    wave = 0.06 * np.sin(u * math.pi * 1.6)
    v = (y - 0.22 - wave) / 0.52
    cloth = (u >= 0) & (u <= 1) & (v >= 0) & (v <= 1)
    mask = blur(cloth.astype(np.float32), 0.8)
    checks = ((np.floor(u * 6) + np.floor(v * 4)) % 2).astype(np.float32)
    col = lerp(np.broadcast_to(srgb(a), (N, N, 3)), np.broadcast_to(srgb(b), (N, N, 3)), checks[..., None])
    # the folds: lighter on the slopes facing the light
    fold = 0.82 + 0.3 * np.cos(u * math.pi * 1.6 + 0.6)
    col = col * fold[..., None]
    ic.rgb = lerp(ic.rgb, col, mask[..., None])
    ic.alpha = np.maximum(ic.alpha, mask)
    # a gloss over the top
    ic.rgb = lerp(ic.rgb, np.ones_like(ic.rgb), (smoothstep(0.45, 0.0, v) * mask * 0.25)[..., None])
    ic.save(name)


def gear(ic, colour):
    x, y = canvas()
    dx, dy = x - 0.5, y - 0.5
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    teeth = 0.33 + 0.07 * smoothstep(-0.2, 0.2, np.cos(ang * 8))
    body = smoothstep(teeth + 0.01, teeth - 0.01, r) * smoothstep(0.11, 0.13, r)
    ic.add(body, colour, 7)


def main():
    ic = Icon()
    person(ic, (40, 200, 50))
    ic.save('icon_solo')

    ic = Icon()
    person(ic, (40, 200, 50), cx=0.36, s=0.85)
    globe = ellipse(0.68, 0.66, 0.24, 0.24)
    ic.add(globe, (40, 110, 220), 8)
    x, y = canvas()
    land = globe * smoothstep(0.1, 0.25, np.sin(x * 23.0) * np.cos(y * 17.0) + 0.1 * np.sin(y * 41.0))
    ic.add(land * 0.7, (70, 160, 70), 2)
    ic.save('icon_online')

    ic = Icon()
    person(ic, (40, 200, 220))
    ic.save('icon_profile')

    ic = Icon()
    cube(ic, 0.30, 0.30, 0.20, (240, 170, 30))
    cube(ic, 0.66, 0.30, 0.20, (240, 170, 30))
    cube(ic, 0.48, 0.42, 0.20, (250, 190, 40))
    ic.save('icon_editors')

    ic = Icon()     # quit: a red block, a white arrow leaving it
    cube(ic, 0.42, 0.24, 0.27, (215, 40, 40))
    ic.add(poly([(0.50, 0.58), (0.74, 0.58), (0.74, 0.48), (0.95, 0.66), (0.74, 0.84), (0.74, 0.74), (0.50, 0.74)]),
           (245, 245, 245), 5)
    ic.save('icon_quit')

    ic = Icon()     # browse: two folders
    for dx, c in ((0.0, (230, 150, 30)), (0.1, (250, 185, 50))):
        ic.add(rrect(0.10 + dx, 0.30 + dx * 0.6, 0.38 + dx, 0.42 + dx * 0.6, 0.03), c, 4)
        ic.add(rrect(0.10 + dx, 0.36 + dx * 0.6, 0.80 + dx, 0.80 + dx * 0.6, 0.05), c, 6)
    ic.save('icon_browse')

    ic = Icon()     # back: an arrow to the left
    ic.add(poly([(0.08, 0.55), (0.42, 0.25), (0.42, 0.42), (0.92, 0.42), (0.92, 0.68), (0.42, 0.68), (0.42, 0.85)]),
           (225, 45, 45), 9)
    ic.save('icon_back')

    ic = Icon()     # replays: a film strip with a play triangle
    strip = rrect(0.08, 0.24, 0.92, 0.80, 0.04)
    holes = np.zeros((N, N), np.float32)
    for i in range(7):
        hx = 0.14 + i * 0.12
        holes = np.maximum(holes, rrect(hx, 0.28, hx + 0.06, 0.34, 0.01))
        holes = np.maximum(holes, rrect(hx, 0.70, hx + 0.06, 0.76, 0.01))
    ic.add(strip * (1 - holes), (60, 70, 80), 6)
    ic.add(poly([(0.40, 0.38), (0.64, 0.52), (0.40, 0.66)]), (60, 150, 240), 6)
    ic.save('icon_replays')

    ic = Icon()
    gear(ic, (150, 165, 180))
    ic.save('icon_options')

    ic = Icon()     # the welcome card's car, seen from the front: body, wings, wheels, visor
    for wx in (0.16, 0.84):
        ic.add(rrect(wx - 0.11, 0.42, wx + 0.11, 0.80, 0.05), (35, 35, 40), 6)
    ic.add(rrect(0.10, 0.62, 0.90, 0.70, 0.02), (40, 110, 230), 4)
    ic.add(poly([(0.30, 0.72), (0.38, 0.36), (0.62, 0.36), (0.70, 0.72)]), (45, 125, 245), 8)
    ic.add(ellipse(0.5, 0.40, 0.09, 0.07), (235, 240, 250), 5)
    ic.add(rrect(0.14, 0.26, 0.86, 0.33, 0.02), (40, 110, 230), 4)
    ic.save('icon_car')

    for name, a, b in (('white', (245, 245, 245), (150, 155, 160)), ('green', (60, 205, 60), (20, 110, 25)),
                       ('blue', (60, 120, 245), (20, 50, 150)), ('red', (235, 50, 40), (130, 20, 15)),
                       ('black', (70, 70, 72), (235, 235, 235))):
        flag('flag_' + name, a, b)


if __name__ == '__main__':
    main()
