#!/usr/bin/env python3
"""Corre trabajos del director del tráiler (godot/tests/trailer/director.gd) con pantalla virtual, de a uno o varios en paralelo.
Uso: python3 tools/trailer/run_jobs.py [--par 2] [--res 1920x1080] trabajo1.json trabajo2.json …
Cada trabajo deja sus fotos en la carpeta `out` que dice el JSON y un renglón en el registro (jobs.log junto al JSON)."""
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
GODOT = os.environ.get('GODOT', '/tmp/godot/Godot_v4.4.1-stable_linux.x86_64')
PROJECT = os.environ.get('GODOT_PROJECT', os.path.join(ROOT, 'godot'))  # otra copia del proyecto (por ejemplo con datos viejos para comparar)


def run(job, res):
    w, h = res.split('x')
    t0 = time.time()
    log = job[:-5] + '.log'
    cmd = ['xvfb-run', '-a', '-s', '-screen 0 %sx%sx24' % (w, h), GODOT, '--path', PROJECT, '--rendering-driver', 'opengl3', '--resolution', res,
           '--script', 'res://tests/trailer/director.gd', '--', '--job=' + job]
    with open(log, 'w') as f:
        p = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, timeout=3 * 3600)
    txt = open(log, errors='replace').read()
    ok = 'director:' in txt and 'fotos en' in txt
    err = [l for l in txt.splitlines() if 'SCRIPT ERROR' in l or 'Parse Error' in l][:3]
    print('%s %-40s %5.0f s %s' % ('OK  ' if ok else 'FALLA', os.path.basename(job), time.time() - t0, ' | '.join(err)), flush=True)
    return ok


def main():
    par = 2
    res = '1920x1080'
    jobs = []
    a = sys.argv[1:]
    i = 0
    while i < len(a):
        if a[i] == '--par':
            par = int(a[i + 1]); i += 2
        elif a[i] == '--res':
            res = a[i + 1]; i += 2
        else:
            jobs.append(os.path.abspath(a[i])); i += 1
    with ThreadPoolExecutor(max_workers=par) as ex:
        results = list(ex.map(lambda j: run(j, res), jobs))
    sys.exit(0 if all(results) else 1)


if __name__ == '__main__':
    main()
