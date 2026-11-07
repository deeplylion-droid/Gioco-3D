extends Node
## La schermata di caricamento con Jilly (richiesta dell'utente del 7 novembre): il video in ciclo dietro i comandi e
## il consiglio, registrato dal motore (scenes/ui/caricamento/registra_jilly.gd).
## - il video c'è, è Theora, piccolo, lungo un ciclo, e la schermata lo fa partire in ciclo;
## - tutte le entrate (Nuova partita dopo lo spot, Continua, le partenze F9) passano dalla stessa schermata;
## - il consiglio e i comandi stanno a sinistra, la destra resta a Jilly;
## - il video non pesa: col video che va il tempo di un fotogramma cresce di poco, la memoria non cresce mentre gira
##   e torna com'era quando la schermata si chiude (niente nodi orfani);
## - finito il video ricomincia (ciclo).
## Per non caricare la sala, la schermata carica una scena vuota.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_caricamento_jilly.gd

const SCHERMATA := "res://scenes/ui/caricamento.tscn"
const VUOTA := "res://tests/scene/prova_vuota.tscn"
## Il video al massimo (MB): il pacchetto non deve crescere troppo.
const MB_MASSIMI := 8.0
## Quanto può crescere in media il tempo di un fotogramma col video (ms).
const MS_IN_PIU := 4.0

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	var car := load("res://scripts/ui/menu/caricamento.gd")
	var percorso: String = car.VIDEO_JILLY
	check(ResourceLoader.exists(percorso), "il video di Jilly c'è (%s)" % percorso)
	var f := FileAccess.open(percorso, FileAccess.READ)
	var mb := f.get_length() / 1e6 if f else 0.0
	check(mb > 0.1 and mb <= MB_MASSIMI, "il video è piccolo: %.2f MB (al massimo %.0f)" % [mb, MB_MASSIMI])
	check(load(percorso) is VideoStreamTheora, "il video è Theora (Godot lo legge da solo)")
	# tutte le entrate passano dalla stessa schermata
	check(GameState.SCENA_CARICAMENTO == SCHERMATA, "Continua e le ripartenze da disco passano dalla schermata")
	check(MenuProva.SCENA_CARICAMENTO == SCHERMATA, "le partenze F9 passano dalla schermata")
	check(load("res://scripts/ui/menu/menu_principale.gd").SCENA_CARICAMENTO == SCHERMATA,
			"Nuova partita (dopo lo spot) passa dalla schermata")

	await _frames(10)
	var orfani_prima := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var mem_prima := Performance.get_monitor(Performance.MEMORY_STATIC)
	var tempo_senza := await _tempo_medio(120)
	var s := (load(SCHERMATA) as PackedScene).instantiate()
	s.set(&"scena", VUOTA)
	s.set(&"tempo_minimo", 600.0)   # resta a schermo per tutta la prova
	get_tree().root.add_child(s)
	await _frames(30)
	var v := s.find_child("VideoJilly", true, false) as VideoStreamPlayer
	check(v != null, "nella schermata c'è il video di Jilly")
	if v == null:
		_fine()
		return
	check(v.is_playing() and v.loop, "il video va, in ciclo")
	var lunghezza := v.get_stream_length()
	check(absf(lunghezza - 8.0) < 0.2, "il video dura un ciclo: %.2f s" % lunghezza)
	var t0 := v.stream_position
	await _frames(60)
	check(v.stream_position > t0 + 0.5, "il video avanza (%.2f -> %.2f s)" % [t0, v.stream_position])
	# i testi a sinistra, Jilly a destra
	var cons := s.find_child("Consiglio", true, false) as Control
	var w := float(s.get_viewport_rect().size.x)
	check(cons != null and cons.get_global_rect().end.x <= w * 0.55,
			"il consiglio sta a sinistra (finisce a %.0f su %.0f)" % [cons.get_global_rect().end.x if cons else -1.0, w])
	var posto := s.find_child("PostoJilly", true, false) as Control
	check(posto != null and posto.get_global_rect().position.x >= w * 0.4, "la destra è libera per Jilly")
	# il tempo di un fotogramma e la memoria mentre gira
	var tempo_con := await _tempo_medio(120)
	check(tempo_con - tempo_senza <= MS_IN_PIU,
			"col video un fotogramma costa in media %.2f ms in più (al massimo %.1f)" % [tempo_con - tempo_senza, MS_IN_PIU])
	var mem_a := Performance.get_monitor(Performance.MEMORY_STATIC)
	# oltre la fine del video: ricomincia
	var giri := 0
	var prima := v.stream_position
	for i in int((lunghezza + 1.5) * 60.0):
		await get_tree().process_frame
		if v.stream_position < prima - 1.0:
			giri += 1
		prima = v.stream_position
	check(giri >= 1 and v.is_playing(), "finito il video ricomincia (%d volte)" % giri)
	var mem_b := Performance.get_monitor(Performance.MEMORY_STATIC)
	check(mem_b - mem_a < 2e6, "mentre gira la memoria non cresce (%+.2f MB in %.0f s)" % [(mem_b - mem_a) / 1e6, lunghezza + 1.5])
	s.queue_free()
	await _frames(20)
	var mem_dopo := Performance.get_monitor(Performance.MEMORY_STATIC)
	check(mem_dopo - mem_prima < 3e6, "chiusa la schermata la memoria torna com'era (%+.2f MB)" % [(mem_dopo - mem_prima) / 1e6])
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) <= orfani_prima, "nessun nodo orfano")
	_fine()


func _tempo_medio(n: int) -> float:
	var somma := 0.0
	for i in n:
		await get_tree().process_frame
		somma += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	return somma / n


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)
