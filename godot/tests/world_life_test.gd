## Comprobación corta del núcleo de World Life (sin escena, sin red): reloj, semilla, determinismo, ON/OFF/ON, reconstrucción y sectores.
## Uso: godot --headless --script res://tests/world_life_test.gd
extends SceneTree

const WorldLife := preload("res://game/world/world_life.gd")
const WorldSeed := preload("res://game/world/world_seed.gd")
const WorldClock := preload("res://game/world/world_clock.gd")
const WorldLifeSystem := preload("res://game/world/world_life_system.gd")

var fails := 0

class FakeProfile:
	extends RefCounted
	var d := {}
	func setting(k: String):
		return {"quality": "auto", "autoTier": 1}.get(k)
	func save() -> void:
		pass

## Un sistema de prueba: «instancia» una entidad por sector activo (derivada de la semilla) y cuenta las llamadas
class Probe:
	extends "res://game/world/world_life_system.gd"
	var alive := {}
	var updates := 0
	var enables := 0
	var disables := 0
	func _init() -> void:
		system_id = "probe"
		update_hz = 10.0
	func enable() -> void:
		enables += 1
	func disable() -> void:
		disables += 1
		alive.clear()
	func rebuild() -> void:
		alive.clear()
		for s in wl.sectors.active:
			alive[s] = WorldSeed.hash_ints(wl.state.system_seed("probe"), s.x, s.y, int(floor(wl.clock.now() / 60.0)))
	func on_sector_changed() -> void:
		rebuild()
	func update(_dt: float) -> void:
		updates += 1
	func logical_hash() -> int:
		var h := 0
		var keys := alive.keys()
		keys.sort()
		for k in keys:
			h = WorldSeed.combine(h, int(alive[k]))
		return h

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _make(seed_v: int, ver: int, mode_online := true) -> RefCounted:
	var wl = WorldLife.new()
	wl.setup(FakeProfile.new(), 160.0)
	if mode_online:
		wl.apply_server({"world_id": "dream_city", "version": ver, "seed": seed_v, "time": 1000.0, "time_scale": 1.0}, 0.0, true)
	return wl

