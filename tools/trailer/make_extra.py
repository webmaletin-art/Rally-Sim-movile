#!/usr/bin/env python3
"""Trabajos extra del tráiler: la Aventura corriendo (con el rival al lado), los pilotos con sus gestos (en la sala y al costado del camino), el derrape y la noche de Dream City.
Uso: python3 tools/trailer/make_extra.py /carpeta_de_trabajos /carpeta_de_fotos"""
import json
import os
import sys

jobs_dir, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(jobs_dir, exist_ok=True)


def dump(name, j):
    json.dump(j, open(os.path.join(jobs_dir, name + '.json'), 'w'), indent=1)


# ── La Aventura («La Ruta de los Sueños»): etapas con paisajes distintos, el auto maneja solo y el rival corre al lado ──
ADV_CAMS = [
    ('front_low', {'orbit': {'a': 24, 'r': 4.6, 'h': 0.5, 'lh': 0.8}}, 60),
    ('side', {'orbit': {'a': 86, 'r': 7.2, 'h': 0.9, 'lh': 0.85}}, 32),
    ('rear', {'orbit': {'a': 168, 'r': 6.8, 'h': 1.3, 'lh': 1.0}}, 48),
    ('high', {'orbit': {'a': 40, 'r': 9.5, 'h': 3.4, 'lh': 0.7}}, 40),
]
ADV = [(1, 0.35, 'girasoles'), (2, 0.40, 'rio_bosque'), (4, 0.30, 'tunel'), (7, 0.40, 'cantera'), (8, 0.40, 'lluvia'), (10, 0.35, 'nieve'), (11, 0.30, 'cumbre')]
for stage, at, nm in ADV:
    shots = []
    for ci, (cn, cam, fov) in enumerate(ADV_CAMS):
        shots.append({'name': '%s_%s' % (nm, cn), 'fov': fov, 'near': 1.2, 'cam': cam, 'wait': 3, 'sim': 6.0 if ci == 0 else 1.0, 'warm': 1.5 if ci == 0 else 0.8})
    dump('adv_%s' % nm, {'mode': 'world', 'out': os.path.join(out_dir, 'adv_' + nm), 'car': 'hatch', 'auto': True, 'cfg': {'type': 'adventure', 'stage': stage, 'back': 'home', 'at': at}, 'shots': shots})

# ── Pilotos: gestos de Mixamo junto al auto (sala) y al costado del camino (mundo) ──
GEST = [('Waving', 0.2), ('Standing_Greeting', 0.55), ('Standing_Fist_Pump', 0.95), ('Pointing', 0.65), ('Clapping', 0.6)]
for car in ['hyper', 'rally80', 'gt3']:
    shots = []
    for k, (clip, t) in enumerate(GEST):
        shots.append({'name': 'g%d_%s' % (k, clip), 'fov': 30, 'wait': 3, 'cam': {'orbit': {'a': 36 + 4 * k, 'r': 8.0, 'h': 1.15, 'lh': 0.95, 'lx': 1.0}},
                      'pilots': [{'clip': clip, 't': t, 'at': [3.0, 1.1], 'face': 'cam', 'h': 1.78}]})
    dump('pilots_studio_' + car, {'mode': 'studio', 'out': os.path.join(out_dir, 'pilots_' + car), 'car': car, 'lights': 'dramatic', 'shots': shots})

# al costado del camino: bosque al atardecer (como pw1) y la ruta de la montaña
for nm, car, cfg, at in [('forest_sunset', 'rally80', {'type': 'race', 'track': 'forest', 'ai': 0, 'laps': 1, 'sky': 'sunset'}, 0.33),
                         ('lake_dusk', 'gt', {'type': 'race', 'track': 'lake', 'ai': 0, 'laps': 1, 'sky': 'dusk'}, 0.50),
                         ('dream', 'hyper', {'type': 'race', 'track': 'dream', 'ai': 0, 'laps': 1, 'sky': 'day'}, 0.28)]:
    shots = []
    for k, (clip, t) in enumerate(GEST):
        shots.append({'name': 'w%d_%s' % (k, clip), 'fov': 38, 'near': 1.5, 'wait': 6, 'cam': {'orbit': {'a': 38 + 7 * k, 'r': 10.5, 'h': 1.3, 'lh': 1.0}},
                      'pilots': [{'clip': clip, 't': t, 'at': [3.6, 1.6], 'face': 'cam', 'h': 1.78}, {'clip': GEST[(k + 2) % len(GEST)][0], 't': GEST[(k + 2) % len(GEST)][1], 'at': [3.0, -1.6], 'face': 'cam', 'h': 1.68}]})
    dump('pilots_world_' + nm, {'mode': 'world', 'out': os.path.join(out_dir, 'pilots_world_' + nm), 'car': car, 'cfg': cfg, 'view_at': at, 'shots': shots})

# ── Derrape (el mapa de drift del juego) y picada ──
DR = [('front_low', {'orbit': {'a': 28, 'r': 5.2, 'h': 0.5, 'lh': 0.7}}, 58), ('side', {'orbit': {'a': 80, 'r': 7.5, 'h': 0.9, 'lh': 0.8}}, 32), ('rear', {'orbit': {'a': 165, 'r': 7.0, 'h': 1.4, 'lh': 0.9}}, 48), ('high', {'orbit': {'a': 40, 'r': 11.0, 'h': 4.5, 'lh': 0.6}}, 42)]
shots = []
for k in range(4):
    for ci, (cn, cam, fov) in enumerate(DR):
        shots.append({'name': 'd%d_%s' % (k, cn), 'fov': fov, 'near': 1.2, 'cam': cam, 'wait': 3, 'sim': 5.0 if ci == 0 else 0.7, 'warm': 1.5 if ci == 0 else 0.7})
dump('drift', {'mode': 'world', 'out': os.path.join(out_dir, 'drift'), 'car': 'torito', 'auto': True, 'cfg': {'type': 'drift', 'track': 'drift', 'ai': 0, 'sky': 'sunset'}, 'shots': shots})

print('listo')
