# [B] Modo de prueba (20/10/2026): menú, guía hablada (51 líneas del guion), hojas con dibujos, pausa de la prueba, HUD, volante, avisos de la policía y nivel de simulación
# orden: en, pt, fr, it, de
import json, os

_G = json.load(open(os.path.join(os.path.dirname(__file__), '..', '..', '..', 'godot', 'game', 'data', 'guide_script.json'), encoding='utf-8'))
ES = {l['id']: l['es'] for l in _G['lines']}  # (las claves son exactamente el texto del guion)

T = {}

def add(es, en, pt, fr, it, de):
    T[es] = (en, pt, fr, it, de)

# ───────────────────────── la guía hablada (guion) ─────────────────────────
add(ES['welcome'],
    "Hi, I'm Claudio, your guide. This is test mode: a place to get to know the car, tune the setup and drift before heading out to the open world. You can read the guide or go straight to the test.",
    "Oi, eu sou o Claudio, o seu guia. Este é o modo de teste: um lugar para conhecer o carro, ajustar a regulagem e fazer drift antes de sair para o mundo aberto. Você pode ler o guia ou ir direto para o teste.",
    "Salut, je suis Claudio, ton guide. Voici le mode essai : un endroit pour découvrir la voiture, ajuster le réglage et drifter avant de partir dans le monde ouvert. Tu peux lire le guide ou aller directement à l'essai.",
    "Ciao, sono Claudio, la tua guida. Questa è la modalità prova: un posto per conoscere l'auto, regolare l'assetto e fare drift prima di uscire nel mondo aperto. Puoi leggere la guida o andare direttamente alla prova.",
    "Hallo, ich bin Claudio, dein Guide. Das ist der Testmodus: ein Ort, um das Auto kennenzulernen, das Setup einzustellen und zu driften, bevor du in die offene Welt fährst. Du kannst die Anleitung lesen oder gleich zum Test gehen.")
add(ES['guide_pages'],
    "Use the arrows to flip the pages: suspension, traction, brakes, cameras, steering wheel and drift. Whenever you like, come back and enter the test.",
    "Com as setas você passa as páginas: suspensão, tração, freios, câmeras, volante e drift. Quando quiser, volte e entre no teste.",
    "Avec les flèches tu tournes les pages : suspension, traction, freins, caméras, volant et drift. Quand tu veux, reviens et entre dans l'essai.",
    "Con le frecce sfogli le pagine: sospensioni, trazione, freni, camere, volante e drift. Quando vuoi, torna indietro ed entra nella prova.",
    "Mit den Pfeilen blätterst du: Federung, Antrieb, Bremsen, Kameras, Lenkrad und Drift. Wenn du so weit bist, geh zurück und starte den Test.")
add(ES['setup_welcome'],
    "Choose which car you'll test with, the simulation level and what you want to do: drift or race.",
    "Escolha com qual carro você vai testar, o nível de simulação e o que quer fazer: drift ou corrida.",
    "Choisis avec quelle voiture tu vas essayer, le niveau de simulation et ce que tu veux faire : drift ou course.",
    "Scegli con quale auto provare, il livello di simulazione e cosa vuoi fare: drift o gara.",
    "Wähle, mit welchem Auto du testest, die Simulationsstufe und was du machen willst: Driften oder Rennen.")
add(ES['car_pickup'],
    "The pickup: tall and heavy. Ideal for feeling the suspension on the speed bumps and on dirt.",
    "A caminhonete: alta e pesada. Ideal para sentir a suspensão nas lombadas e na terra.",
    "Le pick-up : haut et lourd. Idéal pour sentir la suspension sur les dos d'âne et sur la terre.",
    "Il pick-up: alto e pesante. Ideale per sentire le sospensioni sui dossi e sullo sterrato.",
    "Der Pickup: hoch und schwer. Ideal, um die Federung auf den Bodenschwellen und im Dreck zu spüren.")
add(ES['car_gt'],
    "The GT: balanced and stable. A fast road car to learn the setup.",
    "O GT: equilibrado e estável. Um carro de rua rápido para aprender a regulagem.",
    "La GT : équilibrée et stable. Une voiture de route rapide pour apprendre le réglage.",
    "La GT: equilibrata e stabile. Un'auto stradale veloce per imparare l'assetto.",
    "Der GT: ausgewogen und stabil. Ein schneller Straßenwagen, um das Setup zu lernen.")
add(ES['car_classic'],
    "The classic: little grip and lots of character. It slides easily, so it's great fun for drifting.",
    "O clássico: pouca aderência e muito caráter. Ele escorrega fácil, por isso é muito divertido para o drift.",
    "La classique : peu d'adhérence et beaucoup de caractère. Elle glisse facilement, donc elle est très amusante pour le drift.",
    "La classica: poca aderenza e tanto carattere. Scivola facilmente, quindi è molto divertente per il drift.",
    "Der Klassiker: wenig Grip und viel Charakter. Er rutscht leicht und macht deshalb beim Driften richtig Spaß.")
add(ES['car_super'],
    "The supercar: huge power. In full simulation you have to handle it with care.",
    "O superesportivo: muita potência. Na simulação total é preciso tratá-lo com cuidado.",
    "La supercar : une puissance énorme. En simulation totale, il faut la manier avec précaution.",
    "La supersportiva: potenza enorme. Con la simulazione totale va trattata con cura.",
    "Der Supersportwagen: enorme Leistung. In der vollen Simulation musst du ihn mit Vorsicht behandeln.")
add(ES['sim_arcade'],
    "Arcade: high ABS, traction control and stability, and the steering wheel turns only a little: three quarters of a turn lock to lock. The car forgives almost everything.",
    "Arcade: ABS, controle de tração e estabilidade altos, e o volante gira pouco: três quartos de volta de batente a batente. O carro perdoa quase tudo.",
    "Arcade : ABS, antipatinage et stabilité élevés, et le volant tourne peu : trois quarts de tour d'une butée à l'autre. La voiture pardonne presque tout.",
    "Arcade: ABS, controllo di trazione e stabilità alti, e il volante gira poco: tre quarti di giro da un fondo corsa all'altro. L'auto perdona quasi tutto.",
    "Arcade: ABS, Traktionskontrolle und Stabilität sind hoch, und das Lenkrad dreht nur wenig: dreiviertel Umdrehung von Anschlag zu Anschlag. Das Auto verzeiht fast alles.")
add(ES['sim_mid'],
    "Intermediate: medium assists. A balanced drive, between arcade and the simulator.",
    "Intermediário: ajudas médias. Uma condução equilibrada, entre o arcade e o simulador.",
    "Intermédiaire : aides moyennes. Une conduite équilibrée, entre l'arcade et le simulateur.",
    "Intermedio: aiuti medi. Una guida equilibrata, tra l'arcade e il simulatore.",
    "Mittel: mittlere Hilfen. Ein ausgewogenes Fahrgefühl zwischen Arcade und Simulator.")
add(ES['sim_pro'],
    "Full simulator: no assists, and the on-screen wheel asks for real turns, like a real one. Harder, but very realistic.",
    "Simulador total: sem ajudas, e o volante da tela pede voltas de verdade, como um real. Mais difícil, mas muito realista.",
    "Simulateur total : sans aides, et le volant à l'écran demande de vrais tours, comme un vrai. Plus difficile, mais très réaliste.",
    "Simulatore totale: senza aiuti, e il volante sullo schermo richiede giri veri, come uno reale. Più difficile, ma molto realistico.",
    "Voller Simulator: ohne Hilfen, und das Lenkrad auf dem Bildschirm verlangt echte Umdrehungen wie ein richtiges. Schwieriger, aber sehr realistisch.")
add(ES['sim_custom'],
    "Custom: you pick each assist and how far you want the wheel to turn, from three quarters of a turn up to three full turns lock to lock.",
    "Personalizado: você escolhe cada ajuda e o quanto quer que o volante gire, de três quartos de volta até três voltas de batente a batente.",
    "Personnalisé : tu choisis chaque aide et de combien tu veux que le volant tourne, de trois quarts de tour jusqu'à trois tours d'une butée à l'autre.",
    "Personalizzato: scegli ogni aiuto e quanto vuoi che giri il volante, da tre quarti di giro fino a tre giri da un fondo corsa all'altro.",
    "Benutzerdefiniert: Du wählst jede Hilfe und wie weit sich das Lenkrad drehen soll, von dreiviertel Umdrehung bis zu drei Umdrehungen von Anschlag zu Anschlag.")
add(ES['mode_drift'],
    "Drift: a big plaza with cones and four cars drifting on their own. You can score points or just slide freely.",
    "Drift: uma praça grande com cones e quatro carros fazendo drift sozinhos. Você pode somar pontos ou derrapar livremente.",
    "Drift : une grande place avec des cônes et quatre voitures qui driftent toutes seules. Tu peux marquer des points ou glisser librement.",
    "Drift: una grande piazza con coni e quattro auto che fanno drift da sole. Puoi fare punti o derapare liberamente.",
    "Drift: ein großer Platz mit Pylonen und vier Autos, die von allein driften. Du kannst Punkte sammeln oder frei rutschen.")
