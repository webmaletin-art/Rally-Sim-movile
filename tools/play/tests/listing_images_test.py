#!/usr/bin/env python3
"""Prueba de listing_images.py: las imágenes del manifiesto cumplen las medidas; el ensayo no confirma; la subida sólo toca los tres tipos del idioma predeterminado y mantiene el orden."""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import listing_images as li  # noqa: E402
from googleapiclient.discovery import build_from_document  # noqa: E402
from googleapiclient.discovery_cache import get_static_doc  # noqa: E402
fails = 0
def check(ok, msg):
    global fails
    print(("  OK   " if ok else "  FALLA ") + msg); fails += 0 if ok else 1
items = li.load_manifest()
check(not li.check(items) and len(items["phoneScreenshots"]) == 8, "las 8 capturas, el ícono y el gráfico cumplen las medidas")
check(len({os.path.basename(f) for f in items["phoneScreenshots"]}) == 8, "las 8 capturas son distintas")
class Rec:
    def __init__(self): self.calls = []
    def request(self, uri, method="GET", body=None, headers=None, **kw):
        class R(dict): status = 200; reason = "OK"
        p = uri.split("?")[0]; self.calls.append((method, p))
        out = {"id": "E1"} if p.endswith("/edits") and method == "POST" else ({"image": {"id": "i"}} if "/listings/" in p else {})
        r = R(); r["content-type"] = "application/json"; return r, json.dumps(out).encode()
def run(args):
    rec = Rec(); svc = build_from_document(json.loads(get_static_doc("androidpublisher", "v3")), http=rec)
    li.build_service = lambda info, read_only=False: svc; li.service_account_info = lambda: {"client_email": "a@b.c"}
    sys.argv = ["x"] + args
    try: li.main()
    except SystemExit as e: return rec, e.code or 0
    return rec, 0
rec, code = run(["upload"])
check(code == 0 and not any(c[1].endswith(":commit") for c in rec.calls), "ensayo: no confirma")
rec, code = run(["upload", "--confirm", "IMAGENES"])
img = [c for c in rec.calls if "/listings/es-419/" in c[1]]
check(code == 0 and any(c[1].endswith(":commit") for c in rec.calls), "confirmar: hace commit")
check(all("/listings/es-419/" in c[1] for c in rec.calls if "listings" in c[1]) and not any("/tracks" in c[1] or "/testers" in c[1] for c in rec.calls), "sólo toca imágenes del idioma predeterminado (nada de pistas ni testers)")
ups = [c for c in rec.calls if c[0] == "POST" and "/listings/" in c[1]]
check(len(ups) == 10, "sube 10 archivos: 1 ícono + 1 gráfico + 8 capturas (%d)" % len(ups))
print("TODO OK" if not fails else "HAY FALLAS: %d" % fails); sys.exit(1 if fails else 0)
