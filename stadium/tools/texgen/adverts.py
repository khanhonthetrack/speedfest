"""The adverts on the remake's screens and boards: our own fictional sponsors (no real brands) in
the Stadium's restrained style: white or black panels, one logo each, a single accent colour,
lots of space. One strip of 8 panels (512 x 256 each) side by side, read by env/tm_adverts.gd.
usage: python3 stadium/tools/texgen/adverts.py"""
import math
import numpy as np
from PIL import Image, ImageDraw
from texlib import *

PW, PH = 512, 256
INK = (20, 21, 24)
PAPER = (240, 241, 238)


def panel(bg):
    img = Image.new('RGB', (PW, PH), bg)
    return img, ImageDraw.Draw(img)


def ft(name, px):
    return font(name, px)


def emblem_draw(d, cx, cy, s, colour, slant=0.42):
    """Our emblem (the parallelogram frame with SF), drawn with ImageDraw."""
    k = slant
    o = [(cx - s + k * s * 0.5, cy - s * 0.5), (cx + s + k * s * 0.5, cy - s * 0.5),
         (cx + s - k * s * 0.5, cy + s * 0.5), (cx - s - k * s * 0.5, cy + s * 0.5)]
    t = s * 0.13
    i = [(o[0][0] + t * 1.4, o[0][1] + t), (o[1][0] - t * 0.6, o[1][1] + t),
         (o[2][0] - t * 1.4, o[2][1] - t), (o[3][0] + t * 0.6, o[3][1] - t)]
    d.polygon(o, fill=colour)
    return i


def speedfest(dark):
    bg, fg = (INK, PAPER) if dark else (PAPER, INK)
    img, d = panel(bg)
    inner = emblem_draw(d, 118, 128, 74, fg)
    d.polygon(inner, fill=bg)
    d.text((118, 130), 'SF', font=ft('orbitron-latin-900-normal', 58), fill=fg, anchor='mm')
    d.text((210, 112), 'SPEEDFEST', font=ft('orbitron-latin-900-normal', 39), fill=fg, anchor='lm')
    d.text((218, 160), 'S T A D I U M', font=ft('rajdhani-latin-700-normal', 30), fill=(200, 40, 36) if not dark else (90, 180, 255), anchor='lm')
    return img


def gripline():
    img, d = panel((214, 216, 214))
    # tread blocks as the logo
    for k in range(5):
        x = 46 + k * 22
        d.polygon([(x, 86), (x + 14, 86), (x + 4, 170), (x - 10, 170)], fill=INK)
    d.text((176, 118), 'GRIPLINE', font=ft('orbitron-latin-900-normal', 54), fill=INK, anchor='lm')
    d.rectangle([178, 152, 470, 160], fill=(206, 34, 30))
    d.text((180, 182), 'RACING TYRES', font=ft('rajdhani-latin-700-normal', 26), fill=(60, 62, 66), anchor='lm')
    return img


def voltage():
    img, d = panel((26, 27, 31))
    d.polygon([(78, 52), (40, 140), (72, 140), (52, 206), (122, 104), (88, 104), (112, 52)], fill=(250, 210, 30))
    d.text((150, 112), 'VOLTAGE', font=ft('orbitron-latin-900-normal', 60), fill=PAPER, anchor='lm')
    d.text((154, 168), 'ENERGY DRINK', font=ft('rajdhani-latin-700-normal', 30), fill=(250, 210, 30), anchor='lm')
    return img


def apex():
    img, d = panel(PAPER)
    d.polygon([(60, 190), (120, 60), (140, 60), (100, 190)], fill=(240, 120, 20))
    d.polygon([(110, 190), (150, 104), (170, 104), (150, 190)], fill=INK)
    d.text((196, 118), 'APEX', font=ft('orbitron-latin-900-normal', 76), fill=INK, anchor='lm')
    d.text((200, 180), 'MOTOR OIL', font=ft('rajdhani-latin-700-normal', 30), fill=(90, 92, 96), anchor='lm')
    return img


def northwind():
    img, d = panel((18, 44, 102))
    for k in range(3):
        y = 92 + k * 26
        d.arc([30, y - 40, 150, y + 40], 200, 340, fill=PAPER, width=8)
    d.text((172, 116), 'NORTHWIND', font=ft('orbitron-latin-700-normal', 40), fill=PAPER, anchor='lm')
    d.text((180, 168), 'TEAMWEAR', font=ft('rajdhani-latin-700-normal', 30), fill=(120, 180, 255), anchor='lm')
    return img


def time_attack():
    img, d = panel(PAPER)
    sq = 16
    for x in range(0, PW, sq):
        for y in range(0, 2 * sq, sq):
            if (x // sq + y // sq) % 2 == 0:
                d.rectangle([x, PH - 2 * sq + y, x + sq - 1, PH - 2 * sq + y + sq - 1], fill=INK)
    d.text((PW // 2, 92), 'TIME ATTACK', font=ft('orbitron-latin-900-normal', 54), fill=INK, anchor='mm')
    d.text((PW // 2, 160), 'BEAT THE AUTHOR TIME', font=ft('rajdhani-latin-700-normal', 30), fill=(200, 40, 36), anchor='mm')
    return img


def emblem_big():
    img, d = panel(INK)
    inner = emblem_draw(d, PW // 2, PH // 2, 150, PAPER)
    d.polygon(inner, fill=INK)
    d.text((PW // 2, PH // 2 + 4), 'SF', font=ft('orbitron-latin-900-normal', 120), fill=PAPER, anchor='mm')
    return img


def finish_strip():
    img, d = panel((26, 27, 31))
    d.text((PW // 2, 100), 'KEEP IT FLAT', font=ft('orbitron-latin-900-normal', 50), fill=PAPER, anchor='mm')
    d.text((PW // 2, 160), 'SPEEDFEST STADIUM', font=ft('rajdhani-latin-700-normal', 30), fill=(90, 180, 255), anchor='mm')
    return img


if __name__ == '__main__':
    panels = [speedfest(False), gripline(), voltage(), apex(), speedfest(True), northwind(), time_attack(), emblem_big()]
    strip = Image.new('RGB', (PW * len(panels), PH))
    for i, p in enumerate(panels):
        strip.paste(p, (i * PW, 0))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, 'adverts.png')
    strip.save(path, optimize=True)
    write_import(path, False)
    print('adverts', strip.size)
