extends Node
## Ricontrollo della parte tunnel dei caricamenti nel thread (0.3.25, enigmi): le ripartenze dal primo checkpoint del
## tunnel (Checkpoint_6), nel gioco vero senza schermo. Per ogni ripartenza:
## - dall'entrata del tunnel nella scena nuova: quando lo schermo è libero (Dissolvenza.schermo_libero e nessuna
##   DeathSequence) e quando lei comincia a riemergere (lei_stato da VIA a SALE) e manda lei_riemersa;
## - nei 5 s a schermo libero: il fotogramma più lungo e quelli sopra 50 ms (il fotogramma intero, da un _process di
##   questa sonda al successivo);
## - le forme dei tentacoli del tunnel (FormeTunnel._cache) confrontate con quelle calcolate da capo sullo stesso tunnel
##   (impronta md5 del contenuto), e se c'erano forme tenute.
## Casi: f9 (F9 Tunnel), due_morti (F9 Tunnel e due morti di fila al checkpoint 6), continua_salva (F9 Tunnel con il
## salvataggio su disco, poi l'uscita dal gioco) e continua (il titolo e Continua, nel processo dopo: la chiusura).
## Uso: godot --headless --path godot --script res://tests/run.gd -- <questo> <caso>

const TITOLO := "res://scenes/ui/menu_principale.tscn"
var _t0 := 0
var _ultimo := 0
var _misura := false
var _fot: Array = []
## I fotogrammi sopra 50 ms nella finestra: durata e inizio (dall'entrata del tunnel).
var _fot_lunghi: Array = []
var _t_finestra := 0.0
var _tun_id := 0
var _t_tunnel := 0.0
var _t_libero := -1.0
var _t_sale := -1.0
var _t_segnale := -1.0
var _ripartenza := 0
var _stato_lei := -1


func _ready() -> void:
	process_priority = -1000
	_run.call_deferred()


func _ora() -> float:
	return (Time.get_ticks_usec() - _t0) / 1e6


func _tunnel() -> Node:
	var s := get_tree().current_scene
	var t: Node = s.get(&"sala_sottomarino") if s and &"sala_sottomarino" in s else null
	return t if is_instance_valid(t) else null


func _libero() -> bool:
	if not Dissolvenza.schermo_libero(get_tree()):
		return false
	return get_tree().root.find_children("*", "DeathSequence", true, false).is_empty()


func _process(_d: float) -> void:
	var t := Time.get_ticks_usec()
	var ms := (t - _ultimo) / 1000.0 if _ultimo > 0 else 0.0
	var inizio := (_ultimo - _t0) / 1e6
	_ultimo = t
	var tun := _tunnel()
	if tun and tun.get_instance_id() != _tun_id:
		_tun_id = tun.get_instance_id()
		_t_tunnel = _ora()
		_t_libero = -1.0
		_t_sale = -1.0
		_t_segnale = -1.0
		_stato_lei = -1
		tun.connect(&"lei_riemersa", _segnale)
	if tun:
		var sl := int(tun.get(&"lei_stato"))
		if _t_sale < 0.0 and _stato_lei == int(SalaSottomarino.Lei.VIA) and sl != _stato_lei:
			_t_sale = _ora()
		_stato_lei = sl
	if tun and _t_libero < 0.0 and _libero() and GameState.player and GameState.player.input_enabled:
		_t_libero = _ora()
	if _misura:
		_fot.append(ms)
		if ms > 50.0:
			_fot_lunghi.append("%.0f ms da %.2f s" % [ms, inizio - _t_tunnel])


func _segnale() -> void:
	_t_segnale = _ora()


func _in_gioco() -> bool:
	var p := GameState.player
	return p != null and is_instance_valid(p) and p.input_enabled and not GameState.is_dying


func _impronta_forme(forme: Array) -> String:
	return var_to_bytes(forme).hex_encode().md5_text().substr(0, 12)


