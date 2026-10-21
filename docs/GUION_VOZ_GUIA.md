# Guion de la voz del Modo de prueba (guía de Claudio)

Generado por `python3 tools/audio/guide_voice_todo.py --md` desde `godot/game/data/guide_script.json`: **si cambiás un texto, cambialo en el JSON** y volvé a generar este archivo.

## Cómo funciona

- Cada línea de abajo se muestra como **subtítulo** (abajo en el medio jugando; a la derecha en los menús y la pausa) con el nombre «🎓 CLAUDIO».
- Si existe su **audio** en `godot/game/audio/guide/<idioma>/<id>.ogg` (también `.mp3` o `.wav`), se escucha con la voz mientras se ve el subtítulo. El subtítulo dura lo que dura el audio.
- **Sin audio no pasa nada malo:** se ve sólo el texto. Se pueden ir sumando grabaciones de a poco, sin tocar código.
- Si falta el audio en un idioma (en, pt, fr, it, de) se usa el de `es/`; si no hay tampoco, queda el subtítulo (traducido).
- Cada línea se dice **una sola vez por sesión** (salvo que el jugador la vuelva a provocar, p. ej. elegir otra vez un auto en el armado). Si el jugador toca algo mientras Claudio habla, la línea nueva corta la vieja.
- El jugador elige cómo escucharla con el botón **GUÍA** (🔊 voz y texto · 💬 sólo texto · 🔇 apagada); se guarda en el perfil (`guideMode`).

## Cómo grabar

1. Un archivo por línea, con **exactamente** el nombre de la columna «archivo» (`welcome.ogg`, `car_gt.ogg`…). Formato recomendado: **OGG Vorbis, mono, 44,1 kHz, calidad 4–5** (unos 20–60 KB por línea; todas pesan ~2 MB). Sirve también MP3 o WAV.
2. Poné los archivos en `godot/game/audio/guide/es/` (español). Para otro idioma, en `godot/game/audio/guide/en/`, `pt/`, `fr/`, `it/` o `de/` con los mismos nombres.
3. Verificá qué falta: `python3 tools/audio/guide_voice_todo.py` (o `--lang en`). Para pegar todos los textos en un programa de voz: `python3 tools/audio/guide_voice_todo.py --txt es`.
4. Subí los archivos al repositorio (commit y push). No hay que cambiar nada más: el APK nuevo los trae y la voz suena sola.
5. Tono: cercano y tranquilo, como un instructor que acompaña; frases cortas; no hace falta leer los símbolos ni los emojis. Que el volumen de todas las líneas sea parecido.

## Líneas del guion (español)

