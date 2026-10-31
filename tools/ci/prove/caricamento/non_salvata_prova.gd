extends Resource
## Prova per tools/ci/morbidezza_operatori.py (--prova): uno script di Resource che nessun .tres o .tscn usa (si crea
## solo con new() sul thread principale): qui funzioni, setter e operatori vanno bene.

var doppio := 0.06 * 2.0
var forza := 1.0:
	set(v):
		forza = v * 2.0


func _init() -> void:
	doppio = doppio + 1.0
