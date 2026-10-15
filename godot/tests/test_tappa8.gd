extends Node
## Test automatico della tappa 8 (docs/livello/capitolo1.md), "lei sbuca dal bordo" nell'area bimbi,
## simulando gli input. Al buio (dopo il risveglio) si segue la scia lungo il muro ovest: il
## checkpoint prima della scena, le vasche basse che si riempiono dalla fossa, lei che sbuca dal
## bordo quando ti avvicini.
## 1. Se le vai incontro ti prende: fauce aperta, vene nell'occhio, sequenza di morte (saltata) e
##    si riparte dal checkpoint con la scena di nuovo in attesa.
## 2. Se non la guardi resta affacciata, anche oltre l'attesa e anche se ti allontani.
## 3. Quando l'hai vista bene (nell'inquadratura, vicino al centro, senza niente in mezzo, per due
##    secondi di fila) ti fissa ancora un po', poi scivola sotto e la sua luce si allontana lungo il
##    condotto.
## 4. Poi la strada verso la torre: lungo il muro nord, dal cancello del recinto (aperto nella
##    tappa 4) giù nella spiaggia della piscina vuota, lungo la spiaggia e fuori dal lato est, ai
##    piedi della torre, con i checkpoint.
## Finché l'ambiente non ha fatto la fossa (marker medusa_sbuca e medusa_fuga) la scena nel livello
## è spenta: il test la accende sulla fossa provvisoria e spegne la fine della demo sulla scia.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_tappa8.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const PIEDE_TORRE := Vector3(10.6, 0.0, -14.3)

