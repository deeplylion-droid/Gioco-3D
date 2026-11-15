extends Node
## Test automatico di lei sotto il pavimento della stanza delle pozze (LeiPozze, 0.4.0 «L'acqua è sua»), col giocatore
## vero nella stanza grigia di prova e il motore vero di lei (AcquaDiLei di mascotte, modo INTERA come segnaposto finché
## non c'è la mano). Le pause fra un'uscita e l'altra qui sono corte (1,5 s, e la calma del motore dopo un'uscita 1 s);
## l'avviso, la presa, la respinta e le distanze sono quelli veri.
## 0. Esportati e valori di partenza (letale acceso, pausa 15-20 s, portata 2 m); i tempi sono quelli del motore, che ha
##    un punto d'uscita su ognuna delle 16 pozze del bordo.
## 1. Senza colori tolti lei non c'è (e prima che le pompe siano riaccese nemmeno dopo).
## 2. Tolto il primo colore, la prima uscita: lontana dal giocatore e dove guarda, con l'avviso del motore e la luce
##    sotto la pozza, che non prende.
## 3. Poi punta la pozza piena del bordo più vicina al giocatore: chi resta lì è preso e muore (medusa).
## 4. Allontanandosi di 3 m lungo la passerella, anche partendo da un angolo, si è salvi.
## 5. Col getto in faccia mentre esce, viene respinta.
## 6. Svuotando quel colore, viene cacciata prima di uscire.
## 7. Tre colori sbagliati: le pozze si riempiono di nuovo, tutte le porte si riaprono e lei torna a uscire.
## 8. L'enigma si risolve come prima con lei sveglia; risolto, se ne va.
## 9. Letale spento: esce e incombe, ma solo paura.
## 10. Mai senza scampo: non la chiama mentre il giocatore aspira senza vedere la pozza, è in una pozza o fuori dalla
##     stanza; dall'angolo c'è sempre una via di salvezza (col tempo dell'avviso del motore).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_pozze_lei.gd

const PLAYER := "res://scenes/player/player.tscn"
const STANZA := preload("res://tests/pozze/stanza_prova.gd")
const F := AcquaDiLei.Fase
## La linea di mezzo della passerella (m dal centro della griglia).
var r := 0.0

