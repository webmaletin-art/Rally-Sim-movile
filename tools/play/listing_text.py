#!/usr/bin/env python3
"""Textos de la ficha de Play (título, descripción corta y completa) SIN tocar imágenes, vídeo, categoría ni nada más.

  python3 tools/play/listing_text.py show                       → muestra qué textos tiene hoy Play Console por idioma (abre una edición temporal y la borra)
  python3 tools/play/listing_text.py set --langs es-419         → ensayo: valida subir los textos de store_listing/ficha.md de esos idiomas y borra la edición
  python3 tools/play/listing_text.py set --langs es-419 --confirm TEXTOS  → confirma (queda guardado en la ficha; Google lo revisa al publicar)

Sólo `edits.listings.get/list/patch`. No borra, no toca imágenes (como hace `listing.py sync`), pistas, versiones ni testers."""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from play_common import build_service, explain_http_error, fail, load_config, masked_account, service_account_info  # noqa: E402
import listing  # noqa: E402


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["show", "set"])
    ap.add_argument("--config")
    ap.add_argument("--langs", default="")
    ap.add_argument("--confirm", default="")
    a = ap.parse_args()
    cfg = load_config(a.config)
    pkg = cfg["package"]
    info = service_account_info()
    if not info:
        fail("Falta GOOGLE_PLAY_SERVICE_ACCOUNT")
    print("Cuenta de servicio: %s" % masked_account(info))
    svc = build_service(info)
    edit_id = None
    try:
        edit_id = svc.edits().insert(packageName=pkg, body={}).execute()["id"]
        have = {l["language"]: l for l in svc.edits().listings().list(packageName=pkg, editId=edit_id).execute().get("listings", [])}
        print("Idiomas con ficha en Play: %s" % (", ".join(sorted(have)) or "ninguno"))
        for lang, l in sorted(have.items()):
            print("  %s · título %d · corta %d · completa %d caracteres%s" % (lang, len(l.get("title", "")), len(l.get("shortDescription", "")), len(l.get("fullDescription", "")),
                                                                         " · video" if l.get("video") else ""))
        if a.cmd == "show":
            return
        texts, _ = listing.load_texts(cfg)
        langs = [x.strip() for x in a.langs.split(",") if x.strip()]
        if not langs:
            fail("Indicá --langs (por ejemplo es-419).")
        for lang in langs:
            t = texts.get(lang)
            if not t:
                fail("No hay textos de ficha.md para %s" % lang)
            if len(t["title"]) > 30 or len(t["short"]) > 80 or not t["full"] or len(t["full"]) > 4000:
                fail("Los textos de %s no cumplen los límites de Google." % lang)
            body = {"title": t["title"], "shortDescription": t["short"], "fullDescription": t["full"]}
            if lang in have:
                svc.edits().listings().patch(packageName=pkg, editId=edit_id, language=lang, body=body).execute()
            else:
                svc.edits().listings().update(packageName=pkg, editId=edit_id, language=lang, body=dict(body, language=lang)).execute()
            print("  texto preparado: %s (%d caracteres de descripción completa)" % (lang, len(t["full"])))
        svc.edits().validate(packageName=pkg, editId=edit_id).execute()
        print("✅ Google VALIDÓ los textos (%s)" % edit_id)
        if a.confirm == "TEXTOS":
            r = svc.edits().commit(packageName=pkg, editId=edit_id).execute()
            edit_id = None
            print("🚀 CONFIRMADO: textos de la ficha guardados (edición %s)." % r.get("id"))
        else:
            print("ℹ️ ENSAYO: no se cambió nada. Para confirmar: --confirm TEXTOS")
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