| archivo | cuándo se dice | texto |
|---|---|---|
| `welcome.ogg` | Pantalla de bienvenida (antes de entrar) | Hola, soy Claudio, tu guía. Este es el modo de prueba: un lugar para conocer el auto, ajustar el reglaje y hacer drift sin ir a una carrera. Queda siempre en el inicio, así que volvé cuando quieras. Podés leer la guía o ir directo a la prueba. |
| `welcome_first.ogg` | Primera vez que se juega: bienvenida al llegar al inicio (el juego lo manda acá una sola vez) | ¡Bienvenido a Dream Racing! Soy Claudio, tu guía. Antes de salir, pasemos por el modo de prueba: un lugar para conocer el juego, reglar tu auto y probar cosas sin ir a una carrera. Después queda siempre en el menú. Podés leer la guía o ir directo a la prueba. |
| `guide_pages.ogg` | Al abrir las hojas de la guía | Con las flechas pasás las hojas: suspensión, tracción, frenos, cámaras, volante y drift. Cuando quieras, volvé y entrá a la prueba. |
| `setup_welcome.ogg` | Pantalla de armado de la prueba | Elegí con qué auto vas a probar, el nivel de simulación y qué querés hacer: drift o carrera. |
| `car_pickup.ogg` | Elegir la camioneta | La camioneta: alta y pesada. Es ideal para sentir la suspensión en los lomos de burro y en la tierra. |
| `car_gt.ogg` | Elegir el GT | El GT: equilibrado y estable. Un auto rápido de calle para aprender el reglaje. |
| `car_classic.ogg` | Elegir el clásico | El clásico: poco agarre y mucho carácter. Se desliza fácil, así que es muy divertido para el drift. |
| `car_super.ogg` | Elegir el superdeportivo | El superdeportivo: muchísima potencia. Con simulación total hay que tratarlo con cuidado. |
| `car_mine.ogg` | Elegir «mi auto» (el del garaje) | Vas a probar con tu auto, con las piezas y el reglaje que ya tiene. Lo que ajustes en la prueba no se guarda: para dejarlo fijo, aplicalo en el taller. |
| `sim_arcade.ogg` | Elegir Arcade | Arcade: ABS, control de tracción y estabilidad altos, y el volante gira poco: tres cuartos de vuelta de tope a tope. El auto te perdona casi todo. |
| `sim_mid.ogg` | Elegir Intermedio | Intermedio: ayudas medias. Un manejo equilibrado, entre el arcade y el simulador. |
| `sim_pro.ogg` | Elegir Simulador total | Simulador total: sin ayudas, y el volante de la pantalla pide vueltas de verdad, como uno real. Más difícil, pero muy realista. |
| `sim_custom.ogg` | Elegir Personalizado | Personalizado: elegís cada ayuda y cuánto querés que gire el volante, desde tres cuartos de vuelta hasta tres vueltas de tope a tope. |
| `mode_drift.ogg` | Elegir el modo Drift | Drift: una plaza grande con conos y cuatro autos haciendo drift solos. Podés sumar puntos o derrapar libre. |
| `mode_race.ogg` | Elegir el modo Carrera | Carrera: una vuelta contrarreloj por puertas. Elegí el camino de tierra por detrás de la ciudad o la pista entre los edificios. |
| `score_points.ogg` | Drift por puntos | Con puntos: cada derrape suma según el ángulo y la velocidad, y cuanto más largo, mejor el multiplicador. |
| `score_free.ogg` | Drift libre | Libre: sin puntos ni apuro. Sólo vos, el auto y el ángulo. |
| `loop_dirt.ogg` | Circuito de tierra | El camino de tierra: da toda la vuelta por atrás de la ciudad y vuelve al playón por el otro lado. |
| `loop_urban.ogg` | Circuito entre los edificios | Entre los edificios: una vuelta por las calles de la ciudad, con esquinas cerradas y una rotonda. |
| `lab_on.ogg` | Ayuda de reglaje: sí | Con la ayuda de reglaje vas a ver el menú de reglajes en la pausa: suspensión, tracción, frenos y más. |
| `lab_off.ogg` | Ayuda de reglaje: no | Sin ayuda de reglaje el auto va como viene de fábrica. Igual podés cambiar el nivel de simulación desde la pausa. |
| `gfx.ogg` | Botón de calidad gráfica | Si el juego te anda justo, bajá la calidad gráfica desde acá. Podés volver a medirla cuando quieras. |
| `start.ogg` | Al estar todo elegido | Cuando estés listo, tocá empezar la prueba. Podés salir y volver cuando quieras: queda en el inicio. |
| `test_welcome.ogg` | Al largar | Ya estás en la pista. Manejá un rato para entrar en calor. Con la pausa abrís los reglajes y la guía. |
| `test_try_drift.ogg` | Pasaron unos segundos sin derrapar (drift) | Probá hacer un drift: acelerá, girá el volante y tirá del freno de mano, el botón H, para soltar la cola. |
| `test_pause.ogg` | Al abrir la pausa | Esta es la pausa de la prueba. Podés cambiar el nivel de simulación, abrir los reglajes, mirar la guía o salir de la prueba. |
| `test_drift_first.ogg` | Primer derrape | ¡Eso es drift! Cuanto más ángulo y más velocidad, más puntos. Si chocás, perdés el derrape. |
| `test_bumps.ogg` | Al llegar a los lomos de burro | Estos son lomos de burro. Pasalos a distintas velocidades y fijate cómo trabaja la suspensión. |
| `test_fuel_corner.ogg` | Al llegar a la esquina de la nafta | Esta es la esquina de la nafta. Frená adentro del cuadrado verde y el tanque se carga solo. |
| `test_refuel.ogg` | Empieza a cargar | Cargando nafta. Quedate quieto un momento. |
| `test_fuel_full.ogg` | Tanque lleno | Tanque lleno. Ya podés seguir probando. |
| `test_fuel_low.ogg` | Poca nafta | Te queda poca nafta. Buscá la esquina verde. |
| `test_fuel_empty.ogg` | Sin nafta | Te quedaste sin nafta. El auto no acelera: llevalo al cuadrado verde o reiniciá desde la pausa. |
| `race_start.ogg` | Largada de la carrera | Pasá por las puertas en orden. Te marco la próxima con un faro verde. Cada vuelta se mide. |
| `test_lap_first.ogg` | Primera vuelta | Primera vuelta completa. A ver si la mejorás. |
| `test_lap_done.ogg` | Otras vueltas | Otra vuelta. Fijate si bajaste el tiempo. |
| `cam_onboard.ogg` | Cámara onboard (casco) | Esta es la cámara onboard: ves desde el casco del piloto. Es la más realista. |
| `cam_chase.ogg` | Cámaras de persecución | Cámara de persecución: el auto visto desde atrás. Cambiá la distancia con el botón de cámara. |
| `cam_aerial.ogg` | Cámara aérea | Cámara aérea: ideal para ver el trazado completo de un derrape. |
| `cam_free.ogg` | Cámara libre | Cámara libre: movela con el dedo y acercá con dos dedos. |
| `cam_rear.ogg` | Cámara interior | Cámara interior, atrás del piloto: ves el tablero, el volante y las manos. |
| `cam_hood.ogg` | Cámara de capó | Cámara de capó: se ve la trompa del auto delante tuyo. |
| `cam_bumper.ogg` | Cámara de paragolpes | Cámara de paragolpes: la más baja y la que más sensación de velocidad da. |
| `lab_open.ogg` | Al abrir los reglajes | Acá podés modificar lo que quieras del auto: potencia, agarre, suspensión, frenos, transmisión y aerodinámica. Cada cambio se aplica enseguida: probalo y volvé. |
| `lab_motor.ogg` | Solapa Motor | Motor: la potencia, el peso y la resistencia al aire. Menos peso y más potencia aceleran más, pero las ruedas patinan. |
| `lab_agarre.ogg` | Solapa Agarre | Agarre: gomas, presiones y alineación. Más agarre atrás frena el derrape; menos agarre atrás lo facilita. |
| `lab_susp.ogg` | Solapa Suspensión | Suspensión: la altura, los resortes, los amortiguadores y las barras. Los resortes duros responden rápido; los blandos absorben mejor los lomos de burro. |
| `lab_frenos.ogg` | Solapa Frenos | Frenos: el reparto entre adelante y atrás, la presión y la dirección. Más freno atrás ayuda a meter el auto de costado. |
| `lab_trans.ogg` | Solapa Transmisión | Transmisión: cómo se reparte la tracción entre adelante y atrás, el diferencial y la relación final. La tracción trasera es la reina del drift. |
| `lab_aero.ogg` | Solapa Aerodinámica | Aerodinámica: la carga adelante y atrás. Aprieta el auto al piso a alta velocidad, pero le quita punta. |
| `sim_changed.ogg` | Cambio de nivel de simulación en la pausa | Cambiaste el nivel de simulación. Se aplica enseguida. |
| `wheel_real.ogg` | Volante real activo | Con el volante real tenés que girar de verdad con el dedo: hasta tres vueltas de tope a tope. |
| `exit_done.ogg` | Al salir de la prueba (sólo la primera vez que se hace) | Listo, volvemos al menú. El modo de prueba queda en el inicio: volvé cuando quieras reglar tu auto o probar algo sin ir a una carrera. |

## English (subtítulos y guion para grabar en ese idioma)

