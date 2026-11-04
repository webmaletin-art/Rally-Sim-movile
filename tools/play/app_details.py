#!/usr/bin/env python3
"""Datos de contacto de la app en Play (correo, teléfono, web) y un resumen de la ficha (imágenes y vídeo por idioma), sin tocar nada más.

  python3 tools/play/app_details.py show                                  → muestra los datos de contacto actuales y cuántas imágenes tiene la ficha (abre una edición temporal y la borra)
  python3 tools/play/app_details.py set --email a@b.c                     → ensayo: valida guardar ese correo de contacto (no cambia nada)
  python3 tools/play/app_details.py set --email a@b.c --confirm CONTACTO  → confirma
Sólo `edits.details.get/patch` y lecturas de listados/imágenes. No toca imágenes, textos, pistas, versiones ni testers."""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from play_common import build_service, explain_http_error, fail, load_config, masked_account, service_account_info  # noqa: E402


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["show", "set"])
    ap.add_argument("--config")
    ap.add_argument("--email", default="")
    ap.add_argument("--confirm", default="")
    a = ap.parse_args()
    cfg = load_config(a.config)
    pkg = cfg["package"]
    if a.cmd == "set" and not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", a.email):
        fail("Indicá un correo válido en --email.")
    info = service_account_info()
    if not info:
        fail("Falta GOOGLE_PLAY_SERVICE_ACCOUNT")
    print("Cuenta de servicio: %s" % masked_account(info))
    svc = build_service(info)
    edit_id = None
    try:
        edit_id = svc.edits().insert(packageName=pkg, body={}).execute()["id"]
        d = svc.edits().details().get(packageName=pkg, editId=edit_id).execute()
        print("Idioma predeterminado: %s" % d.get("defaultLanguage", "(sin dato)"))
        print("Correo de contacto: %s" % (d.get("contactEmail") or "(vacío)"))
        print("Teléfono de contacto: %s" % ("sí" if d.get("contactPhone") else "(vacío)"))
        print("Web de contacto: %s" % (d.get("contactWebsite") or "(vacío)"))
        for l in svc.edits().listings().list(packageName=pkg, editId=edit_id).execute().get("listings", []):
            lang = l["language"]
            print("Ficha %s: título %d · corta %d · completa %d caracteres · vídeo %s" % (lang, len(l.get("title", "")), len(l.get("shortDescription", "")), len(l.get("fullDescription", "")), "sí" if l.get("video") else "no"))
            for kind in ("icon", "featureGraphic", "phoneScreenshots", "sevenInchScreenshots", "tenInchScreenshots"):
                try:
                    n = len(svc.edits().images().list(packageName=pkg, editId=edit_id, language=lang, imageType=kind).execute().get("images", []))
                except Exception:  # noqa: BLE001
                    n = -1
                print("   imágenes %s: %s" % (kind, n if n >= 0 else "no se pudo leer"))
        if a.cmd == "show":
            return
        svc.edits().details().patch(packageName=pkg, editId=edit_id, body={"contactEmail": a.email}).execute()
        svc.edits().validate(packageName=pkg, editId=edit_id).execute()
        print("✅ Google VALIDÓ el correo de contacto %s" % a.email)
        if a.confirm == "CONTACTO":
            r = svc.edits().commit(packageName=pkg, editId=edit_id).execute()
            edit_id = None
            print("🚀 CONFIRMADO: correo de contacto guardado (edición %s)." % r.get("id"))
        else:
            print("ℹ️ ENSAYO: no se cambió nada. Para confirmar: --confirm CONTACTO")
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
