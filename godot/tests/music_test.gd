## La música de los menús: los 9 temas están y cargan; suena sólo cuando corresponde (menús / también jugando / apagada) y a volumen bajo por defecto.
## Uso: godot --headless --path godot --script res://tests/music_test.gd
extends SceneTree

const MusicPlayer := preload("res://game/audio/music_player.gd")

class FakeProfile:
	extends RefCounted
	var s := {"musicMode": "menu", "volMusic": 25, "volume": 80}
	func setting(k: String):
		return s.get(k)

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	_run()

func _run() -> void:
	var pr := FakeProfile.new()
	var mp: Node = MusicPlayer.new()
	mp.profile = pr
	get_root().add_child(mp)
	await process_frame
	check(mp.tracks.size() == 9, "hay 9 temas en tracks.json (%d)" % mp.tracks.size())
	var ids := {}
	var all_load := true
	for t in mp.tracks:
		ids[str(t["id"])] = true
		var st := load("res://game/audio/music/" + str(t["file"])) as AudioStream
		if st == null or st.get_length() < 60.0:
			all_load = false
			print("   no carga o es muy corto:", t["file"])
	check(ids.size() == mp.tracks.size() and all_load, "los temas no se repiten y todos cargan como audio (más de 1 minuto)")
	# cuándo suena
	mp.set_context("menu")
	check(mp.wanted(), "en los menús suena por defecto")
	mp.set_context("game")
	check(not mp.wanted(), "jugando no suena por defecto")
	pr.s["musicMode"] = "always"
	check(mp.wanted(), "con «también jugando» suena jugando")
	pr.s["musicMode"] = "off"
	mp.set_context("menu")
	check(not mp.wanted(), "apagada no suena en los menús")
	pr.s["musicMode"] = "menu"
	pr.s["volMusic"] = 0
	check(not mp.wanted(), "con volumen 0 no suena")
	pr.s["volMusic"] = 25
	check(mp.level_db() < -12.0 and mp.level_db() > -30.0, "volumen de radio por defecto (%.1f dB)" % mp.level_db())
	# arranca solo: se espera el sondeo y un tema al azar empieza
	for i in 40:
		await process_frame
		await create_timer(0.02).timeout
	check(mp.is_playing(), "un tema empieza solo en el menú (%s)" % str(mp.now_title))
	# al pasar a jugar se apaga con un fundido
	mp.set_context("game")
	for i in 200:
		await process_frame
		await create_timer(0.03).timeout
		if not mp.is_playing():
			break
	check(not mp.is_playing(), "al entrar a jugar se apaga")
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
