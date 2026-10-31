extends Node
## Prova per tools/ci/morbidezza_operatori.py (--prova): le static var e il _static_init di una classe interna.


class Dentro:
	static var _quarto := 1.0 / 4.0  # A RISCHIO
	static var _ok := 2

	static func _static_init() -> void:  # A RISCHIO
		_quarto = _quarto * 2.0
