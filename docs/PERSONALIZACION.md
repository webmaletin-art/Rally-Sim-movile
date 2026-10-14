# Personalización comprable: diseños de pintura, interiores y volantes (14/10/2026)

Pedido del dueño: con 30 vehículos, ampliar la personalización con diseños comprables y varias texturas de interior y de volante según el auto, que se cambian en un taller.

## Qué hay
- **18 diseños de pintura** (`game/data/cosmetics.json → styles`): Carbono Rojo / Total, Competición (círculo con número en las puertas) azul y roja, Rojo y Negro, Dos Tonos Océano, Neón Nocturno / Violeta
  (líneas que **brillan de noche**), Rally Clásico / Dakar, Degradé Atardecer / Hielo, Bandera a Cuadros, Llamas / Llamas Azules, Oro Metálico, y dos **exclusivos**: «Vandal de Fábrica Naranja» (sólo STRIX) e
  «Interceptor Encubierto» (sólo el patrullero). Precios de $4.500 a $12.000.
  Son 8 patrones nuevos del sombreador de la carrocería (`car_visual.gd`, 12 a 19: carbono, competición con número, dos tonos, neón, rally clásico, degradé, damero, llamas). Se proyectan en el espacio del modelo
  (como los rotulados de siempre), **no dependen de las UV de cada auto**: sirven igual para los 30. Los números de competición están en `game/models/paint/numbers.png` (en el contenido, no en el paquete de autos).
  Los diseños de siempre (sólidos con letras, de textura y «De fábrica») siguen gratis. La textura original de cada auto no se toca: los diseños son opciones aparte.
- **8 interiores** (`interiors`): Dream (el de siempre, gratis), Rally Gamuza, Carbono, Cuero Rojo y Negro, Clásico Crema, Patrulla, Noche Neón, Trabajo y Campo. Recolorean el tablero, puertas, butacas, acolchado,
  jaula y techo del habitáculo (`cockpit.gd → _apply_interior`); el tablero y las puertas usan un grano claro para que un cuero crema se vea crema.
- **6 volantes** (`wheels`): Deportivo (el de siempre), **Volante Pro 3D** (el modelo del dueño reducido de 320 mil a 4.500 triángulos con su textura: `tools/cars/build_cabin_parts.py` → `models/cabin/volante_pro.glb`),
  Rally Gamuza, Carbono y Rojo, Madera Clásico, Cuero Blanco.
- **De fábrica según el auto**: el patrullero trae «Patrulla»; el monoplaza, «Carbono» y el Volante Pro; el STRIX, el volante «Carbono y Rojo». Los demás conservan el habitáculo aprobado (no se cambió ninguno).

## Dónde se compran
Taller (garaje → taller → **Pintura**): solapas nuevas **Interior** y **Volante**, y la sección **Diseños exclusivos** debajo de los estilos de la carrocería. Un diseño se prueba en el auto sin pagar
(se ve en la sala); la plata se pide al tocar COMPRAR. Interior y volante se ven con las cámaras de adentro. Todo se compra **una vez por auto**; después se cambia gratis.

## Economía (servidor)
Cada compra es un `buy_part` de la cuenta (igual que las piezas): el servidor valida el id y el precio contra `online_cat_parts` y lo guarda en el auto (`cars[id].parts`). Al sincronizar, el juego deja sólo lo que dice el servidor.
Lo elegido vive en la pintura del auto (`paint.interior`, `paint.steer`, `paint.livery/number`); si algo no es tuyo, se dibuja el de fábrica (`Cosmetics.paint_ok/interior_of/wheel_of`).
**Hace falta aplicar la migración** `supabase/migrations/20261015000000_catalog_28_cosmetics.sql` (flujo «Supabase · aplicar migraciones»): suma los cosméticos y los dos autos nuevos (Interceptor y STRIX) al catálogo del servidor.
Sin la migración el servidor rechaza esas compras y las devuelve. Si cambia un precio: editar `cosmetics.json` y correr `tools/online/cosmetics_migration.py`.

## Pruebas
`tests/cosmetics_test.gd` (compra, evento al servidor, lo no comprado no se dibuja, valores de fábrica, exclusivos, la cabina arma los 8 × 6 combinaciones, precios iguales a la migración);
`menu_ui_test` (las tres pantallas del taller con su barra de COMPRAR). Vistas: `tests/_liv.gd` (los 8 patrones en un auto) y `CAB_TRIM=cab_carbono,vol_pro tests/_cabview.gd` (cabina).
