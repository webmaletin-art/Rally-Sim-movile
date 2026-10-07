#!/usr/bin/env python3
"""Mete una ruta exportada por el generador HTML (formato «dreamracing-route» v1) en el juego:
  · la valida (route_spec.py) y se niega si no sirve;
  · la agrega a godot/game/data/routes.json (ruta) y a «maps» (mapa; con --reverse también la versión inversa «<id>Rev»);
  · con --event <id> hace que un evento de la carrera use ese mapa (con sus vueltas o su tramo).
Uso: python3 tools/route_gen/import_route.py ruta.json [--event c1] [--reverse] [--replace] [--dry-run]"""
import argparse, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import route_spec as S

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
ROUTES = os.path.join(ROOT, "godot", "game", "data", "routes.json")
CATALOG = os.path.join(ROOT, "godot", "game", "data", "catalog.json")

def dump(path, d):
    open(path, "w", encoding="utf-8").write(json.dumps(d, ensure_ascii=False, separators=(",", ":")))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--event", default="")
    ap.add_argument("--reverse", action="store_true")
    ap.add_argument("--replace", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    doc = json.load(open(a.file, encoding="utf-8"))
    errs, warns, info = S.validate(doc)
    for m in warns:
        print("⚠", m)
    if errs:
        for m in errs:
            print("❌", m)
        sys.exit("La ruta no pasa la validación: no se importó nada.")
    if doc["type"] == "drag":
        sys.exit("Las picadas (drag) todavía se integran a mano: pasame el archivo y lo adapto (la picada usa un óvalo fijo, ver docs/RUTAS_NUEVAS.md).")
    rid = doc["id"]
    routes = json.load(open(ROUTES, encoding="utf-8"))
    if (rid in routes["routes"] or rid in routes["maps"]) and not a.replace:
        sys.exit(f"Ya existe «{rid}» (usá --replace para reemplazarla).")
    r = doc["route"]
    routes["routes"][rid] = {"halfWidth": r["halfWidth"], "shoulder": r["shoulder"], "points": r["points"], "custom": True}
    m = {"name": doc["name"], "icon": doc.get("icon", "🏁"), "kind": "route", "route": rid, "mode": doc["surface"], "custom": True}
    if doc.get("scenery"):
        m["scenery"] = doc["scenery"]
    routes["maps"][rid] = m
    if a.reverse:
        routes["maps"][rid + "Rev"] = dict(m, name=doc["name"] + " (inversa)", reverse=True)
    print(f"ruta «{rid}»: {info['length']:.0f} m de lazo · radio mínimo {info['min_radius']:.0f} m · pendiente máx. {info['max_slope'] * 100:.1f} %")
    if a.event:
        cat = json.load(open(CATALOG, encoding="utf-8"))
        ev = next((e for e in cat["events"] if e["id"] == a.event), None)
        if ev is None:
            sys.exit(f"No existe el evento «{a.event}».")
        ev["map"] = rid
        if doc["type"] == "circuit":
            ev["laps"] = doc["race"]["laps"]
            ev.pop("seg", None)
        else:
            ev["seg"] = doc["race"]["seg"]
            ev.pop("laps", None)
        print(f"evento {a.event} «{ev['name']}» ahora corre en «{doc['name']}»")
        if not a.dry_run:
            dump(CATALOG, cat)
    if not a.dry_run:
        dump(ROUTES, routes)
        print("listo: routes.json actualizado. Siguiente: godot --headless --path godot --script res://tests/custom_route_test.gd -- --id=" + rid)
    else:
        print("(dry-run: no se escribió nada)")

if __name__ == "__main__":
    main()
