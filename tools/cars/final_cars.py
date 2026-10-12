"""Lista DEFINITIVA de autos del juego (26) y cómo se arma cada carrocería a partir de los modelos con textura que manda el dueño.
Los crudos (GLB de ~300 k a ~1 M de triángulos, una sola malla + textura 1024²) NO se publican en el repo: se leen de una carpeta (SRC_DIR, por defecto /tmp/claude-0/autos).
build_final.py los pone en el auto (frente a +z, piso en y = 0), mide los pasos de rueda, el vidrio y la cabina, y escribe godot/game/models/cars/<id>.glb (completo, SIN reducir, con su textura),
<id>_lo.glb (versión liviana con la misma textura, para los rivales) y <id>.json (medidas).

MODEL: src = archivo crudo · rot = giro (°) sobre y para que el frente quede en +z · L = largo (m) · wscale = ancho · gap = luz goma/paso (m) · wf = peso adelante ·
       arches = pasos de rueda a mano [(z, yc, r)] en unidades del largo (L = 1) cuando el ajuste automático falla · phys = {wb, R, trackF}: el modelo se ajusta a la física que ya tenía el auto
       glass = 'auto' | polígono [(z, y)…] | None · belt_k/ws_len/rg_len = opciones del vidrio automático · skin = parámetros de la piel de medición
"""
import os

SRC_DIR = os.environ.get('CARS_SRC', '/tmp/claude-0/autos')

MODEL = {
    # ── camionetas y camiones
    'pickup':    dict(src='Yaguarete.glb', rot=90, L=6.04, wscale=0.78, gap=0.06, wf=0.54, phys=dict(wb=3.685, R=0.44, trackF=1.73), glass='auto'),
    'camo':      dict(src='T6+Multicam.glb', rot=90, L=5.30, wscale=0.86, gap=0.05, wf=0.54, R=0.40, glass='auto'),
    'kodiak':    dict(src='Kodiak+Raid.glb', rot=0, L=5.00, wscale=0.88, gap=0.05, wf=0.54, R=0.40, glass=[(1.20, 1.30), (0.45, 1.72), (-0.85, 1.74), (-1.0, 1.38)]),
    'suv':       dict(src='G4+4x4.glb', rot=0, L=4.45, wscale=0.85, gap=0.05, wf=0.52, R=0.40, glass='auto'),
    'truck':     dict(src='Mamut+6x6.glb', rot=90, L=6.98, wscale=0.80, gap=0.07, wf=0.50, phys=dict(wb=4.2, R=0.55, trackF=2.1), glass='auto'),
    'titan':     dict(src='semi+truck+3d+model (1).glb', rot=0, L=6.20, wscale=0.80, gap=0.06, wf=0.55, R=0.52,
                      arches=[(-0.38, 0.045, 0.085), (0.27, 0.045, 0.085)], glass='auto'),
    # ── hatch y rally
    'hatch':     dict(src='R2+Turbo.glb', rot=90, L=4.20, wscale=0.84, gap=0.04, wf=0.57, glass='auto'),
    'hatch2':    dict(src='R2+Turbi.glb', rot=0, L=3.90, wscale=0.85, gap=0.04, wf=0.57, glass='auto'),
    'rally80':   dict(src='Rally+80.glb', rot=0, L=3.95, wscale=0.84, gap=0.04, wf=0.50, glass='auto'),
    'buggy':     dict(src='Dune+R.glb', rot=0, L=4.30, wscale=0.80, gap=0.05, wf=0.48, glass=None),
    # ── clásicos y musculosos
    'torito':    dict(src='Torito+67.glb', rot=0, L=4.70, wscale=0.88, gap=0.05, wf=0.52, glass='auto', R=0.33,
                      arches=[(-0.257, 0.035, 0.069), (0.292, 0.030, 0.085)]),
    'clasico60': dict(src='Legend+GTl.glb', rot=0, L=4.35, wscale=0.95, gap=0.04, wf=0.46, glass='auto'),
    'muscle':    dict(src='Furia+V8.glb', rot=90, L=4.65, wscale=0.88, gap=0.04, wf=0.54, glass='auto'),
    # ── coupés y GT
    'gt':        dict(src='Zero+GT.glb', rot=0, L=4.15, wscale=0.88, gap=0.04, wf=0.50, glass='auto'),
    'kl5':       dict(src='KL5+Sport (1).glb', rot=0, L=4.60, wscale=0.84, gap=0.04, wf=0.47, glass='auto',
                      arches=[(-0.275, 0.07, 0.075), (0.265, 0.07, 0.075)]),
    'trilux':    dict(src='Trilux_Base.glb', rot=0, L=4.55, wscale=0.92, gap=0.04, wf=0.52, glass='auto',
                      arches=[(-0.292, 0.126, 0.089), (0.253, 0.080, 0.084)]),
    'trilux_s':  dict(src='Trilux_Sport.glb', rot=0, L=4.60, wscale=0.92, gap=0.04, wf=0.52, glass='auto'),
    'trilux_gt': dict(src='Trilux_Pro GT.glb', rot=0, L=4.75, wscale=0.95, gap=0.04, wf=0.52, glass='auto'),
    'pro_gt':    dict(src='Pro+GT.glb', rot=90, L=4.60, wscale=0.72, gap=0.04, wf=0.46, glass='auto',
                      arches=[(-0.29, 0.08, 0.078), (0.27, 0.08, 0.078)]),
    'gt3':       dict(src='GT3+RS.glb', rot=0, L=4.55, wscale=0.84, gap=0.04, wf=0.46, glass='auto'),
    # ── superdeportivos
    'veltor':    dict(src='Veltor_Max_Base.glb', rot=0, L=4.75, wscale=0.96, gap=0.04, wf=0.43, glass='auto'),
    'veltor_s':  dict(src='Veltor_Max_Sport.glb', rot=0, L=5.05, wscale=0.96, gap=0.04, wf=0.43, glass='auto'),
    'veltor_gtr': dict(src='Veltor_Max_Pro GTR.glb', rot=0, L=5.00, wscale=0.98, gap=0.04, wf=0.43, glass='auto'),
    'moust':     dict(src='MoustExtreme.glb', rot=90, L=4.45, wscale=0.84, gap=0.04, wf=0.44, glass='auto'),
    'hyper':     dict(src='Aerion.glb', rot=90, L=4.80, wscale=0.88, gap=0.04, wf=0.44, glass='auto'),
    # Bisonte: mantiene la física y las medidas del modelo de siempre (4,56 × 2,2 × 1,36 m, entre ejes 2,95, rueda R 0,508); solo cambia la textura y las ruedas
    'genesis':   dict(src='Bisonte+XR.glb', rot=0, L=4.56, wscale=0.80, gap=0.04, wf=0.48, phys=dict(wb=2.95, R=0.508, trackF=1.86), glass=[(0.62, 1.12), (0.2, 1.65), (-0.9, 1.66), (-1.75, 1.30)]),
}

