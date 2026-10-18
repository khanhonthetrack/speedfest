"""Our own texture toolkit for the Stadium remake's materials (numpy + Pillow, fonts from
stadium/assets/fonts). Everything is generated: tileable noise, grime, ribs, bolts, text, normal
maps from height. Textures tile in both directions unless noted. Outputs go to
stadium/assets/tex/<name>_albedo.png (sRGB), _normal.png (OpenGL, Y up), _orm.png (R occlusion,
G roughness, B metallic): Godot's ORM layout.
Needs: numpy, pillow, fonttools + brotli (to read the .woff2 fonts)."""
import os, io, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'tex')
FONTS = os.path.join(ROOT, 'assets', 'fonts')


# --- noise ----------------------------------------------------------------------------------------

def rng(seed):
    return np.random.default_rng(seed)


def fbm(w, h, seed, beta=2.0, lo=1.0, hi=None):
    """Tileable fractal noise by spectral synthesis: white noise filtered to 1/f^(beta/2) between
    frequencies lo and hi (cycles per tile), normalised to mean 0, std 1."""
    r = rng(seed)
    n = r.standard_normal((h, w))
    F = np.fft.fft2(n)
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    f = np.sqrt(fx * fx + fy * fy)
    amp = np.where(f > 0, 1.0 / np.maximum(f, 1e-6) ** (beta / 2.0), 0.0)
    amp[f < lo] = 0.0
    if hi is not None:
        amp *= 1.0 / (1.0 + (f / hi) ** 4)
    out = np.real(np.fft.ifft2(F * amp))
    out -= out.mean()
    s = out.std()
    return out / s if s > 0 else out


def blur(a, radius):
    """Tileable Gaussian blur (FFT), radius = sigma in pixels."""
    if radius <= 0:
        return a
    h, w = a.shape[:2]
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2.0 * (math.pi * radius) ** 2 * (fx * fx + fy * fy))
    if a.ndim == 2:
        return np.real(np.fft.ifft2(np.fft.fft2(a) * g))
    return np.stack([np.real(np.fft.ifft2(np.fft.fft2(a[..., c]) * g)) for c in range(a.shape[2])], -1)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def speckles(w, h, seed, density, rmin, rmax):
    """Sparse round dots (pebbles, pits): a mask 0..1, tileable."""
    r = rng(seed)
    m = np.zeros((h, w), np.float32)
    n = int(w * h * density)
    ys = r.integers(0, h, n)
    xs = r.integers(0, w, n)
    rs = r.uniform(rmin, rmax, n)
    for y, x, rad in zip(ys, xs, rs):
        R = int(math.ceil(rad))
        for dy in range(-R, R + 1):
            for dx in range(-R, R + 1):
                d = math.sqrt(dx * dx + dy * dy)
                if d <= rad:
                    m[(y + dy) % h, (x + dx) % w] = max(m[(y + dy) % h, (x + dx) % w], 1.0 - d / (rad + 0.5))
    return m


def cracks(w, h, seed, count, length, jitter=0.6):
    """Hairline cracks: random walks drawn as thin lines, a mask 0..1."""
    r = rng(seed)
    img = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = r.uniform(0, w), r.uniform(0, h)
        a = r.uniform(0, 2 * math.pi)
        pts = [(x, y)]
        for _ in range(int(length)):
            a += r.normal(0, jitter)
            x += math.cos(a) * 6
            y += math.sin(a) * 6
            pts.append((x, y))
        for ox in (-w, 0, w):
            for oy in (-h, 0, h):
                d.line([(p[0] + ox, p[1] + oy) for p in pts], fill=255, width=1)
    return np.asarray(img, np.float32) / 255.0


# --- maps -----------------------------------------------------------------------------------------

def normal_from_height(hgt, strength, wrap=True):
    """OpenGL-style normal map (RGB 0..255) from a height field in pixels' units x strength."""
    if wrap:
        dx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * 0.5
        dy = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * 0.5
    else:
        dy, dx = np.gradient(hgt)
    nx = -dx * strength
    ny = dy * strength          # image rows run down; OpenGL's green is up
    nz = np.ones_like(hgt)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / l, ny / l, nz / l], -1)
    return np.clip((n * 0.5 + 0.5) * 255.0 + 0.5, 0, 255).astype(np.uint8)


def to8(a):
    return np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8)


def srgb(c):
    """(r, g, b) 0..255 -> float array 0..1."""
    return np.array(c, np.float32) / 255.0


def save(name, albedo=None, normal=None, orm=None, size=None):
    """Writes the maps (float RGB 0..1 albedo, uint8 normal, float RGB orm) as PNGs."""
    os.makedirs(OUT, exist_ok=True)
    out = []
    for suffix, a in (('albedo', albedo), ('normal', normal), ('orm', orm)):
        if a is None:
            continue
        arr = a if a.dtype == np.uint8 else to8(a)
        im = Image.fromarray(arr, 'RGBA' if arr.shape[-1] == 4 else 'RGB')
        if size is not None and suffix != 'albedo':
            im = im.resize(size, Image.LANCZOS)
        # JPEG keeps the repo small (Godot recompresses for the GPU anyway; normal maps at a
        # higher quality, their blocks would show as dents); maps with alpha as PNG
        if arr.shape[-1] == 4:
            p = os.path.join(OUT, '%s_%s.png' % (name, suffix))
            im.save(p, optimize=True)
        else:
            p = os.path.join(OUT, '%s_%s.jpg' % (name, suffix))
            im.save(p, quality=95 if suffix == 'normal' else 90, subsampling=0)
        write_import(p, suffix == 'normal')
        out.append(p)
    print(name, *[os.path.basename(p) for p in out])
    return out


