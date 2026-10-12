#!/usr/bin/env python3
"""Revisa un archivo del «Editor de RED de rutas» (formato dreamracing-network v1, ver PROMPT_EDITOR_RED.md): nodos, calles, rotondas, estaciones.
Uso: python3 tools/route_gen/validate_network.py red_1.json"""
import json, math, sys, collections

def main(path):
    d = json.load(open(path, encoding='utf-8'))
    assert d.get('format') == 'dreamracing-network', 'no es una red (format dreamracing-network)'
    nodes = {n['id']: n for n in d['nodes']}
    edges = d['edges']
    errs, warns = [], []
    deg = collections.Counter()
    total = 0.0
    by = collections.defaultdict(float)
    tiny, long_gap = [], []
    for e in edges:
        for k in ('a', 'b'):
            if e[k] not in nodes:
                errs.append('calle %s: nodo %s no existe' % (e['id'], e[k]))
            else:
                deg[e[k]] += 1
        pts = e['pts']
        L = sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))
        total += L
        by[e['surface']] += L
        if L < 2.0:
            tiny.append((e['id'], round(L, 2)))
        mx = max((math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1)), default=0)
        if mx > 80:
            long_gap.append((e['id'], round(mx)))
        a, b = nodes.get(e['a']), nodes.get(e['b'])
        if a and math.dist((a['x'], a['z']), pts[0]) > 0.5:
            errs.append('calle %s: el primer punto no coincide con el nodo %s' % (e['id'], e['a']))
        if b and math.dist((b['x'], b['z']), pts[-1]) > 0.5:
            errs.append('calle %s: el último punto no coincide con el nodo %s' % (e['id'], e['b']))
    # nodos sueltos / grado vs tipo
    for nid, n in nodes.items():
        g = deg[nid]
        if g == 0:
            warns.append('nodo %s (%s) sin calles' % (nid, n['kind']))
        elif n['kind'] == 'junction' and g < 3:
            warns.append('nodo %s marcado junction con %d calle(s)' % (nid, g))
        elif n['kind'] == 'end' and g > 1:
            warns.append('nodo %s marcado end con %d calles' % (nid, g))
    # componentes conexas
    adj = collections.defaultdict(set)
    for e in edges:
        adj[e['a']].add(e['b'])
        adj[e['b']].add(e['a'])
    for r in d.get('roundabouts', []):
        pe = [p['edge'] for p in r['ports']]
        ids = {e['id']: e for e in edges}
        ns = [ids[x]['a' if p['end'] == 'a' else 'b'] for x, p in zip(pe, r['ports']) if x in ids]
        for i in range(len(ns)):
            for j in range(i + 1, len(ns)):
                adj[ns[i]].add(ns[j])
                adj[ns[j]].add(ns[i])
    seen, comps = set(), []
    for n in nodes:
        if n in seen:
            continue
        st, comp = [n], set()
        while st:
            x = st.pop()
            if x in comp:
                continue
            comp.add(x)
            st.extend(adj[x] - comp)
        seen |= comp
        comps.append(comp)
    comps.sort(key=len, reverse=True)
    print('%s · %d nodos · %d calles · %d rotondas · %d estaciones' % (d['name'], len(nodes), len(edges), len(d.get('roundabouts', [])), len(d.get('stations', []))))
    print('largo total %.1f km (%s)' % (total / 1000, ' · '.join('%s %.1f km' % (k, v / 1000) for k, v in by.items())))
    bb = d['bbox']
    print('caja: %.1f × %.1f km' % ((bb['maxX'] - bb['minX']) / 1000, (bb['maxZ'] - bb['minZ']) / 1000))
    print('partes sueltas (conectadas entre sí): %d  (nodos por parte: %s)' % (len(comps), [len(c) for c in comps][:12]))
    print('calles de menos de 2 m (suelen ser restos del editor): %s' % tiny)
    print('saltos de más de 80 m entre puntos: %s' % long_gap[:10])
    print('cursos: %d · largadas: %d · zonas: %d' % (len(d.get('courses', [])), len(d.get('starts', [])), len(d.get('zones', []))))
    for w in warns[:15]:
        print('AVISO', w)
    for e in errs[:15]:
        print('ERROR', e)
    print('%d errores · %d avisos' % (len(errs), len(warns)))
    return 1 if errs else 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
