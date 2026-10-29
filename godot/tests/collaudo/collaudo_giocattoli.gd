extends "res://tests/test_enigma_giocattoli.gd"
## Collaudo indipendente dell'enigma dei giocattoli (ambienti-2, 29 ottobre), col giocatore e il getto veri come
## test_enigma_giocattoli.gd, di cui usa il caricamento, la spinta e lo svuotamento:
## 1. i due ordini, misurando quanti colpi e quanti secondi di gioco servono per ogni giocattolo (la spinta non deve
##    frustrare);
## 2. incastri: ogni giocattolo messo contro ogni ostacolo del fondo (scalette, conca della botola, gonfiabili, P5,
##    ripartenza) dalla parte lontana dal suo cerchio, e in ogni angolo della parte profonda, a piscina vuota e piena;
##    da lì deve tornare al suo cerchio;
## 3. lo sbaglio: la paperella sul cerchio rosso, a piscina piena e poi vuota (niente piatto, lampeggiante giallo), poi
##    corretta sul fondo e l'enigma finito;
## 4. morte e Continua a metà enigma: due piatti scesi e il terzo giocattolo a metà strada, il checkpoint della pozza
##    vuota, poi si sposta tutto e si muore; e Continua dal disco dopo una chiusura: tutto torna come al checkpoint.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/collaudo_giocattoli.gd [parti]

var _parti: PackedStringArray


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	_parti = a[1].split(",") if a.size() > 1 else PackedStringArray(["ordini", "incastri", "sbaglio", "morte"])
	if "ordini" in _parti:
		await _ordini()
	if "incastri" in _parti:
		await _incastri()
	if "sbaglio" in _parti:
		await _sbaglio()
	if "morte" in _parti:
		await _morte()
	_fine()


func _secondi() -> float:
	return Engine.get_physics_frames() / 60.0


## Spinge e misura: secondi di gioco (il giocatore qui si sposta subito dietro al giocattolo: nel gioco si aggiunge il
## tempo per arrivarci).
func _spingi_misura(i: int, cosa: String, max_colpi := 40) -> bool:
	print("SPINTA_INIZIO ", cosa)
	var t := _secondi()
	var ok := await _spingi(i, max_colpi)
	print("SPINTA_FINE %s ok=%s secondi=%.1f" % [cosa, ok, _secondi() - t])
	return ok


func _ordini() -> void:
	print("1. Ordine A (prima sull'acqua, poi lo svuotamento), misurato")
	await _carica()
	for i in 3:
		check(await _spingi_misura(i, "A acqua %d" % i), "A: il giocattolo %d arriva sul suo cerchio galleggiando" % i)
	await _svuota()
	for k in 600:
		if enigma.risolto_ok and pulsante.enabled:
			break
		await get_tree().physics_frame
	check(enigma.risolto_ok and pulsante.enabled, "A: svuotata, i tre piatti scesi e il pulsante funziona")
	for i in 3:
		check(_sul_piatto(i), "A: il giocattolo %d è sul suo piatto (%s)" % [i, _dove(i)])
	print("2. Ordine B (prima lo svuotamento, poi sul fondo), misurato")
	await _carica()
	await _svuota()
	await _frames(120)
	for i in 3:
		check(await _spingi_misura(i, "B fondo %d" % i), "B: spinto sul fondo, il giocattolo %d arriva e il piatto scende (%s)" % [i, _dove(i)])
	for k in 120:
		if pulsante.enabled:
			break
		await get_tree().physics_frame
	check(enigma.risolto_ok and pulsante.enabled, "B: risolto, il pulsante funziona")
	await _colpisci_pulsante()
	check(bool(portello.get(&"is_open")), "B: la botola si apre")


## I posti dove un giocattolo può restare incastrato, nel sistema del nodo dell'enigma: gli ostacoli del fondo (x, z,
## raggio) e gli angoli della parte profonda.
func _trappole() -> Array:
	var out := []
	for l in enigma._posti_liberi():
		out.append(["ostacolo (%.1f, %.1f) r %.2f" % [l.x, l.y, l.z], Vector2(l.x, l.y), float(l.z)])
	var ar: Rect2 = enigma.area
	for c in [ar.position, Vector2(ar.end.x, ar.position.y), Vector2(ar.position.x, ar.end.y), ar.end]:
		out.append(["angolo (%.1f, %.1f)" % [c.x, c.y], c, 0.0])
	return out


