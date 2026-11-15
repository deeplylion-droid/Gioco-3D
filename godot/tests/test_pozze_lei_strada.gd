extends Node
## Lei sotto le pozze nel gioco vero (LeiPozze, 0.4.0), sulla strada della Risalita, col giocatore vero e il motore vero
## di lei (AcquaDiLei di mascotte):
## 1. dalla partenza F9 "Fiume lento" fino alla stanza delle pozze, come test_pozze_strada; il checkpoint d'ingresso (14)
##    si scrive su disco; lei dorme;
## 2. tolto un colore lei si sveglia, fa l'uscita dimostrativa e poi, col giocatore fermo sulla passerella, lo prende
##    (medusa): la scena della morte vera, poi la ripartenza;
## 3. si riparte dal checkpoint d'ingresso con le pozze tutte piene, la porta chiusa e lei che dorme di nuovo finché non
##    si toglie un colore (la prima volta dimostrativa non torna: una volta per partita);
## 4. partita nuova nello stesso avvio (GameState.reset_progress, come il menu): di nuovo fino alle pozze, e la prima
##    uscita è di nuovo quella dimostrativa (lontana, non prende).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_pozze_lei_strada.gd

var p: Player
var level: Node
var ris: Node
var e: EnigmaPozze
## Le fasi del motore: [fase, fotogramma di fisica].
var fasi: Array = []
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


## Il riscaldamento della stanza delle pozze ripartendo vicino (RisalitaGioco.riscaldo_pozze): in quanti fotogrammi
## c'è stato, e in quanti la camera del gioco avrebbe visto qualcosa di diverso (un pezzo della stanza tolto dalla
## vista, o lei e la sua luce in posa visibili).
var riscaldo_visti := 0
var riscaldo_scoperti := 0


func _process(_d: float) -> void:
	var s := get_tree().current_scene
	var r := s.get_node_or_null(^"Risalita") if s else null
	if r and r.get(&"riscaldo_pozze") == true:
		riscaldo_visti += 1
		if not _vista_com_era(r.get(&"pozze") as Node3D):
			riscaldo_scoperti += 1


