#!/usr/bin/env python3
"""Prueba de app_details.py (cliente real de Google, transporte que sólo registra): mostrar sólo lee; set sólo hace PATCH de details con el correo."""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import app_details as ad  # noqa: E402
from googleapiclient.discovery import build_from_document  # noqa: E402
from googleapiclient.discovery_cache import get_static_doc  # noqa: E402
fails = 0
def check(ok, msg):
    global fails
    print(("  OK   " if ok else "  FALLA ") + msg); fails += 0 if ok else 1
class Rec:
    def __init__(self): self.calls = []
    def request(self, uri, method="GET", body=None, headers=None, **kw):
        class R(dict): status = 200; reason = "OK"
        p = uri.split("?")[0]; self.calls.append((method, p, json.loads(body) if body else None))
        if p.endswith("/edits"): out = {"id": "E1"}
        elif p.endswith("/details"): out = {"defaultLanguage": "es-419", "contactEmail": "x@y.z"}
        elif p.endswith("/listings"): out = {"listings": [{"language": "es-419", "title": "t", "shortDescription": "s", "fullDescription": "f"}]}
        elif "/listings/es-419/" in p: out = {"images": [{"id": "1"}]}
        else: out = {}
        r = R(); r["content-type"] = "application/json"; return r, json.dumps(out).encode()
def run(args):
    rec = Rec(); svc = build_from_document(json.loads(get_static_doc("androidpublisher", "v3")), http=rec)
    ad.build_service = lambda info, read_only=False: svc; ad.service_account_info = lambda: {"client_email": "a@b.c"}
    sys.argv = ["x"] + args
    try: ad.main()
    except SystemExit as e: return rec, e.code or 0
    return rec, 0
rec, code = run(["show"])
check(code == 0 and not any(c[0] in ("PUT", "PATCH") for c in rec.calls), "mostrar: sólo lee")
rec, code = run(["set", "--email", "nuevo@mail.com", "--confirm", "CONTACTO"])
w = [c for c in rec.calls if c[0] in ("PUT", "PATCH")]
check(len(w) == 1 and w[0][1].endswith("/details") and w[0][2] == {"contactEmail": "nuevo@mail.com"} and any(c[1].endswith(":commit") for c in rec.calls), "set: un PATCH sólo con el correo y confirma con --confirm CONTACTO")
rec, code = run(["set", "--email", "nuevo@mail.com"])
check(not any(c[1].endswith(":commit") for c in rec.calls), "sin --confirm no confirma")
rec, code = run(["set", "--email", "no es correo"])
check(code != 0 and not rec.calls, "rechaza un correo inválido")
print("TODO OK" if not fails else "HAY FALLAS: %d" % fails); sys.exit(1 if fails else 0)
