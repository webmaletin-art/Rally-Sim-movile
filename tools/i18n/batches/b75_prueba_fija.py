# [B] Modo de prueba FIJO (21/10/2026, pedido del dueño): siempre en el menú, «mi auto», entrada de la primera vez y textos sin «una sola vez»
# (las líneas nuevas del guion —welcome_first, car_mine— y las que cambiaron —welcome, start, exit_done— están en b74_modo_prueba.py, que lee guide_script.json)
# orden: en, pt, fr, it, de
T = {}

def add(es, en, pt, fr, it, de):
    T[es] = (en, pt, fr, it, de)

# baldosa del inicio y pantalla de armado
add("reglá y probá tu auto", "tune and test your car", "regule e teste o seu carro", "règle et essaie ta voiture", "regola e prova la tua auto", "Auto einstellen und testen")
add("salís y volvés cuando quieras", "leave and come back whenever you like", "saia e volte quando quiser", "quitte et reviens quand tu veux", "esci e torna quando vuoi", "jederzeit raus und wieder rein")

# guía antes de entrar
add("👋 ¡Bienvenido! Como es tu primera vez, arrancamos por acá.",
    "👋 Welcome! Since it's your first time, we start here.",
    "👋 Bem-vindo! Como é a sua primeira vez, começamos por aqui.",
    "👋 Bienvenue ! Comme c'est ta première fois, on commence ici.",
    "👋 Benvenuto! Visto che è la tua prima volta, cominciamo da qui.",
    "👋 Willkommen! Da es dein erstes Mal ist, starten wir hier.")
add("Un lugar para reglar tu auto y probar cosas sin ir a una carrera: manejá en una pista con lomos de burro, un punto de nafta, un camino de tierra por atrás de la ciudad y cuatro autos haciendo drift.",
    "A place to tune your car and try things without going to a race: drive on a track with speed bumps, a fuel point, a dirt road behind the city and four cars drifting.",
    "Um lugar para regular o seu carro e experimentar coisas sem ir a uma corrida: dirija numa pista com lombadas, um ponto de combustível, uma estrada de terra atrás da cidade e quatro carros fazendo drift.",
    "Un endroit pour régler ta voiture et tester des choses sans aller en course : roule sur une piste avec des dos d'âne, un point d'essence, un chemin de terre derrière la ville et quatre voitures qui driftent.",
    "Un posto per regolare la tua auto e provare cose senza andare a una gara: guida su una pista con dossi, un punto benzina, una strada sterrata dietro la città e quattro auto che fanno drift.",
    "Ein Ort, um dein Auto einzustellen und Dinge auszuprobieren, ohne in ein Rennen zu gehen: Fahr auf einer Strecke mit Bodenschwellen, einem Tankpunkt, einer Schotterstraße hinter der Stadt und vier driftenden Autos.")
add("✔ Queda siempre en el inicio: volvé cuando quieras.",
    "✔ It always stays on the home screen: come back whenever you like.",
    "✔ Fica sempre na tela inicial: volte quando quiser.",
    "✔ Il reste toujours sur l'accueil : reviens quand tu veux.",
    "✔ Resta sempre nella schermata iniziale: torna quando vuoi.",
    "✔ Er bleibt immer im Startmenü: Komm zurück, wann du willst.")
add("Estos ajustes no se guardan en tu auto: para dejarlos, aplicalos en el TALLER (el mecánico cobra).",
    "These adjustments aren't saved to your car: to keep them, apply them in the WORKSHOP (the mechanic charges for it).",
    "Estes ajustes não são salvos no seu carro: para mantê-los, aplique-os na OFICINA (o mecânico cobra).",
    "Ces réglages ne sont pas enregistrés sur ta voiture : pour les garder, applique-les à l'ATELIER (le mécanicien est payant).",
    "Queste regolazioni non vengono salvate sulla tua auto: per mantenerle, applicale in OFFICINA (il meccanico si fa pagare).",
    "Diese Einstellungen werden nicht an deinem Auto gespeichert: Um sie zu behalten, wende sie in der WERKSTATT an (der Mechaniker kassiert).")
add("AHORA NO · IR AL MENÚ", "NOT NOW · GO TO THE MENU", "AGORA NÃO · IR PARA O MENU", "PAS MAINTENANT · ALLER AU MENU", "NON ORA · VAI AL MENU", "NICHT JETZT · ZUM MENÜ")
