class_name Paratia
extends Node
## Uno dei due cancelli stagni (paratie) della camera delle onde (tappe 5-6).
## Riscontro della v0.3.1 (punto 6): all'inizio sono chiusi e si aprono da soli quando il giocatore
## arriva, con un colpo metallico forte (suono "cancello_stagno_apre"); passato il giocatore restano
## aperti. Quando ripartono le pompe (la leva) scendono di nuovo e chiudono la strada verso il pozzo.
## Muove il pannello del modello (PARATIA_n, origine sul bordo basso) lungo il suo Y; la collisione è
## figlia del pannello e si muove con lui.

signal chiusa
## Si è aperta da sola al passaggio del giocatore.
signal aperta

## Il pannello da muovere.
@export var pannello_path: NodePath
## Di quanto scende (m) e in quanto tempo (s) quando le pompe ripartono.
@export var discesa := 2.65
@export var durata := 4.5
## Chiusa all'inizio, si apre da sola quando il giocatore si avvicina.
@export var apri_al_passaggio := true
## Distanza in pianta (m) dal cancello a cui comincia ad aprirsi.
@export var raggio_apertura := 10.0
## Quando si alza rispetto all'inizio del suono (s): parte e sbatte in cima. Di serie quelli dell'audio
## (Audio.CANCELLO_STAGNO_PARTE e _ARRIVA), prima si sentono i chiavistelli e lo sfiato.
@export var apertura_parte := 0.55
@export var apertura_arriva := 2.55
## Il suono dell'apertura (nel catalogo dell'audio).
@export var suono_apertura := &"cancello_stagno_apre"

var is_chiusa := false
var is_aperta := false
## Vero mentre scende (l'audio ci suona motore e catene).
var in_movimento := false
## Vero mentre si alza: il suo colpo metallico ([member suono_apertura]) basta, niente catene.
var in_salita := false

var _pannello: Node3D
var _alto := Vector3.ZERO
var _t := 0.0
var _tempo := 0.0


func _ready() -> void:
	add_to_group(&"persist")
	_pannello = get_node_or_null(pannello_path) as Node3D
	var audio := get_node_or_null(^"/root/Audio")
	if audio and audio.get_script():
		var c: Dictionary = (audio.get_script() as Script).get_script_constant_map()
		apertura_parte = float(c.get("CANCELLO_STAGNO_PARTE", apertura_parte))
		apertura_arriva = float(c.get("CANCELLO_STAGNO_ARRIVA", apertura_arriva))
	if _pannello:
		_alto = _pannello.position
		if apri_al_passaggio:
			_metti(1.0)
		else:
			is_aperta = true


## Scende fino in fondo (le pompe sono ripartite): dopo non si apre più.
func chiudi() -> void:
	if is_chiusa or _pannello == null:
		return
	if in_salita:
		# Stava salendo proprio adesso: riparte da dov'è.
		_t = 1.0 - _t
	elif in_movimento:
		return
	else:
		_t = 0.0 if is_aperta else 1.0
	in_salita = false
	in_movimento = true


## Si alza (da sola, quando arriva il giocatore).
func apri() -> void:
	if is_aperta or is_chiusa or in_movimento or in_salita or _pannello == null:
		return
	in_salita = true
	_t = 0.0
	_tempo = 0.0
	_suona()


func _physics_process(delta: float) -> void:
	if not in_movimento and not in_salita:
		if apri_al_passaggio and not is_aperta and not is_chiusa and _vicino():
			apri()
		return
	if in_salita:
		_tempo += delta
		var corsa := maxf(apertura_arriva - apertura_parte, 0.1)
		_t = clampf((_tempo - apertura_parte) / corsa, 0.0, 1.0)
		_metti(1.0 - _profilo_salita(_t * corsa, corsa))
		if _t >= 1.0:
			in_salita = false
			is_aperta = true
			aperta.emit()
		return
	_t = minf(_t + delta / maxf(durata, 0.01), 1.0)
	# Pesante: parte con uno strappo, scende regolare e si ferma di colpo.
	var k := _t * _t * (3.0 - 2.0 * _t) * 0.35 + _t * 0.65
	_metti(k)
	if _t >= 1.0:
		in_movimento = false
		is_chiusa = true
		is_aperta = false
		chiusa.emit()


## Quanta strada ha fatto salendo (0..1) dopo [param t] secondi su [param corsa]: uno strappo, a
## velocità piena dopo 0,4 s, frena appena nell'ultimo quarto di secondo e sbatte in cima.
static func _profilo_salita(t: float, corsa: float) -> float:
	var a := minf(0.4, corsa * 0.4)
	var b := minf(0.25, corsa * 0.2)
	var v_fine := 0.5
	var totale := a * 0.5 + (corsa - a - b) + b - (1.0 - v_fine) * b * 0.5
	var s: float
	if t < a:
		s = t * t / (2.0 * a)
	elif t < corsa - b:
		s = a * 0.5 + (t - a)
	else:
		var u := minf(t, corsa) - (corsa - b)
		s = a * 0.5 + (corsa - a - b) + u - (1.0 - v_fine) * u * u / (2.0 * b)
	return clampf(s / totale, 0.0, 1.0)


## Vero quando il giocatore è entro [member raggio_apertura] in pianta dal cancello.
func _vicino() -> bool:
	var p := GameState.player
	if p == null or not is_instance_valid(p) or _pannello == null:
		return false
	var genitore := _pannello.get_parent() as Node3D
	var c := genitore.to_global(_alto) if genitore else _pannello.global_position
	var d := p.global_position - c
	return Vector2(d.x, d.z).length() < raggio_apertura and absf(d.y + discesa * 0.5) < 3.0


func _metti(k: float) -> void:
	# Giù nella scena degli ambienti tecnici (il genitore del pannello non è ruotato).
	_pannello.position = _alto - Vector3.UP * discesa * k


func _suona() -> void:
	var audio := get_node_or_null(^"/root/Audio")
	if audio and _pannello:
		audio.call(&"suona", suono_apertura, _pannello.global_position + Vector3.UP * 1.0)


func save_state() -> Dictionary:
	return {"chiusa": is_chiusa, "aperta": is_aperta}


func load_state(data: Dictionary) -> void:
	if _pannello == null:
		return
	in_movimento = false
	in_salita = false
	is_chiusa = bool(data.get("chiusa", false))
	is_aperta = not is_chiusa and bool(data.get("aperta", not apri_al_passaggio))
	_metti(0.0 if is_aperta else 1.0)
