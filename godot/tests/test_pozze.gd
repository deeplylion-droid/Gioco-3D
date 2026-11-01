extends Node
## Test automatico della stanza delle pozze colorate (EnigmaPozze; GDD, "La stanza delle pozze colorate", scelte
## dell'utente del 31 ottobre), col giocatore vero: si guarda la pozza dalla passerella e si tiene il tasto destro
## (aspira), come chi gioca.
## 1. La griglia: 25 pozze piene, 5 per colore (arancione, rosa, viola, turchese, bianco latte); ogni riga e ogni
##    colonna ha tutti i colori, due pozze dello stesso colore non si toccano nemmeno in diagonale, ogni colore ha
##    pozze sul bordo; la porta è chiusa e il lampeggiante spento.
## 2. Risolto nei due ordini (turchese, viola, arancione e al contrario): aspirando da una pozza il serbatoio prende il
##    suo colore (quello di prima si butta) e tutte le pozze di quel colore si svuotano col gorgo; al terzo colore
##    giusto la porta si apre e si raggiunge il checkpoint.
## 3. Sbagliato e poi giusto: al terzo colore sbagliato il lampeggiante lampeggia, la porta resta chiusa, non si aspira
##    e in pochi secondi tutte le pozze si riempiono di nuovo coi loro colori; poi i tre giusti la aprono.
## 4. Un quarto colore non comincia mentre tre si stanno togliendo.
## 5. Lo stato salvato a metà (un colore tolto, uno che si stava svuotando, lo sbaglio) e a enigma risolto, ripreso in
##    una stanza nuova come dopo un checkpoint o Continua.
## 6. Chi cade in una pozza piena esce saltando sulla passerella.
## Per ora nella stanza grigia di prova (tests/pozze/stanza_prova.gd); con la stanza vera di ambienti-1 si prova lì.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_pozze.gd

const PLAYER := "res://scenes/player/player.tscn"
const STANZA := preload("res://tests/pozze/stanza_prova.gd")

