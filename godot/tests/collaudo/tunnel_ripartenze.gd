extends Node
## Collaudo 0.3.25 (copia portabile di test_forme_tenute.gd, gira anche sulla 0.3.24): F9 Tunnel, due morti di fila,
## poi una chiusura e Continua dal checkpoint del tunnel. Per ogni ripartenza: i fotogrammi nei 5 s dopo lo schermo
## libero (velo e scena di morte; il fotogramma misurato da _process a _process, con priorità -1000), quelli sopra 50 ms
## e i tre più lunghi; quando lei riemerge dopo la ripartenza nel tunnel. Senza le forme tenute (non ci sono sulla 0.3.24).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/tunnel_ripartenze.gd

const MASSIMO_MS := 150.0
const RIEMERGE_DA := 1.6
const RIEMERGE_A := 2.25

var _ok := 0
var _ko := 0
var _t := 0
var _misura := false
var _lunghi: Array[float] = []
var _riemersa_us := 0
var _t_libero := 0


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
	var ora: int = Time.get_ticks_usec()
	if ora == _t:
		return
	if _misura and _t > 0:
		var ms := (ora - _t) / 1000.0
		_lunghi.append(ms)
		# (quelli sopra 30 ms, coi segni: con TORRE_TEMPI dicono cosa c'era)
		if ms > 50.0:
			print("    fotogramma da %.1f ms a %.2f s dallo schermo libero" % [ms, (ora - _t_libero) / 1e6])
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
	_t_libero = Time.get_ticks_usec()
	_misura = true
	var t2 := Time.get_ticks_msec()
	var morto := false
	while Time.get_ticks_msec() - t2 < 15000:
		await get_tree().process_frame
		if GameState.is_dying and not morto:
			morto = true
			print("RT: %s: il giocatore muore a %.2f s dallo schermo libero" % [nome, (Time.get_ticks_usec() - _t_libero) / 1e6])
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
	print("RT: %s: nei 15 s fotogrammi sopra 50 ms %d" % [nome, _lunghi.filter(func(x): return x > 50.0).size()])


var _vecchio_tunnel := 0


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.reset_progress()
	# F9 Tunnel: il primo checkpoint del tunnel, dalla schermata di caricamento
	MenuProva.parti(get_tree(), "tunnel")
	await _ripartenza("F9 Tunnel", 0)
	# due morti di fila: le forme sono quelle tenute
	for k in 2:
		var vecchio := GameState.player.get_instance_id()
		GameState.kill_player()
		await _ripartenza("morte %d" % (k + 1), vecchio)
	# una chiusura (progressi azzerati) e Continua dal checkpoint del tunnel: le forme si ricalcolano
	var d := MenuProva.istantanea("tunnel")
	GameState.reset_progress()
	var vecchio2 := GameState.player.get_instance_id() if GameState.player else 0
	GameState.prepara_ripresa(d)
	get_tree().change_scene_to_file(GameState.SCENA_CARICAMENTO)
	await _ripartenza("Continua", vecchio2)
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
