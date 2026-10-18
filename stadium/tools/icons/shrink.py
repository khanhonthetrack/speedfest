"""Shrinks the editor's block icons (assets/ui/blocks/*.png, rendered by block_icons.tscn): 256
colours with alpha (PIL's octree quantizer), optimized PNGs; about a third of the size, no visible
change at icon size. usage: python3 stadium/tools/icons/shrink.py"""
import glob, os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
for p in sorted(glob.glob(os.path.join(HERE, '..', '..', 'assets', 'ui', 'blocks', '*.png'))):
    im = Image.open(p).convert('RGBA')
    im.quantize(256, method=Image.Quantize.FASTOCTREE).save(p, optimize=True)
