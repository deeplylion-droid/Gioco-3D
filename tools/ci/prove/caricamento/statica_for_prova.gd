extends RefCounted
## Prova per tools/ci/morbidezza_operatori.py (--prova): il for ... in nelle funzioni che girano quando la classe si
## carica non è un operatore (va bene, niente da trovare; falso positivo trovato da enigmi il 31 ottobre).

static var _lista: Array[int] = [1, 2]
static var _somma := _conta()
static var _n := 0


static func _conta() -> int:
	var c := 0
	for k in _lista:
		c = k
	return c


static func _static_init() -> void:
	for k: int in _lista:
		_n = k
