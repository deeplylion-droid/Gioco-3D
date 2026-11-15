extends Node
## Collaudo 0.4.0 (candidata), la fossa «mai di sorpresa»: senza schermo, col gioco vero (F9 «Sala al buio»). BF:.
## Ogni strada: il giocatore entra dalla serranda (parte il giro), poi è messo all'inizio della strada e la percorre
## camminando o correndo verso la fossa, guardando dove va; arrivato vicino alla fossa si ferma 6 s guardandola, poi le va
## addosso. Si segna: dove finisce il giro (distanza dalla fossa), l'avviso (fasi della luce e del canto), quando lei
## compare (sbuca o già affacciata), a che distanza e se la fossa era in vista; la presa: se c'è stato l'avviso, quanto
## l'ha vista ferma prima (in_vista_t) e se lei era sbucata in vista. DIFETTI segnati: presa senza avviso, presa senza
## averla vista ferma abbastanza, comparsa in vista entro 8 m.
## Strade: ovest, est, serranda (lontano dal bordo), bordo (lungo il bordo ovest), area_bimbi, spiaggia; con _corre
## correndo. Ripartenze: cp16, cp17, cp18 (il checkpoint raggiunto, una morte, la ripartenza, poi verso la fossa).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/buio_fossa.gd <strade,...>

var spia: Node
var buio: LeiSalaAlBuio
var ls: LeiSbuca
var t0 := 0
var difetti := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _t() -> float:
	return (Time.get_ticks_msec() - t0) / 1000.0


func _p() -> Player:
	return GameState.player as Player


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _arriva(vecchio: int) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 600000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		var p := GameState.player
		if s and String(s.name) != "Caricamento" and String(s.name) != "MenuPrincipale" and p and is_instance_valid(p) \
				and p.get_instance_id() != vecchio and p.is_inside_tree() and not GameState.is_dying and not GameState.is_restoring() and p.input_enabled:
			return true
	return false


func _parti() -> void:
	var vecchio := _p().get_instance_id() if GameState.player and is_instance_valid(GameState.player) else 0
	if get_tree().current_scene and String(get_tree().current_scene.name) != "MenuPrincipale" and vecchio != 0:
		Game.return_to_title()
		var t := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t < 300000 and not (get_tree().current_scene and String(get_tree().current_scene.name) == "MenuPrincipale"):
			await get_tree().process_frame
		await _fisica(30)
	GameState.reset_progress()
	MenuProva.parti(get_tree(), "sala_buio")
	await _arriva(vecchio)
	_prendi()


func _prendi() -> void:
	var level := get_tree().current_scene
	buio = level.find_child("LeiSalaAlBuio", true, false) as LeiSalaAlBuio
	ls = buio.lei_sbuca


func _guarda(dove: Vector3) -> void:
	var p := _p()
	var d := dove - (p.global_position + Vector3.UP * 1.6)
	p.set_look(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _metti(pos: Vector3) -> void:
	var p := _p()
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 2.0, pos + Vector3.DOWN * 3.0, Layers.WORLD)
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	p.teleport(h.position + Vector3.UP * 0.02 if not h.is_empty() else pos)


func _fossa() -> Vector3:
	return ls.punto_sbuca.global_position


func _d() -> float:
	return AcquaDiLei._in_pianta(_p().global_position, _fossa())


func _dall_occhio() -> float:
	var q: Vector3 = ls.call(&"_testa_prevista")
	return Vector2(q.x - _p().global_position.x, q.z - _p().global_position.z).length()


func _lascia() -> void:
	for a in [&"move_forward", &"move_back", &"sprint", &"spray"]:
		Input.action_release(a)