def write_import(path, normal):
    """Godot's import settings for a generated map (VRAM compressed, mipmaps; normal maps as such)
    unless they exist already."""
    imp = path + '.import'
    if os.path.exists(imp):
        return
    with open(imp, 'w') as f:
        f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
                'compress/mode=2\ncompress/high_quality=false\ncompress/lossy_quality=0.7\n'
                'compress/hdr_compression=1\ncompress/normal_map=%d\ncompress/channel_pack=0\n'
                'mipmaps/generate=true\nmipmaps/limit=-1\nroughness/mode=0\nroughness/src_normal=""\n'
                'process/fix_alpha_border=true\nprocess/premult_alpha=false\n'
                'process/normal_map_invert_y=false\nprocess/hdr_as_srgb=false\n'
                'process/hdr_clamp_exposure=false\nprocess/size_limit=0\ndetect_3d/compress_to=1\n'
                % (1 if normal else 2))


# --- drawing --------------------------------------------------------------------------------------

_fonts = {}


def font(name, px):
    """A font from stadium/assets/fonts (e.g. 'orbitron-latin-900-normal') at px pixels."""
    key = (name, px)
    if key not in _fonts:
        path = os.path.join(FONTS, name + '.woff2')
        from fontTools.ttLib import TTFont
        t = TTFont(path)
        t.flavor = None
        buf = io.BytesIO()
        t.save(buf)
        buf.seek(0)
        _fonts[key] = ImageFont.truetype(buf, px)
    return _fonts[key]


def text_mask(w, h, text, fnt, xy, anchor='mm', italic=0.0, tracking=0):
    """Text as a mask 0..1 (PIL), optionally slanted (italic: shear x per y) and letter-spaced."""
    img = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(img)
    if tracking:
        widths = [d.textlength(ch, font=fnt) for ch in text]
        total = sum(widths) + tracking * (len(text) - 1)
        x0 = xy[0] - total / 2 if anchor[0] == 'm' else xy[0]
        for ch, cw in zip(text, widths):
            d.text((x0, xy[1]), ch, font=fnt, fill=255, anchor='l' + anchor[1])
            x0 += cw + tracking
    else:
        d.text(xy, text, font=fnt, fill=255, anchor=anchor)
    if italic:
        img = img.transform((w, h), Image.AFFINE, (1, italic, -italic * xy[1], 0, 1, 0), Image.BICUBIC)
    return np.asarray(img, np.float32) / 255.0


def poly_mask(w, h, polys, blur_px=0.0):
    """Filled polygons ([(x, y), ...] in pixels) as a mask 0..1, antialiased by supersampling."""
    ss = 4
    img = Image.new('L', (w * ss, h * ss), 0)
    d = ImageDraw.Draw(img)
    for p in polys:
        d.polygon([(x * ss, y * ss) for x, y in p], fill=255)
    img = img.resize((w, h), Image.LANCZOS)
    a = np.asarray(img, np.float32) / 255.0
    return blur(a, blur_px) if blur_px else a


def rect_mask(w, h, x0, y0, x1, y1, soft=1.0):
    """An axis-aligned box (pixels), soft edges."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return (smoothstep(x0 - soft, x0 + soft, xx) * (1 - smoothstep(x1 - soft, x1 + soft, xx)) *
            smoothstep(y0 - soft, y0 + soft, yy) * (1 - smoothstep(y1 - soft, y1 + soft, yy)))


def lerp(a, b, t):
    t = t[..., None] if (np.ndim(t) == 2 and np.ndim(a) == 3) or (np.ndim(t) == 2 and np.ndim(b) == 3) else t
    return a + (b - a) * t


def grime(w, h, seed, amount=1.0, scale=1.0):
    """Dirt build-up: large blotches with fine breakup, 0..1."""
    big = fbm(w, h, seed, beta=2.6, lo=1.0 * scale)
    fine = fbm(w, h, seed + 1, beta=1.4, lo=8.0 * scale)
    g = smoothstep(0.2, 1.6, big + 0.35 * fine)
    return np.clip(g * amount, 0, 1)


def edge_wear(mask, seed, width_px):
    """Wear along the edges of a mask (paint chipped where it meets other things): 0..1."""
    soft = blur(mask, width_px)
    edge = np.clip(1.0 - np.abs(soft - 0.5) * 2.0, 0, 1) * mask
    n = fbm(mask.shape[1], mask.shape[0], seed, beta=1.2, lo=4.0)
    return np.clip(edge * smoothstep(-0.2, 0.9, n) * 1.5, 0, 1)
