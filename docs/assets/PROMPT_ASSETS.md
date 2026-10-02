# Prompt para generar los assets (PNG sin fondo)

Sirve para cualquier generador de imágenes (ChatGPT/DALL·E, Midjourney, Ideogram, Firefly, Leonardo…). Para las **letras** (nombre del juego y de los autos) conviene **Ideogram** o **ChatGPT**, que escriben bien el texto.

## Sobre el «fondo transparente»
La mayoría de los generadores **no** entrega transparencia real. Lo más seguro: pedir **fondo liso verde puro (#00FF00)** y después sacarlo (con el mismo generador si lo permite, con remove.bg o con Photoshop/Photopea). Cuando me pases el zip, si los íconos vienen sobre un fondo liso, **lo recorto yo** con un script. Entregá:
- Íconos: PNG 256×256 (los del menú principal 512×512), centrados, con ~10 % de margen.
- Letras/logos: PNG de unos 1600 px de ancho.
- Nombres de archivo **exactos** de `docs/assets/LISTA_ICONOS.md` (columna «Archivo») y `docs/assets/LISTA_NOMBRES.md`.

## 1) Guía de estilo (pegala SIEMPRE al principio, igual en todos los pedidos)
```
Set de íconos de videojuego de carreras de rally, estilo "flat 2.5D premium":
formas simples y legibles a 64 px, contorno grueso oscuro (azul marino #0E1420),
relleno con degradé suave y un brillo, sombra interior sutil, perspectiva frontal.
Paleta fija: naranja #FF7A1A (principal), blanco #FFFFFF, azul marino #0E1420, gris acero #8A97AB,
acentos puntuales amarillo #FFC531 y verde #34D17A. Sin texto, sin marca de agua.
UN solo objeto centrado, margen del 10 %, fondo liso verde puro #00FF00 (sin sombra proyectada sobre el fondo).
Mismo grosor de línea y misma fuente de luz (arriba a la izquierda) en todos los íconos.
```

## 2) Pedido por ícono (plantilla)
```
[Pegar la guía de estilo]
Ícono: <SIGNIFICADO>. Referencia del significado: <EMOJI>.
Debe leerse como "<SIGNIFICADO>" a primera vista.
```
Ejemplos: `Ícono: Aventura (camino de montaña con sol naciente) 🌄` · `Ícono: Tienda de autos 🏬` · `Ícono: Taller (llave y engranaje) 🔧` · `Ícono: Derrape (auto cruzado dejando humo) 🌀`.
Tip: pedí **8 a 12 íconos por vez en una grilla** del mismo estilo y después recortalos; así salen todos coherentes.

## 3) Nombre del juego («DREAM RACING»)
```
Logotipo "DREAM RACING" para el menú de un videojuego de rally, letras itálicas anchas y filosas
con sensación de velocidad, "DREAM" en blanco y "RACING" en naranja #FF7A1A, bisel metálico suave,
rayas de velocidad diagonales detrás, contorno azul marino grueso, brillo en el borde superior.
Debajo, en letra chica: "RALLY · DRIFT · AVENTURA". Fondo liso verde puro #00FF00. Sin ruido ni marca de agua.
Entregar también una versión solo con las iniciales "DR" (para el ícono de la app).
```

## 4) Marca y modelo de cada auto
```
Letras del nombre de un auto de videojuego: "<MARCA>" en mayúsculas, estilo <ESTILO DE LA MARCA>,
cromado/metal con reflejos, contorno oscuro, sin ningún otro elemento. Fondo liso verde puro #00FF00.
```
Estilos sugeridos por marca (podés cambiarlos): PAMPERO robusto y rústico · VOLT eléctrico/futurista con rayo · COLOSSUS pesado e industrial · DR dorado sobre negro (premium) · PAMPA redondeado y simpático · TEHUELCHE patagónico, aventurero · CHAKAL agresivo, garras · BRAVA muscle americano, cromo clásico · KAZE minimalista japonés · ALTAIR de competición, aerodinámico · VORTEX futurista con remolino.

## 5) Cartel «PRONTO» y botones nuevos
```
Cartel/botón de videojuego con la palabra "<TEXTO>" (PRONTO / MODO ONLINE / MUNDO ABIERTO / OFERTA),
mismo estilo y paleta que el logotipo DREAM RACING, forma de placa con bordes biselados. Fondo verde puro #00FF00.
```
