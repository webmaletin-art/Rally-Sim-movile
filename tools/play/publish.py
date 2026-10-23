#!/usr/bin/env python3
"""Publica (o valida) un .aab en Google Play con la API oficial (Google Play Developer API v3, edición → bundle → pista → validar → confirmar).

Comandos:
  status                       Estado real en Play: pistas, versiones, códigos de versión usados y días de la prueba cerrada (sólo lectura).
  next-version-code --min N    Imprime el próximo versionCode libre: max(N, mayor código ya usado en Play + 1).
  release --aab A --track T    Sube el AAB a la pista T. --mode validate (por defecto) NO publica nada: sube a una edición temporal, la valida y la borra.
                               --mode publish confirma la edición (queda en la pista).
  products                     Compara los productos de game.json con los de Play Console (sólo lectura).

Pistas: internal (pruebas internas) · alpha (prueba cerrada) · beta (prueba abierta) · production.
PRODUCCIÓN exige además --production-approval «AUTORIZO PRODUCCION <versionName>» (la autorización explícita del dueño para ESA versión).
La cuenta de servicio sale de la variable GOOGLE_PLAY_SERVICE_ACCOUNT (nunca se imprime)."""
import argparse
import datetime
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from play_common import Report, build_service, explain_http_error, fail, load_config, masked_account, repo_path, service_account_info  # noqa: E402
import listing  # noqa: E402

TRACKS = ("internal", "alpha", "beta", "production")


def connect(cfg):
    info = service_account_info()
    if not info:
        fail("Falta el secreto GOOGLE_PLAY_SERVICE_ACCOUNT (el JSON completo de la cuenta de servicio): no se puede hablar con Google Play. "
             "Pasos: docs/PUBLICAR_EN_PLAY.md → «Conectar Google Play».")
    print("Cuenta de servicio: %s" % masked_account(info))
    return build_service(info)


def used_version_codes(svc, pkg, edit_id):
    """Todos los códigos de versión que Play ya conoce (bundles subidos + los de todas las pistas)."""
    codes = set()
    try:
        for b in svc.edits().bundles().list(packageName=pkg, editId=edit_id).execute().get("bundles", []):
            codes.add(int(b["versionCode"]))
    except Exception:  # noqa: BLE001  (app sin bundles todavía)
        pass
    tracks = svc.edits().tracks().list(packageName=pkg, editId=edit_id).execute().get("tracks", [])
    for t in tracks:
        for r in t.get("releases", []):
            for c in r.get("versionCodes", []):
                codes.add(int(c))
    return codes, tracks


def with_edit(svc, pkg, fn):
    """Abre una edición, corre fn(edit_id) y la BORRA siempre (para comandos de sólo lectura)."""
    edit_id = svc.edits().insert(packageName=pkg, body={}).execute()["id"]
    try:
        return fn(edit_id)
    finally:
        try:
            svc.edits().delete(packageName=pkg, editId=edit_id).execute()
        except Exception:  # noqa: BLE001
            pass


def cmd_next_version_code(cfg, a):
    base = int(a.min)
    if not os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT") and not os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_FILE"):
        print("::warning::Sin cuenta de servicio no se puede consultar a Play: se usa %d (puede repetir un código ya usado)" % base, file=sys.stderr)
        print(base)
        return
    svc = build_service(service_account_info())
    try:
        codes, _ = with_edit(svc, cfg["package"], lambda e: used_version_codes(svc, cfg["package"], e))
    except Exception as e:  # noqa: BLE001
        fail(explain_http_error(e, cfg["package"]))
    nxt = max([base] + [c + 1 for c in codes])
    print("::notice::versionCode: mínimo %d · mayor ya usado en Play %s → %d" % (base, max(codes) if codes else "ninguno", nxt), file=sys.stderr)
    print(nxt)


