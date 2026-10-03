# Próxima actualización · plan

Dream City sale en la versión 1 con la ciudad base y las rutas hacia otras ciudades **bloqueadas** («PRÓXIMAMENTE»). Esta es la lista de lo que viene, en orden de prioridad.

## 1. Pulido de la ciudad (según lo que diga el dueño al probarla)
- Ajustar alturas, colores y variedad de fachadas; más estilos de edificio (esquinas redondeadas, edificios con bajada de garage, comercios con carteles).
- Más cantidad de barrios con personalidad propia (ahora: centro, grilla, casco viejo, colina, costa, afueras).
- Medir en teléfonos reales (flojos y buenos) y ajustar `view_k`, radio de cuadras y niebla.

## 2. Vida en las calles
- Tránsito de papel (autos que siguen las calles con `CityDriver`), peatones planos, palomas en la plaza.
- Semáforos que funcionan (ciclo rojo/verde) y cruces con prioridad.
- Más objetos rompibles: carteles, conos, puestos de diarios, canteros.

## 3. Garajes, concesionarios y talleres
- ✅ Hecho: ocho locales entrables con puerta de garage (concesionario, pintura, motor, transmisión, suspensión y frenos, ruedas y dos reglajes) y estacionamiento subterráneo.
- Pendiente: menú del taller visto de costado (suspensión y pintura con el auto de perfil) y las piezas de carrocería (alerón, paragolpes…), que las trae el dueño.

## 4. Obras grandes
- ✅ Hecho: túnel subterráneo en cruz (oculto) con cuatro bocas.
- Autovía elevada con tren de alta velocidad y de carga (imágenes), túneles por la montaña, puentes procedurales, campos de girasoles y otros efectos de perspectiva.
- Conexión con la plaza de drift y picadas en las avenidas anchas.

## 5. Otras ciudades (abren las Salidas)
- Cada Salida N (20, 40, 60, 80) conecta con otra ciudad generada con otra semilla y otro estilo. El portón se abre cuando la ciudad existe.
- Conexión con el modo aventura.

## 6. Online
- Servidores de 10–20 jugadores sobre el mismo mapa (semilla compartida): presencia por Supabase Realtime, autos de papel interpolados, objetos rotos por cuadra. Detalle en `docs/MUNDO_ABIERTO.md`.

## 7. Cosas de tienda y legales (antes de publicar)
- Play Console: actualizar la «Seguridad de los datos» (correo, ID de usuario, puntajes) y la URL de eliminación de cuenta.
- Voz del copiloto en el idioma elegido.
- Publicidad y carteles de empresas en la ciudad (más adelante).
