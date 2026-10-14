#!/usr/bin/env python3
"""Variantes de color del «Volante Pro 3D» (pedido del dueño, 14/10/2026: «el volante podés hacer varias texturas y colores, que se vea bonito»).
Recolorea la textura del modelo (godot/game/models/cabin/volante_pro_0.png) por partes: cuero (oscuro), costuras (rojo), marcas (amarillo); el resto (metal, botones) igual.
El sombreado del original se conserva (se multiplica por el brillo de cada píxel). Salen volante_pro_<id>.png; cosmetics.json las usa con "tex".
Uso: python3 tools/cars/make_wheel_variants.py"""
import os
import numpy as np
from PIL import Image
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
DIR = os.path.join(ROOT, 'godot', 'game', 'models', 'cabin')
SRC = os.path.join(DIR, 'volante_pro_0.png')
# id: (cuero, costura, marca)  — colores 0..1
VARS = {
    'azul': ((0.10, 0.14, 0.30), (0.20, 0.50, 1.00), (0.95, 0.95, 0.95)),
    'rojo': ((0.42, 0.05, 0.06), (0.92, 0.90, 0.86), (1.00, 0.82, 0.10)),
    'blanco': ((0.86, 0.85, 0.82), (0.85, 0.08, 0.10), (0.10, 0.31, 0.88)),
    'oro': ((0.08, 0.08, 0.09), (0.86, 0.66, 0.22), (0.92, 0.74, 0.28)),
    'verde': ((0.06, 0.20, 0.11), (0.55, 0.95, 0.20), (0.95, 0.95, 0.95)),
}

def hsv(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = a.max(-1)
    mn = a.min(-1)
    d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    s = np.where(mx > 0, d / (mx + 1e-6), 0)
    return h, s, mx

def main():
    img = np.asarray(Image.open(SRC).convert('RGB'), dtype=np.float32) / 255.0
    h, s, v = hsv(img)
    stitch = (s > 0.45) & ((h < 25) | (h > 330)) & (v > 0.18)
    mark = (s > 0.45) & (h > 35) & (h < 75) & (v > 0.4)
    leather = (~stitch) & (~mark) & (s < 0.35) & (v < 0.22)
    base_v = float(np.median(v[leather])) or 0.1
    for vid, (lc, sc, mc) in VARS.items():
        out = img.copy()
        shade_l = np.clip(v / base_v, 0.35, 1.8)[..., None]
        out = np.where(leather[..., None], np.clip(np.array(lc) * shade_l, 0, 1), out)
        out = np.where(stitch[..., None], np.clip(np.array(sc) * np.clip(v / 0.55, 0.5, 1.3)[..., None], 0, 1), out)
        out = np.where(mark[..., None], np.clip(np.array(mc) * np.clip(v / 0.85, 0.6, 1.15)[..., None], 0, 1), out)
        Image.fromarray((out * 255).astype(np.uint8)).save(os.path.join(DIR, 'volante_pro_%s.png' % vid))
        print('volante_pro_%s.png' % vid)
    print('cuero %.0f %% · costuras %.1f %% · marcas %.1f %% de la textura' % (leather.mean() * 100, stitch.mean() * 100, mark.mean() * 100))

if __name__ == '__main__':
    main()
