#!/usr/bin/env python3
"""Volante 3D del dueño (biblioteca/modelos/cabina/volante.glb, ~320 mil triángulos) → versión liviana para la cabina del juego
(godot/game/models/cabin/volante_pro.glb: ~14 mil triángulos con la misma textura, centrado, aro en el plano x-y, el piloto mira hacia −z… ver cockpit.gd).
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
FACES = 14000
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
    # reducción que RESPETA la textura (PyMeshLab: colapso de aristas con las coordenadas de textura de cada esquina). Antes se soldaban las costuras y se
    # reproyectaba la textura: el volante quedaba con la textura corrida «en zigzag» (se vio de cerca el 14/10/2026). Igual que tools/cars/build_cabin_dash.py.
    import tempfile, pymeshlab
    tmp = tempfile.mkdtemp()
    tm = trimesh.Trimesh(V, F, visual=trimesh.visual.TextureVisuals(uv=UV, image=img), process=False)
    tm.export(os.path.join(tmp, 'a.obj'))
    ms = pymeshlab.MeshSet()
    ms.load_new_mesh(os.path.join(tmp, 'a.obj'))
    if not ms.current_mesh().has_wedge_tex_coord():
        ms.compute_texcoord_transfer_vertex_to_wedge()
    ms.meshing_decimation_quadric_edge_collapse_with_texture(targetfacenum=FACES, qualitythr=0.4, extratcoordw=1.5, preserveboundary=True, boundaryweight=1.5, preservenormal=True, planarquadric=True)
    ms.save_current_mesh(os.path.join(tmp, 'b.obj'))
    out = trimesh.load(os.path.join(tmp, 'b.obj'), process=False, force='mesh')
    v2 = np.asarray(out.vertices, dtype=np.float64)
    f2 = np.asarray(out.faces, dtype=np.int64)
    uv2 = np.asarray(out.visual.uv, dtype=np.float64)
    mesh = trimesh.Trimesh(v2, f2, process=False)
    n2 = np.asarray(mesh.vertex_normals)
    if img.size[0] > 512:
        img = img.resize((512, 512), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    n = export_glb(os.path.join(OUT, 'volante_pro.glb'), v2, f2, n2, uv2, img)
    print('volante_pro.glb: %d triángulos, %.0f KB, diámetro %.2f m' % (len(f2), n / 1e3, DIAM))

if __name__ == '__main__':
    main()
