#!/usr/bin/env python3
"""Crea en Google Play Console los productos integrados (compras únicas) de Dream Racing, EXACTAMENTE como están en tools/play/game.json
(IDs y precio base en USD) con el nombre y la descripción de godot/game/store/products.gd. Ver docs/INFORME_PRODUCTOS_PLAY.md.

  python3 tools/play/create_products.py                      → ensayo: muestra qué crearía; NO escribe nada en Play
  python3 tools/play/create_products.py --confirm CREAR      → crea los que faltan (los que ya existen NO se tocan) y los activa

Sólo usa: monetization.onetimeproducts.list / get / patch (con allowMissing: crear), monetization.convertRegionPrices (calcula los precios por país a partir del precio
base en USD, no cambia nada) y monetization.onetimeproducts.purchaseOptions.batchUpdateStates (ACTIVAR). No borra, no desactiva, no toca precios de productos
existentes, no toca pistas, versiones, AAB ni la ficha. Consumible o no: lo decide el juego al «consumir» la compra (las bolsas de monedas); en Play todos son compras únicas."""
import argparse
import os
import re
import sys
from decimal import Decimal

sys.path.insert(0, os.path.dirname(__file__))
from play_common import ROOT, Report, build_service, explain_http_error, load_config, masked_account, service_account_info  # noqa: E402

PURCHASE_OPTION = "compra"
LANG = "es-419"


def money(usd):
    d = Decimal(str(usd))
    units = int(d)
    return {"currencyCode": "USD", "units": str(units), "nanos": int((d - units) * 1000000000)}


def game_texts():
    """id → (nombre, descripción) leídos de products.gd (una sola fuente de verdad)."""
    src = open(os.path.join(ROOT, "godot", "game", "store", "products.gd"), encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'"(\w+)": \{"kind": "\w+"(?:, "amount": \d+)?, "name": "([^"]+)"[^\n]*?\n?\s*"desc": "([^"]+)"', src):
        out[m.group(1)] = (m.group(2), m.group(3))
    return out


def build_product(pkg, pid, name, desc, conv):
    """Cuerpo OneTimeProduct: un listado (es-419) y una opción de compra con el precio base convertido a cada país por Google."""
    regional = []
    for rc, cp in sorted((conv.get("convertedRegionPrices") or {}).items()):
        regional.append({"regionCode": rc, "availability": "AVAILABLE", "price": cp["price"]})
    other = conv.get("convertedOtherRegionsPrice") or {}
    option = {
        "purchaseOptionId": PURCHASE_OPTION,
        "buyOption": {"legacyCompatible": True, "multiQuantityEnabled": False},
        "regionalPricingAndAvailabilityConfigs": regional,
    }
    if other.get("usdPrice") and other.get("eurPrice"):
        option["newRegionsConfig"] = {"availability": "AVAILABLE", "usdPrice": other["usdPrice"], "eurPrice": other["eurPrice"]}
    return {"packageName": pkg, "productId": pid, "listings": [{"languageCode": LANG, "title": name[:55], "description": desc[:200]}], "purchaseOptions": [option]}


def existing(svc, pkg):
    found = {}
    token = None
    while True:
        kw = {"packageName": pkg}
        if token:
            kw["pageToken"] = token
        r = svc.monetization().onetimeproducts().list(**kw).execute()
        for p in r.get("oneTimeProducts", []):
            found[p["productId"]] = p
        token = r.get("nextPageToken")
        if not token:
            return found


def create_all(svc, pkg, wanted, texts, write, rep, have):
    rep.info("Productos que ya existen en Play: %d (%s)" % (len(have), ", ".join(sorted(have)) or "ninguno"))
    if not write:
        rep.warn("ENSAYO: no se escribió nada. Para crear: --confirm CREAR")
    for pid, spec in wanted:
        name, desc = texts[pid]
        usd = float(spec["usd"])
        if pid in have:
            rep.ok("%s ya existe: no se toca" % pid)
            continue
        line = "%s · %s · USD %.2f · «%s»" % (pid, "consumible (lo consume el juego)" if spec["kind"] == "credits" else "no consumible", usd, name)
        if not write:
            rep.info("crearía: " + line)
            continue
        try:
            conv = svc.monetization().convertRegionPrices(packageName=pkg, body={"price": money(usd)}).execute()
            version = (conv.get("regionVersion") or {}).get("version")
            body = build_product(pkg, pid, name, desc, conv)
            svc.monetization().onetimeproducts().patch(
                packageName=pkg, productId=pid, body=body, allowMissing=True, updateMask="listings,purchaseOptions",
                **{"regionsVersion_version": version}, latencyTolerance="PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_SENSITIVE").execute()
            svc.monetization().onetimeproducts().purchaseOptions().batchUpdateStates(
                packageName=pkg, productId=pid,
                body={"requests": [{"activatePurchaseOptionRequest": {"packageName": pkg, "productId": pid, "purchaseOptionId": PURCHASE_OPTION}}]}).execute()
            got = svc.monetization().onetimeproducts().get(packageName=pkg, productId=pid).execute()
            states = [po.get("state") for po in got.get("purchaseOptions", [])]
            if states and all(s == "ACTIVE" for s in states):
                rep.ok("creado y ACTIVO: " + line)
            else:
                rep.block("%s creado pero su estado es %s (no ACTIVE)" % (pid, states))
        except Exception as e:  # noqa: BLE001
            rep.block("%s NO se pudo crear: %s" % (pid, explain_http_error(e, pkg).replace("\n", " ")[:600]))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config")
    ap.add_argument("--confirm", default="")
    a = ap.parse_args()
    cfg = load_config(a.config)
    pkg = cfg["package"]
    rep = Report("Crear productos de compras: %s" % pkg)
    write = a.confirm == "CREAR"
    texts = game_texts()
    wanted = [(pid, spec) for pid, spec in cfg["products"].items() if not pid.startswith("_")]
    for pid, _ in wanted:
        if pid not in texts:
            rep.block("%s no tiene nombre/descripción en products.gd" % pid)
    if rep.blockers:
        rep.emit()
        sys.exit(1)
    info = service_account_info()
    if not info:
        rep.block("Falta GOOGLE_PLAY_SERVICE_ACCOUNT")
        rep.emit()
        sys.exit(1)
    rep.info("Cuenta de servicio: %s" % masked_account(info))
    svc = build_service(info)
    try:
        have = existing(svc, pkg)
    except Exception as e:  # noqa: BLE001
        rep.block("No se pudo leer la lista de productos: %s" % explain_http_error(e, pkg).replace("\n", " "))
        rep.emit()
        sys.exit(1)
    create_all(svc, pkg, wanted, texts, write, rep, have)
    rep.emit()
    sys.exit(1 if rep.blockers else 0)


if __name__ == "__main__":
    main()