# orden de aparición (se redefine en make_final_vehicles.py por precio)
IDS = list(MODEL)

# alto total real (m) y luz al piso (m) por auto: los modelos salen más altos de lo que corresponde, se aprietan en y
HEIGHT = {
    'pickup': (1.95, 0.20), 'camo': (1.85, 0.22), 'kodiak': (1.88, 0.20), 'suv': (1.92, 0.22), 'truck': (3.10, 0.30), 'titan': (3.50, 0.30),
    'hatch': (1.42, 0.12), 'hatch2': (1.45, 0.14), 'rally80': (1.36, 0.16), 'buggy': (1.75, 0.22),
    'torito': (1.38, 0.14), 'clasico60': (1.30, 0.12), 'muscle': (1.32, 0.12),
    'gt': (1.30, 0.11), 'kl5': (1.20, 0.10), 'trilux': (1.30, 0.11), 'trilux_s': (1.36, 0.11), 'trilux_gt': (1.36, 0.10), 'pro_gt': (1.34, 0.10), 'gt3': (1.28, 0.10),
    'veltor': (1.16, 0.09), 'veltor_s': (1.18, 0.09), 'veltor_gtr': (1.16, 0.09), 'moust': (1.30, 0.12), 'hyper': (1.15, 0.09),
}
for _k, (_h, _g) in HEIGHT.items():
    MODEL[_k]['H'] = _h
    MODEL[_k]['ground'] = _g
