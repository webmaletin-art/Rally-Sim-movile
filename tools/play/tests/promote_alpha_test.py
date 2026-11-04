#!/usr/bin/env python3
"""Prueba de promote_alpha.py con el cliente real de Google y un transporte que sólo registra: ensayo = valida y borra la edición sin confirmar; confirmar = commit; sólo toca la pista alpha;
falla sin subir nada si el bundle no existe."""
import io, json, os, subprocess, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import promote_alpha as pa  # noqa: E402
from googleapiclient.discovery import build_from_document  # noqa: E402
from googleapiclient.discovery_cache import get_static_doc  # noqa: E402
import play_common  # noqa: E402

fails = 0
def check(ok, msg):
    global fails
    print(("  OK   " if ok else "  FALLA ") + msg)
    fails += 0 if ok else 1

class Rec:
    def __init__(self, bundles): self.calls = []; self.bundles = bundles
    def request(self, uri, method="GET", body=None, headers=None, **kw):
        class R(dict): status = 200; reason = "OK"
        path = uri.split("?")[0]; self.calls.append((method, path, json.loads(body) if body else None))
        out = {}
        if method == "POST" and path.endswith("/edits"): out = {"id": "E1"}
        elif path.endswith("/bundles"): out = {"bundles": [{"versionCode": v} for v in self.bundles]}
        elif path.endswith("/tracks/alpha"): out = {"track": "alpha"}
        elif path.endswith(":validate"): out = {"id": "E1"}
        elif path.endswith(":commit"): out = {"id": "E1"}
        r = R(); r["content-type"] = "application/json"
        return r, json.dumps(out).encode()

def run(bundles, confirm):
    rec = Rec(bundles)
    doc = json.loads(get_static_doc("androidpublisher", "v3"))
    svc = build_from_document(doc, http=rec)
    play_common.build_service = lambda info, read_only=False: svc
    pa.build_service = play_common.build_service
    pa.service_account_info = lambda: {"client_email": "a@b.c"}
    argv = ["x", "--version-code", "1007", "--version-name", "1.0.1"] + (["--confirm", confirm] if confirm else [])
    sys.argv = argv
    code = 0
    try: pa.main()
    except SystemExit as e: code = e.code or 0
    return rec, code

rec, code = run([1006, 1007], "")
m = [(c[0], c[1].rsplit("/", 1)[-1]) for c in rec.calls]
check(code == 0 and not any(x[1] == "E1:commit" or x[1].endswith(":commit") for x in m), "ensayo: valida y NO confirma")
check(any(c[0] == "DELETE" for c in rec.calls), "ensayo: borra la edición temporal")
tr = [c for c in rec.calls if c[1].endswith("/tracks/alpha") and c[0] == "PUT"]
check(len(tr) == 1 and tr[0][2]["releases"][0]["versionCodes"] == ["1007"] and tr[0][2]["releases"][0]["status"] == "completed", "pone el bundle 1007 en alpha (completed)")
check(not any("/tracks/" in c[1] and not c[1].endswith("/tracks/alpha") for c in rec.calls), "no toca ninguna otra pista")
check(not any(c[1].endswith("/bundles") and c[0] == "POST" for c in rec.calls) and not any("upload" in c[1] for c in rec.calls), "no sube ningún archivo")
rec, code = run([1006, 1007], "ALPHA")
check(code == 0 and any(c[1].endswith(":commit") for c in rec.calls), "con --confirm ALPHA confirma la edición")
rec, code = run([1006], "ALPHA")
check(code != 0 and not any(c[1].endswith(":commit") for c in rec.calls), "si el bundle no existe, falla y no confirma")
print("TODO OK" if not fails else "HAY FALLAS: %d" % fails)
sys.exit(1 if fails else 0)
