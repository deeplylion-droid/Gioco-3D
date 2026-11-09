extends Node
## Ricontrollo del lampo rosa (#131, lavoro/lampo-bacino) sui cinque casi del collaudo del fondo nero (enigmi). In più
## della sonda del fondo: quando il tunnel è costruito, quali mesh sono sullo strato del riscaldamento (13) dentro e fuori
## dal tunnel, e quali mesh del tunnel sullo strato 1 non ce l'hanno; e lo stato della luce rosa degli effetti.
## Base: collaudo finale 0.3.21 (enigmi): il fondo nero dietro la porta di servizio del bacino delle condotte
## (SalaInseguimento._fondo_porta, "FondoPortaServizio") nel gioco vero, senza schermo. Fotogramma per fotogramma:
## quanti fondi ci sono, se il tunnel è pronto (AttesaZone "tunnel"), se il tunnel c'è ed è costruito, se le condotte
## sono costruite e visibili, se c'è il giocatore coi comandi. Conta i fotogrammi "vuoto" (condotte visibili col
## giocatore, tunnel non pronto e nessun fondo), "nero sopra il tunnel" (fondo col tunnel pronto) e i doppioni.
## Casi: f9 (partenza Inseguimento del menu di prova), morte (una morte nelle condotte), due_morti (due di fila, la
## seconda appena ricompare), continua (Continua dal titolo con l'istantanea "inseguimento"), torre (Continua dalla
## torre e poi subito al bacino).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_lampo_casi.gd <caso>

const TITOLO := "res://scenes/ui/menu_principale.tscn"
const TEMPORANEO := GameState.SAVE_PATH + ".tmp"
const VANO := Vector3(40.4, -28.925, -5.0)

var _t0 := 0
var _stato := ""
var _vuoto := 0
var _vuoto_t := []
var _nero_sopra := 0
var _doppioni := 0
var _max_fondi := 0
var _comparsi := 0
var _tolti := 0
var _ultimo_fondo := false
var _fase := ""
var _tunnel_visti := {}
var _luce_stato := ""
var _strati_ok := 0
var _strati_ko := 0


func _strati(tun: Node3D) -> void:
	# una volta per tunnel costruito: le mesh sullo strato del riscaldamento, dentro e fuori dal tunnel
	var dentro := 0
	var fuori := []
	var senza := []
	var tutte := 0
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var nel := tun.is_ancestor_of(g)
		if nel and g.layers & 1:
			tutte += 1
		if g.layers & EffettiInseguimento.STRATO_RISCALDA:
			if nel:
				dentro += 1
			else:
				fuori.append(str(g.get_path()))
		elif nel and g.layers & 1:
			senza.append(str(g.get_path()))
	if fuori.is_empty() and senza.is_empty():
		_strati_ok += 1
	else:
		_strati_ko += 1
	print("STRATI %s %.2f s: tunnel costruito; sullo strato 13: %d mesh del tunnel (su %d sullo strato 1), %d fuori dal tunnel %s; del tunnel sullo strato 1 senza il 13: %d %s" % [
			_fase, _ora(), dentro, tutte, fuori.size(), fuori.slice(0, 5), senza.size(), senza.slice(0, 5)])


func _ready() -> void:
	_run.call_deferred()


func _ora() -> float:
	return (Time.get_ticks_usec() - _t0) / 1e6


func _ins() -> Node3D:
	var s := get_tree().current_scene
	if s == null:
		return null
	return s.get_node_or_null(^"SalaTorre/SalaInseguimento") as Node3D


func _fondi() -> Array:
	return get_tree().root.find_children("FondoPortaServizio", "", true, false)