var p: Player
var e: EnigmaPozze
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
	await _nuova_stanza()

	print("1. La griglia")
	check(e.pozze().size() == 25, "25 pozze (%d)" % e.pozze().size())
	var ok_colori := true
	for c in EnigmaPozze.COLORI:
		ok_colori = ok_colori and e.pozze_del_colore(c).size() == 5
	check(ok_colori, "5 pozze per ognuno dei 5 colori")
	check(_righe_e_colonne(), "ogni riga e ogni colonna ha tutti e 5 i colori")
	check(_nessuna_vicina(), "due pozze dello stesso colore non si toccano, nemmeno in diagonale")
	check(_tutti_sul_bordo(), "ogni colore ha pozze sul bordo, a portata dalla passerella")
	check(_tutte_piene(), "le pozze sono piene, ognuna del suo colore")
	check(not EnigmaPozze.GIUSTI.has(WaterMix.ROSA) and not EnigmaPozze.GIUSTI.has(WaterMix.BIANCO_LATTE) and EnigmaPozze.GIUSTI.size() == 3,
		"i tre giusti sono turchese, viola e arancione")
	check(not _porta().aperta and not _lampeggia(), "la porta è chiusa e il lampeggiante spento")
	var in_tabella := 0
	for b in WaterManager.get_bodies():
		if is_instance_valid(b) and e.is_ancestor_of(b):
			in_tabella += 1
	check(in_tabella == 0, "le pozze non prendono posti nella tabella delle masse d'acqua dell'addon (%d)" % in_tabella)

	print("2. Risolto nei due ordini")
	await _risolvi([WaterMix.TURCHESE, WaterMix.VIOLA, WaterMix.ARANCIONE], "turchese, viola, arancione")
	await _nuova_stanza()
	await _risolvi([WaterMix.ARANCIONE, WaterMix.VIOLA, WaterMix.TURCHESE], "arancione, viola, turchese")

	print("3. Sbagliato e poi giusto")
	await _nuova_stanza()
	for c in [WaterMix.ROSA, WaterMix.VIOLA]:
		await _togli(c)
	check(e.stato == EnigmaPozze.Stato.APERTO and not _porta().aperta, "con due colori tolti non succede niente")
	await _togli(WaterMix.ARANCIONE)
	check(e.stato == EnigmaPozze.Stato.SBAGLIATO, "al terzo colore, sbagliato (rosa, viola, arancione)")
	check(not _porta().aperta, "la porta resta chiusa")
	var visto_acceso := false
	var visto_spento := false
	for i in 50:
		await get_tree().physics_frame
		if _lampeggia():
			visto_acceso = true
		else:
			visto_spento = true
	check(visto_acceso and visto_spento, "il lampeggiante rosso lampeggia")
	var bianca: WaterTank = e.pozze_del_colore(WaterMix.BIANCO_LATTE)[0]
	check(not bianca.suckable and not bianca.is_in_group(&"water_sources"), "mentre si riempiono di nuovo non si aspira")
	var t0 := Time.get_ticks_msec()
	for i in 60 * 12:
		await get_tree().physics_frame
		if e.stato == EnigmaPozze.Stato.APERTO:
			break
	var dt := (Time.get_ticks_msec() - t0) / 1000.0
	check(e.stato == EnigmaPozze.Stato.APERTO and _tutte_piene(), "in pochi secondi le pozze sono di nuovo piene coi loro colori (%.1f s)" % dt)
	check(e.tolti.is_empty() and not _lampeggia() and not _porta().aperta, "si riparte da capo: niente tolto, lampeggiante spento, porta chiusa")
	await _risolvi([WaterMix.VIOLA, WaterMix.TURCHESE, WaterMix.ARANCIONE], "dopo lo sbaglio, viola, turchese, arancione")

	print("4. Un quarto colore no")
	await _nuova_stanza()
	for c in [WaterMix.ROSA, WaterMix.VIOLA, WaterMix.TURCHESE]:
		await _aspira(c, 0.4)
	check(e.svuotando.size() + e.tolti.size() == 3, "tre colori cominciati (%s, %s)" % [e.svuotando, e.tolti])
	await _aspira(WaterMix.BIANCO_LATTE, 0.6)
	check(not WaterMix.BIANCO_LATTE in e.svuotando and not WaterMix.BIANCO_LATTE in e.tolti and _piene(WaterMix.BIANCO_LATTE),
		"il quarto (bianco latte) non comincia e le sue pozze restano piene")
	await _aspetta_stato(EnigmaPozze.Stato.SBAGLIATO, 8.0)
	await _aspetta_stato(EnigmaPozze.Stato.APERTO, 12.0)

	print("5. Lo stato salvato")
	await _nuova_stanza()
	await _togli(WaterMix.TURCHESE)
	await _aspira(WaterMix.VIOLA, 0.4)
	check(WaterMix.VIOLA in e.svuotando and e.tolti == [WaterMix.TURCHESE], "un colore tolto e uno che si sta svuotando")
	var salvato := _salva()
	await _nuova_stanza()
	_carica(salvato)
	await _frames(3)
	check(e.tolti.size() == 2 and WaterMix.TURCHESE in e.tolti and WaterMix.VIOLA in e.tolti and e.svuotando.is_empty(),
		"ripreso: quello che si svuotava riparte già vuoto (%s)" % [e.tolti])
	check(_vuote(WaterMix.TURCHESE) and _vuote(WaterMix.VIOLA) and _piene(WaterMix.ARANCIONE) and _piene(WaterMix.ROSA),
		"le pozze vuote e piene sono quelle giuste")
	await _togli(WaterMix.ARANCIONE)
	check(e.stato == EnigmaPozze.Stato.RISOLTO and _porta().aperta, "e col terzo colore si risolve")
	salvato = _salva()
	await _nuova_stanza()
	_carica(salvato)
	await _frames(3)
	check(e.stato == EnigmaPozze.Stato.RISOLTO and _porta().aperta and _porta().aperta_subito, "ripreso risolto: la porta è già aperta, senza animazione")
	check(_vuote(WaterMix.TURCHESE) and _vuote(WaterMix.VIOLA) and _vuote(WaterMix.ARANCIONE) and _piene(WaterMix.ROSA) and _piene(WaterMix.BIANCO_LATTE),
		"e le pozze dei tre giusti sono vuote")
	# lo sbaglio a metà
	await _nuova_stanza()
	for c in [WaterMix.ROSA, WaterMix.VIOLA, WaterMix.ARANCIONE]:
		await _togli(c)
	check(e.stato == EnigmaPozze.Stato.SBAGLIATO, "uno sbaglio")
	salvato = _salva()
	await _nuova_stanza()
	_carica(salvato)
	await _frames(3)
	check(e.stato == EnigmaPozze.Stato.APERTO and _tutte_piene() and e.tolti.is_empty() and not _lampeggia(),
		"ripreso a metà dello sbaglio: riparte già ricaricato")

	print("6. Dentro una pozza")
	await _nuova_stanza()
	var t: WaterTank = e.pozze_del_colore(WaterMix.ROSA)[0]
	var sud := _pozza_sul_bordo(WaterMix.ROSA)
	t = sud
	p.teleport(t.global_position + Vector3(0, 0.05, 0), 0.0, 0.0)
	await _frames(20)
	check(p.global_position.y < -0.5, "chi cade in una pozza sta sul fondo, con l'acqua alla vita (%.2f)" % p.global_position.y)
	# verso la passerella a sud (+Z): si salta e si avanza
	p.teleport(p.global_position, 0.0, 0.0)
	p.yaw = PI
	var fuori := false
	for i in 4:
		Input.action_press(&"move_forward")
		Input.action_press(&"jump")
		await _frames(2)
		Input.action_release(&"jump")
		for k in 50:
			await get_tree().physics_frame
			if p.global_position.y > -0.05 and p.global_position.z > t.global_position.z + e.lato * 0.5 + 0.2:
				fuori = true
				break
		Input.action_release(&"move_forward")
		if fuori:
			break
	check(fuori, "esce saltando sulla passerella (%s)" % p.global_position)

	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- La stanza ------------------------------------------------------------------------------

