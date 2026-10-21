# ¿Qué falta? — lista única de pendientes antes de publicar (actualizada el 21/10/2026)

Para el dueño. Está ordenada: primero lo que **ya está hecho**, después lo que **sólo podés hacer vos**, con el documento donde está el paso a paso.
Regla de siempre: **nada de esto está probado en un teléfono** (desde acá sólo se prueba con pruebas automáticas, capturas y un Postgres de prueba).

## 1. Lo que ya está hecho (por mí)
- Todas las tandas de arreglos del juego, **fusionadas en `main` el 21/10/2026** (commit `e953c9b`; ver `docs/REGISTRO_TECNICO.md`, entradas `[B]` del 19 y 20/10). La compilación de `main` arma el APK normal («Dream Racing», release `godot-apk`); la RC sigue armando «Dream Racing RC» (release `godot-apk-rc`).
- **Modo de prueba guiado** con la voz de Claudio (subtítulos y audio opcional): `docs/GUION_VOZ_GUIA.md`.
- SQL: las 4 migraciones nuevas, su prueba y **su aplicación al servidor real (21/10/2026 00:02 UTC, sin errores; `docs/GUIA_SQL_SUPABASE.md` → «Historial»)**.
- Guías: `docs/GUIA_SQL_SUPABASE.md`, `docs/GUIA_PLAY_CONSOLE_PASO_A_PASO.md`, esta lista; políticas de privacidad y términos; textos de la ficha en 6 idiomas; AAB reproducible con un flujo.

## 2. Probar en el teléfono (APK normal de `main` / «Dream Racing RC»; la primera vez que abras cada una baja los autos de nuevo, ~600 MB, con wifi)
**Descargas directas:** APK normal (versión de `main`, sin herramientas de desarrollo): https://github.com/webmaletin-art/Rally-Sim-movile/releases/download/godot-apk/DreamRacing-liviano.apk · APK de pruebas «Dream Racing RC» (con modo desarrollador y «COPIAR REGISTRO»): https://github.com/webmaletin-art/Rally-Sim-movile/releases/download/godot-apk-rc/DreamRacing-RC.apk. Los dos traen lo mismo del juego; cambia el nombre, el paquete (se instalan uno al lado del otro) y las herramientas.
Hacelo con calma y **anotá qué falla**; con una captura y «dónde» (el 📍 del mapa o el nombre de la calle) lo arreglo.

| Qué | Cómo se prueba | Qué tiene que pasar |
|---|---|---|
| **Modo de prueba (fijo)** | Inicio → baldosa **MODO DE PRUEBA** (aparece después de la configuración gráfica y **queda siempre**) | Guía con voz/subtítulos, armado (podés elegir **MI AUTO**), pista con lomos de burro, punto de nafta, camino de tierra y calles; carrera por puertas; pausa con la guía a la derecha y REGLAJES; **SALIR DE LA PRUEBA** sale con un toque y la baldosa sigue ahí. **Primera vez:** con un perfil nuevo (instalá de cero o borrá los datos de la app), después de la configuración gráfica el inicio te manda solo a la guía del modo de prueba (con «AHORA NO · IR AL MENÚ» para dejarlo) |
| **Pausa: nivel de simulación** | Cualquier carrera menos la Aventura → pausa → NIVEL DE SIMULACIÓN | Pasar de simulación total a arcade se aplica al instante y el auto sigue donde está |
| **Volante real** | Simulación total (o PERSONALIZADO → Volante real) | Hay que girar el dedo de verdad: ¾ de vuelta en Arcade, 1½ en Real 50 %, 3 en Real 100 % |
| **Calles y rutas** | Dream City: Avenida 2 y 3 (cuadras 3 y 6), Ruta 80 (cuadras 4 y 13), esquinas, la X de la Panorámica | Sin pedazos de tierra ni pasto sobre el asfalto, sin paredes invisibles, sin la rampa invisible |
| **Policía** | Pasar un control de ruta y llegar a un pueblo; después cambiar de auto | Al llegar a otro pueblo dejan de perseguirte; si volvés te esperan; con otro auto no te reconocen y la ruta queda libre |
| **Taller** | Taller → una llanta / goma / mejora | **COMPRAR** queda fijo arriba (no hay que desplazar); elegir una rueda no hace saltar la lista |
| **Sin Nitro ni alerones; precios** | Taller y concesionarios | No existen; los autos se agrupan de a 2 o más por precio |
| **Cabinas** | Cámara interior del monoplaza (DR-1) y del buggy | Un solo tablero y un solo volante (el nuestro) |
| **Calidad gráfica** | Opciones → Gráficos | El diálogo entra en pantalla y se desplaza |
| **Versión pública** | Acerca de y Opciones → Sonido en el APK de `main` | La versión es sólo un texto; **no** hay modo desarrollador ni «COPIAR REGISTRO» (sólo en la RC) |

