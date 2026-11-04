#!/usr/bin/env python3
"""Imágenes de la ficha de Play (idioma predeterminado) según store_listing/imagenes_alpha.json: ícono, gráfico de funciones y capturas de teléfono, EN ESE ORDEN.

  python3 tools/play/listing_images.py check                    → controla tamaños y formatos (sin red)
  python3 tools/play/listing_images.py upload                   → ensayo: sube a una edición temporal, la valida y la BORRA (no cambia nada en Play)
  python3 tools/play/listing_images.py upload --confirm IMAGENES → confirma (reemplaza SÓLO esos tres tipos de imagen del idioma predeterminado)

No toca textos, vídeo, pistas, versiones ni testers, y no borra ningún archivo del repositorio."""
import argparse
import json
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(__file__))
from play_common import ROOT, build_service, explain_http_error, fail, load_config, masked_account, service_account_info  # noqa: E402


def size_of(path):
    with open(path, "rb") as f:
        head = f.read(26)
        if head[:8] == b"\x89PNG\r\n\x1a\n":
            return struct.unpack(">II", head[16:24])
        f.seek(2)
        while True:
            b = f.read(1)
            while b and b != b"\xff":
                b = f.read(1)
            while b == b"\xff":
                b = f.read(1)
            if b and b[0] in (0xC0, 0xC1, 0xC2):
                f.read(3)
                h, w = struct.unpack(">HH", f.read(4))
                return w, h
            if not b:
                return 0, 0
            f.seek(struct.unpack(">H", f.read(2))[0] - 2, 1)


def load_manifest():
    m = json.load(open(os.path.join(ROOT, "store_listing", "imagenes_alpha.json"), encoding="utf-8"))
    out = {"icon": [m["icon"]], "featureGraphic": [m["featureGraphic"]], "phoneScreenshots": list(m["phoneScreenshots"])}
    return {k: [os.path.join(ROOT, p) for p in v] for k, v in out.items()}


def check(items):
    problems = []
    for kind, files in items.items():
        for f in files:
            if not os.path.isfile(f):
                problems.append("No existe %s" % f)
                continue
            w, h = size_of(f)
            kb = os.path.getsize(f) // 1024
            ok = (kind == "icon" and (w, h) == (512, 512) and kb <= 1024) or (kind == "featureGraphic" and (w, h) == (1024, 500)) or \
                 (kind == "phoneScreenshots" and 320 <= min(w, h) and max(w, h) <= 3840 and max(w, h) <= 2 * min(w, h))
            print("  %s %-17s %5dx%-5d %5d KB  %s" % ("OK   " if ok else "MAL  ", kind, w, h, kb, os.path.relpath(f, ROOT)))
            if not ok:
                problems.append("%s no cumple las medidas de Google" % f)
    if not (2 <= len(items["phoneScreenshots"]) <= 8):
        problems.append("Hacen falta entre 2 y 8 capturas de teléfono")
    return problems


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["check", "upload"])
    ap.add_argument("--config")
    ap.add_argument("--confirm", default="")
    a = ap.parse_args()
    cfg = load_config(a.config)
    items = load_manifest()
    problems = check(items)
    if problems:
        fail("; ".join(problems))
    if a.cmd == "check":
        print("✅ Las imágenes cumplen las medidas")
        return
    from googleapiclient.http import MediaFileUpload
    pkg = cfg["package"]
    lang = cfg["default_language"]
    info = service_account_info()
    if not info:
        fail("Falta GOOGLE_PLAY_SERVICE_ACCOUNT")
    print("Cuenta de servicio: %s" % masked_account(info))
    svc = build_service(info)
    edit_id = None
    try:
        edit_id = svc.edits().insert(packageName=pkg, body={}).execute()["id"]
        for kind, files in items.items():
            svc.edits().images().deleteall(packageName=pkg, editId=edit_id, language=lang, imageType=kind).execute()
            for f in files:
                mt = "image/png" if f.lower().endswith(".png") else "image/jpeg"
                svc.edits().images().upload(packageName=pkg, editId=edit_id, language=lang, imageType=kind, media_body=MediaFileUpload(f, mimetype=mt)).execute()
            print("  subidas %s: %d" % (kind, len(files)))
        svc.edits().validate(packageName=pkg, editId=edit_id).execute()
        print("✅ Google VALIDÓ las imágenes (%s)" % edit_id)
        if a.confirm == "IMAGENES":
            r = svc.edits().commit(packageName=pkg, editId=edit_id).execute()
            edit_id = None
            print("🚀 CONFIRMADO: imágenes de la ficha guardadas (edición %s)." % r.get("id"))
        else:
            print("ℹ️ ENSAYO: no se cambió nada. Para confirmar: --confirm IMAGENES")
    except SystemExit:
        raise
    except Exception as e:  # noqa: BLE001
        fail(explain_http_error(e, pkg))
    finally:
        if edit_id:
            try:
                svc.edits().delete(packageName=pkg, editId=edit_id).execute()
                print("(edición temporal borrada: no quedó nada sin confirmar)")
            except Exception:  # noqa: BLE001
                pass


if __name__ == "__main__":
    main()
