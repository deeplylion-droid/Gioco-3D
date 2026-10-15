class_name AudioLoop
extends Node3D
## Un suono continuo (fondo, motore, ronzio) con volume e tono che si muovono morbidi.
## Si accende da solo quando [member volume] sale sopra zero e si ferma quando torna a zero,
## ripartendo da un punto a caso del loop (così più sorgenti uguali non suonano all'unisono).
## Con [code]in_3d = true[/code] è un AudioStreamPlayer3D posizionato dove sta questo nodo;
## altrimenti un AudioStreamPlayer normale (per i fondi e per i suoni del giocatore).
##
##   var l := AudioLoop.new()
##   l.prepara(stream, &"Effetti", true)
##   turbina.add_child(l)
##   l.volume = 0.8      # 0..1, lineare
##   l.tono = 1.2

## Con il driver audio "Dummy" (headless, test automatici) non esce niente: i suoni allora non
## partono davvero, così all'uscita del programma non restano riproduzioni appese. Lo stato
## (volume, tono, is_suonando) resta giusto. I test possono forzare la riproduzione vera con
## AudioLoop.forza_riproduzione(true).
const _META_FORZA := &"audio_forza_riproduzione"

## Volume voluto, lineare (0 = spento).
var volume := 0.0
## Tono voluto (pitch_scale).
var tono := 1.0
## Quanto in fretta il volume raggiunge quello voluto (1/s).
var rapidita_volume := 6.0
## Quanto in fretta il tono raggiunge quello voluto (1/s).
var rapidita_tono := 4.0
## Volume di base in dB (taratura del suono).
var volume_db_base := 0.0

var player: Node   # AudioStreamPlayer o AudioStreamPlayer3D
var _attuale := 0.0
var _tono_attuale := 1.0
var _finto := false


## Vero se c'è un'uscita audio vera (o se la riproduzione è forzata).
static func riproduzione_attiva() -> bool:
	return bool(Engine.get_meta(_META_FORZA, false)) or AudioServer.get_driver_name() != "Dummy"


## Fa suonare davvero anche senza uscita audio (per i test).
static func forza_riproduzione(attiva: bool) -> void:
	Engine.set_meta(_META_FORZA, attiva)


## Crea il player del loop. [param in_3d]: suono posizionato nello spazio.
func prepara(stream: AudioStream, bus: StringName, in_3d: bool, unit_size := 3.0, max_distance := 30.0) -> void:
	name = "AudioLoop"
	if in_3d:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = unit_size
		p3.max_distance = max_distance
		p3.max_db = 0.0
		p3.attenuation_filter_cutoff_hz = 6000.0
		p3.attenuation_filter_db = -18.0
		player = p3
	else:
		player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = -80.0
	add_child(player)


## Cambia subito volume e tono, senza rampa (per esempio al primo fotogramma).
func salta(nuovo_volume: float, nuovo_tono := -1.0) -> void:
	volume = nuovo_volume
	_attuale = nuovo_volume
	if nuovo_tono > 0.0:
		tono = nuovo_tono
		_tono_attuale = nuovo_tono
	_applica()


func is_suonando() -> bool:
	return player != null and (player.playing or _finto)


## Ferma subito il suono (il volume voluto resta: se è sopra zero riparte al prossimo fotogramma).
func ferma() -> void:
	_attuale = 0.0
	_finto = false
	if player and player.playing:
		player.stop()


func _process(delta: float) -> void:
	if player == null:
		return
	if _attuale <= 0.0005 and not is_suonando():
		# da spento il tono non scivola: quando riparte è già quello voluto
		_tono_attuale = tono
	else:
		_tono_attuale = lerpf(_tono_attuale, tono, 1.0 - exp(-rapidita_tono * delta))
	_attuale = move_toward(_attuale, clampf(volume, 0.0, 2.0), delta * rapidita_volume * maxf(absf(volume - _attuale), 0.05))
	_applica()


func _applica() -> void:
	if _attuale > 0.0005:
		if not is_suonando():
			if riproduzione_attiva():
				var lunghezza: float = player.stream.get_length() if player.stream else 0.0
				player.play(randf() * lunghezza * 0.9 if lunghezza > 0.0 else 0.0)
			else:
				_finto = true
		player.volume_db = volume_db_base + linear_to_db(_attuale)
		player.pitch_scale = clampf(_tono_attuale, 0.05, 4.0)
	elif is_suonando():
		_finto = false
		if player.playing:
			player.stop()
