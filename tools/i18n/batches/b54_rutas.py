# Red de rutas: pantalla del menú
# orden: en, pt, fr, it, de
def e(a, b, c, d, f):
    return (a, b, c, d, f)
T = {
"RUTAS": e("ROUTES", "ESTRADAS", "ROUTES", "STRADE", "STRASSEN"),
"circular · persecución": e("roam · chase", "circular · perseguição", "rouler · poursuite", "girare · inseguimento", "fahren · Verfolgung"),
"Una red de rutas de más de 1.600 km: asfalto, tierra y barro, con rotondas y estaciones de servicio. Empezás en una estación.": e("A road network of over 1,600 km: asphalt, dirt and mud, with roundabouts and service stations. You start at a station.", "Uma rede de estradas de mais de 1.600 km: asfalto, terra e barro, com rotatórias e postos de serviço. Você começa em um posto.", "Un réseau de routes de plus de 1 600 km : asphalte, terre et boue, avec ronds-points et stations-service. Tu pars d'une station.", "Una rete di strade di oltre 1.600 km: asfalto, terra e fango, con rotonde e stazioni di servizio. Parti da una stazione.", "Ein Straßennetz von über 1.600 km: Asphalt, Erde und Schlamm, mit Kreisverkehren und Tankstellen. Du startest an einer Tankstelle."),
"JUGAR": e("PLAY", "JOGAR", "JOUER", "GIOCA", "SPIELEN"),
"SOLO ANDAR": e("JUST DRIVE", "SÓ DIRIGIR", "ROULER SEUL", "SOLO GUIDARE", "NUR FAHREN"),
"ME PERSIGUEN": e("I'M CHASED", "ME PERSEGUEM", "ON ME POURSUIT", "MI INSEGUONO", "ICH WERDE VERFOLGT"),
"YO PERSIGO": e("I CHASE", "EU PERSIGO", "JE POURSUIS", "INSEGUO IO", "ICH VERFOLGE"),
"Sin rivales: recorrés las rutas a tu ritmo. Las estaciones de servicio son tu punto de salida y de regreso.": e("No rivals: drive the routes at your own pace. Service stations are your starting and return point.", "Sem rivais: percorra as estradas no seu ritmo. Os postos de serviço são seu ponto de saída e de volta.", "Sans rivaux : parcours les routes à ton rythme. Les stations-service sont ton point de départ et de retour.", "Senza rivali: percorri le strade al tuo ritmo. Le stazioni di servizio sono il tuo punto di partenza e di ritorno.", "Keine Rivalen: Fahr die Straßen in deinem Tempo. Die Tankstellen sind dein Start- und Rückkehrpunkt."),
"Un rival sale detrás tuyo y te persigue por las rutas. Si le abrís la ventaja, ganás; si te alcanza y te pasa, los roles se invierten.": e("A rival starts behind you and chases you along the routes. If you open the lead, you win; if he catches and passes you, the roles swap.", "Um rival sai atrás de você e te persegue pelas estradas. Se você abrir a vantagem, ganha; se ele te alcançar e passar, os papéis se invertem.", "Un rival part derrière toi et te poursuit sur les routes. Si tu creuses l'écart, tu gagnes ; s'il te rattrape et te dépasse, les rôles s'inversent.", "Un rivale parte dietro di te e ti insegue per le strade. Se apri il vantaggio vinci; se ti raggiunge e ti supera, i ruoli si invertono.", "Ein Rivale startet hinter dir und verfolgt dich über die Straßen. Wenn du den Vorsprung herausfährst, gewinnst du; wenn er dich einholt und überholt, tauschen sich die Rollen."),
"Un rival sale adelante y tenés que alcanzarlo. Si te abre la ventaja, se te escapa; si lo pasás, ahora te persigue él.": e("A rival starts ahead and you have to catch him. If he opens the lead, he escapes; if you pass him, now he chases you.", "Um rival sai na frente e você tem que alcançá-lo. Se ele abrir a vantagem, escapa; se você passar, agora ele te persegue.", "Un rival part devant et tu dois le rattraper. S'il creuse l'écart, il t'échappe ; si tu le dépasses, c'est lui qui te poursuit.", "Un rivale parte davanti e devi raggiungerlo. Se apre il vantaggio ti sfugge; se lo superi, ora ti insegue lui.", "Ein Rivale startet vorn und du musst ihn einholen. Wenn er den Vorsprung herausfährt, entkommt er; wenn du ihn überholst, verfolgt er jetzt dich."),
"MODO": e("MODE", "MODO", "MODE", "MODALITÀ", "MODUS"),
"ESTACIÓN DE SALIDA": e("STARTING STATION", "POSTO DE SAÍDA", "STATION DE DÉPART", "STAZIONE DI PARTENZA", "START-TANKSTELLE"),
"VENTAJA PARA GANAR": e("LEAD TO WIN", "VANTAGEM PARA GANHAR", "ÉCART POUR GAGNER", "VANTAGGIO PER VINCERE", "VORSPRUNG ZUM SIEG"),
"RIVAL": e("RIVAL", "RIVAL", "RIVAL", "RIVALE", "RIVALE"),
"TRANQUILO": e("CALM", "TRANQUILO", "TRANQUILLE", "TRANQUILLO", "RUHIG"),
"NORMAL": e("NORMAL", "NORMAL", "NORMAL", "NORMALE", "NORMAL"),
"RÁPIDO": e("FAST", "RÁPIDO", "RAPIDE", "VELOCE", "SCHNELL"),
"EXPERTO": e("EXPERT", "EXPERTO", "EXPERT", "ESPERTO", "EXPERTE"),
"La ventaja es la distancia en línea recta entre los dos autos: quien la abre primero gana. Podés volver a salir de la estación más cercana con el botón ↺ ESTACIÓN.": e("The lead is the straight-line distance between the two cars: whoever opens it first wins. You can restart from the nearest station with the ↺ STATION button.", "A vantagem é a distância em linha reta entre os dois carros: quem abrir primeiro ganha. Você pode sair de novo do posto mais próximo com o botão ↺ POSTO.", "L'écart est la distance en ligne droite entre les deux voitures : celui qui le creuse en premier gagne. Tu peux repartir de la station la plus proche avec le bouton ↺ STATION.", "Il vantaggio è la distanza in linea retta tra le due auto: chi lo apre per primo vince. Puoi ripartire dalla stazione più vicina con il pulsante ↺ STAZIONE.", "Der Vorsprung ist die Luftlinie zwischen beiden Autos: Wer ihn zuerst herausfährt, gewinnt. Mit der Taste ↺ TANKSTELLE startest du an der nächsten Station neu."),
"Estación 1": e("Station 1", "Posto 1", "Station 1", "Stazione 1", "Station 1"),
"Estación 2": e("Station 2", "Posto 2", "Station 2", "Stazione 2", "Station 2"),
"Estación 3": e("Station 3", "Posto 3", "Station 3", "Stazione 3", "Station 3"),
"Estación 4": e("Station 4", "Posto 4", "Station 4", "Stazione 4", "Station 4"),
"Estación 5": e("Station 5", "Posto 5", "Station 5", "Stazione 5", "Station 5"),
"Estación 6": e("Station 6", "Posto 6", "Station 6", "Stazione 6", "Station 6"),
"Estación 7": e("Station 7", "Posto 7", "Station 7", "Stazione 7", "Station 7"),
"Estación 8": e("Station 8", "Posto 8", "Station 8", "Stazione 8", "Station 8"),
"Estación 9": e("Station 9", "Posto 9", "Station 9", "Stazione 9", "Station 9"),
"↺ ESTACIÓN": e("↺ STATION", "↺ POSTO", "↺ STATION", "↺ STAZIONE", "↺ TANKSTELLE"),
}
T.update({
"Ver los pilotos desde las cámaras de afuera (vidrios transparentes)": e("See the drivers from the outside cameras (clear glass)", "Ver os pilotos pelas câmeras de fora (vidros transparentes)", "Voir les pilotes depuis les caméras extérieures (vitres transparentes)", "Vedere i piloti dalle camere esterne (vetri trasparenti)", "Fahrer in den Außenkameras sehen (klare Scheiben)"),
})
