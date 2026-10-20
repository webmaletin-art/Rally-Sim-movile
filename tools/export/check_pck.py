#!/usr/bin/env python3
"""Controla que un .pck exportado lleve los archivos de datos que Godot NO exporta solo (los que no son recursos: .bin, .dat…).
Pasó con region_1.bin: andaba en la PC pero el APK no lo traía (include_filter sólo tenía *.pap y *.txt) y la región no aparecía en el juego.
Uso: python3 tools/export/check_pck.py build/content.pck   (sale con error si falta algo)"""
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RAW_EXT = ('.bin', '.dat', '.bytes')
EXTRA = ['game/data/region/spawns.json', 'game/data/networks/red_1.json']


def required():
    out = subprocess.run(['git', 'ls-files', 'godot'], cwd=ROOT, capture_output=True, text=True, check=True).stdout.split('\n')
    req = [p[len('godot/'):] for p in out if p.endswith(RAW_EXT)]
    # El marcador de la versión candidata lo escribe el flujo (build-godot.yml, paso «Marcar la versión candidata») sólo fuera de main: si está en la carpeta, tiene que estar en el pck
    # (sin él la RC perdería el modo desarrollador y «COPIAR REGISTRO»; ver Release.internal()).
    if os.path.exists(os.path.join(ROOT, 'godot', 'game', 'build_channel.txt')):
        req.append('game/build_channel.txt')
    return sorted(set(req + EXTRA))


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    data = open(argv[1], 'rb').read()
    missing = [p for p in required() if p.encode() not in data]
    for p in required():
        print(('FALTA  ' if p in missing else 'ok     ') + p)
    if missing:
        print('ERROR: el pck no trae %d archivo(s) de datos: revisá include_filter de export_presets.cfg' % len(missing))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
