extends Node
## La fine vera della demo, in fondo all'inseguimento (SB1): il nero dell'inseguimento (SalaInseguimento._nero, livello
## 80), la scritta "FINE DELLA DEMO" sopra il nero (l'HUD la mette su un livello suo, 90, sotto il menu di pausa a 100;
## prima stava sotto il nero e non si vedeva: collaudo della v0.3.13), e finita la scritta il gioco torna da solo al
## titolo (scelta 12A dell'utente, 24 ottobre). Il tempo della scritta si ferma con la pausa, e il ritorno al titolo
## non scatta una seconda volta.
## Con FINE_SCATTO=<file.jpg> (e un renderer vero) salva lo schermo col nero e la scritta.
## Con FINE_TUNNEL=1 la fine è quella del tunnel del viaggio sottomarino (il portello chiuso, lo schianto, il nero).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_fine_titolo.gd

const SALA := "res://scenes/sala_principale.tscn"

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	# per lo scatto: il 3D non si disegna (il nero lo copre tutto; così sala e torre non riempiono la memoria del
	# renderer software), il 2D sì
	if OS.get_environment("FINE_SCATTO") != "":
		get_viewport().disable_3d = true
		# e senza le parti grandi della sala, che il nero copre comunque (la sala intera con la torre supera la memoria)
		var lv := (load(SALA) as PackedScene).instantiate()
		for percorso in ["Interni", "Piscina", "Vasche", "Vasca", "BambiniBalconata", "Tecnici", "Risalita", "Sala"]:
			var n := lv.get_node_or_null(NodePath(percorso))
			if n:
				n.get_parent().remove_child(n)
				n.free()
		get_tree().root.add_child(lv)
		get_tree().current_scene = lv
	else:
		get_tree().change_scene_to_file(SALA)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene
	check(level != null and level.has_method(&"_on_fine_torre"), "la sala principale è caricata")
	var nero: CanvasLayer = null
	if OS.get_environment("FINE_SCATTO") != "":
		# per lo scatto la torre no (sul renderer software non entra nella memoria): lo stesso nero di
		# SalaInseguimento._nero (un CanvasLayer al livello 80 con un ColorRect nero pieno) e la stessa fine del capitolo
		nero = CanvasLayer.new()
		nero.layer = 80
		var r := ColorRect.new()
		r.color = Color(0, 0, 0, 1)
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		nero.add_child(r)
		level.add_child(nero)
		level.call(&"_on_fine_torre")
		await _secondi(1.0)
	else:
		# come nel gioco: alla torre si arriva col blackout, il portone la fa caricare
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
		(level.get(&"portone") as Node).call(&"apri")
		var t0 := Time.get_ticks_msec()
		while level.get(&"sala_torre") == null and Time.get_ticks_msec() - t0 < 120000:
			await get_tree().process_frame
		var torre: Node = level.get(&"sala_torre")
		check(torre != null, "la torre è caricata")
		if torre == null:
			_fine()
			return
		if torre.get(&"inseguimento") == null:
			torre.call(&"_aggiungi_inseguimento")
		var ins: Node = torre.get(&"inseguimento")
		check(ins != null and ins.has_method(&"_nero"), "c'è l'inseguimento")
		if ins == null:
			_fine()
			return
		await _secondi(1.0)
		if OS.get_environment("FINE_TUNNEL") != "":
			# la fine nel tunnel del viaggio sottomarino: si chiude il portello, lei ci sbatte, il nero del tunnel
			level.call(&"_metti_sottomarino", load(level.get(&"sala_sottomarino_scena")) as PackedScene, false)
			var tunnel: Node = level.get(&"sala_sottomarino")
			check(tunnel != null, "c'è il tunnel")
			tunnel.call(&"chiudi_portello")
			var t1 := Time.get_ticks_msec()
			while not bool(level.get(&"demo_finished")) and Time.get_ticks_msec() - t1 < 30000:
				await get_tree().process_frame
			check(bool(level.get(&"demo_finished")), "il portello chiuso e lo schianto finiscono la demo")
			await _secondi(1.5)      # (come dopo il nero dell'inseguimento: i tempi della scritta sotto contano da qui)
			for c in tunnel.get_children():
				if c is CanvasLayer:
					nero = c
		else:
			# la fine vera: Jilly ti guarda, il nero, la fine del capitolo
			ins.call(&"_nero")
			await _secondi(2.5)
			check(bool(level.get(&"demo_finished")), "il nero dell'inseguimento finisce il capitolo (la demo)")
			for c in ins.get_children():
				if c is CanvasLayer:
					nero = c
		var rect := nero.get_child(0) as ColorRect if nero else null
		check(rect != null and rect.color.a > 0.99 and rect.is_visible_in_tree(), "lo schermo è nero (livello %d)" % (nero.layer if nero else -1))
	var hud = level.call(&"_hud")
	var strato: CanvasLayer = hud.get(&"strato_scritta") if hud else null
	var scritta: Label = hud.call(&"banner_label") if hud else null
	check(strato != null and nero != null and strato.layer > nero.layer and strato.layer < 100 and strato.visible,
		"la scritta sta sopra il nero e sotto il menu di pausa (livello %d)" % (strato.layer if strato else -1))
	check(scritta != null and scritta.is_visible_in_tree() and scritta.modulate.a > 0.9 and scritta.text.begins_with("FINE DELLA DEMO"),
		"la scritta si vede: «%s»" % (scritta.text.replace("\n", " / ") if scritta else ""))
	check(hud != null and (hud as CanvasLayer).layer < nero.layer, "il resto dell'interfaccia (mirino, zaino, messaggi) resta sotto il nero")
	var file := OS.get_environment("FINE_SCATTO")
	if file != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(file, 0.9)
		# (il ritorno al titolo col renderer software e la sala ancora in memoria non ci sta: lo controlla il giro senza schermo)
		_fine()
		return
	# in pausa il tempo della scritta si ferma
	Game.set_paused(true)
	for i in 60 * 8:
		await get_tree().process_frame
	check(get_tree().current_scene == level, "in pausa non torna al titolo")
	Game.set_paused(false)
	await _secondi(3.0)
	check(get_tree().current_scene == level, "a 5 s di scritta è ancora la fine della demo")
	await _secondi(6.0)
	var titolo := get_tree().current_scene
	check(titolo != null and titolo.scene_file_path == Game.SCENE_TITLE, "finita la scritta, torna da solo al titolo (%s)" % (titolo.scene_file_path if titolo else "niente"))
	await _secondi(10.0)
	check(get_tree().current_scene == titolo, "e non ci torna una seconda volta")
	_fine()


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)
