extends Node
## La fossa della sala al buio non sorprende mai (collaudo della 0.4.0, scelta A del coordinatore). Nella sala vera, al
## buio, il giocatore va verso la fossa da più parti, camminando (3,4 m/s) e correndo (5,8 m/s), guardando avanti con
## un'occhiata indietro ogni tanto, poi resta vicino alla fossa guardandola; e riparte dai checkpoint 16, 17 e 18. In
## ogni fotogramma:
## - lei comincia a sbucare (la salita in vista) solo dopo l'avviso intero (la luce sotto la fossa, il canto, il
##   silenzio: 3,5 s) e col giocatore a più di 3,4 m da dove sarà il suo occhio (la presa più un metro);
## - compare già affacciata solo con la fossa fuori dall'inquadratura (o a schermo nero) e col giocatore a più di 8 m;
## - mentre sale non prende; prende solo dopo che il giocatore l'ha avuta in vista affacciata e ferma per 3 s (1,6 s se
##   l'ha vista sbucare: in tutto mai prima di avviso + salita + 1,6 s).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_fossa_mai_di_sorpresa.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const CAMMINA := 3.4
const CORRE := 5.8

var _ok := 0
var _ko := 0
var level: Node
var buio: LeiSalaAlBuio
var ls: LeiSbuca
var p: Player


func _ready() -> void:
	_run.call_deferred()


func check(c: bool, msg: String) -> void:
	if c:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _prendi_riferimenti() -> void:
	level = get_tree().current_scene
	buio = level.find_child("LeiSalaAlBuio", true, false) as LeiSalaAlBuio
	ls = level.find_child("LeiSbuca", true, false) as LeiSbuca
	p = GameState.player as Player


## Riparte dal checkpoint [param nome] della sala (anche se intanto il giocatore ne ha preso uno dopo: passando
## dall'area bimbi prende il 17).
func _ricarica(nome := "CheckpointSerranda") -> void:
	# (dopo una presa la sala si è già ricaricata da sola: si aspetta che sia pronta)
	for i in 60 * 40:
		if get_tree().current_scene and GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying \
				and not GameState.is_restoring():
			break
		await get_tree().process_frame
	await _fisica(5)
	_prendi_riferimenti()
	var cp := level.find_child(nome, true, false) as Checkpoint
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	GameState.capture_snapshot(GameState.persist_key(cp), cp.order, cp.get_spawn_transform())
	var vecchia := get_tree().current_scene
	GameState.respawn()
	for i in 60 * 40:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s != vecchia and GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _fisica(20)
	_prendi_riferimenti()
	# (il fischio dal buio lo prova test_fischio_sala: qui solo la fossa)
	buio.fischio = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path == LEVEL and GameState.player and is_instance_valid(GameState.player):
			break
	await _fisica(30)
	_prendi_riferimenti()
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var f := ls.punto_sbuca.global_position
	var occhio := ls.punto_sbuca.global_transform * Vector3(0.0, 1.63, 1.8)
	print("fossa ", f, " occhio ", occhio)

	var ovest: Array[Vector3] = [Vector3(-17.6, 0, 14.0), Vector3(-17.6, 0, -3.5)]
	var est: Array[Vector3] = [Vector3(-7.4, 0, 14.0), Vector3(-7.4, 0, -3.5)]
	var serranda: Array[Vector3] = [Vector3(-15.0, 0, 19.3), Vector3(-17.6, 0, 10.0), Vector3(-17.6, 0, -3.5)]
	var bordo_sud: Array[Vector3] = [Vector3(-12.5, 0, 7.6), Vector3(-8.6, 0, 7.6), Vector3(-8.6, 0, -3.6)]
	var spiaggia: Array[Vector3] = [Vector3(0.0, 0, -14.2)]
	var bimbi: Array[Vector3] = [Vector3(-18.3, 0, -0.5)]
	for v in [CAMMINA, CORRE]:
		for c in [["ovest della vasca grande", ovest], ["est della vasca grande", est], ["dalla serranda", serranda],
				["dal bordo della vasca grande, dritto verso la fossa guardandola", bordo_sud],
				["dalla spiaggia", spiaggia], ["dall'area bimbi", bimbi]]:
			if OS.has_environment("SOLO") and not c[0].begins_with(OS.get_environment("SOLO")):
				continue
			await _ricarica()
			await _percorso("%s, %s" % [c[0], "camminando" if v == CAMMINA else "correndo"], c[1], v, c[0].begins_with("dal bordo"))
	await _ricarica()
	await _bordo()
	for nome in ([] if OS.has_environment("SOLO") and OS.get_environment("SOLO") != "checkpoint" else ["CheckpointAreaBimbi", "CheckpointSpiaggiaBuio"]):
		await _ricarica(nome)
		var da := p.global_position
		await _percorso("ripartendo da %s" % nome, [Vector3(da.x, 0, da.z)] as Array[Vector3], CAMMINA, false, true)
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)


