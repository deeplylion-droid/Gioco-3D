extends Node
## Ricontrollo dei passi lunghi del tunnel (#149, enigmi): il thread nuovo dell'involucro della lampada a gabbia
## (SalaSottomarino._avvia_involucri / _finisci_involucri / _exit_tree) quando si esce a metà.
## Nel gioco vero, senza schermo: partenza F9 Inseguimento; il tunnel si costruisce a pezzi nelle condotte. Quando i
## compiti del thread sono partiti, dopo [fotogrammi] fotogrammi (o "meta": a metà dei passi, "fine": all'ultimo passo):
##   titolo: torna al titolo (Game.return_to_title, come dal menu di pausa), poi di nuovo F9 Inseguimento fino al
##           tunnel pronto;
##   morte:  il giocatore muore (GameState.kill_player), riparte, fino al tunnel pronto;
##   esci:   esce dal gioco (Game.esci).
## Terzo argomento "pieno:<n>:<ms>": appena il tunnel entra nella sala, <n> lavori finti a bassa priorità di <ms> ms nel
## pool dei thread (come se il pool fosse occupato da altro): i compiti dell'involucro restano in coda o in corso.
## Momento "attesa": quando la costruzione è ferma ad aspettare i compiti (_finisci_involucri).
## Stampa a ogni fotogramma interessante lo stato dei compiti (partiti, finiti), dei passi e del tunnel.
## Uso: godot --headless --path godot --script res://tests/run.gd -- <questo> <titolo|morte|esci> <fotogrammi|meta|fine>

var _t0 := 0
var _ultimo := ""
var _finti: Array = []


## Un lavoro finto per il pool dei thread: dorme [ms] millisecondi (solo una chiamata, come i compiti del gioco).
class _Finto:
	var ms := 1000

	func esegui() -> void:
		OS.delay_msec(ms)


func _ready() -> void:
	_run.call_deferred()


func _ora() -> float:
	return (Time.get_ticks_usec() - _t0) / 1e6


func _tunnel() -> Node:
	var s := get_tree().current_scene
	var t: Node = s.get(&"sala_sottomarino") if s and &"sala_sottomarino" in s else null
	return t if is_instance_valid(t) else null


func _stato(t: Node) -> String:
	if t == null:
		return "nessun tunnel"
	var lavori: Array = t.get(&"_involucri_lavori")
	var finiti := 0
	for l in lavori:
		if WorkerThreadPool.is_task_completed(l.compito):
			finiti += 1
	var passi: Array = t.get(&"_coda") if &"_coda" in t else []
	return "compiti %d (finiti %d), costruendo %s, costruita %s, passi rimasti %s, nell'albero %s" % [lavori.size(), finiti,
			t.get(&"_costruendo"), t.get(&"costruita"), passi.size() if &"_coda" in t else "?", t.is_inside_tree()]


func _segui() -> void:
	var st := _stato(_tunnel())
	if st != _ultimo:
		print("THREAD %.2f s, fotogramma %d: %s" % [_ora(), Engine.get_process_frames(), st])
		_ultimo = st