func _init() -> void:
	# semilla determinista
	check(WorldSeed.hash_ints(123456789012, 3, 4, 5) == WorldSeed.hash_ints(123456789012, 3, 4, 5), "la semilla da siempre lo mismo")
	check(WorldSeed.hash_ints(1, 2) != WorldSeed.hash_ints(2, 1), "las claves importan en el orden")
	var u := WorldSeed.unit(99, 1, 2, 3)
	check(u >= 0.0 and u < 1.0, "unit() entre 0 y 1 (%.4f)" % u)
	check(WorldSeed.hash_ints(4503599627370495, 7) != WorldSeed.hash_ints(4503599627370494, 7), "las semillas grandes (53 bits) distinguen su parte alta y baja")
	var r1 := WorldSeed.rng(5, 1)
	var r2 := WorldSeed.rng(5, 1)
	check(r1.randi() == r2.randi() and r1.randf() == r2.randf(), "el RNG sembrado repite la secuencia")
	# reloj
	var c := WorldClock.new()
	c.set_reference(960.0 * 0.375, 1.0, true) # las 9:00
	c.set_test_time(960.0 * 0.375)
	check(absf(c.hour() - 9.0) < 0.001, "hora = 9:00 (%.3f)" % c.hour())
	c.set_test_time(-1.0)
	c.set_reference(100.0, 1.0, true)
	var t0 := c.now()
	var d := c.correct(t0 + 5.0) # el servidor dice que vamos 5 s atrasados
	check(absf(d - 5.0) < 0.05, "la deriva se mide (%.2f s)" % d)
	check(absf(c.now() - t0) < 0.2, "la corrección NO salta de golpe")
	var before := c.pending_correction()
	for i in 20:
		c.tick(0.1) # 2 s
	check(c.pending_correction() < before and c.pending_correction() > 0.0, "la corrección avanza de a poco (quedan %.2f s)" % c.pending_correction())
	c.correct(c.now() + 500.0)
	check(c.pending_correction() == 0.0 and c.synced, "una diferencia enorme se corta en seco una sola vez")
	# determinismo entre «teléfonos»
	var a = _make(777, 1)
	var b = _make(777, 1)
	var other_seed = _make(778, 1)
	var other_ver = _make(777, 2)
	check(a.state.fingerprint(1234.5) == b.state.fingerprint(1234.5), "mismo id + versión + semilla + tiempo = misma huella")
	check(a.state.fingerprint(1234.5) != a.state.fingerprint(1300.0), "otro tiempo = otra huella")
	check(a.state.fingerprint(1234.5) != other_seed.state.fingerprint(1234.5), "otra semilla = otra huella")
	check(a.state.fingerprint(1234.5) != other_ver.state.fingerprint(1234.5), "otra versión = otra huella (versión y tiempo son independientes)")
	check(a.state.system_seed("traffic") == b.state.system_seed("traffic") and a.state.system_seed("traffic") != a.state.system_seed("parked"), "cada sistema tiene su propia semilla, igual en todos")
	check(a.state.compatible() and not other_ver.state.compatible(), "se detecta una versión de reglas incompatible")
	# offline: usa la semilla local estable
	var prof := FakeProfile.new()
	var off1 = WorldLife.new()
	off1.setup(prof, 160.0)
	var off2 = WorldLife.new()
	off2.setup(prof, 160.0)
	check(off1.state.world_seed != 0 and off1.state.world_seed == off2.state.world_seed and off1.state.world_id == "dream_city_local", "offline: id y semilla locales estables")
	check(off1.state.mode == "offline" and off1.state.world_version >= 1, "offline: modo y versión")
	# ON / OFF / ON con un sistema registrado
	var wl = _make(4242, 1)
	var p := Probe.new()
	wl.register_system(p)
	check(not wl.is_enabled() and p.enables == 0, "arranca apagado hasta que se enciende")
	wl.set_enabled(true)
	check(wl.is_enabled() and p.enables == 1, "ON: el sistema se activa")
	for i in 30:
		wl.update(0.1, Vector2(50.0, 50.0)) # 3 s
	check(p.updates > 0, "ON: el sistema se actualiza (%d veces)" % p.updates)
	check(p.alive.size() > 0, "ON: hay entidades en los sectores activos (%d)" % p.alive.size())
	var h_on: int = wl.logical_hash(5000.0)
	var alive_on := p.alive.size()
	wl.set_enabled(false)
	check(not wl.is_enabled() and p.disables == 1 and p.alive.is_empty(), "OFF: se libera todo lo que instanció el sistema")
	var upd := p.updates
	for i in 30:
		wl.update(0.1, Vector2(50.0, 50.0))
	check(p.updates == upd, "OFF: el sistema no se actualiza (sin trabajo oculto)")
	check(wl.sectors.active.is_empty(), "OFF: el administrador de sectores queda vacío")
	wl.set_enabled(true)
	wl.update(0.1, Vector2(50.0, 50.0))
	check(p.alive.size() == alive_on, "ON otra vez: se reconstruye lo mismo (%d)" % p.alive.size())
	check(wl.logical_hash(5000.0) == h_on, "ON otra vez: el estado lógico reconstruido es idéntico")
	# otro «teléfono» con los mismos datos reconstruye lo mismo
	var wl2 = _make(4242, 1)
	var p2 := Probe.new()
	wl2.register_system(p2)
	wl2.set_enabled(true)
	wl2.update(0.1, Vector2(50.0, 50.0))
	check(wl2.logical_hash(5000.0) == h_on, "otro teléfono con id + versión + semilla + tiempo iguales reconstruye el mismo estado lógico")
	# sincronizar con el servidor con la semilla distinta reconstruye
	var rb: int = wl.rebuilds
	wl.apply_server({"world_id": "dream_city", "version": 1, "seed": 9999, "time": 2000.0, "time_scale": 1.0}, 0.2, false)
	check(wl.rebuilds == rb + 1 and wl.state.world_seed == 9999, "si el servidor trae otra semilla, se reconstruye")
	# sectores y niveles de actividad
	var sm = wl.sectors
	sm.update(Vector2(1000.0, 1000.0))
	var moved: bool = sm.update(Vector2(1000.0 + 200.0, 1000.0))
	check(moved, "cambiar de sector se detecta")
	check(not sm.update(Vector2(1210.0, 1000.0)), "moverse dentro del sector no recalcula nada")
	check(sm.active.size() > 0 and sm.simplified.size() > 0 and sm.logical.size() > 0, "hay sectores activos (%d), simplificados (%d) y lógicos (%d)" % [sm.active.size(), sm.simplified.size(), sm.logical.size()])
	check(sm.level_at(Vector2(1210.0, 1050.0)) == sm.Level.ACTIVE and sm.level_at(Vector2(1210.0 + 5000.0, 1000.0)) == sm.Level.NONE, "niveles por distancia: cerca = activo, lejos = no existe")
	# el costo depende del entorno del jugador, no del mapa
	var total: int = sm.active.size() + sm.simplified.size() + sm.logical.size()
	check(total < 200, "sectores bajo seguimiento: %d (no depende del tamaño del mapa)" % total)
	# perfiles
	wl.set_profile("LOW")
	var low_total: int = 0
	wl.sectors.update(Vector2(0.0, 0.0))
	low_total = wl.sectors.active.size() + wl.sectors.simplified.size() + wl.sectors.logical.size()
	wl.set_profile("HIGH")
	wl.sectors.sector = Vector2i(-99999, -99999)
	wl.sectors.update(Vector2(0.0, 0.0))
	var high_total: int = wl.sectors.active.size() + wl.sectors.simplified.size() + wl.sectors.logical.size()
	check(low_total < high_total and int(wl.state.rules.get("max_active_vehicles", 0)) > 12, "perfiles LOW < HIGH (%d < %d sectores; HIGH %d vehículos)" % [low_total, high_total, int(wl.state.rules.get("max_active_vehicles", 0))])
	print("WORLD_LIFE_TEST %s" % ("OK" if fails == 0 else "FALLÓ (%d)" % fails))
	quit(0 if fails == 0 else 1)