## Chi arriva al bordo della vasca grande (dalla serranda, al bordo sud) e ci resta ha ancora un'uscita dalla vasca
## prima che la luce se ne vada alla fossa.
func _bordo() -> void:
	print("— al bordo sud della vasca grande, dalla serranda")
	buio.letale = false
	var acqua := buio.acqua
	var pos := Vector3(-15.0, 0.05, 19.3)
	var bordo := buio.vasca_grande.to_global(Vector3(0, 0, buio.vasca_grande.inner_size.z * 0.5 + 0.4))
	bordo.y = 0.05
	var uscita := false
	var finita_prima := false
	for i in 60 * 40:
		pos = pos.move_toward(bordo, 3.4 / 60.0)
		p.teleport(pos)
		p.look_at_point(buio.vasca_grande.global_position)
		await get_tree().physics_frame
		if buio.stato == LeiSalaAlBuio.Stato.FINITO and not uscita:
			finita_prima = true
			break
		if acqua.fase == AcquaDiLei.Fase.ESCE:
			uscita = true
			break
	check(uscita and not finita_prima, "al bordo sud lei esce dalla vasca grande prima che la luce vada alla fossa (sala %d, uscita %s)" % [buio.stato, uscita])
	buio.letale = true


## Il giocatore lungo [param punti] e poi fin quasi al suo occhio (a 1,5 m), a [param v] m/s; guarda avanti (o sempre la
## fossa, con [param guarda_la_fossa]) con un'occhiata indietro di 0,8 s ogni 4 s; poi resta lì 8 s guardandola, si gira
## per 2 s e la riguarda 6 s. Controlla le regole in ogni fotogramma.
func _percorso(nome: String, punti: Array[Vector3], v: float, guarda_la_fossa: bool, gia_li := false) -> void:
	print("— ", nome)
	var occhio := ls.punto_sbuca.global_transform * Vector3(0.0, 1.63, 1.8)
	var ultimo: Vector3 = punti[punti.size() - 1]
	var verso := Vector3(occhio.x - ultimo.x, 0, occhio.z - ultimo.z).normalized()
	var arrivo := Vector3(occhio.x, 0, occhio.z) - verso * 1.5
	var tappe: Array[Vector3] = punti.duplicate()
	tappe.append(arrivo)
	var errori: Array[String] = []
	if not gia_li and (buio.stato == LeiSalaAlBuio.Stato.FINITO or ls.fase != LeiSbuca.Fase.ATTESA):
		errori.append("la fossa è partita prima del percorso (sala %d, fossa %d)" % [buio.stato, ls.fase])
	var pos := tappe[0] if not gia_li else p.global_position
	pos.y = 0.05
	p.teleport(pos)
	await _fisica(2)
	var dt := 0.0
	var t := 0.0
	var i := 1 if not gia_li else 0
	var acqua := buio.acqua
	var fase_prima := ls.fase
	var t_avviso := -1.0         # quando la luce è partita verso la fossa (ARRIVA dopo il giro)
	var avviso_intero := false   # ARRIVA -> SPEGNE -> SILENZIO arrivati in fondo
	var fasi_acqua: Array = []
	var t_su := -1.0
	var come := ""
	var morto := false
	var fermo_t := 0.0
	var d_sbuca := -1.0
	var in_arrivo := true        # ancora sul percorso (non fermo vicino alla fossa)
	var aspetta_al_buio := 0     # fotogrammi in cui lei aspetta dopo l'avviso con la luce della fossa spenta
	var aspetta := 0
	while t < 120.0:
		# (il tempo del gioco: un fotogramma di fisica)
		dt = get_physics_process_delta_time()
		# il passo
		var guarda: Vector3
		if i < tappe.size():
			var meta := tappe[i]
			meta.y = pos.y
			var d := pos.distance_to(meta)
			var passo := v * dt
			if d <= passo:
				pos = meta
				i += 1
			else:
				pos += (meta - pos) / d * passo
			guarda = pos + (meta - pos).normalized() * 5.0 + Vector3.UP * 1.4 if d > 0.01 else occhio
			if guarda_la_fossa:
				guarda = occhio
			if fmod(t, 4.0) > 3.2:
				guarda = pos - (guarda - pos)
		else:
			in_arrivo = false
			# vicino alla fossa: la guarda 8 s, si gira 2 s, la riguarda 6 s; poi torna indietro guardandola fino a 12 m
			# dalla fossa e aspetta lì (lei può sbucare in vista: è a più di 8 m); poi le va incontro fino a 1,5 m dal suo
			# occhio e resta lì (correndo solo la prima parte: il resto è uguale)
			fermo_t += dt
			guarda = occhio
			if fermo_t > 8.0 and fermo_t < 10.0:
				guarda = pos - (occhio - pos)
			elif fermo_t > 16.0 and v > CAMMINA:
				break
			elif fermo_t > 16.0 and fermo_t <= 30.0:
				var lontano := Vector3(occhio.x, pos.y, occhio.z) - verso * 12.0
				pos = pos.move_toward(lontano, v * dt)
			elif fermo_t > 30.0 and fermo_t <= 44.0:
				pos = pos.move_toward(Vector3(arrivo.x, pos.y, arrivo.z), v * dt)
			elif fermo_t > 44.0:
				break
		p.teleport(pos)
		p.look_at_point(guarda)
		await get_tree().physics_frame
		t += dt
		# l'avviso
		if acqua and is_instance_valid(acqua) and (fasi_acqua.is_empty() or fasi_acqua[-1] != acqua.fase):
			fasi_acqua.append(acqua.fase)
			if OS.has_environment("DEBUG_FOSSA"):
				print("    t=%.2f acqua %d buio %d ls %d d=%.1f" % [t, acqua.fase, buio.stato, ls.fase, AcquaDiLei._in_pianta(pos, ls.punto_sbuca.global_position)])
			if fasi_acqua.size() == 1 and gia_li and buio.stato == LeiSalaAlBuio.Stato.FINITO \
					and acqua.fase in [AcquaDiLei.Fase.ARRIVA, AcquaDiLei.Fase.SPEGNE, AcquaDiLei.Fase.SILENZIO]:
				# (ripartendo vicino alla fossa l'avviso parte già al caricamento: lo si conta da prima)
				t_avviso = -INF
				fasi_acqua = [AcquaDiLei.Fase.ARRIVA, AcquaDiLei.Fase.SPEGNE, AcquaDiLei.Fase.SILENZIO].slice(0, [AcquaDiLei.Fase.ARRIVA, AcquaDiLei.Fase.SPEGNE, AcquaDiLei.Fase.SILENZIO].find(acqua.fase) + 1)
			elif acqua.fase == AcquaDiLei.Fase.ARRIVA and buio.stato == LeiSalaAlBuio.Stato.FINITO:
				t_avviso = t
		if acqua and acqua.fase == AcquaDiLei.Fase.LONTANA and fasi_acqua.size() >= 4 \
				and fasi_acqua.slice(-4) == [AcquaDiLei.Fase.ARRIVA, AcquaDiLei.Fase.SPEGNE, AcquaDiLei.Fase.SILENZIO, AcquaDiLei.Fase.LONTANA]:
			avviso_intero = true
		# B: finché aspetta dopo l'avviso, la luce rosa resta nella fossa
		if ls.sta_aspettando() and not ls.aspetta_il_giro:
			aspetta += 1
			if not buio.luce_fossa_accesa():
				aspetta_al_buio += 1
		# lei alla fossa
		var dist := AcquaDiLei._in_pianta(pos, ls.punto_sbuca.global_position)
		if ls.fase != fase_prima and OS.has_environment("DEBUG_FOSSA"):
			print("    t=%.2f ls %d -> %d d=%.1f" % [t, fase_prima, ls.fase, AcquaDiLei._in_pianta(pos, ls.punto_sbuca.global_position)])
		if ls.fase != fase_prima:
			if fase_prima == LeiSbuca.Fase.ATTESA and ls.fase == LeiSbuca.Fase.SBUCA:
				come = "sbuca" if in_arrivo else "sbuca (tornando indietro)"
				d_sbuca = AcquaDiLei._in_pianta(pos, occhio)
				t_su = t
				if d_sbuca <= ls.distanza_sbuca:
					errori.append("sbuca col giocatore a %.1f m dal suo occhio" % d_sbuca)
				if not avviso_intero or t - t_avviso < 3.5 - 0.05:
					errori.append("sbuca senza l'avviso intero (%.2f s dall'avviso)" % (t - t_avviso))
			elif fase_prima == LeiSbuca.Fase.ATTESA and ls.fase == LeiSbuca.Fase.GUARDA:
				come = "affacciata"
				t_su = t
				if dist <= 8.0:
					errori.append("compare affacciata col giocatore a %.1f m" % dist)
				# (ripartendo vicino alla fossa, appena caricata la sala a schermo nero, lei è già affacciata)
				if ls.fossa_in_vista(p) and Dissolvenza.schermo_libero(get_tree()) and not (gia_li and t < 0.6):
					errori.append("compare affacciata con la fossa in vista")
			fase_prima = ls.fase
		if GameState.is_dying:
			morto = true
			if GameState.last_death_cause == &"medusa" and ls.fase == LeiSbuca.Fase.PRESA:
				var serve := ls.vista_dopo_sbucata if ls.sbucata_in_vista else ls.vista_per_prendere
				if ls.in_vista_t < serve - 0.02:
					errori.append("prende dopo solo %.2f s in vista (ne servono %.1f)" % [ls.in_vista_t, serve])
				if ls.sbucata_in_vista and t - t_avviso < 3.5 + ls.durata_sbuca + 1.6 - 0.05:
					errori.append("prende %.2f s dopo l'avviso (meno di avviso + salita + 1,6 s)" % (t - t_avviso))
			break
	if aspetta_al_buio > 1:
		errori.append("lei aspetta con la luce della fossa spenta (%d fotogrammi)" % aspetta_al_buio)
	# camminando dalla serranda e da ovest lei si fa vedere mentre il giocatore arriva (sbuca in vista oltre la soglia, o è
	# già affacciata se in quel momento lui guardava altrove); dal bordo guardandola sbuca in vista oltre la soglia
	if v == CAMMINA and nome.begins_with("dal bordo") and not come.begins_with("sbuca"):
		errori.append("dal bordo guardandola doveva sbucare in vista (%s)" % come)
	var esito := "lei %s %s" % [come if come != "" else "non è venuta", ("(%.1f s dall'avviso)" % (t_su - t_avviso)) if t_su >= 0.0 and t_avviso >= 0.0 else ""]
	esito += "; %s" % ("presa" if morto else "nessuna presa")
	if d_sbuca >= 0.0:
		esito += "; sbucata col giocatore a %.1f m dal suo occhio" % d_sbuca
	if aspetta > 0:
		esito += "; ha aspettato %.1f s con la luce nella fossa" % (aspetta / 60.0)
	check(errori.is_empty(), "%s: %s%s" % [nome, esito, "" if errori.is_empty() else " — " + "; ".join(errori)])
	if morto:
		# (si aspetta la fine della sequenza di morte: la prossima ricarica parte da lì)
		for k in 60 * 15:
			await get_tree().process_frame
			if not GameState.is_dying:
				break
