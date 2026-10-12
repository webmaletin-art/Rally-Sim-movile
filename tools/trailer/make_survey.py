#!/usr/bin/env python3
"""Recorrido de cada ruta con el auto puesto cada 5 % del trayecto (dos cámaras), para elegir los mejores lugares del tráiler.
Uso: python3 tools/trailer/make_survey.py /carpeta_de_trabajos /carpeta_de_fotos"""
import json
import os
import sys

jobs_dir, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(jobs_dir, exist_ok=True)
FR = [round(0.03 + 0.05 * i, 2) for i in range(19)]
SCENES = [
    ('forest_sunset', 'rally80', {'type': 'race', 'track': 'forest', 'ai': 0, 'laps': 1, 'sky': 'sunset'}),
    ('forest_day', 'pickup', {'type': 'race', 'track': 'forest', 'ai': 0, 'laps': 1, 'sky': 'day'}),
    ('lake_dusk', 'gt', {'type': 'race', 'track': 'lake', 'ai': 0, 'laps': 1, 'sky': 'dusk'}),
    ('mountain_sunset', 'veltor', {'type': 'race', 'track': 'asphaltLong', 'ai': 0, 'laps': 1, 'sky': 'sunset'}),
    ('quarry_day', 'buggy', {'type': 'race', 'track': 'quarry', 'ai': 0, 'laps': 1, 'sky': 'day'}),
    ('travesia', 'pickup', {'type': 'race', 'track': 'travesia', 'convoy': True, 'ai': 5, 'laps': 1, 'sky': 'day', 'quick': True}),
    ('dream', 'hyper', {'type': 'race', 'track': 'dream', 'ai': 0, 'laps': 1, 'sky': 'day'}),
    ('marte', 'muscle', {'type': 'race', 'track': 'marte', 'ai': 0, 'laps': 1, 'sky': 'day'}),
    ('luna', 'gt3', {'type': 'race', 'track': 'luna', 'ai': 0, 'laps': 1, 'sky': 'day'}),
    ('anillo', 'veltor_gtr', {'type': 'race', 'track': 'anillo', 'ai': 0, 'laps': 1, 'sky': 'day'}),
    ('paper', 'hatch2', {'type': 'race', 'track': 'paperRace', 'ai': 0, 'laps': 1, 'sky': 'day'}),
]
for name, car, cfg in SCENES:
    shots = []
    for f in FR:
        shots.append({'name': 'p%02d_a' % int(f * 100), 'tp': {'frac': f}, 'fov': 38, 'near': 1.5, 'cam': {'orbit': {'a': 28, 'r': 6.5, 'h': 0.8, 'lh': 0.7}}, 'wait': 8})
        shots.append({'name': 'p%02d_b' % int(f * 100), 'fov': 46, 'near': 2.0, 'cam': {'orbit': {'a': 165, 'r': 12, 'h': 4.0, 'lh': 0.9}}, 'wait': 3})
    j = {'mode': 'world', 'out': os.path.join(out_dir, name), 'car': car, 'cfg': cfg, 'view_at': 0.0, 'shots': shots}
    json.dump(j, open(os.path.join(jobs_dir, 'survey_%s.json' % name), 'w'), indent=1)
print(len(SCENES), 'recorridos')
