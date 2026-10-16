#!/usr/bin/env python3
"""Simulación de progresión económica de Dream Racing (fase 4, 16/10/2026).

Sin simular partidas: usa los PREMIOS, PRECIOS y REGLAS REALES del juego y calcula cuánto tarda cada perfil de jugador en llegar a cada auto.
Fuentes (todas del repositorio, nada inventado):
  - tools/econ/game_data_snapshot.txt: las 79 carreras del mapa (tipo, largo, premio, posición) y las prestaciones de los 28 autos, volcadas por
    godot/tests/econ_dump.gd con el mismo código del juego (OW.build, CarBuild.perf_of). Para regenerarlo: tools/test/run_test.sh econ_dump 60 y
    grep -oE '(EV|CAR) \\{.*' test_logs/econ_dump.log > tools/econ/game_data_snapshot.txt
  - godot/game/data/catalog.json: precios de autos, mejoras, gomas, copas, logros.
  - Reglas copiadas de game/city/city_events.gd (REPEAT_K, PLACE_K, MEDAL_K, COOLDOWN) y game/data/rewards.gd (premio por medalla, caída 100/60/35/20 %).
Lo que NO es determinista está marcado como SUPUESTO (velocidad media, porcentaje de victorias, tiempo entre carreras, gastos por hora).

Uso: python3 tools/econ/progression_sim.py [--fix]      (--fix = con la corrección del 2.º puesto, ver docs/AUDITORIA_CICLO_DE_JUEGO.md fase 4)
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SNAP = os.path.join(ROOT, "tools", "econ", "game_data_snapshot.txt")
CATALOG = os.path.join(ROOT, "godot", "game", "data", "catalog.json")

# ── reglas reales (city_events.gd / rewards.gd) ──
REPEAT_K = 0.35          # repetir una carrera del mapa ya ganada
LOSE_K = 0.55            # (--fix) un resultado que NO es victoria, del 2.º intento en adelante: × 0,55 (2.º: 45 → 25 %, plata: 60 → 33 %; ambos debajo del 35 % de una victoria repetida)
MEDAL_K = [1.0, 0.6, 0.35]  # oro, plata, bronce (rally, montaña, velocidad)
PLACE_K = [1.0, 0.45, 0.25, 0.1]   # 1.º, 2.º, 3.º, 4.º+ (carreras con rivales)
COOLDOWN_S = 90.0        # una carrera del mapa no se puede volver a largar antes de 90 s
CUP_DECAY = [1.0, 0.6, 0.35, 0.2]  # copas: 1.ª vez, 2.ª, 3.ª, después
CUP_MEDAL = {"race": [0.2, 0.4, 0.6, 1.0], "other": [0.1, 0.4, 0.6, 1.0]}

# ── SUPUESTOS (no hay medición en el teléfono) ──
SPEED_MS = {"sprint": 26.0, "velocidad": 30.0, "rally": 19.0, "montana": 17.0, "persecucion": 24.0, "huida": 0.0, "circuito": 24.0, "drift": 0.0}
FIXED_S = {"huida": 90.0, "drift": 90.0}  # duración fija
TRAVEL_MS = 25.0          # 90 km/h promedio para ir de una carrera a otra (rutas + ciudad)
SETUP_S = 40.0            # frenar en el círculo, cuenta regresiva, resultado
COST_PER_H = 400.0        # nafta + peajes + gomas (auditoría E5: < $600/h)
CUP_RACE_S = 240.0        # una carrera de copa ≈ 4 min (menú incluido)

PROFILES = {
    # win: probabilidad de ganar una carrera; place2: si no gana, sale 2.º (resto 3.º)
    "A · nuevo":      {"win": 0.40, "place2": 0.6, "cup_medal": 2},
    "B · intermedio": {"win": 0.70, "place2": 0.8, "cup_medal": 3},
    "C · avanzado":   {"win": 0.95, "place2": 1.0, "cup_medal": 3},
}

MILESTONES = [("hatch2", "primer cambio (R2 Rally)"), ("rally80", "especializado (Rally 80)"), ("kl5", "gama media (KL5)"),
              ("veltor", "primer superdeportivo (Veltor, clase S)"), ("veltor_gtr", "superdeportivo tope (Veltor GTR)")]
UPGRADE_SET = 60000       # «un conjunto razonable de mejoras»: motor 2 + suspensión 2 + frenos 2 + gomas ≈ $60.000 (catálogo)


def load():
    evs, cars = [], {}
    for line in open(SNAP):
        tag, js = line.split(" ", 1)
        d = json.loads(js)
        if tag == "EV":
            evs.append(d)
        else:
            cars[d["id"]] = d
    cat = json.load(open(CATALOG))
    return evs, cars, cat


def race_seconds(e):
    if e["type"] in FIXED_S:
        return FIXED_S[e["type"]]
    return e["len"] / SPEED_MS.get(e["type"], 24.0)


def nonwin_k(p):
    """lo que paga en promedio un resultado que no es victoria (fracción del premio)"""
    return p["place2"] * PLACE_K[1] + (1 - p["place2"]) * PLACE_K[2]


def first_pass(evs, p, fix=False):
    """recorrido de descubrimiento: de Dream City a la carrera más cercana, y así; cada una se intenta hasta ganarla (SUPUESTO: al 3.er intento gana).
    Valor esperado exacto: P(llegar al intento i) × [gana: premio entero | no gana: PLACE_K × premio (× REPEAT_K desde el 2.º intento con --fix)]"""
    left = list(evs)
    x, y = 0.0, 0.0
    t = money = 0.0
    for _ in range(len(evs)):
        e = min(left, key=lambda e: math.hypot(e["x"] - x, e["y"] - y))
        left.remove(e)
        t += math.hypot(e["x"] - x, e["y"] - y) / TRAVEL_MS
        x, y = e["x"], e["y"]
        r = e["reward"]
        back = 0 if e["type"] in ("circuito", "huida", "drift") else e["len"] / TRAVEL_MS  # volver a la largada para reintentar
        reach = 1.0
        for i in range(3):
            pw = p["win"] if i < 2 else 1.0
            t += reach * (race_seconds(e) + SETUP_S + (back if i > 0 else 0))
            lose = nonwin_k(p) * r * (LOSE_K if (fix and i > 0) else 1.0)
            money += reach * (pw * r + (1 - pw) * lose)
            reach *= (1 - pw)
    return t / 3600.0, money


def repeat_rate(evs, p, fix):
    """$/h repitiendo las 2 carreras ganadas más rentables y cercanas entre sí (se alternan por el enfriamiento de 90 s)"""
    best = None
    rates = []
    for a in evs:
        for b in evs:
            if a is b:
                continue
            gap = math.hypot(a["x"] - b["x"], a["y"] - b["y"])
            if gap > 8000:
                continue
            cyc = 0.0
            pay = 0.0
            for e, nxt in ((a, b), (b, a)):
                end_to_next = gap if e["type"] in ("circuito", "huida", "drift") else gap + e["len"]  # (A→B termina lejos de la largada)
                cyc += race_seconds(e) + SETUP_S + end_to_next / TRAVEL_MS
                win_pay = REPEAT_K * e["reward"]
                lose_pay = nonwin_k(p) * e["reward"] * (LOSE_K if fix else 1.0)
                pay += p["win"] * win_pay + (1 - p["win"]) * lose_pay
            rate = pay / cyc * 3600.0
            rates.append(rate)
            if best is None or rate > best[0]:
                best = (rate, a["id"], b["id"], cyc)
    rates.sort()
    return best + (rates[len(rates) // 2], rates[int(len(rates) * 0.9)], len(rates))


def second_place_farm(evs, fix):
    """el agujero: salir 2.º a propósito en la carrera más rentable (sin ganar nunca)"""
    best = 0.0
    for e in evs:
        if e["type"] in ("huida", "drift", "persecucion"):
            continue  # ahí no hay «2.º puesto» ni medalla de plata
        k = MEDAL_K[1] if e["type"] in ("rally", "montana", "velocidad") else PLACE_K[1]  # plata o 2.º puesto
        cyc = race_seconds(e) + SETUP_S + max(COOLDOWN_S, (e["len"] / TRAVEL_MS if e["type"] != "circuito" else 0))
        pay = k * e["reward"] * (LOSE_K if fix else 1.0)
        best = max(best, pay / cyc * 3600.0)
    return best


def cups_first(cat, p):
    money = t = 0.0
    tiers = {x["id"]: x for x in cat["tiers"]}
    for tid in ("debut", "nacional"):  # las copas gratis (Release.PUBLIC_TIERS)
        base = tiers[tid]["base"]
        for e in cat["events"]:
            if e["tier"] != tid:
                continue
            kind = "race" if e["type"] == "race" else "other"
            money += base * (1.6 if e.get("final") else 1.0) * CUP_MEDAL[kind][p["cup_medal"]]
            t += CUP_RACE_S
    return t / 3600.0, money


def cups_repeat_rate(cat, p):
    """repetir la carrera de copa que más paga, ya con la caída al 20 %"""
    tiers = {x["id"]: x for x in cat["tiers"]}
    best = 0.0
    for e in cat["events"]:
        if e["tier"] not in ("debut", "nacional"):
            continue
        kind = "race" if e["type"] == "race" else "other"
        pay = tiers[e["tier"]]["base"] * (1.6 if e.get("final") else 1.0) * CUP_MEDAL[kind][p["cup_medal"]] * CUP_DECAY[3]
        best = max(best, pay / CUP_RACE_S * 3600.0)
    return best


def main():
    fix = "--fix" in sys.argv
    evs, cars, cat = load()
    ach = sum(int(a.get("cr", 0)) for a in cat["achievements"])
    print(f"Datos: {len(evs)} carreras del mapa (premio total 1.ª vez ${sum(e['reward'] for e in evs):,}), {len(cars)} autos, logros ${ach:,}"
          .replace(",", "."))
    print(f"Regla del 2.º puesto: {'CORREGIDA (no-victoria × 0,55 desde el 2.º intento)' if fix else 'ACTUAL (2.º = 45 % siempre, sin caída)'}\n")
    print(f"Granja «salir 2.º o sacar plata a propósito» (la carrera que más paga): ${second_place_farm(evs, fix):,.0f}/h".replace(",", "."))
    print()
    for name, p in PROFILES.items():
        t_ow, m_ow = first_pass(evs, p, fix)
        t_cup, m_cup = cups_first(cat, p)
        t_first = t_ow + t_cup
        m_first = m_ow + m_cup + ach
        rep = repeat_rate(evs, p, fix)
        cup_rep = cups_repeat_rate(cat, p)
        rate = max(rep[4], cup_rep)  # jugador típico: la MEDIANA de los pares de carreras cercanas (el mejor par es el techo)
        net = rate - COST_PER_H
        print(f"── {name} ──")
        print(f"  Primera vuelta de premios: {t_first:.1f} h · ${m_first:,.0f} (mapa ${m_ow:,.0f} en {t_ow:.1f} h, copas ${m_cup:,.0f}, logros ${ach:,})".replace(",", "."))
        print(f"  Repetible típico: ${rate:,.0f}/h bruto (mediana de {rep[6]} pares de carreras cercanas; p90 ${rep[5]:,.0f}/h; el mejor par {rep[1]}+{rep[2]} ${rep[0]:,.0f}/h; copas ${cup_rep:,.0f}/h) − gastos ${COST_PER_H:,.0f}/h = ${net:,.0f}/h neto".replace(",", "."))
        # progresión: primero la vuelta de premios únicos, después lo repetible
        start = 9000 - cars["hatch"]["price"]  # arranca con el R2 Turbo (9.000) y $0
        rows = []
        for cid, label in MILESTONES:
            need = cars[cid]["price"]
            if need <= m_first:
                h = t_first * need / max(m_first, 1)
                rows.append(f"    {label:42s} ${need:>7,}: {h:5.1f} h (con premios de 1.ª vez)")
            else:
                h = t_first + (need - m_first) / max(net, 1)
                rows.append(f"    {label:42s} ${need:>7,}: {h:5.1f} h")
            h_rep = need / max(net, 1)
            rows[-1] += f"   · sólo con lo repetible: {h_rep:5.1f} h"
        for r in rows:
            print(r.replace(",", "."))
        print(f"    {'conjunto razonable de mejoras':42s} ${UPGRADE_SET:>7,}: {UPGRADE_SET / max(net, 1):5.1f} h sólo con lo repetible".replace(",", "."))
        hours = [1, 5, 10, 15]
        acc = []
        for H in hours:
            if H <= t_first:
                acc.append(m_first * H / t_first)
            else:
                acc.append(m_first + (H - t_first) * net)
        print("  Plata acumulada: " + " · ".join(f"{H} h ${a:,.0f}" for H, a in zip(hours, acc)).replace(",", "."))
        print()
    _ = start


if __name__ == "__main__":
    main()
