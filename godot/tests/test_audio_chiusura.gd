extends Node
## Test dell'audio quando le scene si liberano a pezzi o il gioco si chiude (difetto di mascotte, 29 ottobre: chiudendo il
## gioco durante l'inseguimento, una volta su tre "Lambda capture at index 4 was freed" in audio.gd, Funzione.aggiorna).
## Le funzioni chiamate a ogni fotogramma per un nodo (lampade d'emergenza, neon, effetto sott'acqua, scivolo del
## giocatore) catturano anche i loop e le luci figli del nodo: quando la scena si libera dalle foglie
## (AccensioneAPezzi.libera, come all'uscita dalla sala e alla chiusura) i figli spariscono prima del nodo, che resta
## nell'albero ancora qualche fotogramma. Qui, 5 volte di fila, per lampade d'emergenza (fissa, pulsante, rotante) e neon:
## - si liberano a pezzi con fotogrammi in mezzo (un figlio alla volta);
## - si liberano a pezzi tutte insieme, poi si chiude il gioco con le ultime ancora nell'albero;
## e nessun errore "Lambda capture" né altri errori dello script dell'audio.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_audio_chiusura.gd

class Errori extends Logger:
	var righe: PackedStringArray = []
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		righe.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func copia() -> PackedStringArray:
		mutex.lock()
		var c := righe.duplicate()
		mutex.unlock()
		return c


var _errori: Errori
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


## Le lampade e i neon di una prova, con l'audio collegato.
func _crea() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for m in [LuceEmergenza.Modalita.FISSA, LuceEmergenza.Modalita.PULSANTE, LuceEmergenza.Modalita.ROTANTE]:
		var l := LuceEmergenza.new()
		l.modalita = m
		add_child(l)
		out.append(l)
	var neon := Neon.new()
	add_child(neon)
	out.append(neon)
	return out


## Gli errori nuovi che vengono dall'audio (o dalle catture delle lambda).
func _errori_audio(da: int) -> PackedStringArray:
	var out := PackedStringArray()
	var tutti := _errori.copia()
	for i in range(da, tutti.size()):
		var r := tutti[i]
		if r.contains("Lambda capture") or r.contains("addons/audio"):
			out.append(r)
	return out


func _run() -> void:
	_errori = Errori.new()
	OS.add_logger(_errori)
	Game.pause_on_focus_loss = false
	for giro in 5:
		var da := _errori.copia().size()
		var nodi := _crea()
		await _frames(10)
		# un figlio alla volta, con un fotogramma in mezzo (il nodo resta nell'albero)
		for n in nodi:
			while is_instance_valid(n) and n.get_child_count() > 0:
				n.get_child(n.get_child_count() - 1).free()
				await _frames(2)
			if is_instance_valid(n):
				n.free()
		await _frames(5)
		# come all'uscita dalla sala: dalle foglie, a pezzi
		nodi = _crea()
		await _frames(10)
		for n in nodi:
			AccensioneAPezzi.libera(n, 0.0)
		await _frames(20)
		var e := _errori_audio(da)
		check(e.is_empty(), "giro %d: liberate a pezzi, nessun errore dell'audio" % (giro + 1), e)
	# e la chiusura vera con le lampade ancora accese e una liberazione a pezzi a metà
	var da_fine := _errori.copia().size()
	var ultime := _crea()
	await _frames(10)
	AccensioneAPezzi.libera(ultime[2], 0.0)
	await _frames(1)
	print("")
	var e := _errori_audio(da_fine)
	check(e.is_empty(), "chiusura con le lampade accese: nessun errore dell'audio", e)
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(cond: bool, what: String, extra: Variant = null) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what, "" if extra == null else "  " + str(extra))
