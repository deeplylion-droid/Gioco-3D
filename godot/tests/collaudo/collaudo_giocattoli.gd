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
	if "sponda" in _parti:
		await _sponda()
	if "gonfiabile" in _parti:
		await _gonfiabile()
	if "portellone" in _parti:
		await _portellone()
	if "portellone_diretto" in _parti:
		await _portellone_diretto()
	if "affonda" in _parti:
		await _affonda()
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
	# (i posti liberi ora sono capsule: il centro e il raggio che le contiene)
	for f in enigma._posti_liberi():
		var c: Vector2 = ((f["a"] as Vector2) + (f["b"] as Vector2)) / 2.0
		var r: float = float(f["r"]) + ((f["b"] as Vector2) - (f["a"] as Vector2)).length() / 2.0
		out.append(["ostacolo (%.1f, %.1f) r %.2f" % [c.x, c.y, r], c, r])
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
			_compenetrazioni("piscina %s, dopo %s" % ["vuota" if vuota else "piena", t[0]])
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
	# (la sala si carica nel thread dalla schermata di caricamento: si aspetta fino a 4 minuti veri)
	var t_cont := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_cont < 240000:
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


## Come farebbe un giocatore con un giocattolo fermo contro il muro di una scaletta o in un angolo (i casi dove la spinta
## automatica, che spara al giocattolo o all'acqua dietro di lui, non lo stacca): si spara sul muro proprio accanto a
## lui, dai due lati, e l'onda lo respinge via dal muro; poi la spinta normale.
## I casi: SPONDA=<giocattolo>:<x>:<z>[;...] (sistema del nodo), a piscina vuota.
func _sponda() -> void:
	print("6. Staccare dal muro, sparando sul muro accanto")
	for caso in OS.get_environment("SPONDA").split(";", false):
		var v := caso.split(":")
		var i := int(v[0])
		await _carica()
		await _svuota()
		await _frames(120)
		var stato: Dictionary = enigma.save_state()
		stato["pos"][i] = [float(v[1]), float(v[2]), 0.0]
		enigma.load_state(stato)
		await _frames(150)
		var g := enigma.giocattolo(i)
		var gp := g.global_position
		var r: float = EnigmaGiocattoli.RAGGI[i]
		# il muro più vicino (est o ovest, nord o sud) e il punto accanto al giocattolo, dai due lati
		var ar: Rect2 = enigma.area
		var verso_muro := Vector3(-1, 0, 0) if gp.x < 0 else Vector3(1, 0, 0)
		if minf(absf(gp.z - ar.position.y), absf(gp.z - ar.end.y)) < minf(absf(gp.x - ar.position.x), absf(gp.x - ar.end.x)):
			verso_muro = Vector3(0, 0, -1) if gp.z < (ar.position.y + ar.end.y) / 2.0 else Vector3(0, 0, 1)
		var lato := verso_muro.cross(Vector3.UP)
		var staccato := false
		for tentativo in 6:
			var s := 1.0 if tentativo % 2 == 0 else -1.0
			var mira := gp + verso_muro * (r + 0.45) + lato * s * (r + 0.15) + Vector3(0, 0.3, 0)
			var stand := gp - verso_muro * 2.0 + lato * s * 1.2
			# (il raggio parte da sopra il bordo: dove il fondo sale verso la parte bassa, partendo dalla quota del pallone non
			# lo trovava e il giocatore finiva a -99)
			stand.y = _fondo_sotto(Vector3(stand.x, 1.0, stand.z), []) + 0.05
			p.teleport(stand, 0.0, 0.0)
			await _frames(4)
			p.water_pack.set_tank_amount(20.0)
			Input.action_press(&"spray")
			for f in 50:
				p.look_at_point(mira)
				await get_tree().physics_frame
			Input.action_release(&"spray")
			await _frames(90)
			var ora := g.global_position
			print("    sponda %d: giocattolo %d da %s a %s" % [tentativo, i, gp.snapped(Vector3.ONE * 0.01), ora.snapped(Vector3.ONE * 0.01)])
			if (ora - gp).dot(-verso_muro) > 0.5:
				staccato = true
				break
			gp = ora
		check(staccato, "giocattolo %d in %s: sparando sul muro accanto si stacca dal muro" % [i, caso])
		if staccato:
			check(await _spingi_misura(i, "dopo la sponda %s" % caso, 25), "giocattolo %d in %s: poi arriva al suo cerchio (%s)" % [i, caso, _dove(i)])


