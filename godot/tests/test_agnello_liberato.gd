extends Node
## Test: il bambino agnello (bambino_agnello.tscn, con AgnelloFluorescente) istanziato e liberato 3 volte non dà errori
## del renderer. Prima, a ogni liberazione, «Parameter "material" is null» (material_get_instance_shader_parameters):
## la superficie rilasciava la copia del materiale prima di liberare la sua istanza del renderer (test_presa_vera,
## test_strada e test_tappa7, l'agnellino del corridoio C2; uguale su main). Ora AgnelloFluorescente toglie le copie
## dalle superfici prima. A schermo il bambino resta identico (scatto prima e dopo nella stessa posa: 0 pixel diversi).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_agnello_liberato.gd

const GIRI := 3

var _ok := 0
var _ko := 0
var _errori := RaccoltaErrori.new()


## Gli errori del motore e degli script (non gli avvisi).
class RaccoltaErrori extends Logger:
	var errori: Array = []
	var _mutex := Mutex.new()

	func _log_error(function: String, _file: String, _line: int, _code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errori.append("%s: %s" % [function, rationale])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func copia() -> Array:
		_mutex.lock()
		var c := errori.duplicate()
		_mutex.unlock()
		return c


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	OS.add_logger(_errori)
	for k in GIRI:
		var n := (load("res://scenes/creature/bambino_agnello.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(n)
		for i in 5:
			await get_tree().process_frame
		var luminose := 0
		for f in n.find_children("*", "AgnelloFluorescente", true, false):
			luminose += (f.get(&"_materiali") as Array).size()
		check(luminose > 0, "giro %d: il bambino agnello ha le sue copie dei materiali luminosi (%d)" % [k + 1, luminose])
		n.queue_free()
		for i in 3:
			await get_tree().process_frame
	var errori := _errori.copia()
	check(errori.is_empty(), "istanziato e liberato %d volte: nessun errore (%s)" % [GIRI, "; ".join(errori)])
	OS.remove_logger(_errori)
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
