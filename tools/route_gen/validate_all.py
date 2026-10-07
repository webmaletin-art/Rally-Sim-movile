#!/usr/bin/env python3
"""Valida TODOS los mapas de godot/game/data/custom_maps (lo corre la CI: un archivo roto frena la compilación antes de llegar al teléfono)."""
import glob, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import route_spec as S

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
files = sorted(glob.glob(os.path.join(ROOT, "godot", "game", "data", "custom_maps", "*.json")))
cat = json.load(open(os.path.join(ROOT, "godot", "game", "data", "catalog.json"), encoding="utf-8"))
event_ids = {e["id"] for e in cat["events"]}
bad = 0
ids = set()
for f in files:
    name = os.path.basename(f)
    try:
        d = json.load(open(f, encoding="utf-8"))
    except Exception as ex:
        print(f"❌ {name}: no es un JSON válido ({ex})")
        bad += 1
        continue
    e, w, info = S.validate(d)
    if d.get("version") not in (2, 3):
        e.append("el archivo tiene que ser versión 2 o 3 (convertilo con tools/route_gen/import_route.py)")
    if d.get("id") != name[:-5]:
        e.append(f"el archivo se tiene que llamar {d.get('id')}.json")
    if d.get("id") in ids:
        e.append("id repetido")
    ids.add(d.get("id"))
    ev = (d.get("career") or {}).get("event")
    if ev and ev not in event_ids:
        e.append(f"career.event «{ev}» no existe")
    for m in e:
        print(f"❌ {name}: {m}")
    for m in w:
        print(f"⚠ {name}: {m}")
    print(("✔" if not e else "✖"), name, {k: round(v, 1) for k, v in info.items()})
    bad += 1 if e else 0
print(f"{len(files)} mapa(s), {bad} con errores")
sys.exit(1 if bad else 0)