def cmd_status(cfg, a):
    """Estado en Play, SÓLO LECTURA: únicamente pedidos GET (applications.tracks.releases.list). NO abre ediciones, no sube nada, no confirma nada.
    El servicio se construye con un candado que rechaza cualquier pedido que no sea GET."""
    info = service_account_info()
    if not info:
        fail("Falta el secreto GOOGLE_PLAY_SERVICE_ACCOUNT (el JSON completo de la cuenta de servicio): no se puede consultar Google Play.")
    print("Cuenta de servicio: %s" % masked_account(info))
    svc = build_service(info, read_only=True)
    pkg = cfg["package"]
    rep = Report("Estado en Google Play de %s (SOLO LECTURA)" % pkg)
    found = {}
    first_error = ""
    for track in TRACKS:
        try:
            r = svc.applications().tracks().releases().list(parent="applications/%s/tracks/%s" % (pkg, track)).execute()
            found[track] = r.get("releases", [])
        except Exception as e:  # noqa: BLE001
            msg = explain_http_error(e, pkg)
            if "404" in msg and not found:
                fail(msg)
            first_error = first_error or msg
            found[track] = None
            rep.warn("Pista «%s»: no se pudo leer (%s)" % (track, msg.splitlines()[0][:160]))
    if all(v is None for v in found.values()):
        fail(first_error)
    rep.ok("Google Play responde y la cuenta de servicio puede LEER la app %s" % pkg)
    names = {"internal": "pruebas internas", "alpha": "prueba cerrada (alpha)", "beta": "prueba abierta (beta)", "production": "producción"}
    for track in TRACKS:
        rels = found.get(track)
        if rels is None:
            continue
        if not rels:
            rep.info("Pista «%s» (%s): sin versiones" % (track, names[track]))
        for r in rels:
            arts = r.get("activeArtifacts", [])
            rep.info("Pista «%s» (%s): versión %s · estado %s · artefactos activos: %s" % (
                track, names[track], r.get("releaseName", "?"), r.get("releaseLifecycleState", "?"),
                json.dumps(arts, ensure_ascii=False)[:300] if arts else "ninguno"))
    if not any(found.get(t) for t in TRACKS):
        rep.warn("Ninguna pista tiene versiones visibles por la API: la versión 1006 puede estar todavía en borrador (sin enviar a la pista) o la API no la expone en estado borrador")
    ct = cfg.get("closed_test", {})
    rep.info("Prueba cerrada: %s. La API NO informa si se cumplió el requisito de testers/días: se ve en Play Console → Panel" %
             ("empezó el %s" % ct["started_on"] if ct.get("started_on") else "sin fecha en game.json → closed_test.started_on"))
    rep.emit()


def cmd_release(cfg, a):
    pkg = cfg["package"]
    if a.track not in TRACKS:
        fail("Pista desconocida «%s». Opciones: %s" % (a.track, ", ".join(TRACKS)))
    if not os.path.isfile(a.aab):
        fail("No existe el AAB %s" % a.aab)
    if a.mode == "publish" and a.track == "production":
        want = "AUTORIZO PRODUCCION %s" % a.version_name
        if (a.production_approval or "").strip() != want:
            fail("Producción NO autorizada. Para publicar la versión %s en PRODUCCIÓN hay que escribir exactamente: «%s». No se publicó nada." % (a.version_name, want))
    # notas de la versión
    notes = []
    if a.notes:
        texts = listing.parse_novedades(repo_path(a.notes) if not os.path.isabs(a.notes) else a.notes)
        for lang in cfg["languages"]:
            t = texts.get(lang)
            if not t:
                fail("Falta la nota de versión para %s en %s" % (lang, a.notes))
            if len(t) > 500:
                fail("La nota de versión %s tiene %d caracteres (máximo 500)" % (lang, len(t)))
            notes.append({"language": lang, "text": t})
    from googleapiclient.http import MediaFileUpload
    svc = connect(cfg)
    print("Modo: %s · pista: %s · AAB: %s (%.0f MB)" % (a.mode, a.track, os.path.basename(a.aab), os.path.getsize(a.aab) / 1048576))
    edit_id = None
    status = a.status
    try:
        edit_id = svc.edits().insert(packageName=pkg, body={}).execute()["id"]
        codes, _ = used_version_codes(svc, pkg, edit_id)
        print("Códigos ya conocidos por Play: %s" % (sorted(codes) or "ninguno"))
        req = svc.edits().bundles().upload(packageName=pkg, editId=edit_id,
                                           media_body=MediaFileUpload(a.aab, mimetype="application/octet-stream", resumable=True, chunksize=64 * 1024 * 1024))
        resp = None
        last = -1
        while resp is None:
            st, resp = req.next_chunk(num_retries=5)
            if st and int(st.progress() * 10) != last:
                last = int(st.progress() * 10)
                print("  subiendo… %d%%" % (st.progress() * 100), flush=True)
        vc = int(resp["versionCode"])
        print("✅ Play recibió el bundle: versionCode %d · sha256 %s" % (vc, resp.get("sha256", "?")))
        if a.expect_version_code and int(a.expect_version_code) != vc:
            fail("Play recibió versionCode %d pero se esperaba %s" % (vc, a.expect_version_code))
        release = {"name": a.version_name, "versionCodes": [str(vc)], "status": status}
        if notes:
            release["releaseNotes"] = notes
        if status == "inProgress":
            release["userFraction"] = float(a.user_fraction)

        def set_track(rel):
            return svc.edits().tracks().update(packageName=pkg, editId=edit_id, track=a.track, body={"track": a.track, "releases": [rel]}).execute()
        try:
            set_track(release)
        except Exception as e:  # noqa: BLE001
            if "draft" in explain_http_error(e, pkg).lower() and status != "draft" and a.allow_draft_fallback:
                print("⚠️ La app está en borrador en Play: se reintenta la versión como «borrador» (hay que enviarla desde Play Console).")
                release["status"] = status = "draft"
                release.pop("userFraction", None)
                set_track(release)
            else:
                raise
        print("✅ Pista «%s» preparada con la versión %s (%s)" % (a.track, a.version_name, status))
        kwargs = {}
        if a.changes_not_sent_for_review:
            kwargs["changesNotSentForReview"] = True
        svc.edits().validate(packageName=pkg, editId=edit_id).execute()
        print("✅ Google VALIDÓ la edición (%s)" % edit_id)
        if a.mode == "validate":
            print("ℹ️ MODO VALIDAR: no se publicó nada. La edición temporal se borra.")
            result = "validado"
        else:
            r = svc.edits().commit(packageName=pkg, editId=edit_id, **kwargs).execute()
            edit_id = None
            print("🚀 CONFIRMADO en Play Console: edición %s, versión %s en la pista «%s» (%s)." % (r.get("id"), a.version_name, a.track, status))
            result = "publicado"
        link = "https://play.google.com/console/developers/app/%s" % pkg
        summary = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary:
            with open(summary, "a", encoding="utf-8") as f:
                f.write("## Resultado: %s\n\n- App: `%s`\n- Pista: `%s`\n- Versión: `%s` (código `%d`)\n- Estado de la versión: `%s`\n- Cómo comprobarlo: abrí Play Console → la app → *Prueba y publicación* → pista `%s`.\n"
                        % (result.upper(), pkg, a.track, a.version_name, vc, status, a.track))
        print("Comprobá el resultado en Play Console (la consola exige iniciar sesión): %s" % link)
    except SystemExit:
        raise
    except Exception as e:  # noqa: BLE001
        fail(explain_http_error(e, pkg))
    finally:
        if edit_id:
            try:
                svc.edits().delete(packageName=pkg, editId=edit_id).execute()
                print("(edición temporal borrada: no quedó nada sin confirmar)")
            except Exception:  # noqa: BLE001
                pass


