extends Node
## Collaudo 0.4.0, zona B (la sala al buio), senza schermo, col gioco vero: F9 «Sala al buio» (alla serranda). BG:.
## Scenari (argomento, separati da virgola):
##   partenza: fermo alla serranda 6 s (il giro non parte), dentro la sala 40 s (dove passa la luce: in quale acqua,
##     quanto fuori dall'acqua e quanto sopra il pavimento), indietro nel magazzino (il giro finisce), di nuovo dentro;
##   bordo0..bordo3: sul bordo della vasca grande accanto al punto d'uscita k, guardando la vasca: la luce passa, lei
##     esce e prende; i giocattoli prima e dopo (sovrapposti fra loro, dentro il bordo), la morte, da dove riparte, i
##     giocattoli dopo la ripartenza, il giro che riparte tornando sul bordo;
##   salvo: sul bordo 0, quando esce si allontana di 4,5 m: non prende;
##   getto: sul bordo 0, quando esce il getto vero dello zaino sul viso: torna sotto;
##   fossa_cammina / fossa_corre: da 14 m dalla fossa, lontano dai punti d'uscita, verso la fossa camminando o
##     correndo: quando finisce il giro, dove è il giocatore quando lei è alla fossa, cosa fa LeiSbuca (sbuca o già
##     affacciata), poi il getto e dopo 20 s di silenzio (il canto).
## Con la spia del canto (SC:).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/buio_giro.gd <scenari>

var spia: Node
var buio: LeiSalaAlBuio
var t0 := 0
var _orig := {}        # percorso del giocattolo -> posizione all'arrivo


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _t() -> float:
	return (Time.get_ticks_msec() - t0) / 1000.0


