"""Measures a car's silhouettes on a public blueprint drawing (side, top, front, rear views), for
the road cars' specs (tools/assets/roadcars/<id>.py): numbers only; the drawings themselves are
never in the repo (fetch them again with `fetch`, from the sources in blueprints.json).

  python3 blueprint_fit.py fetch DIR                 the drawings into DIR/<id>.img
  python3 blueprint_fit.py views DIR <id>            finds the drawing's views (boxes), saves an
                                                     annotated preview DIR/<id>_views.png
  python3 blueprint_fit.py profile DIR <id>          the silhouettes in metres from the boxes in
                                                     blueprints.json: the side's top and bottom
                                                     lines over d (from the nose), the top view's
                                                     half width over d, the front's half width
                                                     over height; prints keys for a spec and saves
                                                     DIR/<id>_profile.json
  python3 blueprint_fit.py curves DIR <id>           the silhouettes, dense, for the spec ->
                                                     roadcars/profiles/<id>.json (numbers only)
  python3 blueprint_fit.py overlay DIR <id> ORTHO    the model's orthographic views (roadcar.py
                                                     --ortho ORTHO) over the drawing's: its
                                                     silhouette red, glass blue, lamps green
                                                     -> DIR/<id>_overlay.png

A view's box is [x0, y0, x1, y1, flip]: pixels in the drawing; flip mirrors it so the nose is on
the left (side, top) and the car's left (+x) is on the right (front: seen from the front).
"""
import json
import os
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "blueprints.json")


THR = [0.62]          # the dark lines' threshold of the drawing in use (blueprints.json "thr")


def load_db():
    with open(DB) as f:
        return json.load(f)


def use(cid):
    e = load_db()[cid]
    THR[0] = e.get("thr", 0.62)
    return e


def gray(path):
    return np.asarray(Image.open(path).convert("L"), np.float32) / 255.0


def lines(g, thr=0.62):
    """The drawing's dark lines (a bool mask)."""
    return g < thr


def dilate(m, r):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def flood_outside(wall):
    """The pixels reachable from the image's border without crossing a wall (a bool mask)."""
    from collections import deque
    h, w = wall.shape
    seen = np.zeros_like(wall)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not wall[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if not wall[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] and not wall[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    return seen


def erode(m, r):
    return ~dilate(~m, r)


def largest(m):
    """The mask's largest connected part."""
    from collections import deque
    h, w = m.shape
    lab = np.zeros((h, w), np.int32)
    best, best_n, n = None, 0, 0
    for y0, x0 in zip(*np.nonzero(m)):
        if lab[y0, x0]:
            continue
        n += 1
        lab[y0, x0] = n
        q = deque([(y0, x0)])
        cnt = 0
        while q:
            y, x = q.popleft()
            cnt += 1
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = n
                    q.append((ny, nx))
        if cnt > best_n:
            best, best_n = n, cnt
    return lab == best if best else m


def silhouette(g, close=2, thin=None, thr=0.62):
    """A view's filled silhouette: everything the outside can't reach through its (thickened)
    outline, without thin strokes (dimension lines, leader lines: opened away) and stray parts
    (the largest part only)."""
    wall = dilate(lines(g, thr), close)
    s = ~flood_outside(wall)
    if thin is None:
        thin = max(4, int(round(max(g.shape) / 280.0)))   # strokes a few px wide at the drawing's scale
    if thin > 0:
        s = dilate(erode(s, thin), thin) & s
    return largest(s)


def components(mask, min_px=2000):
    """Bounding boxes of the mask's connected parts (big ones), via a coarse grid."""
    from collections import deque
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32)
    boxes = []
    n = 0
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys[::7], xs[::7]):
        if lab[y0, x0]:
            continue
        n += 1
        q = deque([(y0, x0)])
        lab[y0, x0] = n
        bx = [x0, y0, x0, y0]
        cnt = 0
        while q:
            y, x = q.popleft()
            cnt += 1
            bx = [min(bx[0], x), min(bx[1], y), max(bx[2], x), max(bx[3], y)]
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = n
                    q.append((ny, nx))
        if cnt >= min_px:
            boxes.append(bx + [cnt])
    return boxes


