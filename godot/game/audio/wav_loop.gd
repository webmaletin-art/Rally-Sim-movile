extends RefCounted
## Bucle seguro de un AudioStreamWAV (arreglo del 15/10/2026: CAUSA CONFIRMADA de los cierres nativos, ver docs/REGISTRO_TECNICO.md).
## Godot reproduce un bucle hasta la muestra `loop_end` INCLUSIVE (scene/resources/audio_stream_wav.cpp, _mix_internal/decode_samples) y su
## importador nunca deja loop_end más allá de «muestras − 1». El juego ponía loop_end = muestras: en cada vuelta leía UNA muestra después del
## final de los datos; si el sonido terminaba justo en el borde de una página de memoria, Android cerraba el juego (SIGSEGV en el hilo
## «AudioTrack», AudioStreamPlaybackWAV::decode_samples, visto en la lápida del Z2356 con Godot 4.5.1 y 4.7.2).
## Acá se agrega al final una copia de la primera muestra y loop_end = muestras: Godot toca esa copia y sigue desde la muestra 1, así que el
## bucle queda exacto (sin salto) y nunca lee fuera de los datos.

## Deja `w` (ya duplicado) en bucle hacia adelante sobre sus `frames` muestras. Devuelve w.
static func make(w: AudioStreamWAV, frames: int) -> AudioStreamWAV:
	var bpf := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
	var data := w.data
	var plain := w.format == AudioStreamWAV.FORMAT_16_BITS or w.format == AudioStreamWAV.FORMAT_8_BITS
	frames = mini(frames, data.size() / bpf) if plain else frames
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	if plain and frames > 1:
		data.resize(frames * bpf) # (por si el archivo traía algo de más)
		data.append_array(data.slice(0, bpf)) # la primera muestra otra vez, al final
		w.data = data
		w.loop_end = frames
	else:
		w.loop_end = maxi(frames - 1, 0) # (formatos comprimidos: como el importador de Godot)
	return w

## ¿Este bucle lee sólo dentro de los datos? (para las pruebas)
static func safe(w: AudioStreamWAV) -> bool:
	if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		return true
	var bpf := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
	if w.format != AudioStreamWAV.FORMAT_16_BITS and w.format != AudioStreamWAV.FORMAT_8_BITS:
		return true
	return w.loop_end <= w.data.size() / bpf - 1 and w.loop_begin >= 0 and w.loop_begin < w.loop_end