## La strada: [inizio, tappe...]; l'ultima tappa è la fossa.
func _strada(nome: String) -> Array:
	var f := _fossa()
	match nome:
		"ovest": return [Vector3(-18.5, 0, 8.0), Vector3(-18.5, 0, -3.5), f]
		"est": return [Vector3(-7.3, 0, 8.0), Vector3(-7.3, 0, -4.5), f]
		"serranda": return [Vector3(-21.0, 0, 15.0), Vector3(-21.0, 0, -4.0), f]
		"bordo": return [Vector3(-16.6, 0, 8.0), Vector3(-16.6, 0, -3.4), f]
		"area_bimbi": return [Vector3(-9.0, 0, -17.0), f]
		"spiaggia": return [Vector3(2.0, 0, -12.6), f]
		"bordo_sud": return [Vector3(-8.6, 0, 7.45), Vector3(-16.4, 0, 7.45), Vector3(-18.5, 0, -3.5), f]
		"serranda_dritto": return [Vector3(-15.0, 0, 16.8), f]
		"strada_vera": return [Vector3(-15.0, 0, 16.8), Vector3(-18.5, 0, 8.0), Vector3(-18.3, 0, -0.5), f]
	return []


func _cammina(tappe: Array, corre: bool, tag: String) -> void:
	var avviso_fasi := []
	var visto_avviso := false
	var comparsa_fatta := false
	var fine_giro := -1.0
	var ult_fase := -1
	var ult_acqua := ""
	var t_fermo := -1.0
	Input.action_press(&"move_forward")
	if corre:
		Input.action_press(&"sprint")
	var k := 1
	var fase_g := 0
	var pelo_prima := -INF
	var salto_max := 0.0
	var pelo_sbuca := []
	var fermo := float(OS.get_environment("FERMO")) if OS.get_environment("FERMO") != "" else 5.0
	var tt := Time.get_ticks_msec()
	var fase_presa := ""
	while Time.get_ticks_msec() - tt < 40000:
		await get_tree().physics_frame
		if GameState.is_dying:
			break
		var p := _p()
		var d := _d()
		# la tappa
		if k < tappe.size() - 1 and AcquaDiLei._in_pianta(p.global_position, tappe[k]) < 0.7:
			k += 1
		var meta: Vector3 = tappe[k]
		if k == tappe.size() - 1:
			# verso la fossa: fermo a FERMO m guardandola; se dopo 4 s aspetta ancora sotto, indietro fino a 6,5 m; poi addosso
			if d < fermo and t_fermo < 0.0:
				t_fermo = _t()
				_lascia()
				print("BF: %s %.2f s fermo a %.2f m dalla fossa (%.2f m dal suo occhio) a guardarla" % [tag, _t(), d, _dall_occhio()])
			if t_fermo >= 0.0 and fase_g == 0 and _t() - t_fermo > 4.0:
				if ls.fase == LeiSbuca.Fase.ATTESA:
					fase_g = 1
					Input.action_press(&"move_back")
					print("BF: %s %.2f s lei aspetta ancora sotto: indietro guardandola" % [tag, _t()])
				else:
					fase_g = 2
			if fase_g == 1 and (d > 6.5 or ls.fase != LeiSbuca.Fase.ATTESA):
				Input.action_release(&"move_back")
				fase_g = 2
				t_fermo = _t()
				print("BF: %s %.2f s fermo a %.2f m (%.2f m dal suo occhio), LeiSbuca %s" % [tag, _t(), d, _dall_occhio(), LeiSbuca.Fase.keys()[ls.fase]])
			if fase_g == 2 and _t() - t_fermo > 5.0 and not Input.is_action_pressed(&"move_forward"):
				Input.action_press(&"move_forward")
				print("BF: %s %.2f s le va addosso (LeiSbuca %s, in vista %.2f s)" % [tag, _t(), LeiSbuca.Fase.keys()[ls.fase], ls.in_vista_t])
			_guarda(meta + Vector3.UP * 0.8)
		else:
			_guarda(meta + Vector3.UP * 1.4)
		# il pelo della fossa: il salto più grande in un fotogramma, e quanto cambia intorno alla salita
		var tank := ls.vasche[0] as WaterTank if ls.vasche.size() > 0 else null
		if tank:
			var py := tank.get_surface_global_y()
			if pelo_prima > -INF:
				if absf(py - pelo_prima) > absf(salto_max):
					salto_max = py - pelo_prima
					if absf(salto_max) > 0.01:
						print("BF: %s %.2f s il pelo della fossa salta di %.3f m in un fotogramma (LeiSbuca %s, giocatore a %.2f m)" % [tag, _t(), salto_max, LeiSbuca.Fase.keys()[ls.fase], d])
			if ls.fase == LeiSbuca.Fase.SBUCA:
				pelo_sbuca.append(py)
			pelo_prima = py
		# il giro e l'avviso
		if buio.stato == LeiSalaAlBuio.Stato.FINITO and fine_giro < 0.0:
			fine_giro = d
			print("BF: %s %.2f s giro finito col giocatore a %.2f m dalla fossa (lontano dal bordo %s)" % [tag, _t(), d, buio.call(&"_lontano_dal_bordo", p)])
		var fa: String = AcquaDiLei.Fase.keys()[buio.acqua.fase] + "/" + String(buio.acqua.fase_canto)
		if fa != ult_acqua:
			ult_acqua = fa
			avviso_fasi.append("%s@%.2f(%.1fm)" % [fa, _t(), d])
			if fa.begins_with("SILENZIO"):
				visto_avviso = true
		if ls.fase != ult_fase:
			ult_fase = ls.fase
			var nome_f: String = LeiSbuca.Fase.keys()[ls.fase]
			var inv := ls.fossa_in_vista(p)
			print("BF: %s %.2f s LeiSbuca %s a %.2f m, fossa in vista %s, medusa visibile %s, luce fossa %s, avviso visto %s" % [tag, _t(), nome_f, d, inv,
					ls.medusa.visible, buio.luce_fossa_accesa(), visto_avviso])
			if (nome_f == "SBUCA" or nome_f == "GUARDA") and not comparsa_fatta:
				comparsa_fatta = true
				if d <= 8.0 and inv:
					difetti += 1
					print("BF: DIFETTO %s: comparsa in vista a %.2f m" % [tag, d])
			if nome_f == "PRESA":
				fase_presa = "presa a %.2f m, in vista %.2f s (serve %.1f), sbucata in vista %s, avviso visto %s" % [d, ls.in_vista_t,
						ls.vista_dopo_sbucata if ls.sbucata_in_vista else ls.vista_per_prendere, ls.sbucata_in_vista, visto_avviso]
				print("BF: %s %.2f s %s" % [tag, _t(), fase_presa])
				if not visto_avviso or not ls.puo_prendere():
					difetti += 1
					print("BF: DIFETTO %s: presa senza avviso o senza averla vista ferma" % tag)
		if Engine.get_physics_frames() % 120 == 0:
			print("BF: %s %.2f s stato: giocatore %s a %.2f m, LeiSbuca %s, in vista adesso %s (tot %.2f s), luce fossa %s, canto %s" % [tag, _t(),
					p.global_position.snappedf(0.01), d, LeiSbuca.Fase.keys()[ls.fase], ls.in_vista(p), ls.in_vista_t, buio.luce_fossa_accesa(), spia.call(&"adesso")])
		if t_fermo >= 0.0 and fase_g == 2 and _t() - t_fermo > 16.0:
			break
	_lascia()
	if GameState.is_dying and OS.get_environment("DOPO_PRESA") == "1" and not tag.ends_with("_dopo"):
		var v := _p().get_instance_id()
		var td := Time.get_ticks_msec()
		await _arriva(v)
		_prendi()
		await _fisica(60)
		print("BF: %s dopo la presa: ripartito in %.1f s (scena di morte intera), checkpoint %s, giocatore a %.2f m dalla fossa, LeiSbuca %s, giro %s, acqua %s" % [tag,
				(Time.get_ticks_msec() - td) / 1000.0, GameState.snapshot.get("checkpoint", ""), _d(), LeiSbuca.Fase.keys()[ls.fase],
				LeiSalaAlBuio.Stato.keys()[buio.stato], AcquaDiLei.Fase.keys()[buio.acqua.fase]])
		await _cammina([_p().global_position, _fossa()], false, tag + "_dopo")
		return
	if not pelo_sbuca.is_empty():
		print("BF: %s pelo della fossa durante la salita: da %.3f a %.3f" % [tag, pelo_sbuca[0], pelo_sbuca[-1]])
	print("BF: %s fine in %s: giro finito a %.2f m, LeiSbuca %s, morendo %s (causa %s), in vista %.2f s; luce/canto: %s" % [tag, _p().global_position.snappedf(0.01), fine_giro, LeiSbuca.Fase.keys()[ls.fase],
			GameState.is_dying, GameState.last_death_cause, ls.in_vista_t, avviso_fasi])