| archivo | texto |
|---|---|
| `welcome.ogg` | Hi, I'm Claudio, your guide. This is test mode: a place to get to know the car, tune the setup and drift without going to a race. It always stays on the home screen, so come back whenever you like. You can read the guide or go straight to the test. |
| `welcome_first.ogg` | Welcome to Dream Racing! I'm Claudio, your guide. Before you head out, let's stop by test mode: a place to get to know the game, tune your car and try things without going to a race. After that it always stays in the menu. You can read the guide or go straight to the test. |
| `guide_pages.ogg` | Use the arrows to flip the pages: suspension, traction, brakes, cameras, steering wheel and drift. Whenever you like, come back and enter the test. |
| `setup_welcome.ogg` | Choose which car you'll test with, the simulation level and what you want to do: drift or race. |
| `car_pickup.ogg` | The pickup: tall and heavy. Ideal for feeling the suspension on the speed bumps and on dirt. |
| `car_gt.ogg` | The GT: balanced and stable. A fast road car to learn the setup. |
| `car_classic.ogg` | The classic: little grip and lots of character. It slides easily, so it's great fun for drifting. |
| `car_super.ogg` | The supercar: huge power. In full simulation you have to handle it with care. |
| `car_mine.ogg` | You'll test with your own car, with the parts and setup it already has. Whatever you adjust in the test isn't saved: to make it permanent, apply it in the workshop. |
| `sim_arcade.ogg` | Arcade: high ABS, traction control and stability, and the steering wheel turns only a little: three quarters of a turn lock to lock. The car forgives almost everything. |
| `sim_mid.ogg` | Intermediate: medium assists. A balanced drive, between arcade and the simulator. |
| `sim_pro.ogg` | Full simulator: no assists, and the on-screen wheel asks for real turns, like a real one. Harder, but very realistic. |
| `sim_custom.ogg` | Custom: you pick each assist and how far you want the wheel to turn, from three quarters of a turn up to three full turns lock to lock. |
| `mode_drift.ogg` | Drift: a big plaza with cones and four cars drifting on their own. You can score points or just slide freely. |
| `mode_race.ogg` | Race: a time-trial lap through gates. Pick the dirt road behind the city or the track between the buildings. |
| `score_points.ogg` | With points: every drift scores according to angle and speed, and the longer it is, the better the multiplier. |
| `score_free.ogg` | Free: no points and no rush. Just you, the car and the angle. |
| `loop_dirt.ogg` | The dirt road: it goes all the way around behind the city and returns to the plaza from the other side. |
| `loop_urban.ogg` | Between the buildings: a lap through the city streets, with tight corners and a roundabout. |
| `lab_on.ogg` | With tuning help on, you'll see the tuning menu in the pause screen: suspension, traction, brakes and more. |
| `lab_off.ogg` | Without tuning help the car stays as it comes from the factory. You can still change the simulation level from the pause screen. |
| `gfx.ogg` | If the game runs a bit tight, lower the graphics quality from here. You can measure it again whenever you like. |
| `start.ogg` | When you're ready, tap start the test. You can leave and come back whenever you like: it stays on the home screen. |
| `test_welcome.ogg` | You're on the track. Drive around for a while to warm up. With the pause button you open the tuning and the guide. |
| `test_try_drift.ogg` | Try a drift: accelerate, turn the wheel and pull the handbrake, the H button, to kick the tail out. |
| `test_pause.ogg` | This is the test pause. You can change the simulation level, open the tuning, look at the guide or leave the test. |
| `test_drift_first.ogg` | That's drifting! The more angle and speed, the more points. If you crash, you lose the drift. |
| `test_bumps.ogg` | These are speed bumps. Go over them at different speeds and notice how the suspension works. |
| `test_fuel_corner.ogg` | This is the fuel corner. Stop inside the green square and the tank refills by itself. |
| `test_refuel.ogg` | Refueling. Stay still for a moment. |
| `test_fuel_full.ogg` | Tank full. You can keep testing. |
| `test_fuel_low.ogg` | You're low on fuel. Look for the green corner. |
| `test_fuel_empty.ogg` | You ran out of fuel. The car won't accelerate: take it to the green square or restart from the pause screen. |
| `race_start.ogg` | Go through the gates in order. I'll mark the next one with a green beam. Every lap is timed. |
| `test_lap_first.ogg` | First lap complete. Let's see if you can beat it. |
| `test_lap_done.ogg` | Another lap. See if you brought the time down. |
| `cam_onboard.ogg` | This is the onboard camera: you see from the driver's helmet. It's the most realistic one. |
| `cam_chase.ogg` | Chase camera: the car seen from behind. Change the distance with the camera button. |
| `cam_aerial.ogg` | Aerial camera: ideal to see the whole path of a drift. |
| `cam_free.ogg` | Free camera: move it with your finger and zoom with two fingers. |
| `cam_rear.ogg` | Interior camera, behind the driver: you see the dashboard, the steering wheel and the hands. |
| `cam_hood.ogg` | Hood camera: you see the nose of the car in front of you. |
| `cam_bumper.ogg` | Bumper camera: the lowest one, and the one that gives the most sense of speed. |
| `lab_open.ogg` | Here you can change whatever you want on the car: power, grip, suspension, brakes, transmission and aerodynamics. Every change applies right away: try it and come back. |
| `lab_motor.ogg` | Engine: power, weight and air resistance. Less weight and more power accelerate harder, but the wheels spin. |
| `lab_agarre.ogg` | Grip: tires, pressures and alignment. More grip at the rear stops the drift; less grip at the rear makes it easier. |
| `lab_susp.ogg` | Suspension: ride height, springs, dampers and bars. Stiff springs respond quickly; soft ones absorb speed bumps better. |
| `lab_frenos.ogg` | Brakes: the front-to-rear split, pressure and steering. More rear braking helps get the car sideways. |
| `lab_trans.ogg` | Transmission: how the traction is split between front and rear, the differential and the final drive. Rear-wheel drive is the queen of drifting. |
| `lab_aero.ogg` | Aerodynamics: the downforce at the front and rear. It presses the car to the ground at high speed, but costs top speed. |
| `sim_changed.ogg` | You changed the simulation level. It applies right away. |
| `wheel_real.ogg` | With the real wheel you have to turn it for real with your finger: up to three turns lock to lock. |
| `exit_done.ogg` | Done, back to the menu. Test mode stays on the home screen: come back whenever you want to tune your car or try something without going to a race. |

## Português (subtítulos y guion para grabar en ese idioma)

