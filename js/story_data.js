/* ═══ Modo historia · capítulos 2 a 4 ═══
   Personajes (solo por voz, por radio o intercomunicador):
   - TANO (copiloto): Cayetano "Tano" Bustos, mecánico y copiloto de tu viejo durante quince años. Te conoce desde que usabas pañales.
   - EL VIEJO: Aníbal Correa, tres veces campeón de la Montaña. Desapareció hace ocho años en una etapa nocturna, dentro de la mina.
   - EL BUITRE: Horacio Salvatierra. Fue el primer copiloto de tu viejo; lo vendió por plata y hoy maneja Los Cuervos, carreras clandestinas y repuestos robados.
   - LA HIENA: corre para Salvatierra. Choca por deporte, se ríe de todo.
   - EL TANQUE: maneja un camión Dakar de diez toneladas. Habla poco.
   - LA SOMBRA: la mejor piloto de Los Cuervos. Nunca corre sucio.
   - DON ALDO: el mecánico del pueblo, amigo de Tano. Cuida su galpón como a un hijo.
   - CUERVO: cualquier corredor de Salvatierra por la radio.
   quien → voz: tano · viejo · buitre · hiena · tanque · sombra · aldo · cuervo
   cuando (durante la misión): inicio · rival_cerca · dano50 · mitad · final_cerca · tiempo_mal · poco_tiempo · radar */

export const SPEAKERS={
 tano:{n:'Tano',c:'#ffb347'},viejo:{n:'El Viejo',c:'#9fd3ff'},buitre:{n:'El Buitre',c:'#ff5a5a'},hiena:{n:'La Hiena',c:'#ff7ad9'},
 tanque:{n:'El Tanque',c:'#c9a24b'},sombra:{n:'La Sombra',c:'#b9b3ff'},aldo:{n:'Don Aldo',c:'#8fe388'},cuervo:{n:'Radio',c:'#ff8a80'}};

