"""Física y ficha de tienda de los 26 autos definitivos. Parte de las fichas que ya tenían (make_vehicles.CARS y batch2.SPEC), agrega los 4 modelos nuevos
(Pampa R2 Turbo urbano, Pro GT, Moust Extreme y el R2 Rally) y ordena todo de menor a mayor precio.
La pickup, el camión y el Bisonte vienen de la versión HTML (vehicles.json): no se redefinen acá, solo se les ajusta la ficha."""
import copy
import make_vehicles as MV
import batch2 as B2
from batch2 import _s, _c
from make_vehicles import SURF_ROAD, SURF_MIX, SURF_OFF

SPEC = {}
SPEC.update(MV.CARS)
SPEC.update(B2.SPEC)
for k in ('safari', 'volcan', 'veltor_gtr_hd'):
    SPEC.pop(k, None)

# ── autos nuevos
SPEC['hatch'] = _s('genesis', 'Pampa R2 Turbo', '🚗', 'Hatch urbano · el auto de todos', 4, 1150, 0.52, 0.20, (1.5, 1.55), 0.34, 0.6, 270, 7000, True,
                   [3.55, 2.05, 1.42, 1.08, 0.86, 0.72], 4.2, 'FWD', 1.0, 0.5, 350, 10.5, 0.56, 10.0, 0.74, 0.98, SURF_ROAD, 'road', 0.14, 0.18, 0.13, 0.4, 0.13, 0.016,
                   _c('PAMPA', 'R2 Turbo', 'Hatch urbano', 9000, '1.6 turbo 190 cv', 'FWD', 2024,
                      'Chiquito, liviano y noble: el auto de todos los días. Perdona los errores, es fácil de manejar y es el mejor lugar para empezar.', '#e11d2a', '#f5f5f2', '#1b1d22'))
SPEC['hatch2'] = _s('genesis', 'Pampa R2 Rally', '🏁', 'Hatch de rally · ágil y filoso', 4, 1180, 0.50, 0.22, (1.55, 1.6), 0.34, 0.6, 410, 7500, True,
                    [3.62, 2.2, 1.55, 1.18, 0.95, 0.78], 4.1, 'AWD', 0.58, 0.5, 900, 11.5, 0.56, 10.5, 0.78, 1.0, SURF_MIX, 'road', 0.13, 0.17, 0.14, 0.5, 0.11, 0.017,
                    _c('PAMPA', 'R2 Rally', 'Hatch de rally', 24000, '1.6 turbo 280 cv', 'AWD', 2026,
                       'La versión de rally del R2: tracción integral, 280 cv y la librea del equipo. Se tira a las curvas como pocos y perdona poco en las rectas largas.', '#f2f2ee', '#e11d2a', '#1b1d22'))
SPEC['pro_gt'] = _s('genesis', 'Altair Pro GT', '🏎️', 'GT de pista · motor atrás, tracción pura', 6, 1290, 0.44, 0.11, (1.7, 1.8), 0.38, 0.65, 520, 8800, False,
                    [3.2, 2.2, 1.7, 1.38, 1.14, 0.96], 4.1, 'RWD', 0.0, 0.5, 1150, 12.8, 0.5, 11.0, 0.9, 1.12, SURF_ROAD, 'road', 0.115, 0.155, 0.13, 0.4, 0.08, 0.014,
                    _c('ALTAIR', 'Pro GT', 'GT de pista', 92000, 'Bóxer 4.0 · 510 cv · 8800 rpm', 'RWD', 2027,
                       'El motor va detrás del eje trasero: sale de las curvas como un cohete y se va de cola si lo apurás. Un GT de pista pensado para manos expertas.', '#f5f5f2', '#e11d2a', '#2b2f36'))
SPEC['moust'] = _s('genesis', 'Moust Extreme', '👹', 'Superdeportivo extremo · 800 cv de mal carácter', 8, 1560, 0.42, 0.10, (1.8, 1.9), 0.4, 0.68, 1050, 8200, True,
                   [3.3, 2.3, 1.78, 1.42, 1.17, 0.99, 0.84], 3.8, 'AWD', 0.38, 0.38, 1300, 13.5, 0.5, 11.2, 0.84, 1.14, SURF_ROAD, 'slick', 0.112, 0.152, 0.17, 0.35, 0.07, 0.013,
                   _c('MOUST', 'Extreme', 'Superdeportivo extremo', 205000, 'V8 4.0 biturbo · 800 cv', 'AWD', 2027,
                      'Ancho, bajo y con aire de mal humor. Un V8 biturbo que empuja sin parar y una tracción integral que no te deja ir por el pasto.', '#3a3d44', '#e11d2a', '#0b0c0e'))