var p: Player
var e: EnigmaPozze
var lei: LeiPozze
var acqua: AcquaDiLei
## Le fasi del motore: [fase, fotogramma di fisica].
var fasi: Array = []
## La camera del giocatore com'era (la scena della morte della medusa la porta davanti al viso di lei).
var _camera := Transform3D.IDENTITY
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		print("  FALLITO ", what)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(3)
	_camera = p.camera.transform

	print("0. Esportati e valori di partenza")
	var l := LeiPozze.new()
	var esportati := {}
	for prop in l.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_EDITOR:
			esportati[String(prop["name"])] = true
	var nomi := ["letale", "portata", "prima_attesa", "pausa_min", "pausa_max", "riprova", "velocita_luce",
			"profondita_uscita", "distanza_dimostrativa", "distanza_attenzione", "angolo_vista", "velocita_fuga",
			"reazione", "margine_fuga"]
	var mancano := nomi.filter(func(n): return not esportati.has(n))
	check(mancano.is_empty(), "letale, tempi e distanze sono esportati (mancano: %s)" % [mancano])
	check(l.letale and is_equal_approx(l.pausa_min, 15.0) and is_equal_approx(l.pausa_max, 20.0) and is_equal_approx(l.portata, 2.0),
		"si parte con letale acceso, pausa di 15-20 s e portata di 2 m")
	check(not esportati.has("avviso") and not esportati.has("silenzio"), "l'avviso e il silenzio non sono qui: sono del motore")
	l.free()
	await _nuova_stanza()
	check(acqua != null and acqua.get_parent() == lei, "nella stanza c'è il motore di lei (AcquaDiLei)")
	check(acqua.letale and acqua.modo == AcquaDiLei.Modo.MANO and acqua.prima_volta_dimostrativa and not acqua.automatica,
		"il motore ha letale acceso, il modo MANO (mano e tentacoli), la prima volta dimostrativa e non viene da solo")
	check(is_equal_approx(lei.portata_effettiva(), acqua.portata_mano), "la presa arriva fin dove arriva la mano (%.1f m dal punto)" % lei.portata_effettiva())
	check(absf(acqua.pelo - _pelo_pieno(e.pozze()[0])) < 0.001, "il pelo del motore è quello dell'acqua piena (%.4f)" % acqua.pelo)
	# i punti d'uscita della mano: sul grigliato a filo del bordino, di fronte al centro della pozza, +Z verso fuori,
	# due nelle pozze d'angolo
	var giusti := 0
	var punti := 0
	for t in e.pozze():
		if not lei._sul_bordo(t):
			continue
		var c := e.to_local(t.global_position)
		var ms: Array = lei.uscite_di(t)
		var angolo := absf(c.x) > 2.0 and absf(c.z) > 2.0
		var ok := ms.size() == (2 if angolo else 1)
		for m: Marker3D in ms:
			punti += 1
			ok = ok and m in acqua.punti_uscita
			var lq := e.to_local(m.global_position)
			var fuori := e.global_basis.inverse() * m.global_basis.z
			var lato := Vector3(signf(lq.x), 0, 0) if absf(fuori.x) > 0.9 else Vector3(0, 0, signf(lq.z))
			var sul_bordo := absf(absf(lq.x) - 2.8) < 0.01 if lato.x != 0.0 else absf(absf(lq.z) - 2.8) < 0.01
			var accanto := absf(lq.z - c.z) < 0.01 if lato.x != 0.0 else absf(lq.x - c.x) < 0.01
			ok = ok and sul_bordo and accanto and absf(lq.y) < 0.001 and fuori.distance_to(lato) < 0.01
		if ok:
			giusti += 1
	check(giusti == 16 and punti == 20 and acqua.punti_uscita.size() == 20,
		"i punti della mano: sul grigliato a filo del bordino (2,80 m), di fronte alla pozza, +Z verso fuori, due nelle 4 pozze d'angolo (%d/16, %d punti)" % [giusti, punti])
	# col segnaposto INTERA: uno per pozza, al centro, al pelo
	lei.modo = AcquaDiLei.Modo.INTERA
	var centrati := 0
	for t in e.pozze():
		if lei._sul_bordo(t):
			var pose := lei._pose_uscita(t)
			if pose.size() == 1 and _in_pianta(pose[0].origin, t.global_position) < 0.01 and absf(pose[0].origin.y - _pelo_pieno(t)) < 0.01:
				centrati += 1
	lei.modo = AcquaDiLei.Modo.MANO
	check(centrati == 16, "(col segnaposto INTERA un punto per pozza, al centro, al pelo: %d/16)" % centrati)
	# niente scarichi: la stanza è quella di prima, nodo per nodo; l'interruttore li mette sul fondo
	check(not e.scarichi and e.pozze().all(func(u): return u.get_node_or_null(^"Scarico") == null and u.find_children("*", "ScaricoPozza", true, false).is_empty()),
		"niente scarichi: le pozze sono quelle di prima (interruttore spento)")
	var con := EnigmaPozze.new()
	con.scarichi = true
	var radice_con := Node3D.new()
	radice_con.position = Vector3(0, -40, 0)
	add_child(radice_con)
	radice_con.add_child(con)
	await _frames(1)
	var a_posto := 0
	for t in con.pozze():
		var sc := t.get_node_or_null(^"Scarico") as ScaricoPozza
		if sc == null:
			continue
		var q := t.to_local(sc.global_position)
		var r_sc := ScaricoPozza.DIAMETRO * 0.5 + ScaricoPozza.ANELLO
		if absf(q.y) < 0.001 and absf(q.x) + r_sc <= con.lato * 0.5 - 0.01 and absf(q.z) + r_sc <= con.lato * 0.5 - 0.01:
			a_posto += 1
	check(a_posto == 25, "(con l'interruttore acceso uno scarico sul fondo di ognuna delle 25 pozze, tutto dentro: %d)" % a_posto)
	radice_con.queue_free()
	await _frames(2)

	print("1. Senza colori tolti lei non c'è")
	_metti(Vector3(0, 0, r))
	await _secondi(8.0)
	check(lei.fase == LeiPozze.Fase.DORME and fasi.is_empty() and AcquaDiLei.chi_la_usa() == null and not acqua.in_giro(),
		"in 8 s con le pozze piene il motore non si muove e la luce non c'è (%s, %d fasi)" % [lei.nome_fase(), fasi.size()])
	GameState.imposta_luci(GameState.Luci.PRIMA_DEL_RISVEGLIO)
	await _togli(WaterMix.ROSA)
	await _secondi(lei.prima_attesa + 1.0)
	check(lei.fase == LeiPozze.Fase.GIRA and fasi.is_empty() and not acqua.in_giro(),
		"prima che le pompe siano riaccese, anche col primo colore tolto, lei non viene (niente luce)")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)

	print("2. Il primo colore: la prima uscita, dimostrativa")
	await _nuova_stanza()
	preload("res://scripts/game/stato_lei.gd").azzera()
	await _togli(WaterMix.ROSA)
	await _frames(2)
	check(lei.fase == LeiPozze.Fase.GIRA and lei.prossima_dimostrativa(), "tolto il primo colore si sveglia, e la prossima uscita è quella dimostrativa")
	# la luce che gira di pozza in pozza, fino all'avviso
	var giro := await _segui_luce(F.ARRIVA, lei.prima_attesa + 8.0)
	var a: Array = giro["arrivo"]
	var viste: Array = giro["pozze"]
	check(giro["in_giro"], "la luce rosa gira sotto le pozze (AcquaDiLei.percorri)")
	check(viste.size() >= 3, "passa di pozza in pozza (%d pozze)" % viste.size())
	check(viste.all(func(u): return String(u.fill_pigment) != WaterMix.ROSA), "solo sotto pozze piene")
	check(giro["di_fila"], "da una pozza a una accanto, senza salti")
	check(giro["vicinanza"] > 0.05, "e il canto sale da sotto (vicinanza fino a %.2f)" % giro["vicinanza"])
	check(giro["energia_centro_min"] >= 0.5 and giro["salti"] == 0,
		"la luce non salta, ed è accesa al centro di ogni pozza dove passa (energia minima lì %.2f, salti %d)" % [giro["energia_centro_min"], giro["salti"]])
	# (sotto i bordini il motore la abbassa in 0,25 s: com'è, per decisione del coordinatore la luce che gira resta
	# così; qui solo la misura)
	print("  (sotto i bordini l'energia arriva al più a %.2f, al centro delle pozze almeno %.2f)" % [giro["fuori_max"], giro["energia_centro_min"]])
	check(not a.is_empty(), "dopo qualche secondo arriva la prima volta")
	if a.is_empty():
		return _fine()
	var t: WaterTank = lei.bersaglio
	check(viste.size() >= 1 and (viste.back() == t or viste.back() in lei._vicine(t)), "l'avviso comincia da una pozza accanto")
	check(t != null and lei._piena(t) and lei._sul_bordo(t), "in una pozza piena del bordo (%s)" % (t.name if t else "?"))
	check(lei._distanza(p, t) >= lei.distanza_dimostrativa, "lontana dal giocatore (%.1f m)" % lei._distanza(p, t))
	check(lei._la_vede(p, t) or not _ce_ne_e_una_in_vista(), "ed è dove il giocatore guarda")
	var da := acqua.punto_luce
	check(_sotto_pozza_piena(da), "la luce parte sotto una pozza piena")
	var si := await _aspetta(F.SILENZIO, acqua.avviso + 1.0)
	check(not si.is_empty() and _in_pianta(acqua.punto_luce, t.global_position) < 0.05,
		"nel silenzio la luce è nella pozza, al centro (%.2f m)" % _in_pianta(acqua.punto_luce, t.global_position))
	# il liquido opaco (decisione del coordinatore del 15 novembre): comincia nel silenzio, piano
	var op_inizio := _estinzione(t)
	await _frames(int(0.15 * 60))
	var op_mezzo := _estinzione(t)
	check(op_inizio < 0.5 * lei.opaco_estinzione and op_mezzo > op_inizio and op_mezzo < 0.95 * lei.opaco_estinzione,
		"nel silenzio il liquido della sua pozza comincia a farsi opaco, piano (%.1f, dopo 0,15 s %.1f, opaco %.0f)" % [op_inizio, op_mezzo, lei.opaco_estinzione])
	var es := await _aspetta(F.ESCE, acqua.silenzio + 1.0)
	var dt: float = (es[1] - a[1]) / 60.0 if not es.is_empty() else -1.0
	check(not es.is_empty() and absf(dt - acqua.avviso) < 0.05, "esce %.2f s dopo l'arrivo della luce (avviso del motore %.1f s)" % [dt, acqua.avviso])
	check(_estinzione(t) >= 0.95 * lei.opaco_estinzione, "quando esce il liquido è già opaco (%.1f)" % _estinzione(t))
	var su := await _aspetta(F.SU, 5.0)
	var salita: float = (su[1] - es[1]) / 60.0 if not su.is_empty() and not es.is_empty() else -1.0
	print("        (salita %.2f s)" % salita)
	var accanto := lei._vicine(t).filter(func(u): return lei._piena(u))
	check(not accanto.is_empty() and accanto.all(func(u): return _estinzione(u) >= 0.95 * lei.opaco_estinzione),
		"anche le %d pozze piene accanto sono opache" % accanto.size())
	var lontane := e.pozze().filter(func(u): return u != t and not (u in accanto))
	check(lontane.all(func(u): return is_equal_approx(_estinzione(u), _estinzione_stile(u))), "le altre pozze restano come sono")
	var lr := AcquaDiLei._luce
	check(lr.visible and lr.global_position.y > t.get_surface_global_y() + 0.1 and _in_pianta(lr.global_position, t.global_position) < 0.05,
		"mentre è su la luce rosa sta sopra il pelo, al centro della sua pozza (%.2f m sopra)" % (lr.global_position.y - t.get_surface_global_y()))
	var ca2 := await _aspetta(F.CALMA, 6.0)
	check(not ca2.is_empty() and _estinzione(t) >= 0.95 * lei.opaco_estinzione, "tornata sotto, il liquido è ancora opaco")
	await _frames(int((lei.opaco_tempo + 0.1) * 60))
	check(([t] + accanto).all(func(u): return is_equal_approx(_estinzione(u), _estinzione_stile(u))),
		"poi si schiarisce, e torna com'era (%.2f, stile %.2f)" % [_estinzione(t), _estinzione_stile(t)])
	check(lei.prese == 0 and lei.uscite == 1 and not GameState.is_dying and not lei.prossima_dimostrativa(), "e non prende")

	print("3. Poi la pozza piena del bordo più vicina: chi resta lì è preso")
	# (davanti alla pozza arancione del lato sud)
	_metti(Vector3(0, 0, r))
	a = await _aspetta(F.ARRIVA, 8.0)
	check(not a.is_empty(), "arriva di nuovo dopo la pausa")
	if a.is_empty():
		return _fine()
	t = lei.bersaglio
	check(t == _piu_vicina(), "punta la pozza piena del bordo più vicina al giocatore (%s)" % t.name)
	check(_dist_uscita() <= lei.portata_effettiva(), "il giocatore è a portata (%.1f m)" % _dist_uscita())
	var pr := await _aspetta(F.PRESA, acqua.avviso + 5.0)
	check(not pr.is_empty() and lei.prese == 1 and GameState.is_dying and GameState.last_death_cause == &"medusa",
		"resta lì: esce e lo prende, si muore (%s)" % GameState.last_death_cause)
	await _frames(int((lei.opaco_tempo + 0.1) * 60))
	check(not lei.liquido_trasparente_alla_presa and _estinzione(t) >= 0.95 * lei.opaco_estinzione,
		"nella scena di morte il liquido resta opaco (%.1f; piano B, interruttore spento di serie)" % _estinzione(t))
	var lm := AcquaDiLei._luce
	check(lm.visible and lm.global_position.y > t.get_surface_global_y() + 0.1, "e la luce rosa resta sopra il pelo")
	_rianima()

	print("4. Allontanandosi lungo la passerella si è salvi, anche vicino a un angolo")
	await _nuova_stanza(false)
	await _togli(WaterMix.ROSA)
	_metti(Vector3(e.passo * 2.0, 0, r))
	# (8 s: il giro a caso della luce, 4 pozze a 1,5 m/s, non si interrompe allo scadere dell'attesa; con l'avvicinamento il caso peggiore è circa 8,3 s dal risveglio)
	a = await _aspetta(F.ARRIVA, lei.prima_attesa + 8.0)
	if a.is_empty():
		check(false, "arriva")
		return _fine()
	t = lei.bersaglio
	check(_dist_uscita() <= lei.portata_effettiva(), "vicino all'angolo punta una pozza a portata (%s, %.1f m)" % [t.name, _dist_uscita()])
	await _cammina_via(t, 3.0)
	check(_dist_uscita() >= 3.0 and acqua.fase in [F.ARRIVA, F.SPEGNE, F.SILENZIO],
		"camminando lungo la passerella è a %.1f m dal punto prima che esca" % _dist_uscita())
	var ca := await _aspetta(F.CALMA, 14.0)
	check(not ca.is_empty() and lei.uscite == 1 and lei.prese == 0 and not GameState.is_dying, "lei esce, incombe e torna sotto senza prenderlo")

	print("5. Col getto in faccia mentre esce, viene respinta")
	_metti(Vector3(0, 0, r))
	_zaino()
	p.water_pack.set_tank_amount(p.water_pack.tank_capacity)
	a = await _aspetta(F.ARRIVA, 8.0)
	if a.is_empty():
		check(false, "arriva di nuovo")
		return _fine()
	t = lei.bersaglio
	check(_dist_uscita() <= lei.portata_effettiva(), "a portata della pozza %s (%.1f m)" % [t.name, _dist_uscita()])
	await _aspetta(F.ESCE, acqua.avviso + 1.0)
	var viso := acqua.find_child("Viso", true, false) as Node3D
	if viso == null:
		viso = lei.find_child("Viso", true, false) as Node3D
	check(viso != null, "c'è il viso da colpire")
	Input.action_press(&"spray")
	for i in 60 * 4:
		if viso:
			p.look_at_point(viso.global_position)
		await get_tree().physics_frame
		if lei.respinte > 0 or lei.prese > 0:
			break
	Input.action_release(&"spray")
	check(lei.respinte == 1 and lei.prese == 0 and not GameState.is_dying, "col getto in faccia viene respinta e non lo prende")
	if GameState.is_dying:
		return _fine()
	await _aspetta(F.CALMA, 6.0)

	print("6. Svuotando quel colore, viene cacciata")
	_metti(Vector3(0, 0, r))
	a = await _aspetta(F.ARRIVA, 8.0)
	if a.is_empty():
		check(false, "arriva di nuovo")
		return _fine()
	t = lei.bersaglio
	var colore := String(t.fill_pigment)
	p.look_at_point(_pelo(t))
	await _frames(2)
	var uscite := lei.uscite
	Input.action_press(&"suck")
	for i in 60 * 4:
		await get_tree().physics_frame
		if lei.cacciate > 0 or lei.uscite > uscite:
			break
	Input.action_release(&"suck")
	check(colore in e.svuotando or colore in e.tolti, "aspirando dalla pozza %s il suo colore comincia a svuotarsi" % t.name)
	await _frames(2)
	check(lei.cacciate == 1 and lei.uscite == uscite and acqua.fase == F.LONTANA and lei.fase == LeiPozze.Fase.GIRA and not GameState.is_dying,
		"la pozza che si svuota è una porta che si chiude: viene cacciata, la luce se ne va senza uscita")

	print("7. Tre colori sbagliati: le pozze si riempiono e tutte le porte si riaprono")
	lei._t = -1000.0
	await _aspetta_tolto(colore, 6.0)
	var terzo := ""
	for c in EnigmaPozze.COLORI:
		if not c in e.tolti and not c in e.svuotando:
			terzo = c
			break
	await _togli(terzo)
	check(e.stato == EnigmaPozze.Stato.SBAGLIATO, "rosa, %s e %s: sbagliato" % [colore, terzo])
	for i in 60 * 12:
		await get_tree().physics_frame
		if e.stato == EnigmaPozze.Stato.APERTO:
			break
	await _frames(5)
	check(e.stato == EnigmaPozze.Stato.APERTO and e.tolti.is_empty(), "le pozze si sono riempite di nuovo")
	check(lei._pozze_buone().size() == 16, "tutte le 16 pozze del bordo sono di nuovo porte aperte (%d)" % lei._pozze_buone().size())
	lei._t = -0.5
	_metti(Vector3(0, 0, r))
	# (8 s: il giro a caso della luce, 4 pozze a 1,5 m/s, non si interrompe allo scadere dell'attesa: con l'avvicinamento, circa 5,8 s da qui nel caso peggiore)
	a = await _aspetta(F.ARRIVA, 8.0)
	check(not a.is_empty(), "e lei torna a venire")
	if not a.is_empty():
		await _cammina_via(lei.bersaglio, 3.0)
	await _aspetta(F.CALMA, 14.0)
	check(not GameState.is_dying, "(e il giocatore si salva allontanandosi)")
	if GameState.is_dying:
		return _fine()

	print("8. L'enigma si risolve come prima, con lei sveglia")
	lei.letale = false
	for c in EnigmaPozze.GIUSTI:
		await _togli(c)
	await _frames(3)
	check(e.stato == EnigmaPozze.Stato.RISOLTO and _porta().aperta, "turchese, viola e arancione: risolto, la porta stagna si apre")
	check(lei.fase == LeiPozze.Fase.FINITA and not acqua.abilitata, "risolto, lei se ne va (%s)" % lei.nome_fase())
	await _aspetta_lontana(8.0)
	var n := fasi.size()
	await _secondi(5.0)
	check(fasi.size() == n and acqua.fase == F.LONTANA and not acqua.in_giro() and not _luce_accesa(), "e non viene più, la luce non c'è")

	print("9. Letale spento: solo paura")
	await _nuova_stanza(false)
	lei.letale = false
	await _togli(WaterMix.ROSA)
	_metti(Vector3(0, 0, r))
	# (8 s: il giro a caso della luce, 4 pozze a 1,5 m/s, non si interrompe allo scadere dell'attesa; con l'avvicinamento il caso peggiore è circa 8,3 s dal risveglio)
	a = await _aspetta(F.ARRIVA, lei.prima_attesa + 8.0)
	check(not a.is_empty() and _dist_uscita() <= lei.portata_effettiva(), "arriva a portata del giocatore")
	var sc := await _aspetta(F.SCENDE, acqua.avviso + 8.0)
	check(not sc.is_empty() and lei.uscite == 1 and lei.prese == 0 and not GameState.is_dying and p.input_enabled,
		"esce e incombe vicino a lui, ma non lo prende e non si muore")
	await _aspetta(F.CALMA, 6.0)
	check(lei.fase == LeiPozze.Fase.GIRA, "e torna a girare sotto le pozze")

	print("10. Mai senza scampo")
	await _nuova_stanza(false)
	# (qui si chiede solo dove la chiamerebbe: non viene)
	lei.prima_attesa = 1000.0
	await _togli(WaterMix.ROSA)
	check(lei.fase == LeiPozze.Fase.GIRA and acqua.fase == F.LONTANA and not GameState.is_dying, "(lei sveglia, ferma)")
	_metti(Vector3(0, 0, r))
	await _frames(3)
	var vicina := _piu_vicina()
	p.look_at_point(_pelo(vicina))
	await _frames(2)
	p.water_pack.is_sucking = true
	check(lei._bersaglio() == vicina, "aspirando e guardando la pozza, la può puntare (puntabile %s, la vede %s, salvezza %s)"
		% [lei._puntabile(p), lei._la_vede(p, vicina), lei.via_di_salvezza(p.global_position, vicina)])
	p.look_at_point(Vector3(0, 1.0, r + 5.0))
	await _frames(1)
	p.water_pack.is_sucking = true
	check(lei._bersaglio() == null, "aspirando con la pozza alle spalle no: aspetta")
	p.water_pack.is_sucking = false
	p.teleport(Vector3(0, -0.45, 2.2), 0.0, 0.0)
	check(lei._bersaglio() == null, "nemmeno con il giocatore caduto in una pozza")
	p.teleport(Vector3(0, 0.05, 30.0), 0.0, 0.0)
	await _frames(2)
	check(lei._bersaglio() == null, "né fuori dalla stanza")
	var angolo: WaterTank = null
	for u in e.pozze():
		if u.position.x > 2.0 and u.position.z > 2.0:
			angolo = u
	check(lei.via_di_salvezza(e.to_global(Vector3(r, 0, r)), angolo), "dall'angolo della passerella c'è una via di salvezza dalla pozza d'angolo")
	var avviso := acqua.avviso
	acqua.avviso = 0.9
	check(not lei.via_di_salvezza(e.to_global(Vector3(r, 0, r)), angolo), "(e il controllo se ne accorge quando non c'è: con un avviso di 0,9 s no)")
	acqua.avviso = avviso

	print("11. Svuotando il colore dove passa la luce, la luce se ne va")
	await _nuova_stanza(false)
	lei.prima_attesa = 1000.0
	await _togli(WaterMix.ROSA)
	var col := ""
	for i in 60 * 6:
		await get_tree().physics_frame
		if lei._in_giro and not lei._giro.is_empty():
			var fine_giro: WaterTank = lei._giro.back()
			if String(fine_giro.fill_pigment) == WaterMix.ROSA:
				continue
			col = String(fine_giro.fill_pigment)
			break
	check(col != "", "la luce gira (verso una pozza %s)" % col)
	if col != "":
		var tc: WaterTank = null
		for u: WaterTank in e.pozze_del_colore(col):
			if tc == null or u.position.z > tc.position.z:
				tc = u
		p.teleport(Vector3(tc.global_position.x, e.global_position.y + 0.05, e.to_global(Vector3(0, 0, r)).z), 0.0, 0.0)
		await _frames(2)
		p.look_at_point(_pelo(tc))
		Input.action_press(&"suck")
		var spenta := false
		for i in 60 * 4:
			await get_tree().physics_frame
			if col in e.svuotando or col in e.tolti:
				break
		Input.action_release(&"suck")
		for i in 60 * 3:
			await get_tree().physics_frame
			if not _luce_accesa():
				spenta = true
				break
		check(col in e.svuotando or col in e.tolti, "il %s comincia a svuotarsi" % col)
		check(spenta, "la luce si allontana e si spegne")
		var riparte := false
		var dove: WaterTank = null
		for i in 60 * 6:
			await get_tree().physics_frame
			if _luce_accesa() and lei._in_giro:
				riparte = true
				dove = lei._giro[0]
				break
		check(riparte and dove != null and lei._piena(dove), "poi riprende a girare da una pozza piena (%s)" % (dove.name if dove else "?"))

	print("12. Con liquido_trasparente_alla_presa acceso: dalla presa il liquido torna trasparente (com'era prima)")
	await _nuova_stanza(false)
	lei.liquido_trasparente_alla_presa = true
	await _togli(WaterMix.ROSA)
	_metti(Vector3(0, 0, r))
	var pr2 := await _aspetta(F.PRESA, lei.prima_attesa + acqua.avviso + 10.0)
	check(not pr2.is_empty(), "esce vicino e lo prende")
	if not pr2.is_empty():
		var t2: WaterTank = lei.bersaglio
		await _frames(int((lei.opaco_tempo + 0.2) * 60))
		check(t2 != null and is_equal_approx(_estinzione(t2), _estinzione_stile(t2)),
			"dalla presa il liquido torna trasparente (%.2f, stile %.2f)" % [_estinzione(t2) if t2 else -1.0, _estinzione_stile(t2) if t2 else -1.0])
		_rianima()
	_fine()


