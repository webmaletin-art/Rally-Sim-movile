/* ═══════════════════════════════════════════════════════════════════
   GSKORP RALLY — datos del juego (catálogo, piezas, neumáticos, ajustes)
   Todo lo que es "contenido" vive acá; la lógica en carbuild/profile.
   ═══════════════════════════════════════════════════════════════════ */

/* Metadatos de cada auto (la física de fábrica está en main.js → VEHICLES) */
export const CAR_META={
 pickup:{brand:'TITAN',model:'Raptor X',kind:'Pick-up 4x4',price:18000,starter:true,
  engine:'V6 3.5 biturbo',drive:'4x4',year:2025,
  desc:'Pick-up ancha y noble. Aguanta todo, perdona errores y se agranda en la tierra.',
  paint:{body:'#b31f24',accent:'#1b1d22',rim:'#23262b'}},
 t1plus:{brand:'VOLT',model:'Raid Ultimate',kind:'Prototipo T1+',price:62000,starter:true,
  engine:'Híbrido 2 motores',drive:'AWD',year:2026,
  desc:'Prototipo de raid con suspensión de recorrido largo. Ágil, liviano y muy rápido en tierra.',
  paint:{body:'#1a4fe0',accent:'#ff6a08',rim:'#ff6a08'}},
 truck:{brand:'COLOSSUS',model:'Master 6x6',kind:'Camión Dakar',price:45000,
  engine:'Diésel 13L 1000 cv',drive:'AWD',year:2024,
  desc:'Diez toneladas de camión de rally. Lento en asfalto, imparable fuera del camino.',
  paint:{body:'#e8e6df',accent:'#c1121f',rim:'#1b1d22'}},
 genesis:{brand:'GENESIS',model:'X Skorpio Concept',kind:'Hiperdeportivo AWD',price:95000,
  engine:'V8 biturbo híbrido',drive:'AWD',year:2027,
  desc:'El buque insignia GSkorp. Más de 1000 cv y tracción integral. Solo para manos firmes.',
  paint:{body:'#15181d',accent:'#c9a24b',rim:'#2a2d33'}},
};
export const CAR_ORDER=['pickup','t1plus','truck','genesis'];

/* Autos que llegan con los próximos modelos 3D */
export const COMING_SOON=[
 {name:'Hatch Rally R2',kind:'Tracción delantera',icon:'🚗'},
 {name:'Clásico 4x4 ’85',kind:'Leyenda Grupo B',icon:'🏁'},
 {name:'Buggy Dakar SSV',kind:'Side-by-side',icon:'🏜️'},
 {name:'Muscle V8 ’70',kind:'Tracción trasera',icon:'🔥'},
 {name:'Hypercar Eléctrico',kind:'4 motores',icon:'⚡'},
 {name:'Drift Coupé',kind:'Tracción trasera',icon:'🌀'},
];

/* ─── Piezas del taller ───
   eff: multiplicadores (x) o sumas (+) sobre la física.  unlock: ajustes que habilita */