func _fotogramma() -> void:
	var s := get_tree().current_scene
	var ins := _ins()
	var fondi := _fondi()
	var n := fondi.size()
	_max_fondi = maxi(_max_fondi, n)
	if n > 1:
		_doppioni += 1
	var fondo_vis := n > 0 and (fondi[0] as Node3D).is_visible_in_tree()
	var pronta := AttesaZone.e_pronta(&"tunnel")
	var tun: Node3D = s.get(&"sala_sottomarino") if s and &"sala_sottomarino" in s else null
	var tun_c := is_instance_valid(tun) and bool(tun.get(&"costruita"))
	var tun_v := is_instance_valid(tun) and tun.is_visible_in_tree()
	var ins_c := is_instance_valid(ins) and bool(ins.get(&"costruita"))
	var ins_v := is_instance_valid(ins) and ins.is_visible_in_tree()
	var p := GameState.player
	var gioca := p != null and is_instance_valid(p) and p.input_enabled and not GameState.is_dying
	if tun_c and not _tunnel_visti.has(tun.get_instance_id()):
		_tunnel_visti[tun.get_instance_id()] = true
		_strati(tun)
	var e: EffettiInseguimento = tun.get(&"effetti") if is_instance_valid(tun) else null
	var ls := "-"
	if e and is_instance_valid(e) and e.luce:
		ls = "accesa %s, maschera %d, nebbia %.2f, riscalda %s" % [e.luce.visible, e.luce.light_cull_mask, e.luce.light_volumetric_fog_energy, e.get(&"_riscalda")]
	if ls != _luce_stato:
		print("LUCE %s %.2f s: %s" % [_fase, _ora(), ls])
		_luce_stato = ls
	if fondo_vis and not _ultimo_fondo:
		_comparsi += 1
	if not fondo_vis and _ultimo_fondo:
		_tolti += 1
	_ultimo_fondo = fondo_vis
	# il vano si vede (condotte visibili, col giocatore) e dietro non c'è né il fondo né il tunnel pronto
	if ins_v and p != null and is_instance_valid(p) and not fondo_vis and not pronta:
		_vuoto += 1
		if _vuoto_t.size() < 5:
			_vuoto_t.append(snappedf(_ora(), 0.01))
	if fondo_vis and pronta:
		_nero_sopra += 1
	var st := "scena %s, condotte %s%s, fondi %d%s, tunnel %s%s%s, pronto %s, giocatore %s" % [
			s.name if s else "-", "costruite" if ins_c else ("in costruzione" if is_instance_valid(ins) else "no"),
			" visibili" if ins_v else "", n, " visibile" if fondo_vis else "",
			"c'è" if is_instance_valid(tun) else "no", " costruito" if tun_c else "", " visibile" if tun_v else "",
			"sì" if pronta else "no", "coi comandi" if gioca else ("c'è" if p != null and is_instance_valid(p) else "no")]
	if st != _stato:
		var dove := ""
		if n > 0:
			dove = " (fondo in %s)" % (fondi[0] as Node3D).global_position.snapped(Vector3.ONE * 0.001)
		print("FONDO %s %.2f s: %s%s" % [_fase, _ora(), st, dove])
		_stato = st


func _aspetta(secondi: float, finche := Callable()) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < secondi * 1000.0:
		await get_tree().process_frame
		if finche.is_valid() and not finche.call():
			return


func _stabile() -> bool:
	# finché il tunnel non è pronto, o c'è ancora un fondo
	return not AttesaZone.e_pronta(&"tunnel") or not _fondi().is_empty() or GameState.player == null


func _morte() -> void:
	GameState.kill_player(&"collaudo")
	for i in 2:
		await get_tree().process_frame
	var seq: Node = GameState.get(&"_death_sequence")
	if is_instance_valid(seq):
		seq.emit_signal(&"finished", true)
	# fino al giocatore nuovo
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 120000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p.input_enabled and not GameState.is_dying:
			break


func _continua(id: String) -> void:
	var d := MenuProva.istantanea(id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMPORANEO))
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	get_tree().change_scene_to_file(TITOLO)
	for i in 20:
		await get_tree().process_frame
	var t := get_tree().current_scene
	print("FONDO: dal titolo, Continua da %s (%s)" % [id, d.get("checkpoint", "")])
	(t.call(&"voci")[0] as Button).pressed.emit()


func _vista_dal(occhio: Vector3, nome: String) -> void:
	# dal punto di ripartenza: si vede il vano? (raggi sulle collisioni verso 9 punti del vano, 2 cm davanti al muro)
	var w := get_viewport().find_world_3d()
	var visti := 0
	for dz in [-0.6, 0.0, 0.6]:
		for dy in [-0.9, 0.0, 0.9]:
			var q := PhysicsRayQueryParameters3D.create(occhio, VANO + Vector3(0.02, dy, dz))
			if GameState.player:
				q.exclude = [GameState.player.get_rid()]
			if w.direct_space_state.intersect_ray(q).is_empty():
				visti += 1
	print("FONDO: da %s (occhi in %s, a %.1f m dal vano) si vedono %d punti del vano su 9" % [nome, occhio.snapped(Vector3.ONE * 0.01), occhio.distance_to(VANO), visti])