## La spinta di test_enigma_giocattoli.gd, con una correzione per il collaudo: se dietro al giocattolo alla distanza
## voluta c'è il muro, il giocatore si avvicina invece di passare subito alla sponda (che spara lontano dal giocattolo).
var _ultima_d := 99.0
var _fermo := 0


func _spingi(i: int, max_colpi := 40) -> bool:
	var g := enigma.giocattolo(i)
	var c := enigma.cerchio(i).global_position
	_ultima_d = 99.0
	_fermo = 0
	for colpo in max_colpi:
		var gp := g.global_position
		var d := Vector2(c.x - gp.x, c.z - gp.z)
		if enigma.piatto_giu(i) or (d.length() < 0.1 and enigma.velocita(i) < 0.05):
			return true
		var dir := d.normalized()
		# (collaudo: come un giocatore, se spingendo dritto non si muove, per esempio contro un gonfiabile sulla linea,
		# lo si spinge di lato per un colpo e poi si riprova)
		if _ultima_d - d.length() < 0.05:
			_fermo += 1
		else:
			_fermo = 0
		_ultima_d = d.length()
		if _fermo >= 2:
			dir = dir.rotated(1.1 * (1.0 if colpo % 2 == 0 else -1.0))
			_fermo = 0
		var dietro := clampf(1.6 + d.length() * 0.3, 1.8, 3.0)
		var voluto := Vector2(gp.x - dir.x * dietro, gp.z - dir.y * dietro)
		# dove si sta: nella parte profonda, non troppo vicino al muro sud (lì c'è la cassetta del pulsante, che
		# prenderebbe il getto). Se dietro di lui non ci si sta (è contro un muro), lo si spinge di sponda: davanti a lui,
		# colpendo il muro o l'acqua alle sue spalle l'onda lo manda verso il cerchio (e verso chi spruzza)
		# (collaudo: tutta la parte profonda, fino a 40 cm dai muri: anche a nord dei cerchi, dove un giocatore ci sta)
		var dove_si_sta := Rect2(-6.6, -4.0, 13.2, 8.6)
		# (collaudo: se dietro di lui alla distanza voluta non ci si sta, ci si avvicina, fino a 0,6 m, come farebbe un
		# giocatore; di sponda solo se nemmeno così)
		if not dove_si_sta.has_point(voluto):
			for k in 8:
				var dd := lerpf(dietro, 0.6, (k + 1) / 8.0)
				var prova := Vector2(gp.x - dir.x * dd, gp.z - dir.y * dd)
				if dove_si_sta.has_point(prova):
					voluto = prova
					break
		var sponda := not dove_si_sta.has_point(voluto)
		var stand := Vector3(voluto.x, 0.0, voluto.y)
		var lato := Vector2(-dir.y, dir.x)
		if sponda:
			# di fianco, colpendo l'acqua (o il muro) dietro di lui ma accanto, così il getto non prende lui
			if not dove_si_sta.has_point(Vector2(gp.x, gp.z) + lato * 2.2):
				lato = -lato
			stand = Vector3(gp.x + lato.x * 2.2, 0.0, gp.z + lato.y * 2.2)
		stand.y = _fondo_sotto(Vector3(stand.x, 0.0, stand.z), []) + 0.05
		p.teleport(stand, atan2(-(gp.x - stand.x), -(gp.z - stand.z)), 0.0)
		await _frames(4)
		p.water_pack.set_tank_amount(20.0)
		# si spruzza finché va alla velocità giusta per arrivarci scivolando (non oltre)
		var v_obiettivo := clampf(d.length() * 0.8, 0.3, 1.8)
		Input.action_press(&"spray")
		for f in 70:
			# (un po' più in alto: il getto scende)
			var mira := g.global_position + Vector3(0, EnigmaGiocattoli.ALTEZZE[i] * 0.75 + 0.1 * Vector2(gp.x - stand.x, gp.z - stand.z).length(), 0)
			if sponda:
				mira = g.global_position - Vector3(dir.x, 0.0, dir.y) * (EnigmaGiocattoli.RAGGI[i] + 0.3) \
					+ Vector3(lato.x, 0.0, lato.y) * (EnigmaGiocattoli.RAGGI[i] + 0.1)
			p.look_at_point(mira)
			await get_tree().physics_frame
			if f > 8 and enigma.velocita(i) >= v_obiettivo:
				break
		Input.action_release(&"spray")
		for f in 90:
			await get_tree().physics_frame
			if enigma.velocita(i) < 0.05:
				break
		print("    colpo %d: giocattolo %d a %.2f m dal cerchio, colpito %d volte, acqua %d, altro %d" % [colpo, i,
			Vector2(c.x - g.global_position.x, c.z - g.global_position.z).length(), _colpi.get("giocattolo", 0),
			_colpi.get("acqua", 0), _colpi.get("altro", 0)], " ", _colpi.get("primo", ""), " giocatore ", p.global_position.snapped(Vector3.ONE * 0.01))
		_colpi.clear()
	var fine := enigma.giocattolo(i).global_position
	return enigma.piatto_giu(i) or Vector2(fine.x, fine.z).distance_to(Vector2(c.x, c.z)) < 0.15