func _incastri() -> void:
	for vuota in [true, false]:
		print("3. Incastri, piscina %s" % ("vuota" if vuota else "piena"))
		await _carica()
		if vuota:
			await _svuota()
			await _frames(120)
		var trappole := _trappole()
		var ar: Rect2 = enigma.area
		for t in trappole:
			# (a piscina piena galleggiano sopra gli ostacoli: lì contano solo gli angoli)
			if not vuota and float(t[2]) > 0.0:
				continue
			# il giocattolo col cerchio più lontano, dalla parte lontana dal cerchio, appoggiato all'ostacolo
			var migliore := 0
			var lontano := -1.0
			for i in 3:
				var ci := Vector2(enigma.cerchio(i).position.x, enigma.cerchio(i).position.z)
				var d := ci.distance_to(t[1])
				if d > lontano and not enigma.piatto_giu(i):
					lontano = d
					migliore = i
			var c := Vector2(enigma.cerchio(migliore).position.x, enigma.cerchio(migliore).position.z)
			var via := (t[1] as Vector2) - c
			via = via.normalized() if via.length() > 0.01 else Vector2.RIGHT
			var pos: Vector2 = (t[1] as Vector2) + via * (float(t[2]) + float(EnigmaGiocattoli.RAGGI[migliore]) + 0.02)
			pos = Vector2(clampf(pos.x, ar.position.x, ar.end.x), clampf(pos.y, ar.position.y, ar.end.y))
			var stato: Dictionary = enigma.save_state()
			stato["pos"][migliore] = [pos.x, pos.y, 0.0]
			enigma.load_state(stato)
			await _frames(150)
			var g := enigma.giocattolo(migliore)
			var partito := Vector2(g.position.x, g.position.z)
			var ok := await _spingi_misura(migliore, "incastro %s %s giocattolo %d" % ["vuota" if vuota else "piena", t[0], migliore], 25)
			check(ok, "piscina %s, giocattolo %d da %s (partito da %s): torna al suo cerchio (%s)" % ["vuota" if vuota else "piena",
				migliore, t[0], partito.snapped(Vector2.ONE * 0.01), _dove(migliore)])
			# lo si rimette dov'era all'inizio per la prova dopo (un piatto sceso resta: si ricarica la sala ogni tanto)
			if enigma.piatto_giu(migliore):
				await _carica()
				if vuota:
					await _svuota()
					await _frames(120)


func _sbaglio() -> void:
	print("4. Lo sbaglio: la paperella sul cerchio rosso")
	await _carica()
	var rosso := Vector2(enigma.cerchio(1).position.x, enigma.cerchio(1).position.z)
	var stato: Dictionary = enigma.save_state()
	# il pallone via dal suo cerchio (parte già lontano), la paperella sopra il rosso, galleggiando
	stato["pos"][0] = [rosso.x, rosso.y, 0.0]
	enigma.load_state(stato)
	await _frames(200)
	check(not enigma.piatto_giu(0) and not enigma.piatto_giu(1), "a piscina piena la paperella sul cerchio rosso non fa niente")
	await _svuota()
	for k in 300:
		if piscina.attivo:
			break
		await get_tree().physics_frame
	await _frames(240)
	check(not enigma.piatto_giu(1) and not enigma.piatto_giu(0), "svuotata, la paperella posata sul cerchio rosso non lo fa scendere (%s)" % _dove(0))
	var g := enigma.giocattolo(0)
	var c1 := enigma.cerchio(1).global_position
	check(g.global_position.y >= c1.y - 0.01, "e sta appoggiata sopra il piatto rosso, non dentro (giocattolo y %.3f, piatto %.3f)" % [g.global_position.y, c1.y])
	var luce := piscina.get_node_or_null(^"SegnalePulsante") as OmniLight3D
	check(not pulsante.enabled and luce != null and luce.light_color.r > 0.9 and luce.light_color.b < 0.3, "il pulsante non si preme e il lampeggiante è giallo")
	print("  corretta sul fondo:")
	for i in [0, 1, 2]:
		check(await _spingi_misura(i, "sbaglio corretto %d" % i), "sul fondo il giocattolo %d va al suo cerchio (%s)" % [i, _dove(i)])
	for k in 120:
		if pulsante.enabled:
			break
		await get_tree().physics_frame
	check(enigma.risolto_ok and pulsante.enabled, "corretto lo sbaglio, l'enigma è risolto")


