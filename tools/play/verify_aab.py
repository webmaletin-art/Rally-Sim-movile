#!/usr/bin/env python3
"""Verifica un .aab antes de subirlo a Google Play: firma (no puede ser la de depuración), paquete, versionCode, versionName, API de destino,
permiso de compras y páginas de 16 KB (reusa tools/export/check_aab_alignment.py). No publica nada ni necesita credenciales.

Uso: python3 tools/play/verify_aab.py archivo.aab --bundletool bundletool.jar [--expect-version-code N] [--expect-version-name 1.0.0]
                                       [--expect-sha256 AA:BB:…]   (huella SHA-256 del certificado de SUBIDA registrado en Play Console)
Sale con código 1 si hay algún BLOQUEO. Necesita Java (keytool/jarsigner) y bundletool (https://github.com/google/bundletool)."""
import argparse
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
from play_common import ROOT, Report, load_config  # noqa: E402


def run(cmd):
    p = subprocess.run(cmd, capture_output=True, text=True)
    out = "\n".join(l for l in (p.stdout + "\n" + p.stderr).splitlines() if not l.startswith("Picked up JAVA_TOOL_OPTIONS"))
    return p.returncode, out


def debug_fingerprints():
    """Huellas SHA-256 de las claves de depuración del proyecto (godot/keystore/debug.keystore, contraseña «android»): un AAB firmado con ellas NO sirve para Play."""
    ks = os.path.join(ROOT, "godot", "keystore", "debug.keystore")
    if not os.path.exists(ks):
        return set()
    rc, out = run(["keytool", "-list", "-v", "-keystore", ks, "-storepass", "android"])
    return {norm(m) for m in re.findall(r"SHA256:\s*([0-9A-F:]{95})", out)}


def norm(fp):
    return re.sub(r"[^0-9A-F]", "", (fp or "").upper())


def verify(aab, cfg, bundletool=None, expect_code=None, expect_name=None, expect_sha=None):
    rep = Report("Verificación del AAB: %s" % os.path.basename(aab))
    if not os.path.isfile(aab):
        rep.block("No existe el archivo %s" % aab)
        return rep
    rep.info("Tamaño: %.0f MB" % (os.path.getsize(aab) / 1048576))
    # ── firma
    rc, out = run(["keytool", "-printcert", "-jarfile", aab])
    sha = re.search(r"SHA256:\s*([0-9A-F:]{95})", out)
    owner = re.search(r"Owner:\s*(.+)", out)
    if not sha:
        rep.block("El AAB NO está firmado (o keytool no pudo leer la firma). Google Play lo rechaza.")
    else:
        fp = sha.group(1)
        own = owner.group(1).strip() if owner else "?"
        if re.search(r"debug|androiddebugkey", own, re.I) or norm(fp) in debug_fingerprints():
            rep.block("El AAB está firmado con la clave de DEPURACIÓN (%s). Falta configurar los secretos de firma." % own)
        else:
            rep.ok("Firmado por «%s» · SHA-256 del certificado: %s" % (own, fp))
        rc2, out2 = run(["jarsigner", "-verify", aab])
        if rc2 != 0 or "jar verified" not in out2.lower():
            rep.block("jarsigner no pudo verificar la firma del AAB")
        else:
            rep.ok("La firma del AAB es íntegra (jarsigner: jar verified)")
        if expect_sha:
            if norm(fp) == norm(expect_sha):
                rep.ok("La huella coincide con la de la clave de subida registrada (variable UPLOAD_CERT_SHA256)")
            else:
                rep.block("La huella del AAB (%s) NO coincide con la esperada (%s). No es la clave de subida registrada en Play: Google lo rechazaría." % (fp, expect_sha))
        else:
            rep.warn("No hay huella esperada (variable de GitHub UPLOAD_CERT_SHA256): no se pudo comparar con la clave registrada en Play. "
                     "Comparala a mano en Play Console → Prueba y publicación → Integridad de la aplicación → Firma de la app → «Certificado de clave de carga» (SHA-256) con %s" % fp)
    # ── manifiesto
    if not bundletool or not os.path.exists(bundletool):
        rep.block("No hay bundletool: no se pudo leer el manifiesto del AAB")
    else:
        rc, out = run(["java", "-jar", bundletool, "dump", "manifest", "--bundle=" + aab])
        pkg = re.search(r'\bpackage="([^"]+)"', out)
        code = re.search(r'android:versionCode="(\d+)"', out)
        name = re.search(r'android:versionName="([^"]*)"', out)
        tsdk = re.search(r'targetSdkVersion="(\d+)"', out)
        msdk = re.search(r'minSdkVersion="(\d+)"', out)
        if not pkg or not code:
            rep.block("No se pudo leer el manifiesto del AAB (bundletool): %s" % out[:200].replace("\n", " "))
        else:
            if pkg.group(1) != cfg["package"]:
                rep.block("Identificador de paquete %s ≠ %s (el de la app registrada en Play)" % (pkg.group(1), cfg["package"]))
            else:
                rep.ok("Paquete %s" % pkg.group(1))
            vc = int(code.group(1))
            if expect_code is not None and vc != int(expect_code):
                rep.block("versionCode %d ≠ el esperado %s" % (vc, expect_code))
            else:
                rep.ok("versionCode %d" % vc)
            if expect_name and (name.group(1) if name else "") != expect_name:
                rep.block("versionName %s ≠ el esperado %s" % (name.group(1) if name else "?", expect_name))
            else:
                rep.ok("versionName %s" % (name.group(1) if name else "?"))
            g = cfg["godot"]
            if tsdk and int(tsdk.group(1)) < g["min_target_sdk"]:
                rep.block("API de destino %s: Google Play exige %d o más" % (tsdk.group(1), g["min_target_sdk"]))
            elif tsdk:
                rep.ok("API de destino %s (mínimo Android API %s)" % (tsdk.group(1), msdk.group(1) if msdk else "?"))
            if "android:debuggable=\"true\"" in out:
                rep.block("El manifiesto tiene debuggable=true")
            if "com.android.vending.BILLING" in out:
                rep.ok("Incluye el permiso de Google Play Billing (el plugin de compras está adentro)")
            else:
                rep.block("Sin permiso com.android.vending.BILLING: el AAB salió SIN COMPRAS")
    # ── 16 KB
    rc, out = run([sys.executable, os.path.join(ROOT, "tools", "export", "check_aab_alignment.py"), aab])
    if rc == 0:
        rep.ok("Bibliotecas nativas de 64 bits alineadas a 16 KB")
    else:
        rep.block("Alineación de 16 KB: %s" % out.strip().splitlines()[-1][:200] if out.strip() else "falló")
    return rep


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("aab")
    ap.add_argument("--config")
    ap.add_argument("--bundletool")
    ap.add_argument("--expect-version-code")
    ap.add_argument("--expect-version-name")
    ap.add_argument("--expect-sha256", default=os.environ.get("UPLOAD_CERT_SHA256", ""))
    a = ap.parse_args()
    rep = verify(a.aab, load_config(a.config), a.bundletool, a.expect_version_code, a.expect_version_name, a.expect_sha256 or None)
    rep.emit()
    sys.exit(1 if rep.blockers else 0)


if __name__ == "__main__":
    main()