add(ES['mode_race'],
    "Race: a time-trial lap through gates. Pick the dirt road behind the city or the track between the buildings.",
    "Corrida: uma volta contra o relógio por portões. Escolha a estrada de terra atrás da cidade ou a pista entre os prédios.",
    "Course : un tour chronométré par des portes. Choisis le chemin de terre derrière la ville ou la piste entre les immeubles.",
    "Gara: un giro a cronometro attraverso le porte. Scegli la strada sterrata dietro la città o la pista tra i palazzi.",
    "Rennen: eine Zeitfahrrunde durch Tore. Wähle die Schotterstraße hinter der Stadt oder die Strecke zwischen den Gebäuden.")
add(ES['score_points'],
    "With points: every drift scores according to angle and speed, and the longer it is, the better the multiplier.",
    "Com pontos: cada derrapagem soma conforme o ângulo e a velocidade, e quanto mais longa, melhor o multiplicador.",
    "Avec points : chaque drift rapporte selon l'angle et la vitesse, et plus il est long, meilleur est le multiplicateur.",
    "Con i punti: ogni derapata fa punti in base all'angolo e alla velocità, e più è lunga, migliore è il moltiplicatore.",
    "Mit Punkten: Jeder Drift bringt Punkte je nach Winkel und Geschwindigkeit, und je länger er dauert, desto besser der Multiplikator.")
add(ES['score_free'],
    "Free: no points and no rush. Just you, the car and the angle.",
    "Livre: sem pontos nem pressa. Só você, o carro e o ângulo.",
    "Libre : sans points ni pression. Juste toi, la voiture et l'angle.",
    "Libero: niente punti e nessuna fretta. Solo tu, l'auto e l'angolo.",
    "Frei: ohne Punkte und ohne Eile. Nur du, das Auto und der Winkel.")
add(ES['loop_dirt'],
    "The dirt road: it goes all the way around behind the city and returns to the plaza from the other side.",
    "A estrada de terra: dá a volta toda por trás da cidade e volta à praça pelo outro lado.",
    "Le chemin de terre : il fait tout le tour derrière la ville et revient sur la place par l'autre côté.",
    "La strada sterrata: fa tutto il giro dietro la città e torna alla piazza dall'altro lato.",
    "Die Schotterstraße: Sie führt ganz um die Stadt herum und kommt von der anderen Seite zurück auf den Platz.")
add(ES['loop_urban'],
    "Between the buildings: a lap through the city streets, with tight corners and a roundabout.",
    "Entre os prédios: uma volta pelas ruas da cidade, com esquinas fechadas e uma rotatória.",
    "Entre les immeubles : un tour par les rues de la ville, avec des virages serrés et un rond-point.",
    "Tra i palazzi: un giro per le strade della città, con curve strette e una rotonda.",
    "Zwischen den Gebäuden: eine Runde durch die Stadtstraßen, mit engen Kurven und einem Kreisverkehr.")
add(ES['lab_on'],
    "With tuning help on, you'll see the tuning menu in the pause screen: suspension, traction, brakes and more.",
    "Com a ajuda de regulagem você vê o menu de regulagens na pausa: suspensão, tração, freios e mais.",
    "Avec l'aide au réglage, tu verras le menu de réglages dans la pause : suspension, traction, freins et plus.",
    "Con l'aiuto assetto vedrai il menu delle regolazioni nella pausa: sospensioni, trazione, freni e altro.",
    "Mit der Setup-Hilfe siehst du im Pausenmenü die Einstellungen: Federung, Antrieb, Bremsen und mehr.")
add(ES['lab_off'],
    "Without tuning help the car stays as it comes from the factory. You can still change the simulation level from the pause screen.",
    "Sem a ajuda de regulagem o carro vai como sai de fábrica. Mesmo assim você pode mudar o nível de simulação na pausa.",
    "Sans l'aide au réglage, la voiture reste comme à la sortie d'usine. Tu peux quand même changer le niveau de simulation depuis la pause.",
    "Senza l'aiuto assetto l'auto resta com'è di fabbrica. Puoi comunque cambiare il livello di simulazione dalla pausa.",
    "Ohne Setup-Hilfe bleibt das Auto ab Werk. Die Simulationsstufe kannst du trotzdem im Pausenmenü ändern.")
add(ES['gfx'],
    "If the game runs a bit tight, lower the graphics quality from here. You can measure it again whenever you like.",
    "Se o jogo estiver rodando no limite, diminua a qualidade gráfica por aqui. Você pode medir de novo quando quiser.",
    "Si le jeu tourne juste, baisse la qualité graphique d'ici. Tu peux la mesurer de nouveau quand tu veux.",
    "Se il gioco gira al limite, abbassa la qualità grafica da qui. Puoi misurarla di nuovo quando vuoi.",
    "Wenn das Spiel knapp läuft, senke hier die Grafikqualität. Du kannst sie jederzeit neu messen.")
add(ES['start'],
    "When you're ready, tap start the test. Remember: it can only be done once.",
    "Quando estiver pronto, toque em começar o teste. Lembre-se: só dá para fazer uma vez.",
    "Quand tu es prêt, touche commencer l'essai. N'oublie pas : on ne peut le faire qu'une seule fois.",
    "Quando sei pronto, tocca inizia la prova. Ricorda: si fa una sola volta.",
    "Wenn du bereit bist, tippe auf Test starten. Denk daran: Er geht nur einmal.")
add(ES['test_welcome'],
    "You're on the track. Drive around for a while to warm up. With the pause button you open the tuning and the guide.",
    "Você já está na pista. Dirija um pouco para esquentar. Na pausa você abre as regulagens e o guia.",
    "Tu es sur la piste. Roule un peu pour t'échauffer. Avec la pause, tu ouvres les réglages et le guide.",
    "Sei in pista. Guida un po' per scaldarti. Con la pausa apri le regolazioni e la guida.",
    "Du bist auf der Strecke. Fahr dich ein bisschen warm. Mit der Pause öffnest du die Einstellungen und die Anleitung.")
add(ES['test_try_drift'],
    "Try a drift: accelerate, turn the wheel and pull the handbrake, the H button, to kick the tail out.",
    "Experimente um drift: acelere, gire o volante e puxe o freio de mão, o botão H, para soltar a traseira.",
    "Essaie un drift : accélère, tourne le volant et tire le frein à main, le bouton H, pour lâcher l'arrière.",
    "Prova un drift: accelera, gira il volante e tira il freno a mano, il pulsante H, per far scivolare la coda.",
    "Probier einen Drift: Gib Gas, dreh das Lenkrad und zieh die Handbremse, die H-Taste, um das Heck ausbrechen zu lassen.")
add(ES['test_pause'],
    "This is the test pause. You can change the simulation level, open the tuning, look at the guide or leave the test.",
    "Esta é a pausa do teste. Você pode mudar o nível de simulação, abrir as regulagens, ver o guia ou sair do teste.",
    "Voici la pause de l'essai. Tu peux changer le niveau de simulation, ouvrir les réglages, regarder le guide ou quitter l'essai.",
    "Questa è la pausa della prova. Puoi cambiare il livello di simulazione, aprire le regolazioni, guardare la guida o uscire dalla prova.",
    "Das ist die Pause des Tests. Du kannst die Simulationsstufe ändern, die Einstellungen öffnen, die Anleitung ansehen oder den Test verlassen.")
add(ES['test_drift_first'],
    "That's drifting! The more angle and speed, the more points. If you crash, you lose the drift.",
    "Isso é drift! Quanto mais ângulo e velocidade, mais pontos. Se você bater, perde a derrapagem.",
    "Ça, c'est du drift ! Plus d'angle et de vitesse, plus de points. Si tu tapes, tu perds le drift.",
    "Questo è drift! Più angolo e più velocità, più punti. Se sbatti, perdi la derapata.",
    "Das ist Driften! Je mehr Winkel und Tempo, desto mehr Punkte. Wenn du crashst, verlierst du den Drift.")
add(ES['test_bumps'],
    "These are speed bumps. Go over them at different speeds and notice how the suspension works.",
    "Estas são lombadas. Passe por elas em velocidades diferentes e veja como a suspensão trabalha.",
    "Voici des dos d'âne. Passe-les à différentes vitesses et observe comment la suspension travaille.",
    "Questi sono dossi. Passali a velocità diverse e osserva come lavorano le sospensioni.",
    "Das sind Bodenschwellen. Fahr mit unterschiedlichem Tempo drüber und achte darauf, wie die Federung arbeitet.")
add(ES['test_fuel_corner'],
    "This is the fuel corner. Stop inside the green square and the tank refills by itself.",
    "Esta é a esquina do combustível. Pare dentro do quadrado verde e o tanque se enche sozinho.",
    "Voici le coin de l'essence. Arrête-toi dans le carré vert et le réservoir se remplit tout seul.",
    "Questo è l'angolo della benzina. Fermati dentro il quadrato verde e il serbatoio si riempie da solo.",
    "Das ist die Tankecke. Halte im grünen Quadrat an, und der Tank füllt sich von selbst.")