func _secondi(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await get_tree().physics_frame


func _arriva(vecchio: int) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 600000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		var p := GameState.player
		if s and String(s.name) != "Caricamento" and p and is_instance_valid(p) and p.get_instance_id() != vecchio \
				and p.is_inside_tree() and not GameState.is_dying and not GameState.is_restoring() and p.input_enabled:
			return true
	return false


func _prendi_livello() -> void:
	var level := get_tree().current_scene
	buio = level.find_child("LeiSalaAlBuio", true, false) as LeiSalaAlBuio
	if buio and buio.acqua:
		buio.acqua.fase_cambiata.connect(func(f): print("BG: condizioni %s" % _condizioni(buio.acqua)) if int(f) == AcquaDiLei.Fase.LONTANA else null)
		buio.acqua.fase_cambiata.connect(func(f): print("BG: %.2f s fase %s, giocatore %s, luce %s, stato giro %s" % [_t(),
				AcquaDiLei.Fase.keys()[int(f)], GameState.player.global_position.snappedf(0.01), buio.acqua.punto_luce.snappedf(0.01),
				LeiSalaAlBuio.Stato.keys()[buio.stato]]))
		buio.acqua.presa.connect(func(): print("BG: %.2f s PRESA" % _t()))
		buio.acqua.respinta.connect(func(): print("BG: %.2f s respinta" % _t()))
		buio.acqua.tornata_sotto.connect(func(): print("BG: %.2f s tornata sotto" % _t()))
	var ls := buio.lei_sbuca if buio else null
	if ls:
		for sg in ["sbucata", "vista", "spruzzata", "andata_via", "presa"]:
			ls.connect(sg, func(_a = null): print("BG: %.2f s LeiSbuca %s, fase %s, giocatore %s" % [_t(), sg, LeiSbuca.Fase.keys()[ls.fase],
					GameState.player.global_position.snappedf(0.01)]))


func _condizioni(acq: Node) -> String:
	if acq == null:
		return "-"
	var altrove := []
	var prop: Node = acq.get(&"_proprietaria")
	if prop and is_instance_valid(prop) and prop != acq:
		altrove.append("proprietaria " + str(prop.get_path()))
	for n in get_tree().get_nodes_in_group(AcquaDiLei.LEI_IN_SCENA):
		if n != acq.get(&"_lei") and n is Node3D and (n as Node3D).is_visible_in_tree():
			altrove.append("in scena " + str(n.get_path()))
	var p := GameState.player as Node3D
	for n in get_tree().get_nodes_in_group(MedusaAffacciata.GRUPPO_LEI):
		var l := n as Node3D
		if l and l != acq.get(&"_lei") and l.is_visible_in_tree():
			altrove.append("affacciata visibile %s a %.1f m" % [l.get_path(), (l.global_position + Vector3.UP * 1.5).distance_to(p.global_position)])
	var cam := get_viewport().get_camera_3d()
	var lista: Array = get_tree().get_nodes_in_group(&"bambini")
	for n in get_tree().get_nodes_in_group(&"persist"):
		if n is BambinoSfuggita:
			lista.append(n)
	for n in lista:
		var b := n as Node3D
		if b and b.is_visible_in_tree() and cam and cam.is_position_in_frustum(b.global_position + Vector3.UP * 0.8):
			altrove.append("bambino in vista %s in %s a %.1f m" % [b.get_path(), b.global_position.snappedf(0.1), b.global_position.distance_to(cam.global_position)])
	return "luci %s, morendo %s, zona %s, puo %s, altrove %s, in vista %s, bambino %s %s" % [GameState.luci, GameState.is_dying,
			acq.call(&"giocatore_nella_zona"), acq.call(&"puo_venire"), acq.call(&"lei_altrove"), acq.call(&"lei_in_vista_altrove"),
			acq.call(&"bambino_in_vista"), altrove]


func _p() -> Player:
	return GameState.player as Player


func _guarda(dove: Vector3) -> void:
	var p := _p()
	var d := dove - (p.global_position + Vector3.UP * 1.6)
	p.set_look(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _metti(pos: Vector3, verso: Vector3) -> void:
	var p := _p()
	# il pavimento sotto
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 2.0, pos + Vector3.DOWN * 3.0, Layers.WORLD)
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	var su := pos
	if not h.is_empty():
		su = h.position + Vector3.UP * 0.02
	p.teleport(su)
	_guarda(verso)
	print("BG: %.2f s giocatore messo in %s (pavimento %s)" % [_t(), su.snappedf(0.01), "trovato" if not h.is_empty() else "NON TROVATO"])


## Il punto sul bordo accanto al punto d'uscita k: 0,45 m fuori dal bordo interno della vasca grande.
func _bordo(k: int) -> Vector3:
	var v := buio.vasca_grande
	var m := v.inner_size * 0.5
	var loc: Vector3 = [Vector3(m.x + 0.45, 0, 0), Vector3(-m.x - 0.45, 0, 0), Vector3(0, 0, m.z + 0.45), Vector3(0, 0, -m.z - 0.45)][k]
	var g := v.to_global(loc)
	g.y = 0.0
	return g


func _giocattoli() -> Dictionary:
	return buio.galleggianti_e_raggi()


func _impronta(g: Node3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	var mesh_g: Array = g.find_children("*", "MeshInstance3D", true, false)
	if g is MeshInstance3D:
		mesh_g.append(g)
	var v := buio.vasca_grande
	for m in mesh_g:
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var f := mi.mesh.get_faces()
		for i in range(0, f.size(), 3):
			var l := v.to_local(mi.global_transform * f[i])
			out.append(Vector2(l.x, l.z))
	return out


## I giocattoli: dentro il bordo (quanto escono dall'interno della vasca), fra loro (la distanza minima fra le impronte),
## e dal punto d'uscita q (il più vicino).
func _controlla_giocattoli(tag: String, q: Node3D) -> void:
	var gr := _giocattoli()
	var v := buio.vasca_grande
	var m := v.inner_size * 0.5
	var impr := {}
	for g in gr:
		impr[g] = _impronta(g)
	var nomi := []
	for g in gr:
		var fuori := -INF
		for p2 in impr[g]:
			fuori = maxf(fuori, maxf(absf(p2.x) - m.x, absf(p2.y) - m.z))
		var dq := INF
		if q:
			var lq := v.to_local(q.global_position)
			for p2 in impr[g]:
				dq = minf(dq, p2.distance_to(Vector2(lq.x, lq.z)))
		var sp: float = g.global_position.distance_to(_orig.get(str(g.get_path()), g.global_position))
		nomi.append("%s fuori dal bordo interno %.3f m, dal punto %.2f m, spostato %.2f m" % [g.name, fuori, dq, sp])
	print("BG: %s giocattoli %d: %s" % [tag, gr.size(), nomi])
	var lista := gr.keys()
	var cattivi := []
	for i in lista.size():
		for j in range(i + 1, lista.size()):
			var a: Node3D = lista[i]
			var b: Node3D = lista[j]
			if Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length() > float(gr[a]) + float(gr[b]) + 0.1:
				continue
			var dm := INF
			var ia: PackedVector2Array = impr[a]
			var ib: PackedVector2Array = impr[b]
			for x in range(0, ia.size(), 3):
				for y in range(0, ib.size(), 3):
					dm = minf(dm, ia[x].distance_to(ib[y]))
			cattivi.append("%s-%s %.3f m" % [a.name, b.name, dm])
	print("BG: %s coppie vicine (distanza minima fra le impronte in pianta, vertici): %s" % [tag, cattivi])


func _segna_originali() -> void:
	_orig.clear()
	for g in _giocattoli():
		_orig[str(g.get_path())] = (g as Node3D).global_position


func _confronta_originali(tag: String) -> void:
	var mx := 0.0
	var chi := ""
	var n := 0
	var level := get_tree().current_scene
	for k in _orig:
		var g := level.get_node_or_null(NodePath(String(k).trim_prefix("/root/" + level.name + "/"))) as Node3D
		if g == null:
			g = get_tree().root.get_node_or_null(NodePath(k)) as Node3D
		if g == null:
			continue
		n += 1
		var d := g.global_position.distance_to(_orig[k])
		if d > mx:
			mx = d
			chi = g.name
	print("BG: %s giocattoli confrontati %d, il più lontano dal suo posto %s a %.4f m" % [tag, n, chi, mx])


func _aspetta_fase(fasi: Array, massimo: float) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < massimo * 1000.0:
		await get_tree().physics_frame
		if buio.acqua and AcquaDiLei.Fase.keys()[buio.acqua.fase] in fasi:
			return true
		if GameState.is_dying:
			return false
	return false


func _in_acqua(pt: Vector3) -> String:
	for v in [buio.vasca_grande] + buio.vasche_bimbi:
		var l := (v as WaterTank).to_local(pt)
		var m := (v as WaterTank).inner_size * 0.5
		if absf(l.x) <= m.x and absf(l.z) <= m.z and pt.y <= v.get_surface_global_y() + 0.01 and pt.y >= v.get_floor_global_y() - 0.01:
			return v.name
	return ""


func _partenza() -> void:
	print("BG: partenza: stato %s, giocatore %s, nella zona %s" % [LeiSalaAlBuio.Stato.keys()[buio.stato], _p().global_position.snappedf(0.01),
			buio.zona.has_point(_p().global_position)])
	var luce_vista := false
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 6000:
		await get_tree().physics_frame
		luce_vista = luce_vista or (buio.acqua.call(&"in_giro") as bool)
	print("BG: dopo 6 s alla serranda: stato %s, luce in giro %s" % [LeiSalaAlBuio.Stato.keys()[buio.stato], luce_vista])
	var spawn := _p().global_position
	_metti(spawn + Vector3(0, 0, -2.5), buio.vasca_grande.global_position)
	var conta := {}
	var max_sopra := -INF
	var dove_sopra := Vector3.ZERO
	var tot := 0
	var punti_giro: PackedVector3Array = buio.acqua.get(&"_giro")
	t = Time.get_ticks_msec()
	var prossimo := 0.0
	while Time.get_ticks_msec() - t < 40000:
		await get_tree().physics_frame
		if punti_giro.is_empty():
			punti_giro = buio.acqua.get(&"_giro")
			if not punti_giro.is_empty():
				print("BG: %.2f s il giro parte (stato %s), punti %s" % [_t(), LeiSalaAlBuio.Stato.keys()[buio.stato], punti_giro])
		var luce: OmniLight3D = buio.acqua.get(&"_luce")
		if luce and luce.is_visible_in_tree() and luce.light_energy > 0.01:
			tot += 1
			var w := _in_acqua(luce.global_position)
			conta[w if w != "" else "FUORI"] = int(conta.get(w if w != "" else "FUORI", 0)) + 1
			if w == "":
				# quanto sopra il pavimento più vicino (raggio verso l'alto e verso il basso)
				var sp: PhysicsDirectSpaceState3D = luce.get_world_3d().direct_space_state
				var hq := sp.intersect_ray(PhysicsRayQueryParameters3D.create(luce.global_position, luce.global_position + Vector3.UP * 3.0, Layers.WORLD))
				var sopra: float = -1.0 if hq.is_empty() else (hq.position.y - luce.global_position.y)
				if hq.is_empty() and luce.global_position.y > max_sopra:
					max_sopra = luce.global_position.y
					dove_sopra = luce.global_position
			var ora := (Time.get_ticks_msec() - t) / 1000.0
			if ora >= prossimo:
				prossimo += 1.0
				print("BG: giro %.1f s: luce in %s (%s), energia %.2f, vicinanza %.2f, fc %s, canto %s" % [ora, luce.global_position.snappedf(0.01), w if w != "" else "FUORI DALL'ACQUA",
						luce.light_energy, float(buio.acqua.vicinanza), buio.acqua.fase_canto, spia.call(&"adesso")])
	print("BG: giro 40 s: fotogrammi con la luce accesa %d, dove: %s; la più alta fuori dall'acqua senza niente sopra: %s" % [tot, conta, dove_sopra.snappedf(0.01) if max_sopra > -INF else "-"])
	# indietro nel magazzino
	_metti(spawn + Vector3(0, 0, 1.5), spawn + Vector3(0, 0, 10))
	await _secondi(4.0)
	var luce2: OmniLight3D = buio.acqua.get(&"_luce")
	print("BG: nel magazzino dopo 4 s: stato %s, luce visibile %s, in giro %s, fase %s, canto %s" % [LeiSalaAlBuio.Stato.keys()[buio.stato],
			luce2.is_visible_in_tree() if luce2 else null, buio.acqua.call(&"in_giro"), AcquaDiLei.Fase.keys()[buio.acqua.fase], spia.call(&"adesso")])
	_metti(spawn + Vector3(0, 0, -2.5), buio.vasca_grande.global_position)
	await _secondi(4.0)
	print("BG: di nuovo dentro dopo 4 s: stato %s, in giro %s" % [LeiSalaAlBuio.Stato.keys()[buio.stato], buio.acqua.call(&"in_giro")])


func _sul_bordo(k: int, modo: String) -> void:
	var q: Node3D = buio.acqua.punti_uscita[k]
	print("BG: bordo%d (%s): punto d'uscita in %s" % [k, modo, q.global_position.snappedf(0.01)])
	if buio.stato != LeiSalaAlBuio.Stato.GIRO:
		# come si arriva davvero: dalla serranda dentro la sala, e il giro parte
		_metti(Vector3(-15.0, 0.0, 16.8), buio.vasca_grande.global_position)
		var tg := Time.get_ticks_msec()
		while buio.stato != LeiSalaAlBuio.Stato.GIRO and Time.get_ticks_msec() - tg < 10000:
			await get_tree().physics_frame
		await _secondi(1.0)
		print("BG: bordo%d: entrato nella sala, stato %s" % [k, LeiSalaAlBuio.Stato.keys()[buio.stato]])
	_metti(_bordo(k), Vector3(q.global_position.x, buio.vasca_grande.get_surface_global_y(), q.global_position.z))
	_controlla_giocattoli("bordo%d prima" % k, q)
	var ok := await _aspetta_fase(["ARRIVA"], 90.0)
	if not ok:
		print("BG: bordo%d: lei non arriva in 90 s (stato %s, fase %s)" % [k, LeiSalaAlBuio.Stato.keys()[buio.stato], AcquaDiLei.Fase.keys()[buio.acqua.fase]])
		return
	var preso: Node3D = buio.acqua.get(&"_punto")
	print("BG: bordo%d: arriva al punto %s" % [k, buio.acqua.punti_uscita.find(preso)])
	await _aspetta_fase(["ESCE"], 10.0)
	if modo.begins_with("getto_su") or modo.begins_with("getto_esce"):
		if modo.begins_with("getto_su"):
			await _aspetta_fase(["SU"], 5.0)
		var t_su := Time.get_ticks_msec()
		var reaz := float(modo.get_slice("_", 2)) if modo.get_slice_count("_") > 2 else 0.0
		while Time.get_ticks_msec() - t_su < reaz * 1000.0:
			await get_tree().physics_frame
		var viso2: Node3D = buio.acqua.get(&"_viso")
		if viso2:
			_guarda(viso2.global_position)
		Input.action_press(&"spray")
		var esito := ""
		while Time.get_ticks_msec() - t_su < 4000:
			await get_tree().physics_frame
			if viso2 and is_instance_valid(viso2):
				_guarda(viso2.global_position)
			var fz: String = AcquaDiLei.Fase.keys()[buio.acqua.fase]
			if fz == "SCENDE" or fz == "CALMA":
				esito = "RESPINTA"
				break
			if fz == "PRESA" or GameState.is_dying:
				esito = "PRESO"
				break
		Input.action_release(&"spray")
		print("BG: %s: %s %.2f s dopo l'inizio (reazione %.2f s), zaino %.1f" % [modo, esito, (Time.get_ticks_msec() - t_su) / 1000.0, reaz, _p().water_pack.tank_amount])
		if esito == "PRESO":
			var v2 := _p().get_instance_id()
			await _arriva(v2)
			_prendi_livello()
		else:
			await _secondi(3.0)
		return
	match modo:
		"presa":
			await _secondi(2.0)
			_controlla_giocattoli("bordo%d con lei fuori" % k, preso)
			var v := _p().get_instance_id()
			var t := Time.get_ticks_msec()
			while not GameState.is_dying and Time.get_ticks_msec() - t < 10000:
				await get_tree().physics_frame
			print("BG: bordo%d: morendo %s" % [k, GameState.is_dying])
			_segna_originali_se_vuoto()
			await _arriva(v)
			_prendi_livello()
			print("BG: bordo%d: ripartito, checkpoint %s, giocatore %s, stato giro %s, fase %s" % [k, GameState.snapshot.get("checkpoint", ""),
					_p().global_position.snappedf(0.01), LeiSalaAlBuio.Stato.keys()[buio.stato], AcquaDiLei.Fase.keys()[buio.acqua.fase]])
			_confronta_originali("bordo%d dopo la ripartenza" % k)
			await _secondi(3.0)
			print("BG: bordo%d: 3 s dopo la ripartenza: stato %s, in giro %s" % [k, LeiSalaAlBuio.Stato.keys()[buio.stato], buio.acqua.call(&"in_giro")])
		"salvo":
			var via := (_p().global_position - q.global_position)
			via.y = 0
			_metti(_p().global_position + via.normalized() * 4.5, q.global_position)
			var ok2 := await _aspetta_fase(["SCENDE", "PRESA"], 10.0)
			print("BG: salvo: %s, fase %s, distanza dal punto %.2f m" % [ok2, AcquaDiLei.Fase.keys()[buio.acqua.fase],
					Vector2(_p().global_position.x - q.global_position.x, _p().global_position.z - q.global_position.z).length()])
			await _secondi(3.0)
		"getto":
			var viso: Node3D = buio.acqua.get(&"_viso")
			var t := Time.get_ticks_msec()
			Input.action_press(&"spray")
			var colpi := 0
			while Time.get_ticks_msec() - t < 6000 and AcquaDiLei.Fase.keys()[buio.acqua.fase] in ["ESCE", "SU"]:
				await get_tree().physics_frame
				if viso and is_instance_valid(viso):
					_guarda(viso.global_position)
			Input.action_release(&"spray")
			print("BG: getto: dopo %.2f s di getto fase %s, morendo %s, acqua nello zaino %.1f" % [(Time.get_ticks_msec() - t) / 1000.0,
					AcquaDiLei.Fase.keys()[buio.acqua.fase], GameState.is_dying, _p().water_pack.tank_amount if _p().water_pack else -1.0])
			await _secondi(3.0)


func _segna_originali_se_vuoto() -> void:
	pass


func _fossa(corre: bool, ferma := false) -> void:
	var ls := buio.lei_sbuca
	var f := ls.punto_sbuca.global_position
	var da := _p().global_position
	# a ovest della vasca grande (la strada vera dalla serranda all'area bimbi), poi verso la fossa
	var start := Vector3(-18.5, 0.0, 8.0)
	var tappe: Array = [Vector3(-18.5, 0.0, -3.5), Vector3(f.x, 0.0, f.z)]
	_metti(start, f + Vector3.UP * 0.5)
	await _secondi(1.0)
	print("BG: fossa: parto da %s (%.1f m dalla fossa), stato giro %s, LeiSbuca %s" % [_p().global_position.snappedf(0.01),
			AcquaDiLei._in_pianta(_p().global_position, f), LeiSalaAlBuio.Stato.keys()[buio.stato], LeiSbuca.Fase.keys()[ls.fase]])
	Input.action_press(&"move_forward")
	if corre:
		Input.action_press(&"sprint")
	var t := Time.get_ticks_msec()
	var finito_a := -1.0
	var lei_a := -1.0
	var ult := -1
	while Time.get_ticks_msec() - t < 12000:
		await get_tree().physics_frame
		var d := AcquaDiLei._in_pianta(_p().global_position, f)
		if tappe.size() > 1 and AcquaDiLei._in_pianta(_p().global_position, tappe[0]) < 0.7:
			tappe.pop_front()
		_guarda((tappe[0] as Vector3) + Vector3.UP * 1.4)
		if buio.stato == LeiSalaAlBuio.Stato.FINITO and finito_a < 0:
			finito_a = d
			print("BG: %.2f s giro finito col giocatore a %.2f m dalla fossa" % [_t(), d])
			if ferma:
				Input.action_release(&"move_forward")
				Input.action_release(&"sprint")
				var tf := Time.get_ticks_msec()
				var forte_g := -80.0
				while Time.get_ticks_msec() - tf < 6000:
					await get_tree().physics_frame
					_guarda(f + Vector3.UP * 0.8)
					if ls.fase != ult:
						ult = ls.fase
						print("BG: %.2f s LeiSbuca fase %s, giocatore a %.2f m dalla fossa" % [_t(), LeiSbuca.Fase.keys()[ls.fase], AcquaDiLei._in_pianta(_p().global_position, f)])
					if ls.fase == LeiSbuca.Fase.GUARDA:
						forte_g = maxf(forte_g, float(spia.call(&"adesso")[0]))
				print("BG: fermo a %.2f m: LeiSbuca %s, il canto più forte mentre guarda %.0f dB" % [AcquaDiLei._in_pianta(_p().global_position, f), LeiSbuca.Fase.keys()[ls.fase], forte_g])
				Input.action_press(&"move_forward")
				tappe = [Vector3(f.x, 0.0, f.z)]
				t = Time.get_ticks_msec()
		if ls.fase != ult:
			ult = ls.fase
			print("BG: %.2f s LeiSbuca fase %s, giocatore a %.2f m dalla fossa, medusa visibile %s" % [_t(), LeiSbuca.Fase.keys()[ls.fase], d, ls.medusa.visible])
		if d < (5.5 if ferma else 4.0):
			break
		if GameState.is_dying:
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	print("BG: fossa: fermo a %.2f m, LeiSbuca %s, morendo %s" % [AcquaDiLei._in_pianta(_p().global_position, f), LeiSbuca.Fase.keys()[ls.fase], GameState.is_dying])
	if GameState.is_dying:
		return
	await _secondi(1.0)
	# il getto sul viso di lei alla fossa
	Input.action_press(&"spray")
	t = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 5000 and (ls.fase == LeiSbuca.Fase.GUARDA or ls.fase == LeiSbuca.Fase.SBUCA):
		await get_tree().physics_frame
		var occhio: Vector3 = ls.medusa.call(&"get_eye_position") if ls.medusa.has_method(&"get_eye_position") else ls.medusa.global_position + Vector3.UP * 1.5
		_guarda(occhio)
	Input.action_release(&"spray")
	print("BG: %.2f s fossa: dopo il getto LeiSbuca %s" % [_t(), LeiSbuca.Fase.keys()[ls.fase]])
	t = Time.get_ticks_msec()
	var forte := -80.0
	while Time.get_ticks_msec() - t < 20000:
		await get_tree().physics_frame
		forte = maxf(forte, float(spia.call(&"adesso")[0]))
	print("BG: fossa: nei 20 s dopo, LeiSbuca %s, il canto più forte %.0f dB, stato giro %s, acqua abilitata %s" % [LeiSbuca.Fase.keys()[ls.fase], forte,
			LeiSalaAlBuio.Stato.keys()[buio.stato], buio.acqua.abilitata])


## Dopo la fossa (F9 Torre, o una morte dopo): la sala resta spenta. Il giocatore sul bordo di ogni punto, 15 s.
func _dopo_fossa() -> void:
	print("BG: dopo la fossa: stato %s, LeiSbuca %s, acqua abilitata %s" % [LeiSalaAlBuio.Stato.keys()[buio.stato],
			LeiSbuca.Fase.keys()[buio.lei_sbuca.fase], buio.acqua.abilitata])
	_metti(Vector3(-15.0, 0.0, 16.8), buio.vasca_grande.global_position)
	await _secondi(3.0)
	for k in 4:
		_metti(_bordo(k), buio.vasca_grande.global_position)
		var luce := 0
		var forte := -80.0
		var fasi := {}
		var t := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t < 15000:
			await get_tree().physics_frame
			var l: OmniLight3D = buio.acqua.get(&"_luce")
			if l and l.is_visible_in_tree() and l.light_energy > 0.01 and l.get_parent() == buio.acqua:
				luce += 1
			forte = maxf(forte, float(spia.call(&"adesso")[0]))
			fasi[AcquaDiLei.Fase.keys()[buio.acqua.fase]] = true
		print("BG: dopo la fossa, bordo %d: stato %s, fotogrammi con la luce della sala %d, canto più forte %.0f dB, fasi %s" % [k,
				LeiSalaAlBuio.Stato.keys()[buio.stato], luce, forte, fasi.keys()])


func _acquari() -> void:
	var level := get_tree().current_scene
	for nome in ["EnigmaAcquari", "PortoneTorre", "Portone"]:
		var n := level.find_child(nome, true, false) as Node3D
		if n == null:
			continue
		var pos := n.global_position
		if n is Node3D and nome == "EnigmaAcquari":
			# il primo figlio con una posizione (l'enigma può stare all'origine)
			for c in n.find_children("*", "Node3D", true, false):
				if (c as Node3D).global_position.length() > 1.0:
					pos = (c as Node3D).global_position
					break
		_metti(pos + Vector3(0, 0, 2.0), pos)
		spia.set(&"etichetta", "dopo la fossa, " + nome)
		var forte := -80.0
		var t := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t < 20000:
			await get_tree().physics_frame
			forte = maxf(forte, float(spia.call(&"adesso")[0]))
		print("BG: dopo la fossa vicino a %s (%s): in 20 s il canto più forte %.0f dB" % [nome, _p().global_position.snappedf(0.01), forte])


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	spia = preload("res://tests/collaudo/spia_canto.gd").new()
	get_tree().root.add_child.call_deferred(spia)
	var a := OS.get_cmdline_user_args()
	var scenari := (a[1] if a.size() > 1 else "partenza").split(",")
	var partenza := OS.get_environment("PARTENZA") if OS.get_environment("PARTENZA") != "" else "sala_buio"
	print("BG: F9 %s: %s" % [partenza, MenuProva.parti(get_tree(), partenza)])
	if not await _arriva(0):
		print("BG: non arrivato")
		Game.esci(1)
		return
	t0 = Time.get_ticks_msec()
	_prendi_livello()
	await _secondi(1.0)
	var sp := _p().global_position
	print("BG: arrivato, checkpoint %s, giocatore %s, luci %s; punti d'uscita %s; pelo vasca grande %.3f, fondo %.3f; fossa %s" % [
			GameState.snapshot.get("checkpoint", ""), sp.snappedf(0.01), GameState.luci,
			buio.acqua.punti_uscita.map(func(q): return q.global_position.snappedf(0.01)), buio.vasca_grande.get_surface_global_y(),
			buio.vasca_grande.get_floor_global_y(), buio.lei_sbuca.punto_sbuca.global_position.snappedf(0.01)])
	_segna_originali()
	_controlla_giocattoli("all'arrivo", null)
	for s in scenari:
		spia.set(&"etichetta", s)
		print("BG: ===== %s" % s)
		match s:
			"partenza":
				await _partenza()
			"bordo0", "bordo1", "bordo2", "bordo3":
				await _sul_bordo(int(s.substr(5)), "presa")
			"salvo":
				await _sul_bordo(0, "salvo")
			"getto":
				await _sul_bordo(0, "getto")
			"getto_su", "getto_su_0.2", "getto_su_0.4", "getto_esce_0.6", "getto_esce_1.0", "getto_esce_1.4", "getto_esce_1.8":
				await _sul_bordo(0, s)
			"dopo_fossa":
				await _dopo_fossa()
			"fossa_cammina":
				await _fossa(false)
			"fossa_corre":
				await _fossa(true)
			"fossa_ferma":
				await _fossa(false, true)
				await _acquari()
	spia.call(&"riassunto")
	print("BG: finito")
	Game.esci(0)
