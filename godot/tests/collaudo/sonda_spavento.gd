extends "res://tests/test_presa_vera.gd"
## Collaudo del crash dopo il primo spavento (lavoro/crash-spavento): la strada vera di test_presa_vera fino alla
## serranda, poi più prese vere di fila alla fossa dell'area bimbi, ognuna ripartendo dal checkpoint della presa prima.
## Modi (in ordine, dagli argomenti, separati da virgole): "intera" (la sequenza di morte fino in fondo, senza toccare
## niente), "saltata" (tenendo premuto il tasto di "skip", Spazio, finché si salta), "torre" (come "intera", ma alla presa
## la torre deve essere in caricamento nel thread o in preparazione nascosta: se non lo è già, dopo la ripartenza si
## aspetta che cominci a prepararsi e si va subito alla fossa).
## Per ogni presa: il checkpoint da cui si riparte, la distanza dal suo punto, la sala intera (le parti e il numero di
## nodi), gli errori del motore e degli script dalla presa a 10 s dopo la ripartenza, la memoria.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_spavento.gd \
##        intera,intera,intera,saltata,saltata,torre

const PARTI := ["Interni", "Tecnici", "Risalita", "Sala", "Gioco/EnigmaAcquari", "Piscina", "Mascotte", "Polaroid"]
var _modi: PackedStringArray = []
var _nodi_prima := 0


func _presa() -> void:
	var a := OS.get_cmdline_user_args()
	var lista := "intera,intera,intera,saltata,saltata,torre"
	for x in a:
		if x.contains("intera") or x.contains("saltata") or x.contains("torre") or x.contains("preparazione"):
			lista = x
	_modi = lista.split(",")
	_nodi_prima = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("SPAVENTO: modi %s, nodi alla serranda %d, checkpoint %s" % [", ".join(_modi), _nodi_prima, _checkpoint()])
	for i in _modi.size():
		await _una(i + 1, _modi[i])
	_fine()


func _torre_occupata() -> String:
	var sala := get_tree().current_scene
	if sala == null:
		return "?"
	if bool(sala.get(&"_torre_in_caricamento")):
		return "in caricamento nel thread"
	if sala.has_method(&"lavori_in_corso") and bool(sala.call(&"lavori_in_corso")):
		return "in preparazione nascosta"
	if sala.get(&"_torre_preparata"):
		return "preparata, nascosta"
	if sala.get(&"sala_torre") != null:
		return "in sala"
	return "non caricata"


