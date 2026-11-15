extends Node
## Test automatico di lei sotto il pavimento della stanza delle pozze (LeiPozze, 0.4.0 «L'acqua è sua»), col giocatore
## vero nella stanza grigia di prova e un motore di lei finto (tests/pozze/motore_finto.gd), che non si vede e tiene
## l'elenco delle fasi. Le pause fra un'uscita e l'altra qui sono corte (1,5 s); l'avviso, il silenzio, il colpo e le
## distanze sono quelli veri.
## 0. Tempi e distanze esportati, coi valori di partenza (letale acceso, pausa 15-20 s, avviso 3 s, portata 2 m).
## 1. Senza colori tolti lei non c'è (e senza il motore di lei non c'è mai).
## 2. Tolto il primo colore: canto e luce che passa di pozza in pozza, poi la prima uscita, lontana dal giocatore e dove
##    guarda, che non prende.
## 3. Poi punta la pozza piena del bordo più vicina al giocatore: chi resta lì è preso e muore.
## 4. Allontanandosi di 3 m lungo la passerella, anche partendo da un angolo, si è salvi.
## 5. Col getto sulla pozza mentre esce, viene respinta.
## 6. Svuotando quel colore, viene cacciata.
## 7. Tre colori sbagliati: le pozze si riempiono di nuovo, tutte le porte si riaprono e lei torna a uscire.
## 8. L'enigma si risolve come prima con lei sveglia; risolto, se ne va.
## 9. Letale spento: esce e prende, ma solo paura.
## 10. Mai senza scampo: non esce mentre il giocatore aspira senza vedere la pozza, è in una pozza o fuori dalla stanza;
##     dall'angolo c'è sempre una via di salvezza.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_pozze_lei.gd

const PLAYER := "res://scenes/player/player.tscn"
const STANZA := preload("res://tests/pozze/stanza_prova.gd")
const MOTORE := preload("res://tests/pozze/motore_finto.gd")
## La linea di mezzo della passerella (m dal centro della griglia).
var r := 0.0

