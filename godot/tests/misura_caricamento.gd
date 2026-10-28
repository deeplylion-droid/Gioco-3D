extends Node
## Misura la schermata di caricamento dell'avvio col renderer vero: mentre la sala si carica nel thread e
## RiscaldamentoShader crea e disegna gli shader delle zone, la schermata non deve mai fermarsi più di 100 ms.
## Stampa ogni fotogramma sopra 50 ms (con le pipeline compilate in quel fotogramma), il peggiore e la durata del
## riscaldamento; esce appena il riscaldamento è finito (prima che la sala entri in scena).
## Per la cache vuota (il primo avvio su un PC nuovo) spostare via prima user://shader_cache (non cancellarla).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##       --script res://tests/run.gd -- res://tests/misura_caricamento.gd

const MONITOR := [Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW,
	Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file("res://scenes/ui/caricamento.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var schermata := get_tree().current_scene
	var r: RiscaldamentoShader = null
	for c in schermata.get_children():
		if c is RiscaldamentoShader:
			r = c
	if r == null:
		print("CARICAMENTO: nessun riscaldamento nella schermata")
		get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	var prima := Time.get_ticks_usec()
	var conta := []
	for m in MONITOR:
		conta.append(Performance.get_monitor(m))
	var peggiore := 0.0
	var n := 0
	while not r.concluso and Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		var ora := Time.get_ticks_usec()
		var ms := (ora - prima) / 1000.0
		prima = ora
		n += 1
		var c := []
		for k in MONITOR.size():
			var v := Performance.get_monitor(MONITOR[k])
			c.append(int(v - conta[k]))
			conta[k] = v
		if n > 3:
			peggiore = maxf(peggiore, ms)
		if ms > 50.0:
			print("LUNGO %.0f ms (fatti %d/%d; pipeline surface %d draw %d spec %d)" % [ms, r.fatti, r.totale, c[0], c[1], c[2]])
	print("CARICAMENTO: riscaldamento di %d materiali in %.1f s, %d fotogrammi, il peggiore %.0f ms" % [
			r.totale / 2, (Time.get_ticks_msec() - t0) / 1000.0, n, peggiore])
	Game.esci()