def views(d, cid):
    g = gray(os.path.join(d, cid + ".img"))
    m = dilate(lines(g), 4)
    boxes = components(m)
    boxes.sort(key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))
    im = Image.open(os.path.join(d, cid + ".img")).convert("RGB")
    dr = ImageDraw.Draw(im)
    for i, b in enumerate(boxes[:10]):
        w, h = b[2] - b[0], b[3] - b[1]
        print("box %d: [%d, %d, %d, %d]  %dx%d aspect %.2f" % (i, b[0], b[1], b[2], b[3], w, h, w / max(h, 1)))
        dr.rectangle(b[:4], outline=(255, 0, 0), width=3)
        dr.text((b[0] + 4, b[1] + 4), str(i), fill=(255, 0, 0))
    im.thumbnail((1400, 1400))
    im.save(os.path.join(d, cid + "_views.png"))


def crop(g, box, pad=14):
    """A view's pixels with a margin round them (the flood fill needs a way round the outline)."""
    x0, y0, x1, y1 = box[:4]
    c = np.pad(g[y0:y1, x0:x1], pad, constant_values=1.0)
    if len(box) > 4 and box[4]:
        c = c[:, ::-1]
    return c


def side_profile(g, box, length):
    """The side view's top and bottom lines (y up, metres) over d (from the nose, metres)."""
    s = silhouette(crop(g, box), thr=THR[0])
    cols = np.nonzero(s.any(axis=0))[0]
    rows = np.nonzero(s.any(axis=1))[0]
    x0, x1 = cols[0], cols[-1]
    ground = rows[-1]
    k = length / (x1 - x0)
    out = []
    for x in range(x0, x1 + 1):
        ys = np.nonzero(s[:, x])[0]
        if len(ys):
            out.append(((x - x0) * k, (ground - ys[0]) * k, (ground - ys[-1]) * k))
    return np.array(out), k


def top_profile(g, box, length):
    """The top view's half width over d (metres)."""
    s = silhouette(crop(g, box), thr=THR[0])
    cols = np.nonzero(s.any(axis=0))[0]
    x0, x1 = cols[0], cols[-1]
    k = length / (x1 - x0)
    rows = np.nonzero(s.any(axis=1))[0]
    mid = (rows[0] + rows[-1]) * 0.5
    out = []
    for x in range(x0, x1 + 1):
        ys = np.nonzero(s[:, x])[0]
        if len(ys):
            out.append(((x - x0) * k, (ys[-1] - ys[0]) * 0.5 * k, (mid - (ys[0] + ys[-1]) * 0.5) * k))
    return np.array(out), k


def front_profile(g, box, height):
    """The front (or rear) view's half width over height (metres), scaled by the car's height (its
    width would count the mirrors)."""
    s = silhouette(crop(g, box), thr=THR[0])
    rows = np.nonzero(s.any(axis=1))[0]
    k = height / (rows[-1] - rows[0])
    ground = rows[-1]
    out = []
    for y in range(rows[0], rows[-1] + 1):
        xs = np.nonzero(s[y])[0]
        if len(xs):
            out.append(((ground - y) * k, (xs[-1] - xs[0]) * 0.5 * k))
    return np.array(out), k


def sample(prof, at, col=1):
    prof = prof[np.argsort(prof[:, 0])]
    return [(round(float(a), 3), round(float(np.interp(a, prof[:, 0], prof[:, col])), 3)) for a in at]


