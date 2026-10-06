# Configuración gráfica automática (perfil calibrado y FIJO)

Objetivo: **la mayor calidad visual que el teléfono pueda sostener de forma estable (~60 FPS)**, elegida UNA vez y dejada fija. No hay resolución dinámica ni adaptación por FPS durante la partida.

## Flujo
- **Primer arranque** (después del aviso legal / cuenta, al llegar al menú principal): aviso «⚙️ CONFIGURACIÓN AUTOMÁTICA» → **CONTINUAR** → calibración («⚙️ OPTIMIZANDO RENDIMIENTO…») → «✓ CONFIGURACIÓN COMPLETADA» → **JUGAR** (guarda el perfil y vuelve al menú).
- **Arranques siguientes**: se carga el perfil guardado y se aplica; no se calibra.
- **RECALIBRAR RENDIMIENTO**: Opciones → Gráficos (sólo en el menú principal). Mismo aviso → calibración → resultado → vuelve a Opciones → Gráficos, en Automático.
- Se recalibra sólo si: el jugador lo pide, el perfil guardado es de otra pantalla/GPU (`gfx.sig` = ventana real + GPU) o de una `Autotune.VERSION` anterior.

## Qué es un perfil
`autotune.gd`. Una **escalera de 8 perfiles**, de más a menos calidad: `[nivel de RESOLUCIÓN DE FRAME, nivel de EFECTOS]`:

| # | Frame | Efectos | Nombre |
|---|---|---|---|
| 0 | 100 % | ALTO (TIERS[2]: partículas 10, texturas altas, árboles 4500, sombras) | ALTO |
| 1 | 100 % | MEDIO (TIERS[1]) | MEDIO |
| 2 | 83 % | MEDIO | MEDIO |
| 3 | 67 % | MEDIO | MEDIO |
| 4 | 67 % | BAJO (TIERS[0]) | BAJO |
| 5 | 50 % | BAJO | BAJO |
| 6 | 40 % | BAJO | BAJO |
| 7 | 40 % | MUY BAJO (partículas 2, árboles 1000) | MUY BAJO |

- **RESOLUCIÓN DE FRAME** = la que ya existía (`ui/frame_res.gd`: todo el cuadro 2D, HUD incluido, en una SubViewport interna que se estira a la pantalla). Los niveles son **proporcionales a la pantalla real** (100 / 83 / 67 / 50 / 40 %, ambos lados, mismo aspecto): 2400×1080 → 1992×896 · 1608×724 · 1200×540 · 960×432; 1920×1080 → 1594×896 · 1286×724 · 960×540 · 768×432.
- **ESCALA 3D** = la de siempre (`race.res_scale`; mundo 3D = pantalla × escala). El perfil la fija en `min(0,8, % del frame)`: nunca se dibuja el mundo a más resolución que el cuadro que lo muestra.
- **Efectos** = los TIERS que ya existían (partículas, texturas, árboles, sombras y alcance de la vista de la ciudad vía `autoTier`) más un nivel más bajo. Primero se bajan los efectos secundarios y recién después la resolución.
- No se tocan: vida del mundo, clima, efectos de cámara, calidad de modelo (sólo existe como opción de depuración), HUD, física, mapas, streaming, shaders.

## La calibración (`ui/calibration.gd`, dentro de una carrera de Dream City, `cfg.calib`)
- Zona de prueba: **centro del pueblo** (el spot «CENTRO DEL PUEBLO» de `diag_spots.gd`: el de mayor carga de píxeles), de día y despejado, con el HUD real, tránsito, peatones, edificios, árboles, niebla y horizonte.
- Búsqueda binaria sobre la escalera: se prueban **3 ó 4 escalones**. Por escalón: se aplica el perfil por los mismos ajustes de siempre, **2,5 s de estabilización** (4 s el primero; no cuentan), **5 s de medición** de la duración de cada cuadro (los tirones cuentan).
- **Estable** = promedio ≥ 95 % del objetivo (57 de 60) **y** piso (el 5 % peor de los cuadros) ≥ 80 % del objetivo (48). Un pico no alcanza: 60 de promedio con caídas a 40 NO es estable.
- Se elige el escalón de **mayor calidad estable**. Nunca vuelve a subir. Si ni el último escalón es estable, se elige el de mayor calidad entre los medidos que rinda cerca del mejor rendimiento logrado (no se promete 60). Objetivo = 60 FPS o la frecuencia de la pantalla si es menor.

## Dónde se guarda
Perfil del jugador (`profile.gd`): los ajustes «auto…» que el juego ya leía en «Automático» (`autoFrame`, `autoRes`, `autoParticles`, `autoTex`, `autoTrees`, `autoShadows`, `autoTier`) + el registro `gfx` (pantalla, dispositivo, perfil, % de frame, escala 3D, FPS medidos, probes, `locked`, `version`, `sig`). `gfxMode`: `auto` / `manual`.

## En Opciones → Gráficos (menú normal; sin menú técnico)
- **Configuración gráfica**: Automática (perfil calibrado, todo en «auto») / Manual (elegís cada opción; tocar una pasa sola a Manual).
- **Resolución de frame**: Automática / 100 / 83 / 67 / 50 / 40 %. **Resolución del 3D**: la de siempre; «Automática» ahora es la escala FIJA del perfil (ya no se adapta por FPS).
- **🔄 RECALIBRAR RENDIMIENTO** + una línea «Perfil calibrado: …».

## Diagnóstico (📊, separado)
Sigue siendo la herramienta técnica; no aparece en Opciones. Muestra PANTALLA / FRAME / ESCALA FRAME / ESCALA 3D / MUNDO 3D / PERFIL / PARTÍCULAS / EFECTOS / FPS CALIBRACIÓN / OBJETIVO / PERFIL BLOQUEADO / MODO, también en capturas y «COPIAR TODO». El botón PERFIL de ESCALA 3D = la escala fija del perfil.
