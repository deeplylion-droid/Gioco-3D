extends Node
## Collaudo finale 0.3.21 (enigmi): l'arrivo da una partenza del menu di prova, secondo per secondo: quando c'è il
## giocatore coi comandi (si gioca), e fin quando durano dopo i caricamenti nel thread e i lavori della sala; e i
## fotogrammi lenti (sopra 100 ms) da quando si gioca.
## Uso: godot --headless --path godot --script res://tests/run.gd -- <questo> <partenza>

var _t0 := 0
var _ultimo := 0
var _gioca := -1.0
var _lenti: Array = []


func _ready() -> void:
	_run.call_deferred()


func _ora() -> float:
	return (Time.get_ticks_usec() - _t0) / 1e6


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var partenza := a[1] if a.size() > 1 else "fiume"
	_t0 = Time.get_ticks_usec()
	if not MenuProva.parti(get_tree(), partenza):
		print("ARRIVO: partenza %s non trovata" % partenza)
		get_tree().quit(2)
		return
	var prossimo := 0.0
	var stato_prima := ""
	while _ora() < 300.0:
		await get_tree().process_frame
		var adesso := Time.get_ticks_usec()
		if _ultimo > 0 and _gioca >= 0.0 and (adesso - _ultimo) / 1000.0 > 100.0:
			_lenti.append([(adesso - _ultimo) / 1000.0, _ora()])
		_ultimo = adesso
		var sc := get_tree().current_scene
		var p := GameState.player
		var c_p := p != null and is_instance_valid(p) and p.input_enabled and not GameState.is_dying
		if c_p and _gioca < 0.0:
			_gioca = _ora()
			print("ARRIVO %s: si gioca a %.2f s (scena %s)" % [partenza, _gioca, sc.name if sc else "-"])
		var car := Game.caricamenti_in_corso()
		var lav := sc != null and sc.has_method(&"lavori_in_corso") and bool(sc.call(&"lavori_in_corso"))
		var st := "scena %s, giocatore %s, caricamenti %s, lavori %s" % [sc.name if sc else "-", "sì" if c_p else "no", "sì" if car else "no", "sì" if lav else "no"]
		if st != stato_prima or _ora() >= prossimo:
			# e cosa sta caricando il thread in quel momento
			var nel_thread := PackedStringArray()
			for percorso: String in Game.get(&"_caricamenti"):
				if ResourceLoader.load_threaded_get_status(percorso) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					nel_thread.append(percorso.get_file())
			var ris := sc.get_node_or_null(^"Risalita") if sc else null
			var fiume_in_costruzione := ris != null and is_instance_valid(ris.get(&"_fiume_nuovo"))
			print("ARRIVO %.2f s: %s%s; nel thread %d: %s" % [_ora(), st, ", fiume in costruzione" if fiume_in_costruzione else "",
					nel_thread.size(), ", ".join(nel_thread.slice(0, 8))])
			stato_prima = st
			prossimo = _ora() + 2.0
		if c_p and not car and not lav:
			print("ARRIVO %s: tutto finito a %.2f s (si gioca da %.2f s)" % [partenza, _ora(), _gioca])
			break
	_lenti.sort_custom(func(x, y) -> bool: return x[0] > y[0])
	print("ARRIVO: %d fotogrammi sopra 100 ms da quando si gioca" % _lenti.size())
	for l in _lenti.slice(0, 10):
		print("   fotogramma di %.0f ms a %.2f s" % [l[0], l[1]])
	get_tree().quit(0)