var level: Node
var p: Player
var lei: LeiSbuca
var fossa_vera := false
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	await _aspetta_livello()
	check(lei != null, "c'è la tappa 8 (LeiSbuca) con la medusa della fossa")
	if lei == null:
		_fine()
		return
	fossa_vera = lei.abilitata
	print("  (fossa dell'ambiente: %s)" % ("sì" if fossa_vera else "non ancora, uso quella provvisoria"))
	check(not lei.medusa.visible, "prima non si vede")

	print("Un salvataggio di prima, senza lo stato del cancello, oltre il fondo della piscina")
	var giochi := level.get_node("RuotaESecchio")
	check(not bool(giochi.get(&"gate_open")), "in una partita nuova il cancello della piscina è chiuso")
	GameState.capture_snapshot("Gioco/CheckpointFondo", 3, Transform3D(Basis(), Vector3(0.0, -0.6, -1.0)))
	(GameState.snapshot["objects"] as Dictionary).erase(GameState.persist_key(giochi))
	GameState._restore_pending = true
	GameState._on_level_ready()
	await _frames(2)
	check(bool(giochi.get(&"gate_open")), "ripartendo da lì il cancello è aperto")

	print("Prima del risveglio non succede niente")
	_prepara()
	p.teleport(Vector3(-18.3, 0.0, -3.0), 0.0, 0.0)
	await _frames(60)
	check(lei.fase == LeiSbuca.Fase.ATTESA and not lei.medusa.visible, "con le luci di prima lei non sbuca")

	print("Al buio, sulla scia")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	# Dal risveglio a qui passano minuti: l'acqua è già salita un po' (piano, dalla fossa).
	for v in lei.vasche:
		var t := v as WaterTank
		t.fill = minf(t.fill + 0.08 / t.inner_size.y, t.max_fill)
	p.teleport(Vector3(-18.3, 0.0, 2.6), 0.0, 0.0)
	await _frames(5)
	var vasca: WaterTank = level.get_node("Vasche/VascaBimbi1")
	var prima := vasca.get_surface_global_y()
	check(await _cammina_verso(Vector3(-18.3, 0.0, -0.4), 600), "lungo il muro ovest fino al checkpoint")
	await _frames(5)
	check(_checkpoint().ends_with("CheckpointAreaBimbi"), "checkpoint: prima della scena (%s)" % _checkpoint())
	check(lei.fase == LeiSbuca.Fase.ATTESA, "al checkpoint lei non è ancora sbucata")
	await _frames(120)
	check(vasca.get_surface_global_y() > prima + 0.005, "le vasche basse si riempiono dalla fossa (pelo da %.3f a %.3f)" % [prima, vasca.get_surface_global_y()])

	print("1. Le vai incontro seguendo la scia: ti prende")
	var ritorno := level.get(&"ritorno") as RitornoAlBuio
	var scia := ritorno.scia
	var sbucata := false
	Input.action_press(&"move_forward")
	for k in range(scia.size() - 6, scia.size()):
		for i in 400:
			var d := scia[k] - p.global_position
			if Vector2(d.x, d.z).length() < 0.35 or GameState.is_dying:
				break
			p.set_look(atan2(-d.x, -d.z), 0.0)
			await get_tree().physics_frame
			sbucata = sbucata or lei.fase == LeiSbuca.Fase.SBUCA or lei.fase == LeiSbuca.Fase.GUARDA
		if GameState.is_dying:
			break
	Input.action_release(&"move_forward")
	check(sbucata, "avvicinandosi, lei sbuca dal bordo")
	check(GameState.is_dying and lei.fase == LeiSbuca.Fase.PRESA, "troppo vicino: ti prende")
	var seq := GameState.get_children().filter(func(n): return n is DeathSequence)
	check(seq.size() == 1 and (seq[0] as DeathSequence).cause == &"medusa", "parte la sequenza di morte di lei")
	await _frames(45)
	var strappo := lei.medusa.find_child("Medusa_Strappo", true, false) as Node3D
	check(strappo != null and strappo.visible, "la fauce si apre (pelle strappata, gola e denti)")
	var occhio := lei.medusa.find_child("Medusa_Occhio", true, false) as MeshInstance3D
	var m := occhio.get_active_material(0) as ShaderMaterial if occhio else null
	check(m != null and float(m.get_shader_parameter(&"venatura")) > 0.5, "e l'occhio si riempie di vene")
	if seq.size() == 1:
		(seq[0] as DeathSequence).skip()
	await _aspetta_livello()
	_prepara()
	await _frames(10)
	check(GameState.luci == GameState.Luci.BLACKOUT and _checkpoint().ends_with("CheckpointAreaBimbi"), "si riparte dal checkpoint, al buio")
	check(lei.fase == LeiSbuca.Fase.ATTESA and not lei.medusa.visible, "e la scena è di nuovo in attesa")
	check(p.global_position.distance_to(Vector3(-18.3, 0.0, -0.5)) < 1.0, "il giocatore è sulla scia (%s)" % str(p.global_position))
	# Ricaricando il livello al buio, la sala del ritorno (tappa 7) è com'era.
	ritorno = level.get(&"ritorno") as RitornoAlBuio
	var lampione := level.get_node(^"Vasca/Sfarfallio") as FlickerLight
	check(ritorno.attivo and not ritorno.medusa.visible and ritorno.macchie_scia() >= 15 and not lampione.is_on,
			"e la sala è ancora al buio: vasca vuota, scia di gocce, lampione spento")

	print("2. Non la guardi: lei resta affacciata")
	check(await _cammina_verso(Vector3(-18.3, 0.0, -1.9), 300), "qualche passo avanti")
	await _frames(10)
	check(lei.fase == LeiSbuca.Fase.SBUCA or lei.fase == LeiSbuca.Fase.GUARDA, "lei sbuca a pochi metri (fase %d)" % lei.fase)
	# Ti giri dall'altra parte (a sud, da dove sei venuto) e ti allontani di qualche passo, senza
	# guardarla: lei resta lì ben oltre l'attesa.
	p.set_look(PI, 0.0)
	await _frames(30)
	check(await _cammina_verso(Vector3(-18.3, 0.0, 1.6), 300), "ti allontani senza guardarla")
	p.set_look(PI, 0.0)
	await _frames(int((lei.attesa + lei.tempo_vista + 2.0) * 60.0))
	check(lei.fase == LeiSbuca.Fase.GUARDA and lei.medusa.visible and not lei.vista_bene,
			"dopo %.0f s è ancora affacciata: non l'hai vista (fase %d)" % [lei.attesa + lei.tempo_vista + 2.0, lei.fase])
	var occhio_lei: Vector3 = lei.medusa.call(&"get_eye_position")
	# Oltre la distanza massima non conta, anche guardandola dritta.
	p.look_at_point(occhio_lei)
	await _frames(2)
	var dv := lei.distanza_vista
	lei.distanza_vista = p.camera.global_position.distance_to(occhio_lei) - 0.5
	check(not lei.la_stai_guardando(p), "più lontano della distanza massima non conta come vista")
	lei.distanza_vista = dv
	p.set_look(PI, 0.0)
	await _frames(30)

	# Da qui lo scivolo grande è in mezzo: anche guardando verso di lei non la vedi.
	p.look_at_point(occhio_lei)
	await _frames(3)
	check(not lei.la_stai_guardando(p), "con lo scivolo in mezzo non conta come vista")
	p.set_look(PI, 0.0)
	await _frames(30)

	print("3. La guardi bene: ti fissa, poi scivola sotto e se ne va")
	# Torni sulla scia, un po' più avanti, dove né lo scivolo né le colonne la coprono, e la guardi.
	check(await _cammina_verso(Vector3(-18.3, 0.0, -3.0), 400), "torni sulla scia, dove si vede bene")
	check(not lei.vista_bene and lei.fase == LeiSbuca.Fase.GUARDA, "camminando senza guardarla non conta")
	p.look_at_point(occhio_lei)
	await _frames(3)
	check(lei.la_stai_guardando(p), "lei è nell'inquadratura, vicino al centro, senza niente in mezzo")
	await _frames(int(lei.tempo_vista * 60.0 * 0.5))
	check(not lei.vista_bene and lei.fase == LeiSbuca.Fase.GUARDA, "dopo un secondo non basta ancora (%.1f s)" % lei.vista_t)
	await _frames(int(lei.tempo_vista * 60.0 * 0.5) + 10)
	check(lei.vista_bene, "dopo %.0f secondi di fila l'hai vista bene" % lei.tempo_vista)
	occhio_lei = lei.medusa.call(&"get_eye_position")
	var sguardo: Vector3 = lei.medusa.call(&"get_eye_direction")
	var verso_te := (p.get_eye_position() - occhio_lei).normalized()
	check(lei.fase == LeiSbuca.Fase.GUARDA and sguardo.dot(verso_te) > 0.85,
			"le mani sul bordo, l'occhio fisso su di te (%.2f)" % sguardo.dot(verso_te))
	check(LeiSbuca._in_pianta(p.global_position, occhio_lei) > lei.distanza_presa + 1.0, "e tu sei lontano (%.1f m)" % LeiSbuca._in_pianta(p.global_position, occhio_lei))
	await _frames(int(lei.attesa * 60.0 * 0.5))
	check(lei.fase == LeiSbuca.Fase.GUARDA, "ti fissa ancora per un po'")
	var fuga_vista := false
	var luce_lontana := 0.0
	for i in 900:
		await get_tree().physics_frame
		var luce := lei.get_node_or_null(^"LuceSottacqua") as OmniLight3D
		if luce:
			fuga_vista = true
			luce_lontana = maxf(luce_lontana, luce.global_position.distance_to(lei.punto_sbuca.global_position))
		if lei.fase == LeiSbuca.Fase.FINITA:
			break
	check(fuga_vista and luce_lontana > 1.5, "scivola sotto e la sua luce si allontana sott'acqua (%.1f m)" % luce_lontana)
	check(lei.fase == LeiSbuca.Fase.FINITA and not lei.medusa.visible and not GameState.is_dying, "poi non c'è più, e tu sei vivo")

	print("4. Verso la torre, dalla spiaggia della piscina vuota")
	var ok := true
	for t in [Vector3(-18.3, 0, -9.7), Vector3(-18.3, 0, -15.1), Vector3(-17.5, 0, -16.5), Vector3(-15.9, 0, -16.9),
			Vector3(-10.5, 0, -16.9), Vector3(-5.5, 0, -17.1), Vector3(-0.7, 0, -16.3), Vector3(0.0, 0, -15.0)]:
		ok = ok and await _cammina_verso(t, 900)
	check(ok, "lungo il muro nord, lontano dalle vasche")
	ok = true
	for t in [Vector3(0.0, 0, -13.0), Vector3(0.6, 0, -12.2), Vector3(3.5, 0, -11.8)]:
		ok = ok and await _cammina_verso(t, 600)
	await _frames(5)
	check(ok and p.global_position.y < -0.1, "dal cancello giù nella spiaggia della piscina vuota (y %.2f)" % p.global_position.y)
	check(_checkpoint().ends_with("CheckpointSpiaggiaBuio"), "checkpoint: la spiaggia (%s)" % _checkpoint())
	ok = true
	for t in [Vector3(6.1, 0, -12.2)]:
		ok = ok and await _cammina_verso(t, 600)
	ok = true
	for t in [Vector3(8.1, 0, -12.5), Vector3(9.5, 0, -13.3), PIEDE_TORRE + Vector3(-0.3, 0, 0)]:
		ok = ok and await _cammina_verso(t, 600)
	await _frames(10)
	check(ok and _checkpoint().ends_with("CheckpointTorre"), "fino ai piedi della torre: checkpoint (%s)" % _checkpoint())
	if fossa_vera:
		check(bool(level.get(&"demo_finished")), "ai piedi della torre finisce la demo")
	else:
		print("  (la fine della demo passa ai piedi della torre quando c'è la fossa)")
	_fine()


