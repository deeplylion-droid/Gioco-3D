extends RefCounted
## Prova per tools/ci/morbidezza_operatori.py (--prova): costruita da una static var di statica_usa_prova.gd, quando
## quella classe si carica (anche nel thread). Girano i valori dei var e _init.

var quarto := 1.0 / 4.0  # A RISCHIO
var intero := 4


func altra() -> float:
	return quarto * 2.0
