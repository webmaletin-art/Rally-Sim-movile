#!/usr/bin/env python3
"""Atlas de letras de los rotulados con texto (godot/game/models/cars/decals.png + decals.json).
Una fila por texto (1024×128, letras blancas con alfa, centradas y ajustadas al ancho): DREAM RACING, SRGamestudios, SPORT y el nombre de cada auto del catálogo.
El sombreador de la carrocería (car_visual.gd, patrones 7–10) lo proyecta sobre las puertas. Se corre cuando se agrega un auto: python3 tools/cars/gen_decals.py"""
import json, os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
OUT = os.path.join(ROOT, 'godot', 'game', 'models', 'cars')
FONT = '/usr/share/fonts/truetype/freefont/FreeSansBoldOblique.ttf'
W, H = 1024, 128

def row_img(text):
    im = Image.new('RGBA', (W, H), (255, 255, 255, 0))
    size = 124
    while size > 20:
        f = ImageFont.truetype(FONT, size)
        l, t, r, b = f.getbbox(text)
        if r - l <= W - 24 and b - t <= H - 8:
            break
        size -= 2
    d = ImageDraw.Draw(im)
    d.text(((W - (r - l)) / 2 - l, (H - (b - t)) / 2 - t), text, font=f, fill=(255, 255, 255, 255))
    return im

def main():
    veh = json.load(open(os.path.join(ROOT, 'godot', 'game', 'data', 'vehicles.json'), encoding='utf-8'))
    cat = json.load(open(os.path.join(ROOT, 'godot', 'game', 'data', 'catalog.json'), encoding='utf-8'))
    texts = [('dream', 'DREAM RACING'), ('sr', 'SRGamestudios'), ('sport', 'SPORT')]
    for cid in cat['order']:
        texts.append((cid, veh[cid]['name'].upper()))
    atlas = Image.new('RGBA', (W, H * len(texts)), (255, 255, 255, 0))
    rows = {}
    for i, (k, t) in enumerate(texts):
        atlas.paste(row_img(t), (0, i * H))
        rows[k] = i
    atlas.save(os.path.join(OUT, 'decals.png'), optimize=True)
    json.dump({'row_h': H, 'rows': rows, 'total': len(texts)}, open(os.path.join(OUT, 'decals.json'), 'w'), indent=1)
    print('decals:', len(texts), 'filas', atlas.size)

if __name__ == '__main__':
    main()
