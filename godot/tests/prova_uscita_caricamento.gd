extends Node
## Riproduce l'uscita dal gioco con un caricamento nel thread ancora in corso (CI di lavoro/godot
## 58cc633: test_acquari muore con "Aborted" 12 s dopo il RISULTATO). Modi:
##   torre [s]  la sala, la precarica della torre e quit() dopo s secondi (0: subito);
##   cambio     la sala, la precarica della torre e subito il ritorno al titolo (la sala esce dall'albero);
##   livello    la schermata di caricamento del livello e subito quit().
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/prova_uscita_caricamento.gd <modo>


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var modo := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "torre"
	if modo == "livello":
		get_tree().change_scene_to_file("res://scenes/ui/caricamento.tscn")
		for i in 3:
			await get_tree().process_frame
		print("USCITA durante il caricamento del livello")
		get_tree().quit()
		return
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 30:
		await get_tree().process_frame
	var sala := get_tree().current_scene
	sala.call(&"_precarica_torre")
	print("torre in caricamento: %s" % sala.get(&"_torre_in_caricamento"))
	var attesa := float(OS.get_cmdline_user_args()[2]) if OS.get_cmdline_user_args().size() > 2 else 0.0
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	while Time.get_ticks_msec() - t0 < attesa * 1000.0 and sala.get(&"_torre_in_caricamento"):
		await get_tree().process_frame
	print("dopo %.1f s: stato %d" % [(Time.get_ticks_msec() - t0) / 1000.0,
			ResourceLoader.load_threaded_get_status(sala.get(&"sala_torre_scena"))])
	if modo == "cambio":
		get_tree().change_scene_to_file("res://scenes/ui/menu_principale.tscn")
		for i in 5:
			await get_tree().process_frame
		print("sala uscita, ora quit")
	print("USCITA con la torre in caricamento")
	get_tree().quit()
