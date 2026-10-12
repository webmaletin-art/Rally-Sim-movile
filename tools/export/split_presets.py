#!/usr/bin/env python3
"""Parte el contenido del juego en dos paquetes para que el APK liviano baje por separado lo pesado:
  · content.pck  = todo menos godot/game/models/cars/ (preset «Content»)
  · cars.pck     = solo las carrocerías de los autos con su textura, sin reducir (preset «Cars»), de ~500 MB; cambia poco, así que se baja una vez
Godot filtra por carpetas con patrones, no se puede decir «solo esta carpeta»: se arma la lista de exclusión de «Cars» con todo lo demás.
Uso (lo corre la compilación antes de exportar): python3 tools/export/split_presets.py"""
import os, re, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
G = os.path.join(ROOT, 'godot')
CFG = os.path.join(G, 'export_presets.cfg')
KEEP = 'game/models/cars'
SKIP = {'.godot', '.git', 'export'}

def others():
    """patrones que dejan afuera todo menos KEEP (carpetas enteras donde se puede, archivos sueltos en las carpetas que contienen a KEEP)"""
    pats = []
    parents = set()
    p = KEEP
    while p:
        parents.add(p)
        p = os.path.dirname(p)
    parents.add('')
    def walk(rel):
        full = os.path.join(G, rel)
        for name in sorted(os.listdir(full)):
            if name in SKIP:
                continue
            r = (rel + '/' + name) if rel else name
            if os.path.isdir(os.path.join(G, r)):
                if r == KEEP:
                    continue
                if r in parents:
                    walk(r)
                else:
                    pats.append(r + '/*')
            else:
                pats.append(r)
    walk('')
    return pats

def main():
    s = open(CFG, encoding='utf-8').read()
    m = re.search(r'\[preset\.2\]\n.*?(?=\n\[preset\.3\])', s, re.S)
    assert m, 'no encuentro el preset Content'
    content = m.group(0)
    s = s.replace(content, re.sub(r'exclude_filter="[^"]*"', 'exclude_filter="bootstrap/*, tests/*, keystore/*, %s/*"' % KEEP, content, count=1))
    cars = re.sub(r'\[preset\.2', '[preset.4', content)
    cars = cars.replace('name="Content"', 'name="Cars"').replace('../build/content.pck', '../build/cars.pck')
    ex = ['bootstrap/*', 'tests/*', 'keystore/*'] + others()
    cars = re.sub(r'exclude_filter="[^"]*"', lambda _m: 'exclude_filter="%s"' % ', '.join(ex), cars, count=1)
    cars = re.sub(r'include_filter="[^"]*"', 'include_filter="*.json"', cars, count=1)
    s = re.sub(r'\n\[preset\.4\].*', '', s, flags=re.S).rstrip('\n') + '\n\n' + cars.rstrip('\n') + '\n'
    open(CFG, 'w', encoding='utf-8').write(s)
    print('Cars: %d patrones de exclusión' % len(ex))

if __name__ == '__main__':
    main()
