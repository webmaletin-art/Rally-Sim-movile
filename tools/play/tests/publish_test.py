#!/usr/bin/env python3
"""Pruebas de tools/play/publish.py contra un Google Play FALSO (fake_play.py): no usa credenciales ni red.
Comprueba: validar no publica, publicar confirma, producción exige autorización, errores comprensibles, versionCode sin duplicar, notas de versión."""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fake_play  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PUB = os.path.join(ROOT, "tools", "play", "publish.py")
FAILS = []


def check(cond, msg):
    print(("  OK   " if cond else "  FALLA ") + msg)
    if not cond:
        FAILS.append(msg)


def fake_account(srv, tmp):
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()).decode()
    port = srv.server_address[1]
    info = {"type": "service_account", "client_email": "prueba@proyecto-falso.iam.gserviceaccount.com", "private_key": pem,
            "private_key_id": "k1", "token_uri": "http://127.0.0.1:%d/token" % port, "project_id": "falso"}
    p = os.path.join(tmp, "sa.json")
    json.dump(info, open(p, "w"))
    return p


def run(args, env_extra):
    env = dict(os.environ, **env_extra)
    env.pop("GOOGLE_PLAY_SERVICE_ACCOUNT", None)
    p = subprocess.run([sys.executable, PUB] + args, capture_output=True, text=True, env=env)
    return p.returncode, p.stdout + p.stderr, p.stdout


