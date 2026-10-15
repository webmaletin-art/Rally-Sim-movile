extends Node
## RESOLUCIÓN DE FRAME (la usa el perfil gráfico calibrado, Opciones → Gráficos, y el menú 📊 para medir): dibuja TODO el cuadro 2D (el mundo 3D ya reducido por ESCALA 3D + el HUD + los menús + el propio 📊)
## en una superficie interna más chica y después la estira a la pantalla. La pantalla/ventana de Android sigue igual (p. ej. 2400×1080).
## Cómo: una SubViewport "frame" del tamaño elegido, con size_2d_override = el tamaño lógico de la ventana (1280×576 en este proyecto): todo se arma y se toca en las mismas
## coordenadas de siempre. Cada CanvasLayer (mundo 3D, HUD, diagnóstico) se redirige a esa SubViewport con `custom_viewport` (no se mueve ningún nodo de lugar) y una
## capa en la ventana muestra su textura a pantalla completa. Los toques siguen llegando a la ventana con las coordenadas lógicas de siempre: no hace falta reenviarlos.
## NATIVA = nada de esto está activo (los CanvasLayer dibujan directo en la ventana, como antes, y la SubViewport no se renderiza).
## No cambia ESCALA 3D (el mundo 3D sigue midiendo pantalla × escala; no depende de esta opción).

## [porcentaje, 100, nombre]: tamaño = pantalla × porcentaje (en 2400×1080: 2400×1080 · 1992×896 · 1608×724 · 1200×540 · 960×432). Se calcula siempre sobre la pantalla real y conserva su relación de aspecto
const LEVELS := [[100, 100, "NATIVA"], [83, 100, "ALTA"], [67, 100, "MEDIA"], [50, 100, "BAJA"], [40, 100, "MUY BAJA"]]

var level := 0
var sub: SubViewport
var show_layer: CanvasLayer
var rect: TextureRect
var _moved: Array = [] # CanvasLayer redirigidos (para devolverlos a la ventana)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sub = SubViewport.new()
	sub.name = "FrameViewport"
	sub.size = Vector2i(64, 64)
	sub.disable_3d = true # sólo 2D: el mundo 3D sigue en su propia SubViewport
	sub.transparent_bg = false
	sub.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sub.canvas_item_default_texture_filter = get_tree().root.canvas_item_default_texture_filter
	sub.size_2d_override_stretch = true
	add_child(sub)
	show_layer = CanvasLayer.new()
	show_layer.layer = 1
	show_layer.visible = false
	add_child(show_layer)
	rect = TextureRect.new()
	rect.texture = sub.get_texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_layer.add_child(rect)
	get_tree().root.size_changed.connect(_resize)

func screen_size() -> Vector2i:
	return Vector2i(DisplayServer.window_get_size())

## Tamaño del frame para el nivel i de una pantalla de `screen` píxeles (proporcional: ambos lados × el mismo porcentaje)
static func size_for(screen: Vector2i, i: int) -> Vector2i:
	var l: Array = LEVELS[clampi(i, 0, LEVELS.size() - 1)]
	var k := float(l[0]) / float(l[1])
	return Vector2i(maxi(2, int(round(float(screen.x) * k))), maxi(2, int(round(float(screen.y) * k))))

static func fraction_of(i: int) -> float:
	var l: Array = LEVELS[clampi(i, 0, LEVELS.size() - 1)]
	return float(l[0]) / float(l[1])

func size_of(i: int) -> Vector2i:
	return size_for(screen_size(), i)

func name_of(i: int) -> String:
	return str((LEVELS[i] as Array)[2])

## Tamaño REAL de la superficie del frame ahora: la textura de la SubViewport si está activa; si no, la pantalla (se dibuja directo en la ventana)
func actual_size() -> Vector2i:
	if level > 0:
		return Vector2i(sub.get_texture().get_size())
	return screen_size()

func set_level(i: int) -> void:
	i = clampi(i, 0, LEVELS.size() - 1)
	if i == level:
		return
	level = i
	if level == 0:
		_deactivate()
	else:
		_activate()

func _activate() -> void:
	_resize()
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	show_layer.visible = true
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		_redirect(n as CanvasLayer)

func _deactivate() -> void:
	if not is_inside_tree():
		return
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	for cl in _moved:
		if is_instance_valid(cl):
			(cl as CanvasLayer).custom_viewport = get_tree().root # de vuelta a la ventana (con null Godot 4.4.1 deja la capa sin dibujar)
			if (cl as CanvasLayer).tree_exiting.is_connected(_on_layer_exiting):
				(cl as CanvasLayer).tree_exiting.disconnect(_on_layer_exiting)
	_moved.clear()
	if sub != null:
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if show_layer != null:
		show_layer.visible = false

func _redirect(cl: CanvasLayer) -> void:
	if level == 0 or cl == show_layer or _moved.has(cl) or not is_instance_valid(cl) or not cl.is_inside_tree():
		return # (level 0: un _redirect diferido que llega después de apagar el frame no debe mandar la capa a la SubViewport)
	cl.custom_viewport = sub
	_moved.append(cl)
	if not cl.tree_exiting.is_connected(_on_layer_exiting):
		cl.tree_exiting.connect(_on_layer_exiting.bind(cl), CONNECT_ONE_SHOT)

## Una capa redirigida se va del árbol (la pantalla de carga al terminar de cargar, un aviso, la carrera entera): se la devuelve a la ventana
## ANTES de que salga. Godot conecta `child_order_changed` del padre con el viewport en el que la capa ENTRÓ (la ventana) y al salir desconecta con
## el viewport que tenga en ese momento: si seguía en el frame, desconectaba algo que no existe («Attempt to disconnect a nonexistent connection from
## 'App' … child_order_changed», en todos los registros del 14/10) y la capa quedaba apuntando a una SubViewport que se borra con la carrera.
func _on_layer_exiting(cl: CanvasLayer) -> void:
	_moved.erase(cl)
	if is_instance_valid(cl) and cl.is_inside_tree() and cl.custom_viewport == sub:
		cl.custom_viewport = cl.get_tree().root

func _on_node_added(n: Node) -> void:
	if level > 0 and n is CanvasLayer:
		_redirect.call_deferred(n as CanvasLayer) # una capa nueva (aviso, pausa…) también se dibuja en el frame

func _resize() -> void:
	if level == 0 or sub == null:
		return
	var logical := Vector2i(get_tree().root.get_visible_rect().size)
	sub.size = size_of(level)
	sub.size_2d_override = logical
	rect.position = Vector2.ZERO
	rect.size = Vector2(logical)

func _exit_tree() -> void:
	# la carrera se está yendo: cada capa que todavía está en el frame se devuelve sola a la ventana al salir (_on_layer_exiting); las de afuera de la carrera
	# (si alguna quedara) también vuelven acá, para no quedar apuntando a la SubViewport que se borra
	for cl in _moved.duplicate():
		if is_instance_valid(cl) and (cl as CanvasLayer).is_inside_tree() and not (cl as CanvasLayer).is_queued_for_deletion() and not is_ancestor_of(cl) and not get_parent().is_ancestor_of(cl):
			_on_layer_exiting(cl)
	if level > 0:
		level = 0
		if is_inside_tree() and get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.disconnect(_on_node_added)
		_moved.clear()