export const UPGRADES=[
 {id:'engine',name:'Motor',icon:'⚙️',info:'Más potencia en todo el rango de vueltas. Los autos iniciales vienen con limitador de velocidad de fábrica: la ECU lo sube +25 km/h y el motor de competición lo quita.',levels:[
  {n:'Original'},
  {n:'Admisión y escape deportivo',cost:3500,eff:{power:0.07}},
  {n:'ECU reprogramada + árboles de levas',cost:8500,eff:{power:0.15,rpm:0.04,vgov:25}},
  {n:'Motor de competición',cost:17000,eff:{power:0.26,rpm:0.07,inertia:-0.15,vgov:999}}]},
 {id:'turbo',name:'Sobrealimentación',icon:'🌀',info:'Turbo más grande: empuje fuerte en medias y altas.',levels:[
  {n:'Original'},
  {n:'Turbo de alto soplado',cost:6000,eff:{power:0.10}},
  {n:'Turbo híbrido + intercooler',cost:12500,eff:{power:0.19}}]},
 {id:'weight',name:'Aligerado',icon:'🪶',info:'Menos peso = acelera, frena y dobla mejor.',levels:[
  {n:'Original'},
  {n:'Interior despojado',cost:3000,eff:{mass:-0.04}},
  {n:'Paneles de fibra de carbono',cost:9000,eff:{mass:-0.09,com:-0.02}},
  {n:'Chasis de competición',cost:18000,eff:{mass:-0.14,com:-0.04,yaw:-0.10}}]},
 {id:'brakes',name:'Frenos',icon:'🛑',info:'Más fuerza de frenado y menos fatiga.',levels:[
  {n:'Original'},
  {n:'Pastillas deportivas',cost:2000,eff:{brake:0.12}},
  {n:'Discos ventilados + pinzas de 6 pistones',cost:6000,eff:{brake:0.25}},
  {n:'Carbono-cerámicos',cost:14000,eff:{brake:0.40}}]},
 {id:'suspension',name:'Suspensión',icon:'🔧',info:'Nivel 1 habilita ajustar resortes, amortiguadores y barras. Nivel 3 habilita altura, caída (camber) y convergencia.',levels:[
  {n:'Original'},
  {n:'Kit deportivo',cost:3000,eff:{freq:0.08,arb:0.15,damp:0.10},unlock:['springs','damp','arb']},
  {n:'Suspensión de rally (recorrido largo)',cost:8000,eff:{travel:0.12,damp:0.15,freq:0.04},unlock:['springs','damp','arb']},
  {n:'Coilovers de competición',cost:15000,eff:{freq:0.06,damp:0.12,arb:0.20},unlock:['springs','damp','arb','height','camber','toe']}]},
 {id:'gearbox',name:'Transmisión',icon:'🕹️',info:'Cambios más rápidos. Nivel 2 habilita ajustar la relación final.',levels:[
  {n:'Original'},
  {n:'Embrague reforzado',cost:2500,eff:{clutch:-0.30,shift:-0.15}},
  {n:'Caja de relación corta',cost:7000,eff:{clutch:-0.35,shift:-0.35},unlock:['final']},
  {n:'Secuencial de competición',cost:14000,eff:{clutch:-0.45,shift:-0.60},unlock:['final']}]},
 {id:'diff',name:'Diferencial',icon:'⚖️',info:'Autoblocante: la potencia llega al piso sin que patine la rueda descargada.',levels:[
  {n:'Original'},
  {n:'Autoblocante deportivo',cost:4000,eff:{lsd:0.40},unlock:['lsd']},
  {n:'Diferencial activo de competición',cost:10000,eff:{lsd:0.80},unlock:['lsd','split']}]},
 {id:'aero',name:'Aerodinámica',icon:'🪽',info:'Carga aerodinámica: más agarre a alta velocidad a cambio de algo de drag.',levels:[
  {n:'Sin kit'},
  {n:'Alerón trasero regulable',cost:4500,eff:{aeroF:0.25,aeroR:0.85,drag:0.03},unlock:['aero']},
  {n:'Kit aerodinámico completo',cost:11000,eff:{aeroF:0.70,aeroR:1.10,drag:0.06},unlock:['aero']}]},
 {id:'nitro',name:'Nitro (N₂O)',icon:'🔥',info:'Óxido nitroso: empujón de potencia a pedido. Se recarga solo.',levels:[
  {n:'Sin nitro'},
  {n:'Kit de una botella',cost:8000,eff:{nitro:5,nitroBoost:0.35}},
  {n:'Doble botella de competición',cost:15000,eff:{nitro:8,nitroBoost:0.45}}]},
 {id:'stance',name:'Estilo y stance',icon:'😎',info:'Para gustos raros: camber extremo, grip trasero reducido para drift, suspensión neumática.',levels:[
  {n:'Original'},
  {n:'Kit stance (camber extremo)',cost:2500,unlock:['stance']},
  {n:'Kit drift (dirección de gran ángulo)',cost:6000,eff:{steer:0.25},unlock:['stance','drift']}]},
];
export const UPG_BY_ID=Object.fromEntries(UPGRADES.map(u=>[u.id,u]));

