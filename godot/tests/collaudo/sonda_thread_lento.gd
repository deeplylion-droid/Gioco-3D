extends Node
## Ricontrollo dei passi lunghi del tunnel (#149, enigmi): l'uscita mentre la costruzione aspetta i compiti
## dell'involucro (SalaSottomarino._finisci_involucri). Nel gioco i compiti finiscono in pochi millisecondi e
## l'attesa non c'è mai (0 fotogrammi); qui si simula un compito lento: nella lista del tunnel (_involucri_lavori),
## dopo i compiti veri, si aggiunge un compito della stessa classe (_LavoroInvolucro, sulla stessa mesh del primo, così
## il risultato non cambia) che nel thread dorme [ms] millisecondi. La costruzione arriva alla prima lampada e
## aspetta; allora: titolo (Game.return_to_title), morte (GameState.kill_player), esci (Game.esci), o niente
## (aspetta la fine). Stampa quanto è durato il fotogramma più lungo dopo, e il risultato.
## Uso: godot --headless --path godot --script res://tests/run.gd -- <questo> <titolo|morte|esci|niente> [ms]

var _t0 := 0
var _peggiore := 0.0
var _ultimo_t := 0


class _Dorme:
	var ms := 8000

	func esegui() -> void:
		OS.delay_msec(ms)


func _ready() -> void:
	_run.call_deferred()


func _ora() -> float:
	return (Time.get_ticks_usec() - _t0) / 1e6


func _fotogramma() -> void:
	var t := Time.get_ticks_usec()
	if _ultimo_t > 0:
		_peggiore = maxf(_peggiore, (t - _ultimo_t) / 1000.0)
	_ultimo_t = t


func _tunnel() -> Node:
	var s := get_tree().current_scene
	var t: Node = s.get(&"sala_sottomarino") if s and &"sala_sottomarino" in s else null
	return t if is_instance_valid(t) else null


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var cosa := a[1] if a.size() > 1 else "titolo"
	var ms := int(a[2]) if a.size() > 2 else 8000
	_t0 = Time.get_ticks_usec()
	get_tree().process_frame.connect(_fotogramma)
	MenuProva.parti(get_tree(), "inseguimento")
	var tun: Node = null
	var lt := Time.get_ticks_msec()
	while Time.get_ticks_msec() - lt < 600000:
		await get_tree().process_frame
		tun = _tunnel()
		if tun and not (tun.get(&"_involucri_lavori") as Array).is_empty():
			break
	var lavori: Array = tun.get(&"_involucri_lavori")
	var classe = (lavori[0] as Object).get_script()
	var lento = classe.new(lavori[0].mesh)
	var d := _Dorme.new()
	d.ms = ms
	lento.compito = WorkerThreadPool.add_task(d.esegui, false, "compito lento simulato")
	lavori.append(lento)
	print("LENTO %.2f s: compiti veri %d (finiti %s), aggiunto un compito lento simulato di %d ms" % [_ora(), lavori.size() - 1,
			lavori.slice(0, lavori.size() - 1).map(func(l): return WorkerThreadPool.is_task_completed(l.compito)), ms])
	# fino alla costruzione ferma ad aspettare
	var prima := -1
	var fermo := 0
	while Time.get_ticks_msec() - lt < 600000:
		await get_tree().process_frame
		var rimasti := (tun.get(&"_coda") as Array).size()
		fermo = fermo + 1 if rimasti == prima else 0
		prima = rimasti
		if fermo >= 20 or bool(tun.get(&"costruita")):
			break
	print("LENTO %.2f s: la costruzione aspetta (passi rimasti %d, costruita %s, compito lento finito %s)" % [_ora(), prima,
			tun.get(&"costruita"), WorkerThreadPool.is_task_completed(lento.compito)])
	_peggiore = 0.0
	var t1 := Time.get_ticks_usec()
	match cosa:
		"titolo":
			await Game.return_to_title()
			print("LENTO %.2f s: al titolo in %.0f ms" % [_ora(), (Time.get_ticks_usec() - t1) / 1000.0])
			for i in 30:
				await get_tree().process_frame
			MenuProva.parti(get_tree(), "inseguimento")
		"morte":
			GameState.kill_player(&"collaudo")
			for i in 2:
				await get_tree().process_frame
			var seq: Node = GameState.get(&"_death_sequence")
			if is_instance_valid(seq):
				seq.emit_signal(&"finished", true)
		"esci":
			print("LENTO %.2f s: Game.esci" % _ora())
			Game.esci(0)
			return
	var ok := false
	var tf := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tf < 600000:
		await get_tree().process_frame
		var tt := _tunnel()
		var p := GameState.player
		if tt and bool(tt.get(&"costruita")) and AttesaZone.e_pronta(&"tunnel") and p and is_instance_valid(p) and p.input_enabled:
			ok = true
			break
	print("LENTO %.2f s: RISULTATO %s col compito lento: tunnel pronto %s, il fotogramma più lungo dopo %.0f ms, checkpoint %s" % [_ora(), cosa, ok,
			_peggiore, GameState.snapshot.get("checkpoint", "")])
	get_tree().quit(0 if ok else 1)
