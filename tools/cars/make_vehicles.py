"""Agrega los autos nuevos a godot/game/data/vehicles.json y catalog.json a partir de las medidas de cada carrocería
(godot/game/models/cars/<id>.json). La pickup y el camión conservan su física: solo se comprueba que el modelo les calce.
Uso: python3 make_vehicles.py"""
import json, os, copy
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, '..', '..', 'godot', 'game', 'data')
MODELS = os.path.join(HERE, '..', '..', 'godot', 'game', 'models', 'cars')

def curve(max_rpm, turbo):
    f = [(0, .38), (.12, .66), (.3, 1), (.8, 1), (.95, .88), (1.05, .55)] if turbo else [(0, .4), (.14, .62), (.34, .88), (.55, 1), (.82, 1), (.95, .9), (1.05, .6)]
    return [[round(max_rpm * a / 50) * 50, b] for a, b in f]

SURF_ROAD = {"asphalt": 1, "dirt": 0.62, "shoulder": 0.72, "grass": 0.45, "outside": 0.4, "mud": 0.35}
SURF_MIX = {"asphalt": 0.9, "dirt": 0.8, "shoulder": 0.78, "grass": 0.55, "outside": 0.42, "mud": 0.5}
SURF_OFF = {"asphalt": 0.85, "dirt": 0.78, "shoulder": 0.75, "grass": 0.6, "outside": 0.5, "mud": 0.45}