func _nuova_stanza() -> void:
	var vecchia := get_node_or_null(^"StanzaPozzeProva")
	if vecchia:
		vecchia.name = "Vecchia"
		vecchia.queue_free()
		await _frames(2)
	e = STANZA.costruisci(self)
	GameState.snapshot = {}
	p.water_pack.set_tank_amount(0.0)
	await _frames(3)


func _porta() -> Node:
	return e.get_parent().get_node(^"PortaStagna")


func _lampeggia() -> bool:
	var lamp := e.get_parent().get_node(^"LampeggianteErrore")
	for l in lamp.find_children("*", "Light3D", true, false):
		if (l as Light3D).visible:
			return true
	return false


# --- Azioni del giocatore -------------------------------------------------------------------

func _zaino() -> void:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)


## La pozza del colore [param c] sulla riga a sud (verso +Z), quella davanti alla passerella dove si sta.
func _pozza_sul_bordo(c: String) -> WaterTank:
	var migliore: WaterTank = null
	for t: WaterTank in e.pozze_del_colore(c):
		if migliore == null or t.position.z > migliore.position.z:
			migliore = t
	return migliore


## Sulla passerella davanti alla pozza di [param c] sul bordo, guardandola, col tasto destro per [param secondi].
func _aspira(c: String, secondi: float) -> void:
	_zaino()
	var t := _pozza_sul_bordo(c)
	var q := t.global_position
	var bordo_sud := e.global_position.z + e.passo * 2.5
	p.teleport(Vector3(q.x, e.global_position.y, bordo_sud + 0.6), 0.0, 0.0)
	await _frames(3)
	p.look_at_point(Vector3(q.x, t.get_surface_global_y(), q.z))
	var prima: Dictionary = p.water_pack.water_mix.duplicate()
	var prima_l: float = p.water_pack.tank_amount
	Input.action_press(&"suck")
	for i in int(secondi * 60.0):
		await get_tree().physics_frame
	Input.action_release(&"suck")
	await _frames(2)
	if prima_l > 0.5 and not prima.is_empty() and WaterMix.frazione(prima, c) < 0.99 and t.suckable:
		check(WaterMix.frazione(p.water_pack.water_mix, c) > 0.99, "aspirando il %s, il serbatoio butta il colore di prima e diventa %s" % [c, c])


