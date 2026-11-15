extends Node
## Collaudo dei tempi delle ripartenze (ritocchi dopo la 0.3.20: lavoro ripetuto tolto, obiettivo 2-4 s, e dalla seconda
## morte nello stesso punto la scena della presa di 1 s). Nel gioco intero, senza schermo: la partenza <id> del menu F9,
## poi tre morti di fila nello stesso checkpoint:
##  1. senza saltare la scena (come chi la guarda tutta);
##  2. di nuovo senza saltarla (dalla seconda dovrebbe durare 1 s);
##  3. saltandola tenendo premuto (come chi ha fretta).
## Per ognuna: quanto dura la scena (dalla morte al nero, cioè al cambio di scena), quanto la ricarica (dal cambio di
## scena al giocatore che può muoversi), il totale, e se si riparte dallo stesso checkpoint e nello stesso posto.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_ripartenze.gd <id>

var _t0 := 0


func _ready() -> void:
	_run.call_deferred(OS.get_cmdline_user_args()[1])


func _cp() -> String:
	return String(GameState.snapshot.get("checkpoint", "")) if GameState.snapshot is Dictionary else ""


func _pronto() -> bool:
	var pl := GameState.player
	var sc := get_tree().current_scene
	return pl and is_instance_valid(pl) and pl.input_enabled and not GameState.is_dying and sc \
			and not String(sc.scene_file_path).contains("caricamento")


func _run(id: String) -> void:
	Game.pause_on_focus_loss = false
	if not MenuProva.parti(get_tree(), id):
		print("RIPARTENZE: ERRORE niente partenza ", id)
		get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		if _pronto():
			break
	# i lavori dopo l'arrivo (stanze nel thread, riscaldamento): 20 s fermi
	for i in 60 * 20:
		await get_tree().process_frame
	print("RIPARTENZE: partenza %s arrivata dopo %.1f s (%s)" % [id, (Time.get_ticks_msec() - t0) / 1000.0, _cp()])
	for k in 3:
		var salta := k == 2
		var cp := _cp()
		var dove := GameState.player.global_position
		var vecchia := get_tree().current_scene
		var tm := Time.get_ticks_msec()
		GameState.kill_player(&"medusa" if id in ["inseguimento", "tunnel"] else &"generico")
		if salta:
			Input.action_press(&"skip")
		var t_nero := -1.0
		var f_nero := -1
		var f := 0
		var f_dopo := 0
		while Time.get_ticks_msec() - tm < 240000:
			await get_tree().process_frame
			f += 1
			if t_nero < 0.0 and get_tree().current_scene != vecchia:
				t_nero = (Time.get_ticks_msec() - tm) / 1000.0
				f_nero = f
			elif t_nero >= 0.0:
				f_dopo += 1
			if t_nero >= 0.0 and _pronto():
				break
		Input.action_release(&"skip")
		var tot := (Time.get_ticks_msec() - tm) / 1000.0
		var pl := GameState.player
		print("RIPARTENZE: %s, morte %d (%s): scena %.2f s di gioco (%d fotogrammi, %.1f s veri), ricarica %.1f s veri (%d fotogrammi), totale vero %.1f s; checkpoint %s (prima %s), a %.2f m da dove si era" % [
				id, k + 1, "saltata" if salta else "guardata", f_nero / 60.0, f_nero, t_nero, tot - t_nero, f_dopo, tot, _cp(), cp,
				pl.global_position.distance_to(dove) if pl and is_instance_valid(pl) else -1.0])
		for i in 60 * 8:
			await get_tree().process_frame
	print("RIPARTENZE: finito")
	get_tree().quit()
