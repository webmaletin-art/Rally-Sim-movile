#!/usr/bin/env python3
"""Prueba de create_products.py con el cliente REAL de Google (documento de descubrimiento incluido) y un transporte que sólo registra los pedidos: comprueba direcciones,
parámetros y cuerpos, que los 10 productos salgan con el ID y el precio de game.json, que NO se escriba nada en el ensayo, que lo existente no se toque y que no haya
ningún pedido de borrado, desactivación, pistas, ediciones ni reseñas."""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import create_products as cp  # noqa: E402
from play_common import Report, load_config  # noqa: E402
from googleapiclient.discovery import build_from_document  # noqa: E402
from googleapiclient.discovery_cache import get_static_doc  # noqa: E402

fails = 0


def check(ok, msg):
    global fails
    print(("  OK   " if ok else "  FALLA ") + msg)
    if not ok:
        fails += 1


class Recorder:
    def __init__(self, existing=()):
        self.calls = []
        self.created = {}
        self.existing = {p: {"productId": p} for p in existing}

    def request(self, uri, method="GET", body=None, headers=None, **kw):
        class R(dict):
            status = 200
            reason = "OK"
        b = json.loads(body) if body else None
        self.calls.append((method, uri, b))
        path = uri.split("?")[0]
        out = {}
        if method == "GET" and path.endswith("/oneTimeProducts"):
            out = {"oneTimeProducts": list(self.existing.values())}
        elif path.endswith("pricing:convertRegionPrices"):
            out = {"regionVersion": {"version": "2022/02"}, "convertedRegionPrices": {"US": {"regionCode": "US", "price": b["price"]}, "AR": {"regionCode": "AR", "price": {"currencyCode": "ARS", "units": "9000", "nanos": 0}}},
                   "convertedOtherRegionsPrice": {"usdPrice": b["price"], "eurPrice": {"currencyCode": "EUR", "units": "9", "nanos": 0}}}
        elif method == "PATCH":
            pid = path.rsplit("/", 1)[-1]
            self.created[pid] = b
            out = b
        elif path.endswith("purchaseOptions:batchUpdateStates"):
            out = {}
        elif method == "GET" and "/oneTimeProducts/" in path:
            pid = path.rsplit("/", 1)[-1]
            out = {"productId": pid, "purchaseOptions": [{"purchaseOptionId": "compra", "state": "ACTIVE"}]}
        r = R()
        r["content-type"] = "application/json"
        return r, json.dumps(out).encode()


def svc_for(rec):
    doc = json.loads(get_static_doc("androidpublisher", "v3"))
    return build_from_document(doc, http=rec)


cfg = load_config(None)
pkg = cfg["package"]
wanted = [(p, s) for p, s in cfg["products"].items() if not p.startswith("_")]
texts = cp.game_texts()
check(len(wanted) == 10 and all(p in texts for p, _ in wanted), "los 10 productos de game.json tienen nombre y descripción en products.gd")
check(all(len(texts[p][0]) <= 55 and len(texts[p][1]) <= 200 for p, _ in wanted), "títulos ≤ 55 y descripciones ≤ 200 caracteres (límites de Google)")

# 1) ensayo: nada se escribe
rec = Recorder()
rep = Report("ensayo")
cp.create_all(svc_for(rec), pkg, wanted, texts, False, rep, cp.existing(svc_for(rec), pkg))
check(all(c[0] == "GET" for c in rec.calls), "el ensayo sólo hace pedidos GET (%d)" % len(rec.calls))

# 2) creación real (contra el registrador)
rec = Recorder(existing=["dr_full"])
rep = Report("creación")
svc = svc_for(rec)
cp.create_all(svc, pkg, wanted, texts, True, rep, cp.existing(svc, pkg))
check(not rep.blockers, "sin bloqueos (%s)" % [b for b in rep.blockers][:2])
check(set(rec.created) == {p for p, _ in wanted} - {"dr_full"}, "crea los 9 que faltan y NO toca el que ya existía (%d creados)" % len(rec.created))
for pid, spec in wanted:
    if pid == "dr_full":
        continue
    body = rec.created.get(pid, {})
    po = (body.get("purchaseOptions") or [{}])[0]
    us = [r for r in po.get("regionalPricingAndAvailabilityConfigs", []) if r["regionCode"] == "US"]
    price = float(us[0]["price"]["units"]) + us[0]["price"]["nanos"] / 1e9 if us else -1
    check(body.get("productId") == pid and abs(price - float(spec["usd"])) < 1e-6 and po.get("purchaseOptionId") == "compra", "%s: ID exacto y precio base USD %.2f" % (pid, spec["usd"]))
methods = {(c[0], c[1].split("?")[0].split("/applications/")[-1].split("/", 1)[-1]) for c in rec.calls}
bad = [c for c in rec.calls if c[0] in ("DELETE", "PUT") or "delete" in c[1].lower() or "deactivate" in c[1].lower() or "/tracks" in c[1] or "/edits" in c[1] or "/reviews" in c[1] or "reply" in c[1].lower()]
check(not bad, "ningún pedido de borrado, desactivación, pistas, ediciones ni reseñas")
patch_uri = [c[1] for c in rec.calls if c[0] == "PATCH"][0]
check("allowMissing=true" in patch_uri and "regionsVersion.version=2022%2F02" in patch_uri and "updateMask=listings%2CpurchaseOptions" in patch_uri, "el PATCH crea (allowMissing), manda la versión de regiones y la máscara: " + patch_uri.split("?")[1][:120])
act = [c for c in rec.calls if c[1].split("?")[0].endswith("purchaseOptions:batchUpdateStates")]
check(len(act) == 9 and all("activatePurchaseOptionRequest" in c[2]["requests"][0] for c in act), "cada producto creado se ACTIVA (9)")
print("TODO OK" if not fails else "HAY FALLAS: %d" % fails)
sys.exit(1 if fails else 0)
