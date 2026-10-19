"""The menus' icons, our own art in the spirit of TMNF's menus: medal discs (author, gold, silver,
bronze, none) with a raised SF emblem, glossy sphere checkboxes (dark off, lime on), a gold star, a
play button, the SPEEDFEST STADIUM logo. RGBA PNGs in stadium/assets/ui/, drawn at twice the size
they show at (the menus scale them down; 4K screens get them sharp). The glass panels and buttons
are vector shapes drawn by ui/tm_glass_box.gd, not textures.
usage: python3 stadium/tools/texgen/ui.py"""
import os, math
import numpy as np
from PIL import Image
from texlib import font, text_mask, smoothstep, blur, srgb, lerp, ROOT

OUT = os.path.join(ROOT, 'assets', 'ui')
LIME = (150, 222, 40)


def save_rgba(name, rgb, alpha):
    os.makedirs(OUT, exist_ok=True)
    a = np.clip(alpha, 0, 1)
    arr = np.concatenate([np.clip(rgb, 0, 1), a[..., None]], -1)
    p = os.path.join(OUT, name + '.png')
    Image.fromarray(np.clip(arr * 255.0 + 0.5, 0, 255).astype(np.uint8), 'RGBA').save(p, optimize=True)
    imp = p + '.import'
    if not os.path.exists(imp):
        # lossless, no mipmaps would alias when scaled down: mipmaps on, filtered by the canvas
        with open(imp, 'w') as f:
            f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
                    'compress/mode=0\ncompress/high_quality=false\ncompress/lossy_quality=0.7\n'
                    'compress/hdr_compression=1\ncompress/normal_map=0\ncompress/channel_pack=0\n'
                    'mipmaps/generate=true\nmipmaps/limit=-1\nroughness/mode=0\nroughness/src_normal=""\n'
                    'process/fix_alpha_border=true\nprocess/premult_alpha=false\n'
                    'process/normal_map_invert_y=false\nprocess/hdr_as_srgb=false\n'
                    'process/hdr_clamp_exposure=false\nprocess/size_limit=0\ndetect_3d/compress_to=1\n')
    print(name, rgb.shape[1], 'x', rgb.shape[0])


def grid(n):
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    c = (n - 1) / 2.0
    return (xx - c) / (n / 2.0), (yy - c) / (n / 2.0)   # -1..1, y down


def shade(nx, ny, nz, light=(-0.45, -0.6, 0.66)):
    """Lambert + a sharp specular for a surface normal (y down, z towards the viewer)."""
    l = np.array(light, np.float32)
    l /= np.linalg.norm(l)
    lam = np.clip(nx * l[0] + ny * l[1] + nz * l[2], 0, 1)
    h = l + np.array([0, 0, 1.0])
    h /= np.linalg.norm(h)
    spec = np.clip(nx * h[0] + ny * h[1] + nz * h[2], 0, 1) ** 40
    return lam, spec


def sphere(name, base, n=96, glow=0.0):
    """A glossy glass sphere (TMNF's checkboxes are spheres): base colour, a window highlight at
    the top, a rim of light at the bottom (light through the glass)."""
    x, y = grid(n)
    r = np.sqrt(x * x + y * y) / 0.86
    inside = smoothstep(1.0 + 2.0 / n, 1.0 - 2.0 / n, r)
    nz = np.sqrt(np.clip(1 - r * r, 0, 1))
    lam, spec = shade(x / 0.86, y / 0.86, nz)
    col = srgb(base)[None, None, :] * (0.35 + 0.75 * lam)[..., None]
    # light through the glass: brighter at the bottom inside the rim
    trans = smoothstep(0.2, 0.95, y / 0.86) * smoothstep(1.0, 0.7, r)
    col = col + srgb(base)[None, None, :] * (0.55 * trans)[..., None]
    # the window highlight: a soft ellipse at the top
    hx, hy = x / 0.55, (y + 0.42) / 0.30
    hl = smoothstep(1.0, 0.2, np.sqrt(hx * hx + hy * hy)) * 0.75
    col = lerp(col, np.ones_like(col), hl)
    col = col + spec[..., None] * 0.6
    rim = smoothstep(0.86, 1.0, r) * inside
    col = col * (1 - 0.45 * rim)[..., None]
    alpha = inside
    if glow > 0:
        g = smoothstep(1.35, 0.95, r) * (1 - inside) * glow
        col = lerp(col, np.broadcast_to(srgb(base), col.shape), g)
        alpha = np.maximum(alpha, g * 0.7)
    save_rgba(name, col, alpha)


