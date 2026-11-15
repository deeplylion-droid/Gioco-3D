extends Node
## Collaudo: molte morti di fila e la memoria (richiesta del coordinatore, 28 ottobre: memoria a ogni morte, torre e
## file dell'inseguimento tenuti in cache fra le ripartenze). Nella sala (con "ridotta" quella di tests/scena_ridotta.gd,
## che col renderer vero sta in memoria) il giocatore all'area bimbi, un checkpoint, poi [n] volte: morte (la sequenza
## saltata tenendo premuto, come chi gioca), la ripartenza, 2 s di gioco. A ogni ripartenza: memoria statica, del
## processo (RSS), video (col renderer vero), oggetti, nodi, orfani, il picco durante la ripartenza e gli errori del
## motore e degli script (ContaErrori di test_presa_vera). Alla fine la crescita media per morte dalla seconda in poi
## (la prima scalda le cache).
## Uso: [xvfb-run ... --rendering-driver vulkan] godot [--headless] --path godot --script res://tests/run.gd -- \
##        res://tests/collaudo/sonda_morti.gd <n> [ridotta]

const LEVEL := "res://scenes/sala_principale.tscn"
const TOGLI := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Polaroid", "Sala/Dettagli", "Sala/TorreScivoli", "Gioco/EnigmaAcquari", "Atmosfera"]
const Presa := preload("res://tests/test_presa_vera.gd")

var _errori := Presa.ContaErrori.new()


func _ready() -> void:
	OS.add_logger(_errori)
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var n := int(a[1]) if a.size() > 1 else 6
	var ridotta := a.has("ridotta")
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	if ridotta:
		Grafica.applica_preset("medio")
	GameState.reset_progress()
	var scena := LEVEL
	if ridotta:
		scena = load("res://tests/scena_ridotta.gd").riduci(LEVEL, TOGLI)
	get_tree().change_scene_to_file(scena)
	await _aspetta_giocatore()
	var p := GameState.player
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	p.teleport(Vector3(-18.3, 0.0, -0.4), 0.0, 0.0)
	for i in 120:
		await get_tree().process_frame
	GameState.capture_snapshot("Prova", 900, p.global_transform)
	print("MORTI: %d, renderer %s, scena %s" % [n, RenderingServer.get_video_adapter_name(), scena])
	print("MORTI: morte | statica MB | RSS MB | video MB | oggetti | nodi | orfani | picco video | errori | ripartenza s")
	var base := _misura()
	_stampa(0, base, base.video, 0, 0.0)
	var dopo_prima := {}
	_errori.attivo = true
	for k in range(1, n + 1):
		var vecchia := get_tree().current_scene
		var t0 := Time.get_ticks_msec()
		GameState.kill_player(&"generico")
		Input.action_press(&"skip")
		var picco := 0
		while Time.get_ticks_msec() - t0 < 180000:
			await get_tree().process_frame
			picco = maxi(picco, _misura().video)
			var sc := get_tree().current_scene
			var pl := GameState.player
			if sc and sc != vecchia and sc.name != Game.SCENA_VUOTA and pl and is_instance_valid(pl) and pl.input_enabled \
					and not GameState.is_dying:
				break
		Input.action_release(&"skip")
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		for i in 120:
			await get_tree().process_frame
		var m := _misura()
		_stampa(k, m, picco, _errori.errori.size(), t)
		if k == 1:
			dopo_prima = m
	_errori.attivo = false
	for e in _errori.errori.slice(0, 15):
		printerr("    ", e)
	var fine := _misura()
	if n > 1:
		var d := float(n - 1)
		print("MORTI: crescita media per morte dalla seconda: statica %+.2f MB, RSS %+.1f MB, video %+.1f MB, oggetti %+.1f, nodi %+.1f, orfani %+.1f" % [
			(fine.statica_f - dopo_prima.statica_f) / d, (fine.rss - dopo_prima.rss) / d, (fine.video - dopo_prima.video) / d,
			(fine.oggetti - dopo_prima.oggetti) / d, (fine.nodi - dopo_prima.nodi) / d, (fine.orfani - dopo_prima.orfani) / d])
	print("MORTI: errori del motore e degli script in tutte le morti: %d" % _errori.errori.size())
	print("RISULTATO: %d controlli ok, %d falliti" % [1 if _errori.errori.is_empty() else 0, 0 if _errori.errori.is_empty() else 1])
	Game.esci(0)


func _misura() -> Dictionary:
	var rss := 0
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	while f and not f.eof_reached():
		var riga := f.get_line()
		if riga.begins_with("VmRSS:"):
			rss = int(riga.split(":")[1].strip_edges().split(" ")[0]) / 1024
			break
	var st := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	return {"statica": int(st), "statica_f": st, "rss": rss, "video": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		"oggetti": int(Performance.get_monitor(Performance.OBJECT_COUNT)), "nodi": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orfani": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}


func _stampa(k: int, m: Dictionary, picco: int, errori: int, t: float) -> void:
	print("MORTI: %4d | %8.2f | %6d | %6d | %7d | %6d | %5d | %6d | %4d | %.1f" % [k, m.statica_f, m.rss, m.video, m.oggetti, m.nodi, m.orfani, picco, errori, t])


func _aspetta_giocatore() -> void:
	for i in 1200:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying and get_tree().current_scene:
			break
	for i in 10:
		await get_tree().process_frame
	GameState.player.input_enabled = true
