#!/usr/bin/env python3
"""Block-by-block look check: where TMNF puts each colour on a block against where ours does.

For every shape both sides have, points are sampled over TMNF's visual mesh (the local reference
visuals from ref_visuals.py: meshes per material with UVs, the materials' diffuse textures) and
over ours (stadium/tests/block_dump.tscn: triangles with material keys and each key's mean albedo).
Each TMNF point takes the colour of its texture there (blurred to the atlas' regions) and is matched
to our nearest surface facing the same way; the report lists, per shape, the area where the two
colours differ, TMNF surface we have nothing at (missing) and ours where TMNF has nothing (extra),
ranked by area times the shape's campaign use. Research only: TMNF's data stays local; this
script prints numbers and names.

usage: material_check.py <ours dir> <ref dir> <block_catalogue.json> [--shape=substr] [--json=out]
       [--density=4] [--de=25] [--top=60] [--detail]
  <ours dir>  blocks.bin / blocks.json / colours.json from block_dump.tscn
  <ref dir>   ref_visuals.py's output (vis/<Shape>.json, materials.json, tex/*.png)
"""
import json, math, os, sys
import numpy as np
from scipy.spatial import cKDTree
from PIL import Image

# TMNF materials our blocks don't carry (the map's terrain is ours, built apart from the blocks)
TERRAIN = ('StadiumGrass', 'StadiumGrassOcc', 'StadiumGrassFence', 'StadiumGrassFence2')
# TMNF's grass materials are drawn by a shader of their own (their texture isn't what shows): they
# are compared as the grass TMNF shows (sRGB, measured from its screenshots)
GRASS_RGB = (66 / 255, 98 / 255, 48 / 255)
REACH = 0.35          # m: a TMNF point is matched to our surface this close
DENSE = 40.0          # points per m2 on the side being matched against (its surface, not its points)
BLUR = 32             # TMNF textures are compared at this size (an atlas's regions, not its grain)


def srgb_to_lab(c):
    c = np.asarray(c, dtype=np.float64)
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def sample(tris, density, rng, extra=None):
    """Area-weighted points on triangles (N,3,3): positions, unit normals, the triangle's index
    and barycentrics (for interpolating extra per-vertex data)."""
    a, b, c = tris[:, 0], tris[:, 1], tris[:, 2]
    n = np.cross(b - a, c - a)
    area = 0.5 * np.linalg.norm(n, axis=1)
    k = np.floor(area * density + rng.random(len(area))).astype(int)
    idx = np.repeat(np.arange(len(area)), k)
    r1 = np.sqrt(rng.random(len(idx))); r2 = rng.random(len(idx))
    w = np.stack([1 - r1, r1 * (1 - r2), r1 * r2], 1)
    p = (tris[idx] * w[:, :, None]).sum(1)
    nn = n[idx] / np.maximum(np.linalg.norm(n[idx], axis=1, keepdims=True), 1e-12)
    return p, nn, idx, w, area


