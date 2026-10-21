#!/usr/bin/env python3
"""Pruebas de tools/play/verify_aab.py: un AAB sin firma y uno firmado con la clave de DEPURACIÓN tienen que ser rechazados."""
import os
import subprocess
import sys
import tempfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "play"))
import verify_aab  # noqa: E402
from play_common import load_config  # noqa: E402

FAILS = []


def check(c, m):
    print(("  OK   " if c else "  FALLA ") + m)
    if not c:
        FAILS.append(m)


tmp = tempfile.mkdtemp()
cfg = load_config()
plain = os.path.join(tmp, "plain.aab")
with zipfile.ZipFile(plain, "w") as z:
    z.writestr("base/manifest/AndroidManifest.xml", "x")
rep = verify_aab.verify(plain, cfg)
check(any("NO está firmado" in b for b in rep.blockers), "un AAB sin firma se rechaza")
dbg = os.path.join(ROOT, "godot", "keystore", "debug.keystore")
if os.path.exists(dbg):
    signed = os.path.join(tmp, "dbg.aab")
    with zipfile.ZipFile(signed, "w") as z:
        z.writestr("base/manifest/AndroidManifest.xml", "x")
    r = subprocess.run(["jarsigner", "-keystore", dbg, "-storepass", "android", signed, "androiddebugkey"], capture_output=True, text=True)
    check(r.returncode == 0, "se pudo firmar con la clave de depuración (preparación de la prueba)")
    rep = verify_aab.verify(signed, cfg)
    check(any("DEPURACIÓN" in b for b in rep.blockers), "un AAB firmado con la clave de depuración se rechaza")
    rep = verify_aab.verify(signed, cfg, expect_sha="00:11")
    check(any("NO coincide" in b for b in rep.blockers) or any("DEPURACIÓN" in b for b in rep.blockers), "una huella distinta de la registrada se rechaza")
check(any("No existe" in b for b in verify_aab.verify(os.path.join(tmp, "nada.aab"), cfg).blockers), "un archivo inexistente se rechaza")
print("\n" + ("TODO OK" if not FAILS else "FALLARON %d" % len(FAILS)))
sys.exit(1 if FAILS else 0)