func _fine() -> void:
	Input.action_release(&"spray")
	Input.action_release(&"suck")
	Input.action_release(&"move_forward")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- La stanza ------------------------------------------------------------------------------

## Una stanza nuova (lei com'era all'inizio della partita se [param dimostrativa], se no la prima volta è già passata).
func _nuova_stanza(dimostrativa := true) -> void:
	var vecchia := get_node_or_null(^"StanzaPozzeProva")
	if vecchia:
		vecchia.name = "Vecchia"
		vecchia.queue_free()
		await _frames(2)
	if GameState.is_dying:
		_rianima()
	e = STANZA.costruisci(self)
	r = e.passo * 2.5 + 0.6
	lei = e.lei
	acqua = lei.acqua
	acqua.prima_volta_dimostrativa = dimostrativa
	fasi = []
	acqua.fase_cambiata.connect(func(f): fasi.append([f, Engine.get_physics_frames()]))
	# (pause corte: l'avviso, la presa, la respinta e le distanze restano quelli veri)
	lei.prima_attesa = 3.0
	lei.pausa_min = 1.5
	lei.pausa_max = 1.5
	acqua.pausa_dopo = 1.0
	acqua.pausa_respinta = 1.0
	GameState.snapshot = {}
	p.water_pack.set_tank_amount(0.0)
	await _frames(3)


