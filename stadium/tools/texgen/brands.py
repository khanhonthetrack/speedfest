"""The Stadium's sponsors: famous Polish brands under parody names (owner, session 14: "put the
logos of famous polish brands ... e.g. ZABKA with RZABKA"). Every panel is our own design: our
lettering in open fonts (tools/texgen/fonts, OFL), simple marks and the brand's colour feel; no
real logo, mascot or slogan is copied. 512 x 256 panels, used by adverts.py (the screens' strip)
and livery.py (the car's stickers)."""
import math
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_DIR = os.path.join(HERE, 'fonts')
PW, PH = 512, 256
_fonts = {}


def f(name, px):
    key = (name, px)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(os.path.join(FONT_DIR, name), px)
    return _fonts[key]


ARCHIVO = 'ArchivoBlack-Regular.ttf'
BARLOW = 'BarlowCondensed-ExtraBold.ttf'
PACIFICO = 'Pacifico-Regular.ttf'
RUSSO = 'RussoOne-Regular.ttf'
POPPINS = 'Poppins-ExtraBold.ttf'
ANTON = 'Anton-Regular.ttf'


def fit(d, text, name, max_w, max_px):
    """The font `name` at the largest size (<= max_px) that keeps text within max_w."""
    px = max_px
    while px > 10 and d.textlength(text, font=f(name, px)) > max_w:
        px -= 2
    return f(name, px)


def panel(bg):
    img = Image.new('RGB', (PW, PH), bg)
    return img, ImageDraw.Draw(img)


def rzabka():
    """Żabka (convenience stores) -> RZABKA: green, a lily pad, white lowercase."""
    green = (20, 128, 58)
    img, d = panel(green)
    d.ellipse([34, 70, 150, 186], fill=(120, 200, 90))
    d.pieslice([34, 70, 150, 186], -35, 5, fill=green)
    d.ellipse([78, 112, 104, 138], fill=green)
    d.text((168, 132), 'rzabka', font=fit(d, 'rzabka', POPPINS, 320, 96), fill=(255, 255, 255), anchor='lm')
    d.text((172, 196), 'SKLEP ZA ROGIEM', font=f(BARLOW, 30), fill=(200, 240, 190), anchor='lm')
    return img


def orlan():
    """Orlen (fuel) -> ORLAN: white, red lettering, a wing of three slanted feathers."""
    red = (220, 24, 36)
    img, d = panel((250, 250, 248))
    for k in range(3):
        x = 52 + k * 26
        d.polygon([(x, 176), (x + 22, 176), (x + 64, 72 + k * 14), (x + 42, 72 + k * 14)], fill=red)
    d.text((176, 120), 'ORLAN', font=fit(d, 'ORLAN', ARCHIVO, 310, 104), fill=red, anchor='lm')
    d.text((180, 188), 'PALIWO DLA MISTRZÓW', font=f(BARLOW, 30), fill=(60, 60, 64), anchor='lm')
    return img


