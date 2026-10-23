#!/usr/bin/env python3
"""Auditoría previa a publicar en Google Play (no publica nada).

Uso: python3 tools/play/audit.py [--online] [--config game.json]
  sin --online: sólo mira el repositorio (export de Godot, firma configurada, productos, ficha, imágenes, flujos).
  con --online: además habla con Google Play (necesita GOOGLE_PLAY_SERVICE_ACCOUNT): acceso, versiones y productos reales.
Qué se puede verificar solo y qué no: docs/PUBLICAR_EN_PLAY.md → «Qué comprueba el sistema y qué no».
Sale con código 1 si hay algún BLOQUEO."""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from play_common import Report, load_config, repo_path  # noqa: E402
import listing  # noqa: E402


def preset(cfg):
    path = repo_path(cfg["godot"]["export_presets"])
    text = open(path, encoding="utf-8").read()
    blocks = re.split(r"\n(?=\[preset\.\d+(?:\.options)?\]\n)", text)
    for i, b in enumerate(blocks):
        if re.search(r'^name="%s"$' % re.escape(cfg["godot"]["preset_name"]), b, re.M):
            m = re.match(r"\[preset\.(\d+)\]", b)
            if not m:
                continue
            opts = next((o for o in blocks if o.startswith("[preset.%s.options]" % m.group(1))), "")
            return b, opts
    return None, None


def val(opts, key):
    m = re.search(r"^%s=(.*)$" % re.escape(key), opts, re.M)
    return m.group(1).strip().strip('"') if m else None


def audit_export(cfg, rep):
    g = cfg["godot"]
    head, opts = preset(cfg)
    if head is None:
        rep.block("No existe el preset de Godot «%s» en %s" % (g["preset_name"], g["export_presets"]))
        return
    pk = val(opts, "package/unique_name")
    if pk != cfg["package"]:
        rep.block("El preset exporta el paquete «%s» pero la app registrada en Play es «%s»" % (pk, cfg["package"]))
    else:
        rep.ok("Identificador de paquete del preset = %s (no se puede cambiar una vez publicado)" % pk)
    t = val(opts, "gradle_build/target_sdk")
    if t and int(t) >= g["min_target_sdk"]:
        rep.ok("API de destino %s (Google Play exige %d o más)" % (t, g["min_target_sdk"]))
    else:
        rep.block("API de destino %s: Google Play exige %d o más" % (t, g["min_target_sdk"]))
    if val(opts, "gradle_build/export_format") == "1" and val(opts, "gradle_build/use_gradle_build") == "true":
        rep.ok("Exporta AAB con compilación Gradle (formato exigido por Google Play)")
    else:
        rep.block("El preset no exporta un AAB con Gradle")
    if val(opts, "architectures/arm64-v8a") == "true":
        rep.ok("Incluye arm64-v8a (obligatorio para 64 bits)")
    else:
        rep.block("Falta la arquitectura arm64-v8a")
    if val(opts, "package/signed") == "true":
        rep.ok("El preset pide firma (la clave real llega por los secretos de GitHub)")
    rep.info("versionCode/versionName del archivo son sólo de relleno: los pone el flujo en cada compilación (código = mayor ya usado en Play + 1)")
    if re.search(r'^custom_features="store"', head, re.M):
        rep.ok("Característica «store»: la versión de Play no trae herramientas de desarrollo")