var p: Player
var e: EnigmaPozze
var lei: LeiPozze
var finto: Node
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
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(3)

	print("0. Tempi e distanze esportati")
	var l := LeiPozze.new()
	var esportati := {}
	for prop in l.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_EDITOR:
			esportati[String(prop["name"])] = true
	var nomi := ["letale", "prima_attesa", "pausa_min", "pausa_max", "avviso", "silenzio", "colpo", "durata_uscita",
			"ritorno", "portata", "raggio_getto", "distanza_dimostrativa", "distanza_attenzione", "angolo_vista",
			"velocita_fuga", "reazione", "margine_fuga"]
	var mancano := nomi.filter(func(n): return not esportati.has(n))
	check(mancano.is_empty(), "letale, tempi e distanze sono esportati (mancano: %s)" % [mancano])
	check(l.letale and is_equal_approx(l.pausa_min, 15.0) and is_equal_approx(l.pausa_max, 20.0) and is_equal_approx(l.avviso, 3.0)
			and is_equal_approx(l.portata, 2.0), "si parte con letale acceso, pausa di 15-20 s, avviso di 3 s e portata di 2 m")
	l.free()

	print("1. Senza colori tolti lei non c'è")
	await _nuova_stanza()
	_metti(Vector3(0, 0, r))
	await _secondi(8.0)
	check(lei.fase == LeiPozze.Fase.DORME and finto.fasi.is_empty() and finto.luci.is_empty(),
		"in 8 s con le pozze piene nessuna fase e nessuna luce (%s, %d fasi)" % [lei.nome_fase(), finto.fasi.size()])
	await _nuova_stanza(false)
	await _togli(WaterMix.ROSA)
	await _secondi(3.0)
	check(e.lei.fase == LeiPozze.Fase.DORME, "senza il motore di lei, anche col primo colore tolto lei non c'è")

	print("2. Il primo colore: il canto, la luce, l'uscita dimostrativa")
	await _nuova_stanza()
	await _togli(WaterMix.ROSA)
	await _frames(2)
	check(finto.quante(&"gira") == 1 and finto.luci.size() >= 1, "tolto il primo colore si sveglia: canto da sotto e luce rosa sotto una pozza")
	var a := await _aspetta(&"arriva", 10.0)
	check(not a.is_empty(), "dopo qualche secondo esce la prima volta")
	if a.is_empty():
		return _fine()
	check(finto.luci.size() >= 3, "intanto la luce è passata di pozza in pozza (%d)" % finto.luci.size())
	check(_luci_su_pozze_piene(), "la luce passa solo sotto pozze piene")
	var t: WaterTank = a[1]
	check(lei._distanza(p, t) >= lei.distanza_dimostrativa, "la prima uscita è lontana dal giocatore (%.1f m)" % lei._distanza(p, t))
	check(lei._la_vede(p, t) or not _ce_ne_e_una_in_vista(), "ed è dove il giocatore guarda")
	var es := await _aspetta(&"esce", 5.0)
	check(not es.is_empty() and bool(es[2].get("dimostrativa", false)), "è dimostrativa")
	check(not es.is_empty() and absf((es[3] - a[3]) / 60.0 - lei.avviso) < 0.1, "esce %.2f s dopo che la luce è arrivata nella pozza (avviso %.1f s)" % [(es[3] - a[3]) / 60.0 if not es.is_empty() else -1.0, lei.avviso])
	await _aspetta(&"torna", 5.0)
	check(lei.prese == 0 and not GameState.is_dying, "e non prende")

	print("3. Poi la pozza piena del bordo più vicina: chi resta lì è preso")
	a = await _aspetta(&"arriva", 8.0)
	check(not a.is_empty(), "esce di nuovo dopo la pausa")
	if a.is_empty():
		return _fine()
	t = a[1]
	check(t == _piu_vicina(), "punta la pozza piena del bordo più vicina al giocatore (%s)" % t.name)
	check(lei._distanza(p, t) <= lei.portata, "il giocatore è a portata (%.1f m)" % lei._distanza(p, t))
	var pr := await _aspetta(&"presa", 6.0)
	check(not pr.is_empty() and GameState.is_dying and GameState.last_death_cause == &"lei_pozze",
		"resta lì: al colpo lo prende e muore (%s)" % GameState.last_death_cause)
	_rianima()

	print("4. Allontanandosi lungo la passerella si è salvi, anche da un angolo")
	await _aspetta(&"gira", 6.0)
	_metti(Vector3(r, 0, r))
	a = await _aspetta(&"arriva", 8.0)
	if a.is_empty():
		check(false, "esce di nuovo")
		return _fine()
	t = a[1]
	check(lei._distanza(p, t) <= lei.portata, "dall'angolo punta una pozza a portata (%s, %.1f m)" % [t.name, lei._distanza(p, t)])
	var prese := lei.prese
	await _cammina_via(t, 3.0)
	check(lei._distanza(p, t) >= 3.0, "camminando lungo la passerella è a %.1f m dalla pozza prima che esca" % lei._distanza(p, t))
	await _aspetta(&"torna", 6.0)
	check(lei.prese == prese and not GameState.is_dying, "lei esce, sbatte e torna giù senza prenderlo")

	print("5. Col getto mentre esce, viene respinta")
	_metti(Vector3(0, 0, r))
	_zaino()
	p.water_pack.set_tank_amount(p.water_pack.tank_capacity)
	a = await _aspetta(&"arriva", 8.0)
	if a.is_empty():
		check(false, "esce di nuovo")
		return _fine()
	t = a[1]
	p.look_at_point(_pelo(t))
	await _aspetta(&"silenzio", 5.0)
	prese = lei.prese
	var respinte: int = finto.quante(&"respinta")
	Input.action_press(&"spray")
	for i in 60 * 3:
		await get_tree().physics_frame
		if finto.quante(&"respinta") > respinte or lei.prese > prese:
			break
	Input.action_release(&"spray")
	check(finto.quante(&"respinta") > respinte and lei.prese == prese and not GameState.is_dying,
		"col getto sulla pozza %s viene respinta e non lo prende" % t.name)
	if GameState.is_dying:
		_rianima()

	print("6. Svuotando quel colore, viene cacciata")
	await _aspetta(&"gira", 6.0)
	_metti(Vector3(0, 0, r))
	a = await _aspetta(&"arriva", 8.0)
	if a.is_empty():
		check(false, "esce di nuovo")
		return _fine()
	t = a[1]
	var colore := String(t.fill_pigment)
	p.look_at_point(_pelo(t))
	await _frames(2)
	prese = lei.prese
	var cacciate: int = finto.quante(&"cacciata")
	Input.action_press(&"suck")
	for i in 60 * 3:
		await get_tree().physics_frame
		if finto.quante(&"cacciata") > cacciate or finto.quante(&"esce") > 0 and lei.fase == LeiPozze.Fase.ESCE:
			break
	Input.action_release(&"suck")
	check(colore in e.svuotando or colore in e.tolti, "aspirando dalla pozza %s il suo colore comincia a svuotarsi" % t.name)
	check(finto.quante(&"cacciata") > cacciate and lei.prese == prese and not GameState.is_dying,
		"la pozza che si svuota è una porta che si chiude: viene cacciata")
	if GameState.is_dying:
		_rianima()

	print("7. Tre colori sbagliati: le pozze si riempiono e tutte le porte si riaprono")
	lei.pausa_min = 1000.0
	lei.pausa_max = 1000.0
	await _aspetta_fase(LeiPozze.Fase.GIRA, 6.0)
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
	lei.pausa_min = 1.5
	lei.pausa_max = 1.5
	lei._t = -0.5
	_metti(Vector3(0, 0, r))
	a = await _aspetta(&"arriva", 6.0)
	check(not a.is_empty(), "e lei torna a uscire")
	if not a.is_empty():
		await _cammina_via(a[1], 3.0)
	await _aspetta(&"torna", 6.0)
	check(not GameState.is_dying, "(e il giocatore si salva allontanandosi)")
	if GameState.is_dying:
		_rianima()

	print("8. L'enigma si risolve come prima, con lei sveglia")
	lei.letale = false
	for c in EnigmaPozze.GIUSTI:
		await _togli(c)
	await _frames(3)
	check(e.stato == EnigmaPozze.Stato.RISOLTO and _porta().aperta, "turchese, viola e arancione: risolto, la porta stagna si apre")
	check(lei.fase == LeiPozze.Fase.FINITA, "risolto, lei se ne va (%s)" % lei.nome_fase())
	var n: int = finto.fasi.size()
	await _secondi(5.0)
	check(finto.fasi.size() == n, "e non esce più")

	print("9. Letale spento: solo paura")
	await _nuova_stanza()
	lei.letale = false
	await _togli(WaterMix.ROSA)
	lei.dimostrativa_fatta = true
	pr = await _aspetta(&"presa", 12.0)
	check(not pr.is_empty() and not GameState.is_dying and p.input_enabled, "esce e prende, ma non si muore")
	var g := await _aspetta(&"gira", 6.0)
	check(not g.is_empty(), "e torna a girare sotto le pozze")

	print("10. Mai senza scampo")
	await _nuova_stanza()
	await _togli(WaterMix.ROSA)
	lei.dimostrativa_fatta = true
	lei._t = -1000.0
	_metti(Vector3(0, 0, r))
	await _frames(3)
	var vicina := _piu_vicina()
	p.look_at_point(_pelo(vicina))
	await _frames(2)
	p.water_pack.is_sucking = true
	check(lei._bersaglio() == vicina, "aspirando e guardando la pozza, la può puntare")
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
	var avviso := lei.avviso
	lei.avviso = 0.9
	check(not lei.via_di_salvezza(e.to_global(Vector3(r, 0, r)), angolo), "(e il controllo se ne accorge quando non c'è: con un avviso di 0,9 s no)")
	lei.avviso = avviso
	_fine()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- La stanza ------------------------------------------------------------------------------

