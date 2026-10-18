"""The adverts on the remake's screens and boards: famous Polish brands under parody names (owner,
session 14), our own designs (brands.py). One strip of 16 panels (512 x 256 each) side by side,
read by env/tm_adverts.gd (blocks/tm_surface.gdshader pattern 8 shows one at a time on each
screen), and its fill: one column per ad holding each row's background colour, which carries an
ad's background out to the ends of a board longer than the ad (fill_column).
usage: python3 stadium/tools/texgen/adverts.py"""
import os
import numpy as np
from PIL import Image
from texlib import OUT, write_import
import brands


def _mode(px):
    """The most common colour among pixels (16 levels a channel), averaged over its pixels, and
    the share of pixels it holds."""
    q = px // 16
    keys = q[:, 0] * 256 + q[:, 1] * 16 + q[:, 2]
    vals, counts = np.unique(keys, return_counts=True)
    top = vals[np.argmax(counts)]
    return px[keys == top].mean(0), counts.max() / len(keys)


def fill_column(panel, band=32):
    """Each row's background: the ad's own (its most common colour), except across a band that
    runs the ad's full width (both edges of the row and most of it one colour: TYMBARG's strip,
    GRZEŚKO's stripes; not ŁACIATKA's spots at its edges)."""
    a = np.asarray(panel.convert('RGB'), np.int32)
    back, _ = _mode(a.reshape(-1, 3))
    out = np.zeros((a.shape[0], 3), np.uint8)
    for y in range(a.shape[0]):
        left, lshare = _mode(a[y, :band])
        right, rshare = _mode(a[y, -band:])
        row, _ = _mode(a[y])
        full = lshare > 0.9 and rshare > 0.9 and np.abs(left - right).max() < 24 and np.abs(left - row).max() < 24
        out[y] = np.round((left + right) / 2 if full else back).astype(np.uint8)
    return out


def write_fill_import(path):
    """Lossless, no mipmaps: one exact colour per column."""
    with open(path + '.import', 'w') as f:
        f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
                'compress/mode=0\ncompress/high_quality=false\ncompress/lossy_quality=0.7\n'
                'compress/hdr_compression=1\ncompress/normal_map=0\ncompress/channel_pack=0\n'
                'mipmaps/generate=false\nmipmaps/limit=-1\nroughness/mode=0\nroughness/src_normal=""\n'
                'process/fix_alpha_border=true\nprocess/premult_alpha=false\n'
                'process/normal_map_invert_y=false\nprocess/hdr_as_srgb=false\n'
                'process/hdr_clamp_exposure=false\nprocess/size_limit=0\ndetect_3d/compress_to=0\n')


if __name__ == '__main__':
    panels = [p() for p in brands.PANELS]
    strip = Image.new('RGB', (brands.PW * len(panels), brands.PH))
    for i, p in enumerate(panels):
        strip.paste(p, (i * brands.PW, 0))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, 'adverts.png')
    strip.save(path, optimize=True)
    fill = np.stack([fill_column(p) for p in panels], 1)          # rows x ads x rgb
    fpath = os.path.join(OUT, 'adverts_fill.png')
    Image.fromarray(fill, 'RGB').save(fpath, optimize=True)
    if not os.path.exists(fpath + '.import'):
        write_fill_import(fpath)
    print('adverts', strip.size, len(panels), 'panels; fill', fill.shape[1], 'x', fill.shape[0])