add(ES['test_refuel'],
    "Refueling. Stay still for a moment.",
    "Abastecendo. Fique parado um instante.",
    "Remplissage en cours. Reste immobile un instant.",
    "Rifornimento in corso. Resta fermo un momento.",
    "Es wird getankt. Bleib kurz stehen.")
add(ES['test_fuel_full'],
    "Tank full. You can keep testing.",
    "Tanque cheio. Você já pode continuar testando.",
    "Réservoir plein. Tu peux continuer à essayer.",
    "Serbatoio pieno. Puoi continuare a provare.",
    "Tank voll. Du kannst weitertesten.")
add(ES['test_fuel_low'],
    "You're low on fuel. Look for the green corner.",
    "Está acabando o combustível. Procure a esquina verde.",
    "Il te reste peu d'essence. Cherche le coin vert.",
    "Ti resta poca benzina. Cerca l'angolo verde.",
    "Dein Sprit wird knapp. Such die grüne Ecke.")
add(ES['test_fuel_empty'],
    "You ran out of fuel. The car won't accelerate: take it to the green square or restart from the pause screen.",
    "O combustível acabou. O carro não acelera: leve-o até o quadrado verde ou reinicie pela pausa.",
    "Tu n'as plus d'essence. La voiture n'accélère plus : emmène-la jusqu'au carré vert ou recommence depuis la pause.",
    "Sei rimasto senza benzina. L'auto non accelera: portala nel quadrato verde o riavvia dalla pausa.",
    "Dir ist der Sprit ausgegangen. Das Auto beschleunigt nicht: Bring es zum grünen Quadrat oder starte im Pausenmenü neu.")
add(ES['race_start'],
    "Go through the gates in order. I'll mark the next one with a green beam. Every lap is timed.",
    "Passe pelos portões em ordem. Eu marco o próximo com um farol verde. Cada volta é cronometrada.",
    "Passe par les portes dans l'ordre. Je te marque la prochaine avec un faisceau vert. Chaque tour est chronométré.",
    "Passa per le porte in ordine. Ti segno la prossima con un faro verde. Ogni giro viene cronometrato.",
    "Fahr der Reihe nach durch die Tore. Das nächste markiere ich dir mit einem grünen Lichtstrahl. Jede Runde wird gestoppt.")
add(ES['test_lap_first'],
    "First lap complete. Let's see if you can beat it.",
    "Primeira volta completa. Vamos ver se você consegue melhorar.",
    "Premier tour terminé. Voyons si tu peux faire mieux.",
    "Primo giro completo. Vediamo se riesci a migliorarlo.",
    "Erste Runde geschafft. Mal sehen, ob du sie verbessern kannst.")
add(ES['test_lap_done'],
    "Another lap. See if you brought the time down.",
    "Mais uma volta. Veja se baixou o tempo.",
    "Encore un tour. Regarde si tu as amélioré ton temps.",
    "Un altro giro. Guarda se hai abbassato il tempo.",
    "Noch eine Runde. Schau, ob du die Zeit gedrückt hast.")
add(ES['cam_onboard'],
    "This is the onboard camera: you see from the driver's helmet. It's the most realistic one.",
    "Esta é a câmera onboard: você vê do capacete do piloto. É a mais realista.",
    "Voici la caméra embarquée : tu vois depuis le casque du pilote. C'est la plus réaliste.",
    "Questa è la camera onboard: vedi dal casco del pilota. È la più realistica.",
    "Das ist die Onboard-Kamera: Du siehst aus dem Helm des Fahrers. Sie ist die realistischste.")
add(ES['cam_chase'],
    "Chase camera: the car seen from behind. Change the distance with the camera button.",
    "Câmera de perseguição: o carro visto por trás. Mude a distância com o botão de câmera.",
    "Caméra de poursuite : la voiture vue de derrière. Change la distance avec le bouton de caméra.",
    "Camera inseguimento: l'auto vista da dietro. Cambia la distanza con il pulsante della camera.",
    "Verfolgerkamera: das Auto von hinten gesehen. Ändere den Abstand mit der Kamerataste.")
add(ES['cam_aerial'],
    "Aerial camera: ideal to see the whole path of a drift.",
    "Câmera aérea: ideal para ver o traçado completo de uma derrapagem.",
    "Caméra aérienne : idéale pour voir toute la trajectoire d'un drift.",
    "Camera aerea: ideale per vedere l'intera traiettoria di una derapata.",
    "Luftkamera: ideal, um die ganze Spur eines Drifts zu sehen.")
add(ES['cam_free'],
    "Free camera: move it with your finger and zoom with two fingers.",
    "Câmera livre: mova com o dedo e aproxime com dois dedos.",
    "Caméra libre : déplace-la avec le doigt et zoome avec deux doigts.",
    "Camera libera: muovila con il dito e fai zoom con due dita.",
    "Freie Kamera: Bewege sie mit dem Finger und zoome mit zwei Fingern.")
add(ES['cam_rear'],
    "Interior camera, behind the driver: you see the dashboard, the steering wheel and the hands.",
    "Câmera interna, atrás do piloto: você vê o painel, o volante e as mãos.",
    "Caméra intérieure, derrière le pilote : tu vois le tableau de bord, le volant et les mains.",
    "Camera interna, dietro il pilota: vedi il cruscotto, il volante e le mani.",
    "Innenkamera hinter dem Fahrer: Du siehst das Armaturenbrett, das Lenkrad und die Hände.")
add(ES['cam_hood'],
    "Hood camera: you see the nose of the car in front of you.",
    "Câmera do capô: você vê a frente do carro à sua frente.",
    "Caméra de capot : tu vois le nez de la voiture devant toi.",
    "Camera cofano: vedi il muso dell'auto davanti a te.",
    "Motorhaubenkamera: Du siehst die Front des Autos vor dir.")
add(ES['cam_bumper'],
    "Bumper camera: the lowest one, and the one that gives the most sense of speed.",
    "Câmera do para-choque: a mais baixa e a que dá mais sensação de velocidade.",
    "Caméra de pare-chocs : la plus basse et celle qui donne le plus de sensation de vitesse.",
    "Camera paraurti: la più bassa e quella che dà più sensazione di velocità.",
    "Stoßfängerkamera: die niedrigste und die mit dem stärksten Geschwindigkeitsgefühl.")
add(ES['lab_open'],
    "Here you can change whatever you want on the car: power, grip, suspension, brakes, transmission and aerodynamics. Every change applies right away: try it and come back.",
    "Aqui você pode modificar o que quiser no carro: potência, aderência, suspensão, freios, transmissão e aerodinâmica. Cada mudança é aplicada na hora: teste e volte.",
    "Ici tu peux modifier ce que tu veux sur la voiture : puissance, adhérence, suspension, freins, transmission et aérodynamique. Chaque changement s'applique tout de suite : essaie et reviens.",
    "Qui puoi modificare quello che vuoi dell'auto: potenza, aderenza, sospensioni, freni, trasmissione e aerodinamica. Ogni modifica si applica subito: provala e torna.",
    "Hier kannst du am Auto alles ändern, was du willst: Leistung, Grip, Federung, Bremsen, Getriebe und Aerodynamik. Jede Änderung gilt sofort: Probier sie aus und komm zurück.")
add(ES['lab_motor'],
    "Engine: power, weight and air resistance. Less weight and more power accelerate harder, but the wheels spin.",
    "Motor: a potência, o peso e a resistência do ar. Menos peso e mais potência aceleram mais, mas as rodas patinam.",
    "Moteur : la puissance, le poids et la résistance de l'air. Moins de poids et plus de puissance accélèrent plus, mais les roues patinent.",
    "Motore: la potenza, il peso e la resistenza dell'aria. Meno peso e più potenza accelerano di più, ma le ruote pattinano.",
    "Motor: Leistung, Gewicht und Luftwiderstand. Weniger Gewicht und mehr Leistung beschleunigen stärker, aber die Räder drehen durch.")
add(ES['lab_agarre'],
    "Grip: tires, pressures and alignment. More grip at the rear stops the drift; less grip at the rear makes it easier.",
    "Aderência: pneus, pressões e alinhamento. Mais aderência atrás segura a derrapagem; menos aderência atrás a facilita.",
    "Adhérence : pneus, pressions et géométrie. Plus d'adhérence à l'arrière freine le drift ; moins d'adhérence à l'arrière le facilite.",
    "Aderenza: gomme, pressioni e allineamento. Più aderenza dietro frena la derapata; meno aderenza dietro la facilita.",
    "Grip: Reifen, Drücke und Spur. Mehr Grip hinten bremst den Drift; weniger Grip hinten erleichtert ihn.")
add(ES['lab_susp'],
    "Suspension: ride height, springs, dampers and bars. Stiff springs respond quickly; soft ones absorb speed bumps better.",
    "Suspensão: a altura, as molas, os amortecedores e as barras. As molas duras respondem rápido; as macias absorvem melhor as lombadas.",
    "Suspension : la hauteur, les ressorts, les amortisseurs et les barres. Les ressorts durs répondent vite ; les souples absorbent mieux les dos d'âne.",
    "Sospensioni: l'altezza, le molle, gli ammortizzatori e le barre. Le molle dure rispondono in fretta; quelle morbide assorbono meglio i dossi.",
    "Federung: Höhe, Federn, Dämpfer und Stabilisatoren. Harte Federn reagieren schnell; weiche schlucken Bodenschwellen besser.")
