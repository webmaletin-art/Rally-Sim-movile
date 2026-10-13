#!/usr/bin/env python3
"""Trabajos de estudio del tráiler: los 26 autos en la sala de exhibición (retrato, perfil, trasera, frente, rueda), vueltas completas («giradiscos») y pintura.
Uso: python3 tools/trailer/make_studio_jobs.py /carpeta_de_trabajos /carpeta_de_fotos [--only id,id]"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cars_info  # noqa: E402

jobs_dir, out_dir = sys.argv[1], sys.argv[2]
only = None
if '--only' in sys.argv:
    only = sys.argv[sys.argv.index('--only') + 1].split(',')
os.makedirs(jobs_dir, exist_ok=True)

PAINTS = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'paint_styles.json')))


def orbit(a, r, h, lh, fov, **kw):
    o = {'a': a, 'r': round(r, 2), 'h': round(h, 2), 'lh': round(lh, 2)}
    o.update(kw)
    return {'fov': fov, 'cam': {'orbit': o}}


def framing(i):
    L, H = i['L'], i['H']
    return {'r': max(6.4, 1.62 * L + 1.1), 'h': 0.26 * H + 0.45, 'lh': 0.36 * H + 0.04}


def portraits(i):
    f = framing(i)
    L, H = i['L'], i['H']
    cid = i['id']
    s = []
    s.append(dict(name='line_' + cid, wait=3, **orbit(38, f['r'], f['h'], f['lh'], 30)))
    s.append(dict(name='hero_' + cid, wait=3, **orbit(28, f['r'] * 0.88, 0.32 + 0.12 * H, f['lh'] * 0.95, 27)))
    s.append(dict(name='side_' + cid, wait=3, **orbit(90, f['r'] * 1.12, 0.22 * H + 0.35, f['lh'] * 0.98, 24)))
    s.append(dict(name='rear_' + cid, wait=3, **orbit(148, f['r'] * 0.95, f['h'] + 0.15, f['lh'], 30)))
    s.append(dict(name='front_' + cid, wait=3, **orbit(10, f['r'] * 0.78, 0.30 * H + 0.3, f['lh'], 32)))
    # rueda delantera derecha de cerca
    x = i['trackF'] / 2
    z = i['wb'] / 2
    s.append(dict(name='wheel_' + cid, wait=3, fov=30, cam={'rel': [x + 1.9, i['R'] + 0.15, z + 1.5], 'look': [x, i['R'] + 0.02, z]}))
    # faro / trompa en primer plano bajo
    s.append(dict(name='nose_' + cid, wait=3, fov=40, cam={'rel': [0.55, 0.30 * H + 0.1, L / 2 + 1.6], 'look': [0.0, 0.28 * H, L / 2 - 0.2]}))
    return s


for cid in cars_info.ORDER:
    if only and cid not in only:
        continue
    i = cars_info.ALL[cid]
    j = {'mode': 'studio', 'out': os.path.join(out_dir, cid), 'car': cid, 'lights': 'dramatic', 'shots': portraits(i)}
    json.dump(j, open(os.path.join(jobs_dir, 'studio_%s.json' % cid), 'w'), indent=1)

# vueltas completas de los autos «estrella» (36 cuadros) y de pintura (la misma pose con los 24 estilos)
TURN = ['hyper', 'veltor_gtr', 'gt3', 'rally80', 'genesis', 'muscle', 'kodiak', 'truck', 'moust', 'torito']
for cid in TURN:
    if only and cid not in only:
        continue
    i = cars_info.ALL[cid]
    f = framing(i)
    shot = dict(name='turn', wait=2, **orbit(0, f['r'] * 0.98, f['h'] + 0.1, f['lh'], 30))
    shot['cam']['orbit'].update({'a0': 0, 'a1': 360, 'n': 36})
    json.dump({'mode': 'studio', 'out': os.path.join(out_dir, 'turn_' + cid), 'car': cid, 'lights': 'dramatic', 'shots': [shot]}, open(os.path.join(jobs_dir, 'turn_%s.json' % cid), 'w'), indent=1)
print('listo')

# los 24 estilos de pintura de Garaje → Pintura → Estilos sobre un mismo auto y una misma cámara (para el «cambio de pintura» cuadro a cuadro)
for cid in ['moust', 'rally80', 'hyper']:
    if only and cid not in only:
        continue
    i = cars_info.ALL[cid]
    f = framing(i)
    shots = []
    for k, st in enumerate(PAINTS):
        pt = {'body': st['body'], 'accent': st['accent'], 'text': st['text'], 'livery': st['livery'], 'finish': st['finish']}
        shots.append(dict(name='paint_%02d' % k, paint=pt, wait=2, **orbit(34, f['r'] * 0.95, f['h'] + 0.05, f['lh'], 29)))
    json.dump({'mode': 'studio', 'out': os.path.join(out_dir, 'paint_' + cid), 'car': cid, 'lights': 'dramatic', 'shots': shots}, open(os.path.join(jobs_dir, 'paint_%s.json' % cid), 'w'), indent=1)
print('pinturas listas')
