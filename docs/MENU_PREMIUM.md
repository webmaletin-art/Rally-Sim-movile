# Menú premium (garaje · taller · tienda)

Rediseño **sólo visual/UX**: nada de economía, compras, inventario, física ni guardado cambió; cada botón llama a lo mismo que antes.

## Qué hay
- **Barra superior** (`ui/menu_chrome.gd`): logo DREAM RACING, secciones GARAJE · TALLER · TIENDA, dinero (el «+» abre COMPRAS), nivel con su barra de progreso y ajustes. En el inicio sólo va la esquina con dinero y nivel.
- **Riel de navegación** a la izquierda: ATRÁS, MIS AUTOS, COMPRA AUTOS y las 6 pestañas del taller (PIEZAS, GOMAS, AJUSTE, PINTURA, LLANTAS, ESTÉTICA). Con nombres en el garaje y la tienda; compacto (ícono + nombre chico) en el taller, que necesita el ancho. Desde Dream City sólo muestra lo que ese local ofrece.
- **Tarjeta del auto** (`menu_garage.gd::_cars`): marca, modelo, categoría y PI, cv · kg · km/h · tracción, las 5 barras reales y un radar con los mismos 5 números. Botones: EN USO / USAR ESTE AUTO, TALLER, COMPRAR y probar (asfalto, tierra, drift).
- **Carrusel de autos** abajo, con miniaturas (`ui/thumbs/<id>.png`, generadas con `tools/godot/gen_thumbs.gd`), categoría y PI; el elegido con borde naranja. Flechas y arrastre. **Tira de especificaciones**: motor, transmisión (cantidad de marchas del `vehicles.json`), tracción, peso, vel. máx. y potencia (todos datos reales).
- **Sala 3D** (`ui/showroom_env.gd`): garaje redondo de grafito con pilares, paneles, barras de luz blancas y naranjas, piso oscuro y logo DR. Pocas mallas (MultiMesh) y una sola luz extra (sin brillo especular). El auto se corre para quedar entre la barra de arriba y el carrusel (`view_shift_y`) y la cámara se aleja un poco (`dist_scale`).
- **Cámara libre** (girar con un dedo, pellizco/rueda para acercar, doble toque para volver) en todas las pantallas con el auto: los toques que no usa la interfaz pasan al 3D. Probado en `tests/menu_ui_test.gd`.
- **Íconos de línea** dibujados en código (`ui/icons.gd`) y estilos nuevos en `ui_kit.gd` (`nav_item`, `stat_bar`, `class_badge`, `icon_button`, `pop_in`). Microinteracciones livianas: hover con borde naranja, entrada suave de paneles, el carrusel se desliza hasta el auto elegido. Sin partículas ni animaciones permanentes.

## Inicio
Logo, auto elegido (categoría + PI), botón grande SEGUIR CARRERA (o AVENTURA si no hay evento) y mosaico de 12 modos con íconos más OPCIONES y ACERCA DE; entra sin desplazar en 1280×576.

## Pendiente / ideas
- ESTADÍSTICAS (en la referencia): no hay datos de estadísticas por auto, así que no se inventó.
- Los textos nuevos están traducidos a los 5 idiomas (en, pt, fr, it, de).
- Tablets 4:3: el panel central estira hasta abajo (queda aire); se puede ajustar al contenido.
