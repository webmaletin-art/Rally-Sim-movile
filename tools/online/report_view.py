#!/usr/bin/env python3
"""Lee los reportes de jugadores (tabla public.reports) y los explica en texto: quién reportó a quién, qué escribió, dónde estaba y a qué velocidad.
Los reportes NO castigan a nadie: esto sirve para decidir a mano.

Cómo conseguir los datos (Supabase → Table editor → reports → exportar JSON, o desde el SQL editor:  select * from public.reports order by id desc;).
Uso:  python3 tools/online/report_view.py reportes.json            # uno o varios reportes (lista de filas o de «evidence»)
      python3 tools/online/report_view.py reportes.json --id 12    # sólo el reporte 12
Sin dependencias (sólo Python 3)."""
import json, math, sys
from datetime import datetime

def rows_of(data):
    if isinstance(data, dict):
        data = data.get("data", [data]) if "evidence" not in data and "reporter" not in data else [data]
    out = []
    for r in data:
        ev = r.get("evidence", r)
        if isinstance(ev, str):
            ev = json.loads(ev)
        out.append((r.get("id"), r.get("status", ""), ev))
    return out

def dist(a, b):
    return math.hypot(a["x"] - b["x"], a["z"] - b["z"])

def trail_report(name, tr):
    if not tr:
        print(f"  {name}: sin rastro guardado.")
        return
    sp = [float(p.get("speed", 0)) for p in tr]
    print(f"  {name}: {len(tr)} puntos · velocidad máx {max(sp):.0f} km/h · media {sum(sp) / len(sp):.0f} km/h")
    jumps = 0
    for a, b in zip(tr, tr[1:]):
        try:
            dt = (datetime.fromisoformat(b["at"].replace("Z", "+00:00")) - datetime.fromisoformat(a["at"].replace("Z", "+00:00"))).total_seconds()
        except Exception:
            continue
        if dt > 0:
            v = dist(a, b) / dt * 3.6
            if v > 450:  # más rápido que cualquier auto del juego: teletransporte o trampa
                jumps += 1
                print(f"    ⚠ salto de {dist(a, b):.0f} m en {dt:.1f} s (≈{v:.0f} km/h) entre {a['at']} y {b['at']}")
    if jumps == 0:
        print("    sin saltos raros de posición.")
    fast = [p for p in tr if float(p.get("speed", 0)) > 350]
    if fast:
        print(f"    ⚠ {len(fast)} puntos por encima de 350 km/h.")

def show(rid, status, ev):
    print("=" * 78)
    print(f"REPORTE {rid if rid is not None else ''} {('[' + status + ']') if status else ''} · {ev.get('at', '')}")
    print(f"  Reportó: {ev.get('reporter_name', '?')} ({ev.get('reporter', '')})")
    print(f"  Reportado: {ev.get('reported_name', '?')} ({ev.get('reported', '')})")
    if ev.get("note"):
        print(f"  Nota: {ev['note']}")
    cp = ev.get("chat_penalties", {})
    print(f"  Faltas de chat del reportado: {cp.get('strikes', 0)} en el nivel actual · nivel de bloqueo {cp.get('level', 0)} · insultos en total {cp.get('total_hits', 0)}")
    chat = ev.get("reported_chat", [])
    print(f"\n  Lo último que escribió el reportado ({len(chat)} mensajes; los insultos ya vienen tapados con ***):")
    for m in chat:
        flag = "  ⚠" if "*" in str(m.get("body", "")) else "   "
        print(f"   {flag} [{m.get('channel')}] {m.get('at', '')}  {m.get('body', '')}")
    cl = ev.get("client", {})
    print("\n  Lo que vio el teléfono de quien reporta:")
    print(f"    build {cl.get('build', '?')} · posición propia {cl.get('my_pos')} · velocidad propia {cl.get('my_kmh', 0):.0f} km/h")
    for e in cl.get("events", []):
        print(f"    evento: {e.get('what')} en ({e.get('x')}, {e.get('z')}) a {e.get('kmh')} km/h")
    for m in cl.get("their_chat_seen", []):
        print(f"    visto en pantalla [{m.get('channel')}]: {m.get('body')}")
    tries = [t for t in cl.get("my_chat_tries", []) if not t.get("ok", True) or t.get("masked")]
    if tries:
        print("    intentos de chat de quien reporta que el filtro frenó o tapó (para ver si él también insultó):")
        for t in tries:
            print(f"      {t.get('body')}  ({t.get('reason') or 'tapado'})")
    print("\n  Rastro de posiciones:")
    trail_report("reportado", ev.get("reported_trail", []))
    trail_report("quien reporta", ev.get("reporter_trail", []))
    a, b = ev.get("reported_trail", []), ev.get("reporter_trail", [])
    if a and b:
        close = min(dist(p, q) for p in a for q in b)
        print(f"  Distancia mínima entre los dos en los rastros guardados: {close:.0f} m ({'estuvieron cerca' if close < 60 else 'nunca estuvieron cerca: ojo con reportes sin contacto'})")
    print()

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    only = None
    if "--id" in sys.argv:
        only = int(sys.argv[sys.argv.index("--id") + 1])
    for rid, status, ev in rows_of(data):
        if only is None or rid == only:
            show(rid, status, ev)

if __name__ == "__main__":
    main()