# ── tanda del 14/10/2026
SPEC['strix'] = _s('genesis', 'Strix Vandal RS', '🦅', 'Superdeportivo · aletas, carbono y mal genio', 10, 1480, 0.43, 0.11, (1.75, 1.85), 0.38, 0.65, 860, 8600, True,
                   [3.2, 2.3, 1.78, 1.42, 1.18, 0.99, 0.84], 3.8, 'AWD', 0.38, 0.38, 1250, 13.5, 0.5, 11.0, 0.82, 1.12, SURF_ROAD, 'road', 0.115, 0.155, 0.17, 0.35, 0.07, 0.013,
                   _c('STRIX', 'Vandal RS', 'Superdeportivo', 170000, 'V10 5.2 biturbo · 820 cv', 'AWD', 2027,
                      'Ancho, bajo y lleno de aletas de carbono. Un V10 biturbo que no se cansa de empujar y una tracción integral que lo pega al asfalto: para los que ya saben frenar tarde.', '#3a3d44', '#ff6a08', '#1b1d22'))
SPEC['police'] = _s('genesis', 'Interceptor DRP', '🚓', 'Patrullero de persecución · V8 preparado', 8, 1720, 0.48, 0.14, (1.6, 1.7), 0.38, 0.64, 900, 7600, True,
                    [3.1, 2.2, 1.65, 1.32, 1.08, 0.9, 0.76], 3.6, 'AWD', 0.42, 0.4, 1200, 13.0, 0.52, 10.5, 0.86, 1.1, SURF_MIX, 'road', 0.12, 0.16, 0.2, 0.4, 0.08, 0.014,
                    _c('DRP', 'Interceptor', 'Patrullero de persecución', 140000, 'V8 5.0 biturbo · 700 cv', 'AWD', 2027,
                       'El patrullero de la Policía de Dream City: V8 biturbo, tracción integral y una trompa reforzada para cerrar el paso. El mismo que te persigue en las rutas, ahora en tu garaje.', '#f2f2ee', '#1a4fe0', '#c0c5cc'))
# monoplaza: vehículo ESPECIAL (no está en la tienda ni en el orden; se habilita con Release.SPECIAL_OPEN en una actualización o evento). Aerodinámica de base (aero).
SPEC['f1'] = _s('genesis', 'Dream Fórmula DR-1', '🏎️', 'Monoplaza de competición · alerones y slicks', 6, 800, 0.38, 0.06, (3.0, 3.2), 0.45, 0.75, 700, 12000, True,
                [3.2, 2.55, 2.1, 1.78, 1.53, 1.35, 1.2, 1.07], 4.4, 'RWD', 0.0, 0.5, 900, 16.0, 0.42, 13.0, 1.0, 1.25, SURF_ROAD, 'slick', 0.11, 0.14, 0.12, 0.25, 0.04, 0.011,
                _c('DREAM', 'Fórmula DR-1', 'Monoplaza de competición', 0, 'V6 1.6 turbo híbrido · 1.000 cv', 'RWD', 2027,
                   'Un monoplaza de verdad: 800 kg, mil caballos y alerones que lo aplastan contra el piso a medida que acelera. En las curvas rápidas no hay nada igual; en la tierra, ni lo intentes.', '#e11d2a', '#f2f2ee', '#1b1d22'))
SPECIAL = {'f1': dict(aeroBaseF=1.7, aeroBaseR=2.5)}   # ClA (m²) de base por eje: con 0,6·v² da ~1,5 veces su peso a 250 km/h

# precios definitivos (de menor a mayor): el más lento y fácil de comprar es el primero
PRICE = {
    'hatch': 9000, 'torito': 18000, 'hatch2': 24000, 'clasico60': 30000, 'titan': 32000, 'pickup': 34000, 'suv': 38000, 'kodiak': 44000, 'camo': 46000,
    'buggy': 50000, 'muscle': 56000, 'truck': 60000, 'rally80': 64000, 'gt': 72000, 'trilux': 78000, 'pro_gt': 92000, 'kl5': 98000, 'trilux_s': 104000,
    'trilux_gt': 118000, 'gt3': 130000, 'veltor': 150000, 'veltor_s': 185000, 'genesis': 190000, 'moust': 205000, 'police': 140000, 'strix': 170000, 'veltor_gtr': 225000, 'hyper': 260000,
}
ORDER = sorted(PRICE, key=lambda k: PRICE[k])
for k, p in PRICE.items():
    if k in SPEC:
        SPEC[k]['cat']['price'] = p
STARTER = 'hatch'