## Toglie il colore [param c] come chi gioca: lo aspira e aspetta che le sue pozze siano vuote.
func _togli(c: String) -> void:
	await _aspira(c, 0.5)
	var cominciato := c in e.svuotando or c in e.tolti
	check(cominciato, "aspirando da una pozza %s cominciano a svuotarsi tutte le pozze %s" % [c, c])
	if not cominciato:
		return
	check(WaterMix.frazione(p.water_pack.water_mix, c) > 0.99 and p.water_pack.tank_amount > 1.0,
		"il serbatoio prende il %s (%.1f l, %s)" % [c, p.water_pack.tank_amount, p.water_pack.water_mix])
	var gorgo := false
	for i in 60 * 6:
		await get_tree().physics_frame
		for t: WaterTank in e.pozze_del_colore(c):
			if t.get_drain_strength() > 0.0 and t.fill > 0.05:
				gorgo = true
		if c in e.tolti:
			break
	check(c in e.tolti and _vuote(c), "le 5 pozze %s si sono svuotate" % c)
	check(gorgo, "col gorgo dello scarico")
	var altre := true
	for k in EnigmaPozze.COLORI:
		if k != c and not k in e.tolti and not k in e.svuotando:
			altre = altre and _piene(k)
	check(altre, "le pozze degli altri colori restano piene")


func _risolvi(ordine: Array, nome: String) -> void:
	for c in ordine:
		await _togli(c)
	await _frames(3)
	check(e.stato == EnigmaPozze.Stato.RISOLTO, "%s: risolto" % nome)
	check(_porta().aperta and not _porta().aperta_subito, "la porta stagna si apre")
	check(not _lampeggia(), "il lampeggiante resta spento")
	check(GameState.snapshot.get("checkpoint", "").ends_with("CheckpointRisolto"), "si raggiunge il checkpoint a enigma risolto (%s)" % GameState.snapshot.get("checkpoint", ""))
	check(_piene(WaterMix.ROSA) and _piene(WaterMix.BIANCO_LATTE), "restano piene le pozze rosa e bianco latte")


func _aspetta_stato(s: EnigmaPozze.Stato, secondi: float) -> void:
	for i in int(secondi * 60.0):
		if e.stato == s:
			return
		await get_tree().physics_frame


# --- Salvataggio ----------------------------------------------------------------------------

## Lo stato dell'enigma e delle pozze, come lo salva GameState (gruppo "persist"), per nome.
func _salva() -> Dictionary:
	var d := {"enigma": e.save_state()}
	for t in e.pozze():
		d[String(t.name)] = t.save_state()
	return JSON.parse_string(JSON.stringify(d))


## Come GameState: prima l'enigma, poi le pozze (sono sue figlie).
func _carica(d: Dictionary) -> void:
	e.load_state(d["enigma"])
	for t in e.pozze():
		t.load_state(d[String(t.name)])


# --- Controlli ------------------------------------------------------------------------------

func _griglia() -> Array:
	var g := []
	for riga in 5:
		var r := []
		for colonna in 5:
			r.append(EnigmaPozze.colore_di(colonna, riga))
		g.append(r)
	return g


func _righe_e_colonne() -> bool:
	var g := _griglia()
	for i in 5:
		var riga := {}
		var colonna := {}
		for j in 5:
			riga[g[i][j]] = true
			colonna[g[j][i]] = true
		if riga.size() != 5 or colonna.size() != 5:
			return false
	return true


func _nessuna_vicina() -> bool:
	var g := _griglia()
	for i in 5:
		for j in 5:
			for di in [-1, 0, 1]:
				for dj in [-1, 0, 1]:
					if di == 0 and dj == 0:
						continue
					var a: int = i + di
					var b: int = j + dj
					if a >= 0 and a < 5 and b >= 0 and b < 5 and g[a][b] == g[i][j]:
						return false
	return true


func _tutti_sul_bordo() -> bool:
	var g := _griglia()
	var sul_bordo := {}
	for i in 5:
		for j in 5:
			if i == 0 or i == 4 or j == 0 or j == 4:
				sul_bordo[g[i][j]] = true
	return sul_bordo.size() == 5


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


func _tutte_piene() -> bool:
	for c in EnigmaPozze.COLORI:
		if not _piene(c):
			return false
	return true


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
