@tool
class_name PowerSource
extends Node3D
## Qualcosa che dà "energia" a porte, vasche e macchinari: turbine, pulsanti...
## Chi la usa legge [member powered] o ascolta [signal powered_changed].

signal powered_changed(is_powered: bool)

var powered := false:
	set(value):
		if value == powered:
			return
		powered = value
		powered_changed.emit(value)


## Vero se almeno una sorgente è accesa.
static func any_powered(sources: Array) -> bool:
	for s in sources:
		if is_instance_valid(s) and s.powered:
			return true
	return false


## Vero se tutte le sorgenti sono accese (e ce n'è almeno una).
static func all_powered(sources: Array) -> bool:
	if sources.is_empty():
		return false
	for s in sources:
		if not is_instance_valid(s) or not s.powered:
			return false
	return true
