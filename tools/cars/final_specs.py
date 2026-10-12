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

# precios definitivos (de menor a mayor): el más lento y fácil de comprar es el primero
PRICE = {
    'hatch': 9000, 'torito': 18000, 'hatch2': 24000, 'clasico60': 30000, 'titan': 32000, 'pickup': 34000, 'suv': 38000, 'kodiak': 44000, 'camo': 46000,
    'buggy': 50000, 'muscle': 56000, 'truck': 60000, 'rally80': 64000, 'gt': 72000, 'trilux': 78000, 'pro_gt': 92000, 'kl5': 98000, 'trilux_s': 104000,
    'trilux_gt': 118000, 'gt3': 130000, 'veltor': 150000, 'veltor_s': 185000, 'genesis': 190000, 'moust': 205000, 'veltor_gtr': 225000, 'hyper': 260000,
}
ORDER = sorted(PRICE, key=lambda k: PRICE[k])
for k, p in PRICE.items():
    if k in SPEC:
        SPEC[k]['cat']['price'] = p
STARTER = 'hatch'
