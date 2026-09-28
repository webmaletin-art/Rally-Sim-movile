/* ═══ Duelos del mundo abierto: los rivales de la historia tienen su base en el campo ═══
   Hacen trompos, saltos u ochos. Si te acercás despacio, los podés retar:
   aparecen arcos de control de a uno (el siguiente sale cuando pasás el anterior) y el primero en pasar todos gana la plata.
   Datos puros (sin three.js): también los lee tools/story_lines.mjs para generar las voces. */

/* stunt: 'donas' (trompos), 'saltos' (ida y vuelta por la rampa), 'ocho' (ochos con freno de mano)
   unlock: misión de la historia que hay que ganar para que el rival te acepte el duelo */
export const DUEL_RIVALS=[
 {id:'buitre',who:'buitre',name:'El Buitre',car:'t1plus',paint:{body:'#15171b',accent:'#c1121f',rim:'#c1121f',finish:'matte'},
  x:-90,z:150,n:5,reward:3000,skill:0.9,stunt:'donas',unlock:null,
  intro:[['buitre','Mirá quién vino a visitarme. El hijo de Correa.'],['buitre','Cinco arcos, pibe. El que pasa primero por todos se lleva la plata.'],['tano','Seguí los arcos rojos del mapa. Cada vez que pasás uno, sale el siguiente.']],
  again:[['buitre','¿Otra vez vos? Dale, que tengo toda la tarde.']],
  win:[['buitre','Suerte de principiante. La próxima no te regalo nada.'],['tano','¡Le ganamos al Buitre en su propia casa!']],
  lose:[['buitre','Igual que tu viejo. Mucho pie y poca cabeza.'],['tano','Tranquilo. Lo agarramos en la revancha.']],
  taunt:['¡Te veo por el espejo, Correa!','Ese arco es mío.','Tu viejo doblaba mejor que vos.']},
 {id:'hiena',who:'hiena',name:'La Hiena',car:'t1plus',paint:{body:'#d8358f',accent:'#16181c',rim:'#16181c',finish:'gloss'},
  x:170,z:-110,n:6,reward:4000,skill:0.95,stunt:'saltos',unlock:'c3m2',ramp:{yaw:0.9,len:10,w:5,h:1.5},
  lock:'La Hiena no corre con cualquiera. Ganale en el bosque (Capítulo 3) y te va a buscar.',
  intro:[['hiena','¡Ja! ¿Vos sos el que me hizo comer tierra en el bosque?'],['hiena','Seis arcos. Si perdés, me dejás el volante de recuerdo.'],['tano','No le sigas el juego. Manejá limpio y dejala hablar.']],
  again:[['hiena','¿Volviste a buscar más? ¡Me encanta!']],
  win:[['hiena','¡No me lo puedo creer! Bueno, tomá. Te lo ganaste.'],['tano','Se le fue la risa. Eso vale más que la plata.']],
  lose:[['hiena','¡Jajaja! ¡Andá a practicar a la plaza!'],['tano','Que se ría. La próxima se la borramos.']],
  taunt:['¡Jajaja! ¡Por acá, nene!','¿Eso es todo lo que tenés?','¡Chau, chau!']},
 {id:'sombra',who:'sombra',name:'La Sombra',car:'genesis',paint:{body:'#221d36',accent:'#b9b3ff',rim:'#2a2d33',finish:'metal'},
  x:-280,z:-40,n:8,reward:6000,skill:0.97,stunt:'ocho',unlock:'c3m4',
  lock:'La Sombra ni te mira todavía. Ganale en el circuito (Capítulo 3).',
  intro:[['sombra','No hablo mucho. Ocho arcos.'],['sombra','Si me ganás, te ganaste mi respeto. Y la plata.'],['tano','Es la más fina de todos. No le regales ni un metro.']],
  again:[['sombra','Otra vez. Bien.']],
  win:[['sombra','Bien manejado. No me lo voy a olvidar.'],['tano','¿La escuchaste? La Sombra felicitando a alguien. Anotalo.']],
  lose:[['sombra','Todavía no.'],['tano','Dos palabras y nos dejó de cama. Otra vez.']],
  taunt:['…','Muy abierto.','Llegás tarde.']},
 {id:'tanque',who:'tanque',name:'El Tanque',car:'truck',paint:{body:'#6b5a2e',accent:'#1b1d22',rim:'#1b1d22',finish:'matte'},
  x:110,z:260,n:10,reward:8000,skill:1,stunt:'donas',unlock:'c4m3',
  lock:'El Tanque no se baja del camión por cualquiera. Ganale en la cantera (Capítulo 4).',
  intro:[['tanque','Diez arcos, flaco. Yo no esquivo nada: paso por encima.'],['tanque','Si te cruzás en mi camino, te llevo puesto.'],['tano','Es un camión. En las curvas lo pasamos. No te le pongas adelante.']],
  again:[['tanque','¿Querés más? Subí.']],
  win:[['tanque','Me ganaste con ese autito. Está bien, tomá lo tuyo.'],['tano','¡Le ganamos al camión! Diez de diez.']],
  lose:[['tanque','Te dije. Lo grande siempre llega.'],['tano','Buscale las curvas, no las rectas. La próxima es nuestra.']],
  taunt:['¡Correte!','¡Ahí voy!','Te paso por arriba.']},
];
export const DUEL_BY_ID=Object.fromEntries(DUEL_RIVALS.map(r=>[r.id,r]));

/* Tano durante el duelo (se escucha: es tu copiloto) */
export const TANO_DUEL={
 cp:['¡Adentro! Mirá el mapa, ya salió el otro.','¡Punto nuestro! El próximo está marcado.','¡Pasamos! Seguí la flecha.','¡Bien ahí! Vamos por el siguiente.'],
 behind:['Nos sacó uno. Cortá camino por el campo.','Va adelante. No hace falta ir por la ruta, andá derecho.'],
 ahead:['Le sacamos uno. No aflojes.','Vamos adelante. Cuidado con los árboles.'],
 last:['¡Último arco! ¡Todo el pie!'],
};

export const duelLineId=(r,part,k)=>`duel_${r}_${part}_${k}`;
