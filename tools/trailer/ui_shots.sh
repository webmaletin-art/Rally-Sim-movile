#!/bin/bash
# Saca las pantallas del menú en Full HD con el perfil de vitrina (tools/trailer/make_profile.py). Uso: tools/trailer/ui_shots.sh /carpeta_de_salida [pantalla[:argumento][@auto] …]
# Sin pantallas pedidas saca las de siempre. «@id» pone ese auto en la sala (--showcar).
out=${1:-/tmp/trailer/stills/ui}; shift
here="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR=${UI_HOME:-/tmp/tr/home}
python3 "$here/make_profile.py" "$HOME_DIR" >/dev/null
mkdir -p "$out"
G=${GODOT:-/tmp/godot/Godot_v4.4.1-stable_linux.x86_64}
shots=("$@")
if [ ${#shots[@]} -eq 0 ]; then
  shots=(home garage@hyper dealer@veltor_gtr workshop@gt3 tune@rally80 paint@moust career events:debut events:continental quick fantasy adventure adv_stages adv_skills travesia spawn rutas options:graficos options:sonido)
fi
cd "$here/../../godot"
for s in "${shots[@]}"; do
  screen=${s%@*}; car=""; [ "$s" != "$screen" ] && car=${s#*@}
  name=$(echo "$screen" | tr ':' '_')
  args=(--menu --screen=$screen --noconsent --shot=$out/$name.png --frames=${FRAMES:-170})
  [ -n "$car" ] && args+=(--showcar=$car)
  XDG_DATA_HOME="$HOME_DIR" timeout 300 xvfb-run -a -s "-screen 0 1920x1080x24" "$G" --path . --rendering-driver opengl3 --resolution 1920x1080 res://game/main.tscn -- "${args[@]}" 2>&1 | grep -E "SCRIPT ERROR|Parse Error" | head -3
  ls -la "$out/$name.png" 2>/dev/null | awk '{print $5, $9}'
done
