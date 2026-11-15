extends Node
## Il finale coi bambini (build 0.5.0) nel gioco vero, nei casi della robustezza chiesta dal coordinatore: dalla partenza
## F9 «Tunnel»; dopo una morte nell'ultimo tratto (ripartenza dall'ultimo checkpoint del tunnel); con Continua dal titolo
## dopo l'ultimo checkpoint; e una seconda volta nella stessa sessione. Ogni volta: il giocatore entra nella camera
## stagna, chiude il portello, e il finale arriva fino in fondo (i sei bambini, il foglio, il nero) e alla fine della
## demo di SalaPrincipale (demo_finished); e niente errori del finale nel registro.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_finale_gioco.gd

const TITOLO := "res://scenes/ui/menu_principale.tscn"

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(2400.0, true, false, true).timeout.connect(func():
		print("  FALLITO tempo scaduto")
		_failed += 1
		_fine())


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		print("  FALLITO ", what)


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = true
	_cancella_salvataggio()
	print("1. Dalla partenza F9 «Tunnel»")
	MenuProva.parti(get_tree(), "tunnel")
	await _gioco()
	await _finale("F9 Tunnel")

	print("2. Una seconda volta nella stessa sessione, dopo una morte nell'ultimo tratto")
	GameState.reset_progress()
	_cancella_salvataggio()
	MenuProva.parti(get_tree(), "tunnel")
	await _gioco()
	var t := await _tunnel()
	if t == null:
		return _fine()
	var ultimo: Checkpoint = t.checkpoint.back()
	GameState.reach_checkpoint(ultimo)
	await _secondi(1.0)
	GameState.kill_player(&"medusa")
	await _salta_morte()
	await _gioco()
	check(String(GameState.snapshot.get("checkpoint", "")).ends_with(ultimo.name), "si riparte dall'ultimo checkpoint del tunnel (%s)" % GameState.snapshot.get("checkpoint", ""))
	await _finale("dopo una morte nell'ultimo tratto")

	print("3. Continua dal titolo dopo l'ultimo checkpoint")
	GameState.reset_progress()
	_cancella_salvataggio()
	MenuProva.parti(get_tree(), "tunnel")
	await _gioco()
	t = await _tunnel()
	if t == null:
		return _fine()
	GameState.reach_checkpoint(t.checkpoint.back())
	await _secondi(1.5)
	GameState.reset_progress()
	get_tree().change_scene_to_file(TITOLO)
	for i in 60:
		await get_tree().process_frame
	var titolo := get_tree().current_scene
	var voci: Array = titolo.call(&"voci") if titolo and titolo.has_method(&"voci") else []
	check(not voci.is_empty(), "nel titolo c'è Continua")
	if voci.is_empty():
		return _fine()
	(voci[0] as Button).pressed.emit()
	await _gioco()
	await _finale("con Continua")
	_fine()


## Il tunnel nel livello, costruito (al più 5 minuti).
func _tunnel() -> SalaSottomarino:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300000:
		var level := get_tree().current_scene
		var t: SalaSottomarino = level.get(&"sala_sottomarino") as SalaSottomarino if level else null
		if t and t.costruita and t._bambini_finale.size() == t.bambini_finale.size():
			return t
		await get_tree().process_frame
	check(false, "il tunnel c'è ed è costruito")
	return null


## Dalla camera stagna si chiude il portello e il finale va fino in fondo.
func _finale(come: String) -> void:
	var t := await _tunnel()
	if t == null:
		return
	var level := get_tree().current_scene
	var p := GameState.player
	t.lei_stato = SalaSottomarino.Lei.VIA
	t.lei_tunnel.via()
	var L := t.lunghezza()
	var pos := t.to_global(t.punto(L) + t.direzione(L) * 1.0)
	pos.y = t.to_global(Vector3(0, t.piano + SalaSottomarino.SOGLIA, 0)).y + 0.02
	p.teleport(pos)
	await _secondi(0.5)
	var fasi: Array = []
	t.fase_finale_cambiata.connect(func(f: String): fasi.append(f))
	var visti := [false]
	t.chiudi_portello()
	var t0 := Time.get_ticks_msec()
	while not bool(level.get(&"demo_finished")) and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if t._bambini_finale.all(func(b): return b.is_visible_in_tree()):
			visti[0] = true
	check(fasi == ["schianto", "stacca", "silenzio", "girata", "fermi", "porge", "foglio", "nero"],
		"%s: il finale passa da tutte le fasi %s" % [come, fasi])
	check(visti[0] and bool(level.get(&"demo_finished")), "%s: i sei bambini compaiono e la demo finisce" % come)
	if &"tempo_fermo" in GameState:
		check(bool(GameState.get(&"tempo_fermo")), "%s: il tempo della partita è fermo" % come)
	await _secondi(2.0)


func _salta_morte() -> void:
	var seq: Node = GameState.get(&"_death_sequence")
	for i in 60 * 12:
		await get_tree().process_frame
		if not is_instance_valid(seq) or not GameState.is_dying:
			break
	if is_instance_valid(seq) and GameState.is_dying:
		seq.emit_signal(&"finished", true)


func _gioco() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and s.scene_file_path != TITOLO \
				and GameState.player and is_instance_valid(GameState.player) and not GameState.is_restoring() and not GameState.is_dying:
			break
	await _secondi(1.0)


func _secondi(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await get_tree().process_frame


func _cancella_salvataggio() -> void:
	for f in [GameState.SAVE_PATH, GameState.SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
