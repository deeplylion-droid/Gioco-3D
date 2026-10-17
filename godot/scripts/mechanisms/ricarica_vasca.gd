class_name RicaricaVasca
extends Node
## Una vasca che si riempie di nuovo da sola: quando smetti di aspirare, dopo [member attesa]
## secondi l'acqua risale piano fino al livello che aveva all'inizio (o a [member livello]).
## Per la vaschetta lava-piedi davanti ai tornelli (riscontro sulla v0.3.1: "deve riempirsi di nuovo
## se finisci l'acqua"). Va messo come figlio della vasca (WaterTank) o la si sceglie con
## [member vasca]. Il livello della vasca si salva già con i checkpoint: qui non c'è altro stato.

## La vasca (vuoto: il genitore).
@export var vasca: WaterTank
## Fin dove risale (riempimento della vasca, 0..1); negativo: quello che ha all'inizio.
@export var livello := -1.0
## Secondi dopo l'ultimo calo (aspirazione) prima che l'acqua cominci a risalire.
@export var attesa := 2.0
## Secondi per risalire da vuota fino al livello.
@export var durata := 25.0

var _livello := 0.0
var _prima := 0.0
var _fermo := 0.0


func _ready() -> void:
	if vasca == null:
		vasca = get_parent() as WaterTank
	if vasca == null:
		set_physics_process(false)
		return
	_livello = livello if livello >= 0.0 else vasca.fill
	_prima = vasca.fill


func _physics_process(delta: float) -> void:
	if not is_instance_valid(vasca):
		return
	var ora := vasca.fill
	if ora < _prima - 0.000001:
		# Sta scendendo (lo zaino aspira): si riparte ad aspettare.
		_fermo = 0.0
	else:
		_fermo += delta
	if _fermo >= attesa and ora < _livello:
		ora = minf(ora + _livello * delta / maxf(durata, 0.01), _livello)
		vasca.fill = ora
	_prima = vasca.fill


## Il livello fin dove risale (riempimento).
func get_livello() -> float:
	return _livello
