extends RefCounted
## Prova per tools/ci/morbidezza_operatori.py (--prova): _static_init su una riga sola, con un operatore.

static var _n := 0


static func _static_init() -> void: _n = _n + 1  # A RISCHIO
