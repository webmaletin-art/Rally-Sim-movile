## El apodo del jugador es de la CUENTA, no del teléfono (20/10/2026, pedido del dueño: «si abro mi cuenta en otro celu me hace poner un nombre nuevo»):
##  · en un teléfono sin apodo elegido se adopta el que la cuenta ya tiene en el servidor (OnlineSocial.adopt_nick) en vez de pedir uno nuevo;
##  · no se adopta lo vacío, el «Piloto» que el servidor pone solo, un nombre muy corto ni uno que el juego no permite (ahí sí se pide uno);
##  · un teléfono que ya eligió su apodo no lo pisa;
##  · mientras no haya apodo elegido no se manda «Piloto» al servidor (pisaba el nombre de la cuenta): va vacío y el servidor se queda con el que tiene;
##  · la respuesta del servidor (la tabla players) se lee bien y lo raro se ignora.
## Sin red. Uso: godot --headless --path godot --script res://tests/nick_account_test.gd
extends SceneTree

const Online := preload("res://game/online/online.gd")
const OnlineSocial := preload("res://game/online/online_social.gd")
const Profile := preload("res://game/data/profile.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _fresh() -> Profile:
	var p := Profile.new()
	p.d = Profile.default_profile()
	return p

func _init() -> void:
	var saved := FileAccess.get_file_as_string(Profile.PATH) if FileAccess.file_exists(Profile.PATH) else "" # (adopt_nick guarda el perfil: se deja el archivo como estaba)
	# ── la respuesta de la tabla players
	check(Online.parse_name([{"name": "Pepe"}]) == "Pepe", "el nombre sale de la fila de la cuenta")
	check(Online.parse_name([{"name": "  Ana  "}]) == "Ana", "se le sacan los espacios")
	check(Online.parse_name([]) == "" and Online.parse_name(null) == "" and Online.parse_name({"message": "JWT expired"}) == "" and Online.parse_name(["Pepe"]) == "", "sin fila, sin respuesta o con un error: vacío")
	# ── teléfono nuevo con una cuenta que ya tiene apodo
	var p := _fresh()
	check(str(p.d["name"]) == "Piloto" and p.d.get("nickSet", false) != true, "un perfil nuevo no tiene apodo elegido")
	check(not OnlineSocial.adopt_nick(p, ""), "sin nombre en la cuenta: se pide uno")
	check(not OnlineSocial.adopt_nick(p, "Piloto"), "el «Piloto» que el servidor pone solo no cuenta como apodo elegido")
	check(not OnlineSocial.adopt_nick(p, "ab"), "un nombre de 2 letras no se adopta")
	check(not OnlineSocial.adopt_nick(p, "puto123"), "un nombre que el juego no permite no se adopta")
	check(str(p.d["name"]) == "Piloto" and p.d.get("nickSet", false) != true, "…y el perfil queda como estaba")
	check(OnlineSocial.adopt_nick(p, "  Tomi_77 "), "el apodo de la cuenta se adopta (sin espacios sobrantes)")
	check(str(p.d["name"]) == "Tomi_77" and p.d["nickSet"] == true, "…y queda elegido: no vuelve a pedir el nombre")
	# ── un teléfono que ya eligió no se pisa
	check(not OnlineSocial.adopt_nick(p, "Otro"), "un teléfono con apodo elegido no lo cambia por el de la cuenta")
	check(str(p.d["name"]) == "Tomi_77", "…se queda con el suyo")
	# ── lo que se le manda al servidor
	var q := _fresh()
	check(Online.net_name(q) == "", "sin apodo elegido no se manda «Piloto»: va vacío")
	q.d["name"] = "Hernan"
	check(Online.net_name(q) == "", "…aunque el nombre local sea otro, mientras no lo haya elegido en la pantalla del nombre")
	q.d["nickSet"] = true
	check(Online.net_name(q) == "Hernan", "con el apodo elegido va ese")
	check(Online.net_name(null) == "", "sin perfil: vacío")
	# ── ningún envío usa el nombre suelto del perfil (volvería a pisar el de la cuenta)
	var src := FileAccess.get_file_as_string("res://game/online/online.gd")
	check(not ("profile.d.get(\"name\"" in src), "online.gd manda el nombre sólo con net_name()")
	var app_src := FileAccess.get_file_as_string("res://game/app.gd")
	check("eco.sync(Online.net_name(profile))" in app_src, "al entrar al online se manda net_name() (antes «Piloto» pisaba el nombre de la cuenta)")
	if saved != "":
		var f := FileAccess.open(Profile.PATH, FileAccess.WRITE)
		f.store_string(saved)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.PATH))
	quit(1 if fail else 0)