func _nuova_stanza(con_motore := true) -> void:
	var vecchia := get_node_or_null(^"StanzaPozzeProva")
	if vecchia:
		vecchia.name = "Vecchia"
		vecchia.queue_free()
		await _frames(2)
	if finto:
		finto.queue_free()
	e = STANZA.costruisci(self)
	r = e.passo * 2.5 + 0.6
	lei = e.lei
	finto = MOTORE.new()
	add_child(finto)
	if con_motore:
		lei.motore = finto
	# (pause corte: l'avviso, il colpo e le distanze restano quelli veri)
	lei.prima_attesa = 3.0
	lei.pausa_min = 1.5
	lei.pausa_max = 1.5
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


## Cammina (col tasto avanti) lungo la passerella fino a [param d] m dalla pozza [param t].
func _cammina_via(t: WaterTank, d: float) -> void:
	var meta := _punto_lontano(t, d + 0.3)
	p.look_at_point(meta + Vector3(0, 1.5, 0))
	p.pitch = 0.0
	Input.action_press(&"move_forward")
	for i in 60 * 3:
		await get_tree().physics_frame
		if lei._distanza(p, t) >= d:
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
		if lei._distanza_punto(g, t) > d:
			var dd := g.distance_to(p.global_position)
			if dd < dm:
				dm = dd
				migliore = g
		s += 0.1
	return migliore


## Dopo una presa vera (kill_player): la scena della morte si toglie prima che finisca (la ripartenza ricaricherebbe la
## scena del test) e il giocatore torna quello di prima.
func _rianima() -> void:
	var seq: Node = GameState.get(&"_death_sequence")
	if is_instance_valid(seq):
		seq.queue_free()
	GameState.is_dying = false
	GameState.player = p
	p.input_enabled = true


# --- Attese e controlli ---------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secondi(s: float) -> void:
	await _frames(int(s * 60.0))


## Aspetta la prossima fase [param nome] del motore (al più [param secondi]); la ritorna, o [] se non arriva.
func _aspetta(nome: StringName, secondi: float) -> Array:
	var prima: int = finto.quante(nome)
	for i in int(secondi * 60.0):
		await get_tree().physics_frame
		if finto.quante(nome) > prima:
			return finto.ultima(nome)
	return []


func _aspetta_fase(f: LeiPozze.Fase, secondi: float) -> void:
	for i in int(secondi * 60.0):
		if lei.fase == f:
			return
		await get_tree().physics_frame


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


func _luci_su_pozze_piene() -> bool:
	for pos in finto.luci:
		var sotto: WaterTank = null
		for t in e.pozze():
			if Vector2(t.global_position.x - pos.x, t.global_position.z - pos.z).length() < 0.1:
				sotto = t
		if sotto == null or String(sotto.fill_pigment) == WaterMix.ROSA:
			return false
	return true