func _al_bacino() -> void:
	var cp := _ins().find_child("Checkpoint_bacino", true, false) as Checkpoint
	GameState.reach_checkpoint(cp)
	print("FONDO %s: raggiunto %s (salvataggio su disco: %s)" % [_fase, GameState.persist_key(cp), GameState.salvataggio().get("checkpoint", "")])


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = true
	var a := OS.get_cmdline_user_args()
	var caso := a[1] if a.size() > 1 else "f9"
	_t0 = Time.get_ticks_usec()
	get_tree().process_frame.connect(_fotogramma)
	_fase = caso
	match caso:
		"f9", "morte", "due_morti":
			MenuProva.parti(get_tree(), "inseguimento")
		"continua":
			# nelle condotte fino al checkpoint del bacino (scritto su disco), poi il titolo e Continua
			MenuProva.parti(get_tree(), "inseguimento")
			var t1 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t1 < 300000:
				await get_tree().process_frame
				var p1 := GameState.player
				if p1 and is_instance_valid(p1) and p1.input_enabled and not GameState.is_dying and _ins() != null:
					break
			await _aspetta(60.0, _stabile)
			await _al_bacino()
			get_tree().change_scene_to_file(TITOLO)
			for i in 20:
				await get_tree().process_frame
			_fase = "continua_dal_titolo"
			print("FONDO: dal titolo, Continua (%s)" % GameState.salvataggio().get("checkpoint", ""))
			(get_tree().current_scene.call(&"voci")[0] as Button).pressed.emit()
		"torre":
			await _continua("torre")
	# fino al giocatore coi comandi
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 300000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p.input_enabled and not GameState.is_dying and _ins() != null:
			break
	print("FONDO %s: si gioca a %.2f s (checkpoint %s)" % [caso, _ora(), GameState.snapshot.get("checkpoint", "")])
	if GameState.player:
		_vista_dal(GameState.player.get_eye_position(), "dove si riparte")
	if caso == "torre":
		# dalla torre subito al bacino: il giocatore portato al checkpoint del bacino
		var cps := _ins().find_children("Checkpoint_*", "", true, false)
		var bacino: Node3D = null
		for c in cps:
			if String(c.name).to_lower().contains("bacino"):
				bacino = c
		if bacino == null and not cps.is_empty():
			bacino = cps[cps.size() - 1]
		print("FONDO torre: checkpoint delle condotte %s; porto il giocatore a %s" % [cps.map(func(c): return String(c.name)), bacino.name if bacino else "-"])
		if bacino:
			_fase = "torre_al_bacino"
			GameState.player.global_position = (bacino as Checkpoint).get_spawn_transform().origin
			await get_tree().physics_frame
			_vista_dal(GameState.player.get_eye_position(), "bacino")
	await _aspetta(60.0, _stabile)
	await _aspetta(2.0)
	if caso == "morte" or caso == "due_morti":
		await _al_bacino()
		_fase = "morte1"
		await _morte()
		print("FONDO morte1: di nuovo in gioco a %.2f s (checkpoint %s)" % [_ora(), GameState.snapshot.get("checkpoint", "")])
		_vista_dal(GameState.player.get_eye_position(), "dove si riparte")
		if caso == "due_morti":
			_fase = "morte2"
			await _morte()
			print("FONDO morte2: di nuovo in gioco a %.2f s" % _ora())
		await _aspetta(60.0, _stabile)
		await _aspetta(2.0)
	print("STRATI %s: RISULTATO tunnel costruiti %d, giusti %d, sbagliati %d" % [caso, _tunnel_visti.size(), _strati_ok, _strati_ko])
	print("FONDO %s: RISULTATO fotogrammi col vuoto %d %s, col nero sopra il tunnel pronto %d (%.2f s a 60/s), fondi al massimo %d, fotogrammi con doppioni %d, fondo comparso %d volte e tolto %d" % [
			caso, _vuoto, _vuoto_t, _nero_sopra, _nero_sopra / 60.0, _max_fondi, _doppioni, _comparsi, _tolti])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	get_tree().quit(0)