func _porta() -> Node:
	return e.get_parent().get_node(^"PortaStagna")


# --- Il giocatore ---------------------------------------------------------------------------

func _metti(locale: Vector3) -> void:
	p.teleport(e.to_global(locale) + Vector3(0, 0.05, 0), p.yaw, 0.0)


func _zaino() -> void:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)


func _pelo(t: WaterTank) -> Vector3:
	return Vector3(t.global_position.x, t.get_surface_global_y(), t.global_position.z)


func _pelo_pieno(t: WaterTank) -> float:
	return t.to_global(Vector3(0, t.inner_size.y * e.pieno, 0)).y


## Toglie il colore [param c] come chi gioca, dalla passerella a sud: lo aspira e aspetta che le sue pozze siano vuote.
func _togli(c: String) -> void:
	_zaino()
	var t: WaterTank = null
	for u: WaterTank in e.pozze_del_colore(c):
		if t == null or u.position.z > t.position.z:
			t = u
	p.teleport(Vector3(t.global_position.x, e.global_position.y + 0.05, e.global_position.z + e.passo * 2.5 + 0.6), 0.0, 0.0)
	await _frames(3)
	p.look_at_point(_pelo(t))
	Input.action_press(&"suck")
	for i in 30:
		await get_tree().physics_frame
	Input.action_release(&"suck")
	await _aspetta_tolto(c, 8.0)
	check(c in e.tolti, "tolto il %s" % c)


