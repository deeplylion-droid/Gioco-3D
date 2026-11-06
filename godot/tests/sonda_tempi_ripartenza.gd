extends Node
## Sonda dei tempi della ripartenza (ritocco "ripartenze" dell'utente del 4 novembre, scelta A: togliere il lavoro che
## serve solo la prima volta). Da una partenza del menu di prova, si arriva, si muore e la sequenza di morte si chiude
## subito (i suoi 5 s non sono lavoro: la scena di 1 s dalla seconda morte è di mascotte); poi si misurano le fasi:
##  attesa  = Game.aspetta_caricamenti (la sala vecchia ferma, i caricamenti nel thread che finiscono);
##  cambio  = la scena vuota e il livello nuovo (Game.cambia_scena_in_due_tempi);
##  pronto  = il giocatore nuovo registrato e la dissolvenza dal nero (GameState.player_respawned);
##  giocabile = niente caricamenti nel thread e niente lavori della sala (si può andare dovunque).
## E i fotogrammi più lenti fra la morte e "giocabile", con la fase in cui cadono. Più giri di fila (la prima ripartenza
## e le altre).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_tempi_ripartenza.gd [partenza] [giri]
## (con un renderer vero misura anche il riscaldamento delle pipeline: xvfb-run ... --rendering-driver vulkan)

var _fase := ""
var _t0 := 0
var _lenti: Array = []
var _ultimo := 0
var _t_pronto := -1.0
## I _ready più lunghi della sala nuova: [ms, percorso]. (I _ready vanno dal basso in alto: il tempo fra un ready e
## quello prima è il _ready del nodo, coi figli già pronti.)
var _ready_lunghi: Array = []
var _ultimo_ready := 0


func _ready() -> void:
	_run.call_deferred()


func _ora() -> float:
	return (Time.get_ticks_usec() - _t0) / 1e6


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var partenza := a[1] if a.size() > 1 else "torre"
	var giri := int(a[2]) if a.size() > 2 else 3
	var albero := get_tree()
	albero.process_frame.connect(_fotogramma)
	# (il segnale può arrivare nello stesso fotogramma in cui il giocatore si registra: si segna l'ora qui)
	GameState.player_respawned.connect(func(): _t_pronto = _ora())
	albero.node_added.connect(_aggiunto)
	_t0 = Time.get_ticks_usec()
	_fase = "partenza"
	if not MenuProva.parti(albero, partenza):
		print("SONDA: partenza %s non trovata" % partenza)
		albero.quit(2)
		return
	await _aspetta_giocabile(240.0)
	print("SONDA %s: arrivato e giocabile a %.2f s" % [partenza, _ora()])
	for g in giri:
		await _frames(30)
		_lenti.clear()
		_ready_lunghi.clear()
		_t0 = Time.get_ticks_usec()
		_fase = "morte"
		_t_pronto = -1.0
		GameState.kill_player(&"sonda")
		await _frames(2)
		# (la sequenza di morte chiusa subito, come tenendo premuto Spazio fino in fondo)
		var seq: Node = GameState.get(&"_death_sequence")
		if is_instance_valid(seq):
			seq.emit_signal(&"finished", true)
		_fase = "attesa"
		var t_morte := _ora()
		var sala_vecchia := albero.current_scene
		while albero.current_scene == sala_vecchia:
			await albero.process_frame
		var t_attesa := _ora()
		_fase = "cambio"
		_ultimo_ready = 0
		while _t_pronto < 0.0:
			await albero.process_frame
		var t_pronto := _t_pronto
		_fase = "dopo"
		await _aspetta_giocabile(240.0)
		var t_giocabile := _ora()
		print("SONDA %s giro %d: attesa %.2f s, cambio fino al giocatore %.2f s, giocabile dopo %.2f s; in tutto %.2f s (dalla fine della sequenza di morte)" % [
				partenza, g + 1, t_attesa - t_morte, t_pronto - t_attesa, t_giocabile - t_pronto, t_giocabile - t_morte])
		_ready_lunghi.sort_custom(func(x, y) -> bool: return x[0] > y[0])
		for r in _ready_lunghi.slice(0, 15):
			print("   _ready di %.0f ms: %s" % [r[0], r[1]])
		_lenti.sort_custom(func(x, y) -> bool: return x[0] > y[0])
		for l in _lenti.slice(0, 12):
			print("   fotogramma di %.0f ms a %.2f s (%s)" % [l[0], l[1], l[2]])
	albero.quit(0)


func _aspetta_giocabile(massimo: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < massimo * 1000.0:
		await get_tree().process_frame
		var sc := get_tree().current_scene
		var p := GameState.player
		if sc == null or p == null or not is_instance_valid(p) or GameState.is_dying or not p.input_enabled:
			continue
		if Game.caricamenti_in_corso():
			continue
		if sc.has_method(&"lavori_in_corso") and bool(sc.call(&"lavori_in_corso")):
			continue
		return


func _aggiunto(n: Node) -> void:
	if _fase != "cambio":
		return
	n.ready.connect(func():
		var adesso := Time.get_ticks_usec()
		var ms := (adesso - _ultimo_ready) / 1000.0
		if _ultimo_ready > 0 and ms > 20.0:
			_ready_lunghi.append([ms, str(n.get_path()) if n.is_inside_tree() else String(n.name)])
		_ultimo_ready = adesso, CONNECT_ONE_SHOT)


func _fotogramma() -> void:
	var adesso := Time.get_ticks_usec()
	if _ultimo > 0:
		var ms := (adesso - _ultimo) / 1000.0
		if ms > 50.0:
			var sc := get_tree().current_scene
			_lenti.append([ms, _ora(), "%s, %s" % [_fase, String(sc.name) if sc else "-"]])
	_ultimo = adesso


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