| archivo | texto |
|---|---|
| `welcome.ogg` | Oi, eu sou o Claudio, o seu guia. Este é o modo de teste: um lugar para conhecer o carro, ajustar a regulagem e fazer drift sem ir a uma corrida. Ele fica sempre na tela inicial, então volte quando quiser. Você pode ler o guia ou ir direto para o teste. |
| `welcome_first.ogg` | Bem-vindo ao Dream Racing! Eu sou o Claudio, o seu guia. Antes de sair, vamos passar pelo modo de teste: um lugar para conhecer o jogo, regular o seu carro e experimentar coisas sem ir a uma corrida. Depois ele fica sempre no menu. Você pode ler o guia ou ir direto para o teste. |
| `guide_pages.ogg` | Com as setas você passa as páginas: suspensão, tração, freios, câmeras, volante e drift. Quando quiser, volte e entre no teste. |
| `setup_welcome.ogg` | Escolha com qual carro você vai testar, o nível de simulação e o que quer fazer: drift ou corrida. |
| `car_pickup.ogg` | A caminhonete: alta e pesada. Ideal para sentir a suspensão nas lombadas e na terra. |
| `car_gt.ogg` | O GT: equilibrado e estável. Um carro de rua rápido para aprender a regulagem. |
| `car_classic.ogg` | O clássico: pouca aderência e muito caráter. Ele escorrega fácil, por isso é muito divertido para o drift. |
| `car_super.ogg` | O superesportivo: muita potência. Na simulação total é preciso tratá-lo com cuidado. |
| `car_mine.ogg` | Você vai testar com o seu carro, com as peças e a regulagem que ele já tem. O que você ajustar no teste não é salvo: para deixar fixo, aplique na oficina. |
| `sim_arcade.ogg` | Arcade: ABS, controle de tração e estabilidade altos, e o volante gira pouco: três quartos de volta de batente a batente. O carro perdoa quase tudo. |
| `sim_mid.ogg` | Intermediário: ajudas médias. Uma condução equilibrada, entre o arcade e o simulador. |
| `sim_pro.ogg` | Simulador total: sem ajudas, e o volante da tela pede voltas de verdade, como um real. Mais difícil, mas muito realista. |
| `sim_custom.ogg` | Personalizado: você escolhe cada ajuda e o quanto quer que o volante gire, de três quartos de volta até três voltas de batente a batente. |
| `mode_drift.ogg` | Drift: uma praça grande com cones e quatro carros fazendo drift sozinhos. Você pode somar pontos ou derrapar livremente. |
| `mode_race.ogg` | Corrida: uma volta contra o relógio por portões. Escolha a estrada de terra atrás da cidade ou a pista entre os prédios. |
| `score_points.ogg` | Com pontos: cada derrapagem soma conforme o ângulo e a velocidade, e quanto mais longa, melhor o multiplicador. |
| `score_free.ogg` | Livre: sem pontos nem pressa. Só você, o carro e o ângulo. |
| `loop_dirt.ogg` | A estrada de terra: dá a volta toda por trás da cidade e volta à praça pelo outro lado. |
| `loop_urban.ogg` | Entre os prédios: uma volta pelas ruas da cidade, com esquinas fechadas e uma rotatória. |
| `lab_on.ogg` | Com a ajuda de regulagem você vê o menu de regulagens na pausa: suspensão, tração, freios e mais. |
| `lab_off.ogg` | Sem a ajuda de regulagem o carro vai como sai de fábrica. Mesmo assim você pode mudar o nível de simulação na pausa. |
| `gfx.ogg` | Se o jogo estiver rodando no limite, diminua a qualidade gráfica por aqui. Você pode medir de novo quando quiser. |
| `start.ogg` | Quando estiver pronto, toque em começar o teste. Você pode sair e voltar quando quiser: ele fica na tela inicial. |
| `test_welcome.ogg` | Você já está na pista. Dirija um pouco para esquentar. Na pausa você abre as regulagens e o guia. |
| `test_try_drift.ogg` | Experimente um drift: acelere, gire o volante e puxe o freio de mão, o botão H, para soltar a traseira. |
| `test_pause.ogg` | Esta é a pausa do teste. Você pode mudar o nível de simulação, abrir as regulagens, ver o guia ou sair do teste. |
| `test_drift_first.ogg` | Isso é drift! Quanto mais ângulo e velocidade, mais pontos. Se você bater, perde a derrapagem. |
| `test_bumps.ogg` | Estas são lombadas. Passe por elas em velocidades diferentes e veja como a suspensão trabalha. |
| `test_fuel_corner.ogg` | Esta é a esquina do combustível. Pare dentro do quadrado verde e o tanque se enche sozinho. |
| `test_refuel.ogg` | Abastecendo. Fique parado um instante. |
| `test_fuel_full.ogg` | Tanque cheio. Você já pode continuar testando. |
| `test_fuel_low.ogg` | Está acabando o combustível. Procure a esquina verde. |
| `test_fuel_empty.ogg` | O combustível acabou. O carro não acelera: leve-o até o quadrado verde ou reinicie pela pausa. |
| `race_start.ogg` | Passe pelos portões em ordem. Eu marco o próximo com um farol verde. Cada volta é cronometrada. |
| `test_lap_first.ogg` | Primeira volta completa. Vamos ver se você consegue melhorar. |
| `test_lap_done.ogg` | Mais uma volta. Veja se baixou o tempo. |
| `cam_onboard.ogg` | Esta é a câmera onboard: você vê do capacete do piloto. É a mais realista. |
| `cam_chase.ogg` | Câmera de perseguição: o carro visto por trás. Mude a distância com o botão de câmera. |
| `cam_aerial.ogg` | Câmera aérea: ideal para ver o traçado completo de uma derrapagem. |
| `cam_free.ogg` | Câmera livre: mova com o dedo e aproxime com dois dedos. |
| `cam_rear.ogg` | Câmera interna, atrás do piloto: você vê o painel, o volante e as mãos. |
| `cam_hood.ogg` | Câmera do capô: você vê a frente do carro à sua frente. |
| `cam_bumper.ogg` | Câmera do para-choque: a mais baixa e a que dá mais sensação de velocidade. |
| `lab_open.ogg` | Aqui você pode modificar o que quiser no carro: potência, aderência, suspensão, freios, transmissão e aerodinâmica. Cada mudança é aplicada na hora: teste e volte. |
| `lab_motor.ogg` | Motor: a potência, o peso e a resistência do ar. Menos peso e mais potência aceleram mais, mas as rodas patinam. |
| `lab_agarre.ogg` | Aderência: pneus, pressões e alinhamento. Mais aderência atrás segura a derrapagem; menos aderência atrás a facilita. |
| `lab_susp.ogg` | Suspensão: a altura, as molas, os amortecedores e as barras. As molas duras respondem rápido; as macias absorvem melhor as lombadas. |
| `lab_frenos.ogg` | Freios: a distribuição entre a frente e a traseira, a pressão e a direção. Mais freio atrás ajuda a colocar o carro de lado. |
| `lab_trans.ogg` | Transmissão: como a tração se divide entre a frente e a traseira, o diferencial e a relação final. A tração traseira é a rainha do drift. |
| `lab_aero.ogg` | Aerodinâmica: a carga na frente e atrás. Aperta o carro contra o piso em alta velocidade, mas tira velocidade final. |
| `sim_changed.ogg` | Você mudou o nível de simulação. Ele é aplicado na hora. |
| `wheel_real.ogg` | Com o volante real você tem que girar de verdade com o dedo: até três voltas de batente a batente. |
| `exit_done.ogg` | Pronto, voltamos ao menu. O modo de teste fica na tela inicial: volte quando quiser regular o seu carro ou experimentar algo sem ir a uma corrida. |