add(ES['lab_frenos'],
    "Brakes: the front-to-rear split, pressure and steering. More rear braking helps get the car sideways.",
    "Freios: a distribuição entre a frente e a traseira, a pressão e a direção. Mais freio atrás ajuda a colocar o carro de lado.",
    "Freins : la répartition avant-arrière, la pression et la direction. Plus de frein à l'arrière aide à mettre la voiture en travers.",
    "Freni: il bilanciamento tra avanti e dietro, la pressione e lo sterzo. Più freno dietro aiuta a mettere l'auto di traverso.",
    "Bremsen: die Verteilung zwischen vorn und hinten, der Druck und die Lenkung. Mehr Bremskraft hinten hilft, das Auto quer zu stellen.")
add(ES['lab_trans'],
    "Transmission: how the traction is split between front and rear, the differential and the final drive. Rear-wheel drive is the queen of drifting.",
    "Transmissão: como a tração se divide entre a frente e a traseira, o diferencial e a relação final. A tração traseira é a rainha do drift.",
    "Transmission : comment la traction se répartit entre l'avant et l'arrière, le différentiel et le rapport final. La propulsion est la reine du drift.",
    "Trasmissione: come si ripartisce la trazione tra avanti e dietro, il differenziale e il rapporto finale. La trazione posteriore è la regina del drift.",
    "Getriebe: wie sich der Antrieb zwischen vorn und hinten verteilt, das Differenzial und die Achsübersetzung. Heckantrieb ist die Königin des Driftens.")
add(ES['lab_aero'],
    "Aerodynamics: the downforce at the front and rear. It presses the car to the ground at high speed, but costs top speed.",
    "Aerodinâmica: a carga na frente e atrás. Aperta o carro contra o piso em alta velocidade, mas tira velocidade final.",
    "Aérodynamique : l'appui à l'avant et à l'arrière. Il plaque la voiture au sol à haute vitesse, mais lui enlève de la vitesse de pointe.",
    "Aerodinamica: il carico davanti e dietro. Schiaccia l'auto a terra ad alta velocità, ma toglie velocità di punta.",
    "Aerodynamik: der Abtrieb vorn und hinten. Er drückt das Auto bei hohem Tempo auf die Straße, kostet aber Höchstgeschwindigkeit.")
add(ES['sim_changed'],
    "You changed the simulation level. It applies right away.",
    "Você mudou o nível de simulação. Ele é aplicado na hora.",
    "Tu as changé le niveau de simulation. Il s'applique tout de suite.",
    "Hai cambiato il livello di simulazione. Si applica subito.",
    "Du hast die Simulationsstufe geändert. Sie gilt sofort.")
add(ES['wheel_real'],
    "With the real wheel you have to turn it for real with your finger: up to three turns lock to lock.",
    "Com o volante real você tem que girar de verdade com o dedo: até três voltas de batente a batente.",
    "Avec le volant réel, tu dois vraiment le tourner avec le doigt : jusqu'à trois tours d'une butée à l'autre.",
    "Con il volante reale devi girarlo davvero con il dito: fino a tre giri da un fondo corsa all'altro.",
    "Beim echten Lenkrad musst du wirklich mit dem Finger drehen: bis zu drei Umdrehungen von Anschlag zu Anschlag.")
add(ES['exit_warn'],
    "If you leave the test you can't enter again. Tap once more to confirm.",
    "Se você sair do teste, não poderá entrar de novo. Toque mais uma vez para confirmar.",
    "Si tu quittes l'essai, tu ne pourras plus y entrer. Touche encore une fois pour confirmer.",
    "Se esci dalla prova non puoi più rientrare. Tocca ancora una volta per confermare.",
    "Wenn du den Test verlässt, kommst du nicht mehr hinein. Tippe noch einmal zur Bestätigung.")
add(ES['exit_done'],
    "Done, you finished the test. Now the open world awaits you. Enjoy it!",
    "Pronto, você terminou o teste. Agora o mundo aberto te espera. Aproveite!",
    "C'est fini, tu as terminé l'essai. Maintenant, le monde ouvert t'attend. Profites-en !",
    "Fatto, hai finito la prova. Ora ti aspetta il mondo aperto. Divertiti!",
    "Geschafft, du hast den Test beendet. Jetzt wartet die offene Welt auf dich. Viel Spaß!")

# ───────────────────────── menú del Modo de prueba ─────────────────────────
add("MODO DE PRUEBA", "TEST MODE", "MODO DE TESTE", "MODE ESSAI", "MODALITÀ PROVA", "TESTMODUS")
add("una sola vez", "one time only", "uma única vez", "une seule fois", "una sola volta", "nur einmal")
add("eventos y ranking", "events and ranking", "eventos e ranking", "événements et classement", "eventi e classifica", "Events und Rangliste")
add("🎓 MODO DE PRUEBA", "🎓 TEST MODE", "🎓 MODO DE TESTE", "🎓 MODE ESSAI", "🎓 MODALITÀ PROVA", "🎓 TESTMODUS")
add("🎓 ARMÁ TU PRUEBA", "🎓 SET UP YOUR TEST", "🎓 MONTE O SEU TESTE", "🎓 PRÉPARE TON ESSAI", "🎓 PREPARA LA TUA PROVA", "🎓 STELL DEINEN TEST ZUSAMMEN")
add("📖 GUÍA DE LA PRUEBA", "📖 TEST GUIDE", "📖 GUIA DO TESTE", "📖 GUIDE DE L'ESSAI", "📖 GUIDA DELLA PROVA", "📖 TESTANLEITUNG")
add("📖 LEER LA GUÍA", "📖 READ THE GUIDE", "📖 LER O GUIA", "📖 LIRE LE GUIDE", "📖 LEGGI LA GUIDA", "📖 ANLEITUNG LESEN")
add("las hojas con dibujos: suspensión, tracción, cámaras, volante…", "illustrated pages: suspension, traction, cameras, steering wheel…", "as páginas com desenhos: suspensão, tração, câmeras, volante…", "les pages illustrées : suspension, traction, caméras, volant…", "le pagine con i disegni: sospensioni, trazione, camere, volante…", "die Seiten mit Zeichnungen: Federung, Antrieb, Kameras, Lenkrad…")
add("▶ IR A LA PRUEBA", "▶ GO TO THE TEST", "▶ IR PARA O TESTE", "▶ ALLER À L'ESSAI", "▶ VAI ALLA PROVA", "▶ ZUM TEST")
add("elegir el auto y empezar", "pick the car and start", "escolher o carro e começar", "choisir la voiture et commencer", "scegli l'auto e inizia", "Auto wählen und starten")
add("▶ EMPEZAR LA PRUEBA", "▶ START THE TEST", "▶ COMEÇAR O TESTE", "▶ COMMENCER L'ESSAI", "▶ INIZIA LA PROVA", "▶ TEST STARTEN")
add("una sola vez: cuando salís no se vuelve a entrar", "one time only: once you leave you can't come back in", "uma única vez: ao sair, não dá para entrar de novo", "une seule fois : une fois sorti, on ne peut plus rentrer", "una sola volta: una volta usciti non si può rientrare", "nur einmal: wenn du rausgehst, kommst du nicht mehr rein")
add("AUTO DE PRUEBA", "TEST CAR", "CARRO DE TESTE", "VOITURE D'ESSAI", "AUTO DI PROVA", "TESTAUTO")
add("CAMIONETA", "PICKUP", "CAMINHONETE", "PICK-UP", "PICK-UP", "PICKUP")
add("CLÁSICO", "CLASSIC", "CLÁSSICO", "CLASSIQUE", "CLASSICA", "KLASSIKER")
add("SUPERDEPORTIVO", "SUPERCAR", "SUPERESPORTIVO", "SUPERCAR", "SUPERSPORTIVA", "SUPERSPORTWAGEN")
add("QUÉ QUERÉS HACER", "WHAT DO YOU WANT TO DO", "O QUE VOCÊ QUER FAZER", "QUE VEUX-TU FAIRE", "COSA VUOI FARE", "WAS MÖCHTEST DU MACHEN")
add("🌀 DRIFT POR PUNTOS", "🌀 DRIFT FOR POINTS", "🌀 DRIFT POR PONTOS", "🌀 DRIFT AUX POINTS", "🌀 DRIFT A PUNTI", "🌀 DRIFT AUF PUNKTE")
add("🌀 DRIFT LIBRE", "🌀 FREE DRIFT", "🌀 DRIFT LIVRE", "🌀 DRIFT LIBRE", "🌀 DRIFT LIBERO", "🌀 FREIES DRIFTEN")
add("🏁 CARRERA · CAMINO DE TIERRA", "🏁 RACE · DIRT ROAD", "🏁 CORRIDA · ESTRADA DE TERRA", "🏁 COURSE · CHEMIN DE TERRE", "🏁 GARA · STRADA STERRATA", "🏁 RENNEN · SCHOTTERSTRASSE")
add("🏁 CARRERA · ENTRE EDIFICIOS", "🏁 RACE · BETWEEN BUILDINGS", "🏁 CORRIDA · ENTRE PRÉDIOS", "🏁 COURSE · ENTRE LES IMMEUBLES", "🏁 GARA · TRA I PALAZZI", "🏁 RENNEN · ZWISCHEN DEN GEBÄUDEN")
add("AYUDA DE REGLAJE", "TUNING HELP", "AJUDA DE REGULAGEM", "AIDE AU RÉGLAGE", "AIUTO ASSETTO", "SETUP-HILFE")
add("⚙ CALIDAD GRÁFICA", "⚙ GRAPHICS QUALITY", "⚙ QUALIDADE GRÁFICA", "⚙ QUALITÉ GRAPHIQUE", "⚙ QUALITÀ GRAFICA", "⚙ GRAFIKQUALITÄT")
add("⚙ AJUSTAR LAS AYUDAS Y EL VOLANTE", "⚙ ADJUST ASSISTS AND STEERING", "⚙ AJUSTAR AS AJUDAS E O VOLANTE", "⚙ RÉGLER LES AIDES ET LE VOLANT", "⚙ REGOLA AIUTI E VOLANTE", "⚙ HILFEN UND LENKRAD EINSTELLEN")
add("GUÍA: VOZ Y TEXTO", "GUIDE: VOICE AND TEXT", "GUIA: VOZ E TEXTO", "GUIDE : VOIX ET TEXTE", "GUIDA: VOCE E TESTO", "FÜHRUNG: STIMME UND TEXT")
add("GUÍA: SÓLO TEXTO", "GUIDE: TEXT ONLY", "GUIA: SÓ TEXTO", "GUIDE : TEXTE SEULEMENT", "GUIDA: SOLO TESTO", "FÜHRUNG: NUR TEXT")
add("GUÍA: APAGADA", "GUIDE: OFF", "GUIA: DESLIGADO", "GUIDE : DÉSACTIVÉ", "GUIDA: SPENTA", "FÜHRUNG: AUS")
add("VOZ", "VOICE", "VOZ", "VOIX", "VOCE", "STIMME")
add("TEXTO", "TEXT", "TEXTO", "TEXTE", "TESTO", "TEXT")
add("SIN GUÍA", "NO GUIDE", "SEM GUIA", "SANS GUIDE", "SENZA GUIDA", "OHNE FÜHRUNG")
add("ADELANTE", "NEXT", "AVANÇAR", "SUIVANT", "AVANTI", "WEITER")
add("🎓 CLAUDIO", "🎓 CLAUDIO", "🎓 CLAUDIO", "🎓 CLAUDIO", "🎓 CLAUDIO", "🎓 CLAUDIO")
add("Un lugar para probar el juego antes de salir al mundo abierto: manejá un auto de prueba en una pista con lomos de burro, un punto de nafta, un camino de tierra por atrás de la ciudad y cuatro autos haciendo drift.",
    "A place to try the game before heading out to the open world: drive a test car on a track with speed bumps, a fuel point, a dirt road behind the city and four cars drifting.",
    "Um lugar para testar o jogo antes de sair para o mundo aberto: dirija um carro de teste numa pista com lombadas, um ponto de combustível, uma estrada de terra atrás da cidade e quatro carros fazendo drift.",
    "Un endroit pour essayer le jeu avant de partir dans le monde ouvert : conduis une voiture d'essai sur une piste avec des dos d'âne, un point d'essence, un chemin de terre derrière la ville et quatre voitures qui driftent.",
    "Un posto per provare il gioco prima di uscire nel mondo aperto: guida un'auto di prova su una pista con dossi, un punto benzina, una strada sterrata dietro la città e quattro auto che fanno drift.",
    "Ein Ort, um das Spiel auszuprobieren, bevor du in die offene Welt fährst: Fahr ein Testauto auf einer Strecke mit Bodenschwellen, einem Tankpunkt, einer Schotterstraße hinter der Stadt und vier driftenden Autos.")
