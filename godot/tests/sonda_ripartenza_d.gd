extends Node
## Sonda per la proposta D (sonda dei load del 9 novembre): quanto si accorcia la ripartenza tenendo in memoria
## (GameState.tieni) la scena della torre e i file dell'inseguimento, e quanta memoria costa.
## Per le partenze F9 torre, inseguimento e tunnel: due morti di fila, il tempo dalla morte al giocatore di nuovo in
## gioco, e la memoria statica (adesso e il picco). Senza schermo la memoria video non c'è: conta solo la statica.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/sonda_ripartenza_d.gd [tieni]

const PARTENZE := ["torre", "inseguimento", "tunnel"]


func _ready() -> void:
	_run.call_deferred()


func _mb(b: int) -> float:
	return b / 1048576.0


func _aspetta_ripresa() -> float:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and GameState.player \
				and is_instance_valid(GameState.player) and not GameState.is_restoring():
			break
	return (Time.get_ticks_msec() - t0) / 1000.0


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var tieni := OS.get_cmdline_user_args().has("tieni")
	print("SONDA_D: modo %s" % ("tieni" if tieni else "com'è"))
	for id in PARTENZE:
		MenuProva.parti(get_tree(), id)
		var tp := await _aspetta_ripresa()
		for i in 300:
			await get_tree().process_frame
		if tieni:
			var sala := get_tree().current_scene
			var extra: Array = [String(sala.get(&"sala_torre_scena"))] + SalaInseguimento.risorse()
			for p in extra:
				if p != "" and ResourceLoader.exists(p):
					GameState.tieni(p, load(p))
		var m0 := OS.get_static_memory_usage()
		var tempi: Array = []
		for k in 2:
			GameState.respawn()
			tempi.append(await _aspetta_ripresa())
			for i in 300:
				await get_tree().process_frame
		print("SONDA_D: %s: partenza %.1f s; ripartenze %s s; memoria statica %.0f MB prima delle morti, %.0f MB dopo, picco %.0f MB" % [
				id, tp, tempi, _mb(m0), _mb(OS.get_static_memory_usage()), _mb(OS.get_static_memory_peak_usage())])
	get_tree().quit()