## Vero se nella stanza delle pozze [param poz] nessuna mesh o luce è solo sullo strato fuori vista, tranne quelle di
## lei (il suo motore), che lì devono stare tutte (la camera del gioco non le vede).
func _vista_com_era(poz: Node3D) -> bool:
	if poz == null or not is_instance_valid(poz):
		return true
	var en := poz.find_child("EnigmaPozze", true, false) as EnigmaPozze
	var aq: Node = en.lei.acqua if en and en.lei else null
	for v in poz.find_children("*", "VisualInstance3D", true, false):
		var vi := v as VisualInstance3D
		if not vi.is_visible_in_tree():
			continue
		var di_lei := aq != null and aq.is_ancestor_of(vi)
		if di_lei and vi.layers != SalaTorre.STRATO_PREPARA:
			return false
		if not di_lei and vi.layers == SalaTorre.STRATO_PREPARA:
			return false
	return true


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
	MenuProva.parti(get_tree(), "fiume")
	await _aspetta_ripresa()
	if e == null:
		check(false, "nella Risalita c'è la stanza delle pozze")
		return _fine()
	await _fino_alle_pozze()
	var ingresso := String(GameState.salvataggio().get("checkpoint", ""))
	check(ingresso.ends_with("CheckpointIngresso") and int(GameState.salvataggio().get("order", 0)) == 14,
		"entrando si scrive il checkpoint d'ingresso, il 14 (%s)" % ingresso)
	check(e.lei != null and e.lei.fase == LeiPozze.Fase.DORME, "nella stanza vera c'è lei, che dorme")
	check(e.lei.letale and e.lei.acqua and e.lei.acqua.letale, "letale acceso")
	check(GameState.luci == GameState.Luci.BLACKOUT and e.lei.acqua.puo_venire(), "le pompe sono riaccese: qui lei può venire (%s)" % _perche_no())
	_registra()
	e.lei.prima_attesa = 2.0

	print("2. Tolto un colore lei si sveglia e, col giocatore fermo, lo prende")
	await _togli(WaterMix.TURCHESE)
	await _frames(2)
	check(e.lei.fase != LeiPozze.Fase.DORME, "tolto il turchese si sveglia (%s)" % e.lei.nome_fase())
	check(e.lei.prossima_dimostrativa(), "la prossima uscita è quella dimostrativa")
	var es := await _aspetta(AcquaDiLei.Fase.ESCE, 12.0)
	check(not es.is_empty() and e.lei.uscite == 1, "esce la prima volta")
	await _aspetta(AcquaDiLei.Fase.CALMA, 8.0)
	check(e.lei.prese == 0 and not GameState.is_dying and not e.lei.prossima_dimostrativa(), "dimostrativa: non prende")
	# (fermo sulla passerella, davanti alle pozze)
	await _vai("sulla passerella sud", [_davanti_alle_pozze(0.0)])
	var morto := false
	for i in 60 * 30:
		await get_tree().physics_frame
		if GameState.is_dying:
			morto = true
			break
	check(morto and GameState.last_death_cause == &"medusa" and e.lei.prese == 1, "dopo la pausa esce vicino a lui e lo prende: si muore (%s)" % GameState.last_death_cause)
	if not morto:
		return _fine()
	# la scena della morte vera, poi la ripartenza (se non finisce da sola in 12 s, la si salta come col tasto)
	var seq: Node = GameState.get(&"_death_sequence")
	for i in 60 * 12:
		await get_tree().process_frame
		if not is_instance_valid(seq) or not GameState.is_dying:
			break
	riscaldo_visti = 0
	riscaldo_scoperti = 0
	if is_instance_valid(seq) and GameState.is_dying:
		seq.emit_signal(&"finished", true)
	await _aspetta_ripresa()

	print("3. Si riparte dall'ingresso con le pozze piene e lei che dorme")
	check(riscaldo_visti > 0 and riscaldo_scoperti == 0,
		"ripartendo lei in posa si disegna fuori vista con la stanza, e la camera del gioco non vede niente di diverso (%d fotogrammi, %d diversi)" % [riscaldo_visti, riscaldo_scoperti])
	check(String(GameState.snapshot.get("checkpoint", "")) == ingresso, "si riparte dal checkpoint d'ingresso (%s)" % GameState.snapshot.get("checkpoint", ""))
	check(e != null and _tutte_piene() and e.tolti.is_empty() and e.stato == EnigmaPozze.Stato.APERTO and not _porta_aperta(),
		"con le pozze tutte piene e la porta chiusa")
	check(e != null and e.lei != null and e.lei.fase == LeiPozze.Fase.DORME and e.lei.acqua.fase == AcquaDiLei.Fase.LONTANA,
		"lei dorme di nuovo")
	if e == null:
		return _fine()
	_registra()
	await _frames(60 * 5)
	check(fasi.is_empty(), "e finché non si toglie un colore non succede niente")
	await _togli(WaterMix.VIOLA)
	await _frames(2)
	check(e.lei.fase == LeiPozze.Fase.GIRA, "tolto il viola si sveglia di nuovo")
	check(not e.lei.prossima_dimostrativa(), "(e la prima volta dimostrativa non torna: una volta per partita)")
	e.lei.prima_attesa = 0.0
	e.lei._t = 0.0
	var ar := await _aspetta(AcquaDiLei.Fase.ARRIVA, 6.0)
	check(not ar.is_empty(), "e torna a venire")
	if GameState.is_dying:
		# (se l'ha preso: la scena della morte si salta, la partita nuova riparte comunque dal menu)
		var seq2: Node = GameState.get(&"_death_sequence")
		if is_instance_valid(seq2):
			seq2.free()
		GameState.is_dying = false

	print("4. Partita nuova nello stesso avvio: la prima uscita è di nuovo dimostrativa")
	GameState.reset_progress()
	_cancella_salvataggio()
	MenuProva.parti(get_tree(), "fiume")
	await _aspetta_ripresa()
	if e == null:
		check(false, "nella Risalita c'è la stanza delle pozze")
		return _fine()
	await _fino_alle_pozze()
	_registra()
	check(e.lei.fase == LeiPozze.Fase.DORME and e.lei.prossima_dimostrativa(), "lei dorme, e la prossima uscita è di nuovo quella dimostrativa")
	e.lei.prima_attesa = 2.0
	await _togli(WaterMix.TURCHESE)
	var es2 := await _aspetta(AcquaDiLei.Fase.ESCE, 12.0)
	check(not es2.is_empty() and e.lei.uscite == 1, "esce la prima volta della partita nuova")
	await _aspetta(AcquaDiLei.Fase.CALMA, 10.0)
	check(e.lei.prese == 0 and not GameState.is_dying and not e.lei.prossima_dimostrativa(), "dimostrativa: lontana, non prende")
	_fine()


