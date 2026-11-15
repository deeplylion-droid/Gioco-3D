extends "res://tests/collaudo/sonda_portone.gd"
## Collaudo del portone della torre col renderer vero: la sala ridotta (senza interni, tecnici, risalita e i pezzi che
## qui non si vedono: col renderer vero la sala intera non sta in memoria) col mondo fatto fino al portone aperto, come
## test_portone_torre. Entrati camminando, ci si gira e si torna piano contro la soglia per tutta la chiusura: uno scatto
## dagli occhi ogni 0,2 s; poi, a portone chiuso, appoggiati alla soglia guardando dritto, in basso, agli spigoli; un
## passo indietro e l'anta chiusa. (Gli ambienti qui non ci sono: lo scarico lo prova sonda_portone senza schermo.)
## Uso: xvfb-run -a -s "-screen 0 800x450x24" godot --path godot --rendering-driver vulkan --resolution 800x450 \
##        --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_portone_scatti.gd scatti <cartella>

const TOGLI := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Sala/Dettagli", "Gioco/EnigmaAcquari", "Atmosfera", "Polaroid", "Vasche", "Piscina", "Vasca",
		"Sala/Piscina", "Sala/VascaCentrale", "Sala/Cupola", "Sala/AreaBimbi", "Sala/Oggetti", "Sala/TorreScivoli"]
var cart := ""
var _n := 0


func _run() -> void:
	OS.add_logger(_errori)
	_errori.attivo = true
	cart = OS.get_cmdline_user_args()[2]
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("basso")
	GameState.save_to_disk = false
	await _prepara()
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	await _scatto("davanti_al_portone")
	await _cammina(EST, 4.0, false, _dentro)
	print("PORTONE: entrato in x %.2f, %s" % [p.global_position.x, _stato_portone()])
	# girati e indietro piano contro la soglia, per tutta la chiusura
	Input.action_press(&"move_forward")
	for i in 60 * 4:
		p.set_look(lerp_angle(EST, OVEST, minf(float(i + 1) / 20.0, 1.0)), 0.0)
		await get_tree().physics_frame
		if i % 12 == 0:
			await _scatto("chiusura_%.2f" % float(portone.get(&"quanto")))
	Input.action_release(&"move_forward")
	await _frames(20)
	print("PORTONE: appoggiato in x %.2f, %s" % [p.global_position.x, _stato_portone()])
	for v in [[OVEST, 0.0, "dritto"], [OVEST, -0.6, "in_basso"], [OVEST, 0.5, "in_alto"], [OVEST + 0.7, 0.0, "spigolo_a"], [OVEST - 0.7, 0.0, "spigolo_b"]]:
		p.set_look(v[0], v[1])
		await _frames(6)
		await _scatto("chiuso_appoggiato_" + v[2])
	Input.action_press(&"move_back")
	await _frames(25)
	Input.action_release(&"move_back")
	p.set_look(OVEST, 0.0)
	await _frames(10)
	await _scatto("chiuso_un_passo_indietro")
	_errori.attivo = false
	for e in _errori.errori.slice(0, 15):
		printerr("    ", e)
	print("PORTONE: errori del motore e degli script: %d" % _errori.errori.size())
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_jpg(cart.path_join("%03d_%s.jpg" % [_n, nome]), 0.88)
	print("PORTONE: scatto %03d %s, giocatore %s, %s" % [_n, nome, p.global_position.snapped(Vector3.ONE * 0.01), _stato_portone()])


func _prepara() -> void:
	GameState.reset_progress()
	Engine.set_meta(&"risalita_subito", true)
	get_tree().change_scene_to_file(load("res://tests/scena_ridotta.gd").riduci(SCENA, TOGLI))
	await _aspetta_livello(p)
	# (senza il tunnel precaricato dietro la torre: col renderer vero non starebbe in memoria)
	level.set(&"sala_sottomarino_scena", "")
	var stati := {}
	var raccolti: Array = []
	for k in 5:
		var parte: String = GEN.PARTI[k]
		stati.merge(GEN.FATTI.get(parte, {}), true)
		raccolti.append_array(GEN.RACCOLTI.get(parte, []))
		for e in GEN.POLAROID.get(parte, []):
			GameState.collect(&"polaroid", StringName(e))
	for n in get_tree().get_nodes_in_group(&"persist"):
		var key := GameState.persist_key(n)
		if key in raccolti:
			GameState.mark_removed(n)
			n.queue_free()
			continue
		if stati.has(key) and n.has_method(&"load_state"):
			var d: Dictionary = n.call(&"save_state") if n.has_method(&"save_state") else {}
			d.merge(stati[key], true)
			n.call(&"load_state", d)
	p.inventory[&"zaino_pompa"] = 1
	if p.water_pack:
		p.water_pack.set_equipped(true, false)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for i in 10:
		await get_tree().physics_frame
	# la torre caricata e il portone aperto davvero (lo stato "aperto" non lo fa scorrere)
	level.call(&"_carica_torre")
	for i in 60 * 120:
		await get_tree().process_frame
		var t = level.get(&"sala_torre")
		if t is Node and bool((t as Node).get(&"costruita")):
			break
	portone = level.get(&"portone")
	if not bool(portone.call(&"is_aperto")):
		portone.call(&"apri")
		for i in 60 * 15:
			await get_tree().physics_frame
			if bool(portone.call(&"is_aperto")):
				break
	_check(bool(portone.call(&"is_aperto")), "la torre è costruita e il portone è aperto")
	# nella sala davanti al portone, rivolti a est (verso la torre)
	p.teleport(Vector3(16.5, 0.05, -15.0), EST, 0.0)
	for i in 30:
		await get_tree().physics_frame
