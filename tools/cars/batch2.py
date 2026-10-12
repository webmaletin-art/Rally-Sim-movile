"""Segunda tanda de autos (14 modelos GLB que mandó el dueño): medidas de la carrocería (MODEL), ruedas (WHEEL), física y ficha de la tienda (SPEC).
build_car.py y make_vehicles.py la leen y la suman a sus tablas. Las fuentes crudas se preparan con prep_sources.py (car10…car23 en tools/cars/src).
Los precios van de menor a mayor entre los 14; el flagship del juego sigue siendo el Bisonte XR (250.000)."""

SURF_ROAD = {"asphalt": 1, "dirt": 0.62, "shoulder": 0.72, "grass": 0.45, "outside": 0.4, "mud": 0.35}
SURF_MIX = {"asphalt": 0.9, "dirt": 0.8, "shoulder": 0.78, "grass": 0.55, "outside": 0.42, "mud": 0.5}
SURF_OFF = {"asphalt": 0.85, "dirt": 0.78, "shoulder": 0.75, "grass": 0.6, "outside": 0.5, "mud": 0.45}

# ── carrocería: L = largo real · wscale = ancho · R = radio de rueda fijo (o ground = luz al piso) · gap = luz goma/paso · wf = peso adelante · glass = 'auto' | polígono | None
MODEL = {
    'safari':     dict(src='car10', L=4.75, wscale=0.94, H=1.55, R=0.40, gap=0.05, wf=0.50, glass=None),
    'volcan':     dict(src='car11', L=4.90, wscale=0.93, H=1.15, ground=0.09, gap=0.04, wf=0.43, glass='auto'),
    'torito':     dict(src='car12', close=4, voxel=0.016, L=4.95, wscale=0.82, H=1.32, ground=0.12, gap=0.05, wf=0.52, glass='auto', arch_pick=(-0.35, 0.35)),
    'clasico60':  dict(src='car13', close=4, voxel=0.016, L=4.15, wscale=0.95, H=1.28, ground=0.10, gap=0.04, wf=0.46, glass='auto'),
    'kl5':        dict(src='car14', close=4, voxel=0.016, L=4.50, wscale=0.73, H=1.28, ground=0.09, gap=0.04, wf=0.47, glass='auto'),
    'titan':      dict(src='car15', close=4, voxel=0.02, L=6.40, wscale=0.88, H=3.4, R=0.52, gap=0.06, wf=0.55, glass=[(2.6, 1.95), (2.25, 3.0), (0.15, 3.2), (0.0, 2.2)], arches=[(-2.44, 0.75, 0.62), (2.30, 0.75, 0.62)]),
    'rally80':    dict(src='car16', close=4, voxel=0.016, L=4.40, wscale=0.83, H=1.36, ground=0.12, gap=0.05, wf=0.50, glass='auto'),
    'trilux':     dict(src='car17', close=7, voxel=0.014, L=4.40, wscale=0.86, H=1.3, ground=0.09, gap=0.04, wf=0.52, glass='auto', arch_pick=(-0.4, 0.4)),
    'trilux_s':   dict(src='car19', close=7, voxel=0.014, L=4.61, wscale=0.86, H=1.3, ground=0.09, gap=0.04, wf=0.52, glass='auto', arch_pick=(-0.4, 0.4)),
    'trilux_gt':  dict(src='car18', close=7, voxel=0.014, L=4.72, wscale=0.86, H=1.3, ground=0.09, gap=0.04, wf=0.52, glass='auto', arch_pick=(-0.4, 0.4)),
    'veltor':     dict(src='car20', close=4, voxel=0.016, L=4.75, wscale=0.93, H=1.17, ground=0.085, gap=0.04, wf=0.43, glass='auto'),
    'veltor_s':   dict(src='car22', close=4, voxel=0.016, L=4.91, wscale=0.93, H=1.15, ground=0.085, gap=0.04, wf=0.43, glass='auto'),
    'veltor_gtr': dict(src='car21', close=4, voxel=0.016, L=5.00, wscale=0.93, H=1.15, ground=0.085, gap=0.04, wf=0.43, glass='auto'),
    'kodiak':     dict(src='car23', close=4, voxel=0.018, L=5.40, wscale=0.88, H=1.95, R=0.45, gap=0.06, wf=0.54, glass=[(1.25, 1.22), (0.55, 1.70), (-1.0, 1.73), (-1.15, 1.25)]),
}