## Il pallone spinto a lungo contro il gonfiabile vicino a (-1,0/0,4) (collaudo delle 07:05: ci entrava di 20 cm e ci
## saliva sopra): dietro di lui, il getto addosso per 8 secondi verso il gonfiabile; non deve entrarci né salirci.
func _gonfiabile() -> void:
	print("7. Il pallone spinto a lungo contro il gonfiabile")
	await _carica()
	await _svuota()
	await _frames(120)
	var cap := {}
	var meglio := 99.0
	for f in enigma._posti_liberi():
		var d := EnigmaGiocattoli._vicino(f, Vector2(-1.0, 0.4)).distance_to(Vector2(-1.0, 0.4))
		if d < meglio:
			meglio = d
			cap = f
	var cc: Vector2 = ((cap["a"] as Vector2) + (cap["b"] as Vector2)) / 2.0
	var ob := Vector3(cc.x, cc.y, float(cap["r"]) + ((cap["b"] as Vector2) - (cap["a"] as Vector2)).length() / 2.0)
	print("  gonfiabile: ", cap)
	var r: float = EnigmaGiocattoli.RAGGI[1]
	for ang in [PI, PI * 0.75, PI * 1.25]:
		var via := Vector2(cos(ang), sin(ang))
		var pos := Vector2(ob.x, ob.y) + via * (ob.z + r + 0.05)
		var stato: Dictionary = enigma.save_state()
		stato["pos"][1] = [pos.x, pos.y, 0.0]
		enigma.load_state(stato)
		await _frames(150)
		var g := enigma.giocattolo(1)
		var y0 := g.global_position.y
		var stand := g.global_position + Vector3(via.x, 0, via.y) * 2.0
		# (il raggio parte da sopra il bordo: dove il fondo sale verso la parte bassa, partendo dalla quota del pallone non
		# lo trovava e il giocatore finiva a -99)
		stand.y = _fondo_sotto(Vector3(stand.x, 1.0, stand.z), []) + 0.05
		p.teleport(stand, 0.0, 0.0)
		await _frames(4)
		p.water_pack.set_tank_amount(30.0)
		var su := 0.0
		var dentro := 0.0
		var scatto := 0.0
		var prima := Vector2(g.position.x, g.position.z)
		var partenza := prima
		Input.action_press(&"spray")
		for f in 480:
			p.look_at_point(g.global_position + Vector3(0, EnigmaGiocattoli.ALTEZZE[1] * 0.6, 0))
			await get_tree().physics_frame
			# (quanto sta sopra il fondo che ha sotto, non sopra la quota di partenza: il fondo non è piano, c'è la conca e
			# il coperchio della botola)
			if true:
				var esclusi: Array = []
				for k in 3:
					esclusi.append(enigma.giocattolo(k).get_rid())
				su = maxf(su, g.global_position.y - _fondo_sotto(g.global_position, esclusi))
			var ora := Vector2(g.position.x, g.position.z)
			scatto = maxf(scatto, ora.distance_to(prima))
			prima = ora
			var d := ora.distance_to(EnigmaGiocattoli._vicino(cap, ora))
			dentro = maxf(dentro, float(cap["r"]) + r - d)
		Input.action_release(&"spray")
		await _frames(60)
		var fine := Vector2(g.position.x, g.position.z)
		var ar: Rect2 = enigma.area
		check(su <= 0.01 and dentro < 0.02, "spinto 8 s contro il gonfiabile da %.0f gradi: non ci sale (sopra il fondo che ha sotto al massimo %.3f m) e non ci entra (%.3f m)" % [rad_to_deg(ang), su, dentro])
		check(fine.distance_to(partenza) > 0.5, "da %.0f gradi ci scivola attorno: si sposta di %.2f m (da %s a %s)" % [rad_to_deg(ang), fine.distance_to(partenza), partenza.snapped(Vector2.ONE * 0.01), fine.snapped(Vector2.ONE * 0.01)])
		check(scatto < 2.5 / 60.0 * 1.2, "senza scatti: al massimo %.3f m in un fotogramma (velocità massima %.3f)" % [scatto, 2.4 / 60.0])
		check(ar.grow(0.01).has_point(fine), "resta nella parte profonda (%s)" % fine.snapped(Vector2.ONE * 0.01))
		_compenetrazioni("dopo la spinta da %.0f gradi" % rad_to_deg(ang))