def cmd_products(cfg, a):
    svc = connect(cfg)
    pkg = cfg["package"]
    rep = Report("Productos integrados: game.json ↔ Play Console")
    found = {}
    try:
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
                break
        source = "monetization.onetimeproducts"
    except Exception as e:  # noqa: BLE001
        rep.warn("No se pudo leer la lista nueva de productos (%s); se prueba la API anterior" % explain_http_error(e, pkg).splitlines()[0])
        try:
            r = svc.inappproducts().list(packageName=pkg).execute()
            found = {p["sku"]: p for p in r.get("inappproduct", [])}
            source = "inappproducts"
        except Exception as e2:  # noqa: BLE001
            rep.block("No se pudo leer los productos de Play: %s" % explain_http_error(e2, pkg))
            rep.emit()
            sys.exit(1)
    rep.info("Productos encontrados en Play (%s): %d" % (source, len(found)))
    for pid, spec in cfg["products"].items():
        if pid.startswith("_"):
            continue
        if pid in found:
            rep.ok("%s existe en Play" % pid)
        else:
            rep.block("%s NO existe en Play Console (%s, USD %.2f recomendado)" % (pid, "consumible" if spec["kind"] == "credits" else "no consumible / producto único", spec["usd"]))
    for pid in found:
        if pid not in cfg["products"]:
            rep.warn("%s está en Play pero el juego no lo conoce" % pid)
    rep.emit()
    sys.exit(1 if rep.blockers else 0)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["status", "next-version-code", "release", "products"])
    ap.add_argument("--config")
    ap.add_argument("--min", default="1000")
    ap.add_argument("--aab")
    ap.add_argument("--track", default="internal")
    ap.add_argument("--mode", choices=["validate", "publish"], default="validate")
    ap.add_argument("--status", choices=["completed", "draft", "inProgress"], default="completed")
    ap.add_argument("--user-fraction", default="0.2")
    ap.add_argument("--version-name", default="1.0.0")
    ap.add_argument("--expect-version-code")
    ap.add_argument("--notes", default="store_listing/novedades.md")
    ap.add_argument("--production-approval", default="")
    ap.add_argument("--allow-draft-fallback", action="store_true")
    ap.add_argument("--changes-not-sent-for-review", action="store_true")
    a = ap.parse_args()
    cfg = load_config(a.config)
    {"status": cmd_status, "next-version-code": cmd_next_version_code, "release": cmd_release, "products": cmd_products}[a.cmd](cfg, a)


if __name__ == "__main__":
    main()