def audit_products(cfg, rep):
    src = cfg["products_sources"]
    client = open(repo_path(src["client"]), encoding="utf-8").read()
    kinds = dict(re.findall(r'"(\w+)":\s*\{"kind":\s*"(\w+)"', client))
    server = re.search(r"PRODUCTS\s*=\s*\[([^\]]*)\]", open(repo_path(src["server"]), encoding="utf-8").read())
    server_ids = set(re.findall(r"'([^']+)'", server.group(1))) if server else set()
    conf = {k: v for k, v in cfg["products"].items() if not k.startswith("_")}
    if set(kinds) == set(conf) == server_ids:
        rep.ok("Los %d productos coinciden en el juego, el servidor (verify-purchase) y game.json" % len(conf))
    else:
        rep.block("Los productos NO coinciden. Juego %s · servidor %s · game.json %s" % (sorted(kinds), sorted(server_ids), sorted(conf)))
    for pid, spec in conf.items():
        if kinds.get(pid) and kinds[pid] != spec["kind"]:
            rep.block("%s: el juego lo trata como «%s» pero game.json dice «%s» (consumible/no consumible)" % (pid, kinds[pid], spec["kind"]))
    cons = [p for p, s in conf.items() if s["kind"] == "credits"]
    rep.info("Consumibles (se pueden volver a comprar): %s · No consumibles: %s" % (", ".join(cons), ", ".join(p for p in conf if p not in cons)))
    billing = open(repo_path("godot/game/store/billing.gd"), encoding="utf-8").read()
    for token, label in (("query_purchases", "restaurar compras"), ("consume_purchase", "consumo de monedas"), ("acknowledge_purchase", "reconocimiento de compras únicas"),
                         ("USER_CANCELED", "cancelación por el jugador"), ("verify_purchase", "verificación en el servidor")):
        if token in billing:
            rep.ok("billing.gd implementa %s" % label)
        else:
            rep.block("billing.gd no implementa %s" % label)
    wf = open(repo_path(".github/workflows/build-aab.yml"), encoding="utf-8").read()
    pin = re.search(r"gh release download (\d+\.\d+\.\d+) --repo godotengine/godot-google-play-billing", wf)
    if pin:
        rep.ok("Plugin de Google Play Billing fijo en la versión %s (Billing Library 8 o más nueva exigida)" % pin.group(1))
    else:
        rep.block("El plugin de compras no está fijo a una versión")
    rep.info("No se hacen compras reales ni se tocan precios: los productos de Play Console se comparan con `publish.py products` (necesita la cuenta de servicio)")


def audit_workflows(cfg, rep):
    wdir = repo_path(".github/workflows")
    names = sorted(os.listdir(wdir))
    rep.info("Flujos: %s" % ", ".join(names))
    build = open(os.path.join(wdir, "build-aab.yml"), encoding="utf-8").read()
    for s in cfg["secrets_required"]["build"]:
        if "secrets.%s" % s in build:
            rep.ok("build-aab.yml usa el secreto %s" % s)
        else:
            rep.block("build-aab.yml no usa el secreto %s" % s)
    if os.path.exists(os.path.join(wdir, "play-release.yml")):
        rep.ok("Existe el flujo play-release.yml (validar / publicar en Play)")
        rel = open(os.path.join(wdir, "play-release.yml"), encoding="utf-8").read()
        if "GOOGLE_PLAY_SERVICE_ACCOUNT" in rel:
            rep.ok("play-release.yml puede usar GOOGLE_PLAY_SERVICE_ACCOUNT (sin imprimirlo)")
    else:
        rep.block("Falta el flujo play-release.yml")
    fn = open(os.path.join(wdir, "supabase-functions.yml"), encoding="utf-8").read()
    if "PLAY_PACKAGE_NAME=%s" % cfg["package"] in fn:
        rep.ok("La función de compras verifica contra el paquete %s" % cfg["package"])
    else:
        rep.block("supabase-functions.yml no apunta al paquete %s" % cfg["package"])


def audit_secrets(cfg, rep, online):
    def present(n):
        return bool(os.environ.get(n, "").strip())
    local = not any(os.environ.get(n) is not None for g in cfg["secrets_required"].values() for n in g) and not os.environ.get("GITHUB_ACTIONS")
    if local:
        rep.info("Estás fuera de GitHub Actions: los secretos no se pueden ver desde acá (sólo el flujo puede saber si existen). Corré el flujo «Play · Publicar» en modo validar")
        return
    for group, names in cfg["secrets_required"].items():
        for n in names:
            if group == "publish" and not online:
                continue
            if present(n):
                rep.ok("Secreto %s: configurado (no se muestra su valor)" % n)
            else:
                rep.block("Falta el secreto %s (GitHub → Settings → Secrets and variables → Actions → New repository secret)" % n)
    if present("UPLOAD_CERT_SHA256"):
        rep.ok("Variable UPLOAD_CERT_SHA256 configurada: se compara la firma del AAB con la clave registrada en Play")
    else:
        rep.warn("Falta la variable UPLOAD_CERT_SHA256 (Settings → Variables): sin ella no se puede comprobar automáticamente que la firma sea la registrada en Play")


