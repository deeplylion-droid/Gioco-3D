extends Node
## Collaudo 0.3.25 (gira anche sulla 0.3.24): la memoria al titolo e in gioco, e lo schermo nero delle ripartenze nella
## torre e nell'inseguimento. Senza schermo: la memoria statica di Godot (OS.get_static_memory_usage) e l'RSS del
## processo (VmRSS/VmHWM da /proc). RM:
##   1. il titolo, 15 s dopo: memoria;
##   2. F9 Torre, 5 s dopo l'arrivo: memoria; poi 3 morti: per ognuna il tempo dalla morte al giocatore di nuovo in gioco
##      e allo schermo libero (niente velo nero né scena di morte), poi la memoria;
##   3. F9 Inseguimento, uguale.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/ripartenze_memoria.gd

const TITOLO := "res://scenes/ui/menu_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


static func _mem() -> String:
	var out := {}
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	while f and not f.eof_reached():
		var riga := f.get_line()
		for k in ["VmRSS", "VmHWM"]:
			if riga.begins_with(k + ":"):
				out[k] = int(riga.split(":")[1].strip_edges().split(" ")[0]) / 1024
	return "statica %.1f MB, RSS %d MB, picco RSS %d MB, oggetti %d, nodi %d, orfani %d" % [OS.get_static_memory_usage() / 1048576.0,
			out.get("VmRSS", 0), out.get("VmHWM", 0), Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)]


func _secondi(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await get_tree().process_frame


func _in_gioco(vecchio: int) -> bool:
	var p := GameState.player
	var s := get_tree().current_scene
	return s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and String(s.name) != "MenuPrincipale" and p \
			and is_instance_valid(p) and p.get_instance_id() != vecchio and p.is_inside_tree() and not GameState.is_restoring() \
			and not GameState.is_dying


func _schermo_libero() -> bool:
	if not Dissolvenza.schermo_libero(get_tree()):
		return false
	for d in get_tree().root.find_children("*", "DeathSequence", true, false):
		var nero := d.get(&"_black") as ColorRect
		if nero and nero.is_visible_in_tree() and nero.color.a > 0.001:
			return false
	return true


func _arriva(vecchio: int) -> void:
	var t := Time.get_ticks_msec()
	while not _in_gioco(vecchio) and Time.get_ticks_msec() - t < 900000:
		await get_tree().process_frame


func _parti(id: String) -> void:
	var vecchio := GameState.player.get_instance_id() if GameState.player and is_instance_valid(GameState.player) else 0
	if get_tree().current_scene == null or String(get_tree().current_scene.name) != "MenuPrincipale":
		Game.return_to_title()
		var t := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t < 300000 and not (get_tree().current_scene and String(get_tree().current_scene.name) == "MenuPrincipale"):
			await get_tree().process_frame
		await _secondi(2.0)
	MenuProva.parti(get_tree(), id)
	await _arriva(vecchio)
	await _secondi(5.0)
	print("RM: %s, 5 s dopo l'arrivo: %s" % [id, _mem()])
	for k in 3:
		var v := GameState.player.get_instance_id()
		var t0 := Time.get_ticks_usec()
		GameState.kill_player(&"prova")
		await _arriva(v)
		var t_gioco := (Time.get_ticks_usec() - t0) / 1e6
		var t1 := Time.get_ticks_msec()
		while not _schermo_libero() and Time.get_ticks_msec() - t1 < 30000:
			await get_tree().process_frame
		var t_libero := (Time.get_ticks_usec() - t0) / 1e6
		await _secondi(3.0)
		print("RM: %s morte %d: in gioco dopo %.2f s, schermo libero dopo %.2f s; poi %s" % [id, k + 1, t_gioco, t_libero, _mem()])


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	print("RM: all'avvio: %s" % _mem())
	get_tree().change_scene_to_file(TITOLO)
	await _secondi(15.0)
	print("RM: al titolo, 15 s dopo: %s" % _mem())
	await _parti("torre")
	await _parti("inseguimento")
	print("RM: finito")
	Game.esci(0)
