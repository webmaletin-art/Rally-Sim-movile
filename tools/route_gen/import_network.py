#!/usr/bin/env python3
"""Convierte una red de rutas del «Editor de RED» (formato dreamracing-network v1) al archivo compacto que lee el juego (godot/game/data/networks/<id>.json).
 · une los nodos a menos de 1 m y saca las calles de menos de 2 m (restos del editor);
 · suaviza los trazos a mano alzada (esquinas muy cerradas) y los vuelve a muestrear cada 12 m, con los extremos EXACTOS sobre los nodos;
 · guarda los puntos en decímetros (enteros) para que pese poco.
Uso: python3 tools/route_gen/import_network.py <red.json> [--out godot/game/data/networks/<id>.json]"""
import json, math, os, sys
import numpy as np

SURF = {'asphalt': 0, 'dirt': 1, 'gravel': 2, 'mud': 3, 'sand': 4}
ENV = {'rural': 0, 'forest': 1, 'desert': 2, 'periurban': 3, 'urban': 4}
STEP = 12.0

def resample(p, step):
    p = np.asarray(p, dtype=np.float64)
    seg = np.hypot(*(p[1:] - p[:-1]).T)
    cum = np.concatenate([[0], np.cumsum(seg)])
    L = cum[-1]
    n = max(2, int(round(L / step)) + 1)
    t = np.linspace(0, L, n)
    return np.stack([np.interp(t, cum, p[:, 0]), np.interp(t, cum, p[:, 1])], 1), L

def smooth(p, passes=10):
    q = p.copy()
    for _ in range(passes):
        q[1:-1] = (q[:-2] + 2 * q[1:-1] + q[2:]) / 4.0
    return q

def main():
    src = sys.argv[1]
    out = sys.argv[sys.argv.index('--out') + 1] if '--out' in sys.argv else None
    d = json.load(open(src, encoding='utf-8'))
    assert d.get('format') == 'dreamracing-network', 'no es una red'
    nodes = {n['id']: n for n in d['nodes']}
    # unir nodos a menos de 1 m
    parent = {k: k for k in nodes}
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    ids = list(nodes)
    for i, a in enumerate(ids):
        for b in ids[i + 1:]:
            if math.dist((nodes[a]['x'], nodes[a]['z']), (nodes[b]['x'], nodes[b]['z'])) < 1.0:
                parent[find(b)] = find(a)
    edges = []
    for e in d['edges']:
        pts = np.asarray(e['pts'], dtype=np.float64)
        L = float(np.hypot(*(pts[1:] - pts[:-1]).T).sum())
        a, b = find(e['a']), find(e['b'])
        if L < 2.0:
            parent[find(b)] = find(a) # calle de restos: sus dos puntas pasan a ser el mismo nodo
            continue
        edges.append((e, a, b))
    # tras unir las puntas de las calles chiquitas, recalcular
    edges = [(e, find(e['a']), find(e['b'])) for e, _, _ in edges]
    used = sorted({x for _, a, b in edges for x in (a, b)} | {r for r in []})
    # nodos de la red final (los de los extremos de calles que quedaron)
    out_nodes = {}
    for nid in used:
        n = nodes[nid]
        out_nodes[nid] = [nid, round(n['x'], 1), round(n['z'], 1), n['kind']]
    out_edges = []
    total = 0.0
    for e, a, b in edges:
        p, _ = resample(e['pts'], 6.0)
        p = smooth(p)
        p, L = resample(p, STEP)
        p[0] = [out_nodes[a][1], out_nodes[a][2]]
        p[-1] = [out_nodes[b][1], out_nodes[b][2]]
        total += L
        flat = [int(round(v * 10)) for q in p for v in q]
        out_edges.append([e['id'], a, b, SURF.get(e['surface'], 0), float(e['widthM']), ENV.get(e['env'], 0), flat])
    rb = []
    for r in d.get('roundabouts', []):
        rb.append({'id': r['id'], 'x': r['x'], 'z': r['z'], 'r': r['radius'], 'w': r['widthM'], 'surf': SURF.get(r['surface'], 0), 'env': ENV.get(r.get('env', 'rural'), 0), 'ccw': r.get('direction', 'ccw') == 'ccw', 'island': bool(r.get('island', True))})
    st = [{'id': s['id'], 'name': s['name'], 'x': s['x'], 'z': s['z'], 'services': s.get('services', [])} for s in d.get('stations', [])]
    bb = d['bbox']
    res = {'id': d['id'], 'name': d['name'], 'bbox': [bb['minX'], bb['minZ'], bb['maxX'], bb['maxZ']], 'step': STEP, 'nodes': list(out_nodes.values()), 'edges': out_edges, 'roundabouts': rb, 'stations': st,
           'km': round(total / 1000, 1)}
    if out is None:
        out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'godot', 'game', 'data', 'networks', d['id'] + '.json')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    json.dump(res, open(out, 'w'), separators=(',', ':'))
    print('%s: %d nodos, %d calles (%.1f km), %d rotondas, %d estaciones → %s (%.2f MB)' % (d['name'], len(out_nodes), len(out_edges), total / 1000, len(rb), len(st), os.path.relpath(out), os.path.getsize(out) / 1e6))

if __name__ == '__main__':
    main()
