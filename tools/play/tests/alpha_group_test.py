#!/usr/bin/env python3
"""Prueba de alpha_group.py con el cliente real de Google y un transporte que sólo registra: mostrar no cambia nada; agregar CONSERVA los grupos que ya había; sólo toca los testers de alpha."""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import alpha_group as ag  # noqa: E402
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
        out = {"id": "E1"} if p.endswith("/edits") else ({"googleGroups": ["viejo@googlegroups.com"]} if p.endswith("/testers/alpha") and method == "GET" else {})
        r = R(); r["content-type"] = "application/json"; return r, json.dumps(out).encode()
def run(args):
    rec = Rec(); svc = build_from_document(json.loads(get_static_doc("androidpublisher", "v3")), http=rec)
    ag.build_service = lambda info, read_only=False: svc; ag.service_account_info = lambda: {"client_email": "a@b.c"}
    sys.argv = ["x"] + args
    try: ag.main()
    except SystemExit as e: return rec, e.code or 0
    return rec, 0
rec, code = run([])
check(code == 0 and not any(c[0] in ("PUT", "PATCH") for c in rec.calls) and any(c[0] == "DELETE" for c in rec.calls), "mostrar: sólo lee y borra la edición temporal")
rec, code = run(["--group", "Nuevo@googlegroups.com", "--confirm", "GRUPO"])
put = [c for c in rec.calls if c[0] == "PUT"]
check(len(put) == 1 and put[0][2]["googleGroups"] == ["viejo@googlegroups.com", "nuevo@googlegroups.com"], "agregar conserva el grupo que ya estaba y suma el nuevo")
check(all("/testers/alpha" in c[1] or "/edits" in c[1] for c in rec.calls) and any(c[1].endswith(":commit") for c in rec.calls), "sólo toca alpha y confirma con --confirm GRUPO")
rec, code = run(["--group", "nuevo@googlegroups.com"])
check(not any(c[1].endswith(":commit") for c in rec.calls), "sin --confirm no confirma")
rec, code = run(["--group", "esto no es un correo"])
check(code != 0 and not rec.calls, "rechaza algo que no es una dirección (no inventa nada)")
print("TODO OK" if not fails else "HAY FALLAS: %d" % fails); sys.exit(1 if fails else 0)