/* estrellas por tipo: se calculan con lo que mide el juego */
export const CHAPTERS=[
 {n:2,title:'Lo que había en la caja',sum:'Salieron de la mina con una caja de herramientas vieja. Tano la reconoce: es la de tu viejo, Aníbal Correa. Afuera los esperan Los Cuervos.',
  hook:[['buitre','Tu viejo me debe una carrera, Correa. Y la vas a pagar vos.']],
  missions:[
  {id:'c2m1',title:'Faros en la salida',type:'escape',map:'quarry',seg:[0.02,0.72],sky:'dusk',ai:2,
   goal:'Escapá por la Cantera Roja con los dos Cuervos encima. Si el auto llega a 0%, te atrapan.',stars:{hp:[1,50,80]},reward:2500,
   shots:['interior','dos_autos','de_frente','persecucion_lejos'],
   intro:[['tano','¿Viste la caja? Es la de tu viejo. Tiene su nombre rayado.'],['tano','Guardala bajo el asiento. Y agarrate, que nos vieron.'],
    ['cuervo','Salieron dos de la mina. Los tengo en la cantera.'],['tano','Dos faros atrás. No les des el costado.']],
   during:{inicio:[['tano','Por la tierra roja, que ellos van pesados.']],rival_cerca:[['cuervo','Pará, pibe. De acá no sale nadie.']],dano50:[['tano','El auto chilla por todos lados. Aguantá.']],final_cerca:[['tano','¡Ya se ve la ruta! ¡Dale que salimos!']]},
   win:[['tano','Los perdimos en el polvo. Respirá.'],['tano','Ahora sí, abramos esa caja.']],lose:[['tano','Nos encerraron. Probemos otra vez, más por adentro.']]},
  {id:'c2m2',title:'La cinta',type:'cinematica',map:'asphaltLong',seg:[0.05,0.33],sky:'dusk',ai:0,
   goal:'De noche, por la ruta de la montaña. Tano encontró algo en la caja.',stars:{auto:3},reward:1500,
   shots:['interior','capo','aerea','persecucion_lejos','detras_piloto','costado_pista'],
   intro:[['tano','Hay una cinta de cassette. Tu viejo grababa todo.'],['tano','La pongo en el estéreo. Bajá un cambio, que no se oye.'],
    ['viejo','Si escuchás esto, llegaste a la mina. Sabía que ibas a venir.'],['viejo','No te enojes conmigo. Me fui para que no te buscaran a vos.'],
    ['viejo','Lo que sacaste es la llave del Cóndor. No se la des a nadie.'],['tano','El Cóndor. El prototipo. Yo creía que era un cuento de taller.'],
    ['viejo','Tano, si estás ahí, cuidalo. Vos sabés de quién hablo.'],['tano','Salvatierra. Tu viejo habla de Salvatierra.'],
    ['tano','Ese tipo fue su primer copiloto. Hasta que lo vendió por plata.']],
   during:{},win:[],lose:[]},
  {id:'c2m3',title:'El refugio del bosque',type:'carrera',map:'forest',seg:[0,0.42],sky:'overcast',ai:2,skill:0.8,
   goal:'La cinta nombra un refugio en el bosque. Los Cuervos van para el mismo lado: llegá primero.',stars:{pos1hp:[0,50,80]},reward:3000,
   shots:['dos_autos','costado_pista','interior'],
   intro:[['tano','La cinta habla de un refugio en el bosque, pasando la loma.'],['buitre','Los Cuervos también escuchamos la radio, Tano.'],
    ['tano','Es Salvatierra. Nos pinchó la frecuencia.'],['buitre','El que llegue primero al refugio se queda con lo que hay adentro.']],
   during:{inicio:[['tano','Largá tranquilo y atacalos en las horquillas.']],rival_cerca:[['cuervo','Correte, nene, que atrás viene el patrón.']],mitad:[['tano','Vamos bien. El refugio está pasando la próxima loma.']],final_cerca:[['tano','¡Ahí se ve el techo del refugio!']]},
   win:[['tano','Llegamos primero. Hay un mapa clavado en la pared.'],['tano','Tiene la letra de tu viejo. Cinco cruces en el valle.']],lose:[['buitre','Llegué antes, Correa. Como siempre.']]},
  {id:'c2m4',title:'La foto de la ruta',type:'radar',map:'lake',seg:[0.97,0.22],sky:'dusk',ai:0,
   goal:'Salvatierra propone un trato: pasá por el radar del lago lo más rápido que puedas.',stars:{kmh:[135,148,158]},reward:3000,
   shots:['costado_pista','de_frente','interior'],
   intro:[['buitre','Te propongo algo, pibe. Un radar, una foto.'],['buitre','Si pasás a más de ciento cuarenta, esta noche no te sigo.'],
    ['tano','No le creas nada. Pero la recta es buena.'],['tano','Tomá carrera desde la curva del lago y no levantes.']],
   during:{inicio:[['tano','Todo el pie, sin miedo.']],radar:[['tano','¡Ahora, ahora, no levantes!']]},
   win:[['buitre','Linda foto. Igualita a tu viejo, el mismo pie pesado.'],['tano','Nos deja ir. Por hoy.']],lose:[['buitre','Muy lento. Mañana te vuelvo a buscar.']]}]},

 {n:3,title:'La deuda de Salvatierra',sum:'Salvatierra dice que tu viejo le debe el Cóndor. Te ofrece pagarlo con carreras en su circuito. Si perdés, se queda con la caja.',
  hook:[['buitre','Pagaste. Pero no quiero la caja. Quiero el Cóndor armado.'],['buitre','Y lo vas a armar vos.']],
  missions:[
  {id:'c3m1',title:'Primera cuota',type:'carrera',map:'lake',laps:1,sky:'overcast',ai:3,skill:0.8,
   goal:'Una vuelta al Circuito del Lago contra tres Cuervos. Tenés que ganar.',stars:{pos1hp:[0,50,80]},reward:3500,
   shots:['de_frente','dos_autos','costado_pista'],
   intro:[['buitre','Una vuelta al lago. Si ganás, bajamos la deuda.'],['tano','Los del Cuervo corren sucio. Mirá los espejos.'],['tano','Y no mires el agua, que te hipnotiza.']],
   during:{inicio:[['tano','Largaste bien. Ahora a buscar la punta.']],rival_cerca:[['cuervo','Esta pista es de Salvatierra, nene.']],final_cerca:[['tano','¡Última curva! ¡Cerrá la puerta!']]},
   win:[['tano','Una cuota menos. Faltan dos.']],lose:[['buitre','La deuda crece, Correa. Con intereses.']]},
  {id:'c3m2',title:'La Hiena',type:'escape',map:'forestRev',seg:[0.02,0.30],sky:'rain',ai:1,boss:'La Hiena',hunterK:1.18,
   goal:'La Hiena quiere la caja. Escapá por el bosque bajo la lluvia sin que te destroce el auto.',stars:{hp:[1,50,80]},reward:4000,gift:'turbo',
   shots:['persecucion_cerca','dos_autos','interior'],
   intro:[['hiena','¿Vos sos el hijo del Correa? Qué desilusión.'],['tano','La Hiena. Choca por deporte. No la dejes pegarse.'],
    ['hiena','Mi abuela dobla mejor que vos, y maneja un Falcon.'],['tano','Con lluvia ella resbala igual que nosotros. Pensá en eso.']],
   during:{rival_cerca:[['hiena','¡Toc, toc! ¿Hay alguien en casa?']],dano50:[['tano','Otro golpe así y nos quedamos sin puerta.']],mitad:[['hiena','Me estoy divirtiendo. ¿Vos no?']]},
   win:[['hiena','Esto no terminó, Correa. Te voy a encontrar.'],['tano','Se quedó en la cuneta. Qué pena, ¿no?']],lose:[['hiena','¡Chau, campeón! Saludos a tu papi.']]},
  {id:'c3m3',title:'La bajada de los badenes',type:'contrarreloj',map:'descent',seg:[0,0.30],sky:'sunset',ai:0,
   goal:'Segunda cuota: bajá la montaña antes que el reloj de Salvatierra.',stars:{time:[54,46,41]},reward:3800,
   shots:['interior','paragolpes','aerea'],
   intro:[['buitre','Segunda cuota. Bajá la montaña antes que mi reloj.'],['tano','Los badenes te levantan. No frenes en el aire.'],['tano','Tu viejo la bajaba en tercera todo el camino. Un loco.']],
   during:{inicio:[['tano','Mirá lejos, no el capó.']],tiempo_mal:[['tano','Vamos atrás del reloj. Soltá los frenos.']],final_cerca:[['tano','¡Último badén y abajo!']]},
   win:[['buitre','Buen tiempo. Tu viejo hacía uno mejor.'],['tano','Dos cuotas. Falta la última.']],lose:[['tano','Se nos pasó el reloj. Otra bajada y sale.']]},
  {id:'c3m4',title:'Duelo con La Sombra',type:'carrera',map:'asphaltRev',seg:[0,0.45],sky:'dusk',ai:1,boss:'La Sombra',bossSkill:1.04,
   goal:'La última cuota es un mano a mano con La Sombra, la mejor de Los Cuervos.',stars:{pos1hp:[0,50,80]},reward:5000,
   shots:['de_frente','dos_autos','costado_pista','interior'],
   intro:[['sombra','Buenas noches. Yo soy la última cuota.'],['sombra','No corro sucio. No lo necesito.'],['tano','La Sombra. Nunca perdió en esta montaña.'],['tano','Frená donde ella frena, y salí un segundo antes.']],
   during:{rival_cerca:[['sombra','Estás cerca. Eso es un error.']],mitad:[['tano','Le estamos comiendo metros. ¡Seguí!']]},
   win:[['sombra','Me ganaste limpio. Eso no se olvida.'],['tano','¡Le ganaste a La Sombra! ¡No lo puedo creer!']],lose:[['sombra','Te faltan años. Volvé cuando los tengas.']]}]},

 {n:4,title:'El Cóndor',sum:'El mapa del refugio marca dónde tu viejo escondió las piezas del Cóndor. Don Aldo presta su galpón para armarlo. Salvatierra no se queda quieto.',
  hook:[['buitre','Muy lindo el Cóndor. Pero le falta el corazón.'],['buitre','Está en la Trinchera. Y tu viejo también.']],
  missions:[
  {id:'c4m1',title:'Las marcas del Viejo',type:'banderas',map:'offroad',flags:5,time:170,sky:'day',ai:0,
   goal:'Cinco cruces en el mapa, cinco piezas del Cóndor escondidas en el Valle Abierto. Juntalas antes de que caiga el sol.',stars:{left:[0,45,70]},reward:3200,gift:'engine',
   shots:['aerea','interior','helicoptero'],
   intro:[['tano','El mapa tiene cinco cruces en el valle. Son sus marcas.'],['viejo','Cada pieza del Cóndor está donde gané una carrera.'],['tano','Típico de tu viejo. Hasta para esconder cosas era cabulero.']],
   during:{inicio:[['tano','La primera marca está pasando la loma. Dale.']],poco_tiempo:[['tano','¡Se viene la noche, apurá!']]},
   win:[['tano','Cinco piezas. Motor, caja y hasta el volante original.']],lose:[['tano','Se hizo de noche. Mañana seguimos buscando.']]},
  {id:'c4m2',title:'El galpón de Don Aldo',type:'estacionar',map:'parking',sky:'dusk',ai:0,
   goal:'Meté el auto en el galpón de Don Aldo sin tocar nada: atrás van las piezas del Cóndor.',stars:{park:[0,26,18]},reward:3000,
   shots:['aerea','capo','interior'],
   intro:[['tano','Don Aldo nos presta el galpón. Es angosto, eh.'],['aldo','Si me rayás la puerta, la pintás vos.'],['tano','Metelo despacio, que atrás van las piezas.']],
   during:{},
   win:[['aldo','Adentro y sin un rayón. Este pibe me gusta.'],['tano','Esta noche armamos el Cóndor.']],lose:[['aldo','¡Mi puerta! Probá de nuevo, pibe.']]},
  {id:'c4m3',title:'El Tanque',type:'escape',map:'quarryRev',seg:[0.02,0.72],sky:'sunset',ai:1,boss:'El Tanque',hunterCar:'truck',hunterK:1.25,
   goal:'Alguien le avisó a Salvatierra. Un camión Dakar de diez toneladas te quiere aplastar en la cantera.',stars:{hp:[1,50,80]},reward:4500,gift:'brakes',
   shots:['persecucion_cerca','de_frente','dos_autos','interior'],
   intro:[['tano','Alguien le avisó a Salvatierra. Viene un camión.'],['tanque','Correa. Bajate del auto.'],['tanque','Te voy a aplastar como a una lata.'],['tano','Diez toneladas. En las curvas es lento. Usalas.']],
   during:{rival_cerca:[['tanque','Te veo.']],dano50:[['tano','¡Un golpe más de ese bicho y volamos!']],mitad:[['tano','Se queda en las curvas. ¡Bien!']]},
   win:[['tanque','La próxima no te escapás.'],['tano','Lo dejamos atascado en la tierra roja.']],lose:[['tanque','Aplastado.']]},
  {id:'c4m4',title:'La caja del Cóndor',type:'contrarreloj',map:'lake',laps:1,sky:'dusk',ai:0,
   goal:'Don Aldo montó la caja de cambios del Cóndor en tu auto. Una vuelta al lago para probarla.',stars:{time:[125,108,98]},reward:4000,
   shots:['interior','capo','costado_pista'],
   intro:[['tano','Aldo le puso la caja del Cóndor a tu auto.'],['tano','Una vuelta al lago. Quiero ver si aguanta.'],['viejo','Si la caja canta en quinta, está perfecta.']],
   during:{inicio:[['tano','Escuchá los cambios. ¿Oís cómo entran?']],tiempo_mal:[['tano','Apurá, que el reloj no espera a nadie.']]},
   win:[['tano','La caja es una joya. Tu viejo era un genio.']],lose:[['tano','Todavía no la entendemos. Otra vuelta.']]}]},
];
export const MISSIONS=CHAPTERS.flatMap(c=>c.missions.map((m,i)=>({...m,chapter:c.n,num:i+1})));
export const MISSION_BY_ID=Object.fromEntries(MISSIONS.map(m=>[m.id,m]));