func _fino_al_tunnel_pronto(massimo := 600.0) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < massimo * 1000.0:
		await get_tree().process_frame
		var tun := _tunnel()
		var p := GameState.player
		if tun and bool(tun.get(&"costruita")) and AttesaZone.e_pronta(&"tunnel") and p and is_instance_valid(p) and p.input_enabled:
			return true
	return false


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var cosa := a[1] if a.size() > 1 else "titolo"
	var quando := a[2] if a.size() > 2 else "0"
	var pieno := a[3] if a.size() > 3 else ""
	_t0 = Time.get_ticks_usec()
	get_tree().process_frame.connect(_segui)
	print("THREAD: %s dopo %s, partenza F9 Inseguimento" % [cosa, quando])
	MenuProva.parti(get_tree(), "inseguimento")
	# "pieno0:<n>:<ms>": il pool occupato dall'inizio della partita (prima che il tunnel entri)
	if pieno.begins_with("pieno0"):
		for k in int(pieno.get_slice(":", 1)):
			var f := _Finto.new()
			f.ms = int(pieno.get_slice(":", 2))
			_finti.append([f, WorkerThreadPool.add_task(f.esegui, false, "finto")])
		print("THREAD %.2f s: pool occupato dall'inizio con %d lavori finti di %s ms" % [_ora(), _finti.size(), pieno.get_slice(":", 2)])
	# fino ai compiti partiti
	var tun: Node = null
	var lt := Time.get_ticks_msec()
	while Time.get_ticks_msec() - lt < 600000:
		await get_tree().process_frame
		tun = _tunnel()
		if tun and pieno.begins_with("pieno:") and _finti.is_empty():
			for k in int(pieno.get_slice(":", 1)):
				var f := _Finto.new()
				f.ms = int(pieno.get_slice(":", 2))
				_finti.append([f, WorkerThreadPool.add_task(f.esegui, false, "finto")])
			print("THREAD %.2f s: il tunnel c'è; pool occupato con %d lavori finti di %s ms" % [_ora(), _finti.size(), pieno.get_slice(":", 2)])
		if tun and not (tun.get(&"_involucri_lavori") as Array).is_empty():
			break
	if tun == null or (tun.get(&"_involucri_lavori") as Array).is_empty():
		print("THREAD: i compiti non sono mai partiti (%s)" % _stato(tun))
	else:
		print("THREAD %.2f s: compiti partiti: %s" % [_ora(), _stato(tun)])
	# il momento
	if quando == "attesa":
		var fermo := 0
		var prima := -1
		var ta := Time.get_ticks_msec()
		while Time.get_ticks_msec() - ta < 300000:
			await get_tree().process_frame
			tun = _tunnel()
			if tun == null or bool(tun.get(&"costruita")):
				break
			var lav: Array = tun.get(&"_involucri_lavori")
			var aperti := lav.filter(func(l): return not WorkerThreadPool.is_task_completed(l.compito)).size()
			var rimasti := (tun.get(&"_coda") as Array).size()
			fermo = fermo + 1 if rimasti == prima and aperti > 0 else 0
			prima = rimasti
			if fermo >= 10:
				break
	elif quando == "meta" or quando == "fine":
		var tot := -1
		while true:
			await get_tree().process_frame
			tun = _tunnel()
			if tun == null or bool(tun.get(&"costruita")):
				break
			var rimasti := (tun.get(&"_coda") as Array).size() if &"_coda" in tun else -1
			tot = maxi(tot, rimasti)
			if quando == "meta" and rimasti >= 0 and rimasti <= tot / 2:
				break
			if quando == "fine" and rimasti >= 0 and rimasti <= 1:
				break
	else:
		for i in int(quando):
			await get_tree().process_frame
	tun = _tunnel()
	print("THREAD %.2f s: ADESSO %s (%s)" % [_ora(), cosa, _stato(tun)])
	var t_adesso := Time.get_ticks_usec()
	var f_adesso := Engine.get_process_frames()
	match cosa:
		"titolo":
			await Game.return_to_title()
			print("THREAD %.2f s: Game.return_to_title finito in %.0f ms (%d fotogrammi)" % [_ora(), (Time.get_ticks_usec() - t_adesso) / 1000.0, Engine.get_process_frames() - f_adesso])
			for i in 30:
				await get_tree().process_frame
			print("THREAD %.2f s: al titolo, scena %s, tunnel del giro prima ancora valido %s" % [_ora(), get_tree().current_scene.name, is_instance_valid(tun)])
			MenuProva.parti(get_tree(), "inseguimento")
			print("THREAD %.2f s: di nuovo F9 Inseguimento" % _ora())
		"morte":
			GameState.kill_player(&"collaudo")
			for i in 2:
				await get_tree().process_frame
			var seq: Node = GameState.get(&"_death_sequence")
			if is_instance_valid(seq):
				seq.emit_signal(&"finished", true)
		"esci":
			Game.esci(0)
			return
	var ok := await _fino_al_tunnel_pronto()
	for x in _finti:
		WorkerThreadPool.wait_for_task_completion(x[1])
	tun = _tunnel()
	print("THREAD %.2f s: RISULTATO %s dopo %s: tunnel pronto %s (%s), checkpoint %s" % [_ora(), cosa, quando, ok, _stato(tun), GameState.snapshot.get("checkpoint", "")])
	get_tree().quit(0 if ok else 1)
