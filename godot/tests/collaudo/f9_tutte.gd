extends Node
## Collaudo 0.4.0, punto E: tutte le partenze del menu F9 arrivano. Senza schermo, dal titolo, una dopo l'altra:
## MenuProva.parti (come il pulsante), poi l'arrivo (giocatore in gioco, comandi attivi), 5 s, dove sta, il checkpoint,
## le luci, gli errori nel log durante la partenza. "inizio" passa da _avvia_nuova_partita del titolo (spot saltato). F9:.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/f9_tutte.gd

const TITOLO := "res://scenes/ui/menu_principale.tscn"


class Errori extends Logger:
	var errori: Array[String] = []
	var _m := Mutex.new()
	func _log_error(_f: String, file: String, line: int, _c: String, r: String, _e: bool, tipo: int, _b: Array[ScriptBacktrace]) -> void:
		_m.lock()
		errori.append("%s %s:%d %s" % ["W" if tipo == ERROR_TYPE_WARNING else "E", file.get_file(), line, r])
		_m.unlock()
	func _log_message(_m2: String, _e: bool) -> void:
		pass


var _err := Errori.new()


func _ready() -> void:
	_run.call_deferred()


func _secondi(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await get_tree().process_frame


func _al_titolo() -> void:
	if get_tree().current_scene and String(get_tree().current_scene.name) == "MenuPrincipale":
		return
	Game.return_to_title()
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 300000 and not (get_tree().current_scene and String(get_tree().current_scene.name) == "MenuPrincipale"):
		await get_tree().process_frame
	await _secondi(2.0)


func _run() -> void:
	OS.add_logger(_err)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	get_tree().change_scene_to_file(TITOLO)
	await _secondi(5.0)
	var ids := MenuProva.disponibili().map(func(x): return x["id"])
	print("F9: partenze nel menu %d: %s" % [ids.size(), ids])
	for id in ids:
		await _al_titolo()
		_err.errori.clear()
		var vecchio := GameState.player.get_instance_id() if GameState.player and is_instance_valid(GameState.player) else 0
		var t0 := Time.get_ticks_msec()
		if id == "inizio":
			get_tree().current_scene.call(&"_avvia_nuova_partita")
			await _secondi(1.0)
			for n in get_tree().root.get_children():
				if n is LettoreSpot:
					n.call(&"_fine")
		else:
			MenuProva.parti(get_tree(), id)
		var ok := false
		while Time.get_ticks_msec() - t0 < 900000:
			await get_tree().process_frame
			var s := get_tree().current_scene
			var p := GameState.player
			if s and String(s.name) != "Caricamento" and String(s.name) != "MenuPrincipale" and p and is_instance_valid(p) \
					and p.get_instance_id() != vecchio and p.is_inside_tree() and p.input_enabled and not GameState.is_dying:
				ok = true
				break
		var dt := (Time.get_ticks_msec() - t0) / 1000.0
		await _secondi(5.0)
		var p2 := GameState.player
		var errs := _err.errori.filter(func(e): return e.begins_with("E"))
		print("F9: %s: arrivato %s in %.1f s, scena %s, giocatore %s, checkpoint %s, luci %s, in gioco dopo 5 s %s; errori %d %s; avvisi %d" % [id, ok, dt,
				get_tree().current_scene.name if get_tree().current_scene else "-", p2.global_position.snappedf(0.01) if p2 and is_instance_valid(p2) else "-",
				GameState.snapshot.get("checkpoint", ""), GameState.luci, p2 != null and is_instance_valid(p2) and p2.input_enabled and not GameState.is_dying,
				errs.size(), errs.slice(0, 4), _err.errori.size() - errs.size()])
	print("F9: finito")
	Game.esci(0)
