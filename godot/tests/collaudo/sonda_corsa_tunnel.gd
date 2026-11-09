extends Node
## Ricontrollo dei passi lunghi del tunnel (#149, enigmi): la corsa intera nel tunnel nel gioco vero, senza schermo.
## Partenza F9 Inseguimento (il tunnel a pezzi nelle condotte; pronto, si fa finire SB1 con
## SalaPrincipale._attiva_sottomarino) o F9 Tunnel (il tunnel tutto insieme, dal checkpoint 6).
## Poi il giocatore va lungo tutta la strada (SalaSottomarino.punti_dove_si_cammina, ogni 3 m, un punto ogni 3
## fotogrammi di fisica: lei non lo prende), passa i checkpoint, muore due volte (dopo 100 m e dopo 300 m) e riparte dal
## checkpoint, arriva nella camera stagna e chiude il portello; poi la fine del capitolo e il ritorno al titolo.
## Stampa i checkpoint presi, le morti e le ripartenze (dove, il tunnel rifatto, quante luci e lampade), la torre
## liberata dopo la prima curva, la fine.
## Uso: godot --headless --path godot --script res://tests/run.gd -- <questo> <inseguimento|tunnel>

var _t0 := 0
var _presi: Array = []
var _fine_vista := false


func _fine() -> void:
	_fine_vista = true


func _ready() -> void:
	_run.call_deferred()


func _ora() -> float:
	return (Time.get_ticks_usec() - _t0) / 1e6


func _tunnel() -> Node:
	var s := get_tree().current_scene
	var t: Node = s.get(&"sala_sottomarino") if s and &"sala_sottomarino" in s else null
	return t if is_instance_valid(t) else null


func _in_gioco() -> bool:
	var p := GameState.player
	return p != null and is_instance_valid(p) and p.input_enabled and not GameState.is_dying


func _aspetta_gioco(massimo := 600.0) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < massimo * 1000.0:
		await get_tree().process_frame
		if _in_gioco():
			return true
	return false


func _conta(t: Node) -> String:
	var luci := t.find_children("*", "OmniLight3D", true, false)
	var tonde := 0
	for l in luci:
		if is_equal_approx((l as OmniLight3D).light_energy, 0.8) and is_equal_approx((l as OmniLight3D).omni_range, 12.0):
			tonde += 1
	return "%d nodi, %d luci omni (%d delle lampade tonde a energia 0,8 = 4 x 20%%), %d gommoni, %d gallerie" % [
			t.find_children("*", "", true, false).size(), luci.size(), tonde,
			t.find_children("Gommone_*", "", true, false).size(), t.find_children("*Galleria*", "", true, false).size()]


func _morte() -> void:
	var cp := String(GameState.snapshot.get("checkpoint", ""))
	print("CORSA %.2f s: MORTE a s %.0f (ultimo checkpoint %s)" % [_ora(), _s_giocatore(), cp])
	GameState.kill_player(&"collaudo")
	for i in 2:
		await get_tree().process_frame
	var seq: Node = GameState.get(&"_death_sequence")
	if is_instance_valid(seq):
		seq.emit_signal(&"finished", true)
	var ok := await _aspetta_gioco()
	for i in 20:
		await get_tree().process_frame
	var t := _tunnel()
	print("CORSA %.2f s: RIPARTENZA %s, checkpoint %s, giocatore a s %.1f, tunnel %s (%s), pronto %s, torre %s" % [_ora(), ok,
			GameState.snapshot.get("checkpoint", ""), _s_giocatore(), "costruito" if t and bool(t.get(&"costruita")) else "NO",
			_conta(t) if t else "-", AttesaZone.e_pronta(&"tunnel"), "c'è" if _torre() else "liberata"])


func _torre() -> Node:
	var s := get_tree().current_scene
	var t: Node = s.get(&"sala_torre") if s and &"sala_torre" in s else null
	return t if is_instance_valid(t) else null