# base: auto del que se copian los campos que no se detallan
CARS = {
    'hatch': dict(base='genesis', name='Pampa R2 Turbo', icon='🚗', tagline='Hatch de rally · ágil y filoso', cyl=4, mass=1180, comH=0.50, travel=0.22, fq=(1.55, 1.6), zb=0.34, zr=0.6,
                  tq=430, rpm=7500, turbo=True, gears=[3.62, 2.2, 1.55, 1.18, 0.95, 0.78], fd=4.1, drive='AWD', fdr=0.58, cbias=0.5, lsd=900, decel=11.5, steer=0.56, sresp=10.5,
                  drag=0.78, mu=1.0, surf=SURF_MIX, tire='road', slipL=0.13, slipT=0.17, eng_in=0.14, clutch=0.5, shift=0.11, vgov=0, roll=0.017,
                  cat=dict(brand='PAMPA', model='R2 Turbo', kind='Hatch de rally', price=24000, engine='1.6 turbo 300 cv', drive='AWD', year=2026,
                           desc='Chiquito, liviano y muy nervioso. Se tira a las curvas como pocos y perdona poco en las rectas largas.', paint=dict(body='#f2f2ee', accent='#e11d2a', rim='#1b1d22'))),
    'suv': dict(base='pickup', name='Tehuelche G4', icon='🚙', tagline='4x4 de montaña · duro y alto', cyl=6, mass=2250, comH=0.80, travel=0.30, fq=(1.2, 1.2), zb=0.34, zr=0.6,
                tq=620, rpm=6200, turbo=True, gears=[4.7, 3.1, 2.1, 1.7, 1.4, 1.1, 0.85], fd=3.9, drive='AWD', fdr=0.45, cbias=0.4, lsd=1100, decel=10.5, steer=0.5, sresp=8,
                drag=1.25, mu=0.96, surf=SURF_MIX, tire='road', slipL=0.14, slipT=0.18, eng_in=0.3, clutch=0.8, shift=0.2, vgov=0, roll=0.02,
                cat=dict(brand='TEHUELCHE', model='G4 4x4', kind='SUV todo terreno', price=30000, engine='V6 3.0 turbo 330 cv', drive='4x4', year=2025,
                         desc='Cuadrado, alto y con tracción a las cuatro. Trepa cualquier cosa; en el asfalto hay que tratarlo con respeto.', paint=dict(body='#2f6f5e', accent='#d4d4cf', rim='#1b1d22'))),
    'buggy': dict(base='t1plus', name='Chakal Dune R', icon='🏜️', tagline='Buggy Dakar · liviano y saltarín', cyl=6, mass=1150, comH=0.66, travel=0.46, fq=(1.45, 1.5), zb=0.4, zr=0.68,
                  tq=520, rpm=7200, turbo=True, gears=[3.3, 2.3, 1.7, 1.32, 1.05], fd=4.3, drive='RWD', fdr=0.0, cbias=0.5, lsd=800, decel=10.0, steer=0.54, sresp=10.5,
                  drag=0.85, mu=1.04, surf=SURF_OFF, tire='mud', slipL=0.13, slipT=0.17, eng_in=0.16, clutch=0.3, shift=0.1, vgov=0, roll=0.024,
                  cat=dict(brand='CHAKAL', model='Dune R', kind='Buggy Dakar', price=38000, engine='V6 3.0 turbo 340 cv', drive='RWD', year=2026,
                           desc='Sin vidrios, sin puertas, con un resorte enorme en cada rueda. Vuela sobre los pozos y derrapa de cola en la tierra.', paint=dict(body='#ffc300', accent='#0b0c0e', rim='#0b0c0e'))),
    'muscle': dict(base='genesis', name='Brava Furia V8', icon='🔥', tagline='Muscle V8 · tracción trasera', cyl=8, mass=1760, comH=0.52, travel=0.17, fq=(1.15, 1.2), zb=0.3, zr=0.55,
                   tq=780, rpm=6800, turbo=False, gears=[3.3, 2.1, 1.5, 1.2, 1.0, 0.8], fd=3.6, drive='RWD', fdr=0.0, cbias=0.5, lsd=900, decel=10.5, steer=0.5, sresp=8.5,
                   drag=1.0, mu=1.0, surf=SURF_ROAD, tire='road', slipL=0.13, slipT=0.17, eng_in=0.34, clutch=1.0, shift=0.16, vgov=0, roll=0.017,
                   cat=dict(brand='BRAVA', model='Furia V8', kind='Muscle car', price=52000, engine='V8 6.2 · 600 cv', drive='RWD', year=2024,
                            desc='Capó largo, 600 cv y una sola forma de usarlos: de cola. Ruge en cada cambio.', paint=dict(body='#e11d2a', accent='#f5f5f2', rim='#c0c5cc'))),
    'gt': dict(base='genesis', name='Kaze Zero GT', icon='🌀', tagline='Coupé GT · fino en curva', cyl=6, mass=1430, comH=0.47, travel=0.15, fq=(1.5, 1.6), zb=0.34, zr=0.6,
               tq=580, rpm=7600, turbo=True, gears=[3.6, 2.2, 1.6, 1.25, 1.0, 0.82], fd=3.9, drive='RWD', fdr=0.0, cbias=0.5, lsd=1000, decel=11.5, steer=0.52, sresp=10,
               drag=0.86, mu=1.06, surf=SURF_ROAD, tire='road', slipL=0.12, slipT=0.16, eng_in=0.2, clutch=0.8, shift=0.13, vgov=0, roll=0.015,
               cat=dict(brand='KAZE', model='Zero GT', kind='Coupé GT', price=70000, engine='V6 3.0 biturbo 480 cv', drive='RWD', year=2026,
                        desc='Un coupé de cola ancha, equilibrado y preciso. El mejor amigo de las curvas largas y de los derrapes controlados.', paint=dict(body='#1a4fe0', accent='#f5f5f2', rim='#16181c'))),
    'gt3': dict(base='genesis', name='Altair GT3 RS', icon='🏁', tagline='GT3 de pista · aerodinámico', cyl=6, mass=1300, comH=0.46, travel=0.12, fq=(1.7, 1.8), zb=0.38, zr=0.65,
                tq=540, rpm=9000, turbo=False, gears=[3.0, 2.1, 1.65, 1.35, 1.12, 0.95], fd=4.1, drive='RWD', fdr=0.0, cbias=0.5, lsd=1200, decel=13.0, steer=0.5, sresp=11,
                drag=0.92, mu=1.14, surf=SURF_ROAD, tire='slick', slipL=0.11, slipT=0.15, eng_in=0.12, clutch=0.4, shift=0.08, vgov=0, roll=0.014,
                cat=dict(brand='ALTAIR', model='GT3 RS', kind='GT3 de pista', price=120000, engine='Bóxer 4.0 · 560 cv · 9000 rpm', drive='RWD', year=2027,
                         desc='Auto de carreras con matrícula. Alerón gigante, gomas lisas y un motor que grita hasta las 9000 vueltas.', paint=dict(body='#f5f5f2', accent='#ff6a08', rim='#c9a24b'))),
    'hyper': dict(base='genesis', name='Vortex Aerion', icon='⚡', tagline='Hypercar híbrido · 4 ruedas motrices', cyl=8, mass=1650, comH=0.44, travel=0.12, fq=(1.7, 1.8), zb=0.36, zr=0.62,
                  tq=1000, rpm=8500, turbo=True, gears=[3.3, 2.3, 1.75, 1.4, 1.15, 0.97, 0.82], fd=3.8, drive='AWD', fdr=0.4, cbias=0.35, lsd=1200, decel=13.0, steer=0.5, sresp=10.5,
                  drag=0.8, mu=1.12, surf=SURF_ROAD, tire='road', slipL=0.12, slipT=0.16, eng_in=0.2, clutch=0.5, shift=0.1, vgov=0, roll=0.014,
                  cat=dict(brand='VORTEX', model='Aerion', kind='Hypercar híbrido', price=150000, engine='V8 biturbo + 2 motores · 1000 cv', drive='AWD', year=2027,
                           desc='Bajo, ancho y brutal. Tracción integral y mil caballos para dejar el asfalto atrás.', paint=dict(body='#0b0c0e', accent='#00b4d8', rim='#c0c5cc'))),
    'camo': dict(base='pickup', name='Cóndor T6 Multicam', icon='🪖', tagline='Todo terreno V6 · suspensión larga', cyl=6, mass=2350, comH=0.78, travel=0.36, fq=(1.1, 1.15), zb=0.36, zr=0.62,
                 tq=650, rpm=6400, turbo=True, gears=[4.6, 3.0, 2.1, 1.6, 1.3, 1.05, 0.84], fd=4.1, drive='AWD', fdr=0.45, cbias=0.42, lsd=1100, decel=10.5, steer=0.5, sresp=8.5,
                 drag=1.18, mu=1.0, surf=SURF_OFF, tire='mud', slipL=0.14, slipT=0.18, eng_in=0.3, clutch=0.7, shift=0.18, vgov=0, roll=0.02,
                 cat=dict(brand='CÓNDOR', model='T6 Multicam', kind='Camioneta todo terreno', price=42000, engine='V6 3.5 biturbo 360 cv', drive='4x4', year=2026,
                          desc='Camioneta militar de camuflaje multicam: ruedas todo terreno, suspensión de recorrido largo y un V6 que no se queja del barro.', paint=dict(body='#ffffff', accent='#2c3a1e', rim='#d9a21c', livery=6))),
}
NEW_ORDER = ['hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']

