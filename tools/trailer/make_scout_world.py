#!/usr/bin/env python3
"""Reconocimiento del mundo abierto (Dream City y la región) para el tráiler: varios puntos con las mismas cámaras.
Uso: python3 tools/trailer/make_scout_world.py /carpeta_de_trabajos /carpeta_de_fotos"""
import json
import math
import os
import sys

jobs_dir, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(jobs_dir, exist_ok=True)
CAMS = [
    ('a_front', {'orbit': {'a': 28, 'r': 6.5, 'h': 0.8, 'lh': 0.7}}, 38, 2.0),
    ('b_low', {'orbit': {'a': 18, 'r': 4.2, 'h': 0.45, 'lh': 0.8}}, 66, 2.0),
    ('c_rear', {'orbit': {'a': 165, 'r': 9.0, 'h': 2.4, 'lh': 0.9}}, 46, 2.0),
    ('d_high', {'orbit': {'a': 150, 'r': 24.0, 'h': 12.0, 'lh': 1.0}}, 50, 3.0),
    ('e_side', {'orbit': {'a': 80, 'r': 9.0, 'h': 1.1, 'lh': 0.8}}, 32, 3.0),
]
shots = [{'name': n, 'cam': c, 'fov': f, 'near': nr, 'wait': 10} for n, c, f, nr in CAMS]


def job(name, car, x, z, yaw_deg, tod=13.0, spawn=0, sky='day'):
    cfg = {'type': 'city', 'track': 'aurelia', 'ai': 0, 'sky': sky, 'seed': 7, 'back': 'home', 'quick': True, 'spawn': spawn, 'online': False, 'tod': tod, 'tod_frozen': True}
    j = {'mode': 'world', 'out': os.path.join(out_dir, name), 'car': car, 'cfg': cfg, 'env': {'DR_POS': '%s,%s,%s' % (x, z, yaw_deg)}, 'shots': shots}
    json.dump(j, open(os.path.join(jobs_dir, 'scoutw_%s.json' % name), 'w'), indent=1)


job('plaza_sunset', 'veltor', 0, 30, 0, 18.2)
job('avenida3_golden', 'gt', 0, 180, 0, 17.6)
job('casco_viejo', 'torito', 305, 563, 64, 18.6)
job('costanera', 'muscle', 0, 1100, 90, 18.0)
job('parque', 'hatch2', 178, 128, 180, 11.0)
job('ruta_este', 'kodiak', 1500, 0, -90, 17.8)
job('circunv_ring', 'gt3', 3300, 0, 0, 18.4)
job('night_plaza', 'hyper', 0, 30, 0, 21.8)
# la región: (nombre, spawn, hora)
for nm, sp, tod, car in [('puerto_alba', 22, 17.8, 'veltor_gtr'), ('bahia_ambar', 4, 18.3, 'pro_gt'), ('quebrada_roja', 25, 17.5, 'pickup'), ('cerro_verde', 5, 7.0, 'camo'), ('cuesta_alta', 7, 18.2, 'rally80')]:
    cfg = {'type': 'city', 'track': 'aurelia', 'ai': 0, 'sky': 'day', 'seed': 7, 'back': 'home', 'quick': True, 'spawn': sp, 'online': False, 'tod': tod, 'tod_frozen': True}
    j = {'mode': 'world', 'out': os.path.join(out_dir, nm), 'car': car, 'cfg': cfg, 'env': {'DR_SPAWN': str(sp)}, 'shots': shots}
    json.dump(j, open(os.path.join(jobs_dir, 'scoutw_%s.json' % nm), 'w'), indent=1)
print('ok')
