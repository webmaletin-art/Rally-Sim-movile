"""Datos de los 26 autos para encuadrar las fotos del tráiler: largo, alto, entre ejes, trocha y nombre (de tools/cars/final_cars.py y vehicles.json)."""
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'cars'))
import final_cars  # noqa: E402

VEH = json.load(open(os.path.join(ROOT, 'godot', 'game', 'data', 'vehicles.json')))
CAT = json.load(open(os.path.join(ROOT, 'godot', 'game', 'data', 'catalog.json')))
ORDER = CAT['order']  # los 26, del más barato al más caro


def info(cid):
    m = final_cars.MODEL[cid]
    v = VEH[cid]
    c = CAT['cars'].get(cid, {})
    return {'id': cid, 'L': float(m['L']), 'H': float(m.get('H', 1.35)), 'wb': float(v['wheelBase']), 'trackF': float(v['trackF']), 'R': float(v['wheelRadius']),
            'name': str(v.get('name', cid)), 'price': int(c.get('price', 0))}


ALL = {cid: info(cid) for cid in ORDER}

if __name__ == '__main__':
    for cid in ORDER:
        i = ALL[cid]
        print('%-11s %-28s L %.2f H %.2f wb %.2f trackF %.2f R %.2f  $%d' % (cid, i['name'], i['L'], i['H'], i['wb'], i['trackF'], i['R'], i['price']))
