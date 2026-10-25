extends Node
## La memoria fotogramma per fotogramma durante la ripartenza (richiesta del coordinatore del 25 ottobre: l'utente ha una
## scheda da 4 GB e la sala ne usa 2,2-2,4; un doppione della sala alla ricarica, anche breve, può far crashare il driver).
## Riparte da un checkpoint nell'area bimbi (GameState.respawn) e stampa a ogni fotogramma la memoria statica di Godot, la
## memoria del processo (RSS), la memoria video (col renderer vero), gli oggetti, i nodi e la scena attuale; alla fine il
## picco rispetto a prima. "un_tempo": la ricarica di prima (la sala nuova si costruisce mentre la vecchia c'è ancora);
## "due_tempi": prima una scena vuota finché la vecchia è liberata, poi la nuova (GameState._cambia_in_due_tempi).
## Con "ridotta" la sala ridotta di tests/scena_ridotta.gd (per il renderer vero, che con la sala intera non sta in memoria).
## Uso (sotto il render.lock):
##   godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/memoria_ripartenza.gd due_tempi
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path godot --rendering-driver vulkan --resolution 640x360 \
##     --script res://tests/run.gd -- res://tests/collaudo/memoria_ripartenza.gd <un_tempo|due_tempi> ridotta

const LEVEL := "res://scenes/sala_principale.tscn"
const TOGLI := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Polaroid", "Sala/Dettagli", "Sala/TorreScivoli", "Gioco/EnigmaAcquari", "Atmosfera"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var due := not args.has("un_tempo")
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	if args.has("ridotta"):
		Grafica.applica_preset("medio")
	GameState.reset_progress()
	var scena := LEVEL
	if args.has("ridotta"):
		scena = load("res://tests/scena_ridotta.gd").riduci(LEVEL, TOGLI)
	get_tree().change_scene_to_file(scena)
	await _aspetta_giocatore()
	var p := GameState.player
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	p.teleport(Vector3(-18.3, 0.0, -0.4), 0.0, 0.0)
	for i in 120:
		await get_tree().process_frame
	GameState.capture_snapshot("Prova", 900, p.global_transform)
	GameState.ricarica_in_due_tempi = due
	print("Ripartenza %s, renderer %s, scena %s" % ["in due tempi" if due else "in un tempo", RenderingServer.get_video_adapter_name(), scena])
	print("  fotogramma | statica MB | RSS MB | video MB | oggetti | nodi | scena")
	var prima := _misura()
	for i in 10:
		await get_tree().process_frame
		prima = _misura()
	_stampa(-1, prima)
	var vecchia := get_tree().current_scene
	GameState.respawn()
	var picco := prima.duplicate()
	var nuova_da := -1
	for f in 2000:
		var m := _misura()
		for k in ["statica", "rss", "video", "oggetti", "nodi"]:
			picco[k] = maxf(float(picco[k]), float(m[k]))
		_stampa(f, m)
		var sc := get_tree().current_scene
		if nuova_da < 0 and sc and sc != vecchia and sc.name != Game.SCENA_VUOTA and GameState.player and is_instance_valid(GameState.player):
			nuova_da = f
		if nuova_da >= 0 and f - nuova_da >= 60:
			break
		await get_tree().process_frame
	var dopo := _misura()
	print("")
	print("PRIMA:  statica %d MB, RSS %d MB, video %d MB, oggetti %d, nodi %d" % [prima.statica, prima.rss, prima.video, prima.oggetti, prima.nodi])
	print("PICCO:  statica %d MB (+%d), RSS %d MB (+%d), video %d MB (+%d), oggetti %d, nodi %d" % [picco.statica,
		picco.statica - prima.statica, picco.rss, picco.rss - prima.rss, picco.video, picco.video - prima.video, picco.oggetti, picco.nodi])
	print("DOPO:   statica %d MB, RSS %d MB, video %d MB, oggetti %d, nodi %d" % [dopo.statica, dopo.rss, dopo.video, dopo.oggetti, dopo.nodi])
	print("")
	print("RISULTATO: 1 controlli ok, 0 falliti")
	Game.esci(0)


func _misura() -> Dictionary:
	var rss := 0
	# (i file di /proc hanno lunghezza 0: si leggono riga per riga)
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	while f and not f.eof_reached():
		var riga := f.get_line()
		if riga.begins_with("VmRSS:"):
			rss = int(riga.split(":")[1].strip_edges().split(" ")[0]) / 1024
			break
	var sc := get_tree().current_scene
	return {"statica": int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0), "rss": rss,
		"video": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		"oggetti": int(Performance.get_monitor(Performance.OBJECT_COUNT)), "nodi": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"scena": String(sc.name) if sc else "-"}


func _stampa(f: int, m: Dictionary) -> void:
	print("  %4d | %6d | %6d | %6d | %7d | %6d | %s" % [f, m.statica, m.rss, m.video, m.oggetti, m.nodi, m.scena])


func _aspetta_giocatore() -> void:
	for i in 1200:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying and get_tree().current_scene:
			break
	for i in 10:
		await get_tree().process_frame
	GameState.player.input_enabled = true
