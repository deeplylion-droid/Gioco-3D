extends Resource
## Prova per tools/ci/morbidezza_operatori.py (--prova): uno script di Resource salvato in un .tres (stile_prova.tres) e in
## un .tscn (scena_prova.tscn), quindi costruito nel thread di caricamento. Ogni riga con "# A RISCHIO" deve essere
## trovata, le altre no.

@export var assorbimento := Vector3(0.45, -0.10, 0.07)
@export_range(0.0, 6.0, 0.01) var torbido := 0.06
@export var colore := Color(0.10, 0.45, 0.55)
@export var nome := &"limpida"
@export var piccolo := 1e-6
@export var negativo := -1.0
var doppio := 0.06 * 2.0  # A RISCHIO
var lontano := Vector3.ONE - Vector3(0, 1, 0)  # A RISCHIO
var acceso := true and false  # A RISCHIO
var maschera := 1 << 3  # A RISCHIO
var lista := [  # su più righe si segnala la prima  # A RISCHIO
	1.0,
	2.0 + 1.0,
]
@export var forza := 1.0:  # A RISCHIO
	set(v):
		forza = v
var letto := 0.0: get = _leggi  # A RISCHIO


func _init() -> void:  # A RISCHIO
	pass


func _leggi() -> float:  # A RISCHIO
	return 0.0