add("🎮  Probá el nivel de simulación: arcade, intermedio, simulador total o personalizado.",
    "🎮  Try the simulation level: arcade, intermediate, full simulator or custom.",
    "🎮  Experimente o nível de simulação: arcade, intermediário, simulador total ou personalizado.",
    "🎮  Essaie le niveau de simulation : arcade, intermédiaire, simulateur total ou personnalisé.",
    "🎮  Prova il livello di simulazione: arcade, intermedio, simulatore totale o personalizzato.",
    "🎮  Probier die Simulationsstufe aus: Arcade, Mittel, voller Simulator oder benutzerdefiniert.")
add("🔧  Ajustá el reglaje: suspensión, tracción, frenos, gomas… se aplica al instante.",
    "🔧  Tune the setup: suspension, traction, brakes, tires… it applies instantly.",
    "🔧  Ajuste a regulagem: suspensão, tração, freios, pneus… é aplicada na hora.",
    "🔧  Ajuste le réglage : suspension, traction, freins, pneus… il s'applique instantanément.",
    "🔧  Regola l'assetto: sospensioni, trazione, freni, gomme… si applica all'istante.",
    "🔧  Stell das Setup ein: Federung, Antrieb, Bremsen, Reifen… es gilt sofort.")
add("🌀  Hacé drift (por puntos o libre) o una carrera contrarreloj por puertas.",
    "🌀  Drift (for points or free) or race a time trial through gates.",
    "🌀  Faça drift (por pontos ou livre) ou uma corrida contra o relógio por portões.",
    "🌀  Fais du drift (aux points ou libre) ou une course chronométrée par des portes.",
    "🌀  Fai drift (a punti o libero) o una gara a cronometro attraverso le porte.",
    "🌀  Drifte (auf Punkte oder frei) oder fahr ein Zeitrennen durch Tore.")
add("🎥  Mirá las cámaras y las ayudas desde la pausa, con la guía en imágenes.",
    "🎥  Check the cameras and the assists from the pause screen, with the illustrated guide.",
    "🎥  Veja as câmeras e as ajudas na pausa, com o guia em imagens.",
    "🎥  Regarde les caméras et les aides depuis la pause, avec le guide en images.",
    "🎥  Guarda le camere e gli aiuti dalla pausa, con la guida illustrata.",
    "🎥  Sieh dir die Kameras und die Hilfen im Pausenmenü an, mit der Anleitung in Bildern.")
add("⚠ La prueba se hace UNA sola vez: cuando salís, no se puede volver a entrar. Tomate el tiempo que quieras.",
    "⚠ The test can be done only ONCE: when you leave, you can't come back in. Take all the time you want.",
    "⚠ O teste só pode ser feito UMA vez: ao sair, não dá para entrar de novo. Fique o tempo que quiser.",
    "⚠ L'essai ne se fait qu'UNE seule fois : une fois sorti, on ne peut plus y rentrer. Prends tout ton temps.",
    "⚠ La prova si fa UNA sola volta: quando esci, non si può più rientrare. Prenditi tutto il tempo che vuoi.",
    "⚠ Der Test geht nur EINMAL: Wenn du rausgehst, kommst du nicht mehr hinein. Nimm dir die Zeit, die du brauchst.")

