extends Node
## Test automatico della tappa 8 (docs/livello/capitolo1.md), "lei sbuca dal bordo" nell'area bimbi,
## simulando gli input. Al buio (dopo il risveglio) lei è già affacciata alla fossa prima che tu
## arrivi, anche con l'acqua delle vasche basse ancora bassa (riscontro sulla v0.3.1); si segue la
## scia lungo il muro ovest: il checkpoint prima della scena, le vasche basse che si riempiono.
## 1. Se le vai incontro ti prende: si gira verso di te, fauce aperta, vene nell'occhio, sequenza di
##    morte (saltata) e si riparte dal checkpoint con lei di nuovo affacciata.
## 2. Se non la spruzzi resta affacciata a lungo: anche se ti allontani e anche dopo che l'hai vista
##    bene (riscontro sulla v0.3.4: va via solo se la spruzzi).
## 3. La spruzzi col getto dello zaino: parte subito il geyser, lei sparisce lì dentro solo quando è
##    coperta (finché si vede, mani e tentacoli non entrano nel bordo né nel pavimento) e la sua luce
##    si allontana lungo il condotto.
## 4. La spruzzi da altre distanze e da altri lati, sulla testa, su una mano, su un tentacolo: se ne
##    va subito ogni volta.
## 5. Quando lei se ne va il portone della sala della torre sulla parete est NON si apre da solo: lo
##    apre l'enigma degli acquari (GDD, 18 ottobre; lo prova test_acquari.gd, qui si apre come farebbe
##    l'enigma). La strada tra l'area bimbi e la piscina, poi lungo il lato nord della spiaggia fino al
##    portone, con i checkpoint; il portone che si apre fa caricare la sala della torre.
## 6. Se le arrivi di lato ti prende girandosi verso di te: la camera della morte la trova di fronte.
## Finché l'ambiente non ha fatto la fossa (marker medusa_sbuca e medusa_fuga) la scena nel livello
## è spenta: il test la accende sulla fossa provvisoria e spegne la fine della demo sulla scia.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_tappa8.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const PORTONE := Vector3(19.84, 0.0, -15.0)

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

	print("Niente recinto sulla spiaggia (tappa 5 rifatta, niente ruota né secchio)")
	check(level.get_node_or_null("RuotaESecchio") == null, "niente più ruota a pale e secchio da riempire")
	check(level.get_node_or_null(^"Sala/Interattivi/sala_cancello_spiaggia") == null, "niente recinto né cancello")
	var portone := level.get(&"portone") as PortoneTorre
	check(portone != null and portone.anta != null and portone.apertura == PortoneTorre.Apertura.SOLO_ENIGMA and not portone.is_aperto(),
		"il portone della sala della torre è chiuso e lo aprirà l'enigma degli acquari")

	print("Lo scivolo giallo e i tetti della struttura di gioco sono solidi (prova della v0.3.2, punto 10)")
	var spazio := p.get_world_3d().direct_space_state
	var su_scivolo := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-11.5, 4.0, -17.8), Vector3(-11.5, 0.5, -17.8), Layers.WORLD))
	check(not su_scivolo.is_empty() and float(su_scivolo.position.y) > 0.6,
		"lo scivolo ha la sua collisione (a metà, alto %.2f m)" % (float(su_scivolo.position.y) if not su_scivolo.is_empty() else 0.0))
	# Ci vai contro di lato: ti ferma.
	p.teleport(Vector3(-11.5, 0.0, -16.2), 0.0, 0.0)
	await _frames(5)
	await _cammina_verso(Vector3(-11.5, 0.0, -19.6), 150)
	check(p.global_position.z > -17.5, "camminandoci contro di lato non lo attraversi (z %.2f)" % p.global_position.z)
	# Ci sali sopra: ci stai e scivoli giù lungo il canale, senza cadere attraverso.
	p.teleport(Vector3(-11.5, 1.7, -17.8), 0.0, 0.0)
	var min_y := 9.0
	for i in 20:
		await get_tree().physics_frame
		min_y = minf(min_y, p.global_position.y)
	check(min_y > 0.6, "salito sopra lo scivolo ci resti sopra (y minima %.2f)" % min_y)
	# Area bimbi HD, la variante (17 ottobre): tre torri col tetto a piramide. Sopra il centro di ogni
	# torre un raggio dall'alto trova il tetto (ben sopra la pedana); lasciato lì sopra, ci resti.
	var tetti_ok := true
	for torre in [[Vector3(-17.2, 0.0, -15.6), 1.24], [Vector3(-17.225, 0.0, -18.375), 2.72], [Vector3(-14.15, 0.0, -18.375), 1.71]]:
		var c: Vector3 = torre[0]
		var pedana: float = torre[1]
		var tetto := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0.0, 12.0, 0.0), c, Layers.WORLD))
		if tetto.is_empty() or float(tetto.position.y) < pedana + 1.5:
			tetti_ok = false
			print("  (niente tetto sopra la torre in %s)" % str(c))
			continue
		var sopra := Vector3(c.x, float(tetto.position.y) + 0.4, c.z)
		p.teleport(sopra, 0.0, 0.0)
		await _frames(20)
		if p.global_position.y < pedana + 1.0 and absf(p.global_position.x - c.x) < 0.9 and absf(p.global_position.z - c.z) < 0.9:
			tetti_ok = false
			print("  (caduto attraverso il tetto sopra %s: y %.2f)" % [str(c), p.global_position.y])
	check(tetti_ok, "e sui tre tetti a piramide si sta sopra")

	print("Prima del risveglio non succede niente")
	_prepara()
	p.teleport(Vector3(18.5, 0.0, -15.0), -PI * 0.5, 0.0)
	await _frames(10)
	check(not bool(level.get(&"demo_finished")) and not portone.is_aperto() and not portone.in_movimento,
		"davanti al portone prima della tappa 8: resta chiuso e la demo non finisce")
	p.teleport(Vector3(16.5, 0.0, -15.0), -PI * 0.5, 0.0)
	await _frames(10)
	check(not _checkpoint().ends_with("CheckpointTorre"), "e il checkpoint del portone vale solo al buio (%s)" % _checkpoint())
	p.teleport(Vector3(-18.3, 0.0, -3.0), 0.0, 0.0)
	await _frames(60)
	check(lei.fase == LeiSbuca.Fase.ATTESA and not lei.medusa.visible, "con le luci di prima lei non sbuca")

	print("Al buio: lei è già affacciata alla fossa (riscontro sulla v0.3.1)")
	# Come nel gioco: dal risveglio si arriva in fretta, l'acqua delle vasche basse è ancora quella di
	# prima (nella v0.3.1 lei restava sotto finché non le eri addosso).
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	await _frames(5)
	check(lei.fase == LeiSbuca.Fase.GUARDA and lei.medusa.visible, "appena c'è il blackout è già sul bordo, prima che tu arrivi (fase %d)" % lei.fase)
	var vasca: WaterTank = level.get_node("Vasche/VascaBimbi1")
	check(vasca.get_surface_global_y() >= minf(lei.pelo_minimo, lei.livello_pieno) - 0.002,
		"e l'acqua della fossa le copre il seno (pelo %.3f)" % vasca.get_surface_global_y())
	p.teleport(Vector3(-18.3, 0.0, 2.6), 0.0, 0.0)
	await _frames(5)
	var prima := vasca.get_surface_global_y()
	var sempre := true
	Input.action_press(&"move_forward")
	for i in 600:
		var d := Vector3(-18.3, 0.0, -0.4) - p.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			break
		p.set_look(atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
		sempre = sempre and lei.fase == LeiSbuca.Fase.GUARDA and lei.medusa.visible
	Input.action_release(&"move_forward")
	await _frames(5)
	check(sempre, "mentre arrivi lungo la scia lei è lì, affacciata")
	check(_checkpoint().ends_with("CheckpointAreaBimbi"), "checkpoint: prima della scena (%s)" % _checkpoint())
	await _frames(120)
	check(vasca.get_surface_global_y() > prima + 0.005, "le vasche basse si riempiono dalla fossa (pelo da %.3f a %.3f)" % [prima, vasca.get_surface_global_y()])

	print("1. Le vai incontro seguendo la scia: ti prende")
	var ritorno := level.get(&"ritorno") as RitornoAlBuio
	var scia := ritorno.scia
	var affacciata := true
	Input.action_press(&"move_forward")
	for k in range(scia.size() - 6, scia.size()):
		for i in 400:
			var d := scia[k] - p.global_position
			if Vector2(d.x, d.z).length() < 0.35 or GameState.is_dying:
				break
			p.set_look(atan2(-d.x, -d.z), 0.0)
			await get_tree().physics_frame
			affacciata = affacciata and (GameState.is_dying or (lei.fase == LeiSbuca.Fase.GUARDA and lei.medusa.visible))
		if GameState.is_dying:
			break
	Input.action_release(&"move_forward")
	check(affacciata, "mentre ti avvicini resta affacciata")
	check(GameState.is_dying and lei.fase == LeiSbuca.Fase.PRESA, "troppo vicino: ti prende")
	await _frames(20)
	check(_angolo_verso(p.global_position) < 12.0, "e si gira verso di te (%.1f gradi)" % _angolo_verso(p.global_position))
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
	check(lei.fase == LeiSbuca.Fase.GUARDA and lei.medusa.visible and not lei.vista_bene, "e lei è di nuovo affacciata alla fossa")
	check(p.global_position.distance_to(Vector3(-18.3, 0.0, -0.5)) < 1.0, "il giocatore è sulla scia (%s)" % str(p.global_position))
	# Ricaricando il livello al buio, la sala del ritorno (tappa 7) è com'era.
	ritorno = level.get(&"ritorno") as RitornoAlBuio
	var lampione := level.get_node(^"Vasca/Sfarfallio") as FlickerLight
	check(ritorno.attivo and not ritorno.medusa.visible and ritorno.metri_scia() >= 8.0 and not lampione.is_on,
			"e la sala è ancora al buio: vasca vuota, scia di bava rosa, lampione spento")

	print("2. Non la spruzzi: lei resta affacciata")
	check(await _cammina_verso(Vector3(-18.3, 0.0, -1.9), 300), "qualche passo avanti")
	await _frames(10)
	check(lei.fase == LeiSbuca.Fase.GUARDA and lei.medusa.visible, "lei è lì, affacciata a pochi metri (fase %d)" % lei.fase)
	# Ti giri dall'altra parte (a sud, da dove sei venuto) e ti allontani di qualche passo, senza
	# guardarla: lei resta lì.
	p.set_look(PI, 0.0)
	await _frames(30)
	check(await _cammina_verso(Vector3(-18.3, 0.0, 1.6), 300), "ti allontani senza guardarla")
	p.set_look(PI, 0.0)
	await _frames(10 * 60)
	check(lei.fase == LeiSbuca.Fase.GUARDA and lei.medusa.visible and not lei.vista_bene,
			"dopo 10 s è ancora affacciata, e non l'hai vista (fase %d)" % lei.fase)
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

	# Con qualcosa in mezzo (un pannello messo qui per il test: lo scivolo grande che la copriva da
	# qui non c'è più dal 16 ottobre) anche guardando verso di lei non la vedi.
	var pannello := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var scatola := BoxShape3D.new()
	scatola.size = Vector3(3.0, 3.0, 0.2)
	forma.shape = scatola
	pannello.add_child(forma)
	level.add_child(pannello)
	var meta := p.camera.global_position.lerp(occhio_lei, 0.5)
	pannello.global_transform = Transform3D(Basis.looking_at(occhio_lei - p.camera.global_position, Vector3.UP), meta)
	p.look_at_point(occhio_lei)
	await _frames(3)
	check(not lei.la_stai_guardando(p), "con qualcosa in mezzo non conta come vista")
	pannello.queue_free()
	p.set_look(PI, 0.0)
	await _frames(30)

	print("3. La guardi bene ma resta lì; la spruzzi e se ne va subito")
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
	# Prima andava via da sola 6 s dopo che l'avevi vista bene: adesso no, resta finché non la spruzzi.
	await _frames(15 * 60)
	check(lei.fase == LeiSbuca.Fase.GUARDA and lei.medusa.visible, "dopo 15 s ti fissa ancora: senza spruzzarla non se ne va")
	var fuga_vista := false
	var luce_lontana := 0.0
	# Mani e tentacoli (i punti delle gocce: dita, punte dei tentacoli sul bordo) mentre scivola sotto:
	# finché si vedono non devono entrare nel bordo né nel pavimento più di quanto già lo toccano.
	var punti: PackedVector3Array = lei.medusa.get(&"punti_gocce")
	var dentro0 := _dentro_pavimento(punti)
	var peggio := 0.0
	var scivolata := false
	var dopo := await _spruzzala(p.global_position, lei.medusa.call(&"get_eye_position"))
	check(dopo >= 0.0 and dopo < 1.2, "la spruzzi in faccia dalla scia: se ne va subito (%.2f s dal primo getto)" % dopo)
	check(lei.get_node_or_null(^"Geyser") != null and (lei.get_node(^"Geyser") as GeyserFossa).in_corso(), "parte il geyser")
	for i in 900:
		await get_tree().physics_frame
		if lei.fase == LeiSbuca.Fase.SCIVOLA and lei.opacita() > 0.25:
			scivolata = true
			var ora := _dentro_pavimento(punti)
			for j in ora.size():
				peggio = maxf(peggio, ora[j] - maxf(dentro0[j], 0.0))
		var luce := lei.get_node_or_null(^"LuceSottacqua") as OmniLight3D
		if luce:
			fuga_vista = true
			luce_lontana = maxf(luce_lontana, luce.global_position.distance_to(lei.punto_sbuca.global_position))
		if lei.fase == LeiSbuca.Fase.FINITA:
			break
	check(scivolata and peggio < 0.05, "scivolando sotto, finché si vedono, mani e tentacoli non entrano nel pavimento (%.2f m)" % peggio)
	check(fuga_vista and luce_lontana > 1.5, "scivola sotto e la sua luce si allontana sott'acqua (%.1f m)" % luce_lontana)
	check(lei.fase == LeiSbuca.Fase.FINITA and not lei.medusa.visible and not GameState.is_dying, "poi non c'è più, e tu sei vivo")

	print("4. La spruzzi da altre distanze e da altri lati: se ne va subito ogni volta")
	var testa5: Vector3 = lei.punto_sbuca.global_transform * Vector3(0.0, 1.63, 1.8)
	var dita: Vector3 = lei.medusa.global_transform * punti[0]
	var tentacolo := dita
	for q in punti:
		var g: Vector3 = lei.medusa.global_transform * q
		if g.y < tentacolo.y:
			tentacolo = g
	for prova in [["davanti a 4 m, sulla testa", _davanti_a(testa5, 0.0, 4.0), testa5],
			["davanti a 9 m, sulla testa", _davanti_a(testa5, 0.0, 9.0), testa5],
			["di traverso a destra, su una mano", _davanti_a(testa5, 25.0, 6.5), dita],
			["di lato a sinistra, su un tentacolo", _davanti_a(testa5, -60.0, 6.5), tentacolo],
			["di lato a sinistra da vicino, sulla testa", _davanti_a(testa5, -60.0, 3.5), testa5]]:
		lei.load_state({"finita": false})
		await _frames(5)
		var piedi5: Vector3 = prova[1]
		piedi5.y = 0.0
		var tempo := await _spruzzala(piedi5, prova[2])
		check(tempo >= 0.0 and tempo < 1.2 and not GameState.is_dying, "%s: se ne va subito (%.2f s)" % [prova[0], tempo])
		for i in 600:
			if lei.fase == LeiSbuca.Fase.FINITA:
				break
			await get_tree().physics_frame

	print("5. Il portone della sala della torre non si apre da solo; la strada fino a lì")
	portone = level.get(&"portone") as PortoneTorre
	await _frames(5)
	check(not portone.in_movimento and not portone.is_aperto(), "quando lei se ne va il portone resta chiuso")
	# Lo apre l'enigma degli acquari (test_acquari.gd).
	portone.apri()
	var ok := true
	for t in [Vector3(-14.0, 0, -4.0), Vector3(-8.3, 0, -4.5), Vector3(-8.3, 0, -8.0), Vector3(-8.3, 0, -12.75),
			Vector3(0.0, 0, -12.75), Vector3(2.0, 0, -12.75)]:
		ok = ok and await _cammina_verso(t, 900)
	await _frames(5)
	check(ok, "tra l'area bimbi e la piscina, poi lungo il lato nord della spiaggia")
	check(_checkpoint().ends_with("CheckpointSpiaggiaBuio"), "checkpoint: la spiaggia (%s)" % _checkpoint())
	check(portone.is_aperto(), "intanto il portone si è aperto")
	var anta := portone.anta.global_position
	check(absf(anta.z - (PORTONE.z + portone.corsa)) < 0.05 and absf(anta.x - PORTONE.x) < 0.05,
		"l'anta è scorsa di %.1f m verso sud (%s)" % [portone.corsa, str(anta)])
	# prova del 19 ottobre: si apre del tutto, e lungo la corsa non attraversa niente
	var forme := portone.anta.find_children("*", "CollisionShape3D", true, false)
	var box := AABB()
	for f in forme:
		var fb := (f as CollisionShape3D).global_transform * (f as CollisionShape3D).shape.get_debug_mesh().get_aabb()
		box = fb if box.size == Vector3.ZERO else box.merge(fb)
	check(not forme.is_empty() and box.position.z > -12.0,
		"aperto lascia libero tutto il varco (l'anta va da z %.2f a %.2f, il varco finisce a -12)" % [box.position.z, box.end.z])
	check(await _corsa_sgombra(portone), "lungo la corsa l'anta non tocca nient'altro")
	# la cornice di lampadine davanti al portone (enigma degli acquari) non è appesa al nulla: i montanti
	# arrivano a terra, la traversa è legata al muro sopra il binario, e l'anta le scorre dietro senza toccarla
	var spente := level.get_node_or_null(^"Gioco/EnigmaAcquari/LampadePortone/Spente")
	if spente == null:
		check(false, "c'è la cornice di lampadine del portone")
	else:
		var anta_vis := AABB()
		for vi in portone.anta.find_children("*", "MeshInstance3D", true, false) + [portone.anta]:
			if vi is MeshInstance3D:
				var mb := (vi as MeshInstance3D).global_transform * (vi as MeshInstance3D).get_aabb()
				anta_vis = mb if anta_vis.size == Vector3.ZERO else anta_vis.merge(mb)
		var montanti_a_terra := true
		var davanti := true
		for nome in ["GuidaSinistra", "GuidaDestra", "GuidaSopra"]:
			var g := spente.get_node(NodePath(nome)) as MeshInstance3D
			var gb := g.global_transform * g.get_aabb()
			if nome != "GuidaSopra":
				montanti_a_terra = montanti_a_terra and gb.position.y < 0.02
			davanti = davanti and gb.end.x < anta_vis.position.x - 0.01
		var staffe := spente.find_children("StaffaMuro*", "MeshInstance3D", false, false)
		var al_muro := staffe.size() >= 3
		for st in staffe:
			var sb := (st as MeshInstance3D).global_transform * (st as MeshInstance3D).get_aabb()
			al_muro = al_muro and sb.end.x > 19.98 and sb.position.y > 5.43
		check(montanti_a_terra and al_muro and davanti,
			"cornice di lampadine: a terra %s, legata al muro sopra il binario %s, davanti all'anta (x %.3f) %s" \
			% [montanti_a_terra, al_muro, anta_vis.position.x, davanti])
	ok = true
	for t in [Vector3(8.0, 0, -12.75), Vector3(15.0, 0, -14.0), Vector3(16.5, 0, -15.0)]:
		ok = ok and await _cammina_verso(t, 900)
	await _frames(10)
	check(ok and _checkpoint().ends_with("CheckpointTorre"), "fino davanti al portone: checkpoint (%s)" % _checkpoint())
	# con la sala della torre la demo non finisce più qui ma in fondo alla discesa (test_torre.gd): il
	# portone che si apre la fa caricare
	var t0 := Time.get_ticks_msec()
	while level.get(&"sala_torre") == null and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
	check(level.get(&"sala_torre") != null and not bool(level.get(&"demo_finished")),
		"davanti al portone aperto c'è la sala della torre (la demo finisce in fondo alla discesa)")

	print("6. Le arrivi di lato: ti prende girandosi verso di te")
	p.water_pack.set_equipped(false, false)
	lei.load_state({"finita": false})
	await _frames(5)
	check(lei.fase == LeiSbuca.Fase.GUARDA and lei.medusa.visible, "(di nuovo affacciata)")
	var testa: Vector3 = lei.punto_sbuca.global_transform * Vector3(0.0, 1.63, 1.8)
	var lato := lei.punto_sbuca.global_basis.x.normalized()
	var piedi := testa + lato * 3.2
	piedi.y = 0.0
	p.teleport(piedi, 0.0, 0.0)
	p.look_at_point(testa)
	await _frames(5)
	check(_angolo_verso(p.global_position) > 70.0, "di lato: lei guarda altrove (%.0f gradi)" % _angolo_verso(p.global_position))
	var preso := await _cammina_verso(testa, 300)
	check(preso or GameState.is_dying, "le vai incontro")
	check(GameState.is_dying and lei.fase == LeiSbuca.Fase.PRESA, "ti prende")
	await _frames(20)
	check(_angolo_verso(p.global_position) < 12.0, "e intanto si gira verso di te: la camera la trova di fronte (%.1f gradi)" % _angolo_verso(p.global_position))
	_fine()


## Di quanti gradi lei è girata rispetto a [param punto] (in pianta, dal suo occhio).
## Un punto sul pavimento a [param metri] dalla sua testa, girato di [param gradi] da dove guarda lei,
## sempre dentro la sala (se in quella direzione c'è un muro ci si ferma prima).
func _davanti_a(testa: Vector3, gradi: float, metri: float) -> Vector3:
	var dir := lei.punto_sbuca.global_basis.z.rotated(Vector3.UP, deg_to_rad(gradi))
	dir.y = 0.0
	dir = dir.normalized()
	var da := Vector3(testa.x, 1.0, testa.z)
	var colpo := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(da, da + dir * metri, Layers.WORLD))
	var dist := metri if colpo.is_empty() else maxf(da.distance_to(colpo.position) - 0.6, 3.0)
	var piedi := testa + dir * dist
	piedi.y = 0.0
	return piedi


