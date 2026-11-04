#!/usr/bin/env python3
"""Candado estático de create_products.py: el único código que escribe en Play Console es crear (patch con allowMissing) y activar; nada de borrar, desactivar, pistas, ediciones,
reseñas, bundles ni la ficha. Se corre antes de crear nada."""
import os
import re
import sys

src = open(os.path.join(os.path.dirname(__file__), "create_products.py"), encoding="utf-8").read()
code = "\n".join(l for l in src.splitlines() if not l.strip().startswith("#"))
code = re.sub(r'""".*?"""', "", code, flags=re.S)
bad = [w for w in ("delete", "deactivate", "batchDelete", ".tracks(", ".edits(", ".reviews(", ".bundles(", ".apks(", ".listings(", "reply", "publish", "cancel") if w in code]
if bad:
    print("⛔ create_products.py usa algo que no corresponde: %s" % bad)
    sys.exit(1)
calls = sorted(set(re.findall(r"\.(onetimeproducts|convertRegionPrices|purchaseOptions|batchUpdateStates|patch|get|list)\(", code)))
print("✅ Candado: create_products.py sólo usa %s (crear y activar productos; nada de borrar, pistas, versiones ni reseñas)" % ", ".join(calls))