func _compenetrazioni(quando: String) -> void:
	var peggio := 0.0
	for a in 3:
		for b in range(a + 1, 3):
			var ga := enigma.giocattolo(a)
			var gb := enigma.giocattolo(b)
			if enigma.piatto_giu(a) or enigma.piatto_giu(b):
				continue
			var d := Vector2(ga.position.x, ga.position.z).distance_to(Vector2(gb.position.x, gb.position.z))
			peggio = maxf(peggio, float(EnigmaGiocattoli.RAGGI[a]) + float(EnigmaGiocattoli.RAGGI[b]) - d)
	var ostacoli := 0.0
	for i in 3:
		# (galleggiando ci passa sopra, come vuole il LEGGIMI)
		if enigma.piatto_giu(i) or enigma._galleggia(i):
			continue
		var g := enigma.giocattolo(i)
		var q := Vector2(g.position.x, g.position.z)
		for f in enigma._capsule:
			ostacoli = maxf(ostacoli, float(EnigmaGiocattoli.RAGGI[i]) + float(f["r"]) - q.distance_to(EnigmaGiocattoli._vicino(f, q)))
	check(peggio < 0.02, "%s i giocattoli non si compenetrano fra loro (%.3f m)" % [quando, peggio])
	check(ostacoli < 0.02, "%s nessun giocattolo dentro un gonfiabile (%.3f m)" % [quando, ostacoli])