## Ti metti in [param piedi], prendi lo zaino pieno, miri a [param bersaglio] (un po' più in alto
## con la distanza: il getto cade) e spari. Ritorna i secondi dal primo getto a quando lei comincia
## ad andarsene (fase SCIVOLA), -1 se non se ne va in 3 s.
func _spruzzala(piedi: Vector3, bersaglio: Vector3) -> float:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(20.0)
	p.teleport(piedi, 0.0, 0.0)
	var d := p.camera.global_position.distance_to(bersaglio)
	var mira := bersaglio + Vector3.UP * 0.0067 * d * d
	p.look_at_point(mira)
	await _frames(5)
	p.look_at_point(mira)
	Input.action_press(&"spray")
	var t := 0.0
	var getto := -1.0
	var risultato := -1.0
	for i in 180:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		p.look_at_point(mira)
		if getto < 0.0 and bool(p.water_pack.get(&"is_spraying")):
			getto = t
		if lei.fase != LeiSbuca.Fase.GUARDA:
			risultato = t - maxf(getto, 0.0)
			break
	Input.action_release(&"spray")
	return risultato


func _angolo_verso(punto: Vector3) -> float:
	var testa: Vector3 = lei.medusa.call(&"get_eye_position")
	var verso := punto - testa
	verso.y = 0.0
	var avanti := lei.medusa.global_basis.z
	avanti.y = 0.0
	if verso.length() < 0.01 or avanti.length() < 0.01:
		return 180.0
	return rad_to_deg(avanti.angle_to(verso))


