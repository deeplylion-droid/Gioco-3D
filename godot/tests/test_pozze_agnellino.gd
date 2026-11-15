extends Node
## L'agnellino nella stanza delle pozze (AgnellinoPozze, build 0.5.0, «La storia»: ostacola e si sente soltanto), nella
## stanza di prova col giocatore vero che aspira dalla passerella:
## 1. dopo il primo colore tolto non succede niente;
## 2. dopo il secondo: le zampette sotto il pavimento, il volantino, poi il PRIMO colore si riempie di nuovo (mentre si
##    riempie non si aspira e non conta fra i tolti); l'agnellino non si vede;
## 3. l'enigma si risolve allo stesso modo, togliendo di nuovo quel colore;
## 4. una volta sola per partita (anche in una stanza nuova, come dopo una ripartenza); con la partita nuova torna;
## 5. mentre lei è fuori non comincia: aspetta che sia tornata sotto;
## 6. con l'interruttore spento non succede;
## 7. lo stato si salva: dopo l'agnellino non torna, e un colore che si riempiva riparte pieno.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_pozze_agnellino.gd

const PLAYER := "res://scenes/player/player.tscn"
const STANZA := preload("res://tests/pozze/stanza_prova.gd")
const STORIA := preload("res://scripts/game/stato_storia.gd")

var p: Player
var e: EnigmaPozze
var _passed := 0
var _failed := 0
var _cominciato := 0
var _riempito := ""


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
	STORIA.azzera()
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _nuova_stanza()
	check(e.agnellino != null and e.agnellino.attivo, "nella stanza c'è l'agnellino, acceso")

	print("1. Dopo il primo colore non succede niente")
	await _togli(WaterMix.VIOLA)
	await _secondi(e.agnellino.attesa + 1.0)
	check(_cominciato == 0 and not e.agnellino.in_corso(), "tolto il viola: niente")

	print("2. Dopo il secondo: zampette, volantino, e il primo colore si riempie di nuovo")
	var z0 := int(Audio.conteggio.get(&"zampette_condotto", 0))
	var v0 := int(Audio.conteggio.get(&"cancello_ruota", 0))
	await _togli(WaterMix.ARANCIONE)
	check(_cominciato == 0, "subito no: aspetta un attimo")
	var t0 := Engine.get_physics_frames()
	await _fino_a(func(): return WaterMix.VIOLA in e.riempiendo, 15.0)
	var dopo := (Engine.get_physics_frames() - t0) / 60.0
	check(_cominciato == 1 and WaterMix.VIOLA in e.riempiendo, "poi comincia a riempirsi il viola, il primo tolto (dopo %.1f s)" % dopo)
	if Audio.stream_di(&"zampette_condotto") != null:
		check(int(Audio.conteggio.get(&"zampette_condotto", 0)) > z0, "prima le zampette sotto il pavimento")
	if Audio.stream_di(&"cancello_ruota") != null:
		check(int(Audio.conteggio.get(&"cancello_ruota", 0)) > v0, "e il volantino che gira")
	check(not WaterMix.VIOLA in e.tolti and _nessuna_aspirabile(WaterMix.VIOLA), "mentre si riempie non è fra i tolti e non si aspira")
	check(_nessun_nodo_visibile(e.agnellino), "l'agnellino non si vede")
	await _aspira(WaterMix.VIOLA, 0.5)
	check(not WaterMix.VIOLA in e.svuotando, "aspirandolo mentre si riempie non ricomincia a svuotarsi")
	await _fino_a(func(): return _riempito != "", 15.0)
	check(_riempito == WaterMix.VIOLA and _piene(WaterMix.VIOLA) and e.tolti == [WaterMix.ARANCIONE],
		"il viola è di nuovo pieno: va tolto ancora (tolti %s)" % [e.tolti])

	print("3. L'enigma si risolve allo stesso modo")
	await _togli(WaterMix.VIOLA)
	await _togli(WaterMix.TURCHESE)
	await _secondi(0.2)
	check(e.stato == EnigmaPozze.Stato.RISOLTO, "viola di nuovo e turchese: risolto")

	print("4. Una volta sola per partita")
	await _nuova_stanza()
	await _togli(WaterMix.TURCHESE)
	await _togli(WaterMix.VIOLA)
	await _secondi(e.agnellino.attesa + e.agnellino.durata_zampette + 2.0)
	check(_cominciato == 0 and e.riempiendo.is_empty() and e.tolti.size() == 2, "in una stanza nuova della stessa partita non torna")
	GameState.reset_progress()
	await _nuova_stanza()
	await _togli(WaterMix.TURCHESE)
	await _togli(WaterMix.ARANCIONE)
	await _fino_a(func(): return _cominciato > 0, 15.0)
	check(_cominciato == 1, "con la partita nuova torna")
	await _fino_a(func(): return _riempito != "", 15.0)
	check(_riempito == WaterMix.TURCHESE, "(e riempie il turchese, il primo tolto)")

	print("5. Mentre lei è fuori aspetta")
	STORIA.azzera()
	await _nuova_stanza()
	var aq := e.lei.acqua
	await _togli(WaterMix.VIOLA)
	aq.set_physics_process(false)
	aq.fase = AcquaDiLei.Fase.SU
	await _togli(WaterMix.TURCHESE)
	await _secondi(e.agnellino.attesa + 3.0)
	check(_cominciato == 0, "con lei fuori non comincia")
	aq.fase = AcquaDiLei.Fase.CALMA
	aq.set_physics_process(true)
	await _fino_a(func(): return _cominciato > 0, 8.0)
	check(_cominciato == 1, "tornata sotto, comincia")
	await _fino_a(func(): return _riempito != "", 15.0)

	print("6. Con l'interruttore spento non succede")
	STORIA.azzera()
	await _nuova_stanza()
	e.agnellino.attivo = false
	await _togli(WaterMix.VIOLA)
	await _togli(WaterMix.ARANCIONE)
	await _secondi(e.agnellino.attesa + e.agnellino.durata_zampette + 2.0)
	check(_cominciato == 0 and e.riempiendo.is_empty(), "spento: niente")

	print("7. Lo stato si salva")
	STORIA.azzera()
	await _nuova_stanza()
	await _togli(WaterMix.VIOLA)
	await _togli(WaterMix.ARANCIONE)
	await _fino_a(func(): return WaterMix.VIOLA in e.riempiendo, 15.0)
	await _secondi(1.0)
	var d := _salva()
	check(bool(d["enigma"].get("agnellino", false)), "nel salvataggio c'è che l'agnellino è passato")
	STORIA.azzera()
	await _nuova_stanza()
	_carica(d)
	await _secondi(0.3)
	check(STORIA.agnellino_pozze, "ripreso il salvataggio, non torna")
	check(_piene(WaterMix.VIOLA) and not WaterMix.VIOLA in e.tolti and e.riempiendo.is_empty() and not WaterMix.VIOLA in e.svuotando,
		"il viola, che si stava riempiendo, riparte pieno")
	_fine()