def emblem_mask(n, s):
    """Our SF emblem (a slanted parallelogram frame around SF) as a mask, centred, s = half width
    in pixels."""
    from PIL import ImageDraw
    ss = 4
    img = Image.new('L', (n * ss, n * ss), 0)
    d = ImageDraw.Draw(img)
    c = n * ss / 2.0
    S = s * ss
    k = 0.42
    o = [(c - S + k * S * 0.5, c - S * 0.5), (c + S + k * S * 0.5, c - S * 0.5),
         (c + S - k * S * 0.5, c + S * 0.5), (c - S - k * S * 0.5, c + S * 0.5)]
    t = S * 0.14
    i = [(o[0][0] + t * 1.4, o[0][1] + t), (o[1][0] - t * 0.6, o[1][1] + t),
         (o[2][0] - t * 1.4, o[2][1] - t), (o[3][0] + t * 0.6, o[3][1] - t)]
    d.polygon(o, fill=255)
    d.polygon(i, fill=0)
    img = img.resize((n, n), Image.LANCZOS)
    frame = np.asarray(img, np.float32) / 255.0
    sf = text_mask(n, n, 'SF', font('orbitron-latin-900-normal', int(s * 0.62)), (n / 2, n / 2 + 1))
    return np.clip(frame + sf, 0, 1)


def medal(name, metal, ring=None, n=128):
    """A medal disc: a bevelled rim, a dished face with our emblem raised on it, the metal's
    colour with a polished highlight; ring: a coloured enamel ring (the author medal's green)."""
    x, y = grid(n)
    r = np.sqrt(x * x + y * y) / 0.9
    inside = smoothstep(1.0 + 2.0 / n, 1.0 - 2.0 / n, r)
    # height: a rounded rim (0.78..1), a lower dished face, the emblem raised
    rim = smoothstep(0.74, 0.82, r)
    hgt = np.where(r < 0.8, 0.25 - 0.1 * r * r, 0.25 + 0.6 * np.clip(np.sin(np.clip((r - 0.8) / 0.2, 0, 1) * math.pi), 0, 1) ** 0.7)
    em = blur(emblem_mask(n, n * 0.25), 0.6)
    hgt = hgt + 0.22 * em * (r < 0.74)
    dy, dx = np.gradient(blur(hgt, 0.8) * n * 0.12)
    nx, ny = -dx, -dy
    nz = np.ones_like(nx)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    lam, spec = shade(nx / l, ny / l, nz / l)
    base = srgb(metal)[None, None, :]
    col = base * (0.45 + 0.75 * lam)[..., None] + spec[..., None] * 0.55
    # brushed sheen: a soft diagonal band
    band = smoothstep(0.5, 0.0, np.abs(x * 0.7 + y * 0.7 + 0.25)) * 0.18
    col = col + band[..., None]
    if ring is not None:
        ring_m = smoothstep(0.55, 0.58, r) * smoothstep(0.76, 0.73, r)
        rc = srgb(ring)[None, None, :] * (0.55 + 0.6 * lam)[..., None] + spec[..., None] * 0.4
        col = lerp(col, rc, ring_m)
    # a thin dark outline so it reads on any background
    edge = smoothstep(0.93, 1.0, r)
    col = col * (1 - 0.5 * edge)[..., None]
    save_rgba(name, col, inside)


def medal_none(name='medal_none', n=128):
    """No medal yet: an empty socket (a dark glass ring)."""
    x, y = grid(n)
    r = np.sqrt(x * x + y * y) / 0.9
    ring = smoothstep(0.66, 0.72, r) * smoothstep(1.0 + 2.0 / n, 1.0 - 2.0 / n, r)
    col = np.ones((n, n, 3), np.float32) * 0.75
    save_rgba(name, col, ring * 0.35 + smoothstep(0.72, 0.6, r) * 0.08)


