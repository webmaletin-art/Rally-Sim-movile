#!/usr/bin/env python3
"""Arma los trabajos de «reconocimiento»: cada escena del juego con unas cuantas cámaras, para elegir los mejores lugares del tráiler.
Uso: python3 tools/trailer/make_scout.py /carpeta_de_trabajos /carpeta_de_fotos"""
import json
import os
import sys

jobs_dir, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(jobs_dir, exist_ok=True)

CAMS = [
    ('a_front', {'orbit': {'a': 30, 'r': 6.5, 'h': 0.8, 'lh': 0.7}}, 38),
    ('b_side', {'orbit': {'a': 90, 'r': 8.5, 'h': 1.0, 'lh': 0.8}}, 34),
    ('c_rear', {'orbit': {'a': 160, 'r': 9.0, 'h': 2.4, 'lh': 0.9}}, 46),
    ('d_wide', {'orbit': {'a': 55, 'r': 24.0, 'h': 4.0, 'lh': 1.5}}, 52),
    ('e_head', {'orbit': {'a': 8, 'r': 5.0, 'h': 0.55, 'lh': 0.8}}, 62),
]
shots = [{'name': n, 'cam': c, 'fov': f, 'wait': 6} for n, c, f in CAMS]


def job(name, car, cfg, extra=None):
    j = {'mode': 'world', 'out': os.path.join(out_dir, name), 'car': car, 'cfg': cfg, 'shots': shots}
    if extra:
        j.update(extra)
    json.dump(j, open(os.path.join(jobs_dir, 'scout_%s.json' % name), 'w'), indent=1)


rt = lambda track, sky='day', **k: dict({'type': 'race', 'track': track, 'ai': 0, 'laps': 1, 'sky': sky}, **k)
job('forest_day', 'rally80', rt('forest', 'day'), {'view_at': 0.30})
job('forest_sunset', 'rally80', rt('forest', 'sunset'), {'view_at': 0.55})
job('forest_rain', 'pickup', rt('forest', 'rain'), {'view_at': 0.45})
job('lake_day', 'gt', rt('lake', 'day'), {'view_at': 0.20})
job('lake_dusk', 'gt', rt('lake', 'dusk'), {'view_at': 0.50})
job('quarry_sunset', 'buggy', rt('quarry', 'sunset'), {'view_at': 0.30})
job('mountain_overcast', 'veltor', rt('asphaltLong', 'overcast'), {'view_at': 0.40})
job('mountain_sunset', 'veltor', rt('asphaltLong', 'sunset'), {'view_at': 0.65})
job('descent_day', 'trilux_s', rt('descent', 'day'), {'view_at': 0.30})
job('dream_vortex', 'hyper', rt('dream', 'day'), {'view_at': 0.15})
job('marte', 'muscle', rt('marte', 'day'), {'view_at': 0.15})
job('luna', 'gt3', rt('luna', 'day'), {'view_at': 0.15})
job('anillo', 'veltor_gtr', rt('anillo', 'day'), {'view_at': 0.15})
job('paper', 'hatch2', rt('paperRace', 'day'), {'view_at': 0.15})
job('drift_plaza', 'torito', {'type': 'drift', 'track': 'drift', 'ai': 0, 'sky': 'sunset'})
job('picada', 'muscle', rt('picada', 'dusk'), {'view_at': 0.0})
job('offroad', 'kodiak', {'type': 'race', 'track': 'offroad', 'ai': 0, 'laps': 1, 'sky': 'day'})
job('travesia', 'pickup', {'type': 'race', 'track': 'travesia', 'convoy': True, 'ai': 5, 'laps': 1, 'sky': 'day', 'quick': True}, {'view_at': 0.30})
for n in range(12):
    job('adv_%02d' % (n + 1), ['hatch', 'rally80', 'pickup', 'buggy', 'suv', 'kodiak', 'camo', 'gt', 'muscle', 'titan', 'veltor', 'hyper'][n], {'type': 'adventure', 'stage': n, 'back': 'home'})
print('trabajos en', jobs_dir)
