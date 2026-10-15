#!/usr/bin/env python3
"""Resumen de uso de Supabase (sólo lectura) para calcular costos del modo online: llamadas por función, por minuto, bytes que bajan los
teléfonos, jugadores distintos y actividad de Realtime, desde los registros del proyecto (Management API → Logs). En el plan gratis los
registros duran 1 día: correrlo el mismo día de la prueba. NO imprime correos, ids ni IPs: sólo cuentas.

Uso (lo corre el flujo «Supabase · uso y costos»):  SUPABASE_ACCESS_TOKEN=… SUPABASE_PROJECT_ID=… python3 tools/online/supabase_usage.py [horas]
Sale por la consola y en usage.json."""
import json, os, sys, time, urllib.parse, urllib.request
from datetime import datetime, timedelta, timezone

TOKEN = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
REF = os.environ.get("SUPABASE_PROJECT_ID", "")
HOURS = min(float(sys.argv[1]) if len(sys.argv) > 1 else 24.0, 23.9) # (el API acepta como mucho 24 h por consulta)
API = "https://api.supabase.com/v1/projects/%s" % REF

def get(path, params=None):
    url = API + path + ("?" + urllib.parse.urlencode(params) if params else "")
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + TOKEN, "User-Agent": "dream-racing-usage"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return {"error": "HTTP %d: %s" % (e.code, e.read().decode()[:300])}
    except Exception as e:  # noqa
        return {"error": str(e)[:300]}

END = datetime.now(timezone.utc).replace(second=0, microsecond=0)
START = END - timedelta(minutes=int(HOURS * 60))
ISO = lambda d: d.strftime("%Y-%m-%dT%H:%M:%S.000Z") # (el API rechaza microsegundos y «+00:00»)

def logs(sql, start=None, end=None):
    """Registros del proyecto (desde 2026: GET …/analytics/endpoints/logs, SQL de ClickHouse sobre una sola tabla «logs»; máx. 24 h por consulta)."""
    time.sleep(3.0)  # (el API frena con 429 si se le pide muy seguido)
    r = get("/analytics/endpoints/logs", {"sql": sql, "iso_timestamp_start": ISO(start or START), "iso_timestamp_end": ISO(end or END)})
    if isinstance(r, dict) and r.get("error"):
        return {"error": r["error"]}
    return r.get("result", r) if isinstance(r, dict) else r

out = {"desde": START.isoformat(), "hasta": END.isoformat(), "horas": HOURS}
if not TOKEN or not REF:
    print("Faltan SUPABASE_ACCESS_TOKEN / SUPABASE_PROJECT_ID")
    sys.exit(1)

# 1) qué fuentes hay y cómo se llama la columna de la fuente (la documentación dice «source» y el aviso de cambio «source_name»)
SRC = None
for col in ["source_name", "source"]:
    r = logs("select %s as src, count() as n from logs group by src order by n desc" % col)
    if isinstance(r, list):
        SRC = col
        out["sources"] = r
        break
    out.setdefault("sources_errores", []).append(r.get("error"))
if SRC is None:
    print(json.dumps(out, indent=1, default=str))
    sys.exit(0)

# 2) los nombres de los campos de cada fuente (sólo los NOMBRES, no los valores)
keys = {}
for src in ["edge_logs", "realtime_logs", "postgres_logs"]:
    r = logs("select arrayJoin(mapKeys(log_attributes)) as k, count() as n from logs where %s = '%s' group by k order by n desc limit 200" % (SRC, src))
    keys[src] = [x.get("k") for x in r] if isinstance(r, list) else r
out["keys"] = keys

def pick(src, *want):
    ks = keys.get(src) if isinstance(keys.get(src), list) else []
    for w in want:
        for k in ks:
            if k == w:
                return k
    for w in want:
        for k in ks:
            if w in k:
                return k
    return None

E = "%s = 'edge_logs'" % SRC
path = pick("edge_logs", "request.path", "path")
meth = pick("edge_logs", "request.method", "method")
clen = pick("edge_logs", "response.headers.content_length", "content_length")
subj = pick("edge_logs", "request.sb.jwt.authorization.payload.subject", "payload.subject", "subject")
out["campos"] = {"path": path, "method": meth, "bytes": clen, "user": subj}
A = lambda k: "log_attributes['%s']" % k
if path:
    out["by_path"] = logs("select %s as path, count() as n%s from logs where %s group by path order by n desc limit 80" % (
        A(path), (", sum(toInt64OrZero(%s)) as bytes" % A(clen)) if clen else "", E))
    out["by_minute"] = logs("select formatDateTime(toStartOfMinute(timestamp), '%%Y-%%m-%%d %%H:%%i') as minute, count() as n, countIf(startsWith(%s, '/rest/v1/rpc/')) as rpc%s%s "
                            "from logs where %s group by minute order by minute" % (A(path), (", sum(toInt64OrZero(%s)) as bytes" % A(clen)) if clen else "",
                            (", uniqExact(%s) as users" % A(subj)) if subj else "", E))
    if subj:  # llamadas por jugador y por función (cuenta, sin ids: se numeran)
        rows = logs("select %s as u, %s as path, count() as n from logs where %s and startsWith(%s, '/rest/v1/rpc/') group by u, path order by n desc limit 400" % (A(subj), A(path), E, A(path)))
        if isinstance(rows, list):
            alias = {}
            for x in rows:
                x["u"] = "jugador %d" % alias.setdefault(x.get("u"), len(alias) + 1)
        out["by_user_path"] = rows
R = "%s = 'realtime_logs'" % SRC
out["realtime_by_minute"] = logs("select formatDateTime(toStartOfMinute(timestamp), '%%Y-%%m-%%d %%H:%%i') as minute, count() as n from logs where %s group by minute order by minute" % R)
out["realtime_kinds"] = logs("select substring(event_message, 1, 70) as msg, count() as n from logs where %s group by msg order by n desc limit 40" % R)

# los totales que guarda Supabase (por día)
for ep in ["usage.api-counts", "usage.api-requests-count"]:
    out[ep] = get("/analytics/endpoints/" + ep, {"interval": "1day"})

json.dump(out, open("usage.json", "w"), indent=1, default=str)
print("== Ventana %s → %s (%.0f h)" % (START.strftime("%d/%m %H:%M"), END.strftime("%d/%m %H:%M"), HOURS))
for k, v in out.items():
    if k in ("desde", "hasta", "horas"):
        continue
    print("\n== %s" % k)
    if isinstance(v, list):
        for r in v[:500]:
            print("  " + json.dumps(r, default=str, ensure_ascii=False))
    else:
        print("  " + json.dumps(v, default=str, ensure_ascii=False)[:4000])