# ── ruedas: style = diseño de la llanta · rim = radio de la llanta · tw/tw_r = ancho de goma adelante/atrás · tread = dibujo
WHEEL = {
    'safari':     dict(spring_col='#ff7a1a', caliper_col='#ff7a1a', style='dish6', rim=0.255, tw=0.30, tw_r=0.32, tread='offroad', spring='coil', susp='truck'),
    'volcan':     dict(spring_col='#ffc300', caliper_col='#ffc300', style='turbine', rim=0.26, tw=0.285, tw_r=0.345, tread='road', spring='coil', susp='car'),
    'torito':     dict(spring_col='#f5f5f2', caliper_col='#c0c5cc', style='star5', rim=0.205, tw=0.235, tw_r=0.30, tread='road', spring='coil', susp='car'),
    'clasico60':  dict(spring_col='#b31f24', caliper_col='#c0c5cc', style='multi10', rim=0.19, tw=0.19, tw_r=0.215, tread='road', spring='coil', susp='car'),
    'kl5':        dict(spring_col='#ff6a08', caliper_col='#ff6a08', style='centerlock', rim=0.245, tw=0.30, tw_r=0.34, tread='slick', spring='coil', susp='car'),
    'titan':      dict(spring_col='#1a4fe0', caliper_col='#c0c5cc', style='steel10', rim=0.254, tw=0.32, tw_r=0.30, tread='road', spring='coil', susp='truck', dual=True),
    'rally80':    dict(spring_col='#e11d2a', caliper_col='#1a4fe0', style='dish8', rim=0.22, tw=0.235, tw_r=0.245, tread='offroad', spring='coil', susp='car'),
    'trilux':     dict(spring_col='#e11d2a', caliper_col='#c0c5cc', style='multi5', rim=0.235, tw=0.255, tw_r=0.285, tread='road', spring='coil', susp='car'),
    'trilux_s':   dict(spring_col='#e11d2a', caliper_col='#e11d2a', style='multi10', rim=0.24, tw=0.265, tw_r=0.295, tread='road', spring='coil', susp='car'),
    'trilux_gt':  dict(spring_col='#ffc300', caliper_col='#ffc300', style='centerlock', rim=0.245, tw=0.285, tw_r=0.325, tread='slick', spring='coil', susp='car'),
    'veltor':     dict(spring_col='#c0c5cc', caliper_col='#e11d2a', style='star5', rim=0.25, tw=0.275, tw_r=0.335, tread='road', spring='coil', susp='car'),
    'veltor_s':   dict(spring_col='#c0c5cc', caliper_col='#ffc300', style='turbine', rim=0.255, tw=0.285, tw_r=0.345, tread='road', spring='coil', susp='car'),
    'veltor_gtr': dict(spring_col='#00b4d8', caliper_col='#00b4d8', style='centerlock', rim=0.26, tw=0.30, tw_r=0.36, tread='slick', spring='coil', susp='car'),
    'kodiak':     dict(spring_col='#ff6a08', caliper_col='#1b1d22', style='beadlock', rim=0.24, tw=0.33, tw_r=0.33, tread='offroad', spring='coil', susp='truck'),
}

