"""The car's livery stickers, our own art, projected onto the body as decals (car/tm_car_visual.gd
_livery): the race number on a white board for the nose, and the side stickers for the sidepods
(our emblem; the sponsors' stickers come from brands.py). RGBA, transparent around the sticker.
usage: python3 stadium/tools/texgen/livery.py"""
import numpy as np
from texlib import *
from road import emblem


def _rgba(mask, colour):
    h, w = mask.shape
    out = np.zeros((h, w, 4), np.float32)
    out[..., :3] = srgb(colour)[None, None, :]
    out[..., 3] = np.clip(mask, 0, 1)
    return out


def _over(dst, src):
    """src over dst (straight alpha)."""
    a = src[..., 3:4]
    out = dst.copy()
    out[..., 3:4] = a + dst[..., 3:4] * (1 - a)
    out[..., :3] = (src[..., :3] * a + dst[..., :3] * dst[..., 3:4] * (1 - a)) / np.maximum(out[..., 3:4], 1e-6)
    return out


def fit_font(name, text, max_w, max_px):
    """The largest size (pixels, at most max_px) at which text is at most max_w wide."""
    from PIL import ImageDraw, Image
    d = ImageDraw.Draw(Image.new('L', (8, 8)))
    px = max_px
    while px > 8 and d.textlength(text, font=font(name, px)) > max_w:
        px -= 4
    return font(name, px)


def number(name='livery_number', w=512, h=640, text='07'):
    """The race number: black figures on a white board with rounded corners and a thin black
    keyline (seen from the chase camera, the board's top towards the nose)."""
    board = rect_mask(w, h, 24, 24, w - 24, h - 24, soft=2.0)
    inner = rect_mask(w, h, 44, 44, w - 44, h - 44, soft=2.0)
    figures = text_mask(w, h, text, fit_font('orbitron-latin-900-normal', text, w - 130, 300), (w // 2, h // 2 + 10), 'mm')
    img = _rgba(board, (250, 250, 248))
    img = _over(img, _rgba(np.clip(board - inner, 0, 1) * 0.9, (12, 12, 14)))
    img = _over(img, _rgba(figures, (12, 12, 14)))
    save(name, img)


def side_emblem(name='livery_emblem', w=1024, h=256):
    """Our emblem and SPEEDFEST in white, for a sidepod."""
    mark = emblem(w, h, 150, h // 2, 92)
    word = text_mask(w, h, 'SPEEDFEST', fit_font('orbitron-latin-900-normal', 'SPEEDFEST', w - 320, 118), (280, h // 2), 'lm', italic=0.28)
    save(name, _rgba(np.clip(mark + word, 0, 1), (248, 248, 246)))


def side_sponsor(name='livery_sponsor', w=1024, h=256):
    """The title sponsor on the sidepods, in white to read on any paint: ORLAN (brands.py) with
    its three-feather wing."""
    from PIL import Image, ImageDraw
    import brands
    img = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(img)
    for k in range(3):
        x = 40 + k * 46
        d.polygon([(x, 200), (x + 38, 200), (x + 112, 40 + k * 24), (x + 74, 40 + k * 24)], fill=255)
    d.text((300, h // 2 - 6), 'ORLAN', font=brands.fit(d, 'ORLAN', brands.ARCHIVO, w - 330, 190), fill=255, anchor='lm')
    mask = np.asarray(img, np.float32) / 255.0
    save(name, _rgba(mask, (250, 250, 248)))


if __name__ == '__main__':
    number()
    side_emblem()
    side_sponsor()
