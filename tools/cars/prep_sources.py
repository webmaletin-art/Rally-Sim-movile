"""Prepara los GLB crudos que manda el dueño (tools/cars/src/<id>.glb): une las piezas, deja la carrocería con el largo sobre el eje z
(frente hacia +z), el piso en y = 0, centrada, y la reduce a ~120 mil triángulos (como los 10 autos anteriores). Tira las texturas: el
juego pinta la carrocería con su propio sombreador.
Uso: python3 prep_sources.py <carpeta_de_crudos> <carpeta_de_salida>     (la lista de modelos y su orientación está en RAW)"""
import sys, os
import numpy as np, trimesh, fast_simplification

# id de la fuente → (archivo crudo, giro en grados sobre el eje y para que el frente quede en +z)
RAW = {
    'car10': ('a8edd152-base_1.glb', 0),
    'car11': ('31e3876e-base.glb', 0),
    'car12': ('b464d35d-classiccarDestruction.glb', -90),
    'car13': ('3471d5df-FB1960.glb', 0),
    'car14': ('119546f8-KL5Sport.glb', 90),
    'car15': ('56bf33c3-semitruck3dmodel.glb', 0),
    'car16': ('12281fd7-SendRally80.glb', 0),
    'car17': ('a7d02819-Trilux_Base.glb', 0),
    'car18': ('ce171648-Trilux_Pro_GT.glb', 0),
    'car19': ('07813db6-Trilux_Sport.glb', 0),
    'car20': ('904761d9-Veltor_Max_Base.glb', 0),
    'car21': ('086a1cda-Veltor_Max_Pro_GTR.glb', 0),
    'car22': ('f5cb4a03-Veltor_Max_Sport.glb', 0),
    'car23': ('09cca332-whitepickuptruck3dmodel.glb', 0),
}

def prep(src, dst, rot, faces=120000):
    sc = trimesh.load(src, force='scene')
    m = sc.dump(concatenate=True)
    V = np.asarray(m.vertices, dtype=np.float64)
    F = np.asarray(m.faces, dtype=np.int64)
    a = np.radians(rot)
    R = np.array([[np.cos(a), 0, np.sin(a)], [0, 1, 0], [-np.sin(a), 0, np.cos(a)]])
    V = V @ R.T
    V[:, 0] -= (V[:, 0].min() + V[:, 0].max()) / 2
    V[:, 2] -= (V[:, 2].min() + V[:, 2].max()) / 2
    V[:, 1] -= V[:, 1].min()
    if len(F) > faces:
        V, F = fast_simplification.simplify(V, F.astype(np.int32), target_reduction=1.0 - faces / len(F), agg=5)
    out = trimesh.Trimesh(V, F, process=False)
    out.export(dst)
    return len(F), out.bounds

if __name__ == '__main__':
    a, b = sys.argv[1], sys.argv[2]
    os.makedirs(b, exist_ok=True)
    for cid, (fn, rot) in RAW.items():
        n, bb = prep(os.path.join(a, fn), os.path.join(b, cid + '.glb'), rot)
        print(cid, fn, 'tris', n, 'tamaño', np.round(bb[1] - bb[0], 3))
