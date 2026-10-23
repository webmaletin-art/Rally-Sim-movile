#!/usr/bin/env python3
"""Candado estático de «Play · Reseñas y errores»: reviews.py y el flujo no pueden responder reseñas ni escribir en Google Play. Sale con código 1 si encuentra algo."""
import ast
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
bad = []
src = open(os.path.join(ROOT, "tools", "play", "reviews.py"), encoding="utf-8").read()
FORBIDDEN = {"reply", "insert", "commit", "upload", "update", "patch", "delete", "deleteall", "create", "edits", "post", "put", "batchUpdate"}
for n in ast.walk(ast.parse(src)):
    if isinstance(n, ast.Attribute) and ast.unparse(n.value) == "sys.path":
        continue  # sys.path.insert no es una llamada a Google
    name = n.attr if isinstance(n, ast.Attribute) else (n.id if isinstance(n, ast.Name) else None)
    if name in FORBIDDEN:
        bad.append("reviews.py usa «%s» (línea %d)" % (name, n.lineno))
if "read_only=True" not in src:
    bad.append("reviews.py no arma el servicio con read_only=True")
if src.count("svc.reviews()") != 1 or "svc.reviews().list(" not in src:
    bad.append("reviews.py debe llamar únicamente a reviews().list()")
wf = open(os.path.join(ROOT, ".github", "workflows", "play-resenas.yml"), encoding="utf-8").read()
if re.search(r"contents:\s*write|actions:\s*write|packages:\s*write|issues:\s*write|pull-requests:\s*write", wf):
    bad.append("el flujo pide permisos de escritura de GitHub")
body = wf.split("jobs:")[1]
for s, arg in re.findall(r"tools/play/(\w+\.py)\s*(\S*)", body):
    if s not in ("reviews.py", "check_reviews_readonly.py"):
        bad.append("el flujo llama a «%s»" % s)
if re.search(r"reply|--aab|publish\.py|upload-artifact@v4[\s\S]*retention-days:\s*(\d{2,})", body) and not re.search(r"retention-days:\s*[1-7]\b", body):
    bad.append("el flujo menciona una escritura o no fija retención corta (1 a 7 días)")
if "git add" in body or "git commit" in body or "git push" in body:
    bad.append("el flujo no puede guardar nada en el repositorio")
if bad:
    for b in bad:
        print("::error::" + b)
    sys.exit(1)
print("✅ Candado estático: reviews.py sólo hace reviews().list() (GET), sin responder, y el flujo no escribe en GitHub ni guarda datos en el repositorio.")
