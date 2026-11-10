extends Node
## Test delle ripartenze dal primo checkpoint del tunnel (richiesta del coordinatore del 9 novembre): F9 Tunnel, due
## morti di fila, poi una chiusura (progressi azzerati) e Continua. Prima, 2 s dopo l'arrivo, lei riemergendo
## calcolava le forme dei tentacoli (FormeTunnel.prepara) in un fotogramma da 1,2-1,5 s a schermo chiaro; ora si
## calcolano a schermo nero e, dalla seconda ripartenza, sono quelle tenute. Per ogni ripartenza:
## - nei 5 s dopo che lo schermo è libero (velo e scena di morte), nessun fotogramma sopra [constant MASSIMO_MS] ms (il
##   fotogramma intero, fisica compresa: Game.ms_nel_fotogramma). Il difetto era di 1,3 s: la soglia che blocca è larga
##   per il rumore delle macchine della CI (scelta del coordinatore); si stampano sempre i tre fotogrammi più lunghi,
##   per vedere se il margine cala (in locale 16-26 ms);
## - lei riemerge (lei_riemersa) quando scatta il timer di 2 s di riparti_da, come prima: il test vede il tunnel
##   ripartito qualche fotogramma dopo, a 1,8 s; prima di questa correzione il segnale arrivava a 3,1-3,2 s, dopo il
##   fotogramma fermo da 1,3 s dentro riemergi;
## - le forme del tunnel sono uguali a quelle calcolate da capo.
## E le forme tenute: riusate dopo una morte, lasciate con una partita nuova; quanta memoria costano.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_forme_tenute.gd

const MASSIMO_MS := 150.0
const RIEMERGE_DA := 1.6
const RIEMERGE_A := 2.25

var _ok := 0
var _ko := 0
var _t := 0
var _misura := false
var _lunghi: Array[float] = []
var _riemersa_us := 0


func _ready() -> void:
	process_priority = -1000
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _process(_d: float) -> void:
	var ora: int = Game._inizio_fotogramma
	if ora == _t:
		return
	if _misura and _t > 0:
		var ms := (ora - _t) / 1000.0
		_lunghi.append(ms)
		# (quelli sopra 30 ms, coi segni: con TORRE_TEMPI dicono cosa c'era)
		if ms > 30.0:
			print("    fotogramma da %.1f ms | %s" % [ms, RiscaldamentoShader.segni_recenti(2)])
	_t = ora


