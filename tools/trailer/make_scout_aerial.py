#!/usr/bin/env python3
"""Vistas aéreas (dron) de la ciudad y la región para elegir los paisajes épicos del tráiler.
Uso: python3 tools/trailer/make_scout_aerial.py /carpeta_de_trabajos /carpeta_de_fotos"""
import json
import os
import sys

jobs_dir, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(jobs_dir, exist_ok=True)
# cámaras relativas al auto (der, alto, adelante): (nombre, posición, mirando a, fov)
CAMS = [
    ('d1_alto_atras', [0, 110, -90], [0, 0, 220], 58),
    ('d2_muy_alto', [0, 320, -250], [0, 0, 700], 55),
    ('d3_lateral', [160, 70, -40], [0, 5, 80], 50),
    ('d4_rasante', [8, 9, -30], [0, 4, 400], 45),
    ('d5_horizonte', [0, 40, 0], [0, 60, 2500], 60),
    ('d6_costado_alto', [-220, 180, 40], [0, 0, 100], 52),
]
shots = [{'name': n, 'cam': {'rel': p, 'look': l}, 'fov': f, 'near': 3.0, 'wait': 40} for n, p, l, f in CAMS]


def job(name, car, tod, spawn=None, pos=None):
    cfg = {'type': 'city', 'track': 'aurelia', 'ai': 0, 'sky': 'day', 'seed': 7, 'back': 'home', 'quick': True, 'spawn': spawn or 0, 'online': False, 'tod': tod, 'tod_frozen': True}
    env = {'DR_SPAWN': str(spawn)} if spawn is not None else {'DR_POS': pos}
    json.dump({'mode': 'world', 'out': os.path.join(out_dir, name), 'car': car, 'cfg': cfg, 'env': env, 'shots': shots}, open(os.path.join(jobs_dir, 'aerial_%s.json' % name), 'w'), indent=1)


job('city_plaza', 'veltor', 18.0, pos='0,40,0')
job('city_costanera', 'gt3', 18.3, pos='0,1100,90')
job('cuesta_alta', 'rally80', 17.8, spawn=7)
job('laguna_blanca', 'kodiak', 17.5, spawn=12)
job('quebrada_roja', 'pickup', 17.9, spawn=25)
job('monte_sol', 'veltor_gtr', 18.2, spawn=16)
job('puerto_alba', 'hyper', 17.6, spawn=22)
job('paso_condor', 'camo', 18.0, spawn=20)
print('ok')
