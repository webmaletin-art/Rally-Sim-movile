#!/usr/bin/env python3
"""Limpia las imágenes crudas de render_views.gd y las deja en godot/game/vegbench/tex/<árbol>/{8views,cross}:
 - reduce a la mitad con promedio premultiplicado (bordes suaves y sin halos oscuros);
 - rellena el color de los píxeles transparentes con el del borde más cercano (los mipmaps no oscurecen el contorno);
 - 8 vistas: <id>_0.png … <id>_315.png · cruce: <id>_front.png (vista 0°) y <id>_side.png (vista 90°) · meta.json con el cuadro (S, altura, radio).
Uso: python3 process_views.py [carpeta de imágenes crudas]"""
import json, os, shutil, sys
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RAW = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/vegraw'
OUT = os.path.join(ROOT, 'godot', 'game', 'vegbench', 'tex')
meta = json.load(open(os.path.join(RAW, 'meta.json')))

def clean(path):
    im = np.asarray(Image.open(path).convert('RGBA')).astype(np.float64) / 255.0
    a = im[..., 3:4]
    pm = np.concatenate([im[..., :3] * a, a], axis=2)
    h, w = pm.shape[:2]
    pm = pm.reshape(h // 2, 2, w // 2, 2, 4).mean(axis=(1, 3))
    a = pm[..., 3:4]
    col = np.where(a > 1e-4, pm[..., :3] / np.maximum(a, 1e-4), 0.0)
    a = np.where(a < 0.03, 0.0, a)  # polvo casi invisible
    solid = a[..., 0] > 0.0
    if solid.any() and not solid.all():
        idx = distance_transform_edt(~solid, return_distances=False, return_indices=True)
        col = col[idx[0], idx[1]]
    out = np.concatenate([np.clip(col, 0, 1), np.clip(a, 0, 1)], axis=2)
    return Image.fromarray((out * 255 + 0.5).astype('uint8'), 'RGBA')

total = 0
for tid, m in meta.items():
    d8 = os.path.join(OUT, tid, '8views')
    dc = os.path.join(OUT, tid, 'cross')
    os.makedirs(d8, exist_ok=True)
    os.makedirs(dc, exist_ok=True)
    for ang in (0, 45, 90, 135, 180, 225, 270, 315):
        im = clean(os.path.join(RAW, '%s_%d.png' % (tid, ang)))
        p = os.path.join(d8, '%s_%d.png' % (tid, ang))
        im.save(p, optimize=True)
        total += os.path.getsize(p)
        if ang in (0, 90):
            q = os.path.join(dc, '%s_%s.png' % (tid, 'front' if ang == 0 else 'side'))
            im.save(q, optimize=True)
            total += os.path.getsize(q)
    json.dump(m, open(os.path.join(OUT, tid, 'meta.json'), 'w'))
    print(tid, m)
print('listo: %.1f KB de PNG' % (total / 1024))
