#!/usr/bin/env python3
"""Genera godot/game/data/vehicles.json y catalog.json con la lista DEFINITIVA de autos (final_specs.py), a partir de las medidas de cada carrocería (models/cars/<id>.json).
Borra los autos que ya no están (Zorro Pampa X, Volcán, Original, T1+ de la tienda). El T1+ queda solo como ficha de física OCULTA (la usan la IA y las pruebas contra la versión HTML).
Uso: python3 tools/cars/make_final_vehicles.py"""
import json, os, copy, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_vehicles as MV
import final_specs as FS
import final_cars as FC
import final_wheels as FW

DATA = MV.DATA
MODELS = MV.MODELS

def main():
    vp = os.path.join(DATA, 'vehicles.json')
    cp = os.path.join(DATA, 'catalog.json')
    v = json.load(open(vp))
    cat = json.load(open(cp))
    final = list(FS.ORDER)
    # autos de la versión HTML (pickup, camión, Bisonte): se conserva la física y las medidas; el modelo se ajusta a ellas
    for cid in ('pickup', 'truck', 'genesis'):
        meta = json.load(open(os.path.join(MODELS, cid + '.json')))
        p = v[cid]
        print('%-7s entre ejes %.3f (físico %.3f) · R %.3f (%.3f)' % (cid, meta['wheelbase'], p['wheelBase'], meta['R'], p['wheelRadius']))
        assert abs(meta['wheelbase'] - p['wheelBase']) < 0.02 and abs(meta['R'] - p['wheelRadius']) < 0.01 and abs(meta['weightFront'] - p['weightFront']) < 0.01
        v[cid]['visualType'] = cid
    for cid in final:
        if cid in ('pickup', 'truck', 'genesis'):
            continue
        meta = json.load(open(os.path.join(MODELS, cid + '.json')))
        v[cid] = MV.build_entry(cid, FS.SPEC[cid], meta, v)
        cat['cars'][cid] = dict(FS.SPEC[cid]['cat'])
    # ficha de tienda de los de la versión HTML: solo el precio
    for cid in ('pickup', 'truck', 'genesis'):
        cat['cars'][cid]['price'] = FS.PRICE[cid]
    # el único auto inicial es el más lento y fácil de comprar
    for cid, c in cat['cars'].items():
        c.pop('starter', None)
    cat['cars'][FS.STARTER]['starter'] = True
    # pintura de fábrica: la textura original (rotulado 11)
    for cid in final:
        cat['cars'][cid].setdefault('paint', {})['livery'] = 11
    for cid, col in FW.RIM.items():
        cat['cars'][cid]['paint']['rim'] = col
    # fuera los que no están en la lista
    for cid in list(cat['cars']):
        if cid not in final:
            del cat['cars'][cid]
    for cid in list(v):
        if cid not in final and cid != 't1plus':
            del v[cid]
    v['t1plus']['hidden'] = True        # solo física (IA y pruebas); no está en la tienda ni en el garaje
    cat['order'] = final
    json.dump(v, open(vp, 'w'), ensure_ascii=False, indent=1)
    json.dump(cat, open(cp, 'w'), ensure_ascii=False, separators=(',', ':'))
    print('vehicles:', list(v), '\norden:', cat['order'])

if __name__ == '__main__':
    main()
