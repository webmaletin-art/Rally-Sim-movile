#!/usr/bin/env python3
"""Reseñas de Google Play, SÓLO LECTURA (androidpublisher.reviews.list, un GET paginado). No responde reseñas, no escribe nada en Play.

Uso: python3 tools/play/reviews.py --out salida/
Escribe en --out (pensado para subirse como ARTEFACTO de GitHub con retención corta; NUNCA al repositorio):
  reviews_raw.json  reseñas tal cual las devuelve Google (contiene nombres y textos de jugadores: DATOS PERSONALES)
  informe.md        resumen por temas con fragmentos cortos de texto, sin nombres (también personal: sólo en el artefacto)
  resumen.json      sólo agregados (sin texto ni nombres)
En la salida estándar y en el resumen del flujo se imprimen SÓLO agregados: cantidades, calificaciones, idiomas, versiones, temas y el alcance temporal OBSERVADO
(fecha de la reseña más vieja y más nueva devueltas), que sirve de evidencia del período que realmente cubre la API."""
import argparse
import collections
import datetime
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from play_common import Report, build_service, explain_http_error, fail, load_config, masked_account, service_account_info  # noqa: E402

# Temas (palabras clave en es/en/pt/fr/it/de). Clasificación simple por palabras: orienta, no reemplaza leer las reseñas.
THEMES = {
    "Cierres / errores": r"crash|se cierra|cierra solo|se cierra|cierre|se tranca|se traba|bug|error|falla|fallo|no funciona|no abre|no inicia|não abre|fecha sozinho|plant|ne s'ouvre|funktioniert nicht|stürzt|crasht|si chiude|non funziona|freez|congel",
    "Rendimiento / lag": r"lag|lento|slow|fps|trab|ralent|laggy|ruckel|langsam|lent\b|lentitud|calent|se calienta|heat|bater|battery",
    "Compras / pagos": r"compra|compré|pagu|cobr|monedas|coins|purchase|bought|refund|reembols|pago|pagament|achat|kauf|acquisto|restaur",
    "Cuenta / login": r"cuenta|login|iniciar sesi|contraseña|password|correo|email|e-mail|registr|sign.?in|conta\b|senha|compte|konto|account",
    "Controles / manejo": r"control|volante|steer|manej|handling|acelera|freno|brake|tilt|botones|buttons|dirección|conduc|pilot",
    "Gráficos / sonido": r"gráfic|graphic|visual|textur|sonido|audio|música|music|sound|som\b|son\b|musique|ton\b|grafik",
    "Contenido / modos": r"modo|mode|mapa|map|autos|cars|carros|carreras|races|level|nivel|aventura|adventure|online|multijugador|multiplayer",
    "Precio / anuncios": r"precio|caro|price|expensive|anuncio|publicidad|ads\b|advert|preço|prix|werbung|pubblicit",
}
SUGGEST = r"sugier|suger|ser[ií]a (bueno|genial|lindo)|podr[ií]an|deber[ií]an|agreg|a[ñn]ad|falta|me gustar[ií]a|ojal[aá]|please add|should|would be (nice|great)|wish|suggest|add more|gostaria|poderiam|adicion|j'aimerais|devriez|ajout|vorschlag|sollte|würde|vorrei|dovreste|aggiung"
POSITIVE = r"excelente|genial|muy bueno|me encanta|increíble|great|awesome|love|amazing|perfect|ótimo|adoro|j'adore|super|fantastic|bellissim|toll"


def fetch(svc, pkg, max_pages=30):
    reviews, token, pages = [], None, 0
    while pages < max_pages:
        kw = {"packageName": pkg, "maxResults": 100}
        if token:
            kw["token"] = token
        r = svc.reviews().list(**kw).execute()
        reviews.extend(r.get("reviews", []))
        token = (r.get("tokenPagination") or {}).get("nextPageToken")
        pages += 1
        if not token:
            break
    return reviews, pages


def user_comment(rv):
    for c in rv.get("comments", []):
        if "userComment" in c:
            return c["userComment"]
    return {}


def analyze(reviews):
    stars = collections.Counter()
    langs = collections.Counter()
    versions = collections.Counter()
    devices = collections.Counter()
    themes = collections.defaultdict(list)
    suggestions, replied, stamps = [], 0, []
    for rv in reviews:
        uc = user_comment(rv)
        text = (uc.get("text") or uc.get("originalText") or "").strip()
        n = int(uc.get("starRating") or 0)
        stars[n] += 1
        langs[uc.get("reviewerLanguage") or "?"] += 1
        versions[str(uc.get("appVersionName") or "?") + "/" + str(uc.get("appVersionCode") or "?")] += 1
        dm = uc.get("deviceMetadata") or {}
        devices[("%s %s" % (dm.get("manufacturer", ""), dm.get("productName", ""))).strip() or "?"] += 1
        ts = int(((uc.get("lastModified") or {}).get("seconds")) or 0)
        if ts:
            stamps.append(ts)
        if any("developerComment" in c for c in rv.get("comments", [])):
            replied += 1
        low = text.lower()
        for name, pat in THEMES.items():
            if re.search(pat, low):
                themes[name].append((n, text))
        if re.search(SUGGEST, low):
            suggestions.append((n, text))
    return {"stars": stars, "langs": langs, "versions": versions, "devices": devices, "themes": themes, "suggestions": suggestions, "replied": replied, "stamps": stamps}


