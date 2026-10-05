# Dream Racing (antes GSkorp Rally) — notas para Claude

- Hablar con el dueño en español rioplatense. Prueba todo desde el APK (GitHub Actions compila cada push a `main`).
- Hoja de ruta y pendientes: `ROADMAP.md`.

## Recordatorios pendientes (avisarle al dueño en la próxima orden)
- Modo aventura: hecho (r26+), detalle en `docs/MODO_AVENTURA.md`. Pedirle al dueño que lo pruebe y diga qué ajustar (ritmo de los rivales, largo de las etapas).
- Dream City (mundo abierto en papel): hecho (base), detalle en `docs/MUNDO_ABIERTO.md`; lo que viene en `docs/PROXIMA_ACTUALIZACION.md`. Pedirle al dueño que lo pruebe desde el APK (¿se ven cerradas las calles? ¿cómo anda en su teléfono?).
- Evolución progresiva (Etapas 1–23): hecha, ver `ROADMAP.md` y `docs/ARQUITECTURA.md`. Pedirle al dueño que pruebe desde el APK: modo online (regalo diario, taller, mercado — `docs/ECONOMIA_ONLINE.md`), peatones, audio ambiente, y FPS con «Mostrar FPS» y «Vida del mundo» SÍ/NO.
- Las migraciones de Supabase se aplican con el flujo «Supabase · aplicar migraciones» (a mano: la variable SUPABASE_AUTODEPLOY está apagada); avisarle al dueño cada vez si salió bien o mal.
- El nombre del proyecto Godot (`config/name`) sigue «GSkorp Rally» a propósito: cambiarlo mueve la carpeta de guardado y se pierde el perfil.