## Dopo un caricamento (o una ripartenza): i riferimenti nuovi. Senza la fossa dell'ambiente la
## scena si accende sulla fossa provvisoria.
func _aspetta_livello() -> void:
	for i in 400:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _frames(5)
	level = get_tree().current_scene
	p = GameState.player
	lei = level.get(&"lei_sbuca") as LeiSbuca
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame


func _prepara() -> void:
	# La tappa 4 è già fatta: il cancello del recinto della piscina è aperto.
	var giochi := level.get_node_or_null(^"RuotaESecchio")
	if giochi:
		giochi.call(&"load_state", {"gate_open": true})
	if lei and not lei.abilitata:
		lei.abilitata = true
		var fine := level.get(&"fine_demo_trigger") as Area3D
		if fine:
			fine.monitoring = false


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _checkpoint() -> String:
	return String(GameState.snapshot.get("checkpoint", ""))


## Cammina in avanti verso t finché non ci arriva (in pianta). Falso se si blocca.
func _cammina_verso(t: Vector3, max_frames: int) -> bool:
	Input.action_press(&"move_forward")
	var arrivato := false
	for i in max_frames:
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			arrivato = true
			break
		p.set_look(atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	if not arrivato:
		printerr("  bloccato in ", p.global_position, " andando verso ", t)
	return arrivato


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