func _entra() -> void:
	_metti(Vector3(-15.0, 0, 16.8))
	_guarda(buio.vasca_grande.global_position)
	var t := Time.get_ticks_msec()
	while buio.stato == LeiSalaAlBuio.Stato.ATTESA and Time.get_ticks_msec() - t < 5000:
		await get_tree().physics_frame
	await _fisica(30)


func _ripartenza(cp: String) -> void:
	var nodo: String = {"cp16": "Tecnici/Logica/Checkpoint/CheckpointSerranda", "cp17": "Gioco/CheckpointAreaBimbi", "cp18": "Gioco/CheckpointSpiaggiaBuio"}[cp]
	var c := get_tree().current_scene.get_node(NodePath(nodo)) as Checkpoint
	await _entra()
	if cp != "cp16":
		_metti((c as Node3D).global_position)
		await _fisica(20)
		GameState.reach_checkpoint(c)
	print("BF: %s checkpoint %s, stato giro %s, LeiSbuca %s" % [cp, GameState.snapshot.get("checkpoint", ""), LeiSalaAlBuio.Stato.keys()[buio.stato], LeiSbuca.Fase.keys()[ls.fase]])
	var v := _p().get_instance_id()
	GameState.kill_player(&"prova")
	await _arriva(v)
	_prendi()
	await _fisica(30)
	print("BF: %s ripartito in %s (%.2f m dalla fossa), stato giro %s, LeiSbuca %s, acqua fase %s" % [cp, _p().global_position.snappedf(0.01), _d(),
			LeiSalaAlBuio.Stato.keys()[buio.stato], LeiSbuca.Fase.keys()[ls.fase], AcquaDiLei.Fase.keys()[buio.acqua.fase]])
	var tappe := [_p().global_position]
	if cp == "cp16":
		tappe = [_p().global_position, Vector3(-18.5, 0, -3.5), _fossa()]
	else:
		tappe.append(_fossa())
	await _cammina(tappe, false, cp)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	spia = preload("res://tests/collaudo/spia_canto.gd").new()
	spia.set(&"stampa", false)
	get_tree().root.add_child.call_deferred(spia)
	t0 = Time.get_ticks_msec()
	var strade := OS.get_cmdline_user_args()[1].split(",")
	for s in strade:
		print("BF: ===== %s" % s)
		await _parti()
		if s.begins_with("cp"):
			await _ripartenza(s)
			continue
		var corre := s.ends_with("_corre")
		var nome := s.trim_suffix("_corre")
		await _entra()
		var tappe := _strada(nome)
		_metti(tappe[0])
		await _fisica(5)
		print("BF: %s parte da %s (%.2f m dalla fossa), stato giro %s" % [s, _p().global_position.snappedf(0.01), _d(), LeiSalaAlBuio.Stato.keys()[buio.stato]])
		await _cammina(tappe, corre, s)
	print("BF: difetti %d" % difetti)
	print("BF: finito")
	Game.esci(0)