def star(name='star', n=96):
    """A gold star with bevelled facets."""
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = 0.92 if k % 2 == 0 else 0.40
        pts.append((math.cos(a) * rr, math.sin(a) * rr + 0.06))
    from PIL import ImageDraw
    ss = 4
    img = Image.new('L', (n * ss, n * ss), 0)
    d = ImageDraw.Draw(img)
    d.polygon([((px + 1) * n * ss / 2, (py + 1) * n * ss / 2) for px, py in pts], fill=255)
    m = np.asarray(img.resize((n, n), Image.LANCZOS), np.float32) / 255.0
    x, y = grid(n)
    # facets: each point's ridge lit by its angle
    ang = np.arctan2(y - 0.06, x)
    sector = (ang + math.pi / 2) / (math.pi / 5)
    facet = (np.floor(sector * 2) % 2)
    lam = 0.55 + 0.45 * np.cos(ang + 2.2) * (0.6 + 0.4 * facet)
    col = srgb((246, 196, 40))[None, None, :] * lam[..., None]
    col = col + (smoothstep(0.5, 0.0, np.sqrt((x + 0.15) ** 2 + (y + 0.25) ** 2)) * 0.35)[..., None]
    save_rgba(name, col, m)


def play(name='play', n=96):
    """The race button's icon: a white triangle with a soft shadow."""
    from PIL import ImageDraw
    ss = 4
    img = Image.new('L', (n * ss, n * ss), 0)
    d = ImageDraw.Draw(img)
    S = n * ss
    d.polygon([(S * 0.28, S * 0.18), (S * 0.84, S * 0.5), (S * 0.28, S * 0.82)], fill=255)
    m = np.asarray(img.resize((n, n), Image.LANCZOS), np.float32) / 255.0
    sh = np.roll(np.roll(blur(m, 2.0), 3, 0), 2, 1) * 0.6
    col = np.ones((n, n, 3), np.float32) * m[..., None]
    save_rgba(name, col, np.maximum(m, sh))


def logo(name='logo', w=1200, h=300):
    """SPEEDFEST in chrome letters (a polished gradient, dark outline, a lime under-glow) over a
    lime STADIUM plate."""
    big = font('orbitron-latin-900-normal', 150)
    m = text_mask(w, h, 'SPEEDFEST', big, (w / 2, 118), italic=0.18, tracking=6)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.clip((yy - 50) / 140.0, 0, 1)
    # chrome: bright top, a dark horizon line at the middle, a lighter bottom
    chrome = np.interp(t, [0.0, 0.42, 0.47, 0.62, 1.0], [1.0, 0.86, 0.38, 0.62, 0.9])
    col = np.stack([chrome * 0.96, chrome * 0.98, chrome * 1.0], -1)
    outline = np.clip(blur(m, 3.5) * 3.0, 0, 1)
    glow = np.clip(blur(m, 14.0) * 1.6, 0, 1)
    # the STADIUM plate: a slanted lime bar with dark letters
    from PIL import ImageDraw
    ss = 4
    img = Image.new('L', (w * ss, h * ss), 0)
    d = ImageDraw.Draw(img)
    x0, x1, y0, y1 = 560, 1110, 214, 276
    k = 0.18 * (y1 - y0)
    d.polygon([((x0 + k) * ss, y0 * ss), ((x1 + k) * ss, y0 * ss), ((x1 - k) * ss, y1 * ss), ((x0 - k) * ss, y1 * ss)], fill=255)
    plate = np.asarray(img.resize((w, h), Image.LANCZOS), np.float32) / 255.0
    word = text_mask(w, h, 'STADIUM', font('orbitron-latin-900-normal', 46), ((x0 + x1) / 2, (y0 + y1) / 2 + 1), italic=0.18, tracking=14)
    lime = srgb(LIME)[None, None, :] * (1.05 - 0.35 * np.clip((yy - y0) / (y1 - y0), 0, 1))[..., None]
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    rgb = lerp(rgb, np.broadcast_to(srgb((40, 90, 10)), rgb.shape), glow)
    a = np.maximum(a, glow * 0.45)
    rgb = lerp(rgb, np.zeros_like(rgb), outline)
    a = np.maximum(a, outline * 0.92)
    rgb = lerp(rgb, col, m)
    a = np.maximum(a, m)
    pl_out = np.clip(blur(plate, 2.5) * 2.5, 0, 1)
    rgb = lerp(rgb, np.zeros_like(rgb), pl_out * (1 - m))
    a = np.maximum(a, pl_out * 0.9)
    rgb = lerp(rgb, lime, plate)
    rgb = lerp(rgb, np.broadcast_to(srgb((12, 22, 6)), rgb.shape), word * plate)
    save_rgba(name, rgb, a)


