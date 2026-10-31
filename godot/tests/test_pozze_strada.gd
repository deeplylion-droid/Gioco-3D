extends Node
## La stanza delle pozze colorate nel gioco vero (GDD, "La stanza delle pozze colorate", scelte dell'utente del 31
## ottobre), sulla strada della Risalita, col giocatore vero (si cammina col tasto avanti, si guarda la pozza e si tiene il
## tasto destro):
## 1. dalla partenza F9 "Fiume lento" (MenuProva.parti, come dal menu): il fiume e l'infermeria con le scorciatoie (le
##    provano test_risalita e test_infermeria_gioco), poi dalla porta nord dell'infermeria si entra nella stanza: c'è il
##    cartello col faretto accanto alla porta, le 25 pozze sono piene, la porta stagna è chiusa e il checkpoint
##    d'ingresso si scrive su disco;
## 2. Continua a metà: tolto un colore, una chiusura (i progressi in memoria azzerati) e Continua dal titolo ripartono
##    dall'ingresso con le pozze tutte piene e la porta chiusa; da lì si risolve (turchese, viola, arancione) e la porta
##    si apre, col checkpoint a enigma risolto scritto su disco;
## 3. Continua da risolto: la porta è già aperta e le pozze dei tre colori vuote; si passa la porta stagna e si sale la
##    scala di servizio fino alla porta di C3, verso il magazzino.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_pozze_strada.gd

const TITOLO := "res://scenes/ui/menu_principale.tscn"

var p: Player
var level: Node
var ris: Node
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
	GameState.save_to_disk = true
	_cancella_salvataggio()

	print("1. Dalla partenza F9 del fiume fino alla stanza delle pozze")
	check(not MenuProva.istantanea("fiume").is_empty(), "c'è la partenza F9 del fiume")
	MenuProva.parti(get_tree(), "fiume")
	await _aspetta_ripresa()
	_prendi_nodi()
	check(e != null, "nella Risalita c'è la stanza delle pozze con l'enigma (%s)" % (GameState.persist_key(e) if e else "-"))
	if e == null:
		_fine()
		return
	await _fino_alle_pozze()
	var inf := ris.get_node(^"Infermeria") as Node3D
	check(inf.get_node_or_null(^"CartelloPozze") != null and (inf.get_node_or_null(^"FarettoCartelloPozze/Luce") as Light3D).visible,
		"accanto alla porta nord dell'infermeria c'è il cartello col faretto acceso")
	check(_tutte_piene() and e.stato == EnigmaPozze.Stato.APERTO and not _porta_aperta(), "le pozze sono piene e la porta stagna è chiusa")
	var ingresso := String(GameState.salvataggio().get("checkpoint", ""))
	check(ingresso.begins_with("Risalita/") and ingresso.ends_with("CheckpointIngresso"),
		"entrando si scrive su disco il checkpoint d'ingresso (%s, ordine %d)" % [ingresso, int(GameState.salvataggio().get("order", 0))])

	print("2. Continua a metà")
	await _togli(WaterMix.TURCHESE)
	check(WaterMix.TURCHESE in e.tolti, "tolto il turchese")
	await _chiudi_e_continua()
	check(String(GameState.snapshot.get("checkpoint", "")) == ingresso, "Continua riparte dall'ingresso della stanza (%s)" % GameState.snapshot.get("checkpoint", ""))
	check(e != null and _tutte_piene() and e.tolti.is_empty() and not _porta_aperta(),
		"con le pozze tutte piene e la porta chiusa, come quando si è entrati")
	for c in [WaterMix.VIOLA, WaterMix.ARANCIONE, WaterMix.TURCHESE]:
		await _togli(c)
	await _frames(10)
	check(e.stato == EnigmaPozze.Stato.RISOLTO and _porta_aperta(), "turchese, viola e arancione: risolto, la porta stagna si apre")
	var risolto := String(GameState.salvataggio().get("checkpoint", ""))
	check(risolto.ends_with("CheckpointRisolto"), "il checkpoint a enigma risolto si scrive su disco (%s)" % risolto)

	print("3. Continua da risolto, poi su per la scala di servizio")
	await _chiudi_e_continua()
	check(String(GameState.snapshot.get("checkpoint", "")) == risolto, "Continua riparte dal checkpoint a enigma risolto")
	check(e != null and e.stato == EnigmaPozze.Stato.RISOLTO and _porta_aperta(), "la porta stagna è già aperta")
	var vuote := true
	for c in EnigmaPozze.GIUSTI:
		for t: WaterTank in e.pozze_del_colore(c):
			vuote = vuote and t.fill < 0.002
	check(vuote and _piene(WaterMix.ROSA) and _piene(WaterMix.BIANCO_LATTE), "le pozze dei tre colori giusti sono vuote, le altre piene")
	var porta := e.porta as Node3D
	var oltre := porta.global_position + porta.global_basis.z * -1.5
	var c3 := (ris.get_node(^"Marker/PortaC3") as Node3D).global_position
	var cima := (ris.get_node(^"Marker/CimaScala") as Node3D).global_position
	check(await _vai("oltre la porta stagna e su per la scala di servizio fino a C3", [porta.global_position + porta.global_basis.z * 0.8,
		oltre, cima, c3]), "si arriva alla porta di C3")
	_fine()