# --- La strada fino alle pozze (come test_pozze_strada) ------------------------------------

func _prendi_nodi() -> void:
	level = get_tree().current_scene
	p = GameState.player
	ris = level.get_node_or_null(^"Risalita") if level else null
	e = level.find_child("EnigmaPozze", true, false) as EnigmaPozze if level else null


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
	inf.get_node(^"Interruttore").set(&"powered", true)
	p.add_item(&"keycard", 1, "Keycard")
	await _frames(60 * 3)
	_prendi_nodi()
	await _vai("dall'approdo nell'infermeria e dalla porta nord nella stanza delle pozze", [
		porta_personale.global_position - porta_personale.global_basis.z * 1.5,
		inf.to_global(Vector3(1.6, 0, 3.6)), inf.to_global(Vector3(1.8, 0, 1.6)), inf.to_global(Vector3(0.0, 0, 0.0)),
		inf.to_global(Vector3(-2.2, 0, -2.4)), inf.to_global(Vector3(-2.2, 0, -3.8)), _davanti_alle_pozze(0.0)])
	await _frames(20)


func _davanti_alle_pozze(x: float) -> Vector3:
	return e.to_global(Vector3(x, 0.0, e.passo * 2.5 + 0.6))


func _pozza_sul_bordo(c: String) -> WaterTank:
	var migliore: WaterTank = null
	for t: WaterTank in e.pozze_del_colore(c):
		if migliore == null or t.position.z > migliore.position.z:
			migliore = t
	return migliore


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
	check(c in e.tolti, "aspirando dalla pozza %s le pozze %s si svuotano" % [c, c])


func _zaino() -> void:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)


func _aspetta_ripresa() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and s.scene_file_path != "res://scenes/ui/menu_principale.tscn" \
				and GameState.player and is_instance_valid(GameState.player) and not GameState.is_restoring() and not GameState.is_dying:
			break
	for i in 30:
		await get_tree().process_frame
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


## Perché il motore adesso non può far venire lei (per i messaggi dei controlli).
func _perche_no() -> String:
	var a := e.lei.acqua
	var altre: Array = []
	for n in get_tree().current_scene.find_children("*", "MedusaAffacciata", true, false):
		if n != AcquaDiLei._lei and (n as Node3D).is_visible_in_tree():
			altre.append(str(get_tree().current_scene.get_path_to(n)))
	return "luci %d, abilitata %s, punti %d, sta morendo %s, la usa %s, altre lei in vista %s, bambino in vista %s" % [
		GameState.luci, a.abilitata, a.punti_uscita.size(), GameState.is_dying, AcquaDiLei.chi_la_usa(), altre,
		a.bambino_in_vista()]


func _registra() -> void:
	fasi = []
	e.lei.acqua.fase_cambiata.connect(func(f): fasi.append([f, Engine.get_physics_frames()]))


## Aspetta la prossima fase [param f] del motore (al più [param secondi]); ritorna [fase, fotogramma], o [] se non arriva.
func _aspetta(f: AcquaDiLei.Fase, secondi: float) -> Array:
	var da := fasi.size()
	for i in int(secondi * 60.0) + 1:
		for k in range(da, fasi.size()):
			if fasi[k][0] == f:
				return fasi[k]
		await get_tree().physics_frame
	return []


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