class Ref:
    def __init__(self, root):
        self.root = root
        self.mats = json.load(open(os.path.join(root, 'materials.json')))
        self.tex = {}

    def texture(self, mat):
        name = (self.mats.get(mat) or {}).get('D')
        if not name:
            return None
        if name not in self.tex:
            path = os.path.join(self.root, 'tex', name + '.png')
            if not os.path.exists(path):
                path = os.path.join(self.root, 'tex', name + 'D.png')
            if os.path.exists(path):
                # alpha-cut textures (trusses, railings) are compared as they show: the mean of their
                # visible texels per region (premultiplied, then divided by the region's coverage)
                a = np.asarray(Image.open(path).convert('RGBA'), dtype=np.float64) / 255.0
                rgb, al = a[..., :3], a[..., 3:]
                def box(x):
                    h, w = x.shape[:2]
                    return x.reshape(BLUR, h // BLUR, BLUR, w // BLUR, x.shape[2]).mean((1, 3))
                if a.shape[0] % BLUR == 0 and a.shape[1] % BLUR == 0:
                    cov = box(al)
                    # see-through regions: the texture's visible mean (what shows of it there)
                    seen = (rgb * al).sum((0, 1)) / max(float(al.sum()), 1e-6)
                    self.tex[name] = np.where(cov > 0.05, box(rgb * al) / np.maximum(cov, 1e-6), seen)
                else:
                    im = Image.open(path).convert('RGB').resize((BLUR, BLUR), Image.BOX)
                    self.tex[name] = np.asarray(im, dtype=np.float64) / 255.0
            else:
                self.tex[name] = None
        return self.tex[name]

    def shape(self, name):
        path = os.path.join(self.root, 'vis', name.replace('/', '__') + '.json')
        if not os.path.exists(path):
            return None
        d = json.load(open(path))
        out = []
        for m in d['meshes']:
            v = np.asarray(m['verts'], dtype=np.float64)
            t = np.asarray(m['tris'], dtype=np.int64).reshape(-1, 3)
            uv = np.asarray(m['uvs'][0], dtype=np.float64) if m.get('uvs') else np.zeros((len(v), 2))
            out.append((m['mat'], v[t], uv[t]))
        return out


def ours_shapes(root):
    index = json.load(open(os.path.join(root, 'blocks.json')))
    colours = json.load(open(os.path.join(root, 'colours.json')))
    raw = np.fromfile(os.path.join(root, 'blocks.bin'),
                      dtype=np.dtype([('k', '<i4'), ('v', '<f4', (9,)), ('uv', '<f4', (6,))]))
    tpath = os.path.join(root, 'textures.json')
    textures = json.load(open(tpath)) if os.path.exists(tpath) else {}
    return index, colours, raw, textures


class OurTex:
    """Our UV-mapped textures, read at our UVs (blurred as TMNF's are)."""
    def __init__(self, spec):
        self.spec = spec
        self.img = {}

    def colour(self, key, uv):
        sp = self.spec.get(key)
        if sp is None:
            return None
        if key not in self.img:
            im = Image.open(sp['file']).convert('RGB')
            w, h = im.size
            # blur to the same share of the texture as TMNF's (an atlas band survives)
            self.img[key] = np.asarray(im.resize((max(BLUR, w // max(1, w // (BLUR * 2))), max(BLUR, h // max(1, h // (BLUR * 2)))), Image.BOX), dtype=np.float64) / 255.0
        a = self.img[key]
        h, w = a.shape[:2]
        u = (uv[:, 0] * sp['scale'][0]) % 1.0
        v = (uv[:, 1] * sp['scale'][1]) % 1.0
        c = a[np.floor(v * h).astype(int) % h, np.floor(u * w).astype(int) % w]
        return c * np.array(sp.get('tint', [1, 1, 1]))


def shape_uses(catalogue):
    uses = {}
    for bid, e in catalogue.items():
        u = int(e.get('campaign_uses', 0) or 0)
        for side in ('air', 'ground'):
            v = e.get(side)
            mobils = v.get('mobils', []) if isinstance(v, dict) else []
            for alt in mobils:
                for s in alt:
                    if s:
                        uses[s] = uses.get(s, 0) + u
    return uses


def check(name, ours, ref_shape, colours, ref, density, de_lim, rng, ourtex=None):
    keys, tris_o = ours
    # TMNF: points with their colour
    pts, nrm, col, mat = [], [], [], []
    for m, tris, uvs in ref_shape:
        if m in TERRAIN or len(tris) == 0:
            continue
        p, n, idx, w, _ = sample(tris, density, rng)
        if len(p) == 0:
            continue
        tex = ref.texture(m)
        if 'Grass' in m:
            c = np.tile(np.array(GRASS_RGB), (len(p), 1))
        elif tex is None:
            c = np.full((len(p), 3), np.nan)
        else:
            uv = (uvs[idx] * w[:, :, None]).sum(1)
            px = np.floor((uv[:, 0] % 1.0) * BLUR).astype(int) % BLUR
            py = np.floor(((1.0 - uv[:, 1]) % 1.0) * BLUR).astype(int) % BLUR     # TMNF's v runs up
            c = tex[py, px]
        pts.append(p); nrm.append(n); col.append(c); mat += [m] * len(p)
    if not pts:
        return None
    pts = np.concatenate(pts); nrm = np.concatenate(nrm); col = np.concatenate(col); mat = np.array(mat)
    # ours: dense (to match TMNF's points against our surface) and sparse (our own points)
    tri_o = tris_o['v'].reshape(-1, 3, 3).astype(np.float64)
    po, no, io, wo, area_o = sample(tri_o, DENSE, rng)
    ko = tris_o['k'][io]
    uvo = (tris_o['uv'].reshape(-1, 3, 2).astype(np.float64)[io] * wo[:, :, None]).sum(1)
    res = {'shape': name, 'tmnf_area': len(pts) / density, 'ours_area': float(area_o.sum())}
    if len(po) == 0:
        res.update(missing=res['tmnf_area'], extra=0.0, differ=0.0, pairs={}, missing_by={}, extra_by={})
        return res
    tree = cKDTree(po)
    d, j = tree.query(pts, k=6, distance_upper_bound=REACH)
    ok = np.isfinite(d)
    j = np.where(ok, j, 0)
    facing = np.abs(np.einsum('ij,ikj->ik', nrm, no[j])) > 0.6
    good = ok & facing
    first = np.where(good.any(1), good.argmax(1), -1)
    hit = first >= 0
    jo = j[np.arange(len(pts)), np.maximum(first, 0)]
    # colours
    key_names = [keys[k] for k in ko[jo]]
    ours_col = np.array([colours.get(k, [np.nan] * 3) for k in key_names], dtype=np.float64)
    if ourtex is not None:
        for k in set(key_names):
            sel = np.array([kn == k for kn in key_names])
            c = ourtex.colour(k, uvo[jo[sel]])
            if c is not None:
                ours_col[sel] = c
    dE = np.linalg.norm(srgb_to_lab(np.clip(col, 0, 1)) - srgb_to_lab(np.clip(ours_col, 0, 1)), axis=1)
    known = hit & np.isfinite(dE)
    differ = known & (dE > de_lim)
    w = 1.0 / density
    pairs = {}
    for m, k, e, dd, c in zip(mat[known], np.array(key_names)[known], dE[known], differ[known], col[known]):
        r = pairs.setdefault((m, k), [0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
        r[0] += w; r[1] += e * w; r[2] += w if dd else 0.0
        r[3] += c[0] * w; r[4] += c[1] * w; r[5] += c[2] * w
    missing_by = {}
    for m in mat[~hit]:
        missing_by[m] = missing_by.get(m, 0.0) + w
    # ours with no TMNF surface near (extra): our sparse points against TMNF's surface, densely
    dp, dn = [], []
    for m, tris, uvs in ref_shape:
        if len(tris):
            p2, n2, _, _, _ = sample(tris, DENSE, rng)
            dp.append(p2); dn.append(n2)
    dp = np.concatenate(dp); dn = np.concatenate(dn)
    ps, ns, isp, _, _ = sample(tri_o, density, rng)
    ks = tris_o['k'][isp]
    tt = cKDTree(dp)
    d2, j2 = tt.query(ps, k=6, distance_upper_bound=REACH)
    ok2 = np.isfinite(d2)
    j2 = np.where(ok2, j2, 0)
    f2 = np.abs(np.einsum('ij,ikj->ik', ns, dn[j2])) > 0.6
    hit2 = (ok2 & f2).any(1)
    extra_by = {}
    for k in ks[~hit2]:
        extra_by[keys[k]] = extra_by.get(keys[k], 0.0) + w
    res.update(missing=float((~hit).sum() * w), extra=float((~hit2).sum() * w), differ=float(differ.sum() * w),
               pairs={'%s -> %s' % k: [round(v[0], 1), round(v[1] / max(v[0], 1e-9), 1), round(v[2], 1),
                                        [round(x / max(v[0], 1e-9), 3) for x in v[3:6]]]
                      for k, v in pairs.items()},
               missing_by={k: round(v, 1) for k, v in missing_by.items()},
               extra_by={k: round(v, 1) for k, v in extra_by.items()})
    return res


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    opt = dict(a[2:].split('=', 1) if '=' in a else (a[2:], '1') for a in sys.argv[1:] if a.startswith('--'))
    ours_root, ref_root, cat_path = args
    density = float(opt.get('density', 4)); de_lim = float(opt.get('de', 25)); top = int(opt.get('top', 60))
    index, colours, raw, textures = ours_shapes(ours_root)
    ourtex = OurTex(textures)
    ref = Ref(ref_root)
    uses = shape_uses(json.load(open(cat_path)))
    rng = np.random.default_rng(7)
    results = []
    for e in index:
        name = e['shape']
        if 'shape' in opt and opt['shape'] not in name:
            continue
        rs = ref.shape(name)
        if rs is None:
            continue
        r = check(name, (e['keys'], raw[e['first']:e['first'] + e['count']]), rs, colours, ref, density, de_lim, rng,
                  ourtex)
        if r is None:
            continue
        r['uses'] = uses.get(name, 0)
        r['score'] = (r['differ'] + r['missing'] + r['extra']) * max(1, r['uses'])
        results.append(r)
    results.sort(key=lambda r: -r['score'])
    if 'missing' in opt:
        # over every shape: TMNF's surface we have nothing at, ours where TMNF has nothing
        for field, label in (('missing_by', 'missing (TMNF material)'), ('extra_by', 'extra (our key)')):
            agg = {}
            for r in results:
                for k, v in r[field].items():
                    a = agg.setdefault(k, [0.0, {}])
                    a[0] += v
                    fam = '/'.join(r['shape'].split('/')[:2])
                    a[1][fam] = a[1].get(fam, 0.0) + v
            print('%s:' % label)
            for k, a in sorted(agg.items(), key=lambda kv: -kv[1][0])[:int(opt['missing'])]:
                fams = ', '.join('%s %.0f' % f for f in sorted(a[1].items(), key=lambda f: -f[1])[:4])
                print('  %-34s %8.0f m2  (%s)' % (k, a[0], fams))
    if 'pairs' in opt:
        # over every shape: each (TMNF material -> our key), its area, TMNF's mean colour there
        agg = {}
        for r in results:
            for k, v in r['pairs'].items():
                a = agg.setdefault(k, [0.0, 0.0, 0.0, np.zeros(3)])
                a[0] += v[0]; a[1] += v[1] * v[0]; a[2] += v[2]; a[3] += np.array(v[3]) * v[0]
        print('%-62s %9s %6s %8s  %-14s %s' % ('TMNF material -> our key', 'area', 'dE', 'differ', 'TMNF rgb', 'ours rgb'))
        for k, a in sorted(agg.items(), key=lambda kv: -kv[1][2])[:int(opt['pairs'])]:
            key = k.split(' -> ')[1]
            t = a[3] / max(a[0], 1e-9); o = colours.get(key, [0, 0, 0])
            print('%-62s %9.0f %6.0f %8.0f  %-14s %s' % (k, a[0], a[1] / max(a[0], 1e-9), a[2],
                  '%3d %3d %3d' % tuple(int(255 * x) for x in t), '%3d %3d %3d' % tuple(int(255 * x) for x in o)))
    if 'json' in opt:
        json.dump(results, open(opt['json'], 'w'), indent=1)
    tot = {k: sum(r[k] for r in results) for k in ('tmnf_area', 'differ', 'missing', 'extra')}
    print('%d shapes; TMNF area %.0f m2: colour differs on %.0f (%.1f%%), missing %.0f (%.1f%%), extra %.0f'
          % (len(results), tot['tmnf_area'], tot['differ'], 100 * tot['differ'] / max(tot['tmnf_area'], 1),
             tot['missing'], 100 * tot['missing'] / max(tot['tmnf_area'], 1), tot['extra']))
    for r in results[:top]:
        print('%-46s uses %4d  area %7.0f  differ %6.0f  missing %6.0f  extra %6.0f' % (
            r['shape'], r['uses'], r['tmnf_area'], r['differ'], r['missing'], r['extra']))
        if 'detail' in opt:
            for k, v in sorted(r['pairs'].items(), key=lambda kv: -kv[1][2])[:6]:
                if v[2] > 1.0:
                    print('      differ %-58s %6.1f m2 of %6.1f, mean dE %.0f' % (k, v[2], v[0], v[1]))
            for k, v in sorted(r['missing_by'].items(), key=lambda kv: -kv[1])[:4]:
                if v > 1.0:
                    print('      missing %-40s %6.1f m2' % (k, v))
            for k, v in sorted(r['extra_by'].items(), key=lambda kv: -kv[1])[:4]:
                if v > 1.0:
                    print('      extra   %-40s %6.1f m2' % (k, v))


if __name__ == '__main__':
    main()
