## «Cuenta obligatoria» (Release.ACCOUNT_REQUIRED): para jugar hay que iniciar sesión, también sin conexión. La pared de «iniciá sesión» sólo aparece con Supabase configurado, sin sesión y sin modo desarrollador;
## sin Supabase (o con el modo desarrollador de las compilaciones de prueba) el juego anda todo local.
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
	check(Release.ACCOUNT_REQUIRED == true, "de fábrica HAY que iniciar sesión para jugar")
	check(Release.login_wall(pr, on), "Supabase configurado y sin cuenta: hay pared de «iniciá sesión»")
	check(MenuAccount.should_offer(pr, on), "el juego ofrece la cuenta al abrir")
	check(Release.account_mode(pr, on), "con Supabase la economía (créditos, autos, compras) es del servidor")
	on.account = true
	check(not Release.login_wall(pr, on), "con la cuenta ya iniciada no hay pared (y después anda sin conexión)")
	check(Release.account_mode(pr, on), "…y la economía sigue siendo de la cuenta")
	on.account = false
	on.ok_cfg = false
	check(not Release.login_wall(pr, on), "sin Supabase configurado no hay pared (no se puede iniciar sesión)")
	check(not Release.account_mode(pr, on), "…y la economía es local")
	on.ok_cfg = true
	var dev := FakeProfile.new()
	dev.s["dev"] = true
	if Release.store():
		check(Release.login_wall(dev, on), "en la versión de Play el modo desarrollador no existe: sigue la pared")
	else:
		check(not Release.login_wall(dev, on) and not Release.account_mode(dev, on), "con el modo desarrollador (sólo compilaciones de prueba) no hay pared y la economía es local")
	check(not Release.login_wall(null, null), "sin app.online no hay pared")
	check(not Release.login_wall(pr, on, false), "(`required` apagado en las pruebas: sin pared)")
	check(Release.ACCOUNT_GRACE_DAYS >= 3 and Release.ACCOUNT_GRACE_DAYS <= 30, "los días de gracia sin conexión son razonables (%d)" % Release.ACCOUNT_GRACE_DAYS)
	on.queue_free()
	print("LOGIN_WALL_TEST ", "FALLÓ" if fail else "OK")
	quit(1 if fail else 0)
