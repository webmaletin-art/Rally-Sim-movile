/* ═══ Modo carrera: copas y eventos ═══
   tipos: race (vs IA) · timetrial (contrarreloj con medallas) · drift (puntos) ·
          parking (estacionar rápido) · rush (banderas en mundo abierto) · trap (radar de velocidad)
   seg: [inicio, fin] como fracción de la vuelta → tramo punto a punto.  laps: vueltas completas. */
export const TIERS=[
 {id:'debut',name:'Copa Debut',sub:'Tus primeras carreras',maxPI:599,stars:0,base:3500,skill:0.76,color:'#37b6ff',icon:'🏁'},
 {id:'nacional',name:'Campeonato Nacional',sub:'Rivales serios · autos clase A',maxPI:699,stars:12,base:6500,skill:0.84,color:'#ff8a1f',icon:'🏆'},
 {id:'continental',name:'Serie Continental',sub:'Los mejores de la región · clase S',maxPI:799,stars:28,base:11000,skill:0.9,color:'#ff3b4f',icon:'🌎'},
 {id:'leyenda',name:'Leyenda GSkorp',sub:'Clase libre · solo para leyendas',maxPI:999,stars:46,base:18000,skill:0.96,color:'#b15cff',icon:'👑'},
 {id:'camiones',name:'Rally Raid de Camiones',sub:'Solo el Colossus 6x6',maxPI:999,stars:6,base:7000,skill:0.82,color:'#c9a24b',icon:'🚛',car:'truck'},
];
export const EVENTS=[
 /* ── Copa Debut ── */
 {id:'d1',tier:'debut',type:'timetrial',name:'Primer Tramo',map:'forest',seg:[0,0.22],sky:'day',desc:'Un tramo corto de tierra para conocer tu auto. Bajá del tiempo para llevarte el oro.'},
 {id:'d2',tier:'debut',type:'race',name:'Vuelta al Lago',map:'lake',laps:2,ai:3,sky:'day',desc:'Asfalto, curvas amplias y tres rivales. Largás último: a pasarlos.'},
 {id:'d3',tier:'debut',type:'parking',name:'Cochera Exprés',map:'parking',sky:'day',desc:'Metelo en la cochera lo más rápido que puedas, sin tocar nada.'},
 {id:'d4',tier:'debut',type:'race',name:'Polvo en la Cantera',map:'quarry',laps:2,ai:3,sky:'sunset',desc:'Tierra roja, curvas cerradas y mucha tierra en el aire.'},
 {id:'d5',tier:'debut',type:'drift',name:'Plaza de Trompos',map:'drift',time:60,sky:'sunset',desc:'60 segundos para sumar puntos de derrape. Mantené el ángulo y la velocidad para multiplicar.'},
 {id:'d6',tier:'debut',type:'rush',name:'Cazador del Valle',map:'offroad',flags:6,time:150,sky:'day',desc:'Mundo abierto: pasá por las 6 banderas antes de que se acabe el tiempo. El camino lo elegís vos.'},
 {id:'d7',tier:'debut',type:'race',name:'Final: Bosque Salvaje',map:'forest',seg:[0,0.42],ai:5,sky:'overcast',final:true,desc:'La final de la copa: tramo largo de bosque contra cinco rivales.'},
 /* ── Nacional ── */
 {id:'n1',tier:'nacional',type:'timetrial',name:'Montaña Contrarreloj',map:'asphaltLong',seg:[0,0.38],sky:'day',desc:'Ruta de montaña rapidísima. Frená tarde, salí fuerte.'},
 {id:'n2',tier:'nacional',type:'race',name:'Atardecer en el Lago',map:'lake',laps:3,ai:5,sky:'sunset',desc:'Tres vueltas al lago con el sol de frente.'},
 {id:'n3',tier:'nacional',type:'trap',name:'Radar de la Recta',map:'lake',seg:[0.97,0.22],sky:'day',desc:'Pasá por el radar lo más rápido posible. Todo el tramo es tuyo para tomar carrera.'},
 {id:'n4',tier:'nacional',type:'race',name:'Cantera al Revés',map:'quarryRev',laps:2,ai:5,sky:'day',desc:'La cantera en sentido contrario: nada es como lo recordás.'},
 {id:'n5',tier:'nacional',type:'drift',name:'Drift en la Plaza (Pro)',map:'drift',time:75,sky:'dusk',desc:'Más tiempo, más exigencia. Encadená derrapes largos.'},
 {id:'n6',tier:'nacional',type:'race',name:'Bosque Inverso',map:'forestRev',seg:[0,0.45],ai:5,sky:'rain',desc:'El bosque de punta a punta, al revés… y bajo la lluvia. El grip baja: frená antes.'},
 {id:'n7',tier:'nacional',type:'rush',name:'Valle: 10 Banderas',map:'offroad',flags:10,time:230,sky:'sunset',desc:'Diez banderas repartidas por todo el valle.'},
 {id:'n8',tier:'nacional',type:'race',name:'Gran Premio Nacional',map:'asphaltLong',laps:1,ai:5,sky:'day',final:true,desc:'La vuelta completa a la montaña contra los mejores del país.'},
 /* ── Continental ── */
 {id:'c1',tier:'continental',type:'race',name:'Rally del Bosque',map:'forest',laps:1,ai:5,sky:'rain',desc:'Vuelta completa al bosque: más de 5 km de tierra.'},
 {id:'c2',tier:'continental',type:'timetrial',name:'Cantera: 3 Vueltas',map:'quarry',laps:3,sky:'sunset',desc:'Constancia pura: tres vueltas sin errores.'},
 {id:'c3',tier:'continental',type:'race',name:'Lago: Resistencia',map:'lake',laps:4,ai:5,sky:'dusk',desc:'Cuatro vueltas. Cuidá el auto y atacá al final.'},
 {id:'c4',tier:'continental',type:'drift',name:'Rey de la Plaza',map:'drift',time:90,sky:'day',desc:'Solo los mejores superan esta marca.'},
 {id:'c5',tier:'continental',type:'race',name:'Montaña Inversa',map:'asphaltRev',laps:1,ai:5,sky:'sunset',desc:'La montaña al revés: bajadas largas y frenadas fuertes.'},
 {id:'c6',tier:'continental',type:'parking',name:'Cochera de Precisión',map:'parking',sky:'dusk',hard:true,desc:'Tiempos de profesional. Un toque y perdés.'},
 {id:'c7',tier:'continental',type:'race',name:'Final Continental',map:'forestRev',laps:1,ai:5,sky:'overcast',final:true,desc:'El bosque completo al revés. Esta es para campeones.'},
 /* ── Leyenda ── */
 {id:'l1',tier:'leyenda',type:'race',name:'Montaña: Dos Vueltas',map:'asphaltLong',laps:2,ai:5,sky:'rain',desc:'Clase libre. Todo vale.'},
 {id:'l2',tier:'leyenda',type:'timetrial',name:'Récord del Bosque',map:'forest',laps:1,sky:'day',desc:'La vuelta completa al bosque contra el reloj.'},
 {id:'l3',tier:'leyenda',type:'race',name:'Cantera Inversa: Maratón',map:'quarryRev',laps:4,ai:5,sky:'dusk',desc:'Cuatro vueltas de cantera al revés.'},
 {id:'l4',tier:'leyenda',type:'trap',name:'Radar de la Montaña',map:'asphaltLong',seg:[0.5,0.72],sky:'day',desc:'¿Cuánto da tu auto de verdad?'},
 {id:'l5',tier:'leyenda',type:'race',name:'Leyenda GSkorp',map:'forest',laps:1,ai:5,sky:'sunset',final:true,desc:'El último desafío. Ganala y sos leyenda.'},
 /* ── Camiones ── */
 {id:'k1',tier:'camiones',type:'race',name:'Duelo de Titanes',map:'quarry',laps:2,ai:3,sky:'day',desc:'Camiones de 10 toneladas en la cantera. Cuidado con los golpes.'},
 {id:'k2',tier:'camiones',type:'timetrial',name:'Raid del Bosque',map:'forest',seg:[0,0.3],sky:'overcast',desc:'El camión contra el reloj en el bosque.'},
 {id:'k3',tier:'camiones',type:'rush',name:'Travesía del Valle',map:'offroad',flags:5,time:240,sky:'sunset',desc:'Banderas en el valle con el gigante.'},
];
export const EVENT_BY_ID=Object.fromEntries(EVENTS.map(e=>[e.id,e]));
export const TYPE_INFO={
 race:{n:'Carrera',icon:'🏁'},timetrial:{n:'Contrarreloj',icon:'⏱️'},drift:{n:'Drift',icon:'🌀'},
 parking:{n:'Estacionar',icon:'🅿️'},rush:{n:'Banderas',icon:'🚩'},trap:{n:'Radar',icon:'📸'},
};
/* ─── medallas: 3 oro · 2 plata · 1 bronce · 0 nada ───
   targets: [oro, plata, bronce]; para tiempos, menor es mejor */