## Il giocatore nuovo è in gioco (non quello di prima, [param vecchio] è il suo instance id; la ripartenza finita).
func _gioco(vecchio: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		var p := GameState.player
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and p and is_instance_valid(p) and p.get_instance_id() != vecchio \
				and p.is_inside_tree() and not GameState.is_restoring() and not GameState.is_dying:
			return


## Lo schermo è libero: niente velo nero e niente scena di morte (o finita la sua dissolvenza).
func _schermo_libero() -> bool:
	if not Dissolvenza.schermo_libero(get_tree()):
		return false
	for d in get_tree().root.find_children("*", "DeathSequence", true, false):
		var nero := d.get(&"_black") as ColorRect
		if nero and nero.is_visible_in_tree() and nero.color.a > 0.001:
			return false
	return true


func _tunnel() -> SalaSottomarino:
	var s := get_tree().current_scene
	return s.get(&"sala_sottomarino") as SalaSottomarino if s else null


## Una ripartenza: aspetta il tunnel e il giocatore, poi lo schermo libero, poi 5 s.
func _ripartenza(nome: String, vecchio: int) -> void:
	var t0 := Time.get_ticks_usec()
	_riemersa_us = 0
	# il tunnel nuovo e il momento in cui riparte (riparti_da, nel _ripristina_sottomarino della sala)
	var tun: SalaSottomarino = null
	while tun == null or not is_instance_valid(tun) or not tun.attivo or tun.get_instance_id() == _vecchio_tunnel:
		await get_tree().process_frame
		tun = _tunnel()
		if Time.get_ticks_usec() - t0 > 300e6:
			check(false, "%s: il tunnel c'è" % nome)
			return
	var t_riparte := Time.get_ticks_usec()
	_vecchio_tunnel = tun.get_instance_id()
	tun.lei_riemersa.connect(func(): _riemersa_us = Time.get_ticks_usec(), CONNECT_ONE_SHOT)
	await _gioco(vecchio)
	var t1 := Time.get_ticks_msec()
	while not _schermo_libero() and Time.get_ticks_msec() - t1 < 20000:
		await get_tree().process_frame
	_lunghi.clear()
	_t = 0
	_misura = true
	var t2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 5000:
		await get_tree().process_frame
	_misura = false
	_lunghi.sort()
	_lunghi.reverse()
	var tre := _lunghi.slice(0, 3).map(func(x): return "%.1f" % x)
	var lungo: float = _lunghi[0] if not _lunghi.is_empty() else 0.0
	check(lungo <= MASSIMO_MS, "%s: nei 5 s dopo lo schermo libero il fotogramma più lungo è %.1f ms (al più %.0f; i tre più lunghi %s ms)" % [
			nome, lungo, MASSIMO_MS, ", ".join(PackedStringArray(tre))])
	while _riemersa_us == 0 and Time.get_ticks_usec() - t_riparte < 20e6:
		await get_tree().process_frame
	var dopo := (_riemersa_us - t_riparte) / 1e6
	check(_riemersa_us > 0 and dopo >= RIEMERGE_DA and dopo <= RIEMERGE_A,
			"%s: lei riemerge %.2f s dopo la ripartenza nel tunnel, al timer di 2 s (fra %.2f e %.2f)" % [nome, dopo, RIEMERGE_DA, RIEMERGE_A])
	# le forme del tunnel uguali a quelle calcolate da capo (un tunnel nuovo costruito subito accanto, senza le tenute)
	var date: Array = FormeTunnel._cache.get(tun.get_instance_id(), [])
	var tenute := FormeTunnel._TENUTE.dati.duplicate()
	FormeTunnel.lascia_tenute()
	var nuovo := (load("res://scenes/sala/sottomarino/sala_sottomarino.tscn") as PackedScene).instantiate() as SalaSottomarino
	tun.get_parent().add_child(nuovo)
	nuovo.global_transform = tun.global_transform
	nuovo.costruisci()
	var m0 := OS.get_static_memory_usage()
	FormeTunnel.prepara(nuovo)
	var costo := (OS.get_static_memory_usage() - m0) / 1048576.0
	var da_capo: Array = FormeTunnel._cache.get(nuovo.get_instance_id(), [])
	check(not date.is_empty() and str(date) == str(da_capo),
			"%s: le forme del tunnel (%d) uguali a quelle calcolate da capo (%d), le forme calcolate %.1f MB" % [nome, date.size(), da_capo.size(), costo])
	FormeTunnel._cache.erase(nuovo.get_instance_id())
	nuovo.free()
	FormeTunnel._TENUTE.dati = tenute


var _vecchio_tunnel := 0


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.reset_progress()
	check(not FormeTunnel.ha_tenute(), "con una partita nuova nessuna forma tenuta")
	# F9 Tunnel: il primo checkpoint del tunnel, dalla schermata di caricamento
	MenuProva.parti(get_tree(), "tunnel")
	await _ripartenza("F9 Tunnel", 0)
	check(FormeTunnel.ha_tenute(), "F9 Tunnel: le forme tenute per le ripartenze")
	var tenute: Array = FormeTunnel._TENUTE.dati[1]
	# due morti di fila: le forme sono quelle tenute
	for k in 2:
		var vecchio := GameState.player.get_instance_id()
		GameState.kill_player()
		await _ripartenza("morte %d" % (k + 1), vecchio)
		var tun := _tunnel()
		check(tun != null and FormeTunnel._cache.get(tun.get_instance_id(), []) == tenute and is_same(FormeTunnel._cache.get(tun.get_instance_id()), tenute),
				"morte %d: le forme sono quelle tenute, non ricalcolate" % (k + 1))
	# una chiusura (progressi azzerati) e Continua dal checkpoint del tunnel: le forme si ricalcolano
	var d := MenuProva.istantanea("tunnel")
	GameState.reset_progress()
	check(not FormeTunnel.ha_tenute(), "chiusura: le forme tenute lasciate")
	var vecchio2 := GameState.player.get_instance_id() if GameState.player else 0
	GameState.prepara_ripresa(d)
	get_tree().change_scene_to_file(GameState.SCENA_CARICAMENTO)
	await _ripartenza("Continua", vecchio2)
	check(FormeTunnel.ha_tenute() and not is_same(FormeTunnel._TENUTE.dati[1], tenute), "Continua: le forme di nuovo tenute, ricalcolate")
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