func _morte() -> void:
	print("5. Morte e Continua a metà enigma")
	await _carica()
	GameState.save_to_disk = true
	# due giocattoli sui cerchi galleggiando, la balena a metà strada; poi lo svuotamento: due piatti scesi
	for i in [0, 1]:
		await _spingi(i)
	var stato: Dictionary = enigma.save_state()
	stato["pos"][2] = [-2.0, 0.6, 0.0]
	enigma.load_state(stato)
	await _svuota()
	await _frames(400)
	var cp := level.get_node(^"Piscina/CheckpointPozzaVuota") as Checkpoint
	GameState.reach_checkpoint(cp)
	await _frames(5)
	var al_cp: Dictionary = enigma.save_state()
	print("  al checkpoint: ", al_cp)
	check((al_cp["giu"] as Array).count(true) == 2, "al checkpoint due piatti sono scesi")
	# si cambia tutto: la balena sul suo cerchio (terzo piatto), poi si muore
	await _spingi(2)
	check(enigma.piatto_giu(2), "dopo il checkpoint anche il terzo piatto scende")
	GameState.kill_player(&"collaudo")
	for k in 1200:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and s != level and GameState.player != null and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			break
	await _frames(60)
	await _confronta(al_cp, "dopo la morte")
	print("  Continua dopo una chiusura")
	GameState.reset_progress()
	check(GameState.continue_from_disk(), "c'è il salvataggio su disco")
	for k in 2400:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and s.scene_file_path == LEVEL and GameState.player != null and is_instance_valid(GameState.player) \
				and GameState.player.input_enabled:
			break
	await _frames(60)
	await _confronta(al_cp, "con Continua")


func _confronta(al_cp: Dictionary, quando: String) -> void:
	level = get_tree().current_scene
	enigma = level.get_node_or_null(^"Piscina/EnigmaGiocattoli") as EnigmaGiocattoli
	vasca = level.get_node_or_null(^"Piscina/Pozza") as WaterTank
	pulsante = level.get_node_or_null(^"Piscina/PulsantePortello") as WaterButton
	check(enigma != null, "%s c'è l'enigma" % quando)
	if enigma == null:
		return
	var ora: Dictionary = enigma.save_state()
	print("  %s: %s" % [quando, ora])
	check(ora["giu"] == al_cp["giu"], "%s i piatti sono come al checkpoint (%s)" % [quando, ora["giu"]])
	for i in 3:
		var a: Array = al_cp["pos"][i]
		var b: Array = ora["pos"][i]
		check(Vector2(a[0], a[1]).distance_to(Vector2(b[0], b[1])) < 0.03, "%s il giocattolo %d è dov'era al checkpoint (%s / %s)" % [quando, i, b, a])
		var g := enigma.giocattolo(i)
		if not enigma.piatto_giu(i):
			var f := _fondo_sotto(g.global_position, [g.get_rid()])
			check(absf(g.global_position.y - f) < 0.03, "%s il giocattolo %d è appoggiato sul fondo (%.3f, fondo %.3f)" % [quando, i, g.global_position.y, f])
		else:
			check(_sul_piatto(i), "%s il giocattolo %d è sul suo piatto sceso" % [quando, i])
	check(vasca != null and vasca.fill <= 0.001, "%s la piscina è vuota" % quando)
	check(pulsante != null and not pulsante.enabled, "%s il pulsante non si preme (due piatti su tre)" % quando)