/* ─── Compuestos de neumático: multiplican el grip de cada superficie ─── */
export const TIRES=[
 {id:'street',n:'Calle',cost:0,icon:'⚪',info:'Todo terreno moderado. Correcto en todos lados.',
  s:{asphalt:1,dirt:1,shoulder:1,grass:1,outside:1,mud:1}},
 {id:'sport',n:'Deportivo',cost:2500,icon:'🟡',info:'Mejor en asfalto, algo peor en tierra.',
  s:{asphalt:1.08,dirt:0.95,shoulder:0.98,grass:0.95,outside:0.95,mud:0.92}},
 {id:'slick',n:'Semi-slick',cost:6500,icon:'🔴',info:'Máximo agarre en asfalto seco. En tierra es un jabón.',
  s:{asphalt:1.18,dirt:0.78,shoulder:0.9,grass:0.75,outside:0.75,mud:0.62}},
 {id:'gravel',n:'Rally grava',cost:4000,icon:'🟤',info:'Tacos para tierra y ripio. Sacrifica algo en asfalto.',
  s:{asphalt:0.95,dirt:1.18,shoulder:1.1,grass:1.12,outside:1.1,mud:1.12}},
 {id:'mud',n:'Barro (M/T)',cost:5000,icon:'🟫',info:'Tacos gigantes: barro y pasto. Ruidosos y lentos en asfalto.',
  s:{asphalt:0.86,dirt:1.1,shoulder:1.05,grass:1.2,outside:1.2,mud:1.4}},
 {id:'drift',n:'Drift',cost:3000,icon:'🌀',info:'Compuesto duro y progresivo: desliza largo y controlable.',
  s:{asphalt:0.9,dirt:0.9,shoulder:0.9,grass:0.9,outside:0.9,mud:0.9},falloff:0.82},
];
export const TIRE_BY_ID=Object.fromEntries(TIRES.map(t=>[t.id,t]));

/* ─── Ajuste fino: definición de cada parámetro ───
   req: pieza desbloqueante (null = siempre).  def: valor de fábrica.  */
