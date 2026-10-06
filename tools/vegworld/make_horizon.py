#!/usr/bin/env python3
"""Arma las dos tiras de bosque lejano del horizonte de Dream City (godot/game/city/trees/horizon_a.png y horizon_b.png), 2048 x 64, que se repiten sin costura alrededor de la cámara.
Salen de las siluetas de las MISMAS imágenes de árboles (godot/game/city/trees) puestas en tres filas (la de atrás más clara y chica, la de adelante más oscura y grande), con manchones densos,
claros con arbustos, hileras de álamos y copas de distinta altura: el borde de arriba es irregular, no un muro. La niebla del juego las funde con la distancia.
Uso: python3 make_horizon.py   (después de process_world_trees.py)"""
import os, random
import numpy as np
from PIL import Image, ImageEnhance

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
TREES = os.path.join(ROOT, 'godot', 'game', 'city', 'trees')
W, H = 2048, 64
SPECIES = {'pino': 'c', 'cipres': 'k', 'alamo': 'k', 'hoja_ancha': 'r', 'roble': 'r', 'abedul': 'r', 'sasafras': 'r'}

def load(sp, ang):
    im = Image.open(os.path.join(TREES, '%s_%d.png' % (sp, ang))).convert('RGBA')
    bb = im.getchannel('A').point(lambda v: 255 if v > 40 else 0).getbbox()
    return im.crop(bb)

def paste_wrap(canvas, sprite, x, y):
    """pega con envoltura horizontal: lo que sale por la derecha entra por la izquierda"""
    w = sprite.width
    for dx in (-W, 0, W):
        if x + dx + w > 0 and x + dx < W:
            canvas.alpha_composite(sprite, (x + dx, y))

def tint(sprite, col, amt):
    a = np.asarray(sprite).astype(np.float64)
    rgb = a[..., :3]
    mix = rgb * (1 - amt) + np.array(col, dtype=np.float64) * amt
    a[..., :3] = mix
    return Image.fromarray(np.clip(a, 0, 255).astype('uint8'), 'RGBA')

def strip(seed, conifer_bias):
    rnd = random.Random(seed)
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    # densidad periódica: manchones de bosque y claros
    ph = [rnd.random() * 6.283 for _ in range(4)]
    def dens(x):
        t = x / W * 6.283
        return 0.55 + 0.22 * np.sin(3 * t + ph[0]) + 0.16 * np.sin(7 * t + ph[1]) + 0.10 * np.sin(13 * t + ph[2])
    rows = [  # (alto mín, alto máx, color de mezcla, cuánto, paso medio, y base)
        (20, 34, (150, 175, 150), 0.55, 9, 6),   # atrás: chicas y claras
        (26, 42, (95, 135, 95), 0.40, 12, 3),    # medio
        (32, 52, (45, 85, 50), 0.28, 17, 0),     # adelante: grandes y oscuras
    ]
    # base: faja de arbustos continua e irregular (tapa los huecos entre troncos y no deja ver el piso)
    for x in range(0, W, 5):
        hh = 5 + int(3 * (0.5 + 0.5 * np.sin(x * 0.07 + ph[3])) + rnd.random() * 3)
        for xx in range(x, min(W, x + 5)):
            for yy in range(H - hh, H):
                canvas.putpixel((xx, yy), (52 + rnd.randint(-4, 4), 86 + rnd.randint(-4, 4), 52, 255))
    for (h0, h1, col, amt, step, yb) in rows:
        x = rnd.random() * step
        while x < W:
            d = dens(x)
            if rnd.random() < d:
                kinds = ['c'] * (3 if conifer_bias else 1) + ['r'] * (2 if conifer_bias else 4) + ['k']
                kind = rnd.choice(kinds)
                names = [s for s, k in SPECIES.items() if k == kind]
                sp = rnd.choice(names)
                im = load(sp, rnd.choice([0, 45, 90, 135, 180, 225, 270, 315]))
                if rnd.random() < 0.5:
                    im = im.transpose(Image.FLIP_LEFT_RIGHT)
                hh = int(rnd.uniform(h0, h1) * (0.8 + 0.4 * d))
                ww = max(3, int(im.width * hh / im.height))
                im = im.resize((ww, hh), Image.LANCZOS)
                im = tint(im, col, amt)
                im = ImageEnhance.Brightness(im).enhance(rnd.uniform(0.88, 1.1))
                paste_wrap(canvas, im, int(x - ww / 2), H - hh - yb)
            x += step * rnd.uniform(0.5, 1.5) * (1.6 if d < 0.4 else 1.0)
    # el alfa duro (el juego recorta con umbral): sin semitransparencias raras
    a = np.asarray(canvas).copy()
    return Image.fromarray(a, 'RGBA')

for name, seed, bias in (('horizon_a', 11, False), ('horizon_b', 29, True)):
    im = strip(seed, bias)
    # color de los bordes transparentes = color vecino (mipmaps sin halo)
    from scipy.ndimage import distance_transform_edt
    arr = np.asarray(im).astype(np.float64)
    solid = arr[..., 3] > 0
    idx = distance_transform_edt(~solid, return_distances=False, return_indices=True)
    arr[..., :3] = arr[idx[0], idx[1]][..., :3]
    out = Image.fromarray(arr.astype('uint8'), 'RGBA')
    p = os.path.join(TREES, name + '.png')
    out.save(p, optimize=True)
    print(p, os.path.getsize(p) // 1024, 'KB')