func _una(n: int, modo: String) -> void:
	print("")
	print("SPAVENTO %d (%s)" % [n, modo])
	if modo == "torre" and not _torre_occupata().begins_with("in "):
		# aspetta che la torre cominci a caricarsi o a prepararsi (dopo la ripartenza si ricarica col portone/enigma)
		var t := Time.get_ticks_msec()
		while not _torre_occupata().begins_with("in ") and Time.get_ticks_msec() - t < 20000:
			await get_tree().process_frame
		print("  (torre: %s dopo %.1f s di attesa)" % [_torre_occupata(), (Time.get_ticks_msec() - t) / 1000.0])
	if modo == "preparazione":
		# alla serranda: si aspetta che la torre, finito il caricamento nel thread, cominci a prepararsi nascosta, poi
		# subito alla fossa (la prima preparazione dura qualche secondo)
		var t := Time.get_ticks_msec()
		while _torre_occupata() != "in preparazione nascosta" and Time.get_ticks_msec() - t < 180000:
			await get_tree().process_frame
		print("  (torre: %s dopo %.1f s di attesa alla serranda)" % [_torre_occupata(), (Time.get_ticks_msec() - t) / 1000.0])
	var cp_prima := _checkpoint()
	var lei := level.get(&"lei_sbuca") as LeiSbuca
	if lei and not lei.abilitata:
		lei.abilitata = true
	var ritorno := level.get(&"ritorno") as RitornoAlBuio
	var scia := ritorno.scia
	var vicino := 0
	for i in scia.size():
		if scia[i].distance_to(p.global_position) < scia[vicino].distance_to(p.global_position):
			vicino = i
	var t_strada := Time.get_ticks_msec()
	Input.action_press(&"move_forward")
	for k in range(vicino, scia.size()):
		for i in 600:
			var d := scia[k] - p.global_position
			if Vector2(d.x, d.z).length() < 0.35 or GameState.is_dying:
				break
			p.set_look(atan2(-d.x, -d.z), 0.0)
			await get_tree().physics_frame
		if GameState.is_dying:
			break
	Input.action_release(&"move_forward")
	var torre_presa := _torre_occupata()
	var cp_presa := _checkpoint()
	var pp: Array = GameState.snapshot.get("player", {}).get("position", [])
	var spawn_presa: Vector3 = Vector3(pp[0], pp[1], pp[2]) if pp.size() == 3 else Vector3.INF
	check(GameState.is_dying and lei.fase == LeiSbuca.Fase.PRESA, "%d %s: lungo la scia (%.1f s), alla fossa lei ti prende (in %s); torre: %s" % [n, modo,
		(Time.get_ticks_msec() - t_strada) / 1000.0, p.global_position.snapped(Vector3.ONE * 0.01), torre_presa])
	_stato("presa %d" % n)
	if modo == "torre" or modo == "preparazione":
		check(torre_presa.begins_with("in "), "%d: alla presa la torre si sta caricando o preparando (%s)" % [n, torre_presa])
	var seq := GameState.get_children().filter(func(x): return x is DeathSequence)
	var glitch := (seq[0] as Node).find_children("*", "JumpscareGlitch", true, false) if seq.size() == 1 else []
	check(seq.size() == 1 and (seq[0] as DeathSequence).cause == &"medusa" and glitch.size() == 1, "%d: la sequenza di morte di lei col glitch" % n)
	var saltata := {"v": false}
	if seq.size() == 1:
		(seq[0] as DeathSequence).finished.connect(func(s): saltata.v = s, CONNECT_ONE_SHOT)
	_errori.errori.clear()
	_errori.attivo = true
	var vecchia := level
	var t0 := Time.get_ticks_msec()
	var f := 0
	if modo == "saltata":
		# come il giocatore: dopo mezzo secondo tiene premuto Spazio finché la sequenza si salta
		await _frames(30)
		Input.action_press(&"skip")
	var t_fine := -1
	var in_corso := false
	while (get_tree().current_scene == vecchia or get_tree().current_scene == null) and Time.get_ticks_msec() - t0 < 150000:
		if not is_instance_valid(vecchia):
			break
		if t_fine < 0 and vecchia.process_mode == Node.PROCESS_MODE_DISABLED:
			t_fine = Time.get_ticks_msec()
			Input.action_release(&"skip")
		in_corso = Game.caricamenti_in_corso() or (vecchia.has_method(&"lavori_in_corso") and bool(vecchia.call(&"lavori_in_corso")))
		await get_tree().process_frame
		f += 1
	Input.action_release(&"skip")
	var durata := (t_fine - t0) / 1000.0 if t_fine >= 0 else -1.0
	print("  (fine della sequenza a %.1f s, sala nuova a %.1f s, %d fotogrammi; attesa dei caricamenti %.1f s)" % [durata,
		(Time.get_ticks_msec() - t0) / 1000.0, f, GameState.attesa_ripartenza])
	if modo == "saltata":
		check(saltata.v and durata > 0.0 and durata < 3.0, "%d: tenendo premuto la sequenza si salta (finita a %.1f s)" % [n, durata])
	else:
		check(not saltata.v and f >= 60 * 5 - 5, "%d: la sequenza va fino in fondo (%.1f s) e poi la sala si ricarica" % [n, durata])
	check(not in_corso, "%d: la sala si ricarica solo a caricamenti e preparazioni finiti" % n)
	var t_attesa := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_attesa < 90000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying and GameState.player.input_enabled:
			break
	level = get_tree().current_scene
	p = GameState.player
	await _frames(30)
	var cp := _checkpoint()
	var cp_nodo := level.get_node_or_null(NodePath(String(GameState.snapshot.get("checkpoint", "")))) as Node3D
	var dist := p.global_position.distance_to(cp_nodo.global_position) if cp_nodo else -1.0
	check(p != null and is_instance_valid(p) and p.input_enabled and not GameState.is_dying and p.is_on_floor(),
		"%d: si riparte e si gioca, in piedi sul pavimento (%s)" % [n, p.global_position.snapped(Vector3.ONE * 0.01)])
	check(cp == cp_presa and cp_nodo != null and spawn_presa != Vector3.INF and p.global_position.distance_to(spawn_presa) < 0.3, "%d: dal checkpoint giusto (%s; alla presa %s, prima di partire %s; a %.2f m dal nodo del checkpoint, a %.2f m dal posto salvato %s)" % [
		n, cp, cp_presa, cp_prima, dist, p.global_position.distance_to(spawn_presa) if spawn_presa != Vector3.INF else -1.0, spawn_presa])
	var mancano: PackedStringArray = []
	for parte in PARTI:
		if level.get_node_or_null(NodePath(parte)) == null:
			mancano.append(parte)
	var nodi := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	check(mancano.is_empty(), "%d: la sala intera (mancano: %s; nodi %d, alla serranda %d)" % [n, ", ".join(mancano), nodi, _nodi_prima])
	# 10 s di gioco: qualche passo avanti e indietro
	for s in 10:
		p.set_look(PI if s % 2 == 0 else 0.0, 0.0)
		Input.action_press(&"move_forward")
		await _frames(20)
		Input.action_release(&"move_forward")
		await _frames(40)
	_stato("10 s dopo la ripartenza %d" % n)
	_errori.attivo = false
	for e in _errori.errori.slice(0, 20):
		printerr("    ", e)
	check(_errori.errori.is_empty() and is_instance_valid(p) and not GameState.is_dying,
		"%d: dalla presa a 10 s dopo la ripartenza nessun errore del motore o degli script (%d)" % [n, _errori.errori.size()])
	# di nuovo verso la scia: si riparte dal punto del checkpoint
	await _frames(10)