func _aspetta_tolto(c: String, secondi: float) -> void:
	for i in int(secondi * 60.0):
		if c in e.tolti:
			return
		await get_tree().physics_frame


## Cammina (col tasto avanti) lungo la passerella fino a [param d] m dal punto d'uscita della pozza [param t].
func _cammina_via(t: WaterTank, d: float) -> void:
	var meta := _punto_lontano(t, d + 0.3)
	p.look_at_point(meta + Vector3(0, 1.5, 0))
	p.pitch = 0.0
	Input.action_press(&"move_forward")
	for i in 60 * 3:
		await get_tree().physics_frame
		if _dist_uscita(t) >= d:
			break
		p.look_at_point(meta + Vector3(0, 1.5, 0))
	Input.action_release(&"move_forward")


## Il punto della linea di mezzo della passerella, a più di [param d] m dalla pozza [param t], più vicino al giocatore.
func _punto_lontano(t: WaterTank, d: float) -> Vector3:
	var migliore := Vector3.ZERO
	var dm := INF
	var s := 0.0
	while s < 8.0 * r:
		var q := LeiPozze._anello_punto(s, r)
		var g := e.to_global(Vector3(q.x, 0.0, q.y))
		var dg := _in_pianta(g, lei.uscita_scelta.global_position) if lei.uscita_scelta else lei._distanza_punto(g, t)
		if dg > d:
			var dd := g.distance_to(p.global_position)
			if dd < dm:
				dm = dd
				migliore = g
		s += 0.1
	return migliore