# --- La strada fino alle pozze -------------------------------------------------------------

func _prendi_nodi() -> void:
	level = get_tree().current_scene
	p = GameState.player
	ris = level.get_node_or_null(^"Risalita")
	e = level.find_child("EnigmaPozze", true, false) as EnigmaPozze if level else null


## Dall'ingresso del fiume: le scorciatoie del fiume e dell'infermeria, poi a piedi dalla porta nord nella stanza.
func _fino_alle_pozze() -> void:
	if ris.get(&"fiume") == null:
		ris.call(&"carica_subito")
		await _frames(30)
	var fiume := ris.get_node(^"Fiume/FiumeLento") as FiumeLento
	(fiume.get_node(^"Paratia1") as ParatiaFiume).a_destra = false
	(fiume.get_node(^"Paratia3") as ParatiaFiume).a_destra = false
	var porta_personale := ris.get_node(^"Fiume/Marker/PortaPersonale") as Node3D
	p.teleport(porta_personale.global_position + porta_personale.global_basis.z * 0.8, p.yaw, 0.0)
	await _frames(10)
	var inf := ris.get_node(^"Infermeria") as Node3D
	# (il giocatore è lontano, all'approdo: la porta nord dell'infermeria si apre verso dentro e spinge chi ci sta davanti)
	inf.get_node(^"Interruttore").set(&"powered", true)
	p.add_item(&"keycard", 1, "Keycard")
	await _frames(60 * 3)
	_prendi_nodi()
	await _vai("dall'approdo nell'infermeria e dalla porta nord nella stanza delle pozze", [
		porta_personale.global_position - porta_personale.global_basis.z * 1.5,
		inf.to_global(Vector3(1.6, 0, 3.6)), inf.to_global(Vector3(1.8, 0, 1.6)), inf.to_global(Vector3(0.0, 0, 0.0)),
		inf.to_global(Vector3(-2.2, 0, -2.4)), inf.to_global(Vector3(-2.2, 0, -3.8)), _davanti_alle_pozze(0.0)])
	await _frames(20)


## Sulla passerella sud (da cui si entra), davanti alla colonna [param x] della griglia (m dal centro, lungo X).
func _davanti_alle_pozze(x: float) -> Vector3:
	return e.to_global(Vector3(x, 0.0, e.passo * 2.5 + 0.6))


## La pozza del colore [param c] sulla riga a sud (verso la passerella da cui si entra).
func _pozza_sul_bordo(c: String) -> WaterTank:
	var migliore: WaterTank = null
	for t: WaterTank in e.pozze_del_colore(c):
		if migliore == null or t.position.z > migliore.position.z:
			migliore = t
	return migliore