export const TUNE_GROUPS=[
 {g:'Neumáticos',items:[
  {k:'pressF',n:'Presión delantera',min:22,max:40,step:0.5,def:30,u:'psi',info:'Menos presión = más huella y agarre en tierra, pero respuesta más blanda. Más presión = más precisa y rápida en asfalto.'},
  {k:'pressR',n:'Presión trasera',min:22,max:40,step:0.5,def:30,u:'psi',info:'Igual que la delantera, para el eje trasero.'}]},
 {g:'Alineación',items:[
  {k:'camberF',n:'Caída (camber) delantera',min:-5,max:1,step:0.1,def:-1.0,u:'°',req:'camber',info:'Inclinación de la rueda. Algo negativo (−1.5° a −3°) agarra más en curva; demasiado pierde frenado y tracción.'},
  {k:'camberR',n:'Caída (camber) trasera',min:-5,max:1,step:0.1,def:-0.5,u:'°',req:'camber',info:'Menos caída atrás = más tracción en línea recta; más caída = más agarre lateral.'},
  {k:'toeF',n:'Convergencia delantera',min:-1,max:1,step:0.05,def:0,u:'°',req:'toe',info:'Negativa (abierta) = entra más rápido a la curva. Positiva = más estable en recta.'},
  {k:'toeR',n:'Convergencia trasera',min:-1,max:1,step:0.05,def:0.1,u:'°',req:'toe',info:'Positiva (cerrada) = cola estable. Negativa = cola nerviosa, rota más.'},
  {k:'steer',n:'Ángulo de dirección',min:70,max:130,step:1,def:100,u:'%',info:'Cuánto giran las ruedas delanteras a fondo.'}]},
 {g:'Suspensión',items:[
  {k:'height',n:'Altura',min:-60,max:80,step:5,def:0,u:'mm',req:'height',info:'Más baja = centro de gravedad bajo, menos balanceo. Más alta = pasa mejor los pozos y saltos.'},
  {k:'springF',n:'Resortes delanteros',min:60,max:160,step:1,def:100,u:'%',req:'springs',unit:'k',info:'Duro = responde rápido y rola poco. Blando = copia el terreno y tracciona en tierra.'},
  {k:'springR',n:'Resortes traseros',min:60,max:160,step:1,def:100,u:'%',req:'springs',unit:'k',info:'Trasero más duro que el delantero = más sobreviraje.'},
  {k:'bump',n:'Amortiguador: compresión',min:50,max:170,step:1,def:100,u:'%',req:'damp',info:'Controla cómo se hunde en los pozos. Muy alto = el auto rebota en los baches.'},
  {k:'rebound',n:'Amortiguador: extensión',min:50,max:170,step:1,def:100,u:'%',req:'damp',info:'Controla cómo vuelve la rueda. Bajo = rebote largo; alto = la rueda se despega en pozos seguidos.'},
  {k:'arbF',n:'Barra estabilizadora del.',min:0,max:220,step:1,def:100,u:'%',req:'arb',info:'Más dura adelante = más subviraje (empuja de trompa).'},
  {k:'arbR',n:'Barra estabilizadora tras.',min:0,max:220,step:1,def:100,u:'%',req:'arb',info:'Más dura atrás = más sobreviraje (la cola sale).'}]},
 {g:'Frenos',items:[
  {k:'bias',n:'Reparto de frenado',min:40,max:78,step:1,def:0,u:'% del.',info:'Más adelante = estable al frenar. Más atrás = el auto rota al entrar a la curva.'},
  {k:'bpress',n:'Presión de freno',min:70,max:125,step:1,def:100,u:'%',info:'Fuerza total del frenado.'}]},
 {g:'Transmisión',items:[
  {k:'split',n:'Reparto de tracción',min:0,max:100,step:1,def:-1,u:'% del.',info:'0% = tracción trasera pura (RWD) · 100% = delantera (FWD).'},
  {k:'lsd',n:'Bloqueo del diferencial',min:0,max:250,step:1,def:100,u:'%',req:'lsd',info:'Más bloqueo = más tracción saliendo de curva, pero más difícil que gire.'},
  {k:'final',n:'Relación final',min:75,max:130,step:1,def:100,u:'%',req:'final',info:'Más alto = acelera más pero menos velocidad final. Más bajo = más velocidad punta.'}]},
 {g:'Aerodinámica',items:[
  {k:'aeroF',n:'Carga delantera',min:0,max:100,step:1,def:50,u:'%',req:'aero',info:'Más carga adelante = el frente muerde más en curvas rápidas.'},
  {k:'aeroR',n:'Carga trasera (alerón)',min:0,max:100,step:1,def:60,u:'%',req:'aero',info:'Más ángulo de alerón = cola pegada, pero menos velocidad final.'}]},
 {g:'Diversión (gustos raros)',items:[
  {k:'stanceCamber',n:'Camber extremo (stance)',min:0,max:12,step:0.5,def:0,u:'°',req:'stance',info:'Inclinación exagerada solo por estilo. Ojo: cuanto más, menos agarre.'},
  {k:'gripR',n:'Grip trasero',min:60,max:110,step:1,def:100,u:'%',info:'Bajalo para que la cola se suelte fácil y derrapar. 100% = normal.'},
  {k:'gripF',n:'Grip delantero',min:70,max:110,step:1,def:100,u:'%',info:'Agarre del eje delantero.'}]},
];
export const TUNE_ITEMS=Object.fromEntries(TUNE_GROUPS.flatMap(g=>g.items).map(i=>[i.k,i]));

/* ─── Pintura ─── */
export const PAINTS=['#e11d2a','#ff6a08','#ffc300','#9ef01a','#12a454','#00b4d8','#1a4fe0','#3a0ca3','#7b2cbf','#ff4d9d',
 '#f5f5f2','#c0c5cc','#6b7280','#2b2f36','#0b0c0e','#c9a24b','#8b5e34','#2f6f5e','#0f3d5e','#5a1a1a'];
export const FINISHES=[{id:'gloss',n:'Brillante'},{id:'metal',n:'Metalizado'},{id:'matte',n:'Mate'},{id:'chrome',n:'Cromado'}];

/* ─── Niveles de piloto ─── */
export function xpForLevel(l){return Math.round(1100*Math.pow(l,1.5));}