def build_entry(cid, spec, meta, v):
    d = copy.deepcopy(v[spec['base']])
    w = meta['wheel']
    xo = sum(a['x_out'] for a in meta['arches']) / 2
    track = round(2 * (xo - w['tw'] / 2 + 0.02), 3)
    m = spec['mass']
    wb = round(meta['wheelbase'], 3)
    d.update(name=spec['name'], visualType=cid, icon=spec['icon'], tagline=spec['tagline'], firingOrder=spec['cyl'], mass=m, weightFront=meta['weightFront'],
             comHeight=spec['comH'], wheelBase=wb, trackF=track, trackR=round(track + (w['tw_r'] - w['tw']) * 0.3, 3), wheelRadius=round(meta['R'], 3), rimRadius=w['rim'], tireWidth=w['tw'],
             wheelInertia=round(4 + 5.5 * meta['R'] * m / 700, 1), hardpointY=0, travel=spec['travel'], freqF=spec['fq'][0], freqR=spec['fq'][1], zetaBump=spec['zb'], zetaRebound=spec['zr'],
             arbF=round(m * 2.3 / 50) * 50, arbR=round(m * 1.15 / 50) * 50, bumpStopK=round(m * 150 / 1000) * 1000, bumpStopC=round(m * 4.2 / 100) * 100,
             Ixx=round(m * 0.42), Iyy=round(m * wb * wb / 5.2), Izz=round(m * wb * wb / 4.4), mu=spec['mu'], surfGrip=spec['surf'], slipPeakLong=spec['slipL'], slipPeakLat=spec['slipT'],
             peakTorque=spec['tq'], idleRpm=900, launchRpm=int(spec['rpm'] * 0.42), maxRpm=spec['rpm'], torqueCurve=curve(spec['rpm'], spec['turbo']), engineInertia=spec['eng_in'],
             engineBrake=round(spec['tq'] * 0.22), gears=spec['gears'], reverseRatio=3.2, finalDrive=spec['fd'], clutchTime=spec['clutch'], shiftUpRpm=int(spec['rpm'] * 0.93),
             shiftDownRpm=int(spec['rpm'] * 0.42), shiftTime=spec['shift'], driveType=spec['drive'], frontDriveRatio=spec['fdr'], rearDriveRatio=round(1 - spec['fdr'], 3),
             centerDiffBias=spec['cbias'], lsd=spec['lsd'], brakeTorque=round(spec['decel'] * meta['R'] * m / 100) * 100, maxSteer=spec['steer'], steerResponse=spec['sresp'],
             dragCoef=spec['drag'], rolling=spec['roll'], rideOffset=0.0)
    d['vGov'] = spec['vgov']
    if spec['vgov'] == 0:
        d.pop('vGov', None)
    d['tireFalloff'] = 1.3 if spec['tire'] == 'road' else (1.45 if spec['tire'] == 'slick' else 1.35)
    return d