## Come chi gioca: si va sulla passerella davanti alla pozza, la si guarda e si tiene il tasto destro; poi si aspetta
## che le pozze del colore siano vuote.
func _togli(c: String) -> void:
	_zaino()
	var t := _pozza_sul_bordo(c)
	await _vai("sulla passerella davanti alla pozza %s" % c, [_davanti_alle_pozze(t.position.x)])
	p.look_at_point(Vector3(t.global_position.x, t.get_surface_global_y(), t.global_position.z))
	Input.action_press(&"suck")
	for i in 30:
		await get_tree().physics_frame
	Input.action_release(&"suck")
	for i in 60 * 8:
		await get_tree().physics_frame
		if c in e.tolti or e.stato != EnigmaPozze.Stato.APERTO:
			break
	check(c in e.tolti or e.stato == EnigmaPozze.Stato.RISOLTO, "aspirando dalla pozza %s le pozze %s si svuotano" % [c, c])


func _zaino() -> void:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)


# --- Continua -------------------------------------------------------------------------------

## Una chiusura (i progressi in memoria si perdono, resta il disco) e Continua dal titolo.
func _chiudi_e_continua() -> void:
	GameState.reset_progress()
	get_tree().change_scene_to_file(TITOLO)
	for i in 60:
		await get_tree().process_frame
	var t := get_tree().current_scene
	var voci: Array = t.call(&"voci") if t and t.has_method(&"voci") else []
	check(not voci.is_empty() and (voci[0] as Button).text.length() > 0, "nel titolo c'è Continua")
	if voci.is_empty():
		return
	(voci[0] as Button).pressed.emit()
	await _aspetta_ripresa()
	_prendi_nodi()
	await _frames(30)


func _aspetta_ripresa() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and s.scene_file_path != TITOLO \
				and GameState.player and is_instance_valid(GameState.player) and not GameState.is_restoring():
			break
	for i in 30:
		await get_tree().process_frame
	# le stanze della Risalita si caricano nel thread: si aspetta che ci siano
	_prendi_nodi()
	if ris and ris.get(&"fiume") == null and ris.has_method(&"carica_subito"):
		ris.call(&"carica_subito")
		for i in 30:
			await get_tree().process_frame
	_prendi_nodi()


func _cancella_salvataggio() -> void:
	for f in [GameState.SAVE_PATH, GameState.SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


# --- Movimento ------------------------------------------------------------------------------

func _vai(nome: String, punti: Array, per_punto := 900) -> bool:
	for k in punti.size():
		var t: Vector3 = punti[k]
		if not await _cammina_verso(t, per_punto):
			check(false, "%s: fermo in %s andando verso il punto %d %s" % [nome, p.global_position.snapped(Vector3.ONE * 0.01), k, t.snapped(Vector3.ONE * 0.01)])
			var fine: Vector3 = punti[punti.size() - 1]
			p.teleport(fine + Vector3(0, 0.05, 0), p.yaw, 0.0)
			await _frames(10)
			return false
	return true


func _cammina_verso(t: Vector3, max_frames: int) -> bool:
	for i in max_frames:
		var d := Vector2(t.x - p.global_position.x, t.z - p.global_position.z)
		if d.length() < 0.35:
			Input.action_release(&"move_forward")
			return true
		p.yaw = atan2(-d.x, -d.y)
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	return false


# --- Controlli ------------------------------------------------------------------------------

func _porta_aperta() -> bool:
	var porta := e.porta if e else null
	if porta == null:
		return false
	for k in [&"e_aperta", &"aperta"]:
		if k in porta:
			return bool(porta.get(k))
	return porta.has_method(&"is_aperta") and bool(porta.call(&"is_aperta"))


func _piene(c: String) -> bool:
	for t: WaterTank in e.pozze_del_colore(c):
		if t.fill < e.pieno - 0.003 or WaterMix.frazione(t.mix, c) < 0.99:
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


func _fine() -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"suck")
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
