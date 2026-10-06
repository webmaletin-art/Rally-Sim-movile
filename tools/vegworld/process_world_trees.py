#!/usr/bin/env python3
"""Limpia las imágenes crudas de render_world_trees.gd y deja en godot/game/city/trees una PNG por vista (<id>_<ángulo>.png, 8 por especie) más trees.json (S = lado del cuadro en m, h = alto del árbol):
 - baja de 512 a la resolución de la especie con promedio premultiplicado (bordes suaves y sin halos oscuros);
 - rellena el color de los píxeles transparentes con el del borde más cercano (los mipmaps no oscurecen el contorno).
Uso: python3 process_world_trees.py [carpeta de imágenes crudas]   (solo procesa las especies de TreeSprites.SPECIES: leé los ids de tree_sprites.gd)"""
import json, os, re, sys
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RAW = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/vegworld_raw'
OUT = os.path.join(ROOT, 'godot', 'game', 'city', 'trees')
os.makedirs(OUT, exist_ok=True)
src = open(os.path.join(ROOT, 'godot', 'game', 'city', 'tree_sprites.gd')).read()
species = re.findall(r'\{"id": "(\w+)", "src": "\w+", "h": [\d.]+, "res": (\d+)', src)
meta = json.load(open(os.path.join(RAW, 'meta.json')))

def clean(path, res):
    im = np.asarray(Image.open(path).convert('RGBA')).astype(np.float64) / 255.0
    a = im[..., 3:4]
    pm = np.concatenate([im[..., :3] * a, a], axis=2)
    chans = [np.asarray(Image.fromarray(pm[..., k].astype(np.float32), 'F').resize((res, res), Image.BOX)) for k in range(4)]
    pm = np.stack(chans, axis=2).astype(np.float64)
    a = pm[..., 3:4]
    col = np.where(a > 1e-4, pm[..., :3] / np.maximum(a, 1e-4), 0.0)
    a = np.where(a < 0.03, 0.0, a)
    solid = a[..., 0] > 0.0
    if solid.any() and not solid.all():
        idx = distance_transform_edt(~solid, return_distances=False, return_indices=True)
        col = col[idx[0], idx[1]]
    out = np.concatenate([np.clip(col, 0, 1), np.clip(a, 0, 1)], axis=2)
    return Image.fromarray((out * 255 + 0.5).astype('uint8'), 'RGBA')

total = 0
out_meta = {}
for tid, res in species:
    res = int(res)
    for ang in (0, 45, 90, 135, 180, 225, 270, 315):
        im = clean(os.path.join(RAW, '%s_%d.png' % (tid, ang)), res)
        p = os.path.join(OUT, '%s_%d.png' % (tid, ang))
        im.save(p, optimize=True)
        total += os.path.getsize(p)
    m = meta[tid]
    out_meta[tid] = {'S': m['S'], 'h': m['h'], 'res': res}
json.dump(out_meta, open(os.path.join(OUT, 'trees.json'), 'w'))
print('listo: %d especies, %.1f KB de PNG' % (len(species), total / 1024))
