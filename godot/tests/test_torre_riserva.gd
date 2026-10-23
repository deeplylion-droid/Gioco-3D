extends Node
## La riserva della torre (sala_principale.gd, 23 ottobre): col portone aperto da più di ATTESA_TORRE secondi e il
## thread che non ha ancora finito (un PC lento, la cache fredda) la torre si carica sul thread principale, a parte
## (CACHE_MODE_IGNORE_DEEP), e il guscio sparisce; la copia del thread, quando arriva, si lascia andare.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_torre_riserva.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	await get_tree().process_frame
	var level := get_tree().current_scene
	var portone := level.get(&"portone") as PortoneTorre
	var scena: String = level.get(&"sala_torre_scena")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	portone.apri()
	await get_tree().process_frame
	check(bool(level.get(&"_torre_in_caricamento")) and level.get(&"sala_torre") == null,
		"il portone si apre: la torre comincia a caricarsi nel thread")
	# come se il portone fosse aperto da più dell'attesa, col thread ancora a metà
	level.set(&"_torre_voluta_da", Time.get_ticks_msec() - int(level.get(&"ATTESA_TORRE") * 1000.0) - 1000)
	var t0 := Time.get_ticks_msec()
	while level.get(&"sala_torre") == null and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	var sala: Node = level.get(&"sala_torre")
	var ancora := ResourceLoader.load_threaded_get_status(scena) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
	check(sala != null and sala.is_inside_tree(), "passata l'attesa la torre si carica sul thread principale (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("  (il thread a quel punto: %s)" % ("ancora in corso" if ancora else "finito"))
	await get_tree().process_frame
	check(level.find_child("sala_torre_guscio", true, false) == null, "il guscio dietro il portone non c'è più")
	t0 = Time.get_ticks_msec()
	while bool(level.get(&"_torre_in_caricamento")) and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	await get_tree().process_frame
	check(not bool(level.get(&"_torre_in_caricamento")) and level.get(&"_torre_pronta") == null and level.get(&"sala_torre") == sala,
		"la copia del thread, arrivata dopo, si lascia andare: resta la torre della riserva")
	check(level.find_children("*", "SalaTorre", true, false).size() == 1, "una torre sola nella sala")
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)
