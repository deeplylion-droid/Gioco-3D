class_name AiutoProva
extends RefCounted
## Prova per tools/ci/morbidezza_operatori.py (--prova): costruita con new() da figlia_prova.gd nel thread di caricamento.
## Girano i valori dei var e _init, non le altre funzioni.

var doppio := 2.0 * 2.0  # A RISCHIO
var semplice := 2.0


func _init() -> void:  # A RISCHIO
	pass


func altra() -> int:
	return 1 + 1
