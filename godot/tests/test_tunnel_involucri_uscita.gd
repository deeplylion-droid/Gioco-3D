extends Node
## Test: il tunnel esce dalla scena mentre la costruzione aspetta l'involucro della lampada nel thread (ricontrollo di
## enigmi del 9 novembre su 48201c67: chiudendo il gioco durante l'attesa, _exit_tree riaspettava anche i compiti già
## aspettati da _finisci_involucri e il log scriveva due volte «ERROR: Invalid Task ID»).
## Due compiti: uno veloce (l'involucro di una scatola), che _finisci_involucri aspetta e toglie dall'elenco, e uno
## lento (nel thread dorme mezzo secondo); mentre aspetta il lento il tunnel esce: _exit_tree aspetta solo quello, una
## volta. La CI controlla anche che nel log non ci sia «Invalid Task ID».
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_tunnel_involucri_uscita.gd

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, cosa: String) -> void:
	if cond:
		_ok += 1
		print("  ok    ", cosa)
	else:
		_ko += 1
		print("  KO    ", cosa)


func _lavoro(m: Mesh) -> SalaSottomarino._LavoroInvolucro:
	var l := SalaSottomarino._LavoroInvolucro.new(m)
	l.compito = WorkerThreadPool.add_task(l.esegui, false, "involucro di prova")
	return l


## Nel thread: solo una chiamata.
static func _dormi() -> void:
	OS.delay_msec(500)


func _run() -> void:
	var t := SalaSottomarino.new()
	add_child(t)
	var a := _lavoro(BoxMesh.new())
	var b := SalaSottomarino._LavoroInvolucro.new(BoxMesh.new())
	b.compito = WorkerThreadPool.add_task(_dormi, false, "compito lento di prova")
	t._involucri_lavori = [a, b] as Array[SalaSottomarino._LavoroInvolucro]
	# la costruzione aspetta (come prima della prima lampada a gabbia)
	t._finisci_involucri()
	var f := 0
	while t._involucri_lavori.size() > 1 and f < 600:
		await get_tree().process_frame
		f += 1
	var lento_in_corso := not WorkerThreadPool.is_task_completed(b.compito)
	check(t._involucri_lavori.size() == 1 and t._involucri_lavori[0] == b,
			"il compito veloce, aspettato, è uscito dall'elenco (%d fotogrammi; resta %d)" % [f, t._involucri_lavori.size()])
	print("    il compito lento era ancora in corso quando il tunnel è uscito: %s" % lento_in_corso)
	# il tunnel esce durante l'attesa (come chiudendo il gioco): _exit_tree aspetta solo il lento
	remove_child(t)
	check(t._involucri_lavori.is_empty(), "uscito, _exit_tree ha aspettato i compiti rimasti e l'elenco è vuoto")
	for i in 3:
		await get_tree().process_frame
	t.free()
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
