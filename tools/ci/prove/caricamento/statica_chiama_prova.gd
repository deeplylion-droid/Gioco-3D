extends RefCounted
## Prova per tools/ci/morbidezza_operatori.py (--prova): _static_init che chiama una funzione dello stesso script con
## un operatore (anche dentro il for), e un _static_init su una riga sola.

static var _n := 3


static func _static_init() -> void:  # A RISCHIO
	_prepara()


static func _prepara() -> void:
	for i in _n - 1:
		_n = i
