extends Node
## Finita la scritta "FINE DELLA DEMO" il gioco torna da solo al titolo (scelta 12A dell'utente, 24 ottobre): prima restava
## il nero e bisognava premere Esc. Il timer si ferma con la pausa, e dopo il ritorno al titolo non scatta una seconda volta.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_fine_titolo.gd

const SALA := "res://scenes/sala_principale.tscn"

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	get_tree().change_scene_to_file(SALA)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene
	check(level != null and level.has_method(&"_on_fine_torre"), "la sala principale è caricata")
	level.call(&"_on_fine_torre")
	await _secondi(3.0)
	# in pausa il tempo della scritta si ferma
	Game.set_paused(true)
	for i in 60 * 8:
		await get_tree().process_frame
	check(get_tree().current_scene == level, "in pausa non torna al titolo")
	Game.set_paused(false)
	await _secondi(3.0)
	check(get_tree().current_scene == level, "a 6 s di scritta è ancora la fine della demo")
	await _secondi(4.5)
	var titolo := get_tree().current_scene
	check(titolo != null and titolo.scene_file_path == Game.SCENE_TITLE, "finita la scritta, torna da solo al titolo (%s)" % (titolo.scene_file_path if titolo else "niente"))
	await _secondi(10.0)
	check(get_tree().current_scene == titolo, "e non ci torna una seconda volta")
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)