## Il pallone spinto contro il portellone della botola (in 0, 2) da più lati, a piscina vuota (dopo il ricontrollo di
## f1096e53: ci saliva sopra di 7 cm): in movimento non deve mai stare più di 1 cm sopra il fondo che ha sotto, e ci deve
## scivolare attorno. Poi il passaggio sulla conca da ovest verso est (180 gradi).
func _portellone() -> void:
	print("8. Il pallone contro il portellone della botola")
	await _carica()
	if not GameState.player_died.is_connected(_morto):
		GameState.player_died.connect(_morto)
	await _svuota()
	await _frames(120)
	var r: float = EnigmaGiocattoli.RAGGI[1]
	var botola := Vector2(0.0, 2.0)
	for ang in [PI, PI * 0.5, PI * 1.5, 0.0, PI * 0.75, PI * 1.25]:
		var via := Vector2(cos(ang), sin(ang))
		var pos := botola + via * 1.6
		var stato: Dictionary = enigma.save_state()
		stato["pos"][1] = [pos.x, pos.y, 0.0]
		# (gli altri due lontani, perché non si mettano in mezzo)
		stato["pos"][0] = [-4.5, -2.5, 0.0]
		stato["pos"][2] = [4.5, -2.5, 0.0]
		enigma.load_state(stato)
		await _frames(150)
		var g := enigma.giocattolo(1)
		var partenza := Vector2(g.position.x, g.position.z)
		var stand := g.global_position + Vector3(via.x, 0, via.y) * 1.8
		# (il raggio parte da sopra il bordo: dove il fondo sale verso la parte bassa, partendo dalla quota del pallone non
		# lo trovava e il giocatore finiva a -99)
		stand.y = _fondo_sotto(Vector3(stand.x, 1.0, stand.z), []) + 0.05
		# (girato verso il pallone, come in test_enigma: con l'imbardata a 0 il getto finiva sul fondo davanti)
		p.teleport(stand, atan2(-(g.global_position.x - stand.x), -(g.global_position.z - stand.z)), 0.0)
		await _frames(20)
		p.water_pack.set_tank_amount(30.0)
		var su := 0.0
		var esclusi: Array = []
		for k in 3:
			esclusi.append(enigma.giocattolo(k).get_rid())
		Input.action_press(&"spray")
		for f in 360:
			# (come la spinta di test_enigma: un po' più in alto, il getto scende)
			p.look_at_point(g.global_position + Vector3(0, EnigmaGiocattoli.ALTEZZE[1] * 0.75 + 0.1 * Vector2(g.global_position.x - stand.x, g.global_position.z - stand.z).length(), 0))
			await get_tree().physics_frame
			su = maxf(su, g.global_position.y - _fondo_sotto(g.global_position, esclusi))
		Input.action_release(&"spray")
		for f in 120:
			await get_tree().physics_frame
			su = maxf(su, g.global_position.y - _fondo_sotto(g.global_position, esclusi))
		var fine := Vector2(g.position.x, g.position.z)
		print("    da %.0f gradi: giocatore in %s, colpi %s" % [rad_to_deg(ang), p.global_position.snapped(Vector3.ONE * 0.01), _colpi])
		_colpi.clear()
		check(su <= 0.01, "spinto verso il portellone da %.0f gradi: mai più di 1 cm sopra il fondo che ha sotto (%.3f m)" % [rad_to_deg(ang), su])
		check(fine.distance_to(partenza) > 0.5, "da %.0f gradi ci scivola attorno: si sposta di %.2f m (a %s)" % [rad_to_deg(ang), fine.distance_to(partenza), fine.snapped(Vector2.ONE * 0.01)])


func _morto(causa: StringName) -> void:
	var gp: Vector3 = GameState.player.global_position if GameState.player and is_instance_valid(GameState.player) else Vector3.ZERO
	printerr("  MORTO il giocatore (causa %s) in %s" % [causa, gp.snapped(Vector3.ONE * 0.01)])