## Una ripartenza: dall'entrata del tunnel allo schermo libero, poi 5 s misurati; poi le forme.
func _ripartenza_misura(nome: String) -> void:
	_ripartenza += 1
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 600000 and (_t_libero < 0.0 or not _in_gioco()):
		await get_tree().process_frame
	_fot = []
	_fot_lunghi = []
	_t_finestra = _ora()
	_misura = true
	var tl := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tl < 5000:
		await get_tree().process_frame
	_misura = false
	# (lei: si aspetta ancora un poco se non è ancora risalita)
	var tw := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tw < 4000 and _t_segnale < 0.0:
		await get_tree().process_frame
	var lunghi := _fot.filter(func(x): return x > 50.0)
	var peggio := _fot.duplicate()
	peggio.sort()
	peggio.reverse()
	print("RIPARTENZA %d (%s): checkpoint %s; schermo libero %.2f s dopo l'entrata del tunnel; lei comincia a riemergere %s, lei_riemersa %s (dall'entrata)" % [
			_ripartenza, nome, GameState.snapshot.get("checkpoint", ""), _t_libero - _t_tunnel,
			"%.2f s" % (_t_sale - _t_tunnel) if _t_sale >= 0.0 else "-", "%.2f s" % (_t_segnale - _t_tunnel) if _t_segnale >= 0.0 else "-"])
	print("RIPARTENZA %d (%s): nei 5 s a schermo libero %d fotogrammi, sopra 50 ms %d, i più lunghi %s ms" % [
			_ripartenza, nome, _fot.size(), lunghi.size(), peggio.slice(0, 3).map(func(x): return snappedf(x, 0.1))])
	print("RIPARTENZA %d (%s): finestra misurata da %.2f s dall'entrata; i fotogrammi sopra 50 ms (inizio dall'entrata): %s" % [
			_ripartenza, nome, _t_finestra - _t_tunnel, _fot_lunghi])
	# le forme: quelle del tunnel (tenute o calcolate) e quelle calcolate da capo sullo stesso tunnel
	var tun := _tunnel()
	var id := tun.get_instance_id()
	var cache: Dictionary = FormeTunnel._cache
	var ft: GDScript = load("res://scripts/environment/forme_tunnel.gd")
	var tenute_c := ft.get_script_method_list().any(func(m): return m["name"] == "lascia_tenute")
	var aveva_tenute := bool(ft.call(&"ha_tenute")) if tenute_c else false
	if not cache.has(id):
		FormeTunnel.prepara(tun as SalaSottomarino)
	var prima: Array = cache[id]
	var imp_prima := _impronta_forme(prima)
	cache.erase(id)
	if tenute_c:
		ft.call(&"lascia_tenute")
	var tc := Time.get_ticks_msec()
	FormeTunnel.prepara(tun as SalaSottomarino)
	var da_capo: Array = cache[id]
	print("RIPARTENZA %d (%s): forme del tunnel %d (impronta %s; forme tenute nel codice: %s, presenti: %s), da capo %d (impronta %s, in %d ms): %s" % [
			_ripartenza, nome, prima.size(), imp_prima, tenute_c, aveva_tenute, da_capo.size(), _impronta_forme(da_capo),
			Time.get_ticks_msec() - tc, "UGUALI" if imp_prima == _impronta_forme(da_capo) else "DIVERSE"])


func _morte() -> void:
	var vecchio := _tun_id
	GameState.kill_player(&"collaudo")
	for i in 2:
		await get_tree().process_frame
	var seq: Node = GameState.get(&"_death_sequence")
	if is_instance_valid(seq):
		seq.emit_signal(&"finished", true)
	# la sala si ricarica: la finestra si misura sul tunnel nuovo, non su quello di prima (che è ancora in scena per
	# qualche fotogramma, col giocatore di prima: la finestra prendeva dentro il ricaricamento)
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 600000 and _tun_id == vecchio:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	var a := OS.get_cmdline_user_args()
	var caso := a[1] if a.size() > 1 else "f9"
	GameState.save_to_disk = caso.begins_with("continua")
	_t0 = Time.get_ticks_usec()
	match caso:
		"f9":
			MenuProva.parti(get_tree(), "tunnel")
			await _ripartenza_misura("F9 Tunnel")
		"due_morti":
			MenuProva.parti(get_tree(), "tunnel")
			await _ripartenza_misura("F9 Tunnel")
			await _morte()
			await _ripartenza_misura("prima morte")
			await _morte()
			await _ripartenza_misura("seconda morte")
		"continua_salva":
			MenuProva.parti(get_tree(), "tunnel")
			var t := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t < 600000 and not _in_gioco():
				await get_tree().process_frame
			for i in 60:
				await get_tree().process_frame
			# F9 mette l'istantanea del checkpoint 6 solo in memoria (si parte già lì, reach_checkpoint non riscrive):
			# la si scrive su disco come fa il gioco quando il giocatore arriva al checkpoint 6 (capture_snapshot)
			GameState._write_disk()
			print("RIPARTENZA: salvato %s; esco dal gioco" % GameState.salvataggio().get("checkpoint", ""))
			Game.esci(0)
			return
		"continua":
			get_tree().change_scene_to_file(TITOLO)
			for i in 30:
				await get_tree().process_frame
			var cp := String(GameState.salvataggio().get("checkpoint", ""))
			var voce := get_tree().current_scene.call(&"voci")[0] as Button
			print("RIPARTENZA: dal titolo, %s (%s)" % [voce.text, cp])
			if not cp.ends_with("Checkpoint_6"):
				print("RIPARTENZA: ERRORE salvataggio senza il checkpoint 6")
				Game.esci(1)
				return
			voce.pressed.emit()
			await _ripartenza_misura("Continua dopo la chiusura")
	print("RIPARTENZA: FINE %s" % caso)
	if caso == "continua":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	Game.esci(0)
