extends Node
## Prova per tools/ci/morbidezza_operatori.py (--prova): lo script di un nodo di scena_prova.tscn. Caricare la scena non
## istanzia i nodi: qui le funzioni e gli operatori vanno bene; solo le static var no (girano quando la classe si carica).

static var _cache := {}
static var _vertici := PackedVector3Array()
static var scelta := "A"
static var fase := -1.0
static var _tenuti: Array[Material] = []
static var _nome := &"a+b"
static var lato := 2.0 * 3.0  # A RISCHIO
static var limite := Vector2(1, 2) - Vector2.ONE  # A RISCHIO
static var bit := 1 << 4  # A RISCHIO
static var _pronto := not true  # A RISCHIO
static var _somma := [  # su più righe si segnala la prima  # A RISCHIO
	1,
	1 + 1,
]
static var _da_funzione := _calcola()  # A RISCHIO
static var _da_costante := _costante()
var stile: Resource
var distanza := 2.0 * 3.0


func _ready() -> void:
	var x := 1 + 2
	distanza = x * 2.0


static func _calcola() -> float:
	return 2.0 * 3.0


static func _costante() -> float:
	return 6.0
