extends Node
## Collaudo 0.4.0, zona A (la lezione nella sala pompe), senza schermo, col gioco vero: F9 «Sala pompe», le tre pompe
## nell'ordine (Risveglio._turbina_accesa), la leva (tirata). Poi ogni 0,1 s (LP:) la luce di lei (fase, giro, dove
## sta nella vasca, energia, portata, visibile), il canto (CantoPrima: fase, chi segue, volumi) e il giocatore. Per
## ogni fotogramma controlla che la luce accesa stia dentro la vasca di raccolta (pianta e sotto il pelo). Alla fine:
## chi tiene lei e la luce. Poi muore, riparte dal checkpoint del risveglio e guarda 25 s: la lezione non si rifà.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/lezione_pompe.gd [x,y,z del giocatore|spawn|leva]

var spia: Node


func _ready() -> void:
	_run.call_deferred()


func _secondi(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await get_tree().process_frame


func _arriva(vecchio: int) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 600000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		var p := GameState.player
		if s and String(s.name) != "Caricamento" and p and is_instance_valid(p) and p.get_instance_id() != vecchio \
				and p.is_inside_tree() and not GameState.is_dying and not GameState.is_restoring():
			return true
	return false


func _stato(level: Node, risv: Node, vasca: WaterTank, tag: String, t: float) -> String:
	var acq: Node = risv.get(&"acqua_lezione")
	var cp = get_node(^"/root/Audio").get(&"canto_prima")
	var luce := _luce_statica()
	var l := "-"
	if luce and is_instance_valid(luce) and luce.is_inside_tree():
		var loc := vasca.to_local(luce.global_position)
		l = "luce vis %s en %.2f portata %.1f in vasca locale %s (pelo-y %.2f), padre %s" % [luce.is_visible_in_tree(), luce.light_energy,
				luce.omni_range, loc.snappedf(0.01), vasca.get_surface_global_y() - luce.global_position.y, luce.get_parent().name]
	var c := "-"
	if cp:
		c = "canto fase %s lei %s mix %.2f lon %s vic %s" % [cp.get(&"fase"), cp.get(&"lei").name if is_instance_valid(cp.get(&"lei")) else "-",
				float(cp.get(&"mix")), _vol(cp.get(&"lon")), _vol(cp.get(&"vic"))]
	var a := "-"
	if acq and is_instance_valid(acq):
		a = "fase %s fc %s giro %s vic %.2f" % [AcquaDiLei.Fase.keys()[int(acq.get(&"fase"))], acq.get(&"fase_canto"), acq.call(&"in_giro"), float(acq.get(&"vicinanza"))]
	return "LP: %s %.1f s: %s; %s; %s; in corso %s; sente %s" % [tag, t, a, l, c, risv.get(&"lezione_in_corso"), spia.call(&"adesso")]


var _ult_cond := ""


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


func _vol(p) -> String:
	if p == null or not is_instance_valid(p) or not p.get(&"playing"):
		return "zitto"
	return "%.0f dB" % float(p.get(&"volume_db"))


func _luce_statica() -> OmniLight3D:
	# le static var si leggono da un'istanza qualsiasi
	for n in get_tree().get_nodes_in_group(&"lei_nell_acqua"):
		return n.get(&"_luce") as OmniLight3D
	return null


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	spia = preload("res://tests/collaudo/spia_canto.gd").new()
	get_tree().root.add_child.call_deferred(spia)
	var a := OS.get_cmdline_user_args()
	var dove := a[1] if a.size() > 1 else "spawn"
	print("LP: F9 sala_pompe: %s" % MenuProva.parti(get_tree(), "sala_pompe"))
	if not await _arriva(0):
		print("LP: non arrivato")
		Game.esci(1)
		return
	await _secondi(2.0)
	var level := get_tree().current_scene
	var risv := level.get_node(^"Tecnici/Logica/SalaPompe/Risveglio")
	var vasca: WaterTank = risv.get(&"vasca")
	var p := GameState.player as Node3D
	var leva: Node3D = risv.get(&"leva")
	print("LP: arrivato, checkpoint %s, giocatore %s, luci %s" % [GameState.snapshot.get("checkpoint", ""), p.global_position.snappedf(0.01), GameState.luci])
	print("LP: vasca %s in %s, base %s, interno %s, pelo %.3f, fondo %.3f; leva %s; porta %s" % [vasca.get_path(), vasca.global_position.snappedf(0.01),
			vasca.global_basis.get_euler().snappedf(0.01), vasca.inner_size, vasca.get_surface_global_y(), vasca.get_floor_global_y(),
			leva.global_position.snappedf(0.01) if leva else null, (risv.get(&"porta") as Node3D).global_position.snappedf(0.01)])
	for i in (risv.get(&"turbine") as Array).size():
		print("LP: turbina %d in %s" % [i, (risv.get(&"turbine")[i] as Node3D).global_position.snappedf(0.01)])
	if dove == "leva" and leva:
		var v := vasca.global_position
		p.global_position = leva.global_position + (Vector3(v.x, leva.global_position.y, v.z) - leva.global_position).normalized() * 2.5
	elif dove.count(",") == 2:
		var k := dove.split(",")
		p.global_position = Vector3(float(k[0]), float(k[1]), float(k[2]))
	if OS.get_environment("GUARDA_LEVA") == "1" and leva:
		var d := leva.global_position - p.global_position
		(p as Player).set_look(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	elif OS.get_environment("GUARDA_VASCA") == "1":
		var d2 := vasca.global_position - p.global_position
		(p as Player).set_look(atan2(-d2.x, -d2.z), atan2(d2.y + 1.0, Vector2(d2.x, d2.z).length()))
	await _secondi(1.0)
	var cam0 := get_viewport().get_camera_3d()
	print("LP: camera in %s guarda %s" % [cam0.global_position.snappedf(0.01), (-cam0.global_basis.z).snappedf(0.01)])
	print("LP: giocatore per la leva in %s" % p.global_position.snappedf(0.01))
	spia.set(&"etichetta", "lezione")
	for i in 3:
		risv.call(&"_turbina_accesa", i)
		await _secondi(0.5)
	print("LP: avviate %d, leva sbloccata %s" % [risv.get(&"avviate"), leva.get(&"sbloccata")])
	leva.call(&"tira")
	var t0 := Time.get_ticks_msec()
	var prossimo := 0.0
	var fuori := 0
	var accesi := 0
	var max_sopra := -INF
	var max_fuori_pianta := -INF
	var visto_giro := false
	while Time.get_ticks_msec() - t0 < 26000:
		await get_tree().physics_frame
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		var luce := _luce_statica()
		if luce and is_instance_valid(luce) and luce.is_visible_in_tree() and luce.light_energy > 0.01:
			accesi += 1
			var loc := vasca.to_local(luce.global_position)
			var h := vasca.inner_size * 0.5
			var fp := maxf(absf(loc.x) - h.x, absf(loc.z) - h.z)
			max_fuori_pianta = maxf(max_fuori_pianta, fp)
			max_sopra = maxf(max_sopra, luce.global_position.y - vasca.get_surface_global_y())
			if fp > 0.0 or luce.global_position.y > vasca.get_surface_global_y() or luce.global_position.y < vasca.get_floor_global_y():
				fuori += 1
		var acq: Node = risv.get(&"acqua_lezione")
		if acq and acq.call(&"in_giro"):
			visto_giro = true
		var cond := _condizioni(acq)
		if cond != _ult_cond:
			_ult_cond = cond
			print("LP: %.2f s condizioni: %s" % [t, cond])
		if t >= prossimo:
			prossimo += 0.1 if (acq and acq.call(&"in_giro")) else 0.5
			print(_stato(level, risv, vasca, "lezione", t))
	print("LP: luce accesa %d fotogrammi, fuori dalla vasca %d; il più fuori in pianta %.3f m (negativo: dentro), il più alto %.3f m dal pelo; giro visto %s; lezione fatta %s, in corso %s" % [
			accesi, fuori, max_fuori_pianta, max_sopra, visto_giro, risv.get(&"lezione_fatta"), risv.get(&"lezione_in_corso")])
	var acq: Node = risv.get(&"acqua_lezione")
	var lei_s: Node = acq.get(&"_lei") if acq else null
	var prop: Node = acq.get(&"_proprietaria") if acq else null
	var luce := _luce_statica()
	print("LP: dopo: proprietaria %s, lei %s (padre %s, visibile %s), luce padre %s visibile %s, fase %s, fase_canto %s" % [prop.get_path() if prop else null,
			lei_s != null and is_instance_valid(lei_s), lei_s.get_parent().get_path() if lei_s and is_instance_valid(lei_s) and lei_s.get_parent() else null,
			lei_s.is_visible_in_tree() if lei_s and is_instance_valid(lei_s) and lei_s.is_inside_tree() else null,
			luce.get_parent().get_path() if luce and is_instance_valid(luce) and luce.get_parent() else null, luce.visible if luce and is_instance_valid(luce) else null,
			AcquaDiLei.Fase.keys()[int(acq.get(&"fase"))], acq.get(&"fase_canto")])
	for n in get_tree().get_nodes_in_group(AcquaDiLei.LEI_IN_SCENA):
		print("LP: in scena: %s" % n.get_path())
	print("LP: checkpoint adesso %s" % GameState.snapshot.get("checkpoint", ""))
	spia.call(&"riassunto")
	# morte e ripartenza dal checkpoint del risveglio
	spia.set(&"etichetta", "dopo la morte")
	var v := p.get_instance_id()
	GameState.kill_player(&"prova")
	await _arriva(v)
	level = get_tree().current_scene
	risv = level.get_node(^"Tecnici/Logica/SalaPompe/Risveglio")
	vasca = risv.get(&"vasca")
	print("LP: ripartito: checkpoint %s, giocatore %s, luci %s, finito %s, lezione fatta %s" % [GameState.snapshot.get("checkpoint", ""),
			GameState.player.global_position.snappedf(0.01), GameState.luci, risv.get(&"finito"), risv.get(&"lezione_fatta")])
	t0 = Time.get_ticks_msec()
	accesi = 0
	prossimo = 0.0
	while Time.get_ticks_msec() - t0 < 25000:
		await get_tree().physics_frame
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		var luce2 := _luce_statica()
		if luce2 and is_instance_valid(luce2) and luce2.is_visible_in_tree() and luce2.light_energy > 0.01:
			accesi += 1
		if t >= prossimo:
			prossimo += 2.5
			print(_stato(level, risv, vasca, "dopo la morte", t))
	print("LP: dopo la ripartenza: luce accesa %d fotogrammi" % accesi)
	spia.call(&"riassunto")
	print("LP: finito")
	Game.esci(0)