## Français (subtítulos y guion para grabar en ese idioma)

| archivo | texto |
|---|---|
| `welcome.ogg` | Salut, je suis Claudio, ton guide. Voici le mode essai : un endroit pour découvrir la voiture, ajuster le réglage et drifter sans aller en course. Il reste toujours sur l'accueil, alors reviens quand tu veux. Tu peux lire le guide ou aller directement à l'essai. |
| `welcome_first.ogg` | Bienvenue dans Dream Racing ! Je suis Claudio, ton guide. Avant de partir, passons par le mode essai : un endroit pour découvrir le jeu, régler ta voiture et tester des choses sans aller en course. Ensuite, il reste toujours dans le menu. Tu peux lire le guide ou aller directement à l'essai. |
| `guide_pages.ogg` | Avec les flèches tu tournes les pages : suspension, traction, freins, caméras, volant et drift. Quand tu veux, reviens et entre dans l'essai. |
| `setup_welcome.ogg` | Choisis avec quelle voiture tu vas essayer, le niveau de simulation et ce que tu veux faire : drift ou course. |
| `car_pickup.ogg` | Le pick-up : haut et lourd. Idéal pour sentir la suspension sur les dos d'âne et sur la terre. |
| `car_gt.ogg` | La GT : équilibrée et stable. Une voiture de route rapide pour apprendre le réglage. |
| `car_classic.ogg` | La classique : peu d'adhérence et beaucoup de caractère. Elle glisse facilement, donc elle est très amusante pour le drift. |
| `car_super.ogg` | La supercar : une puissance énorme. En simulation totale, il faut la manier avec précaution. |
| `car_mine.ogg` | Tu vas essayer avec ta voiture, avec les pièces et le réglage qu'elle a déjà. Ce que tu ajustes pendant l'essai n'est pas enregistré : pour le garder, applique-le à l'atelier. |
| `sim_arcade.ogg` | Arcade : ABS, antipatinage et stabilité élevés, et le volant tourne peu : trois quarts de tour d'une butée à l'autre. La voiture pardonne presque tout. |
| `sim_mid.ogg` | Intermédiaire : aides moyennes. Une conduite équilibrée, entre l'arcade et le simulateur. |
| `sim_pro.ogg` | Simulateur total : sans aides, et le volant à l'écran demande de vrais tours, comme un vrai. Plus difficile, mais très réaliste. |
| `sim_custom.ogg` | Personnalisé : tu choisis chaque aide et de combien tu veux que le volant tourne, de trois quarts de tour jusqu'à trois tours d'une butée à l'autre. |
| `mode_drift.ogg` | Drift : une grande place avec des cônes et quatre voitures qui driftent toutes seules. Tu peux marquer des points ou glisser librement. |
| `mode_race.ogg` | Course : un tour chronométré par des portes. Choisis le chemin de terre derrière la ville ou la piste entre les immeubles. |
| `score_points.ogg` | Avec points : chaque drift rapporte selon l'angle et la vitesse, et plus il est long, meilleur est le multiplicateur. |
| `score_free.ogg` | Libre : sans points ni pression. Juste toi, la voiture et l'angle. |
| `loop_dirt.ogg` | Le chemin de terre : il fait tout le tour derrière la ville et revient sur la place par l'autre côté. |
| `loop_urban.ogg` | Entre les immeubles : un tour par les rues de la ville, avec des virages serrés et un rond-point. |
| `lab_on.ogg` | Avec l'aide au réglage, tu verras le menu de réglages dans la pause : suspension, traction, freins et plus. |
| `lab_off.ogg` | Sans l'aide au réglage, la voiture reste comme à la sortie d'usine. Tu peux quand même changer le niveau de simulation depuis la pause. |
| `gfx.ogg` | Si le jeu tourne juste, baisse la qualité graphique d'ici. Tu peux la mesurer de nouveau quand tu veux. |
| `start.ogg` | Quand tu es prêt, touche commencer l'essai. Tu peux quitter et revenir quand tu veux : il reste sur l'accueil. |
| `test_welcome.ogg` | Tu es sur la piste. Roule un peu pour t'échauffer. Avec la pause, tu ouvres les réglages et le guide. |
| `test_try_drift.ogg` | Essaie un drift : accélère, tourne le volant et tire le frein à main, le bouton H, pour lâcher l'arrière. |
| `test_pause.ogg` | Voici la pause de l'essai. Tu peux changer le niveau de simulation, ouvrir les réglages, regarder le guide ou quitter l'essai. |
| `test_drift_first.ogg` | Ça, c'est du drift ! Plus d'angle et de vitesse, plus de points. Si tu tapes, tu perds le drift. |
| `test_bumps.ogg` | Voici des dos d'âne. Passe-les à différentes vitesses et observe comment la suspension travaille. |
| `test_fuel_corner.ogg` | Voici le coin de l'essence. Arrête-toi dans le carré vert et le réservoir se remplit tout seul. |
| `test_refuel.ogg` | Remplissage en cours. Reste immobile un instant. |
| `test_fuel_full.ogg` | Réservoir plein. Tu peux continuer à essayer. |
| `test_fuel_low.ogg` | Il te reste peu d'essence. Cherche le coin vert. |
| `test_fuel_empty.ogg` | Tu n'as plus d'essence. La voiture n'accélère plus : emmène-la jusqu'au carré vert ou recommence depuis la pause. |
| `race_start.ogg` | Passe par les portes dans l'ordre. Je te marque la prochaine avec un faisceau vert. Chaque tour est chronométré. |
| `test_lap_first.ogg` | Premier tour terminé. Voyons si tu peux faire mieux. |
| `test_lap_done.ogg` | Encore un tour. Regarde si tu as amélioré ton temps. |
| `cam_onboard.ogg` | Voici la caméra embarquée : tu vois depuis le casque du pilote. C'est la plus réaliste. |
| `cam_chase.ogg` | Caméra de poursuite : la voiture vue de derrière. Change la distance avec le bouton de caméra. |
| `cam_aerial.ogg` | Caméra aérienne : idéale pour voir toute la trajectoire d'un drift. |
| `cam_free.ogg` | Caméra libre : déplace-la avec le doigt et zoome avec deux doigts. |
| `cam_rear.ogg` | Caméra intérieure, derrière le pilote : tu vois le tableau de bord, le volant et les mains. |
| `cam_hood.ogg` | Caméra de capot : tu vois le nez de la voiture devant toi. |
| `cam_bumper.ogg` | Caméra de pare-chocs : la plus basse et celle qui donne le plus de sensation de vitesse. |
| `lab_open.ogg` | Ici tu peux modifier ce que tu veux sur la voiture : puissance, adhérence, suspension, freins, transmission et aérodynamique. Chaque changement s'applique tout de suite : essaie et reviens. |
| `lab_motor.ogg` | Moteur : la puissance, le poids et la résistance de l'air. Moins de poids et plus de puissance accélèrent plus, mais les roues patinent. |
| `lab_agarre.ogg` | Adhérence : pneus, pressions et géométrie. Plus d'adhérence à l'arrière freine le drift ; moins d'adhérence à l'arrière le facilite. |
| `lab_susp.ogg` | Suspension : la hauteur, les ressorts, les amortisseurs et les barres. Les ressorts durs répondent vite ; les souples absorbent mieux les dos d'âne. |
| `lab_frenos.ogg` | Freins : la répartition avant-arrière, la pression et la direction. Plus de frein à l'arrière aide à mettre la voiture en travers. |
| `lab_trans.ogg` | Transmission : comment la traction se répartit entre l'avant et l'arrière, le différentiel et le rapport final. La propulsion est la reine du drift. |
| `lab_aero.ogg` | Aérodynamique : l'appui à l'avant et à l'arrière. Il plaque la voiture au sol à haute vitesse, mais lui enlève de la vitesse de pointe. |
| `sim_changed.ogg` | Tu as changé le niveau de simulation. Il s'applique tout de suite. |
| `wheel_real.ogg` | Avec le volant réel, tu dois vraiment le tourner avec le doigt : jusqu'à trois tours d'une butée à l'autre. |
| `exit_done.ogg` | C'est fait, retour au menu. Le mode essai reste sur l'accueil : reviens quand tu veux régler ta voiture ou tester quelque chose sans aller en course. |