## Per ogni punto (coordinate della medusa) quanto sta sotto la superficie su cui poggia (bordo,
## pavimento, fondo della fossa senza il coperchio): positivo se ci è dentro.
func _dentro_pavimento(punti: PackedVector3Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var space := p.get_world_3d().direct_space_state
	var esclusi: Array[RID] = [p.get_rid()]
	if lei.coperchio:
		esclusi.append(lei.coperchio.get_rid())
	for q in punti:
		var g: Vector3 = lei.medusa.global_transform * q
		var giu := PhysicsRayQueryParameters3D.create(Vector3(g.x, 2.5, g.z), Vector3(g.x, -4.0, g.z), Layers.WORLD)
		giu.exclude = esclusi
		var r := space.intersect_ray(giu)
		out.append(float(r.position.y) - g.y if not r.is_empty() else -10.0)
	return out


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
	if lei and not lei.abilitata:
		lei.abilitata = true
		var fine := level.get(&"fine_demo_trigger") as Area3D
		if fine:
			fine.monitoring = false


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)  # aspetta i caricamenti nel thread


## Vero se l'anta del portone, in 11 posizioni dalla chiusa all'aperta, non tocca nessun altro corpo
## (panche, lampade, cornici: la corsa lungo il muro est è libera). Alla fine la lascia aperta.
func _corsa_sgombra(portone: PortoneTorre) -> bool:
	var forme := portone.anta.find_children("*", "CollisionShape3D", true, false)
	var propri: Array[RID] = []
	for f in forme:
		var corpo := (f as Node).get_parent() as CollisionObject3D
		if corpo:
			propri.append(corpo.get_rid())
	var sgombra := not forme.is_empty()
	for i in 11:
		portone.call(&"_metti", i / 10.0)
		await get_tree().physics_frame
		var spazio := portone.get_world_3d().direct_space_state
		for f in forme:
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = (f as CollisionShape3D).shape
			# 3 cm più su: la base dell'anta sfiora il pavimento
			q.transform = (f as CollisionShape3D).global_transform.translated(Vector3(0.0, 0.03, 0.0))
			q.exclude = propri
			for r in spazio.intersect_shape(q, 8):
				sgombra = false
				printerr("    a %d%% l'anta tocca %s" % [i * 10, str(r.get("collider"))])
	portone.call(&"_metti", 1.0)
	return sgombra


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