# ───────────────────────── pausa, HUD y pista de la prueba ─────────────────────────
add("SALIR DE LA PRUEBA", "LEAVE THE TEST", "SAIR DO TESTE", "QUITTER L'ESSAI", "ESCI DALLA PROVA", "TEST VERLASSEN")
add("TOCÁ OTRA VEZ PARA SALIR", "TAP AGAIN TO LEAVE", "TOQUE DE NOVO PARA SAIR", "TOUCHE ENCORE POUR QUITTER", "TOCCA DI NUOVO PER USCIRE", "NOCHMAL TIPPEN ZUM VERLASSEN")
add("OCULTAR LA GUÍA", "HIDE THE GUIDE", "OCULTAR O GUIA", "MASQUER LE GUIDE", "NASCONDI LA GUIDA", "ANLEITUNG AUSBLENDEN")
add("MOSTRAR LA GUÍA", "SHOW THE GUIDE", "MOSTRAR O GUIA", "AFFICHER LE GUIDE", "MOSTRA LA GUIDA", "ANLEITUNG EINBLENDEN")
add("Podés cambiarlo cuando quieras: se aplica en el momento y el auto sigue donde está.", "You can change it whenever you like: it applies at once and the car stays where it is.", "Você pode mudar quando quiser: é aplicado na hora e o carro continua onde está.", "Tu peux le changer quand tu veux : il s'applique tout de suite et la voiture reste où elle est.", "Puoi cambiarlo quando vuoi: si applica subito e l'auto resta dov'è.", "Du kannst es jederzeit ändern: Es gilt sofort und das Auto bleibt, wo es ist.")
add("TOTAL", "TOTAL", "TOTAL", "TOTAL", "TOTALE", "GESAMT")
add("VUELTA", "LAP", "VOLTA", "TOUR", "GIRO", "RUNDE")
add("PUERTA", "GATE", "PORTÃO", "PORTE", "PORTA", "TOR")
add("MEJOR %s", "BEST %s", "MELHOR %s", "MEILLEUR %s", "MIGLIORE %s", "BESTE %s")
add("🏁 Vuelta %d · %s%s", "🏁 Lap %d · %s%s", "🏁 Volta %d · %s%s", "🏁 Tour %d · %s%s", "🏁 Giro %d · %s%s", "🏁 Runde %d · %s%s")
add("  ¡mejor!", "  best!", "  melhor!", "  meilleur !", "  migliore!", "  Bestzeit!")
add("DRIFT LIBRE", "FREE DRIFT", "DRIFT LIVRE", "DRIFT LIBRE", "DRIFT LIBERO", "FREIES DRIFTEN")
add("⛽ Cargando nafta…", "⛽ Refueling…", "⛽ Abastecendo…", "⛽ Remplissage…", "⛽ Rifornimento…", "⛽ Tanken…")
add("⛽ Tanque lleno", "⛽ Tank full", "⛽ Tanque cheio", "⛽ Réservoir plein", "⛽ Serbatoio pieno", "⛽ Tank voll")
add("⛽ Poca nafta: frená en el cuadrado verde para cargar", "⛽ Low fuel: stop in the green square to refuel", "⛽ Pouco combustível: pare no quadrado verde para abastecer", "⛽ Peu d'essence : arrête-toi dans le carré vert pour faire le plein", "⛽ Poca benzina: fermati nel quadrato verde per fare il pieno", "⛽ Wenig Sprit: Halte im grünen Quadrat zum Tanken an")
add("⛽ Sin nafta: el auto no acelera. Empujalo al cuadrado verde o reiniciá", "⛽ Out of fuel: the car won't accelerate. Push it to the green square or restart", "⛽ Sem combustível: o carro não acelera. Empurre-o até o quadrado verde ou reinicie", "⛽ Plus d'essence : la voiture n'accélère plus. Pousse-la jusqu'au carré vert ou recommence", "⛽ Senza benzina: l'auto non accelera. Spingila nel quadrato verde o riavvia", "⛽ Kein Sprit: Das Auto beschleunigt nicht. Schieb es zum grünen Quadrat oder starte neu")
add("⛽ NAFTA", "⛽ FUEL", "⛽ COMBUSTÍVEL", "⛽ ESSENCE", "⛽ BENZINA", "⛽ TANKEN")
add("LOMO DE BURRO", "SPEED BUMP", "LOMBADA", "DOS D'ÂNE", "DOSSO", "BODENSCHWELLE")

# ───────────────────────── hojas de la guía (dibujos y textos) ─────────────────────────
add("MOTOR: POTENCIA, PESO Y AIRE", "ENGINE: POWER, WEIGHT AND AIR", "MOTOR: POTÊNCIA, PESO E AR", "MOTEUR : PUISSANCE, POIDS ET AIR", "MOTORE: POTENZA, PESO E ARIA", "MOTOR: LEISTUNG, GEWICHT UND LUFT")
add("Más potencia acelera más, pero las ruedas patinan más (ideal para el drift). Con menos peso el auto acelera, frena y dobla mejor. La resistencia al aire frena el auto a alta velocidad: con menos llegás más rápido.",
    "More power accelerates harder, but the wheels spin more (great for drifting). With less weight the car accelerates, brakes and turns better. Air resistance slows the car at high speed: with less of it you reach a higher top speed.",
    "Mais potência acelera mais, mas as rodas patinam mais (ideal para o drift). Com menos peso o carro acelera, freia e faz curvas melhor. A resistência do ar freia o carro em alta velocidade: com menos você chega mais rápido.",
    "Plus de puissance accélère plus, mais les roues patinent plus (idéal pour le drift). Avec moins de poids, la voiture accélère, freine et tourne mieux. La résistance de l'air freine la voiture à haute vitesse : avec moins, tu vas plus vite.",
    "Più potenza accelera di più, ma le ruote pattinano di più (ideale per il drift). Con meno peso l'auto accelera, frena e curva meglio. La resistenza dell'aria frena l'auto ad alta velocità: con meno arrivi più veloce.",
    "Mehr Leistung beschleunigt stärker, aber die Räder drehen mehr durch (ideal fürs Driften). Mit weniger Gewicht beschleunigt, bremst und lenkt das Auto besser. Der Luftwiderstand bremst das Auto bei hohem Tempo: Mit weniger kommst du schneller ans Ziel.")
add("AGARRE: GOMAS Y PRESIÓN", "GRIP: TIRES AND PRESSURE", "ADERÊNCIA: PNEUS E PRESSÃO", "ADHÉRENCE : PNEUS ET PRESSION", "ADERENZA: GOMME E PRESSIONE", "GRIP: REIFEN UND DRUCK")
add("Las gomas blandas agarran más y las duras se deslizan: para el drift conviene poco agarre atrás. Con menos presión la goma apoya más superficie. La caída negativa (la rueda inclinada hacia adentro) da más agarre en la curva.",
    "Soft tires grip more and hard ones slide: for drifting, little grip at the rear is best. With less pressure the tire puts more surface on the ground. Negative camber (the wheel tilted inward) gives more grip in the corner.",
    "Os pneus macios aderem mais e os duros deslizam: para o drift convém pouca aderência atrás. Com menos pressão o pneu apoia mais superfície. A cambagem negativa (a roda inclinada para dentro) dá mais aderência na curva.",
    "Les pneus tendres adhèrent plus et les durs glissent : pour le drift, mieux vaut peu d'adhérence à l'arrière. Avec moins de pression, le pneu pose plus de surface. Le carrossage négatif (la roue inclinée vers l'intérieur) donne plus d'adhérence en virage.",
    "Le gomme morbide aderiscono di più e quelle dure scivolano: per il drift conviene poca aderenza dietro. Con meno pressione la gomma appoggia più superficie. La campanatura negativa (la ruota inclinata verso l'interno) dà più aderenza in curva.",
    "Weiche Reifen haften mehr und harte rutschen: Zum Driften ist wenig Grip hinten besser. Mit weniger Druck liegt mehr Reifenfläche auf. Negativer Sturz (das Rad nach innen geneigt) gibt mehr Grip in der Kurve.")
add("AERODINÁMICA", "AERODYNAMICS", "AERODINÂMICA", "AÉRODYNAMIQUE", "AERODINAMICA", "AERODYNAMIK")
add("El aire empuja el auto contra el piso: con más carga aerodinámica agarra más en las curvas rápidas, pero también lo frena en las rectas. A baja velocidad casi no se nota.",
    "The air pushes the car onto the ground: with more downforce it grips more in fast corners, but it also slows it down on the straights. At low speed you hardly notice it.",
    "O ar empurra o carro contra o piso: com mais carga aerodinâmica ele adere mais nas curvas rápidas, mas também o freia nas retas. Em baixa velocidade quase não se nota.",
    "L'air plaque la voiture au sol : avec plus d'appui aérodynamique, elle adhère davantage dans les virages rapides, mais elle est aussi freinée dans les lignes droites. À basse vitesse, on ne le remarque presque pas.",
    "L'aria spinge l'auto contro il suolo: con più carico aerodinamico aderisce di più nelle curve veloci, ma la frena anche nei rettilinei. A bassa velocità quasi non si nota.",
    "Die Luft drückt das Auto auf die Straße: Mit mehr Abtrieb haftet es in schnellen Kurven besser, wird aber auch auf den Geraden gebremst. Bei niedrigem Tempo merkt man es kaum.")
add("TRANSMISIÓN Y TRACCIÓN", "TRANSMISSION AND DRIVETRAIN", "TRANSMISSÃO E TRAÇÃO", "TRANSMISSION ET TRACTION", "TRASMISSIONE E TRAZIONE", "GETRIEBE UND ANTRIEB")
add("Delantera: estable y fácil. Trasera: la reina del drift, porque las ruedas de atrás patinan y empujan el auto de costado. Integral: mucho agarre al salir de las curvas. El reparto se cambia en el reglaje de transmisión.",
    "Front: stable and easy. Rear: the queen of drifting, because the rear wheels spin and push the car sideways. All-wheel: lots of grip coming out of corners. The split is changed in the transmission tuning.",
    "Dianteira: estável e fácil. Traseira: a rainha do drift, porque as rodas de trás patinam e empurram o carro de lado. Integral: muita aderência ao sair das curvas. A distribuição se muda na regulagem da transmissão.",
    "Traction : stable et facile. Propulsion : la reine du drift, car les roues arrière patinent et poussent la voiture en travers. Intégrale : beaucoup d'adhérence en sortie de virage. La répartition se change dans le réglage de la transmission.",
    "Anteriore: stabile e facile. Posteriore: la regina del drift, perché le ruote dietro pattinano e spingono l'auto di traverso. Integrale: molta aderenza in uscita di curva. Il riparto si cambia nella regolazione della trasmissione.",
    "Front: stabil und leicht. Heck: die Königin des Driftens, weil die Hinterräder durchdrehen und das Auto seitlich schieben. Allrad: viel Grip beim Herausbeschleunigen. Die Verteilung stellst du im Getriebe-Setup ein.")