## Italiano (subtítulos y guion para grabar en ese idioma)

| archivo | texto |
|---|---|
| `welcome.ogg` | Ciao, sono Claudio, la tua guida. Questa è la modalità prova: un posto per conoscere l'auto, regolare l'assetto e fare drift senza andare a una gara. Resta sempre nella schermata iniziale, quindi torna quando vuoi. Puoi leggere la guida o andare direttamente alla prova. |
| `welcome_first.ogg` | Benvenuto in Dream Racing! Sono Claudio, la tua guida. Prima di partire, passiamo dalla modalità prova: un posto per conoscere il gioco, regolare la tua auto e provare cose senza andare a una gara. Poi resta sempre nel menu. Puoi leggere la guida o andare direttamente alla prova. |
| `guide_pages.ogg` | Con le frecce sfogli le pagine: sospensioni, trazione, freni, camere, volante e drift. Quando vuoi, torna indietro ed entra nella prova. |
| `setup_welcome.ogg` | Scegli con quale auto provare, il livello di simulazione e cosa vuoi fare: drift o gara. |
| `car_pickup.ogg` | Il pick-up: alto e pesante. Ideale per sentire le sospensioni sui dossi e sullo sterrato. |
| `car_gt.ogg` | La GT: equilibrata e stabile. Un'auto stradale veloce per imparare l'assetto. |
| `car_classic.ogg` | La classica: poca aderenza e tanto carattere. Scivola facilmente, quindi è molto divertente per il drift. |
| `car_super.ogg` | La supersportiva: potenza enorme. Con la simulazione totale va trattata con cura. |
| `car_mine.ogg` | Proverai con la tua auto, con i pezzi e l'assetto che ha già. Quello che regoli nella prova non viene salvato: per renderlo definitivo, applicalo in officina. |
| `sim_arcade.ogg` | Arcade: ABS, controllo di trazione e stabilità alti, e il volante gira poco: tre quarti di giro da un fondo corsa all'altro. L'auto perdona quasi tutto. |
| `sim_mid.ogg` | Intermedio: aiuti medi. Una guida equilibrata, tra l'arcade e il simulatore. |
| `sim_pro.ogg` | Simulatore totale: senza aiuti, e il volante sullo schermo richiede giri veri, come uno reale. Più difficile, ma molto realistico. |
| `sim_custom.ogg` | Personalizzato: scegli ogni aiuto e quanto vuoi che giri il volante, da tre quarti di giro fino a tre giri da un fondo corsa all'altro. |
| `mode_drift.ogg` | Drift: una grande piazza con coni e quattro auto che fanno drift da sole. Puoi fare punti o derapare liberamente. |
| `mode_race.ogg` | Gara: un giro a cronometro attraverso le porte. Scegli la strada sterrata dietro la città o la pista tra i palazzi. |
| `score_points.ogg` | Con i punti: ogni derapata fa punti in base all'angolo e alla velocità, e più è lunga, migliore è il moltiplicatore. |
| `score_free.ogg` | Libero: niente punti e nessuna fretta. Solo tu, l'auto e l'angolo. |
| `loop_dirt.ogg` | La strada sterrata: fa tutto il giro dietro la città e torna alla piazza dall'altro lato. |
| `loop_urban.ogg` | Tra i palazzi: un giro per le strade della città, con curve strette e una rotonda. |
| `lab_on.ogg` | Con l'aiuto assetto vedrai il menu delle regolazioni nella pausa: sospensioni, trazione, freni e altro. |
| `lab_off.ogg` | Senza l'aiuto assetto l'auto resta com'è di fabbrica. Puoi comunque cambiare il livello di simulazione dalla pausa. |
| `gfx.ogg` | Se il gioco gira al limite, abbassa la qualità grafica da qui. Puoi misurarla di nuovo quando vuoi. |
| `start.ogg` | Quando sei pronto, tocca inizia la prova. Puoi uscire e tornare quando vuoi: resta nella schermata iniziale. |
| `test_welcome.ogg` | Sei in pista. Guida un po' per scaldarti. Con la pausa apri le regolazioni e la guida. |
| `test_try_drift.ogg` | Prova un drift: accelera, gira il volante e tira il freno a mano, il pulsante H, per far scivolare la coda. |
| `test_pause.ogg` | Questa è la pausa della prova. Puoi cambiare il livello di simulazione, aprire le regolazioni, guardare la guida o uscire dalla prova. |
| `test_drift_first.ogg` | Questo è drift! Più angolo e più velocità, più punti. Se sbatti, perdi la derapata. |
| `test_bumps.ogg` | Questi sono dossi. Passali a velocità diverse e osserva come lavorano le sospensioni. |
| `test_fuel_corner.ogg` | Questo è l'angolo della benzina. Fermati dentro il quadrato verde e il serbatoio si riempie da solo. |
| `test_refuel.ogg` | Rifornimento in corso. Resta fermo un momento. |
| `test_fuel_full.ogg` | Serbatoio pieno. Puoi continuare a provare. |
| `test_fuel_low.ogg` | Ti resta poca benzina. Cerca l'angolo verde. |
| `test_fuel_empty.ogg` | Sei rimasto senza benzina. L'auto non accelera: portala nel quadrato verde o riavvia dalla pausa. |
| `race_start.ogg` | Passa per le porte in ordine. Ti segno la prossima con un faro verde. Ogni giro viene cronometrato. |
| `test_lap_first.ogg` | Primo giro completo. Vediamo se riesci a migliorarlo. |
| `test_lap_done.ogg` | Un altro giro. Guarda se hai abbassato il tempo. |
| `cam_onboard.ogg` | Questa è la camera onboard: vedi dal casco del pilota. È la più realistica. |
| `cam_chase.ogg` | Camera inseguimento: l'auto vista da dietro. Cambia la distanza con il pulsante della camera. |
| `cam_aerial.ogg` | Camera aerea: ideale per vedere l'intera traiettoria di una derapata. |
| `cam_free.ogg` | Camera libera: muovila con il dito e fai zoom con due dita. |
| `cam_rear.ogg` | Camera interna, dietro il pilota: vedi il cruscotto, il volante e le mani. |
| `cam_hood.ogg` | Camera cofano: vedi il muso dell'auto davanti a te. |
| `cam_bumper.ogg` | Camera paraurti: la più bassa e quella che dà più sensazione di velocità. |
| `lab_open.ogg` | Qui puoi modificare quello che vuoi dell'auto: potenza, aderenza, sospensioni, freni, trasmissione e aerodinamica. Ogni modifica si applica subito: provala e torna. |
| `lab_motor.ogg` | Motore: la potenza, il peso e la resistenza dell'aria. Meno peso e più potenza accelerano di più, ma le ruote pattinano. |
| `lab_agarre.ogg` | Aderenza: gomme, pressioni e allineamento. Più aderenza dietro frena la derapata; meno aderenza dietro la facilita. |
| `lab_susp.ogg` | Sospensioni: l'altezza, le molle, gli ammortizzatori e le barre. Le molle dure rispondono in fretta; quelle morbide assorbono meglio i dossi. |
| `lab_frenos.ogg` | Freni: il bilanciamento tra avanti e dietro, la pressione e lo sterzo. Più freno dietro aiuta a mettere l'auto di traverso. |
| `lab_trans.ogg` | Trasmissione: come si ripartisce la trazione tra avanti e dietro, il differenziale e il rapporto finale. La trazione posteriore è la regina del drift. |
| `lab_aero.ogg` | Aerodinamica: il carico davanti e dietro. Schiaccia l'auto a terra ad alta velocità, ma toglie velocità di punta. |
| `sim_changed.ogg` | Hai cambiato il livello di simulazione. Si applica subito. |
| `wheel_real.ogg` | Con il volante reale devi girarlo davvero con il dito: fino a tre giri da un fondo corsa all'altro. |
| `exit_done.ogg` | Fatto, torniamo al menu. La modalità prova resta nella schermata iniziale: torna quando vuoi regolare la tua auto o provare qualcosa senza andare a una gara. |

