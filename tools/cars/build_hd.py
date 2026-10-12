#!/usr/bin/env python3
"""Versión «original» (alta calidad) de un auto: el modelo crudo con SU PROPIA TEXTURA y SIN bajarle los polígonos, puesto en el mismo lugar que el auto ya armado
(misma escala, piso y centro; mismo json de medidas) para que las ruedas, la suspensión y la física calcen igual.
Uso: python3 tools/cars/build_hd.py <id_nuevo> <id_base> <crudo.glb>
  ej.: python3 tools/cars/build_hd.py veltor_gtr_hd veltor_gtr /ruta/086a1cda-Veltor_Max_Pro_GTR.glb
Escribe godot/game/models/cars/<id_nuevo>.glb (alta, con textura) + _lo.glb (la liviana del auto base, pintada por el juego) + .json (el del base con "textured": true)."""
import sys, os, json, shutil
import numpy as np, trimesh
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_car as bc

MODELS = os.path.join(HERE, '..', '..', 'godot', 'game', 'models', 'cars')

def main():
    new_id, base, raw = sys.argv[1:4]
    cfg = bc.CARS[base]
    # 1) los mismos pasos de build(): escala, ancho, piso y corrimiento del centro de masa, medidos sobre la fuente reducida
    src = bc.load(os.path.join(HERE, 'src', cfg['src'] + '.glb'))
    V = src.vertices.copy()
    s = cfg['L'] / (V[:, 2].max() - V[:, 2].min())
    V *= s
    V[:, 0] *= cfg['wscale']
    y0 = V[:, 1].min()
    V[:, 1] -= y0
    ysc = 1.0
    if 'H' in cfg:
        ysc = (cfg['H'] - cfg.get('ground', 0.1)) / V[:, 1].max()
        V[:, 1] *= ysc
    meta = json.load(open(os.path.join(MODELS, base + '.json')))
    ground = float(meta['lift'])
    # dz: corrimiento en z que usó el auto base (lo da la posición del paso delantero ya corrido)
    hx = np.abs(V[:, 0]).max()
    arch = [a for a in bc.arch_fit(V, hx)]
    if 'arch_pick' in cfg:
        lo, hi = cfg['arch_pick']
        arch = [a for a in arch if lo <= a['z'] / cfg['L'] <= hi]
    arch = [a for a in arch if a['r'] < 0.62]
    rear, front = sorted(arch, key=lambda a: a['z'])
    dz = float(meta['arches'][1]['z']) - front['z']
    # 2) el crudo, con UV y material: mismas operaciones
    sc = trimesh.load(raw)
    m = sc.to_geometry() if isinstance(sc, trimesh.Scene) else sc
    W = np.asarray(m.vertices, dtype=np.float64).copy()
    W[:, 0] -= (W[:, 0].min() + W[:, 0].max()) / 2
    W[:, 2] -= (W[:, 2].min() + W[:, 2].max()) / 2
    W[:, 1] -= W[:, 1].min()
    W *= s
    W[:, 0] *= cfg['wscale']
    W[:, 1] *= ysc
    W[:, 1] += ground
    W[:, 2] += dz
    # solo la textura de color: el juego recolorea con su sombreador (pintura y detalles) y no usa las de metal/rugosidad ni relieve (pesan y no se usan)
    mat = trimesh.visual.material.PBRMaterial(baseColorTexture=m.visual.material.baseColorTexture, metallicFactor=0.3, roughnessFactor=0.5)
    out = trimesh.Trimesh(W, np.asarray(m.faces), visual=trimesh.visual.TextureVisuals(uv=m.visual.uv, material=mat), process=False)
    out.vertices = W
    os.makedirs(MODELS, exist_ok=True)
    glb = out.export(file_type='glb', include_normals=True)
    open(os.path.join(MODELS, new_id + '.glb'), 'wb').write(glb)
    shutil.copy(os.path.join(MODELS, base + '_lo.glb'), os.path.join(MODELS, new_id + '_lo.glb'))
    meta['id'] = new_id
    meta['textured'] = True
    meta['tex'] = {'paint_hue': 0.615, 'accent_hue': 0.0, 'vref': 0.7, 'hue_w': 0.09}   # tono (0–1) de la pintura y de los detalles de la textura, brillo de referencia y ancho del tono
    meta['tris'] = [int(len(out.faces)), 0]
    json.dump(meta, open(os.path.join(MODELS, new_id + '.json'), 'w'), indent=1)
    print(new_id, 'triángulos', len(out.faces), 'tamaño KB', len(glb) // 1024, 'dz %.3f' % dz, 'altura %.3f' % out.bounds[1][1], 'frente z %.3f' % out.bounds[1][2])

if __name__ == '__main__':
    main()
