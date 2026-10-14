#!/usr/bin/env python3
"""Tablero 3D del dueño (biblioteca/modelos/cabina/interior_rally.glb, ~315 mil triángulos, textura 1024) → tablero liviano para la cabina del juego
(godot/game/models/cabin/tablero_rally.glb). Pedido del dueño (14/10/2026): «meté el interior 3D con textura, que encaje con cada habitáculo, ningún borde afuera».
  · se recorta a tablero + consola: se sacan el marco del parabrisas y los parantes (todo lo que está arriba de la tapa del tablero, y > 0,215 en el modelo),
    las tapas de las puertas y los espejos de afuera (|x| > 0,405): eso asomaba por fuera de la carrocería y no encaja con los parantes de cada auto;
  · se gira 180° (en el modelo el piloto está del lado +z; en la cabina del juego +z es adelante);
  · queda en medidas normalizadas: x de −0,5 a 0,5 (ancho), y de 0 a 1 (alto: del piso a la tapa), z = 0 en la cara del tablero que mira al piloto y 1 en la trompa;
    cockpit.gd lo estira a cada auto (ancho del habitáculo, altura de la tapa, del volante al parabrisas);
  · se baja a ~FACES triángulos (soldando las costuras de la textura antes) y la textura se reproyecta.
Uso: python3 tools/cars/build_cabin_dash.py"""
import os, sys
import numpy as np, trimesh, fast_simplification
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_final import project_uv, export_glb
ROOT = os.path.join(HERE, '..', '..')
SRC = os.path.join(ROOT, 'biblioteca', 'modelos', 'cabina', 'interior_rally.glb')
OUT = os.path.join(ROOT, 'godot', 'game', 'models', 'cabin')
FACES = 30000
Y_TOP = 0.215    # tapa del tablero (en el modelo)
X_MAX = 0.405    # hasta acá: afuera quedan las puertas y los espejos
Z_FACE = 0.09    # cara del tablero que mira al piloto (en el modelo, del lado +z)
Z_NOSE = -0.20   # la trompa del tablero (contra el parabrisas)

def main():
    sc = trimesh.load(SRC, force='scene', process=False)
    m = sc.to_geometry()
    V = np.asarray(m.vertices, dtype=np.float64)
    F = np.asarray(m.faces, dtype=np.int64)
    UV = np.asarray(m.visual.uv, dtype=np.float64)
    img = m.visual.material.baseColorTexture
    c = V[F].mean(axis=1)
    keep = (c[:, 1] < Y_TOP) & (np.abs(c[:, 0]) < X_MAX)
    F = F[keep]
    print('recorte: %d de %d triángulos' % (len(F), keep.size))
    # normalizar (y girar 180°: x → −x, z → −z)
    Vn = np.empty_like(V)
    Vn[:, 0] = -V[:, 0] / (2 * X_MAX)
    Vn[:, 1] = V[:, 1] / Y_TOP
    Vn[:, 2] = (Z_FACE - V[:, 2]) / (Z_FACE - Z_NOSE)
    used = np.unique(F)
    remap = -np.ones(len(V), dtype=np.int64)
    remap[used] = np.arange(len(used))
    Vn = Vn[used]
    UVu = UV[used]
    F = remap[F]
    # (x → −x y z → −z a la vez es un giro de 180°, no un espejo: el orden de los triángulos queda igual)
    # reducción que RESPETA la textura (PyMeshLab: colapso de aristas con las coordenadas de textura de cada esquina). Con el simplificador común
    # (soldando las costuras y reproyectando la textura) la textura salía corrida o con manchas blancas.
    import tempfile, pymeshlab
    from PIL import Image
    tmp = tempfile.mkdtemp()
    img.save(os.path.join(tmp, 'tex.png'))
    tm = trimesh.Trimesh(Vn, F, visual=trimesh.visual.TextureVisuals(uv=UVu, image=img), process=False)
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
    os.makedirs(OUT, exist_ok=True)
    n = export_glb(os.path.join(OUT, 'tablero_rally.glb'), v2, f2, n2, uv2, img)
    print('tablero_rally.glb: %d triángulos, %.0f KB · x[%.2f,%.2f] y[%.2f,%.2f] z[%.2f,%.2f]' % (len(f2), n / 1e3, v2[:, 0].min(), v2[:, 0].max(), v2[:, 1].min(), v2[:, 1].max(), v2[:, 2].min(), v2[:, 2].max()))

if __name__ == '__main__':
    main()