## Deutsch (subtítulos y guion para grabar en ese idioma)

| archivo | texto |
|---|---|
| `welcome.ogg` | Hallo, ich bin Claudio, dein Guide. Das ist der Testmodus: ein Ort, um das Auto kennenzulernen, das Setup einzustellen und zu driften, ohne in ein Rennen zu gehen. Er bleibt immer im Startmenü, komm also zurück, wann du willst. Du kannst die Anleitung lesen oder gleich zum Test gehen. |
| `welcome_first.ogg` | Willkommen bei Dream Racing! Ich bin Claudio, dein Guide. Bevor du losfährst, schauen wir im Testmodus vorbei: ein Ort, um das Spiel kennenzulernen, dein Auto einzustellen und Dinge auszuprobieren, ohne in ein Rennen zu gehen. Danach bleibt er immer im Menü. Du kannst die Anleitung lesen oder gleich zum Test gehen. |
| `guide_pages.ogg` | Mit den Pfeilen blätterst du: Federung, Antrieb, Bremsen, Kameras, Lenkrad und Drift. Wenn du so weit bist, geh zurück und starte den Test. |
| `setup_welcome.ogg` | Wähle, mit welchem Auto du testest, die Simulationsstufe und was du machen willst: Driften oder Rennen. |
| `car_pickup.ogg` | Der Pickup: hoch und schwer. Ideal, um die Federung auf den Bodenschwellen und im Dreck zu spüren. |
| `car_gt.ogg` | Der GT: ausgewogen und stabil. Ein schneller Straßenwagen, um das Setup zu lernen. |
| `car_classic.ogg` | Der Klassiker: wenig Grip und viel Charakter. Er rutscht leicht und macht deshalb beim Driften richtig Spaß. |
| `car_super.ogg` | Der Supersportwagen: enorme Leistung. In der vollen Simulation musst du ihn mit Vorsicht behandeln. |
| `car_mine.ogg` | Du testest mit deinem eigenen Auto, mit den Teilen und dem Setup, die es schon hat. Was du im Test einstellst, wird nicht gespeichert: Um es dauerhaft zu machen, wende es in der Werkstatt an. |
| `sim_arcade.ogg` | Arcade: ABS, Traktionskontrolle und Stabilität sind hoch, und das Lenkrad dreht nur wenig: dreiviertel Umdrehung von Anschlag zu Anschlag. Das Auto verzeiht fast alles. |
| `sim_mid.ogg` | Mittel: mittlere Hilfen. Ein ausgewogenes Fahrgefühl zwischen Arcade und Simulator. |
| `sim_pro.ogg` | Voller Simulator: ohne Hilfen, und das Lenkrad auf dem Bildschirm verlangt echte Umdrehungen wie ein richtiges. Schwieriger, aber sehr realistisch. |
| `sim_custom.ogg` | Benutzerdefiniert: Du wählst jede Hilfe und wie weit sich das Lenkrad drehen soll, von dreiviertel Umdrehung bis zu drei Umdrehungen von Anschlag zu Anschlag. |
| `mode_drift.ogg` | Drift: ein großer Platz mit Pylonen und vier Autos, die von allein driften. Du kannst Punkte sammeln oder frei rutschen. |
| `mode_race.ogg` | Rennen: eine Zeitfahrrunde durch Tore. Wähle die Schotterstraße hinter der Stadt oder die Strecke zwischen den Gebäuden. |
| `score_points.ogg` | Mit Punkten: Jeder Drift bringt Punkte je nach Winkel und Geschwindigkeit, und je länger er dauert, desto besser der Multiplikator. |
| `score_free.ogg` | Frei: ohne Punkte und ohne Eile. Nur du, das Auto und der Winkel. |
| `loop_dirt.ogg` | Die Schotterstraße: Sie führt ganz um die Stadt herum und kommt von der anderen Seite zurück auf den Platz. |
| `loop_urban.ogg` | Zwischen den Gebäuden: eine Runde durch die Stadtstraßen, mit engen Kurven und einem Kreisverkehr. |
| `lab_on.ogg` | Mit der Setup-Hilfe siehst du im Pausenmenü die Einstellungen: Federung, Antrieb, Bremsen und mehr. |
| `lab_off.ogg` | Ohne Setup-Hilfe bleibt das Auto ab Werk. Die Simulationsstufe kannst du trotzdem im Pausenmenü ändern. |
| `gfx.ogg` | Wenn das Spiel knapp läuft, senke hier die Grafikqualität. Du kannst sie jederzeit neu messen. |
| `start.ogg` | Wenn du bereit bist, tippe auf Test starten. Du kannst jederzeit rausgehen und wiederkommen: Er bleibt im Startmenü. |
| `test_welcome.ogg` | Du bist auf der Strecke. Fahr dich ein bisschen warm. Mit der Pause öffnest du die Einstellungen und die Anleitung. |
| `test_try_drift.ogg` | Probier einen Drift: Gib Gas, dreh das Lenkrad und zieh die Handbremse, die H-Taste, um das Heck ausbrechen zu lassen. |
| `test_pause.ogg` | Das ist die Pause des Tests. Du kannst die Simulationsstufe ändern, die Einstellungen öffnen, die Anleitung ansehen oder den Test verlassen. |
| `test_drift_first.ogg` | Das ist Driften! Je mehr Winkel und Tempo, desto mehr Punkte. Wenn du crashst, verlierst du den Drift. |
| `test_bumps.ogg` | Das sind Bodenschwellen. Fahr mit unterschiedlichem Tempo drüber und achte darauf, wie die Federung arbeitet. |
| `test_fuel_corner.ogg` | Das ist die Tankecke. Halte im grünen Quadrat an, und der Tank füllt sich von selbst. |
| `test_refuel.ogg` | Es wird getankt. Bleib kurz stehen. |
| `test_fuel_full.ogg` | Tank voll. Du kannst weitertesten. |
| `test_fuel_low.ogg` | Dein Sprit wird knapp. Such die grüne Ecke. |
| `test_fuel_empty.ogg` | Dir ist der Sprit ausgegangen. Das Auto beschleunigt nicht: Bring es zum grünen Quadrat oder starte im Pausenmenü neu. |
| `race_start.ogg` | Fahr der Reihe nach durch die Tore. Das nächste markiere ich dir mit einem grünen Lichtstrahl. Jede Runde wird gestoppt. |
| `test_lap_first.ogg` | Erste Runde geschafft. Mal sehen, ob du sie verbessern kannst. |
| `test_lap_done.ogg` | Noch eine Runde. Schau, ob du die Zeit gedrückt hast. |
| `cam_onboard.ogg` | Das ist die Onboard-Kamera: Du siehst aus dem Helm des Fahrers. Sie ist die realistischste. |
| `cam_chase.ogg` | Verfolgerkamera: das Auto von hinten gesehen. Ändere den Abstand mit der Kamerataste. |
| `cam_aerial.ogg` | Luftkamera: ideal, um die ganze Spur eines Drifts zu sehen. |
| `cam_free.ogg` | Freie Kamera: Bewege sie mit dem Finger und zoome mit zwei Fingern. |
| `cam_rear.ogg` | Innenkamera hinter dem Fahrer: Du siehst das Armaturenbrett, das Lenkrad und die Hände. |
| `cam_hood.ogg` | Motorhaubenkamera: Du siehst die Front des Autos vor dir. |
| `cam_bumper.ogg` | Stoßfängerkamera: die niedrigste und die mit dem stärksten Geschwindigkeitsgefühl. |
| `lab_open.ogg` | Hier kannst du am Auto alles ändern, was du willst: Leistung, Grip, Federung, Bremsen, Getriebe und Aerodynamik. Jede Änderung gilt sofort: Probier sie aus und komm zurück. |
| `lab_motor.ogg` | Motor: Leistung, Gewicht und Luftwiderstand. Weniger Gewicht und mehr Leistung beschleunigen stärker, aber die Räder drehen durch. |
| `lab_agarre.ogg` | Grip: Reifen, Drücke und Spur. Mehr Grip hinten bremst den Drift; weniger Grip hinten erleichtert ihn. |
| `lab_susp.ogg` | Federung: Höhe, Federn, Dämpfer und Stabilisatoren. Harte Federn reagieren schnell; weiche schlucken Bodenschwellen besser. |
| `lab_frenos.ogg` | Bremsen: die Verteilung zwischen vorn und hinten, der Druck und die Lenkung. Mehr Bremskraft hinten hilft, das Auto quer zu stellen. |
| `lab_trans.ogg` | Getriebe: wie sich der Antrieb zwischen vorn und hinten verteilt, das Differenzial und die Achsübersetzung. Heckantrieb ist die Königin des Driftens. |
| `lab_aero.ogg` | Aerodynamik: der Abtrieb vorn und hinten. Er drückt das Auto bei hohem Tempo auf die Straße, kostet aber Höchstgeschwindigkeit. |
| `sim_changed.ogg` | Du hast die Simulationsstufe geändert. Sie gilt sofort. |
| `wheel_real.ogg` | Beim echten Lenkrad musst du wirklich mit dem Finger drehen: bis zu drei Umdrehungen von Anschlag zu Anschlag. |
| `exit_done.ogg` | Geschafft, zurück zum Menü. Der Testmodus bleibt im Startmenü: Komm zurück, wann immer du dein Auto einstellen oder etwas ausprobieren willst, ohne in ein Rennen zu gehen. |
