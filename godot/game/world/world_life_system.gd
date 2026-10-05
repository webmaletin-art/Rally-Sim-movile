extends RefCounted
## Molde de un sistema de vida (tráfico, estacionados, semáforos, peatones, eventos…). World Life los registra y les avisa; cada sistema decide qué hace.
## Un sistema NUNCA guarda miles de entidades en un archivo: calcula su estado con reglas + semilla + tiempo (ver world_state.system_seed y world_seed).

var wl # WorldLife que lo registró
var system_id := "system"
var update_hz := 10.0 # cuántas veces por segundo se actualiza (WorldLife respeta esto)

## Se llama al registrarlo
func setup(p_wl) -> void:
	wl = p_wl

## World Life pasó a ON: crear lo que haga falta
func enable() -> void:
	pass

## World Life pasó a OFF: liberar TODO lo que este sistema instanció o dejó andando
func disable() -> void:
	pass

## Reconstruir el estado lógico desde reglas + semilla + tiempo (al activar, o cuando cambia la semilla/versión tras sincronizar con el servidor)
func rebuild() -> void:
	pass

## El jugador cambió de sector: reevaluar qué instanciar y qué soltar (wl.sectors tiene las listas)
func on_sector_changed() -> void:
	pass

## Paso de simulación (sólo con World Life ON), con el dt acumulado desde la última vez
func update(_dt: float) -> void:
	pass

## Un número que resume el estado lógico (para comprobar que dos teléfonos reconstruyen lo mismo)
func logical_hash() -> int:
	return 0

func stats() -> Dictionary:
	return {}