def profile(d, cid):
    db = use(cid)
    g = gray(os.path.join(d, cid + ".img"))
    L, W = db["length"], db["width"]
    res = {}
    if "side" in db:
        sp, k = side_profile(g, db["side"], L)
        ds = np.round(np.linspace(0, L, 24), 3)
        res["side_top"] = sample(sp, ds, 1)
        res["side_bottom"] = sample(sp, ds, 2)
        res["height"] = round(float(sp[:, 1].max()), 3)
        print("side: %.4f m/px, height %.3f" % (k, res["height"]))
        print("  top    ", res["side_top"])
        print("  bottom ", res["side_bottom"])
    if "top" in db:
        tp, k = top_profile(g, db["top"], L)
        ds = np.round(np.linspace(0, L, 24), 3)
        res["plan_hw"] = sample(tp, ds, 1)
        print("top: %.4f m/px, max half width %.3f" % (k, float(tp[:, 1].max())))
        print("  half width", res["plan_hw"])
    for v in ("front", "rear"):
        if v in db:
            fp, k = front_profile(g, db[v], db["height"])
            hs = np.round(np.linspace(0.05, float(fp[:, 0].max()), 16), 3)
            res[v + "_hw"] = sample(fp, hs, 1)
            print("%s: %.4f m/px, height %.3f" % (v, k, float(fp[:, 0].max())))
            print("  half width over height", res[v + "_hw"])
    with open(os.path.join(d, cid + "_profile.json"), "w") as f:
        json.dump(res, f, indent=1)


def overlay(d, cid, ortho):
    """The model's silhouettes (roadcar.py --ortho DIR: DIR/<id>_<view>.png at a known scale) as
    red outlines over the drawing's views, at the drawing's scale (the car's length for side and
    top, its height for front and rear), aligned on the nose (or the left) and the roof (a drawing's
    wheels can stand apart from its body's outline, so its lowest line isn't always the ground)."""
    db = use(cid)
    info = json.load(open(os.path.join(ortho, cid + ".json")))
    g = gray(os.path.join(d, cid + ".img"))
    tiles = []
    for v in ("side", "top", "front", "rear"):
        if v not in db or v not in info:
            continue
        c = crop(g, db[v])
        ref = silhouette(c, thr=THR[0])
        rows = np.nonzero(ref.any(axis=1))[0]
        cols = np.nonzero(ref.any(axis=0))[0]
        c = c[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]
        ref = ref[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]
        rgba = np.asarray(Image.open(info[v]["path"]).convert("RGBA"))
        a = rgba[:, :, 3] > 127
        mr = np.nonzero(a.any(axis=1))[0]
        mc = np.nonzero(a.any(axis=0))[0]
        rgba = rgba[mr[0]:mr[-1] + 1, mc[0]:mc[-1] + 1]
        a = a[mr[0]:mr[-1] + 1, mc[0]:mc[-1] + 1]
        glass = a & (rgba[:, :, 2] > 128) & (rgba[:, :, 0] < 100)
        lamps = a & (rgba[:, :, 1] > 128) & (rgba[:, :, 0] < 100)
        ppm = info["ppm"]
        if v in ("side", "top"):
            k = (ref.shape[1] / db["length"]) / ppm          # drawing px per model px
        else:
            k = (ref.shape[0] / db["height"]) / ppm
        h, w = max(1, int(round(a.shape[0] * k))), max(1, int(round(a.shape[1] * k)))
        def rs(m):
            return np.asarray(Image.fromarray(m.astype(np.uint8) * 255).resize((w, h), Image.NEAREST)) > 127
        a, glass, lamps = rs(a), rs(glass), rs(lamps)
        H, Wd = max(ref.shape[0], h), max(ref.shape[1], w)
        rgb = np.full((H, Wd, 3), 255, np.uint8)
        base = np.ones((H, Wd), np.float32)
        base[:c.shape[0], :c.shape[1]] = c
        rgb[:] = (base[:, :, None] * 255).astype(np.uint8)
        ox = 0
        if v in ("front", "rear"):
            ox = (Wd - w) // 2 if w < Wd else 0
            rx = (Wd - ref.shape[1]) // 2
            base2 = np.ones((H, Wd), np.float32)
            base2[:c.shape[0], rx:rx + c.shape[1]] = c
            rgb[:] = (base2[:, :, None] * 255).astype(np.uint8)
        for mask, colour in ((a, (230, 20, 20)), (glass, (20, 60, 240)), (lamps, (10, 170, 40))):
            m = np.zeros((H, Wd), bool)
            m[:h, ox:ox + w] = mask
            edge = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
            rgb[dilate(edge, 1)] = colour
        tiles.append(Image.fromarray(rgb))
    width = max(t.width for t in tiles)
    out = Image.new("RGB", (width, sum(t.height + 12 for t in tiles)), "white")
    y = 0
    for t in tiles:
        out.paste(t, (0, y))
        y += t.height + 12
    out.thumbnail((1500, 1800))
    path = os.path.join(d, cid + "_overlay.png")
    out.save(path)
    print("overlay", path)