add("DELANTERA", "FRONT", "DIANTEIRA", "TRACTION", "ANTERIORE", "FRONT")
add("TRASERA", "REAR", "TRASEIRA", "PROPULSION", "POSTERIORE", "HECK")
add("INTEGRAL", "ALL-WHEEL", "INTEGRAL", "INTÉGRALE", "INTEGRALE", "ALLRAD")
add("VOLANTE Y NIVEL DE SIMULACIÓN", "STEERING WHEEL AND SIMULATION LEVEL", "VOLANTE E NÍVEL DE SIMULAÇÃO", "VOLANT ET NIVEAU DE SIMULATION", "VOLANTE E LIVELLO DI SIMULAZIONE", "LENKRAD UND SIMULATIONSSTUFE")
add("En Arcade el volante de la pantalla gira tres cuartos de vuelta de tope a tope. En el volante real hay que girar el dedo de verdad: hasta tres vueltas de tope a tope, y más con el ángulo de dirección en 130 %.",
    "In Arcade the on-screen wheel turns three quarters of a turn lock to lock. With the real wheel you have to turn your finger for real: up to three turns lock to lock, and more with the steering angle at 130 %.",
    "No Arcade o volante da tela gira três quartos de volta de batente a batente. No volante real é preciso girar o dedo de verdade: até três voltas de batente a batente, e mais com o ângulo de direção em 130 %.",
    "En Arcade, le volant à l'écran tourne de trois quarts de tour d'une butée à l'autre. Avec le volant réel, il faut vraiment tourner le doigt : jusqu'à trois tours d'une butée à l'autre, et plus avec l'angle de direction à 130 %.",
    "In Arcade il volante sullo schermo gira tre quarti di giro da un fondo corsa all'altro. Con il volante reale devi girare davvero il dito: fino a tre giri da un fondo corsa all'altro, e di più con l'angolo di sterzo al 130 %.",
    "Im Arcade-Modus dreht sich das Lenkrad auf dem Bildschirm dreiviertel Umdrehung von Anschlag zu Anschlag. Beim echten Lenkrad musst du wirklich mit dem Finger drehen: bis zu drei Umdrehungen von Anschlag zu Anschlag, und mehr mit dem Lenkwinkel auf 130 %.")
add("NAFTA Y LOMOS DE BURRO", "FUEL AND SPEED BUMPS", "COMBUSTÍVEL E LOMBADAS", "ESSENCE ET DOS D'ÂNE", "BENZINA E DOSSI", "SPRIT UND BODENSCHWELLEN")
add("El tanque baja con la velocidad. Frená adentro del cuadrado verde, en la esquina de la nafta, para cargar. En la esquina de pruebas hay lomos de burro: pasalos a distintas velocidades para probar la suspensión.",
    "The tank drops with speed. Stop inside the green square, in the fuel corner, to refill. In the test corner there are speed bumps: go over them at different speeds to test the suspension.",
    "O tanque diminui com a velocidade. Pare dentro do quadrado verde, na esquina do combustível, para abastecer. Na esquina de testes há lombadas: passe por elas em velocidades diferentes para testar a suspensão.",
    "Le réservoir baisse avec la vitesse. Arrête-toi dans le carré vert, dans le coin de l'essence, pour faire le plein. Dans le coin d'essai, il y a des dos d'âne : passe-les à différentes vitesses pour tester la suspension.",
    "Il serbatoio cala con la velocità. Fermati dentro il quadrato verde, nell'angolo della benzina, per fare il pieno. Nell'angolo di prova ci sono dei dossi: passali a velocità diverse per provare le sospensioni.",
    "Der Tank leert sich mit dem Tempo. Halte im grünen Quadrat in der Tankecke an, um aufzutanken. In der Testecke gibt es Bodenschwellen: Fahr mit unterschiedlichem Tempo darüber, um die Federung zu testen.")
add("Los resortes duros responden rápido y evitan que el auto se hamaque; los blandos absorben mejor los baches y los lomos de burro. Los amortiguadores frenan el rebote: si el auto rebota mucho, subí el amortiguador.",
    "Stiff springs respond quickly and keep the car from rocking; soft ones absorb bumps and speed bumps better. The dampers control the rebound: if the car bounces a lot, raise the damper.",
    "As molas duras respondem rápido e evitam que o carro balance; as macias absorvem melhor os buracos e as lombadas. Os amortecedores freiam o rebote: se o carro quica muito, aumente o amortecedor.",
    "Les ressorts durs répondent vite et évitent que la voiture ne tangue ; les souples absorbent mieux les bosses et les dos d'âne. Les amortisseurs freinent le rebond : si la voiture rebondit beaucoup, augmente l'amortisseur.",
    "Le molle dure rispondono in fretta ed evitano che l'auto ondeggi; quelle morbide assorbono meglio le buche e i dossi. Gli ammortizzatori frenano il rimbalzo: se l'auto rimbalza molto, aumenta l'ammortizzatore.",
    "Harte Federn reagieren schnell und verhindern, dass das Auto schaukelt; weiche schlucken Schlaglöcher und Bodenschwellen besser. Die Dämpfer bremsen das Nachfedern: Wenn das Auto stark wippt, erhöhe den Dämpfer.")
add("El reparto de frenado decide qué ruedas frenan más. Más freno adelante: el auto entra recto y estable. Más freno atrás: la cola se suelta y ayuda a meter el auto de costado.",
    "The brake split decides which wheels brake harder. More front brake: the car goes in straight and stable. More rear brake: the tail breaks loose and helps get the car sideways.",
    "A distribuição de frenagem decide quais rodas freiam mais. Mais freio na frente: o carro entra reto e estável. Mais freio atrás: a traseira solta e ajuda a colocar o carro de lado.",
    "La répartition du freinage décide quelles roues freinent le plus. Plus de frein à l'avant : la voiture entre droit et stable. Plus de frein à l'arrière : l'arrière décroche et aide à mettre la voiture en travers.",
    "Il bilanciamento della frenata decide quali ruote frenano di più. Più freno davanti: l'auto entra dritta e stabile. Più freno dietro: la coda si scompone e aiuta a mettere l'auto di traverso.",
    "Die Bremsverteilung entscheidet, welche Räder stärker bremsen. Mehr Bremse vorn: Das Auto fährt gerade und stabil ein. Mehr Bremse hinten: Das Heck bricht aus und hilft, das Auto quer zu stellen.")
add("Onboard (casco): la más realista. Interior, capó y paragolpes: más sensación de velocidad. Persecución y aérea: ven todo el auto y el derrape. Se cambian con el botón de cámara de arriba.",
    "Onboard (helmet): the most realistic. Interior, hood and bumper: more sense of speed. Chase and aerial: you see the whole car and the drift. You switch them with the camera button at the top.",
    "Onboard (capacete): a mais realista. Interna, capô e para-choque: mais sensação de velocidade. Perseguição e aérea: veem o carro todo e a derrapagem. Mudam-se com o botão de câmera de cima.",
    "Embarquée (casque) : la plus réaliste. Intérieur, capot et pare-chocs : plus de sensation de vitesse. Poursuite et aérienne : elles montrent toute la voiture et le drift. Elles se changent avec le bouton de caméra en haut.",
    "Onboard (casco): la più realistica. Interna, cofano e paraurti: più sensazione di velocità. Inseguimento e aerea: vedono tutta l'auto e la derapata. Si cambiano con il pulsante della camera in alto.",
    "Onboard (Helm): die realistischste. Innen, Motorhaube und Stoßfänger: mehr Geschwindigkeitsgefühl. Verfolger und Luft: Sie zeigen das ganze Auto und den Drift. Gewechselt wird mit der Kamerataste oben.")
add("Se derrapa con el auto de costado, a más de 20 km/h. Los puntos suben con la velocidad y el ángulo, y el multiplicador sube cada 2 segundos seguidos. Chocar pierde el derrape; un cono baja el multiplicador.",
    "You drift with the car sideways, above 20 km/h. Points grow with speed and angle, and the multiplier goes up every 2 seconds in a row. Crashing loses the drift; hitting a cone lowers the multiplier.",
    "Derrapa-se com o carro de lado, acima de 20 km/h. Os pontos sobem com a velocidade e o ângulo, e o multiplicador sobe a cada 2 segundos seguidos. Bater perde a derrapagem; um cone baixa o multiplicador.",
    "On drifte avec la voiture en travers, à plus de 20 km/h. Les points augmentent avec la vitesse et l'angle, et le multiplicateur monte toutes les 2 secondes d'affilée. Taper fait perdre le drift ; un cône baisse le multiplicateur.",
    "Si deraspa con l'auto di traverso, sopra i 20 km/h. I punti salgono con la velocità e l'angolo, e il moltiplicatore sale ogni 2 secondi di fila. Sbattere fa perdere la derapata; un cono abbassa il moltiplicatore.",
    "Gedriftet wird mit dem Auto quer, ab 20 km/h. Die Punkte steigen mit Tempo und Winkel, und der Multiplikator steigt alle 2 Sekunden am Stück. Ein Crash verliert den Drift; ein Pylon senkt den Multiplikator.")
