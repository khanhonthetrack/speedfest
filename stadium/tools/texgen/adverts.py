"""The adverts on the remake's screens and boards: famous Polish brands under parody names (owner,
session 14), our own designs (brands.py). One strip of 16 panels (512 x 256 each) side by side,
read by env/tm_adverts.gd (the screens scroll it: blocks/tm_surface.gdshader pattern 8).
usage: python3 stadium/tools/texgen/adverts.py"""
import os
from PIL import Image
from texlib import OUT, write_import
import brands


if __name__ == '__main__':
    panels = [p() for p in brands.PANELS]
    strip = Image.new('RGB', (brands.PW * len(panels), brands.PH))
    for i, p in enumerate(panels):
        strip.paste(p, (i * brands.PW, 0))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, 'adverts.png')
    strip.save(path, optimize=True)
    print('adverts', strip.size, len(panels), 'panels')
