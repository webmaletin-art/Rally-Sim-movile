"""Ruedas de cada auto (diseño de llanta, medidas y dibujo de la goma) y configuración de recoloreo de la textura.
WHEEL: style = diseño de la llanta (wheel_gen.gd) · rim = radio de la llanta (m) · tw/tw_r = ancho de goma adelante/atrás (m) · tread = dibujo · spring/susp = suspensión · dual = ruedas gemelas atrás
TEX: canales de color de la textura que el juego puede cambiar (ver car_visual.gd, use_tex)."""

def _w(style, rim, tw, tw_r=None, tread='road', susp='car', sc='#c0c5cc', cc='#c0c5cc', **kw):
    d = dict(spring_col=sc, caliper_col=cc, style=style, rim=rim, tw=tw, tw_r=tw_r if tw_r else tw, tread=tread, spring='coil', susp=susp)
    d.update(kw)
    return d

WHEEL = {
    'pickup':    _w('dish8', 0.229, 0.325, tread='offroad', susp='truck', sc='#e11d2a', cc='#1b1d22'),
    'camo':      _w('beadlock', 0.235, 0.345, tread='offroad', susp='truck', sc='#d9a21c', cc='#d9a21c'),
    'kodiak':    _w('beadlock', 0.24, 0.33, tread='offroad', susp='truck', sc='#ff6a08', cc='#1b1d22'),
    'suv':       _w('dish6', 0.23, 0.275, tread='offroad', susp='truck', sc='#ff6a08', cc='#d9141c'),
    'truck':     _w('steel10', 0.254, 0.32, 0.40, tread='offroad', susp='truck', sc='#ff6a08', cc='#ffc300'),
    'titan':     _w('steel10', 0.254, 0.32, 0.30, tread='road', susp='truck', sc='#1a4fe0', cc='#c0c5cc', dual=True),
    'hatch':     _w('multi10', 0.205, 0.225, tread='road', sc='#e11d2a', cc='#e11d2a'),
    'hatch2':    _w('star5', 0.205, 0.225, tread='road', sc='#e11d2a', cc='#e11d2a'),
    'rally80':   _w('dish8', 0.20, 0.23, tread='offroad', sc='#e11d2a', cc='#e6c619'),
    'buggy':     _w('beadlock', 0.20, 0.31, 0.34, tread='offroad', susp='buggy', sc='#ffc300', cc='#ff6a08'),
    'torito':    _w('star5', 0.245, 0.27, 0.33, tread='road', sc='#e11d2a', cc='#e6c619'),
    'clasico60': _w('multi5', 0.215, 0.22, 0.24, tread='road', sc='#b31f24', cc='#c0c5cc'),
    'muscle':    _w('star5', 0.245, 0.27, 0.33, tread='road', sc='#e11d2a', cc='#e6c619'),
    'gt':        _w('multi10', 0.235, 0.26, 0.28, tread='road', sc='#1a4fe0', cc='#1a4fe0'),
    'kl5':       _w('centerlock', 0.24, 0.27, 0.31, tread='road', sc='#00b4d8', cc='#00b4d8'),
    'trilux':    _w('multi5', 0.235, 0.255, 0.285, tread='road', sc='#e11d2a', cc='#c0c5cc'),
    'trilux_s':  _w('multi10', 0.24, 0.265, 0.30, tread='road', sc='#c0c5cc', cc='#e11d2a'),
    'trilux_gt': _w('centerlock', 0.245, 0.28, 0.32, tread='slick', sc='#ffc300', cc='#e6c619'),
    'pro_gt':    _w('centerlock', 0.245, 0.28, 0.33, tread='slick', sc='#e11d2a', cc='#e11d2a'),
    'gt3':       _w('centerlock', 0.25, 0.30, 0.34, tread='slick', sc='#e11d2a', cc='#e6c619'),
    'veltor':    _w('turbine', 0.255, 0.285, 0.34, tread='road', sc='#c0c5cc', cc='#e11d2a'),
    'veltor_s':  _w('turbine', 0.255, 0.29, 0.345, tread='road', sc='#e11d2a', cc='#c0c5cc'),
    'veltor_gtr': _w('centerlock', 0.26, 0.30, 0.36, tread='slick', sc='#00b4d8', cc='#00b4d8'),
    'moust':     _w('turbine', 0.255, 0.29, 0.345, tread='road', sc='#e11d2a', cc='#e11d2a'),
    'hyper':     _w('turbine', 0.26, 0.285, 0.33, tread='road', sc='#c0c5cc', cc='#00b4d8'),
    'genesis':   _w('multi10', 0.2286, 0.34, tread='offroad', susp='truck', sc='#c9a24b', cc='#c9a24b'),
}

# canales de color de la textura de cada auto (los elige el análisis de analyze_textures.py sobre lo que se ve del auto):
#  [0, tono, ancho, sat. mínima] = un tono (0 rojo/naranja ≈ 0.0–0.05 · amarillo 0.125 · verde 0.33 · celeste 0.57 · azul 0.64)
#  [1, brillo desde, brillo hasta, sat. máxima] = neutro: blancos, plateados y grises claros
def _t(a, b=None, va=0.7, vb=0.7):
    return dict(a=list(a), b=list(b) if b else [-1.0, 0.0, 0.0, 0.0], va=va, vb=vb)

NEUTRO = (1, 0.30, 0.52, 0.18)
ROJO = (0, 0.0, 0.07, 0.40)
AZUL = (0, 0.64, 0.07, 0.40)
CELESTE = (0, 0.575, 0.06, 0.40)
NARANJA = (0, 0.045, 0.05, 0.40)
AMARILLO = (0, 0.125, 0.10, 0.40)

TEX = {
    'pickup': _t(NEUTRO, va=0.62),
    'camo': _t(NARANJA, va=0.8),
    'kodiak': _t(NEUTRO, ROJO, va=0.85),
    'suv': _t(NEUTRO, ROJO, va=0.75),
    'truck': _t(NEUTRO, ROJO, va=0.8),
    'titan': _t(NEUTRO, va=0.8),
    'hatch': _t(ROJO, va=0.75),
    'hatch2': _t(NEUTRO, ROJO, va=0.8),
    'rally80': _t(NEUTRO, ROJO, va=0.85),
    'buggy': _t(ROJO, va=0.75),
    'torito': _t(AMARILLO, va=0.8),
    'clasico60': _t(NEUTRO, va=0.85),
    'muscle': _t(ROJO, NEUTRO, va=0.75, vb=0.75),
    'gt': _t(NARANJA, AZUL, va=0.85, vb=0.7),
    'kl5': _t(NEUTRO, CELESTE, va=0.85),
    'trilux': _t(NEUTRO, va=0.75),
    'trilux_s': _t(NEUTRO, va=0.75),
    'trilux_gt': _t(NEUTRO, va=0.75),
    'pro_gt': _t(ROJO, NEUTRO, va=0.8, vb=0.85),
    'gt3': _t(NEUTRO, ROJO, va=0.85),
    'veltor': _t(NEUTRO, ROJO, va=0.8),
    'veltor_s': _t(ROJO, va=0.8),
    'veltor_gtr': _t(AZUL, va=0.8),
    'moust': _t(ROJO, NEUTRO, va=0.8, vb=0.75),
    'hyper': _t(NEUTRO, va=0.8),
    'genesis': _t((1, 0.22, 0.45, 0.18), va=0.45),
}