def countdown(text, name, w=360, h=260, pale=False):
    """The start countdown's figures (3, 2, 1, Go!), as TMNF shows them: upright bold rounded
    figures in a glossy blue gradient (light at the top, deep below a bright horizon), a white rim,
    a dark outline and a soft glow; Go! pale (white to ice blue) inside a blue outline."""
    px = 230 if len(text) == 1 else 170
    m = text_mask(w, h, text, font('cabin-latin-700-normal', px), (w / 2, h / 2 + 4))
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
    ys = np.nonzero(m.max(axis=1) > 0.5)[0]
    y0, y1 = (ys[0], ys[-1]) if len(ys) else (0, h)
    t = np.clip((yy - y0) / max(y1 - y0, 1), 0, 1)
    if pale:
        top, mid, mid2, low = srgb((255, 255, 255)), srgb((215, 238, 255)), srgb((190, 225, 255)), srgb((120, 175, 245))
    else:
        top, mid, mid2, low = srgb((190, 230, 255)), srgb((40, 120, 235)), srgb((70, 160, 255)), srgb((10, 40, 140))
    col = np.where((t < 0.5)[..., None], lerp(top[None, None, :], mid[None, None, :], (t / 0.5)[..., None]),
                   lerp(mid2[None, None, :], low[None, None, :], ((t - 0.5) / 0.5)[..., None]))
    rim = np.clip(m - blur(m, 2.0) * 1.0, 0, 1) * 1.5
    col = lerp(col, np.ones_like(col), np.clip(rim, 0, 1) * 0.6)
    outline = np.clip(blur(m, 4.0) * 3.0, 0, 1)
    if pale:      # Go!: a blue outline rather than a near-black one
        rgb0 = np.zeros((h, w, 3), np.float32)
        glow = np.clip(blur(m, 16.0) * 1.8, 0, 1)
        rgb0 = lerp(rgb0, np.broadcast_to(srgb((30, 110, 230)), rgb0.shape), glow)
        a = glow * 0.5
        rgb0 = lerp(rgb0, np.broadcast_to(srgb((20, 80, 200)), rgb0.shape), outline)
        a = np.maximum(a, outline * 0.95)
        rgb0 = lerp(rgb0, col, m)
        save_rgba(name, rgb0, np.maximum(a, m))
        return
    glow = np.clip(blur(m, 16.0) * 1.8, 0, 1)
    rgb = np.zeros((h, w, 3), np.float32)
    rgb = lerp(rgb, np.broadcast_to(srgb((20, 90, 220)), rgb.shape), glow)
    a = glow * 0.5
    rgb = lerp(rgb, np.broadcast_to(srgb((4, 10, 30)), rgb.shape), outline)
    a = np.maximum(a, outline * 0.95)
    rgb = lerp(rgb, col, m)
    a = np.maximum(a, m)
    save_rgba(name, rgb, a)


if __name__ == '__main__':
    for fig in ('3', '2', '1'):
        countdown(fig, 'count_' + fig)
    countdown('Go!', 'count_go', w=520, pale=True)
    sphere('check_off', (40, 52, 62))
    sphere('check_on', LIME)
    medal('medal_author', (226, 196, 92), ring=(40, 170, 70))
    medal('medal_gold', (236, 190, 52))
    medal('medal_silver', (196, 204, 214))
    medal('medal_bronze', (196, 120, 64))
    medal_none()
    star()
    play()
    logo()
