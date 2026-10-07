#!/usr/bin/env python3
"""Mete una ruta exportada por el generador HTML (formato «dreamracing-route» v2; la v1 se convierte) en el juego:
  · la valida (route_spec.py) y se niega si no sirve;
  · la copia a godot/game/data/custom_maps/<id>.json: el juego lee esa carpeta solo al arrancar (aparece en Carrera rápida);
  · con --event <id> (y --tier) la hace reemplazar ese evento de la carrera; con --reverse agrega también la versión inversa.
(Si el archivo ya trae un bloque «career», se respeta; los argumentos lo pisan.)
Uso: python3 tools/route_gen/import_route.py ruta.json [--tier continental --event c1] [--reverse] [--replace] [--dry-run]"""
import argparse, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import route_spec as S

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DEST = os.path.join(ROOT, "godot", "game", "data", "custom_maps")
CATALOG = os.path.join(ROOT, "godot", "game", "data", "catalog.json")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--tier", default="")
    ap.add_argument("--event", default="")
    ap.add_argument("--reverse", action="store_true")
    ap.add_argument("--replace", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    doc = S.normalize(json.load(open(a.file, encoding="utf-8")))
    if a.event:
        cat = json.load(open(CATALOG, encoding="utf-8"))
        ev = next((e for e in cat["events"] if e["id"] == a.event), None)
        if ev is None:
            sys.exit(f"No existe el evento «{a.event}».")
        doc["career"] = dict(doc.get("career") or {}, tier=a.tier or ev["tier"], event=a.event)
        print(f"evento {a.event} «{ev['name']}» ({ev['tier']}) va a correr en «{doc['name']}»")
    if a.reverse:
        doc["reverse"] = True
    errs, warns, info = S.validate(doc)
    for m in warns:
        print("⚠", m)
    if errs:
        for m in errs:
            print("❌", m)
        sys.exit("La ruta no pasa la validación: no se importó nada.")
    if doc["type"] == "drag":
        sys.exit("Las picadas (drag) todavía se integran a mano: pasame el archivo y lo adapto (ver docs/RUTAS_NUEVAS.md).")
    path = os.path.join(DEST, doc["id"] + ".json")
    if os.path.exists(path) and not a.replace:
        sys.exit(f"Ya existe {os.path.relpath(path, ROOT)} (usá --replace para reemplazarla).")
    print(f"ruta «{doc['id']}»: {info['length']:.0f} m de lazo · {len(doc['sections'])} tramos · radio mínimo {info['min_radius']:.0f} m · pendiente máx. {info['max_slope'] * 100:.1f} %")
    if a.dry_run:
        print("(dry-run: no se escribió nada)")
        return
    os.makedirs(DEST, exist_ok=True)
    json.dump(doc, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("listo:", os.path.relpath(path, ROOT), "· siguiente: godot --headless --path godot --script res://tests/custom_route_test.gd -- --id=" + doc["id"])

if __name__ == "__main__":
    main()