func _s_giocatore() -> float:
	var t := _tunnel()
	if t == null or GameState.player == null:
		return -1.0
	return float((t.call(&"proietta", GameState.player.global_position) as Array)[0])


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var partenza := a[1] if a.size() > 1 else "tunnel"
	_t0 = Time.get_ticks_usec()
	MenuProva.parti(get_tree(), partenza)
	await _aspetta_gioco()
	var lt := Time.get_ticks_msec()
	while Time.get_ticks_msec() - lt < 600000:
		await get_tree().process_frame
		var tt := _tunnel()
		if tt and bool(tt.get(&"costruita")) and AttesaZone.e_pronta(&"tunnel"):
			break
	var t := _tunnel()
	print("CORSA %.2f s: %s, tunnel pronto: %s; checkpoint %s; torre %s" % [_ora(), partenza, _conta(t) if t else "NO",
			GameState.snapshot.get("checkpoint", ""), "c'è" if _torre() else "no"])
	if partenza == "inseguimento":
		# SB1 finito: il tunnel entra nel gioco
		get_tree().current_scene.call(&"_attiva_sottomarino")
		for i in 30:
			await get_tree().process_frame
	var morti := [100.0, 300.0]
	var i := 0
	var curva_vista := false
	while true:
		t = _tunnel()
		if t == null:
			print("CORSA: il tunnel non c'è più")
			break
		var punti: Array = t.call(&"punti_dove_si_cammina")
		if i >= punti.size():
			break
		var s_ora := float((t.call(&"proietta", punti[i]) as Array)[0])
		if not morti.is_empty() and s_ora > float(morti[0]):
			morti.pop_front()
			await _morte()
			# di nuovo dal punto più vicino alla ripartenza
			t = _tunnel()
			var sg := _s_giocatore()
			punti = t.call(&"punti_dove_si_cammina")
			i = 0
			while i < punti.size() and float((t.call(&"proietta", punti[i]) as Array)[0]) < sg:
				i += 1
			continue
		GameState.player.global_position = (punti[i] as Vector3) + Vector3.UP * 0.1
		GameState.player.velocity = Vector3.ZERO
		for k in 3:
			await get_tree().physics_frame
		var cp := String(GameState.snapshot.get("checkpoint", ""))
		if not _presi.has(cp):
			_presi.append(cp)
			print("CORSA %.2f s: checkpoint %s a s %.0f" % [_ora(), cp, s_ora])
		if not curva_vista and _torre() == null:
			curva_vista = true
			print("CORSA %.2f s: torre e condotte liberate a s %.0f" % [_ora(), s_ora])
		if GameState.is_dying:
			print("CORSA %.2f s: il giocatore muore da solo a s %.0f" % [_ora(), s_ora])
			await _aspetta_gioco()
		i += 1
	# nella camera stagna: il portello
	t = _tunnel()
	print("CORSA %.2f s: in fondo, giocatore a s %.1f; chiudo il portello" % [_ora(), _s_giocatore()])
	t.connect(&"fine_demo", _fine)
	t.call(&"chiudi_portello")
	var tf := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tf < 60000 and not _fine_vista:
		await get_tree().process_frame
	print("CORSA %.2f s: fine del tunnel (fine_demo) %s" % [_ora(), _fine_vista])
	tf = Time.get_ticks_msec()
	while Time.get_ticks_msec() - tf < 40000:
		await get_tree().process_frame
		if get_tree().current_scene and String(get_tree().current_scene.scene_file_path).contains("menu_principale"):
			break
	var al_titolo := get_tree().current_scene != null and String(get_tree().current_scene.scene_file_path).contains("menu_principale")
	print("CORSA %.2f s: RISULTATO %s: checkpoint presi %d %s, morti 2, al titolo %s" % [_ora(), partenza, _presi.size(), _presi, al_titolo])
	get_tree().quit(0)
