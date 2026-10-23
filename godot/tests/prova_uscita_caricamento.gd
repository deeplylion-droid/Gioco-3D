extends Node
## Riproduce l'uscita dal gioco con un caricamento nel thread ancora in corso (CI di lavoro/godot
## 58cc633: test_acquari muore con "Aborted" 12 s dopo il RISULTATO). Modi:
##   torre [s]  la sala, la precarica della torre e l'uscita dopo s secondi (0: subito);
##   cambio     la sala, la precarica della torre e subito il ritorno al titolo (la sala esce dall'albero);
##   riparti    come la fine di test_acquari: la sala si ricarica mentre la torre carica, poi l'uscita;
##   riparti_dopo come la fine di test_tappa8 (CI di lavoro/godot 2a4f4a8a): la torre ha finito di caricare,
##              parte Game.esci() e, mentre aspetta, la morte fa ripartire il livello (GameState.respawn): la sala
##              nuova richiede la torre nel thread;
##   livello [s] la schermata di caricamento del livello e l'uscita dopo s secondi.
##   pieno      controprova: il livello caricato fino in fondo controllando lo stato, 60 fotogrammi, quit();
##   pieno_esci il livello chiesto con Game.carica_in_thread, 1 s, poi Game.esci().
## Con "diretto" alla fine esce con get_tree().quit() senza aspettare (com'era prima di Game.esci).
## La usa test_uscita.gd. Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/prova_uscita_caricamento.gd <modo>


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var modo := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "torre"
	if modo == "pieno":
		# controprova: il livello caricato nel thread fino in fondo (senza bloccare), poi 60 fotogrammi e l'uscita
		var sala := "res://scenes/sala_principale.tscn"
		ResourceLoader.load_threaded_request(sala, "PackedScene")
		while ResourceLoader.load_threaded_get_status(sala) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		var pk = ResourceLoader.load_threaded_get(sala)
		print("pieno: caricato %s" % pk)
		pk = null
		for i in 60:
			await get_tree().process_frame
		print("USCITA dopo il caricamento pieno")
		get_tree().quit()
		return
	if modo == "pieno_esci":
		Game.carica_in_thread("res://scenes/sala_principale.tscn", "PackedScene")
		var t2 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t2 < 1000:
			var p := []
			ResourceLoader.load_threaded_get_status("res://scenes/sala_principale.tscn", p)
			await get_tree().process_frame
		print("USCITA con il livello in caricamento (senza schermata)")
		Game.esci()
		return
	if modo == "livello":
		get_tree().change_scene_to_file("res://scenes/ui/caricamento.tscn")
		var dopo := float(OS.get_cmdline_user_args()[2]) if OS.get_cmdline_user_args().size() > 2 else 0.0
		var t1 := Time.get_ticks_msec()
		for i in 3:
			await get_tree().process_frame
		while Time.get_ticks_msec() - t1 < dopo * 1000.0:
			await get_tree().process_frame
		print("USCITA durante il caricamento del livello")
		_esci()
		return
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 30:
		await get_tree().process_frame
	var sala := get_tree().current_scene
	var torre: String = sala.get(&"sala_torre_scena")
	sala.call(&"_precarica_torre")
	print("torre in caricamento: %s" % sala.get(&"_torre_in_caricamento"))
	var attesa := float(OS.get_cmdline_user_args()[2]) if OS.get_cmdline_user_args().size() > 2 else 0.0
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	while Time.get_ticks_msec() - t0 < attesa * 1000.0 and sala.get(&"_torre_in_caricamento"):
		await get_tree().process_frame
	print("dopo %.1f s: stato %d" % [(Time.get_ticks_msec() - t0) / 1000.0,
			ResourceLoader.load_threaded_get_status(sala.get(&"sala_torre_scena"))])
	if modo == "riparti_dopo":
		# la torre finisce di caricare, poi l'uscita; subito dopo il respawn come quando lei ti prende
		while sala.get(&"_torre_in_caricamento"):
			await get_tree().process_frame
		print("torre caricata, ora Game.esci() e subito il respawn")
		print("USCITA con il respawn durante l'attesa")
		Game.esci()
		await get_tree().process_frame
		GameState.respawn()
		for i in 3:
			await get_tree().process_frame
		var nuova := get_tree().current_scene
		if nuova != sala and nuova and nuova.has_method(&"_precarica_torre"):
			nuova.call(&"_precarica_torre")
			print("sala ricaricata, torre di nuovo in caricamento: %s" % nuova.get(&"_torre_in_caricamento"))
		else:
			print("sala non ricaricata (si sta uscendo)")
		return
	if modo == "riparti":
		# come la fine di test_acquari: la sala si ricarica (la vecchia esce con la torre in caricamento,
		# la nuova la richiede di nuovo), 10 fotogrammi e quit()
		get_tree().reload_current_scene()
		for i in 3:
			await get_tree().process_frame
		get_tree().current_scene.call(&"_precarica_torre")
		for i in 10:
			await get_tree().process_frame
	if modo == "cambio":
		get_tree().change_scene_to_file("res://scenes/ui/menu_principale.tscn")
		for i in 5:
			await get_tree().process_frame
		print("sala uscita, ora quit")
	# la stessa misura di Game.esci (lo stato nel ResourceLoader), non il flag della sala: la torre può essere già
	# caricata prima che la sala la ritiri (CI di lavoro/godot 2a7ac4d9: "torre 0.3", "aspettati" mancava)
	var in_corso := ResourceLoader.load_threaded_get_status(torre) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
	print("USCITA con la torre in caricamento: %s" % ("IN CORSO" if in_corso else "già finita"))
	_esci()


## Come esce il gioco (Game.esci), oppure con "diretto" in fondo agli argomenti get_tree().quit() come prima.
func _esci() -> void:
	if OS.get_cmdline_user_args()[-1] == "diretto":
		get_tree().quit()
	else:
		Game.esci()