def main():
    srv = fake_play.start()
    tmp = tempfile.mkdtemp()
    sa = fake_account(srv, tmp)
    env = {"GOOGLE_PLAY_SERVICE_ACCOUNT_FILE": sa, "PLAY_API_ENDPOINT": "http://127.0.0.1:%d/" % srv.server_address[1]}
    aab = os.path.join(tmp, "x.aab")
    open(aab, "wb").write(os.urandom(200000))

    print("1) validar NO publica y borra la edición")
    fake_play.reset()
    rc, out, so = run(["release", "--aab", aab, "--track", "internal", "--mode", "validate", "--version-name", "1.0.0"], env)
    check(rc == 0, "validar sale con código 0 (%s)" % out.strip().splitlines()[-1][:90])
    check(not fake_play.STATE["committed"], "no se confirmó ninguna edición")
    check(not fake_play.STATE["edits"], "la edición temporal se borró")
    check("MODO VALIDAR" in out and "Google VALIDÓ" in out, "dice que validó y que no publicó")

    print("2) publicar confirma en la pista pedida, con notas en los 6 idiomas")
    fake_play.reset()
    rc, out, so = run(["release", "--aab", aab, "--track", "alpha", "--mode", "publish", "--version-name", "1.0.0", "--expect-version-code", "1001"], env)
    check(rc == 0 and "CONFIRMADO" in out, "publicar confirma (%s)" % out.strip().splitlines()[-2][:80])
    ed = fake_play.STATE["committed"][0] if fake_play.STATE["committed"] else {}
    tr = ed.get("tracks", {}).get("alpha", {})
    rel = (tr.get("releases") or [{}])[0]
    check(rel.get("status") == "completed" and rel.get("versionCodes") == ["1001"], "la versión 1001 queda «completed» en la pista alpha")
    check(len(rel.get("releaseNotes", [])) == 6, "6 notas de versión (%d)" % len(rel.get("releaseNotes", [])))

    print("3) producción sin autorización: se niega ANTES de hablar con Google")
    fake_play.reset()
    rc, out, so = run(["release", "--aab", aab, "--track", "production", "--mode", "publish", "--version-name", "1.0.0"], env)
    check(rc != 0 and "NO autorizada" in out, "producción sin autorización falla")
    check(not fake_play.STATE["log"], "no hubo ninguna llamada a Play")
    rc, out, so = run(["release", "--aab", aab, "--track", "production", "--mode", "publish", "--version-name", "1.0.0", "--production-approval", "si"], env)
    check(rc != 0 and "NO autorizada" in out, "una autorización distinta tampoco sirve")
    rc, out, so = run(["release", "--aab", aab, "--track", "production", "--mode", "publish", "--version-name", "1.0.0",
                   "--production-approval", "AUTORIZO PRODUCCION 1.0.0"], env)
    check(rc == 0 and fake_play.STATE["committed"], "con la frase exacta SÍ publica")
    fake_play.reset()
    rc, out, so = run(["release", "--aab", aab, "--track", "production", "--mode", "validate", "--version-name", "1.0.0"], env)
    check(rc == 0 and not fake_play.STATE["committed"], "validar producción no necesita autorización y no publica")

    print("4) cuenta sin permiso: mensaje comprensible")
    fake_play.reset(deny=True)
    rc, out, so = run(["release", "--aab", aab, "--track", "internal", "--mode", "publish"], env)
    check(rc != 0 and "Usuarios y permisos" in out, "explica cómo dar permiso a la cuenta de servicio")

    print("5) app en borrador: sin reintento falla, con --allow-draft-fallback sube como borrador")
    fake_play.reset(draft_app=True)
    rc, out, so = run(["release", "--aab", aab, "--track", "internal", "--mode", "publish"], env)
    check(rc != 0 and "borrador" in out, "explica que la app está en borrador")
    fake_play.reset(draft_app=True)
    rc, out, so = run(["release", "--aab", aab, "--track", "internal", "--mode", "publish", "--allow-draft-fallback"], env)
    rel = (fake_play.STATE["committed"][0]["tracks"]["internal"]["releases"][0]) if fake_play.STATE["committed"] else {}
    check(rc == 0 and rel.get("status") == "draft", "reintenta como borrador")

    print("6) versionCode: next-version-code no repite códigos ya usados")
    fake_play.reset(bundles=[{"versionCode": 1004}], tracks={"internal": [{"name": "1.0.0", "status": "completed", "versionCodes": ["1007"]}]})
    rc, out, so = run(["next-version-code", "--min", "1006"], env)
    check(so.strip() == "1008", "mayor usado 1007 → 1008 (%s)" % so.strip())
    fake_play.reset()
    rc, out, so = run(["next-version-code", "--min", "1006"], env)
    check(so.strip() == "1006", "sin versiones previas queda el mínimo 1006")
    rc, out, so = run(["next-version-code", "--min", "1006"], {"PLAY_API_ENDPOINT": ""})
    check(so.strip() == "1006" and "puede repetir" in out, "sin cuenta de servicio avisa y usa el mínimo")

    print("6b) status es SOLO LECTURA: únicamente GET, sin ediciones ni escrituras")
    fake_play.reset(tracks={"internal": [{"name": "1.0.0", "status": "draft", "versionCodes": ["1006"]}]})
    rc, out, so = run(["status"], env)
    writes = [(m, p) for m, p in fake_play.STATE["log"] if m != "GET" and p != "/token"]
    check(subprocess.run([sys.executable, os.path.join(ROOT, "tools", "play", "check_status_readonly.py")], capture_output=True).returncode == 0, "el candado estático pasa")
    check(rc == 0 and "1006" in out, "status informa la versión 1006 de la pista interna")
    check(not writes, "ningún pedido de escritura a Play (%s)" % writes)
    check(not any("/edits" in p for m, p in fake_play.STATE["log"]), "no se abrió ninguna edición")
    check(not fake_play.STATE["edits"] and not fake_play.STATE["committed"], "no quedó ninguna edición ni nada confirmado")
    fake_play.reset(deny=True)
    rc, out, so = run(["status"], env)
    check(rc != 0 and "Usuarios y permisos" in out, "status con permiso denegado da un mensaje comprensible")

    print("6c) el candado de solo lectura bloquea cualquier escritura")
    sys.path.insert(0, os.path.join(ROOT, "tools", "play"))
    import play_common
    os.environ.update(env)
    fake_play.reset()
    info = json.load(open(sa))
    svc = play_common.build_service(info, read_only=True)
    try:
        svc.edits().insert(packageName="com.srg.dreamracing", body={}).execute()
        blocked = False
    except RuntimeError as e:
        blocked = "SOLO LECTURA" in str(e)
    check(blocked and not fake_play.STATE["edits"], "un POST (crear edición) se rechaza antes de salir")
    for k in env:
        os.environ.pop(k, None)
    svc = play_common.build_service(info, read_only=True)  # ruta de PRODUCCIÓN (sin servidor falso): sólo se arma el cliente, no se sale a la red
    try:
        svc.edits().insert(packageName="com.srg.dreamracing", body={}).execute()
        blocked = False
    except RuntimeError as e:
        blocked = "SOLO LECTURA" in str(e)
    check(blocked, "ruta de producción: el cliente se arma y el POST se rechaza")

    print("7) el JSON de la cuenta de servicio nunca se imprime")
    fake_play.reset()
    rc, out, so = run(["status"], env)
    check("PRIVATE KEY" not in out and "private_key" not in out, "no aparece la clave privada")
    check("prueba@proyecto-falso" not in out and "pru…@" in out, "el correo sale enmascarado")

    print("\n%s" % ("TODO OK" if not FAILS else "FALLARON %d: %s" % (len(FAILS), FAILS)))
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
