extends Node
## Collaudo 0.3.24 (gli ERROR di test_torre): il passo 0 di test_torre (la torre costruita a pezzi, nascosta, tolta
## dopo 3 fotogrammi, poi una seconda torre) ripetuto [giri] volte, con quello che gira nei thread nel momento
## dell'instantiate della seconda: lo stato dei caricamenti chiesti dalla prima torre (SalaTorre._precarica, coi
## load_threaded_request di Game.carica_in_thread) e degli altri caricamenti del gioco (torre, tunnel). Conta gli errori
## del log fra prima e dopo ogni instantiate (ST:). Gira col renderer finto (--headless) o con Vulkan sotto xvfb.
## Uso: godot ... --script res://tests/run.gd -- res://tests/collaudo/sonda_torre_thread.gd [giri]

const TORRE := "res://scenes/sala/torre/sala_torre.tscn"


class Errori extends Logger:
	var errori: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		errori.append("%s %s:%d %s %s" % [function, file, line, code, rationale])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func copia() -> Array:
		_mutex.lock()
		var c := errori.duplicate()
		_mutex.unlock()
		return c


var _errori := Errori.new()


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


static func _stato(percorso: String) -> String:
	match ResourceLoader.load_threaded_get_status(percorso):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return "in corso"
		ResourceLoader.THREAD_LOAD_LOADED:
			return "caricato (non ancora preso)"
		ResourceLoader.THREAD_LOAD_FAILED:
			return "fallito"
	return "nessuno"


func _run() -> void:
	OS.add_logger(_errori)
	var a := OS.get_cmdline_user_args()
	var giri := int(a[1]) if a.size() > 1 else 5
	print("ST: renderer %s, giri %d" % [RenderingServer.get_current_rendering_driver_name(), giri])
	var con_errori := 0
	for g in giri:
		var genitore := Node3D.new()
		get_tree().root.add_child(genitore)
		var tp: SalaTorre = (load(TORRE) as PackedScene).instantiate()
		tp.costruzione_a_pezzi = true
		tp.visible = false
		genitore.add_child(tp)
		tp.costruisci_a_pezzi(1.0)
		await _frames(3)
		var chiesti: Dictionary = (tp.get(&"_precarica") as Dictionary).duplicate()
		get_tree().root.remove_child(genitore)
		await _frames(10)
		# il momento dell'instantiate della seconda torre
		var stati := {}
		for p in chiesti:
			var s := _stato(String(p))
			stati[s] = int(stati.get(s, 0)) + 1
		var in_corso: Array = chiesti.keys().filter(func(p): return _stato(String(p)) == "in corso")
		var altri := {}
		for p in [TORRE, "res://scenes/sala/sottomarino/sala_sottomarino.tscn"]:
			altri[p.get_file()] = _stato(p)
		var prima := _errori.copia().size()
		var t2: SalaTorre = (load(TORRE) as PackedScene).instantiate()
		var errori := _errori.copia().slice(prima)
		print("ST: giro %d: alla seconda instantiate i %d caricamenti chiesti dalla prima torre: %s; in corso %s; altri %s; errori nell'instantiate %d %s" % [
				g, chiesti.size(), stati, in_corso.map(func(p): return String(p).get_file()), altri, errori.size(), errori.slice(0, 3)])
		if not errori.is_empty():
			con_errori += 1
		t2.free()
		genitore.free()
		# aspetta che il thread finisca prima del giro dopo
		for p in chiesti:
			while ResourceLoader.load_threaded_get_status(String(p)) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await _frames(1)
		await _frames(5)
	print("ST: giri con errori all'instantiate: %d su %d" % [con_errori, giri])
	print("ST: finito")
	get_tree().quit()
