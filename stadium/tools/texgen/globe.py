"""The menus' globe (M10-5: TMNF's menus turn a green Earth behind them; ours is drawn by
stadium/ui/tm_globe.gdshader from this map): an equirectangular map of the world's land,
R = land (soft edge), G = a band along the coasts (the raised rim TMNF's land has), B = relief noise.
Land outlines: Natural Earth (public domain) through the world-atlas package (ISC), fetched once
into the cache directory, never committed.
usage: python3 stadium/tools/texgen/globe.py [cache dir]"""
import json
import os
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageDraw
from texlib import blur, fbm, save

URL = 'https://cdn.jsdelivr.net/npm/world-atlas@2.0.2/land-50m.json'
W, H = 2048, 1024


def topology(cache):
    path = os.path.join(cache, 'land-50m.json')
    if not os.path.exists(path):
        os.makedirs(cache, exist_ok=True)
        urllib.request.urlretrieve(URL, path)
    return json.load(open(path))


def arcs(topo):
    """TopoJSON arcs, delta-decoded and de-quantized to (lon, lat)."""
    sx, sy = topo['transform']['scale']
    tx, ty = topo['transform']['translate']
    out = []
    for arc in topo['arcs']:
        x = y = 0
        pts = []
        for dx, dy in arc:
            x += dx
            y += dy
            pts.append((x * sx + tx, y * sy + ty))
        out.append(pts)
    return out


def ring(ids, decoded):
    pts = []
    for i in ids:
        a = decoded[i] if i >= 0 else decoded[~i][::-1]
        pts.extend(a if not pts else a[1:])
    return pts


def polygons(topo):
    decoded = arcs(topo)
    geo = topo['objects']['land']
    geoms = geo['geometries'] if geo['type'] == 'GeometryCollection' else [geo]
    for g in geoms:
        polys = g['arcs'] if g['type'] == 'MultiPolygon' else [g['arcs']]
        for poly in polys:
            yield [ring(r, decoded) for r in poly]


def unwrap(pts):
    """A ring's longitudes made continuous (a ring crossing the 180th meridian jumps by 360)."""
    out = [pts[0]]
    for lon, lat in pts[1:]:
        prev = out[-1][0]
        while lon - prev > 180.0:
            lon -= 360.0
        while lon - prev < -180.0:
            lon += 360.0
        out.append((lon, lat))
    return out


def land_mask(topo, ss=2):
    img = Image.new('L', (W * ss, H * ss), 0)
    d = ImageDraw.Draw(img)
    to_px = lambda p, off: ((p[0] + off + 180.0) / 360.0 * W * ss, (90.0 - p[1]) / 180.0 * H * ss)
    for rings in polygons(topo):
        # drawn once a turn either way too, so the part past the meridian lands on the other side
        for off in (-360.0, 0.0, 360.0):
            d.polygon([to_px(p, off) for p in unwrap(rings[0])], fill=255)
            for hole in rings[1:]:
                d.polygon([to_px(p, off) for p in unwrap(hole)], fill=0)
    img = img.resize((W, H), Image.LANCZOS)
    return np.asarray(img).astype(np.float32) / 255.0


def main():
    cache = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.expanduser('~'), '.cache', 'speedfest_globe')
    land = land_mask(topology(cache))
    soft = np.clip(blur(land, 1.2), 0, 1)
    # a band just inside the coasts: land minus the land eroded by a few pixels
    inner = np.clip((blur(land, 5.0) - 0.75) * 4.0, 0, 1)
    coast = np.clip(soft - inner, 0, 1)
    relief = fbm(W, H, 7, beta=1.8, lo=4.0, hi=200.0)
    relief = (relief - relief.min()) / max(1e-6, relief.max() - relief.min())
    save('globe_map', albedo=np.stack([soft, coast, relief], -1))


if __name__ == '__main__':
    main()