def check(d, cid):
    """Each view's silhouette outlined in red on its drawing -> DIR/<id>_check.png."""
    db = use(cid)
    g = gray(os.path.join(d, cid + ".img"))
    tiles = []
    for v in ("side", "top", "front", "rear"):
        if v not in db:
            continue
        c = crop(g, db[v])
        sm = silhouette(c, thr=THR[0])
        rgb = np.repeat((c[:, :, None] * 255).astype(np.uint8), 3, axis=2)
        edge = sm & ~(np.roll(sm, 1, 0) & np.roll(sm, -1, 0) & np.roll(sm, 1, 1) & np.roll(sm, -1, 1))
        rgb[dilate(edge, 2)] = (230, 20, 20)
        im = Image.fromarray(rgb)
        im.thumbnail((900, 500))
        tiles.append(im)
    out = Image.new("RGB", (1800, 520 * ((len(tiles) + 1) // 2)), "white")
    for i, t in enumerate(tiles):
        out.paste(t, ((i % 2) * 900, (i // 2) * 520))
    out.thumbnail((1400, 1400))
    out.save(os.path.join(d, cid + "_check.png"))


def grid(d, cid, view):
    """A view of the drawing at its scale with a metric grid: side (d from the nose across, height
    up), top (d across, x up from the centre line), front/rear (x across from the centre, height
    up); lines every 10 cm, labelled every 50 -> DIR/<id>_<view>_grid.png."""
    db = use(cid)
    g = gray(os.path.join(d, cid + ".img"))
    c = crop(g, db[view])
    sm = silhouette(c, thr=THR[0])
    rows = np.nonzero(sm.any(axis=1))[0]
    cols = np.nonzero(sm.any(axis=0))[0]
    c = c[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]
    h, w = c.shape
    if view in ("side", "top"):
        k = w / db["length"]                       # px per metre
    else:
        k = h / db["height"]
    im = Image.fromarray((c * 255).astype(np.uint8)).convert("RGB")
    scale = min(1.0, 1500.0 / w)
    im = im.resize((int(w * scale), int(h * scale)))
    k *= scale
    w, h = im.size
    dr = ImageDraw.Draw(im)
    if view == "side":
        x0, y0 = 0.0, float(h)                     # the nose, the ground (the roof at the car's height)
        top = db["height"]
        y0 = top * k
        for i in range(int(db["length"] * 10) + 1):
            x = i * 0.1 * k
            dr.line([(x, 0), (x, h)], fill=(255, 120, 120) if i % 5 else (220, 0, 0), width=1)
            if i % 5 == 0:
                dr.text((x + 2, 2), "%.1f" % (i * 0.1), fill=(200, 0, 0))
        for j in range(int(top * 10) + 2):
            y = y0 - j * 0.1 * k
            dr.line([(0, y), (w, y)], fill=(120, 120, 255) if j % 5 else (0, 0, 220), width=1)
            dr.text((2, y - 12), "%.1f" % (j * 0.1), fill=(0, 0, 200))
    elif view == "top":
        mid = h / 2.0
        for i in range(int(db["length"] * 10) + 1):
            x = i * 0.1 * k
            dr.line([(x, 0), (x, h)], fill=(255, 120, 120) if i % 5 else (220, 0, 0), width=1)
            if i % 5 == 0:
                dr.text((x + 2, 2), "%.1f" % (i * 0.1), fill=(200, 0, 0))
        for j in range(-12, 13):
            y = mid - j * 0.1 * k
            dr.line([(0, y), (w, y)], fill=(120, 120, 255) if j % 5 else (0, 0, 220), width=1)
            if j % 5 == 0:
                dr.text((2, y - 12), "%.1f" % (j * 0.1), fill=(0, 0, 200))
    else:
        mid = w / 2.0
        for i in range(-12, 13):
            x = mid + i * 0.1 * k
            dr.line([(x, 0), (x, h)], fill=(255, 120, 120) if i % 5 else (220, 0, 0), width=1)
            if i % 5 == 0:
                dr.text((x + 2, 2), "%.1f" % (i * 0.1), fill=(200, 0, 0))
        for j in range(int(db["height"] * 10) + 1):
            y = h - j * 0.1 * k
            dr.line([(0, y), (w, y)], fill=(120, 120, 255) if j % 5 else (0, 0, 220), width=1)
            dr.text((2, y - 12), "%.1f" % (j * 0.1), fill=(0, 0, 200))
    path = os.path.join(d, "%s_%s_grid.png" % (cid, view))
    im.save(path)
    print(path)


def medfilt(v, r):
    out = v.copy()
    for i in range(len(v)):
        out[i] = np.median(v[max(0, i - r):i + r + 1])
    return out


def curves(d, cid):
    """The car's measured silhouettes, dense (every 2.5 cm), for its spec: the side's top and
    bottom lines over d, the plan's half width over d (the mirrors filtered out, scaled to the
    car's real width), the front's and rear's half widths over height ->
    roadcars/profiles/<id>.json."""
    db = use(cid)
    g = gray(os.path.join(d, cid + ".img"))
    L, W = db["length"], db["width"]
    out = {"length": L, "width": W}
    step = 0.025
    ds = np.round(np.arange(0.0, L + 1e-6, step), 4)
    if "side" in db:
        sp, _ = side_profile(g, db["side"], L)
        sp = sp[np.argsort(sp[:, 0])]
        # heights from the roof: the drawing's ground isn't always the tyres' (open wheels, a sill
        # line), the car's real height is known
        mid = (sp[:, 0] > 0.25 * L) & (sp[:, 0] < 0.75 * L)
        dy = db.get("height", sp[mid, 1].max()) - sp[mid, 1].max()
        out["side_top"] = [[float(a), round(float(np.interp(a, sp[:, 0], sp[:, 1])) + dy, 4)] for a in ds]
        out["side_bottom"] = [[float(a), round(float(np.interp(a, sp[:, 0], sp[:, 2])) + dy, 4)] for a in ds]
    if "top" in db:
        tp, _ = top_profile(g, db["top"], L)
        tp = tp[np.argsort(tp[:, 0])]
        hw = np.interp(ds, tp[:, 0], tp[:, 1])
        hw = medfilt(hw, 5)                    # +-12 cm: the mirrors go
        hw = np.minimum(hw, medfilt(hw, 12))
        hw *= (W * 0.5) / hw.max()
        out["plan_hw"] = [[float(a), round(float(b), 4)] for a, b in zip(ds, hw)]
    for v in ("front", "rear"):
        if v in db and "height" in db:
            fp, _ = front_profile(g, db[v], db["height"])
            fp = fp[np.argsort(fp[:, 0])]
            hs = np.round(np.arange(0.0, db["height"] + 1e-6, step), 4)
            out[v + "_hw"] = [[float(a), round(float(np.interp(a, fp[:, 0], fp[:, 1])), 4)] for a in hs]
    os.makedirs(os.path.join(HERE, "roadcars", "profiles"), exist_ok=True)
    path = os.path.join(HERE, "roadcars", "profiles", cid + ".json")
    with open(path, "w") as f:
        json.dump(out, f, separators=(",", ":"))
    print("curves", path)


def fetch(d):
    os.makedirs(d, exist_ok=True)
    for cid, e in load_db().items():
        url = e.get("url")
        if not url:
            continue
        path = os.path.join(d, cid + ".img")
        if not os.path.exists(path):
            urllib.request.urlretrieve(url, path)
        print(cid, path)


if __name__ == "__main__":
    cmd, d = sys.argv[1], sys.argv[2]
    if cmd == "fetch":
        fetch(d)
    elif cmd == "views":
        views(d, sys.argv[3])
    elif cmd == "profile":
        profile(d, sys.argv[3])
    elif cmd == "grid":
        grid(d, sys.argv[3], sys.argv[4])
    elif cmd == "check":
        check(d, sys.argv[3])
    elif cmd == "curves":
        curves(d, sys.argv[3])
    elif cmd == "overlay":
        overlay(d, sys.argv[3], sys.argv[4])
