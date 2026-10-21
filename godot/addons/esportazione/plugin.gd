@tool
extends EditorPlugin
## Registra EsportaSenzaDoppioni (vedi esporta_senza_doppioni.gd).

var _esporta: EditorExportPlugin


func _enter_tree() -> void:
	_esporta = preload("res://addons/esportazione/esporta_senza_doppioni.gd").new()
	add_export_plugin(_esporta)


func _exit_tree() -> void:
	remove_export_plugin(_esporta)
	_esporta = null
