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
HOURS = float(sys.argv[1]) if len(sys.argv) > 1 else 24.0
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

END = datetime.now(timezone.utc)
START = END - timedelta(hours=HOURS)

def logs(sql, start=None, end=None):
    r = get("/analytics/endpoints/logs.all", {"sql": sql, "iso_timestamp_start": (start or START).isoformat(), "iso_timestamp_end": (end or END).isoformat()})
    if isinstance(r, dict) and r.get("error"):
        return {"error": r["error"]}
    return r.get("result", r) if isinstance(r, dict) else r

def logs_by_hour(sql):
    """El API de registros acota cada consulta: se pide hora por hora y se junta."""
    out, errs = [], []
    t = START
    while t < END:
        t2 = min(t + timedelta(hours=1), END)
        r = logs(sql, t, t2)
        if isinstance(r, dict) and r.get("error"):
            errs.append(str(r["error"]))
        elif isinstance(r, list):
            out.extend(r)
        t = t2
        time.sleep(0.4)
    return out, errs[:3]

REQ = "from edge_logs as t cross join unnest(t.metadata) as m cross join unnest(m.request) as r"
Q = {
    # cuántas llamadas por función o ruta (rpc = funciones del juego; auth; realtime; storage)
    "by_path": "select r.path as path, r.method as method, count(*) as n %s group by path, method order by n desc limit 80" % REQ,
    # por minuto: llamadas totales y a funciones
    "by_minute": "select format_timestamp('%%Y-%%m-%%d %%H:%%M', timestamp_trunc(t.timestamp, minute)) as minute, count(*) as n, countif(r.path like '/rest/v1/rpc/%%') as rpc %s group by minute order by minute" % REQ,
    # bytes que bajan (content-length de la respuesta) por ruta
    "bytes": ("select r.path as path, count(*) as n, sum(safe_cast(h.content_length as int64)) as bytes from edge_logs as t cross join unnest(t.metadata) as m "
              "cross join unnest(m.request) as r cross join unnest(m.response) as resp cross join unnest(resp.headers) as h group by path order by bytes desc limit 60"),
    # jugadores distintos por minuto (sólo la cuenta, sin ids)
    "users_by_minute": ("select format_timestamp('%Y-%m-%d %H:%M', timestamp_trunc(t.timestamp, minute)) as minute, count(distinct p.subject) as users, count(*) as n "
                        "from edge_logs as t cross join unnest(t.metadata) as m cross join unnest(m.request) as r cross join unnest(r.sb) as sb "
                        "cross join unnest(sb.jwt) as j cross join unnest(j.authorization) as a cross join unnest(a.payload) as p group by minute order by minute"),
    # Realtime: qué pasa por minuto (conexiones, uniones a canales, errores) — los registros no traen el texto de los mensajes
    "realtime_by_minute": "select format_timestamp('%Y-%m-%d %H:%M', timestamp_trunc(t.timestamp, minute)) as minute, count(*) as n from realtime_logs as t group by minute order by minute",
    "realtime_kinds": "select substr(t.event_message, 1, 70) as msg, count(*) as n from realtime_logs as t group by msg order by n desc limit 40",
}

out = {"desde": START.isoformat(), "hasta": END.isoformat(), "horas": HOURS}
if not TOKEN or not REF:
    print("Faltan SUPABASE_ACCESS_TOKEN / SUPABASE_PROJECT_ID")
    sys.exit(1)
for k, sql in Q.items():
    rows, errs = logs_by_hour(sql)
    out[k] = rows
    if errs:
        out[k + "_errores"] = errs
# los totales que guarda Supabase (por día)
for ep in ["usage.api-counts", "usage.api-requests-count"]:
    out[ep] = get("/analytics/endpoints/" + ep, {"interval": "1day"})

# juntar lo que vino hora por hora (las agrupaciones se repiten)
def merge(rows, key, nums):
    acc = {}
    for r in rows:
        kk = tuple(r.get(x) for x in key)
        a = acc.setdefault(kk, {x: r.get(x) for x in key})
        for nm in nums:
            a[nm] = (a.get(nm) or 0) + int(r.get(nm) or 0)
    return sorted(acc.values(), key=lambda a: -(a.get(nums[0]) or 0))
out["by_path"] = merge(out["by_path"], ["path", "method"], ["n"])
out["bytes"] = merge(out["bytes"], ["path"], ["bytes", "n"])
out["realtime_kinds"] = merge(out["realtime_kinds"], ["msg"], ["n"])

json.dump(out, open("usage.json", "w"), indent=1, default=str)
print("== Ventana %s → %s (%.0f h)" % (START.strftime("%d/%m %H:%M"), END.strftime("%d/%m %H:%M"), HOURS))
for k in ["by_path", "bytes", "realtime_kinds"]:
    print("\n== %s" % k)
    for r in out[k][:60]:
        print("  " + json.dumps(r, default=str, ensure_ascii=False))
for k in ["by_minute", "users_by_minute", "realtime_by_minute"]:
    rows = out[k]
    print("\n== %s (%d minutos con actividad)" % (k, len(rows)))
    for r in rows:
        print("  " + json.dumps(r, default=str, ensure_ascii=False))
for k in out:
    if k.endswith("_errores"):
        print("\n!! %s: %s" % (k, out[k]))
for ep in ["usage.api-counts", "usage.api-requests-count"]:
    print("\n== %s\n  %s" % (ep, json.dumps(out[ep], default=str)[:3000]))