## Dopo una presa vera (kill_player): la scena della morte si toglie prima che finisca (la ripartenza ricaricherebbe la
## scena del test) e il giocatore torna quello di prima, con la camera al suo posto. Il motore resta nella presa: la
## stanza va rifatta.
func _rianima() -> void:
	var seq: Node = GameState.get(&"_death_sequence")
	if is_instance_valid(seq):
		seq.free()
	p.camera.transform = _camera
	GameState.is_dying = false
	GameState.player = p
	p.input_enabled = true


# --- Attese e controlli ---------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secondi(s: float) -> void:
	await _frames(int(s * 60.0))


## Aspetta la prossima fase [param f] del motore (al più [param secondi]); ritorna [fase, fotogramma], o [] se non arriva.
func _aspetta(f: F, secondi: float) -> Array:
	var da := fasi.size()
	for i in int(secondi * 60.0):
		for k in range(da, fasi.size()):
			if fasi[k][0] == f:
				return fasi[k]
		await get_tree().physics_frame
	for k in range(da, fasi.size()):
		if fasi[k][0] == f:
			return fasi[k]
	return []


## Segue la luce del giro fino alla fase [param f] del motore (al più [param secondi]): le pozze sotto cui passa (in
## ordine), se sono una accanto all'altra, la vicinanza più alta, l'energia più bassa dopo il primo secondo e quante volte
## salta (più di 0,5 m in un fotogramma).
func _segui_luce(f: F, secondi: float) -> Dictionary:
	var out := {"arrivo": [], "pozze": [], "di_fila": true, "vicinanza": 0.0, "energia_min": INF, "energia_centro_min": INF,
			"salti": 0, "in_giro": false, "fuori_max": 0.0}
	var da := fasi.size()
	var prima := Vector3.INF
	var t0 := Engine.get_physics_frames()
	for i in int(secondi * 60.0):
		for k in range(da, fasi.size()):
			if fasi[k][0] == f:
				out["arrivo"] = fasi[k]
		if not (out["arrivo"] as Array).is_empty():
			break
		await get_tree().physics_frame
		if not acqua.in_giro() or not _luce_accesa():
			# (spenta fra due pozze: il salto si misura solo fra due istanti accesi di fila)
			prima = Vector3.INF
			continue
		out["in_giro"] = true
		var q := acqua.punto_luce
		if prima != Vector3.INF and _in_pianta(q, prima) > 0.5:
			out["salti"] += 1
		prima = q
		out["vicinanza"] = maxf(out["vicinanza"], acqua.vicinanza)
		var en: float = AcquaDiLei._luce.light_energy / AcquaDiLei.LUCE_SOTTO
		if Engine.get_physics_frames() - t0 > 90:
			out["energia_min"] = minf(out["energia_min"], en)
		# sotto un bordino (la striscia di 10 cm fra due pozze): quanto è accesa lì
		var dentro := false
		for u in e.pozze():
			var dq := e.global_basis.inverse() * (q - u.global_position)
			if absf(dq.x) < 0.5 and absf(dq.z) < 0.5:
				dentro = true
		if not dentro:
			out["fuori_max"] = maxf(out["fuori_max"], en)
		for u in e.pozze():
			if _in_pianta(u.global_position, q) < 0.15 and Engine.get_physics_frames() - t0 > 90:
				out["energia_centro_min"] = minf(out["energia_centro_min"], en)
			if _in_pianta(u.global_position, q) < 0.15:
				var viste: Array = out["pozze"]
				if viste.is_empty() or viste.back() != u:
					if not viste.is_empty() and not (u in lei._vicine(viste.back())):
						out["di_fila"] = false
					viste.append(u)
	return out


