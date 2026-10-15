class_name Paratia
extends Node
## Una paratia della camera delle onde (tappa 6): alzata finché le pompe non ripartono, poi
## scende e chiude la strada verso il pozzo. Muove il pannello del modello (PARATIA_n, origine sul
## bordo basso) lungo il suo -Y; la collisione è figlia del pannello e scende con lui.

signal chiusa

## Il pannello da far scendere.
@export var pannello_path: NodePath
## Di quanto scende (m) e in quanto tempo (s).
@export var discesa := 2.65
@export var durata := 4.5

var is_chiusa := false
var in_movimento := false

var _pannello: Node3D
var _alto := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
	add_to_group(&"persist")
	_pannello = get_node_or_null(pannello_path) as Node3D
	if _pannello:
		_alto = _pannello.position


## Scende fino in fondo.
func chiudi() -> void:
	if is_chiusa or in_movimento or _pannello == null:
		return
	in_movimento = true
	_t = 0.0


func _physics_process(delta: float) -> void:
	if not in_movimento:
		return
	_t = minf(_t + delta / maxf(durata, 0.01), 1.0)
	# Pesante: parte con uno strappo, scende regolare e si ferma di colpo.
	var k := _t * _t * (3.0 - 2.0 * _t) * 0.35 + _t * 0.65
	_metti(k)
	if _t >= 1.0:
		in_movimento = false
		is_chiusa = true
		chiusa.emit()


func _metti(k: float) -> void:
	# Giù nella scena degli ambienti tecnici (il genitore del pannello non è ruotato).
	_pannello.position = _alto - Vector3.UP * discesa * k


func save_state() -> Dictionary:
	return {"chiusa": is_chiusa}


func load_state(data: Dictionary) -> void:
	if bool(data.get("chiusa", false)) and _pannello:
		is_chiusa = true
		in_movimento = false
		_metti(1.0)