add("DURO ▲ rápido", "STIFF ▲ quick", "DURO ▲ rápido", "DUR ▲ rapide", "DURO ▲ rapido", "HART ▲ schnell")
add("BLANDO ▼ cómodo", "SOFT ▼ comfy", "MACIO ▼ confortável", "SOUPLE ▼ confortable", "MORBIDO ▼ comodo", "WEICH ▼ komfortabel")
add("ADELANTE 60 %", "FRONT 60 %", "FRENTE 60 %", "AVANT 60 %", "AVANTI 60 %", "VORN 60 %")
add("ATRÁS 40 %", "REAR 40 %", "TRÁS 40 %", "ARRIÈRE 40 %", "DIETRO 40 %", "HINTEN 40 %")
add("CASCO", "HELMET", "CAPACETE", "CASQUE", "CASCO", "HELM")
add("CAPÓ", "HOOD", "CAPÔ", "CAPOT", "COFANO", "MOTORHAUBE")
add("PARAGOLPES", "BUMPER", "PARA-CHOQUE", "PARE-CHOCS", "PARAURTI", "STOSSFÄNGER")
add("PERSECUCIÓN", "CHASE", "PERSEGUIÇÃO", "POURSUITE", "INSEGUIMENTO", "VERFOLGER")
add("AÉREA", "AERIAL", "AÉREA", "AÉRIENNE", "AEREA", "LUFT")
add("ARCADE: ¾ de vuelta", "ARCADE: ¾ turn", "ARCADE: ¾ de volta", "ARCADE : ¾ de tour", "ARCADE: ¾ di giro", "ARCADE: ¾ Umdrehung")
add("REAL 50 %: 1 vuelta y media", "REAL 50 %: 1½ turns", "REAL 50 %: 1 volta e meia", "RÉEL 50 % : 1 tour et demi", "REALE 50 %: 1 giro e mezzo", "ECHT 50 %: 1½ Umdrehungen")
add("REAL 100 %: 3 vueltas", "REAL 100 %: 3 turns", "REAL 100 %: 3 voltas", "RÉEL 100 % : 3 tours", "REALE 100 %: 3 giri", "ECHT 100 %: 3 Umdrehungen")
add("ÁNGULO", "ANGLE", "ÂNGULO", "ANGLE", "ANGOLO", "WINKEL")
add("PUNTOS = velocidad × ángulo × multiplicador", "POINTS = speed × angle × multiplier", "PONTOS = velocidade × ângulo × multiplicador", "POINTS = vitesse × angle × multiplicateur", "PUNTI = velocità × angolo × moltiplicatore", "PUNKTE = Tempo × Winkel × Multiplikator")
add("POTENCIA", "POWER", "POTÊNCIA", "PUISSANCE", "POTENZA", "LEISTUNG")
add("PESO", "WEIGHT", "PESO", "POIDS", "PESO", "GEWICHT")
add("AIRE", "AIR", "AR", "AIR", "ARIA", "LUFT")
add("HUELLA", "CONTACT PATCH", "ÁREA DE CONTATO", "EMPREINTE", "IMPRONTA", "AUFSTANDSFLÄCHE")
add("CAÍDA", "CAMBER", "CAMBAGEM", "CARROSSAGE", "CAMPANATURA", "STURZ")
add("PRESIÓN", "PRESSURE", "PRESSÃO", "PRESSION", "PRESSIONE", "DRUCK")
add("Blandas = más agarre · Duras = se deslizan", "Soft = more grip · Hard = slide", "Macios = mais aderência · Duros = deslizam", "Tendres = plus d'adhérence · Durs = glissent", "Morbide = più aderenza · Dure = scivolano", "Weich = mehr Grip · Hart = rutschen")
add("CARGA ▼ agarre · RESISTENCIA ◀ frena", "DOWNFORCE ▼ grip · DRAG ◀ slows", "CARGA ▼ aderência · RESISTÊNCIA ◀ freia", "APPUI ▼ adhérence · TRAÎNÉE ◀ freine", "CARICO ▼ aderenza · RESISTENZA ◀ frena", "ABTRIEB ▼ Grip · LUFTWIDERSTAND ◀ bremst")

# ───────────────────────── volante de la pantalla (Opciones) ─────────────────────────
add("Volante de la pantalla (vueltas de tope a tope)", "On-screen wheel (turns lock to lock)", "Volante da tela (voltas de batente a batente)", "Volant à l'écran (tours d'une butée à l'autre)", "Volante sullo schermo (giri da fondo corsa a fondo corsa)", "Lenkrad auf dem Bildschirm (Umdrehungen von Anschlag zu Anschlag)")
add("Arcade (¾ de vuelta)", "Arcade (¾ turn)", "Arcade (¾ de volta)", "Arcade (¾ de tour)", "Arcade (¾ di giro)", "Arcade (¾ Umdrehung)")
add("Real 50 % (1 vuelta y media)", "Real 50 % (1½ turns)", "Real 50 % (1 volta e meia)", "Réel 50 % (1 tour et demi)", "Reale 50 % (1 giro e mezzo)", "Echt 50 % (1½ Umdrehungen)")
add("Real 100 % (3 vueltas)", "Real 100 % (3 turns)", "Real 100 % (3 voltas)", "Réel 100 % (3 tours)", "Reale 100 % (3 giri)", "Echt 100 % (3 Umdrehungen)")

# ───────────────────────── policía: jurisdicción, reconocimiento y avisos ─────────────────────────
add("🏙 Llegaste a %s: la policía de la ruta ya no tiene jurisdicción. Si volvés, te esperan",
    "🏙 You reached %s: the highway police no longer have jurisdiction. If you come back, they'll be waiting",
    "🏙 Você chegou a %s: a polícia da estrada já não tem jurisdição. Se voltar, eles esperam você",
    "🏙 Tu es arrivé à %s : la police de la route n'a plus de juridiction. Si tu reviens, ils t'attendent",
    "🏙 Sei arrivato a %s: la polizia della strada non ha più giurisdizione. Se torni, ti aspettano",
    "🏙 Du hast %s erreicht: Die Straßenpolizei ist nicht mehr zuständig. Wenn du zurückkommst, warten sie auf dich")
add("🕶 Con este auto no te reconocen: esta ruta no te busca",
    "🕶 They don't recognize you in this car: this road isn't looking for you",
    "🕶 Com este carro não reconhecem você: esta estrada não procura você",
    "🕶 Avec cette voiture, on ne te reconnaît pas : cette route ne te cherche pas",
    "🕶 Con questa auto non ti riconoscono: questa strada non ti cerca",
    "🕶 In diesem Auto erkennt dich niemand: Diese Straße sucht dich nicht")
add("👮 Pasaste despacio por el control: la policía te deja seguir",
    "👮 You went through the checkpoint slowly: the police let you go on",
    "👮 Você passou devagar pelo controle: a polícia deixa você seguir",
    "👮 Tu es passé lentement au contrôle : la police te laisse continuer",
    "👮 Sei passato piano al controllo: la polizia ti lascia proseguire",
    "👮 Du bist langsam durch die Kontrolle gefahren: Die Polizei lässt dich weiterfahren")
add("👮 La policía te está mirando: bajá un cambio",
    "👮 The police are watching you: slow down",
    "👮 A polícia está olhando para você: reduza",
    "👮 La police te surveille : ralentis",
    "👮 La polizia ti sta guardando: rallenta",
    "👮 Die Polizei beobachtet dich: Geh vom Gas")
add("👮 ¡Último aviso! Un choque más y te persiguen",
    "👮 Last warning! One more crash and they'll chase you",
    "👮 Último aviso! Mais uma batida e eles perseguem você",
    "👮 Dernier avertissement ! Un accrochage de plus et ils te poursuivent",
    "👮 Ultimo avviso! Un altro scontro e ti inseguono",
    "👮 Letzte Warnung! Noch ein Unfall und sie verfolgen dich")
add("🚨 ¡Te vieron haciendo lío! La policía te está cazando",
    "🚨 They saw you causing trouble! The police are hunting you",
    "🚨 Viram você fazendo bagunça! A polícia está caçando você",
    "🚨 On t'a vu faire du grabuge ! La police te traque",
    "🚨 Ti hanno visto fare casino! La polizia ti sta dando la caccia",
    "🚨 Man hat dich beim Randalieren gesehen! Die Polizei jagt dich")
add("🚨 ¡Pasaste por un control! Se suman %d patrulleros",
    "🚨 You ran a checkpoint! %d more patrol cars join in",
    "🚨 Você passou por um controle! Mais %d viaturas entram na perseguição",
    "🚨 Tu as forcé un contrôle ! %d patrouilles de plus se joignent à la poursuite",
    "🚨 Hai passato un controllo! Si aggiungono %d pattuglie",
    "🚨 Du bist durch eine Kontrolle gefahren! %d weitere Streifenwagen schließen sich an")
add("😮‍💨 La policía abandona: a los que andan solos los siguen un par de km",
    "😮‍💨 The police give up: lone drivers only get chased for a couple of km",
    "😮‍💨 A polícia desiste: quem anda sozinho é perseguido por uns quilômetros",
    "😮‍💨 La police abandonne : ceux qui roulent seuls ne sont suivis que quelques km",
    "😮‍💨 La polizia si ritira: chi guida da solo viene inseguito per un paio di km",
    "😮‍💨 Die Polizei gibt auf: Wer allein fährt, wird nur ein paar Kilometer verfolgt")