## 3. Servidor (Supabase)
| Qué | Dónde | Estado |
|---|---|---|
| Aplicar las migraciones 20261022 → 20261025120000 | Actions → «Supabase · aplicar migraciones» | ✅ **Hecho** el 21/10/2026 con tu autorización (flujo n.º 35, sin errores). **Falta lo tuyo:** correr en el SQL Editor las 5 consultas de `docs/GUIA_SQL_SUPABASE.md` §4 (30 segundos; desde acá no puedo mirar la base real) |
| «Allow anonymous sign-ins» apagado; «Confirm email» apagado o SMTP propio | Supabase → Authentication | 🖱 **vos** |
| Realtime → «Allow public access» apagado | Supabase → Realtime → Settings | 🖱 **vos** |
| Cuenta de revisión para Google + saldo (`account_admin_grant`) | Juego + SQL Editor | 🖱 **vos** (`docs/CUENTA_Y_ECONOMIA.md`) |
| Publicar la función de compras (`verify-purchase`) y el secreto `GOOGLE_PLAY_SERVICE_ACCOUNT` | GitHub → Actions → «Supabase · publicar funciones» | **vos** (paso 7.9 de la guía de Play) |
| Plan Pro de Supabase antes de abrir el tiempo real | Supabase → Billing | decisión tuya (`docs/COSTOS_ONLINE.md`) |

## 4. Google Play
Todo el camino, con clics, en **`docs/GUIA_PLAY_CONSOLE_PASO_A_PASO.md`**. Lo que más tarda: la **prueba cerrada de 14 días con 12 testers** (empezala apenas haya un AAB que Play acepte).
Pendientes concretos: cuenta de desarrollador y perfil de pagos · «Contenido de la app» (incluida «Seguridad de los datos») · ficha (ajustar la frase del online; la cantidad de autos ya dice 28) · AAB firmado · los 10 productos integrados con sus IDs · prueba interna con compras · prueba cerrada · producción.

## 5. Contenido que sólo vos tenés
- **La voz de Claudio** (opcional, se puede sumar de a poco): 53 líneas en `docs/GUION_VOZ_GUIA.md`; se graban en `godot/game/audio/guide/es/<id>.ogg`. Sin audio se ve el subtítulo.
- **Licencia comercial de la música** (MusicGPT): confirmá que tu plan permite uso comercial; si no, apagamos la música antes de publicar.
- **Logo propio** para el ícono (el «DR» actual es provisorio).
- **Tráiler en YouTube** y las capturas elegidas para la ficha.

## 6. Preguntas que sigo esperando (contestá cuando puedas)
1. **El auto «Ren…»** que se ve feo desde las cámaras internas: ¿cuál es? No existe un auto con ese nombre; las cabinas más rotas son las del **Strix Vandal RS** y el **Chakal Dune R**. ¿Es alguno de ésos?
2. El **«GPS amarillo»** que había que sacar: ¿era la línea o el texto amarillo del GPS en las carreras del mapa?
3. **Monedas «borradas» en otro celular:** ¿qué número veías en cada uno?, ¿el primero tenía el modo desarrollador?, ¿qué APK en cada uno? (No encontré ningún camino que borre créditos del servidor.)
4. La **ficha de Play** dice «online cerrado/próximamente»: ¿mencionamos los eventos y el ranking online?
5. ¿Querés **eventos también en el mundo compartido en tiempo real** cuando se abra (`app_flags.pvp = true`)?
6. ¿Las **carreras con camión** (Colossus Mamut 6x6 y Titán T4) necesitan más sentido? Ver el informe de «vehículos obligatorios» en el registro técnico de hoy.

## 7. Después de publicar
- Prender la cacería para principiantes: `wev_templates` → `caza_inicial` → `enabled = true`.
- Cuando quieras el mundo compartido en tiempo real: `app_flags` → `pvp = true` (sin APK nuevo) y mirar los topes del plan de Supabase.
- Mirar «Android vitals» (cierres y ANR) y las reseñas; pasarme los textos de los cierres.
