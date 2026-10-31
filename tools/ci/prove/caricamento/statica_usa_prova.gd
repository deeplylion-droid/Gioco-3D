extends Node
## Prova per tools/ci/morbidezza_operatori.py (--prova): una static var che costruisce un'altra classe, e un _static_init
## senza operatori (va bene).

static var _aiuto := preload("res://statica_prova.gd").new()
static var _pronto := false


static func _static_init() -> void:
	_pronto = true
