extends Node
## La sequenza di morte di lei intera (urlo, glitch dello schermo, scosse), senza saltarla, col renderer vero e la cache
## degli shader vuota, poi la ricarica del livello e 30 s di gioco: negli interni, perché la sala intera col renderer
## software non sta nella memoria della macchina (crash della v0.3.14 dopo il primo spavento, 25 ottobre).
## Conta gli errori del motore e degli script dalla morte in poi (ContaErrori di test_presa_vera).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path godot --rendering-driver vulkan --resolution 640x360 \
##     --script res://tests/run.gd -- res://tests/collaudo/morte_vulkan.gd

const LEVEL := "res://scenes/interni/interni.tscn"
const Presa := preload("res://tests/test_presa_vera.gd")

var _errori := Presa.ContaErrori.new()
var _passed := 0
var _failed := 0


func _ready() -> void:
	OS.add_logger(_errori)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	check(RenderingServer.get_rendering_device() != null, "c'è il renderer vero (%s)" % RenderingServer.get_video_adapter_name())
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	await _frames(30)
	var vecchia := get_tree().current_scene
	_errori.attivo = true
	var t0 := Time.get_ticks_msec()
	GameState.kill_player(&"medusa")
	await _frames(2)
	var seq := GameState.get_children().filter(func(n): return n is DeathSequence)
	check(seq.size() == 1 and (seq[0] as Node).find_children("*", "JumpscareGlitch", true, false).size() == 1,
		"lei ti prende: sequenza di morte col jumpscare (glitch e urlo)")
	while (get_tree().current_scene == vecchia or get_tree().current_scene == null) and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	print("  (livello ricaricato dopo %.1f s; pipeline draw %d spec %d)" % [(Time.get_ticks_msec() - t0) / 1000.0,
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))])
	check(get_tree().current_scene != vecchia, "la sequenza finisce e il livello si ricarica")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	var p := GameState.player
	check(p != null and is_instance_valid(p) and not GameState.is_dying, "si riparte")
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	check(is_instance_valid(p), "dopo 30 s si gioca ancora")
	_errori.attivo = false
	for e in _errori.errori.slice(0, 20):
		printerr("    ", e)
	check(_errori.errori.is_empty(), "dalla morte a 30 s dopo la ripartenza nessun errore del motore o degli script (%d)" % _errori.errori.size())
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
