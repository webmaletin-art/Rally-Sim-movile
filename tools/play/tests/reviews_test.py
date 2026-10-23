#!/usr/bin/env python3
"""Pruebas de tools/play/reviews.py contra un Google Play FALSO: sólo lectura, sin datos personales en la salida, paginación y candados."""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fake_play  # noqa: E402
from publish_test import fake_account  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
FAILS = []


def check(c, m):
    print(("  OK   " if c else "  FALLA ") + m)
    if not c:
        FAILS.append(m)


def rv(i, name, stars, text, ts, lang="es"):
    return {"reviewId": "gp:id%04d" % i, "authorName": name, "comments": [{"userComment": {"text": text, "starRating": stars, "reviewerLanguage": lang,
            "lastModified": {"seconds": str(ts)}, "appVersionCode": 1006, "appVersionName": "1.0.0", "deviceMetadata": {"manufacturer": "Zeta", "productName": "Z2356"}}}]}


REVIEWS = [rv(1, "Juan Pérez Secreto", 1, "El juego se cierra solo al abrir el mapa, muy lento", 1792800000),
           rv(2, "María Gómez Privada", 5, "Me encanta, sería bueno agregar más autos", 1792900000),
           rv(3, "Carlos Reservado", 3, "Compré las monedas y no llegaron, falla la cuenta", 1793000000),
           rv(4, "Ana Oculta", 4, "Gráficos geniales, falta un modo online con amigos", 1793100000, "es")]


def run(env, out):
    p = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "play", "reviews.py"), "--out", out], capture_output=True, text=True, env=env)
    return p.returncode, p.stdout + p.stderr


def main():
    srv = fake_play.start()
    tmp = tempfile.mkdtemp()
    sa = fake_account(srv, tmp)
    env = dict(os.environ, GOOGLE_PLAY_SERVICE_ACCOUNT_FILE=sa, PLAY_API_ENDPOINT="http://127.0.0.1:%d/" % srv.server_address[1])
    env.pop("GOOGLE_PLAY_SERVICE_ACCOUNT", None)

    print("1) con reseñas (2 páginas): informe, agregados y sin datos personales en la salida")
    fake_play.reset(reviews=REVIEWS)
    out = os.path.join(tmp, "o1")
    rc, log = run(env, out)
    check(rc == 0, "sale con código 0")
    check("4 reseñas" in log, "leyó las 4 reseñas (paginación)")
    writes = [(m, p) for m, p in fake_play.STATE["log"] if m != "GET" and p != "/token"]
    check(not writes, "sólo pedidos GET (%s)" % writes)
    check(not any("/edits" in p or ":reply" in p for m, p in fake_play.STATE["log"]), "ni ediciones ni respuestas")
    for secret in ("Juan", "María", "Carlos", "Ana Oculta", "se cierra solo", "Compré", "Secreto", "Privada"):
        check(secret not in log, "la salida/logs NO contienen «%s»" % secret)
    check("Alcance temporal OBSERVADO" in log and "días" in log, "informa el alcance temporal observado")
    raw = open(os.path.join(out, "reviews_raw.json"), encoding="utf-8").read()
    check("Juan Pérez Secreto" in raw, "el archivo crudo (artefacto) sí tiene los datos")
    resumen = open(os.path.join(out, "resumen.json"), encoding="utf-8").read()
    check("Juan" not in resumen and "se cierra solo" not in resumen, "resumen.json no tiene nombres ni textos")
    informe = open(os.path.join(out, "informe.md"), encoding="utf-8").read()
    check("Cierres / errores" in informe and "Compras / pagos" in informe and "Sugerencias detectadas (2)" in informe, "el informe agrupa errores, compras y 2 sugerencias")
    check("Juan" not in informe and "Pérez" not in informe, "el informe no lleva nombres de jugadores")
    check(json.loads(resumen)["alcance_temporal_observado"]["dias_cubiertos"] > 0, "alcance temporal calculado de las fechas devueltas")

    print("2) sin reseñas: avisa que no hay datos para el alcance")
    fake_play.reset()
    rc, log = run(env, os.path.join(tmp, "o2"))
    check(rc == 0 and "0 reseñas" in log and "no hay datos para comprobar el alcance" in log, "avisa sin inventar alcance")

    print("3) permiso denegado: mensaje comprensible")
    fake_play.reset(deny=True)
    rc, log = run(env, os.path.join(tmp, "o3"))
    check(rc != 0 and "NUNCA responde" in log, "explica el permiso de lectura y que jamás responde")

    print("4) candados")
    check(subprocess.run([sys.executable, os.path.join(ROOT, "tools", "play", "check_reviews_readonly.py")], capture_output=True).returncode == 0, "candado estático OK")
    sys.path.insert(0, os.path.join(ROOT, "tools", "play"))
    import play_common
    os.environ.update({k: v for k, v in env.items() if k.startswith("PLAY_")})
    fake_play.reset()
    svc = play_common.build_service(json.load(open(sa)), read_only=True)
    try:
        svc.reviews().reply(packageName="com.srg.dreamracing", reviewId="gp:id0001", body={"replyText": "hola"}).execute()
        blocked = False
    except RuntimeError as e:
        blocked = "SOLO LECTURA" in str(e)
    check(blocked and not any(":reply" in p for m, p in fake_play.STATE["log"]), "responder una reseña (POST :reply) se rechaza antes de salir")
    print("\n" + ("TODO OK" if not FAILS else "FALLARON %d: %s" % (len(FAILS), FAILS)))
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
