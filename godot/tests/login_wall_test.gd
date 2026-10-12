## «Iniciar sesión para jugar» (Release.LOGIN_REQUIRED): apagado de fábrica; encendido pide la cuenta sólo si el online está abierto, configurado y no hay sesión.
## Uso: godot --headless --path godot --script res://tests/login_wall_test.gd
extends SceneTree

const Release := preload("res://game/data/release.gd")
const MenuAccount := preload("res://game/ui/menu_account.gd")

class FakeOnline:
	extends Node
	var ok_cfg := true
	var account := false
	func configured() -> bool:
		return ok_cfg
	func is_account() -> bool:
		return account

class FakeProfile:
	extends RefCounted
	var s := {}
	func setting(k: String):
		return s.get(k)

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var on := FakeOnline.new()
	var pr := FakeProfile.new()
	check(Release.LOGIN_REQUIRED == false, "de fábrica NO hace falta iniciar sesión para jugar")
	check(not Release.login_wall(pr, on), "apagado: no hay pared aunque no haya cuenta")
	check(not MenuAccount.should_offer(pr, on), "apagado: el juego no ofrece la cuenta al abrir")
	# encendido: depende de que el online esté abierto
	check(not Release.login_wall(pr, on, true), "encendido pero con el modo online cerrado: no hay pared (no hay a dónde iniciar sesión)")
	# con el modo online abierto (el modo desarrollador lo abre en las compilaciones de prueba)
	var dev := FakeProfile.new()
	dev.s["dev"] = true
	check(Release.login_wall(dev, on, true), "encendido + online abierto + configurado + sin cuenta: hay pared")
	on.account = true
	check(not Release.login_wall(dev, on, true), "con la cuenta ya iniciada no hay pared (y después anda sin conexión)")
	on.account = false
	on.ok_cfg = false
	check(not Release.login_wall(dev, on, true), "sin Supabase configurado no hay pared (no se puede iniciar sesión)")
	check(not Release.login_wall(null, null, true), "sin app.online no hay pared")
	on.queue_free()
	print("LOGIN_WALL_TEST ", "FALLÓ" if fail else "OK")
	quit(1 if fail else 0)