def iso(ts):
    return datetime.datetime.fromtimestamp(ts, datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def aggregate(reviews, a, pages):
    """Sólo agregados: nada de nombres ni textos."""
    total = len(reviews)
    avg = (sum(k * v for k, v in a["stars"].items() if k) / max(1, sum(v for k, v in a["stars"].items() if k))) if total else 0
    out = {"fecha_consulta": iso(int(datetime.datetime.now(datetime.timezone.utc).timestamp())), "paginas_leidas": pages, "reseñas_devueltas": total,
           "calificacion_promedio": round(avg, 2), "por_estrellas": {str(k): a["stars"].get(k, 0) for k in (5, 4, 3, 2, 1)},
           "con_respuesta_del_desarrollador": a["replied"], "idiomas": dict(a["langs"].most_common(8)),
           "versiones_de_la_app": dict(a["versions"].most_common(8)), "temas": {k: len(v) for k, v in sorted(a["themes"].items(), key=lambda x: -len(x[1]))},
           "con_sugerencias": len(a["suggestions"])}
    if a["stamps"]:
        lo, hi = min(a["stamps"]), max(a["stamps"])
        out["alcance_temporal_observado"] = {"mas_vieja": iso(lo), "mas_nueva": iso(hi), "dias_cubiertos": round((hi - lo) / 86400, 1)}
    else:
        out["alcance_temporal_observado"] = None
    return out


def digest(reviews, a, agg):
    L = ["# Informe de reseñas de Google Play (DATOS PERSONALES: sólo para uso interno; no subir al repositorio)", "",
         "Consulta: %s · reseñas devueltas por la API: %d · calificación promedio: %s" % (agg["fecha_consulta"], agg["reseñas_devueltas"], agg["calificacion_promedio"]), ""]
    if agg["alcance_temporal_observado"]:
        t = agg["alcance_temporal_observado"]
        L.append("Alcance temporal OBSERVADO: de %s a %s (%s días). Es lo que la API devolvió esta vez; no prueba por sí solo cuál es el límite de Google." % (t["mas_vieja"], t["mas_nueva"], t["dias_cubiertos"]))
    L += ["", "## Calificaciones", ""] + ["- %s estrellas: %d" % (k, v) for k, v in agg["por_estrellas"].items()] + ["", "## Temas repetidos", ""]
    for name, items in sorted(a["themes"].items(), key=lambda x: -len(x[1])):
        L.append("### %s (%d)" % (name, len(items)))
        for n, t in sorted(items, key=lambda x: x[0])[:8]:
            L.append("- %s★ «%s»" % (n, re.sub(r"\s+", " ", t)[:160]))
        L.append("")
    L += ["## Sugerencias detectadas (%d)" % len(a["suggestions"]), ""]
    for n, t in a["suggestions"][:25]:
        L.append("- %s★ «%s»" % (n, re.sub(r"\s+", " ", t)[:200]))
    low = [(user_comment(r).get("starRating") or 0, (user_comment(r).get("text") or "").strip(), r.get("reviewId", "")) for r in reviews]
    pend = [x for x in low if x[0] and x[0] <= 3]
    L += ["", "## Reseñas de 1 a 3 estrellas para atender primero (%d)" % len(pend), ""]
    for n, t, rid in pend[:30]:
        L.append("- %s★ [%s] «%s»" % (n, rid[:8], re.sub(r"\s+", " ", t)[:200]))
    L += ["", "> Las respuestas NO se publican desde acá. Los borradores se preparan aparte y los aprueba una persona."]
    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="reviews_out")
    ap.add_argument("--config")
    args = ap.parse_args()
    cfg = load_config(args.config)
    info = service_account_info()
    if not info:
        fail("Falta el secreto GOOGLE_PLAY_SERVICE_ACCOUNT: no se pueden consultar las reseñas.")
    print("Cuenta de servicio: %s" % masked_account(info))
    svc = build_service(info, read_only=True)
    pkg = cfg["package"]
    try:
        reviews, pages = fetch(svc, pkg)
    except Exception as e:  # noqa: BLE001
        msg = explain_http_error(e, pkg)
        if "403" in msg:
            msg += "\n   → Para LEER reseñas la cuenta necesita en Play Console permisos de la app sobre reseñas/«Ver información de la app» (y «Responder a las reseñas» según Google); este flujo NUNCA responde."
        fail(msg)
    a = analyze(reviews)
    agg = aggregate(reviews, a, pages)
    os.makedirs(args.out, exist_ok=True)
    json.dump(reviews, open(os.path.join(args.out, "reviews_raw.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(agg, open(os.path.join(args.out, "resumen.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    open(os.path.join(args.out, "informe.md"), "w", encoding="utf-8").write(digest(reviews, a, agg))
    rep = Report("Reseñas de %s (SOLO LECTURA; sin nombres ni textos)" % pkg)
    rep.ok("Google Play devolvió %d reseñas en %d página(s)" % (agg["reseñas_devueltas"], pages))
    if not reviews:
        rep.warn("0 reseñas: no hay datos para comprobar el alcance temporal. Si la app todavía no es pública o nadie dejó comentario, es lo esperado")
    else:
        rep.info("Calificación promedio %s · por estrellas %s" % (agg["calificacion_promedio"], agg["por_estrellas"]))
        t = agg["alcance_temporal_observado"]
        if t:
            rep.info("Alcance temporal OBSERVADO: %s → %s (%s días)" % (t["mas_vieja"], t["mas_nueva"], t["dias_cubiertos"]))
        rep.info("Idiomas %s · versiones %s" % (agg["idiomas"], agg["versiones_de_la_app"]))
        rep.info("Temas (cantidad de reseñas): %s · con sugerencias: %d · ya respondidas: %d" % (agg["temas"], agg["con_sugerencias"], agg["con_respuesta_del_desarrollador"]))
    rep.info("Archivos con datos personales: sólo en el artefacto del flujo (retención corta); nada se guarda en el repositorio")
    rep.emit()


if __name__ == "__main__":
    main()
