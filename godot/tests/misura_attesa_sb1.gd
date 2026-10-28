extends Node
## Misura (richiesta del coordinatore, 25 ottobre): su ogni strada che porta a SB1, quanto dopo l'arrivo il tunnel è
## pronto (AttesaZone "tunnel"): SB1 aspetta solo se ci si arriva prima. Le strade: dal titolo (sala, torre,
## inseguimento), dalle partenze F9 "inseguimento" e "tunnel", dalla ripartenza dopo una morte nell'inseguimento.
## A tempo vero (senza --fixed-fps), come il thread.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/misura_attesa_sb1.gd

const LEVEL := "res://scenes/sala_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _aspetta_giocatore(vecchio: Node = null) -> float:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p != vecchio and p.is_inside_tree() and get_tree().current_scene \
				and get_tree().current_scene.scene_file_path == LEVEL:
			break
	return (Time.get_ticks_msec() - t0) / 1000.0


## Secondi dall'arrivo a quando il tunnel è pronto (-1: mai entro 180 s).
func _tunnel_pronto() -> float:
	var t0 := Time.get_ticks_msec()
	while not AttesaZone.passaggio_aperto(&"tunnel"):
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > 180000:
			return -1.0
	return (Time.get_ticks_msec() - t0) / 1000.0


func _run() -> void:
	Game.pause_on_focus_loss = false
	print("1. Dal titolo: sala, acquari, torre")
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	await _aspetta_giocatore()
	var level := get_tree().current_scene
	var enigma := level.get_node_or_null(^"Gioco/EnigmaAcquari")
	if enigma:
		enigma.emit_signal(&"comparso")
	await get_tree().process_frame
	(level.get(&"portone") as PortoneTorre).apri_quando_pronta()
	var t0 := Time.get_ticks_msec()
	while level.get(&"sala_torre") == null or not (level.get(&"sala_torre") as Node3D).visible:
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > 180000:
			break
	print("MISURA sala: torre visibile dopo %.1f s; tunnel pronto %.1f s dopo" % [(Time.get_ticks_msec() - t0) / 1000.0, await _tunnel_pronto()])

	for id in ["inseguimento", "tunnel"]:
		print("2. Partenza F9 %s" % id)
		var vecchio := GameState.player
		MenuProva.parti(get_tree(), id)
		var arrivo := await _aspetta_giocatore(vecchio)
		print("MISURA F9 %s: sala pronta dopo %.1f s; tunnel pronto %.1f s dopo l'arrivo" % [id, arrivo, await _tunnel_pronto()])
		if id == "inseguimento":
			print("3. Ripartenza dopo una morte nell'inseguimento")
			vecchio = GameState.player
			GameState.kill_player()
			var di_nuovo := await _aspetta_giocatore(vecchio)
			print("MISURA ripartenza inseguimento: sala di nuovo dopo %.1f s; tunnel pronto %.1f s dopo" % [di_nuovo, await _tunnel_pronto()])
			print("4. Ripartenza dal checkpoint del bacino, il più vicino a SB1, e SB1 subito")
			var ins: SalaInseguimento = get_tree().current_scene.find_child("SalaInseguimento", true, false)
			var cp: Node3D = ins.find_child("Checkpoint_bacino", true, false)
			GameState.player.teleport(cp.global_position + Vector3.UP * 0.3)
			for i in 30:
				await get_tree().physics_frame
			print("   checkpoint: %s" % GameState.snapshot.get("checkpoint", ""))
			vecchio = GameState.player
			GameState.kill_player()
			di_nuovo = await _aspetta_giocatore(vecchio)
			var t_arrivo := Time.get_ticks_msec()
			ins = get_tree().current_scene.find_child("SalaInseguimento", true, false)
			for i in 400:
				if GameState.player.input_enabled:
					break
				await get_tree().process_frame
			var sc: Dictionary = ins.dati["scale"][ins.dati["scale"].size() - 1]
			var piede := SalaInseguimento.b([float(sc["x"]), float(sc["y"]), float(sc["z0"])])
			var finito := [false]
			ins.sb1_finito.connect(func(): finito[0] = true)
			var attesa := [0.0]
			var t_attesa := [0]
			ins.sb1_in_attesa.connect(func(): t_attesa[0] = Time.get_ticks_msec())
			ins.cala_grata()
			GameState.player.teleport(piede + Vector3(3.0, 0.3, 0.0))
			await get_tree().process_frame
			ins.inizia_sb1()
			var t1 := Time.get_ticks_msec()
			while not finito[0] and Time.get_ticks_msec() - t1 < 120000:
				await get_tree().process_frame
			if t_attesa[0] > 0:
				attesa[0] = (Time.get_ticks_msec() - t_attesa[0]) / 1000.0
			print("MISURA SB1 subito dopo la ripartenza al bacino: SB1 iniziato %.1f s dopo l'arrivo, finito in %.1f s, di cui attesa del tunnel %.1f s" % [(t1 - t_arrivo) / 1000.0, (Time.get_ticks_msec() - t1) / 1000.0, attesa[0]])
	Game.esci(0)
