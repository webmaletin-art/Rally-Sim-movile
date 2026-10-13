#!/usr/bin/env python3
"""Tomas de ACCIÓN del tráiler: el auto maneja solo (la IA del juego) por cada mapa y la cámara lo sigue con polvo, barro y derrapes en el aire. A diferencia del recorrido
(make_survey.py: el auto quieto cada 5 % del trayecto) acá el auto corre `sim` segundos antes de cada foto, así que se ven las partículas.
Uso: python3 tools/trailer/make_action.py /carpeta_de_trabajos /carpeta_de_fotos [mapa …]"""
import json
import os
import sys

jobs_dir, out_dir = sys.argv[1], sys.argv[2]
only = sys.argv[3:]
os.makedirs(jobs_dir, exist_ok=True)

# cámaras (relativas al auto, que va corriendo): nombre, orbit, fov. a = ángulo (0 = adelante mirándolo, 180 = atrás)
CAMS = [
    ('front_low', {'orbit': {'a': 22, 'r': 4.4, 'h': 0.42, 'lh': 0.7}}, 62),
    ('side', {'orbit': {'a': 88, 'r': 6.8, 'h': 0.85, 'lh': 0.75}}, 32),
    ('rear_dust', {'orbit': {'a': 172, 'r': 6.2, 'h': 1.0, 'lh': 0.9}}, 50),
    ('front_high', {'orbit': {'a': 36, 'r': 7.6, 'h': 2.4, 'lh': 0.6}}, 40),
    ('head_on', {'orbit': {'a': 5, 'r': 5.2, 'h': 0.55, 'lh': 0.75}}, 56),
]
# (nombre, auto, configuración de la carrera, posiciones del trayecto)
rt = lambda track, sky='day', **k: dict({'type': 'race', 'track': track, 'ai': 0, 'laps': 1, 'sky': sky}, **k)
SCENES = [
    ('forest_sunset', 'rally80', rt('forest', 'sunset'), [0.12, 0.40, 0.70]),
    ('forest_day', 'pickup', rt('forest', 'day'), [0.15, 0.45, 0.75]),
    ('forest_rain', 'kodiak', rt('forest', 'rain'), [0.20, 0.55]),
    ('lake_dusk', 'gt', rt('lake', 'dusk'), [0.15, 0.50, 0.80]),
    ('quarry_day', 'buggy', rt('quarry', 'day'), [0.18, 0.50]),
    ('mountain_sunset', 'veltor', rt('asphaltLong', 'sunset'), [0.20, 0.55, 0.85]),
    ('descent_day', 'trilux_s', rt('descent', 'day'), [0.20, 0.60]),
    ('dream', 'hyper', rt('dream', 'day'), [0.10, 0.45, 0.80]),
    ('anillo', 'veltor_gtr', rt('anillo', 'day'), [0.10, 0.45, 0.80]),
    ('marte', 'muscle', rt('marte', 'day'), [0.10, 0.50]),
    ('luna', 'gt3', rt('luna', 'day'), [0.10, 0.50]),
    ('paper', 'hatch2', rt('paperRace', 'day'), [0.10, 0.50]),
    ('travesia', 'pickup', {'type': 'race', 'track': 'travesia', 'convoy': True, 'ai': 5, 'laps': 1, 'sky': 'day', 'quick': True}, [0.10, 0.35, 0.60]),
]
for name, car, cfg, fracs in SCENES:
    if only and name not in only:
        continue
    for k, f in enumerate(fracs):
        # un trabajo por lugar: `view_at` arranca la carrera ahí y la IA sigue la ruta (después de un teletransporte la IA se perdería)
        shots = []
        for ci, (cn, cam, fov) in enumerate(CAMS):
            s = {'name': 'a%d_%s' % (k, cn), 'fov': fov, 'near': 1.2, 'cam': cam, 'wait': 3}
            if ci == 0:
                s['sim'] = 5.0  # el auto arranca y agarra velocidad (sin dibujar)
                s['warm'] = 1.5  # el último segundo y medio sí se dibuja: polvo y barro en el aire
            else:
                s['sim'] = 0.8
                s['warm'] = 0.8
            shots.append(s)
        j = {'mode': 'world', 'out': os.path.join(out_dir, name), 'car': car, 'cfg': cfg, 'auto': True, 'view_at': f, 'shots': shots}
        json.dump(j, open(os.path.join(jobs_dir, 'action_%s_%d.json' % (name, k)), 'w'), indent=1)
print('listo')
