#!/usr/bin/env python3
"""Volante 3D del dueño (biblioteca/modelos/cabina/volante.glb, ~320 mil triángulos) → versión liviana para la cabina del juego
(godot/game/models/cabin/volante_pro.glb: ~4 mil triángulos con la misma textura, centrado, aro en el plano x-y, el piloto mira hacia −z… ver cockpit.gd).
Uso: python3 tools/cars/build_cabin_parts.py"""
import os, sys, io
import numpy as np, trimesh, fast_simplification
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_final import project_uv, export_glb
ROOT = os.path.join(HERE, '..', '..')
SRC = os.path.join(ROOT, 'biblioteca', 'modelos', 'cabina', 'volante.glb')
OUT = os.path.join(ROOT, 'godot', 'game', 'models', 'cabin')
FACES = 4500
DIAM = 0.36   # diámetro del aro (m)

def main():
    sc = trimesh.load(SRC, force='scene', process=False)
    m = sc.to_geometry()
    V = np.asarray(m.vertices, dtype=np.float64)
    F = np.asarray(m.faces, dtype=np.int64)
    UV = np.asarray(m.visual.uv, dtype=np.float64)
    img = m.visual.material.baseColorTexture
    # centro del aro: el centro de la caja en x-y; el frente (botones) mira a +z en el modelo
    cx = (V[:, 0].min() + V[:, 0].max()) / 2
    cy = (V[:, 1].min() + V[:, 1].max()) / 2
    zf = V[:, 2].max()
    s = DIAM / (V[:, 0].max() - V[:, 0].min())
    V = (V - np.array([cx, cy, zf])) * s
    # soldar los vértices repetidos por las costuras de la textura (si no, el simplificador no puede tocar esos bordes)
    key, inv = np.unique(np.round(V / 2e-4).astype(np.int64), axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    Vw = np.zeros((len(key), 3))
    np.add.at(Vw, inv, V)
    Vw /= np.bincount(inv)[:, None]
    Fw = inv[F]
    Fw = Fw[(Fw[:, 0] != Fw[:, 1]) & (Fw[:, 1] != Fw[:, 2]) & (Fw[:, 0] != Fw[:, 2])]
    v2, f2 = fast_simplification.simplify(Vw.astype(np.float32), Fw.astype(np.int32), target_reduction=1.0 - FACES / len(Fw), agg=7)
    v2 = np.asarray(v2, dtype=np.float64)
    f2 = np.asarray(f2, dtype=np.int64)
    uv2 = project_uv(V, F, UV, v2)
    mesh = trimesh.Trimesh(v2, f2, process=False)
    n2 = np.asarray(mesh.vertex_normals)
    if img.size[0] > 512:
        img = img.resize((512, 512), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    n = export_glb(os.path.join(OUT, 'volante_pro.glb'), v2, f2, n2, uv2, img)
    print('volante_pro.glb: %d triángulos, %.0f KB, diámetro %.2f m' % (len(f2), n / 1e3, DIAM))

if __name__ == '__main__':
    main()