func _nuova_stanza() -> void:
	var vecchia := get_node_or_null(^"StanzaPozzeProva")
	if vecchia:
		vecchia.name = "Vecchia"
		vecchia.queue_free()
		await _frames(2)
	e = STANZA.costruisci(self)
	GameState.snapshot = {}
	p.water_pack.set_tank_amount(0.0)
	_cominciato = 0
	_riempito = ""
	e.agnellino.comincia.connect(func(): _cominciato += 1)
	e.agnellino.riempito.connect(func(c): _riempito = c)
	# (lei sotto le pozze ha i suoi test: qui non viene; al passo 5 la si mette «fuori» a mano)
	if e.lei and e.lei.acqua:
		e.lei.acqua.abilitata = false
	await _frames(3)


func _zaino() -> void:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)


func _pozza_sul_bordo(c: String) -> WaterTank:
	var migliore: WaterTank = null
	for t: WaterTank in e.pozze_del_colore(c):
		if migliore == null or t.position.z > migliore.position.z:
			migliore = t
	return migliore


func _aspira(c: String, secondi: float) -> void:
	_zaino()
	var t := _pozza_sul_bordo(c)
	var q := t.global_position
	var bordo_sud := e.global_position.z + e.passo * 2.5
	p.teleport(Vector3(q.x, e.global_position.y, bordo_sud + 0.6), 0.0, 0.0)
	await _frames(3)
	p.look_at_point(Vector3(q.x, t.get_surface_global_y(), q.z))
	p.water_pack.set_tank_amount(0.0)
	Input.action_press(&"suck")
	for i in int(secondi * 60.0):
		await get_tree().physics_frame
	Input.action_release(&"suck")
	await _frames(2)


func _togli(c: String) -> void:
	await _aspira(c, 0.5)
	for i in 60 * 8:
		await get_tree().physics_frame
		if c in e.tolti:
			break
	check(c in e.tolti and _vuote(c), "tolto il %s" % c)


func _nessuna_aspirabile(c: String) -> bool:
	for t: WaterTank in e.pozze_del_colore(c):
		if t.suckable:
			return false
	return true


func _nessun_nodo_visibile(n: Node) -> bool:
	return n.find_children("*", "VisualInstance3D", true, false).is_empty()


func _salva() -> Dictionary:
	var d := {"enigma": e.save_state()}
	for t in e.pozze():
		d[String(t.name)] = t.save_state()
	return JSON.parse_string(JSON.stringify(d))


func _carica(d: Dictionary) -> void:
	e.load_state(d["enigma"])
	for t in e.pozze():
		t.load_state(d[String(t.name)])


func _piene(c: String) -> bool:
	for t: WaterTank in e.pozze_del_colore(c):
		if t.fill < e.pieno - 0.003 or WaterMix.frazione(t.mix, c) < 0.99:
			return false
	return true


func _vuote(c: String) -> bool:
	for t: WaterTank in e.pozze_del_colore(c):
		if t.fill > 0.002:
			return false
	return true


func _fino_a(cond: Callable, secondi: float) -> bool:
	for i in int(secondi * 60.0):
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
