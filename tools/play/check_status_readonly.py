#!/usr/bin/env python3
"""Candado estático: `publish.py status` (cmd_status) y el flujo «Play · Estado» no pueden contener operaciones de escritura sobre Google Play.
Sale con código 1 si encuentra alguna. Se corre antes de consultar Play."""
import ast
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FORBIDDEN = ("insert", "commit", "upload", "update", "patch", "delete", "deleteall", "create", "validate", "batchUpdate", "with_edit", "used_version_codes", "edits")
bad = []

src = open(os.path.join(ROOT, "tools", "play", "publish.py"), encoding="utf-8").read()
tree = ast.parse(src)
fn = next(n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef) and n.name == "cmd_status")
for n in ast.walk(fn):
    name = n.attr if isinstance(n, ast.Attribute) else (n.id if isinstance(n, ast.Name) else None)
    if name in FORBIDDEN:
        bad.append("cmd_status usa «%s» (línea %d)" % (name, n.lineno))
if "read_only=True" not in ast.get_source_segment(src, fn):
    bad.append("cmd_status no construye el servicio con read_only=True")

wf = open(os.path.join(ROOT, ".github", "workflows", "play-estado.yml"), encoding="utf-8").read()
cmds = re.findall(r"tools/play/(\w+\.py)\s+(\w[\w-]*)?", wf)
allowed = {("check_status_readonly.py", ""), ("publish.py", "status"), ("tests", "")}
for script, arg in cmds:
    if (script, arg or "") not in allowed and script not in ("check_status_readonly.py",):
        bad.append("el flujo llama a «%s %s», que no es la consulta de solo lectura" % (script, arg))
if re.search(r"release|publish\.py\s+(?!status)|next-version-code|\bmode\b|--aab|upload|commit", wf.split("jobs:")[1]):
    bad.append("el flujo menciona una operación de escritura (release/--aab/upload/commit/mode)")
if re.search(r"contents:\s*write|packages:\s*write|actions:\s*write", wf):
    bad.append("el flujo pide permisos de escritura de GitHub")

if bad:
    for b in bad:
        print("::error::" + b)
    sys.exit(1)
print("✅ Candado estático: cmd_status sólo usa applications.tracks.releases.list (GET) y el flujo sólo corre «publish.py status».")