/* ─── Logros: objetivos con premio (se reclaman en el menú) ─── */
export const ACHIEVEMENTS=[
 {id:'win1',icon:'🥇',n:'Primera victoria',d:'Ganá una carrera contra la IA.',cr:3000,test:p=>p.stats.wins>=1},
 {id:'win5',icon:'🏆',n:'Piloto ganador',d:'Ganá 5 carreras.',cr:8000,test:p=>p.stats.wins>=5},
 {id:'win15',icon:'👑',n:'Imbatible',d:'Ganá 15 carreras.',cr:20000,test:p=>p.stats.wins>=15},
 {id:'pod10',icon:'🎖️',n:'Siempre en el podio',d:'Terminá 10 veces entre los 3 primeros.',cr:7000,test:p=>p.stats.podiums>=10},
 {id:'km50',icon:'🛣️',n:'Kilómetros',d:'Recorré 50 km.',cr:4000,test:p=>p.stats.km>=50},
 {id:'km250',icon:'🌎',n:'Trotamundos',d:'Recorré 250 km.',cr:15000,test:p=>p.stats.km>=250},
 {id:'spd200',icon:'⚡',n:'Barrera de los 200',d:'Superá los 200 km/h en un evento.',cr:5000,test:p=>p.stats.topSpeed>=200},
 {id:'spd250',icon:'🚀',n:'Misil',d:'Superá los 250 km/h.',cr:12000,test:p=>p.stats.topSpeed>=250},
 {id:'drift5k',icon:'🌀',n:'Derrapador',d:'Hacé 5.000 puntos en un evento de drift.',cr:4000,test:p=>p.stats.driftBest>=5000},
 {id:'drift15k',icon:'🔥',n:'Rey del humo',d:'Hacé 15.000 puntos de drift.',cr:12000,test:p=>p.stats.driftBest>=15000},
 {id:'board6',icon:'💥',n:'Rompecarteles',d:'Rompé 6 carteles GSKORP en el mundo abierto.',cr:4000,test:p=>Object.keys(p.stats.boards||{}).length>=6},
 {id:'board12',icon:'🧨',n:'Sin cartel en pie',d:'Rompé los 12 carteles.',cr:12000,test:p=>Object.keys(p.stats.boards||{}).length>=12},
 {id:'trap150',icon:'📸',n:'Multado',d:'Pasá un radar a más de 150 km/h.',cr:3500,test:p=>Object.values(p.stats.traps||{}).some(v=>v>=150)},
 {id:'cars2',icon:'🚘',n:'Coleccionista',d:'Tené 2 autos en el garaje.',cr:5000,test:p=>Object.keys(p.owned).length>=2},
 {id:'cars4',icon:'🏁',n:'Garaje completo',d:'Tené los 4 autos.',cr:25000,test:p=>Object.keys(p.owned).length>=4},
 {id:'gold10',icon:'⭐',n:'Diez de oro',d:'Conseguí 10 medallas de oro.',cr:10000,test:p=>Object.values(p.events).filter(e=>e.medal===3).length>=10},
 {id:'cup1',icon:'🏆',n:'Campeón de copa',d:'Completá una copa entera.',cr:6000,test:p=>Object.keys(p.cups||{}).length>=1},
 {id:'lvl10',icon:'🎓',n:'Nivel 10',d:'Llegá al nivel 10 de piloto.',cr:10000,test:p=>p.level>=10},
];

/* presets de ajuste rápido */
export const PRESETS={
 asfalto:{pressF:32,pressR:32,camberF:-2.2,camberR:-1.4,toeF:-0.05,toeR:0.15,height:-30,springF:125,springR:120,bump:115,rebound:120,arbF:120,arbR:115,aeroF:70,aeroR:70,gripF:100,gripR:100},
 tierra:{pressF:25,pressR:25,camberF:-1.0,camberR:-0.6,toeF:0,toeR:0.2,height:40,springF:85,springR:85,bump:90,rebound:95,arbF:80,arbR:85,aeroF:40,aeroR:50,gripF:100,gripR:100},
 drift:{pressF:30,pressR:36,camberF:-3.5,camberR:-0.5,toeF:-0.3,toeR:0,height:-20,springF:120,springR:110,arbF:130,arbR:90,split:10,lsd:220,steer:125,gripF:100,gripR:78},
 salto:{pressF:28,pressR:28,height:80,springF:95,springR:95,bump:125,rebound:110,arbF:90,arbR:90},
};
export const PRESET_N={asfalto:'Asfalto',tierra:'Tierra',drift:'Drift',salto:'Saltos'};
/* para qué sirve cada uno (se muestra al sugerirlo antes de correr) */
export const PRESET_INFO_T={asfalto:'Bajo y firme, gomas infladas: más agarre y respuesta en la ruta.',tierra:'Más alto y blando, menos presión: copia los pozos y tracciona en la tierra.',drift:'Cola suelta y mucho ángulo de volante: para cruzar el auto.',salto:'Muy alto y amortiguado: aterriza sin rebotar ni tocar el piso.'};
