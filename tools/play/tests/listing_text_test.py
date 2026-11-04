#!/usr/bin/env python3
"""Prueba de listing_text.py con el cliente real de Google y un transporte que sólo registra: mostrar no cambia nada; set sólo hace PATCH/PUT de listados (nunca imágenes ni borrados)."""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import listing_text as lt  # noqa: E402
from googleapiclient.discovery import build_from_document  # noqa: E402
from googleapiclient.discovery_cache import get_static_doc  # noqa: E402
fails = 0
def check(ok, msg):
    global fails
    print(("  OK   " if ok else "  FALLA ") + msg); fails += 0 if ok else 1
class Rec:
    def __init__(self, have): self.calls = []; self.have = have
    def request(self, uri, method="GET", body=None, headers=None, **kw):
        class R(dict): status = 200; reason = "OK"
        p = uri.split("?")[0]; self.calls.append((method, p, json.loads(body) if body else None))
        out = {"id": "E1"} if p.endswith("/edits") else ({"listings": [{"language": l, "title": "t", "shortDescription": "s", "fullDescription": ""} for l in self.have]} if p.endswith("/listings") else {})
        r = R(); r["content-type"] = "application/json"; return r, json.dumps(out).encode()
def run(args, have):
    rec = Rec(have); svc = build_from_document(json.loads(get_static_doc("androidpublisher", "v3")), http=rec)
    lt.build_service = lambda info, read_only=False: svc; lt.service_account_info = lambda: {"client_email": "a@b.c"}
    sys.argv = ["x"] + args
    try: lt.main()
    except SystemExit as e: return rec, e.code or 0
    return rec, 0
rec, code = run(["show"], ["es-419"])
check(code == 0 and all(c[0] == "GET" or c[0] in ("POST", "DELETE") and ("/edits" in c[1]) for c in rec.calls) and not any(c[0] in ("PUT", "PATCH") for c in rec.calls), "mostrar: sólo lee")
rec, code = run(["set", "--langs", "es-419", "--confirm", "TEXTOS"], ["es-419"])
w = [c for c in rec.calls if c[0] in ("PUT", "PATCH")]
check(len(w) == 1 and w[0][1].endswith("/listings/es-419") and set(w[0][2]) == {"title", "shortDescription", "fullDescription"} and len(w[0][2]["fullDescription"]) > 500, "set: un PATCH sólo con título, corta y completa de es-419")
check(not any("images" in c[1].lower() or c[0] == "DELETE" and "listings" in c[1] for c in rec.calls) and any(c[1].endswith(":commit") for c in rec.calls), "no toca imágenes, no borra y confirma con --confirm TEXTOS")
rec, code = run(["set", "--langs", "es-419"], [])
check(not any(c[1].endswith(":commit") for c in rec.calls) and any(c[0] == "PUT" for c in rec.calls), "sin --confirm no confirma (y crea con PUT si no existía)")
print("TODO OK" if not fails else "HAY FALLAS: %d" % fails); sys.exit(1 if fails else 0)
