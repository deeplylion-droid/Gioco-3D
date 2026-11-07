extends Node
## Misura la schermata di caricamento della sala col renderer vero, per confrontare la schermata con Jilly (il video)
## e senza (il file del video spostato via: la schermata torna come prima, col riflesso). Stampa:
## - quando la sala è arrivata nel thread (ResourceLoader) e quando il riscaldamento degli shader è finito;
## - i fotogrammi: quanti, la media, il 95° percentile, il peggiore e quanti oltre 50 ms;
## - la memoria del processo (RSS da /proc/self/status) all'inizio, al massimo e alla fine, e la memoria statica di
##   Godot, mentre la schermata è aperta.
## Esce prima che la sala entri in scena (la sala intera sul renderer software non entra in memoria).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##       --script res://tests/run.gd -- res://tests/misura_caricamento_jilly.gd


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
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
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		var ora := Time.get_ticks_usec()
		tempi.append((ora - prima) / 1000.0)
		prima = ora
		if tempi.size() % 10 == 0:
			rss_max = maxi(rss_max, _rss())
		if arrivata < 0.0 and ResourceLoader.load_threaded_get_status(scena) == ResourceLoader.THREAD_LOAD_LOADED:
			arrivata = (Time.get_ticks_msec() - t0) / 1000.0
		if arrivata >= 0.0 and (r == null or r.concluso):
			break
	var fine := (Time.get_ticks_msec() - t0) / 1000.0
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


## La memoria del processo (kB).
static func _rss() -> int:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return 0
	for riga in f.get_as_text().split("\n"):
		if riga.begins_with("VmRSS:"):
			return int(riga.split(":")[1].strip_edges().split(" ")[0])
	return 0
