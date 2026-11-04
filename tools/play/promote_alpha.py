#!/usr/bin/env python3
"""Pone en la pista de PRUEBA CERRADA (alpha) un AAB que YA está subido a Google Play (por ejemplo el 1007 de la pista interna), SIN subir ni reconstruir nada.

  python3 tools/play/promote_alpha.py --version-code 1007 --version-name 1.0.1                 → valida y borra la edición (no cambia nada en Play)
  python3 tools/play/promote_alpha.py --version-code 1007 --version-name 1.0.1 --confirm ALPHA  → confirma: la versión queda en alpha

Sólo escribe en la pista «alpha» (está fijada en el código: no acepta otra). No toca internal, beta, producción, productos, ficha ni testers."""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from play_common import explain_http_error, fail, load_config, masked_account, repo_path, service_account_info, build_service  # noqa: E402
import listing  # noqa: E402

TRACK = "alpha"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config")
    ap.add_argument("--version-code", required=True)
    ap.add_argument("--version-name", required=True)
    ap.add_argument("--confirm", default="")
    ap.add_argument("--notes", default="store_listing/novedades.md")
    ap.add_argument("--status", choices=["completed", "draft"], default="completed")
    a = ap.parse_args()
    cfg = load_config(a.config)
    pkg = cfg["package"]
    info = service_account_info()
    if not info:
        fail("Falta GOOGLE_PLAY_SERVICE_ACCOUNT")
    print("Cuenta de servicio: %s" % masked_account(info))
    notes = []
    texts = listing.parse_novedades(repo_path(a.notes))
    for lang in cfg["languages"]:
        if not texts.get(lang):
            fail("Falta la nota de versión para %s" % lang)
        notes.append({"language": lang, "text": texts[lang]})
    svc = build_service(info)
    edit_id = None
    try:
        edit_id = svc.edits().insert(packageName=pkg, body={}).execute()["id"]
        have = {int(b["versionCode"]) for b in svc.edits().bundles().list(packageName=pkg, editId=edit_id).execute().get("bundles", [])}
        print("Bundles que Play ya tiene: %s" % sorted(have))
        if int(a.version_code) not in have:
            fail("Play no tiene el bundle con versionCode %s: no se puede poner en alpha sin subirlo (no se sube nada acá)." % a.version_code)
        rel = {"name": a.version_name, "versionCodes": [str(int(a.version_code))], "status": a.status, "releaseNotes": notes}
        svc.edits().tracks().update(packageName=pkg, editId=edit_id, track=TRACK, body={"track": TRACK, "releases": [rel]}).execute()
        print("✅ Pista «%s» preparada con el bundle %s ya subido (versión %s, estado %s)" % (TRACK, a.version_code, a.version_name, a.status))
        svc.edits().validate(packageName=pkg, editId=edit_id).execute()
        print("✅ Google VALIDÓ la edición (%s)" % edit_id)
        if a.confirm == "ALPHA":
            r = svc.edits().commit(packageName=pkg, editId=edit_id).execute()
            edit_id = None
            print("🚀 CONFIRMADO en Play Console: edición %s, versión %s (código %s) en la pista «%s»." % (r.get("id"), a.version_name, a.version_code, TRACK))
        else:
            print("ℹ️ ENSAYO: no se publicó nada; la edición temporal se borra. Para confirmar: --confirm ALPHA")
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
