extends Node
## Sonidos de interfaz (clic, compra, error, cuenta regresiva, largada, moneda, meta): muestras de sfxPlay() del HTML.

const DIR := "res://game/audio/samples/"
var consts: Dictionary
var players: Dictionary = {}
var volume := 0.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	consts = JSON.parse_string(FileAccess.get_file_as_string(DIR + "consts.json"))
	for n in ["click", "buy", "error", "beep", "go", "coin", "finish"]:
		var p := AudioStreamPlayer.new()
		p.stream = load(DIR + "sfx_" + n + ".wav")
		p.bus = "Master"
		add_child(p)
		players[n] = p

func play(n: String) -> void:
	if not players.has(n):
		return
	var p: AudioStreamPlayer = players[n]
	var c: Dictionary = consts["sfx_" + n]
	p.volume_db = linear_to_db(maxf(float(c["unit"]) * volume * 1.3, 1e-4)) # "unit" = amplitud real del sonido del HTML (la muestra está normalizada a 0,9)
	p.play()
