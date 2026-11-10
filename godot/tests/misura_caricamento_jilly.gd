extends Node
## Misura la schermata di caricamento della sala col renderer vero, per confrontare la schermata con Jilly (il video)
## e senza (il file del video spostato via: la schermata torna come prima, col riflesso). Stampa:
## - quando la sala è arrivata nel thread (ResourceLoader) e quando il riscaldamento degli shader è finito;
## - i fotogrammi: quanti, la media, il 95° percentile, il peggiore e quanti oltre 50 ms;
## - la memoria del processo (RSS da /proc/self/status) all'inizio, al massimo e alla fine, e la memoria statica di
##   Godot, mentre la schermata è aperta.
## Con SCATTI=<cartella> salva anche tre scatti della schermata (a 2; 4,6 e 6,4 s).
## Esce prima che la sala entri in scena (la sala intera sul renderer software non entra in memoria). Anche solo
## aspettando la sala nel thread, col riscaldamento, il renderer software arrivava a 12,3 GB e il processo veniva ucciso
## (#139): se la memoria libera della macchina (MemAvailable) scende sotto [constant MEMORIA_MINIMA_MB] MB la misura si
## ferma lì e stampa quello che ha («interrotta per la memoria»). Con FINO=<s> si ferma dopo tanti secondi.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##       --script res://tests/run.gd -- res://tests/misura_caricamento_jilly.gd


## Sotto tanta memoria libera della macchina (MB) la misura si ferma (#139).
const MEMORIA_MINIMA_MB := 2048


func _ready() -> void:
	_run.call_deferred()


var _scatti := []


func _run() -> void:
	Game.pause_on_focus_loss = false
	if OS.get_environment("SCATTI") != "":
		DirAccess.make_dir_recursive_absolute(OS.get_environment("SCATTI"))
		_scatti = [2.0, 4.6, 6.4]
	var rss0 := _rss()
	get_tree().change_scene_to_file("res://scenes/ui/caricamento.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var s := get_tree().current_scene
	var r: RiscaldamentoShader = null
	for c in s.get_children():
		if c is RiscaldamentoShader:
			r = c
	var video := s.find_child("VideoJilly", true, false) != null
	var scena: String = s.get(&"scena")
	var t0 := Time.get_ticks_msec()
	var prima := Time.get_ticks_usec()
	var tempi := PackedFloat32Array()
	var arrivata := -1.0
	var rss_max := rss0
	var fino := float(OS.get_environment("FINO")) if OS.get_environment("FINO").is_valid_float() else 600.0
	var interrotta := ""
	while Time.get_ticks_msec() - t0 < fino * 1000.0:
		await get_tree().process_frame
		var ora := Time.get_ticks_usec()
		tempi.append((ora - prima) / 1000.0)
		prima = ora
		var dt := (Time.get_ticks_msec() - t0) / 1000.0
		for k in _scatti.size():
			if _scatti[k] >= 0.0 and dt >= _scatti[k]:
				_scatti[k] = -1.0
				_salva(OS.get_environment("SCATTI").path_join("caricamento_%d.png" % k))
		if tempi.size() % 10 == 0:
			rss_max = maxi(rss_max, _rss())
			var libera := _libera()
			if libera >= 0 and libera < MEMORIA_MINIMA_MB * 1024:
				interrotta = "interrotta per la memoria a %.1f s (libera %.0f MB, RSS %.0f MB)" % [dt, libera / 1024.0, _rss() / 1024.0]
				break
		if arrivata < 0.0 and ResourceLoader.load_threaded_get_status(scena) == ResourceLoader.THREAD_LOAD_LOADED:
			arrivata = (Time.get_ticks_msec() - t0) / 1000.0
		if arrivata >= 0.0 and (r == null or r.concluso):
			break
	var fine := (Time.get_ticks_msec() - t0) / 1000.0
	if interrotta == "" and (arrivata < 0.0 or (r != null and not r.concluso)):
		interrotta = "interrotta dopo %.0f s" % fine
	if interrotta != "":
		print("MISURA %s: la sala %s, il riscaldamento %s" % [interrotta, "arrivata a %.2f s" % arrivata if arrivata >= 0.0 else "non arrivata",
			"finito" if r == null or r.concluso else "non finito (%d su %d)" % [r.fatti, r.totale]])
	var rss1 := _rss()
	var t := tempi.slice(3)
	var somma := 0.0
	var lunghi := 0
	for x in t:
		somma += x
		if x > 50.0:
			lunghi += 1
	var ord := t.duplicate()
	ord.sort()
	print("MISURA video %s: sala arrivata in %.2f s, riscaldamento finito in %.2f s" % ["SI" if video else "NO", arrivata, fine])
	print("MISURA video %s: %d fotogrammi, media %.1f ms, 95%% %.1f ms, peggiore %.0f ms, %d oltre 50 ms" % [
			"SI" if video else "NO", t.size(), somma / maxf(t.size(), 1), ord[int(ord.size() * 0.95)], ord[-1], lunghi])
	print("MISURA video %s: RSS all'inizio %.0f MB, massimo %.0f MB, alla fine %.0f MB; statica di Godot %.0f MB" % [
			"SI" if video else "NO", rss0 / 1024.0, rss_max / 1024.0, rss1 / 1024.0,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6])
	Game.esci()


func _salva(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(file)


## La memoria del processo (kB).
static func _rss() -> int:
	return _campo("/proc/self/status", "VmRSS:")


## La memoria libera della macchina (kB; -1 se non si legge).
static func _libera() -> int:
	var v := _campo("/proc/meminfo", "MemAvailable:")
	return v if v > 0 else -1


## Un campo in kB di un file di /proc. (Riga per riga: i file di /proc hanno lunghezza 0, e get_as_text() li
## leggeva vuoti, #139.)
static func _campo(file: String, chiave: String) -> int:
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null:
		return 0
	while not f.eof_reached():
		var riga := f.get_line()
		if riga.begins_with(chiave):
			return int(riga.split(":")[1].strip_edges().split(" ")[0])
		if riga == "" and f.eof_reached():
			break
	return 0