## L'estinzione più bassa dei tre canali (1/m) del liquido della pozza [param t] adesso (dal materiale), e quella del
## suo stile.
func _estinzione(t: WaterTank) -> float:
	var b := t.get_node(^"Acqua") as WaterBody
	var ab: Vector3 = b.material.get_shader_parameter(&"absorption")
	var tu: float = b.material.get_shader_parameter(&"turbidity")
	return minf(minf(ab.x, ab.y), ab.z) + tu


func _estinzione_stile(t: WaterTank) -> float:
	var st: WaterStyle = (t.get_node(^"Acqua") as WaterBody).style
	return minf(minf(st.absorption.x, st.absorption.y), st.absorption.z) + st.turbidity


## In pianta, dal giocatore al punto d'uscita dove sta venendo lei (o, senza, a quello più vicino della pozza [param t]).
func _dist_uscita(t: WaterTank = null) -> float:
	if lei.uscita_scelta:
		return _in_pianta(p.global_position, lei.uscita_scelta.global_position)
	return lei._distanza(p, t) if t else INF


func _luce_accesa() -> bool:
	var l := AcquaDiLei._luce
	return l != null and is_instance_valid(l) and l.visible and l.light_energy > 0.05


func _aspetta_lontana(secondi: float) -> void:
	for i in int(secondi * 60.0):
		if acqua.fase == F.LONTANA:
			return
		await get_tree().physics_frame


static func _in_pianta(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## La pozza piena del bordo più vicina al giocatore.
func _piu_vicina() -> WaterTank:
	var migliore: WaterTank
	var dm := INF
	for t in lei._pozze_buone():
		var d := lei._distanza(p, t)
		if d < dm:
			dm = d
			migliore = t
	return migliore


func _ce_ne_e_una_in_vista() -> bool:
	for t in lei._pozze_buone():
		if lei._distanza(p, t) >= lei.distanza_dimostrativa and lei._la_vede(p, t):
			return true
	return false


func _sotto_pozza_piena(pos: Vector3) -> bool:
	for t in e.pozze():
		if _in_pianta(t.global_position, pos) < 0.1:
			return lei._piena(t)
	return false