## Come _portellone, ma la spinta è data direttamente al giocattolo (la sua velocità verso il portellone, per 4 s, come
## un getto continuo che lo colpisce in pieno): prova solo come il gioco lo fa scivolare e a che quota lo tiene, senza
## dipendere da dove il robot riesce a stare e a mirare.
func _portellone_diretto() -> void:
	print("9. Il pallone spinto direttamente contro il portellone")
	await _carica()
	await _svuota()
	await _frames(120)
	var botola := Vector2(0.0, 2.0)
	_senza_fondo = 0
	var esclusi: Array = []
	for k in 3:
		esclusi.append(enigma.giocattolo(k).get_rid())
	for ang in [PI, PI * 0.5, PI * 1.5, 0.0, PI * 0.75, PI * 1.25, PI * 0.25, PI * 1.75]:
		var via := Vector2(cos(ang), sin(ang))
		var pos := botola + via * 1.6
		var stato: Dictionary = enigma.save_state()
		stato["pos"][1] = [pos.x, pos.y, 0.0]
		stato["pos"][0] = [-4.5, -2.5, 0.0]
		stato["pos"][2] = [4.5, -2.5, 0.0]
		enigma.load_state(stato)
		await _frames(120)
		var g := enigma.giocattolo(1)
		var partenza := Vector2(g.position.x, g.position.z)
		var su := 0.0
		var scatto := 0.0
		var prima := partenza
		var minimo := 99.0
		for f in 240:
			# (come fa il getto: aggiunge velocità, non la impone, così lo scivolamento del gioco resta)
			enigma._vel[1] += -via * 4.0 / 60.0
			await get_tree().physics_frame
			su = maxf(su, _sopra(g, esclusi))
			var ora := Vector2(g.position.x, g.position.z)
			scatto = maxf(scatto, ora.distance_to(prima))
			prima = ora
			minimo = minf(minimo, ora.distance_to(botola))
		for f in 120:
			await get_tree().physics_frame
			su = maxf(su, _sopra(g, esclusi))
		var fine := Vector2(g.position.x, g.position.z)
		if _senza_fondo > 0:
			print("    (in %d fotogrammi sotto il pallone il raggio non ha trovato il fondo: non contati)" % _senza_fondo)
			_senza_fondo = 0
		check(su <= 0.01, "spinto dritto verso il portellone da %.0f gradi: mai più di 1 cm sopra il fondo (%.3f m)" % [rad_to_deg(ang), su])
		check(fine.distance_to(partenza) > 0.5 and scatto < 0.05, "da %.0f gradi ci scivola attorno senza scatti: si sposta di %.2f m, al massimo %.3f m in un fotogramma, mai più vicino di %.2f m al centro della botola (a %s)" % [rad_to_deg(ang), fine.distance_to(partenza), scatto, minimo, fine.snapped(Vector2.ONE * 0.01)])



var _senza_fondo := 0


func _sopra(g: Node3D, esclusi: Array) -> float:
	var f := _fondo_sotto(g.global_position, esclusi)
	if f < -50.0:
		_senza_fondo += 1
		if _senza_fondo % 40 == 1:
			var f2 := _fondo_sotto(g.global_position + Vector3.UP * 5.0, esclusi)
			print("    senza fondo: pallone in %s, fondo cercato da 5 m più su: %.3f" % [g.global_position.snapped(Vector3.ONE * 0.001), f2])
		return 0.0
	var su := g.global_position.y - f
	if su > 0.01:
		print("    sopra il fondo di %.3f m: pallone in %s" % [su, g.global_position.snapped(Vector3.ONE * 0.001)])
	return su


## Dove il pallone messo con load_state (come una ripartenza dal checkpoint) finisce sotto il fondo della piscina: a
## piscina vuota, nei punti a 1,6 m dal portellone, fermo, senza spinte.
func _affonda() -> void:
	print("10. Il pallone messo vicino al portellone (load_state), fermo")
	await _carica()
	await _svuota()
	await _frames(120)
	for ang in [PI, PI * 0.5, PI * 1.5, 0.0, PI * 0.75, PI * 1.25, PI * 0.25, PI * 1.75]:
		var pos := Vector2(0.0, 2.0) + Vector2(cos(ang), sin(ang)) * 1.6
		var stato: Dictionary = enigma.save_state()
		stato["pos"][1] = [pos.x, pos.y, 0.0]
		enigma.load_state(stato)
		var g := enigma.giocattolo(1)
		var subito := g.global_position.y
		await _frames(120)
		var f := _fondo_sotto(Vector3(g.global_position.x, 1.0, g.global_position.z), [g.get_rid()])
		check(absf(g.global_position.y - f) < 0.03, "messo in %s da %.0f gradi: resta sul fondo (subito y %.3f, dopo 2 s y %.3f, fondo %.3f)" % [pos.snapped(Vector2.ONE * 0.01), rad_to_deg(ang), subito, g.global_position.y, f])

