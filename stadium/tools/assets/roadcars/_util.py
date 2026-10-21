"""Small helpers for the road cars' specs (outlines in a plane's coordinates)."""
import math


def circle(cx, cy, r, n=36):
    return [(cx + r * math.cos(2 * math.pi * k / n), cy + r * math.sin(2 * math.pi * k / n)) for k in range(n)]


def ellipse(cx, cy, rx, ry, n=40, rot=0.0):
    c, s = math.cos(rot), math.sin(rot)
    out = []
    for k in range(n):
        a = 2 * math.pi * k / n
        x, y = rx * math.cos(a), ry * math.sin(a)
        out.append((cx + x * c - y * s, cy + x * s + y * c))
    return out


def rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def slots(x0, x1, y0, pitch, h, n, slant=0.0):
    """n thin rectangles (louvres, vents) stacked from y0, pitch apart, each h tall, slanted."""
    return [[(x0, y0 + i * pitch), (x1, y0 + i * pitch + slant), (x1, y0 + i * pitch + h + slant), (x0, y0 + i * pitch + h)]
            for i in range(n)]