export const TARGETS={
 d1:[40,44,49],d3:[16,22,32],d5:[6000,3800,2000],d6:[55,35,15],
 n1:[41.5,45.5,50],n3:[176,162,145],n5:[9000,6000,3500],n7:[60,35,12],
 c2:[258,282,310],c4:[14000,9500,6000],c6:[12,16,22],
 l2:[172,188,208],l4:[225,205,185],
 k2:[67,73,80],k3:[70,40,15],
};
export function lowerIsBetter(type){return type==='timetrial'||type==='parking';}
export function medalFor(ev,value){
 if(ev.type==='race')return value===1?3:value===2?2:value===3?1:0;
 const t=TARGETS[ev.id];if(!t)return 0;
 if(lowerIsBetter(ev.type)){if(value<=t[0])return 3;if(value<=t[1])return 2;if(value<=t[2])return 1;return 0;}
 if(value>=t[0])return 3;if(value>=t[1])return 2;if(value>=t[2])return 1;return 0;}
export function rewardFor(ev,medal,tier){const base=tier.base*(ev.final?1.6:1);const mult=[0.2,0.55,0.75,1][medal];return {cr:Math.round(base*mult/50)*50,xp:Math.round((250+tier.base*0.12)*(0.4+medal*0.3)*(ev.final?1.5:1))};}
