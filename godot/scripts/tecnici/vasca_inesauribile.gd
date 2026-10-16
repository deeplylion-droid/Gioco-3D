class_name VascaInesauribile
extends Node
## Una vasca da cui lo zaino aspira senza mai esaurirla (riscontro della v0.3.1, punto 7: nella sala
## pompe l'acqua non deve finire). Il livello scende davvero mentre si aspira, così si vede che
## l'acqua entra nello zaino, ma non va mai sotto [member minimo]; quando si smette di aspirare
## la vasca torna piano al livello di partenza, rabboccata dai tubi della sala.
## Non tocca WaterTank: corregge il suo [code]fill[/code] dopo ogni passo di fisica.

## La vasca da tenere piena.
@export var vasca: WaterTank
## Livello sotto cui non scende mai, come frazione del livello di partenza.
@export_range(0.1, 1.0) var minimo := 0.6
## Quanto risale al secondo quando non si aspira (frazione del livello di partenza).
@export var rabbocco := 0.08
## Dopo quanti secondi senza aspirare comincia a risalire.
@export var attesa_rabbocco := 1.0

var _pieno := -1.0
var _prima := -1.0
var _ferma := 0.0


func _ready() -> void:
	if vasca:
		_pieno = vasca.fill
		_prima = vasca.fill
	# dopo la vasca: process_physics_priority più alta = più tardi nello stesso passo
	process_physics_priority = 10


## Il livello minimo, come [code]fill[/code] della vasca.
func fill_minimo() -> float:
	return _pieno * minimo


func _physics_process(delta: float) -> void:
	if vasca == null or _pieno <= 0.0:
		return
	var f := vasca.fill
	if f < _prima - 1e-6:
		_ferma = 0.0
	else:
		_ferma += delta
	if f < fill_minimo():
		f = fill_minimo()
	elif _ferma >= attesa_rabbocco and f < _pieno:
		f = minf(_pieno, f + _pieno * rabbocco * delta)
	if f != vasca.fill:
		vasca.fill = f
	_prima = vasca.fill