def _s(base, name, icon, tagline, cyl, mass, comH, travel, fq, zb, zr, tq, rpm, turbo, gears, fd, drive, fdr, cbias, lsd, decel, steer, sresp, drag, mu, surf, tire,
       slipL, slipT, eng_in, clutch, shift, roll, cat, vgov=0):
    return dict(base=base, name=name, icon=icon, tagline=tagline, cyl=cyl, mass=mass, comH=comH, travel=travel, fq=fq, zb=zb, zr=zr, tq=tq, rpm=rpm, turbo=turbo, gears=gears, fd=fd,
                drive=drive, fdr=fdr, cbias=cbias, lsd=lsd, decel=decel, steer=steer, sresp=sresp, drag=drag, mu=mu, surf=surf, tire=tire, slipL=slipL, slipT=slipT, eng_in=eng_in,
                clutch=clutch, shift=shift, vgov=vgov, roll=roll, cat=cat)

def _c(brand, model, kind, price, engine, drive, year, desc, body, accent, rim, **kw):
    return dict(brand=brand, model=model, kind=kind, price=price, engine=engine, drive=drive, year=year, desc=desc, paint=dict(body=body, accent=accent, rim=rim, **kw))

# ── física y ficha de la tienda (de menor a mayor precio)
SPEC = {
    'torito': _s('genesis', "Brava Torito '67", '💥', 'Clásico de demolición · V8 a la antigua', 8, 1580, 0.56, 0.17, (1.0, 1.05), 0.28, 0.5, 560, 6200, False,
                 [2.9, 1.9, 1.4, 1.1, 0.9], 3.7, 'RWD', 0.0, 0.5, 300, 8.6, 0.5, 7.5, 1.05, 0.93, SURF_ROAD, 'road', 0.15, 0.2, 0.4, 1.2, 0.24, 0.019,
                 _c('BRAVA', "Torito '67", 'Clásico de demolición', 20000, 'V8 7.0 · 450 cv', 'RWD', 1967,
                    'Un fierro de los años 60 con jaula y alerón de carrera. Pesa, patina y suena a V8 de verdad: ideal para aprender a manejar de cola.', '#1e5aa8', '#f5f5f2', '#c0c5cc')),
    'clasico60': _s('genesis', 'Ñandú Legend GT', '🏛️', 'Deportivo clásico · liviano y noble', 6, 1080, 0.46, 0.15, (1.2, 1.25), 0.3, 0.55, 340, 7200, False,
                    [3.4, 2.05, 1.5, 1.18, 0.95], 4.1, 'RWD', 0.0, 0.5, 350, 9.5, 0.52, 9.0, 0.78, 0.98, SURF_ROAD, 'road', 0.14, 0.18, 0.2, 0.8, 0.17, 0.016,
                    _c('ÑANDÚ', 'Legend GT', 'Deportivo clásico', 28000, '6 cilindros 2.8 · 230 cv', 'RWD', 1962,
                       'Un coupé de los años 60: bajito, liviano y con un sonido que enamora. Poca potencia, pero cada curva es un placer.', '#e8e2d0', '#b31f24', '#c0c5cc')),
    'kodiak': _s('pickup', 'Cóndor Kodiak Raid', '🛻', 'Pick-up de raid · barra de luces y jaula', 6, 2300, 0.78, 0.4, (1.15, 1.2), 0.36, 0.62, 760, 6400, True,
                 [4.6, 3.0, 2.15, 1.65, 1.35, 1.1, 0.9], 4.0, 'AWD', 0.5, 0.45, 1100, 10.5, 0.5, 8.5, 1.22, 1.0, SURF_OFF, 'mud', 0.14, 0.18, 0.3, 0.7, 0.18, 0.021,
                 _c('CÓNDOR', 'Kodiak Raid', 'Pick-up de raid', 36000, 'V6 3.5 biturbo 420 cv', '4x4', 2026,
                    'Pick-up blanca de raid con barra de luces y jaula antivuelco. Suspensión larga, tracción integral y mucha paciencia con los pozos.', '#f5f5f2', '#ff6a08', '#1b1d22')),
    'titan': _s('truck', 'Colossus Titán T4', '🚛', 'Camión tractor · torque de sobra', 6, 8400, 1.2, 0.3, (1.0, 1.0), 0.35, 0.6, 2800, 2200, True,
                [8.2, 5.8, 4.2, 3.0, 2.2, 1.6, 1.2, 0.95], 4.3, 'RWD', 0.0, 0.5, 800, 6.5, 0.45, 6.0, 1.9, 0.88, SURF_MIX, 'road', 0.16, 0.2, 1.8, 1.4, 0.35, 0.011,
                _c('COLOSSUS', 'Titán T4', 'Camión tractor', 32000, 'Diésel 12L · 520 cv', 'RWD', 2025,
                   'La cabeza de un camión de ruta de 8 toneladas. Lento para arrancar, imparable en las rectas y poco amigo de las curvas: frená con tiempo.', '#1a4fe0', '#f5f5f2', '#1b1d22')),
    'rally80': _s('genesis', 'Send Rally 80', '🏁', 'Rally Grupo B moderno · tracción integral', 4, 1230, 0.5, 0.26, (1.5, 1.55), 0.36, 0.62, 540, 7600, True,
                  [3.5, 2.3, 1.65, 1.28, 1.02, 0.84], 4.2, 'AWD', 0.55, 0.5, 1000, 11.5, 0.56, 10.5, 0.82, 1.03, SURF_MIX, 'road', 0.13, 0.17, 0.15, 0.4, 0.09, 0.018,
                  _c('SEND', 'Rally 80', 'Rally Grupo B', 58000, '4 cilindros 2.0 turbo · 480 cv', 'AWD', 1986,
                     'Un auto de rally al estilo de los monstruos del Grupo B: corto, ancho y con un turbo que patea. Vuela en la tierra y perdona poco.', '#f5f5f2', '#1a4fe0', '#e11d2a')),
    'kl5': _s('genesis', 'Kairós KL5 Sport', '🏆', 'GT de pista · alerón gigante', 6, 1380, 0.46, 0.12, (1.65, 1.75), 0.38, 0.65, 640, 8200, True,
              [3.3, 2.25, 1.7, 1.35, 1.1, 0.92, 0.78], 3.9, 'RWD', 0.0, 0.5, 1100, 12.5, 0.5, 10.5, 0.88, 1.12, SURF_ROAD, 'slick', 0.115, 0.155, 0.15, 0.4, 0.08, 0.014,
              _c('KAIRÓS', 'KL5 Sport', 'GT de pista', 68000, 'V6 3.0 biturbo · 620 cv', 'RWD', 2026,
                 'Un GT con alerón de campeonato. Pegado al piso, preciso y rápido: pide manos suaves en los cordones.', '#0f3d5e', '#ff6a08', '#16181c')),
    'trilux': _s('genesis', 'Trilux Base', '🌀', 'Coupé deportivo · equilibrado', 6, 1460, 0.47, 0.13, (1.55, 1.65), 0.36, 0.62, 500, 7000, True,
                 [3.6, 2.2, 1.6, 1.25, 1.0, 0.82], 3.9, 'RWD', 0.0, 0.5, 800, 11.5, 0.52, 10.0, 0.84, 1.04, SURF_ROAD, 'road', 0.125, 0.165, 0.2, 0.7, 0.12, 0.015,
                 _c('TRILUX', 'Base', 'Coupé deportivo', 72000, '6 cilindros 3.0 turbo · 380 cv', 'RWD', 2026,
                    'El coupé de la familia Trilux: tracción trasera, cola ancha y un turbo que sube parejo. La puerta de entrada al mundo de los deportivos.', '#c0c5cc', '#e11d2a', '#2b2f36')),
    'trilux_s': _s('genesis', 'Trilux Sport', '🌀', 'Coupé deportivo · capó ventilado y alerón', 6, 1420, 0.46, 0.12, (1.6, 1.7), 0.37, 0.63, 590, 7200, True,
                   [3.6, 2.2, 1.62, 1.28, 1.04, 0.86], 3.9, 'RWD', 0.0, 0.5, 1000, 12.0, 0.52, 10.3, 0.86, 1.07, SURF_ROAD, 'road', 0.12, 0.16, 0.18, 0.55, 0.1, 0.015,
                   _c('TRILUX', 'Sport', 'Coupé deportivo', 88000, '6 cilindros 3.0 biturbo · 460 cv', 'RWD', 2026,
                      'El Trilux con el capó ventilado y el alerón: más potencia, más agarre y una cola que se suelta cuando se la invita.', '#e11d2a', '#0b0c0e', '#0b0c0e')),
    'safari': _s('t1plus', 'Zorro Pampa X', '🏜️', 'Hypercar todo terreno · techo abierto', 8, 1650, 0.62, 0.26, (1.4, 1.5), 0.38, 0.65, 820, 7200, True,
                 [3.4, 2.35, 1.78, 1.4, 1.15, 0.96, 0.8], 4.0, 'AWD', 0.5, 0.45, 1000, 11.5, 0.54, 10.0, 0.92, 1.06, SURF_MIX, 'road', 0.12, 0.16, 0.2, 0.5, 0.1, 0.018,
                 _c('ZORRO', 'Pampa X', 'Hypercar todo terreno', 95000, 'V8 4.0 biturbo · 700 cv', 'AWD', 2027,
                    'Un hypercar de techo abierto con alma de raid: tracción integral, suspensión alta y la cabeza fría para saltar y volver a pegarse al piso.', '#ff7a1a', '#1b1d22', '#1b1d22')),
    'trilux_gt': _s('genesis', 'Trilux Pro GT', '🏁', 'Coupé de pista · gomas semi-slick', 6, 1360, 0.45, 0.11, (1.7, 1.8), 0.38, 0.65, 700, 7500, True,
                    [3.4, 2.3, 1.74, 1.4, 1.15, 0.97, 0.82], 3.9, 'RWD', 0.0, 0.5, 1200, 12.8, 0.5, 10.8, 0.92, 1.13, SURF_ROAD, 'slick', 0.115, 0.155, 0.16, 0.45, 0.08, 0.014,
                    _c('TRILUX', 'Pro GT', 'Coupé de pista', 112000, '6 cilindros 3.0 biturbo · 560 cv', 'RWD', 2027,
                       'La versión de pista del Trilux: capó con salidas de aire, alerón de competición y gomas semi-slick. Se pega al asfalto como una calcomanía.', '#2b2f36', '#ffc300', '#ffc300')),
    'veltor': _s('genesis', 'Veltor Max', '⚡', 'Superdeportivo híbrido · mitad de motor atrás', 12, 1760, 0.43, 0.11, (1.7, 1.8), 0.37, 0.64, 880, 8500, False,
                 [3.4, 2.4, 1.85, 1.45, 1.18, 0.98, 0.83, 0.72], 3.7, 'AWD', 0.4, 0.35, 1100, 13.0, 0.5, 11.0, 0.82, 1.10, SURF_ROAD, 'road', 0.12, 0.16, 0.18, 0.4, 0.08, 0.014,
                 _c('VELTOR', 'Max', 'Superdeportivo híbrido', 140000, 'V12 6.5 + 3 motores · 800 cv', 'AWD', 2027,
                    'Un V12 detrás de la cabina con ayuda eléctrica adelante. Tracción integral, sonido de ópera y una salida de curva que te clava en el asiento.', '#f5f5f2', '#e11d2a', '#2b2f36')),
    'veltor_s': _s('genesis', 'Veltor Max Sport', '⚡', 'Superdeportivo híbrido · aerodinámica activa', 12, 1700, 0.43, 0.11, (1.75, 1.85), 0.38, 0.65, 1000, 8800, False,
                   [3.3, 2.35, 1.82, 1.45, 1.2, 1.0, 0.85, 0.74], 3.7, 'AWD', 0.4, 0.35, 1200, 13.5, 0.5, 11.0, 0.82, 1.13, SURF_ROAD, 'road', 0.115, 0.155, 0.17, 0.35, 0.07, 0.013,
                   _c('VELTOR', 'Max Sport', 'Superdeportivo híbrido', 175000, 'V12 6.5 + 3 motores · 900 cv', 'AWD', 2027,
                      'El Veltor con alerón elevado, más potencia y menos peso. Frena tarde, sale fuerte y no perdona los errores.', '#e11d2a', '#0b0c0e', '#0b0c0e')),
    'volcan': _s('genesis', 'Volcán Fuego SV', '🔥', 'Hypercar V12 · alerón de competición', 12, 1650, 0.43, 0.11, (1.75, 1.85), 0.38, 0.65, 780, 8700, False,
                 [3.2, 2.3, 1.78, 1.42, 1.18, 0.99, 0.84], 3.8, 'AWD', 0.35, 0.35, 1200, 13.5, 0.5, 11.0, 0.78, 1.16, SURF_ROAD, 'road', 0.115, 0.155, 0.17, 0.4, 0.08, 0.013,
                 _c('VOLCÁN', 'Fuego SV', 'Hypercar V12', 195000, 'V12 6.5 aspirado · 770 cv · 8700 rpm', 'AWD', 2027,
                    'Bajo, ancho y con un V12 que grita hasta las 8700 vueltas. Tracción integral, un alerón enorme y una trompa que corta el aire.', '#ffc300', '#0b0c0e', '#c0c5cc')),
    'veltor_gtr': _s('genesis', 'Veltor Max Pro GTR', '👑', 'Hypercar de pista · el más rápido de la tanda', 12, 1600, 0.42, 0.10, (1.8, 1.9), 0.4, 0.68, 1160, 9000, False,
                     [3.2, 2.3, 1.8, 1.45, 1.2, 1.02, 0.87, 0.76], 3.7, 'AWD', 0.4, 0.35, 1300, 14.0, 0.5, 11.5, 0.84, 1.18, SURF_ROAD, 'slick', 0.11, 0.15, 0.16, 0.3, 0.06, 0.012,
                     _c('VELTOR', 'Max Pro GTR', 'Hypercar de pista', 215000, 'V12 6.5 + 3 motores · 1.050 cv', 'AWD', 2027,
                        'La bestia del club: alerón gigante, gomas slick y más de mil caballos. En una pista seca no hay nada que se le acerque.', '#1a4fe0', '#0b0c0e', '#00b4d8')),
}

# versión «original» del Veltor Max Pro GTR: el modelo crudo con su textura y sin bajarle los polígonos (tools/cars/build_hd.py); misma física que el GTR
import copy
SPEC['veltor_gtr_hd'] = copy.deepcopy(SPEC['veltor_gtr'])
SPEC['veltor_gtr_hd']['name'] = 'Veltor Max Pro GTR Original'
SPEC['veltor_gtr_hd']['tagline'] = 'Hypercar de pista · textura original, sin reducir'
SPEC['veltor_gtr_hd']['cat'].update(model='Max Pro GTR Original', kind='Hypercar de pista (original)', price=50000,
                                    desc='El GTR tal como vino del modelador: con su pintura y detalles originales y todos sus polígonos. Para probar la calidad máxima (pesa más en el teléfono).')

# orden de aparición en la tienda (de menor a mayor precio)
ORDER = ['torito', 'clasico60', 'titan', 'kodiak', 'rally80', 'kl5', 'trilux', 'trilux_s', 'safari', 'trilux_gt', 'veltor', 'veltor_s', 'volcan', 'veltor_gtr', 'veltor_gtr_hd']
