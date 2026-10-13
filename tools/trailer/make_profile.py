#!/usr/bin/env python3
"""Perfil de «vitrina» para sacar las pantallas del menú del tráiler: los 26 autos en el garaje, plata, nivel, medallas de oro en las copas, aventura avanzada y todo desbloqueado.
Uso: python3 tools/trailer/make_profile.py /carpeta_home   → deja el perfil en /carpeta_home/godot/app_userdata/GSkorp Rally/profile.json (se usa con XDG_DATA_HOME=/carpeta_home)"""
import json
import os
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
home = sys.argv[1]
CAT = json.load(open(os.path.join(ROOT, 'godot', 'game', 'data', 'catalog.json')))
udir = os.path.join(home, 'godot', 'app_userdata', 'GSkorp Rally')
os.makedirs(udir, exist_ok=True)

owned = {}
for i, cid in enumerate(CAT['order']):
    paint = dict(CAT['cars'][cid].get('paint', {'body': '#1a4fe0', 'accent': '#f5f5f2', 'rim': '#16181c'}))
    owned[cid] = {'upg': {'engine': 2, 'brakes': 2, 'suspension': 2} if i % 3 == 0 else {}, 'tires': 'street', 'tiresOwned': ['street'], 'tune': {}, 'paint': paint, 'km': 120.0 + 37.0 * i, 'bought': time.time() - 86400 * (30 - i)}
events = {}
for k, ev in enumerate(CAT['events']):
    medal = 3 if k % 5 != 3 else 2
    events[ev['id']] = {'medal': medal, 'best': 1.0, 'done': True, 'plays': 2 + k % 3}
profile = {
    'v': 1, 'name': 'Piloto', 'credits': 245000, 'fuel': 1.0, 'toll_pass': 0, 'migr': 1, 'xp': 21000, 'level': 24, 'owned': owned, 'current': 'hyper', 'events': events, 'cups': {},
    'stats': {'km': 12850.0, 'races': 148, 'wins': 61, 'podiums': 98, 'events': 70, 'driftBest': 48300, 'topSpeed': 312, 'boards': {}, 'traps': {}, 'time': 150000.0},
    'iap': {'dr_full': True}, 'daily': {'day': time.strftime('%Y-%m-%d'), 'streak': 5}, 'claimed': {}, 'created': time.time() - 86400 * 60, 'tutorial': True,
    'consent': {'v': 99, 'ts': time.time()},
    'adv': {'stage': 7, 'points': 14, 'skills': {'curve': 3, 'launch': 2, 'brake': 2, 'control': 3, 'armor': 1}, 'tune': {}, 'tires': 'street', 'damage': {'motor': 0.0, 'dir': 0.0, 'susp': 0.0},
            'pull': 1.0, 'intro': True, 'best': {}, 'tries': 3, 'done': False, 'started': True},
    'settings': {'lang': 'es', 'autotuned': True, 'gfxMode': 'manual', 'quality': 'high', 'res': 1.0, 'frameRes': 0, 'trees': 6000, 'shadowsQ': True, 'textures': 'high', 'particles': 10, 'capBtn': False, 'musicMode': 'off'},
}
json.dump(profile, open(os.path.join(udir, 'profile.json'), 'w'))
print('perfil en', udir)