def allegrro():
    """Allegro (online shop) -> allegrro: white, orange lowercase, a cursor arrow."""
    orange = (255, 90, 0)
    img, d = panel((255, 255, 255))
    d.text((PW // 2, 112), 'allegrro', font=fit(d, 'allegrro', POPPINS, 420, 110), fill=orange, anchor='mm')
    d.polygon([(410, 168), (410, 214), (422, 202), (432, 222), (440, 218), (430, 198), (446, 198)], fill=(40, 40, 44))
    d.text((PW // 2 - 40, 196), 'KLIKNIJ  ·  KUP  ·  JEDŹ', font=f(BARLOW, 30), fill=(90, 90, 96), anchor='mm')
    return img


def inposzt():
    """InPost (parcel lockers) -> INPOSZT: yellow, black lettering, a parcel."""
    yellow = (255, 205, 0)
    ink = (26, 26, 28)
    img, d = panel(yellow)
    d.rectangle([40, 78, 140, 178], outline=ink, width=10)
    d.line([40, 112, 140, 112], fill=ink, width=8)
    d.line([90, 78, 90, 112], fill=ink, width=8)
    d.text((164, 122), 'INPOSZT', font=fit(d, 'INPOSZT', ARCHIVO, 320, 84), fill=ink, anchor='lm')
    d.text((168, 186), 'PACZKA W 24 SEKUNDY', font=f(BARLOW, 30), fill=(70, 60, 0), anchor='lm')
    return img


def lott():
    """LOT (airline) -> LOTT: navy, white lettering, a paper plane."""
    navy = (14, 32, 88)
    img, d = panel(navy)
    d.polygon([(40, 140), (184, 82), (110, 176), (100, 150)], fill=(255, 255, 255))
    d.polygon([(100, 150), (184, 82), (120, 150)], fill=(170, 190, 235))
    d.text((200, 122), 'LOTT', font=fit(d, 'LOTT', RUSSO, 260, 110), fill=(255, 255, 255), anchor='lm')
    d.text((204, 192), 'LATAMY SZYBCIEJ', font=f(BARLOW, 32), fill=(150, 180, 240), anchor='lm')
    return img


def biedronex():
    """Biedronka (supermarket) -> BIEDRONEX: red with a row of black dots, white lettering."""
    red = (226, 28, 34)
    img, d = panel(red)
    for k in range(9):
        cx = 40 + k * 54
        d.ellipse([cx - 12, 22, cx + 12, 46], fill=(20, 20, 22))
    d.text((PW // 2, 136), 'BIEDRONEX', font=fit(d, 'BIEDRONEX', ANTON, 440, 104), fill=(255, 255, 255), anchor='mm')
    d.text((PW // 2, 210), 'TANIO I SZYBKO', font=f(BARLOW, 32), fill=(255, 225, 120), anchor='mm')
    return img


def tymbarg():
    """Tymbark (juice) -> TYMBARG: a green panel with an orange band, an apple."""
    img, d = panel((34, 140, 60))
    d.rectangle([0, 184, PW, PH], fill=(250, 140, 20))
    d.ellipse([40, 64, 136, 160], fill=(200, 30, 40))
    d.polygon([(88, 66), (100, 40), (110, 44), (96, 68)], fill=(60, 30, 10))
    d.ellipse([96, 34, 132, 52], fill=(120, 200, 60))
    d.text((160, 112), 'TYMBARG', font=fit(d, 'TYMBARG', BARLOW, 330, 120), fill=(255, 255, 255), anchor='lm')
    d.text((PW // 2, 220), 'SOK Z POLSKICH JABŁEK', font=f(BARLOW, 30), fill=(60, 30, 0), anchor='mm')
    return img


def wedler():
    """E. Wedel (chocolate) -> E. Wedler: chocolate brown, cream script."""
    img, d = panel((74, 40, 24))
    d.text((PW // 2, 108), 'E. Wedler', font=fit(d, 'E. Wedler', PACIFICO, 420, 96), fill=(244, 226, 196), anchor='mm')
    d.line([120, 176, 392, 176], fill=(200, 160, 110), width=3)
    d.text((PW // 2, 206), 'CZEKOLADA DLA KIEROWCÓW', font=f(BARLOW, 30), fill=(220, 190, 150), anchor='mm')
    return img


def prince_pollo():
    """Prince Polo (wafer) -> PRINCE POLLO: royal blue, gold lettering, a crown."""
    img, d = panel((20, 54, 150))
    gold = (240, 196, 60)
    d.polygon([(PW // 2 - 50, 66), (PW // 2 - 50, 30), (PW // 2 - 25, 50), (PW // 2, 24), (PW // 2 + 25, 50),
               (PW // 2 + 50, 30), (PW // 2 + 50, 66)], fill=gold)
    d.text((PW // 2, 128), 'PRINCE POLLO', font=fit(d, 'PRINCE POLLO', ANTON, 450, 96), fill=gold, anchor='mm')
    d.text((PW // 2, 206), 'WAFELEK MISTRZA', font=f(BARLOW, 32), fill=(220, 230, 255), anchor='mm')
    return img


def cd_projektor():
    """CD Projekt (games) -> CD PROJEKTOR: black, white lettering, a red slash."""
    img, d = panel((18, 18, 20))
    d.polygon([(40, 190), (76, 60), (100, 60), (64, 190)], fill=(210, 30, 40))
    d.text((120, 104), 'CD', font=f(RUSSO, 64), fill=(255, 255, 255), anchor='lm')
    d.text((120, 164), 'PROJEKTOR', font=fit(d, 'PROJEKTOR', RUSSO, 360, 64), fill=(255, 255, 255), anchor='lm')
    d.text((124, 214), 'GRY Z POLSKI', font=f(BARLOW, 28), fill=(170, 170, 176), anchor='lm')
    return img


def five_f():
    """4F (sportswear) -> 5F: black, a huge white 5F."""
    img, d = panel((20, 20, 22))
    d.text((150, 128), '5F', font=f(ARCHIVO, 170), fill=(255, 255, 255), anchor='mm')
    d.text((290, 104), 'SPORTOWA', font=f(BARLOW, 48), fill=(255, 255, 255), anchor='lm')
    d.text((290, 158), 'ODZIEŻ', font=f(BARLOW, 48), fill=(230, 40, 50), anchor='lm')
    return img


def laciatka():
    """Łaciate (milk) -> ŁACIATKA: white with black cow patches, black lettering."""
    img, d = panel((255, 255, 255))
    for (x, y, rx, ry) in [(30, 30, 46, 30), (470, 40, 40, 36), (60, 220, 50, 34), (440, 214, 56, 30), (250, 20, 30, 18)]:
        d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=(20, 20, 22))
    d.text((PW // 2, 124), 'ŁACIATKA', font=fit(d, 'ŁACIATKA', POPPINS, 400, 92), fill=(20, 20, 22), anchor='mm')
    d.text((PW // 2, 190), 'MLEKO  3,2%', font=f(BARLOW, 34), fill=(30, 90, 200), anchor='mm')
    return img


def grzesko():
    """Grześki (wafers) -> GRZEŚKO: yellow, red lettering, wafer stripes."""
    img, d = panel((255, 214, 40))
    for k in range(6):
        d.rectangle([0, 214 + k * 8, PW, 217 + k * 8], fill=(180, 100, 30))
    d.text((PW // 2, 116), 'GRZEŚKO', font=fit(d, 'GRZEŚKO', ANTON, 420, 120), fill=(210, 30, 30), anchor='mm')
    d.text((PW // 2, 190), 'WAFEL W CZEKOLADZIE', font=f(BARLOW, 30), fill=(120, 50, 10), anchor='mm')
    return img


def pku_bank():
    """PKO Bank Polski -> PKU BANK: navy, gold initials in a ring."""
    navy = (16, 34, 76)
    gold = (212, 175, 80)
    img, d = panel(navy)
    d.ellipse([36, 56, 180, 200], outline=gold, width=10)
    d.text((108, 130), 'PKU', font=f(RUSSO, 48), fill=gold, anchor='mm')
    d.text((206, 112), 'PKU BANK', font=fit(d, 'PKU BANK', BARLOW, 280, 80), fill=(255, 255, 255), anchor='lm')
    d.text((208, 176), 'TWÓJ BANK NA TORZE', font=f(BARLOW, 30), fill=gold, anchor='lm')
    return img


def solarys():
    """Solaris (buses) -> SOLARYS: light grey, a bus's side in a band, dark lettering."""
    img, d = panel((232, 234, 236))
    d.rounded_rectangle([34, 150, 478, 210], radius=16, fill=(250, 200, 0))
    for k in range(7):
        d.rectangle([60 + k * 56, 160, 100 + k * 56, 186], fill=(40, 50, 60))
    d.text((PW // 2, 92), 'SOLARYS', font=fit(d, 'SOLARYS', ARCHIVO, 400, 90), fill=(30, 40, 52), anchor='mm')
    d.text((PW // 2, 232), 'AUTOBUSY ELEKTRYCZNE', font=f(BARLOW, 26), fill=(60, 66, 76), anchor='mm')
    return img


def snieza():
    """Śnieżka (paint) -> ŚNIEŻNA: white, blue lettering, a paint stroke."""
    img, d = panel((255, 255, 255))
    blue = (0, 84, 166)
    d.rounded_rectangle([36, 170, 476, 214], radius=22, fill=(0, 150, 220))
    d.text((PW // 2, 104), 'ŚNIEŻNA', font=fit(d, 'ŚNIEŻNA', POPPINS, 420, 100), fill=blue, anchor='mm')
    d.text((PW // 2, 192), 'FARBY  DO  ŚCIAN', font=f(BARLOW, 30), fill=(255, 255, 255), anchor='mm')
    return img


PANELS = [rzabka, orlan, allegrro, inposzt, lott, biedronex, tymbarg, wedler,
          prince_pollo, cd_projektor, five_f, laciatka, grzesko, pku_bank, solarys, snieza]
