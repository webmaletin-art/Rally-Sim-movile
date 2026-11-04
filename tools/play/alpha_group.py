#!/usr/bin/env python3
"""Testers de la prueba cerrada (alpha) por Grupo de Google (el único tipo de lista que deja manejar la API; las listas de correos sólo se editan en Play Console).

  python3 tools/play/alpha_group.py                                  → MUESTRA los grupos que hoy son testers de alpha (abre una edición temporal y la borra)
  python3 tools/play/alpha_group.py --group nombre@googlegroups.com  → ensayo: valida agregar ese grupo (se CONSERVAN los que ya estén) y borra la edición
  python3 tools/play/alpha_group.py --group … --confirm GRUPO         → confirma

Sólo toca los testers de la pista alpha. No inventa direcciones: el grupo lo crea el dueño en groups.google.com y se pasa acá."""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from play_common import build_service, explain_http_error, fail, load_config, masked_account, service_account_info  # noqa: E402

TRACK = "alpha"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config")
    ap.add_argument("--group", default="")
    ap.add_argument("--confirm", default="")
    a = ap.parse_args()
    cfg = load_config(a.config)
    pkg = cfg["package"]
    if a.group and not re.fullmatch(r"[A-Za-z0-9._+-]+@(googlegroups\.com|[A-Za-z0-9.-]+\.[A-Za-z]{2,})", a.group.strip()):
        fail("«%s» no parece una dirección de grupo de Google." % a.group)
    info = service_account_info()
    if not info:
        fail("Falta GOOGLE_PLAY_SERVICE_ACCOUNT")
    print("Cuenta de servicio: %s" % masked_account(info))
    svc = build_service(info)
    edit_id = None
    try:
        edit_id = svc.edits().insert(packageName=pkg, body={}).execute()["id"]
        try:
            cur = svc.edits().testers().get(packageName=pkg, editId=edit_id, track=TRACK).execute().get("googleGroups", [])
        except Exception as e:  # noqa: BLE001
            if "404" in str(e) or "notFound" in str(e):
                cur = []
            else:
                raise
        print("Grupos de Google que hoy son testers de «%s»: %s" % (TRACK, ", ".join(cur) or "ninguno"))
        print("(Las listas de correos de Play Console no se pueden leer por la API.)")
        if not a.group:
            return
        group = a.group.strip().lower()
        new = list(cur) + ([group] if group not in [g.lower() for g in cur] else [])
        svc.edits().testers().update(packageName=pkg, editId=edit_id, track=TRACK, body={"googleGroups": new}).execute()
        svc.edits().validate(packageName=pkg, editId=edit_id).execute()
        print("✅ Google VALIDÓ agregar el grupo %s (quedarían %d grupo(s): %s)" % (group, len(new), ", ".join(new)))
        if a.confirm == "GRUPO":
            r = svc.edits().commit(packageName=pkg, editId=edit_id).execute()
            edit_id = None
            print("🚀 CONFIRMADO: edición %s. El grupo %s es tester de la pista «%s»." % (r.get("id"), group, TRACK))
        else:
            print("ℹ️ ENSAYO: no se cambió nada. Para confirmar: --confirm GRUPO")
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
