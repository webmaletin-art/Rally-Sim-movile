# Plan de la versión 1.0 (decisiones del dueño + propuestas a confirmar)

Estado: **todo lo de juego y tienda está hecho** (ver «Hecho»). **En espera del zip de assets** (íconos + logotipo + nombres de autos): hasta entonces no se toca el menú principal (reorganización sin scroll, íconos nuevos, mundo 3D con cámara libre detrás del menú).

## Hecho (r de esta tanda)
- Economía rebalanceada, packs y compras (`dr_full`, `dr_adventure`, `dr_garage`, autos premium sueltos; sin créditos), 3 etapas gratis, cartel de ofertas, Online y Mundo abierto en «PRONTO».
- Carrera rápida solo con autos propios (el auto se ve en la escena 3D), reglaje y pintura con costo (probar gratis, pagar al aplicar).
- **Duelo de drift** contra un bot adaptativo (Carrera rápida → Drift → Duelo contra un bot, nivel fácil/normal/difícil).
- **Picada** de 400 m (mapa «Picada», Carrera rápida y dos eventos de copa: Picada del Domingo y Picada Nocturna): caja manual obligatoria, barra de vueltas con zona verde de cambio perfecto (cambio al doble de rápido), cambio tarde = rebote contra el limitador, rival a la par; resultado con «cambios perfectos: X de Y». Prueba: `tests/drag_test.gd`.
- Idiomas: español, inglés, portugués, **francés, italiano y alemán** (textos del juego).

## Pendiente
- **Voz del copiloto en el idioma elegido**: en la versión Godot el copiloto hablado **todavía no está portado** (existe solo en la versión HTML, con 756 frases grabadas en español, `audio/cd/`). Plan: portar `js/copilot.js` (situaciones, prioridades, pausas) y reproducir las grabaciones en español; para los demás idiomas usar la voz del sistema (`DisplayServer.tts_speak`) con las frases traducidas, o grabarlas con una voz de cada idioma.
- Carreras A→B / checkpoints sobre tramos de tierra y asfalto de la ruta de aventura.
- Menú principal sin scroll, íconos y nombres nuevos (esperando el zip).

## Decidido por el dueño
- Estudio: **SRGamestudios** · paquete **com.srg.dreamracing** · contacto roldanhr98@gmail.com · ícono: el «DR» provisorio actual.
- Gratis: la copa **Debut** y **3 etapas** de la aventura; todos los mapas desbloqueados.
- Pago: paquete completo (aventura completa + resto) y/o packs más chicos (solo autos / solo aventura); camión y 3 superdeportivos aparte o en paquete.
- Carrera rápida **solo con autos obtenidos** (probar autos queda en la tienda); al elegir auto se muestra en la escena 3D junto a los pilotos.
- Opciones al elegir carrera: mapa, tipo (contrarreloj / libre / con rivales), rivales, clima, y los ajustes de conducción de siempre (menos en la aventura).
- Drift: libre, por puntos y **duelo contra bot** que se adapta al jugador (puede ganar o perder).
- Todo cambio mecánico **cuesta monedas**; taller de reglaje de prueba gratis → se paga al aplicar.
- Economía justa: pocas monedas por carrera, sin farmeo; paga por puesto (1°, 2°, 3° y 4° menos), por derrape y por contrarreloj.
- Nuevas carreras: contrarreloj y *checkpoints* punto A → punto B en caminos de tierra y asfalto de la ruta de aventura (otros biomas, no).
- Sección **Mundo abierto** (Valle abierto + misiones) marcada «PRONTO»; **Modo online** debajo de Aventura, cerrado, con carteles de lo que viene (mundo abierto, ciudades, biomas, carreras JcJ, ranking, eventos mensuales). Supabase listo para integrar después.
- **Picada**: largada recta, solo acelerar y hacer cambios perfectos (ajuste milimétrico), misión relativamente fácil.
- Al terminar las etapas gratis: oferta de compra con capturas vistosas (pradera, montañas, nieve, túnel).
- Menú principal sin scroll (el scroll queda para ajustes de autos); mundo 3D detrás con cámara libre; cartel de ofertas al inicio con presentación 3D.
- Idiomas: completar los que falten; voz del copiloto en el idioma elegido.

## Pendiente de confirmar (ver chat)
Precios finales en Play Console · cuáles son los 3 superdeportivos (hoy: Mamut 6x6, GT3 RS y Aerion) · copas restantes · cómo se hablan las voces del copiloto (voz del sistema o grabadas).