def main():
    vp = os.path.join(DATA, 'vehicles.json')
    v = json.load(open(vp))
    cp = os.path.join(DATA, 'catalog.json')
    cat = json.load(open(cp))
    # la pickup y el camión conservan su física: el modelo tiene que calzar
    for cid in ('pickup', 'truck'):
        meta = json.load(open(os.path.join(MODELS, cid + '.json')))
        p = v[cid]
        xo = sum(a['x_out'] for a in meta['arches']) / 2
        print('%-7s entre ejes %.3f (físico %.3f) · R %.3f (%.3f) · trocha del modelo %.2f (física %.2f)' % (cid, meta['wheelbase'], p['wheelBase'], meta['R'], p['wheelRadius'],
              2 * (xo - meta['wheel']['tw'] / 2 + 0.02), p['trackF']))
        assert abs(meta['wheelbase'] - p['wheelBase']) < 0.02 and abs(meta['R'] - p['wheelRadius']) < 0.01
        assert abs(meta['weightFront'] - p['weightFront']) < 0.01
    for cid in NEW_ORDER:
        spec = CARS[cid]
        meta = json.load(open(os.path.join(MODELS, cid + '.json')))
        v[cid] = build_entry(cid, spec, meta, v)
        c = dict(spec['cat'])
        cat['cars'][cid] = c
        if cid not in cat['order']:
            cat['order'].append(cid)
    done = {'Hatch Rally R2', 'Buggy Dakar SSV', 'Muscle V8 ’70', 'Hypercar Eléctrico'}
    cat['coming'] = [c for c in cat['coming'] if c['name'] not in done]
    json.dump(v, open(vp, 'w'), ensure_ascii=False, indent=1)
    json.dump(cat, open(cp, 'w'), ensure_ascii=False, separators=(',', ':'))
    print('vehicles:', list(v), '\norder:', cat['order'])

if __name__ == '__main__':
    main()