def audit_docs(cfg, rep):
    for rel, label in (("docs/privacidad.html", "Política de privacidad"), ("docs/eliminar-cuenta.html", "Eliminación de cuenta"), ("docs/terminos.html", "Términos"),
                       ("docs/PLAY_STORE.md", "Guía técnica de Play"), ("docs/PUBLICAR_EN_PLAY.md", "Procedimiento «listo para publicar»")):
        if os.path.exists(repo_path(rel)):
            rep.ok("%s: %s" % (label, rel))
        else:
            rep.block("Falta %s (%s)" % (rel, label))


def audit_online(cfg, rep):
    import publish  # noqa: F401
    from play_common import build_service, explain_http_error, masked_account, service_account_info
    info = service_account_info()
    if not info:
        rep.block("Falta GOOGLE_PLAY_SERVICE_ACCOUNT: no se puede comprobar nada contra Google Play")
        return
    rep.info("Cuenta de servicio: %s" % masked_account(info))
    pkg = cfg["package"]
    try:
        svc = build_service(info)
        codes, tracks = publish.with_edit(svc, pkg, lambda e: publish.used_version_codes(svc, pkg, e))
    except Exception as e:  # noqa: BLE001
        rep.block("Google Play no dejó abrir la app «%s»: %s" % (pkg, explain_http_error(e, pkg).replace("\n", " ")))
        return
    rep.ok("Google Play reconoce la app %s y la cuenta de servicio puede abrir ediciones (permiso de publicar)" % pkg)
    rep.info("Códigos de versión usados en Play: %s" % (sorted(codes) or "ninguno"))
    if not any(t.get("releases") for t in tracks):
        rep.warn("La app no tiene ninguna versión en ninguna pista (borrador): la primera subida puede requerir pasos manuales en Play Console")
    try:
        found = {}
        r = svc.monetization().onetimeproducts().list(packageName=pkg).execute()
        for p in r.get("oneTimeProducts", []):
            found[p["productId"]] = p
        missing = [p for p in cfg["products"] if not p.startswith("_") and p not in found]
        if missing:
            rep.warn("Productos que faltan crear en Play Console: %s" % ", ".join(missing))
        else:
            rep.ok("Los %d productos existen en Play Console" % len(found))
    except Exception as e:  # noqa: BLE001
        rep.warn("No se pudieron leer los productos de Play: %s" % explain_http_error(e, pkg).splitlines()[0])


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config")
    ap.add_argument("--online", action="store_true")
    ap.add_argument("--no-secret-check", action="store_true", help="no revisar los secretos de firma/Supabase (ya los revisó otro paso con sus valores a mano)")
    a = ap.parse_args()
    cfg = load_config(a.config)
    rep = Report("Auditoría previa a publicar «%s» (%s)" % (cfg["name"], cfg["package"]))
    audit_export(cfg, rep)
    audit_products(cfg, rep)
    audit_workflows(cfg, rep)
    audit_docs(cfg, rep)
    if not a.no_secret_check:
        audit_secrets(cfg, rep, a.online)
    listing.check(cfg, rep)
    if a.online:
        audit_online(cfg, rep)
    else:
        rep.info("Sin --online: no se comprobó nada contra Google Play (acceso de la cuenta de servicio, versiones, productos reales)")
    rep.emit()
    sys.exit(1 if rep.blockers else 0)


if __name__ == "__main__":
    main()
