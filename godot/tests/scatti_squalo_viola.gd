extends Node
## Scatti interni della scena dello squalo all'inizio, con e senza la luce viola e la nebbia (AtmosferaSqualo), dagli
## stessi punti: la camera del giocatore a 1,0 s (lui chino sulla faccia), 3,5 s (la minaccia), al richiamo di Jilly,
## a metà corsa verso la porta, alla porta che si chiude, al ritorno del controllo e 2 s e 4,5 s dopo (la nebbia che si
## dirada). Per il coordinatore, non per l'utente.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##   --script res://tests/run.gd -- res://tests/scatti_squalo_viola.gd <cartella> [prima]
##   (prima: senza la luce viola e la nebbia, com'era)

const LEVEL := "res://scenes/interni/interni.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var args := OS.get_cmdline_user_args()
	var cartella: String = args[1] if args.size() > 1 else "user://scatti_squalo"
	var prima := args.size() > 2 and args[2] == "prima"
	DirAccess.make_dir_recursive_absolute(cartella)
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 30:
		await get_tree().process_frame
	var level := get_tree().current_scene
	var p := GameState.player
	var s := level.get_node("Gioco/RisveglioSqualo") as RisveglioSqualo
	var a := s.get_node_or_null("Atmosfera") as AtmosferaSqualo
	if prima and a:
		a.process_mode = Node.PROCESS_MODE_DISABLED
		a.visible = false
	var rich: float = s.tempi.get("richiamo", 5.4)
	var porta_t: float = s.tempi.get("porta", 10.15)
	var momenti := [[1.0, "1_faccia"], [3.5, "2_minaccia"], [rich + 0.4, "3_richiamo"], [(rich + porta_t) * 0.5 + 0.6, "4_corsa"],
		[porta_t + 0.3, "5_porta"]]
	level.call(&"fai_risveglio", p, true)
	var t := 0.0
	var k := 0
	while k < momenti.size():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t >= float(momenti[k][0]):
			await _scatto(cartella, momenti[k][1])
			k += 1
	while not p.input_enabled and t < 25.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await _scatto(cartella, "6_controllo")
	for dopo in [[2.0, "7_dopo_2s"], [4.5, "8_dopo_4s"]]:
		var t1 := 0.0
		while t1 < float(dopo[0]) - (2.0 if dopo[1] == "8_dopo_4s" else 0.0):
			await get_tree().process_frame
			t1 += get_process_delta_time()
		await _scatto(cartella, dopo[1])
	print("SCATTI: fatti in ", cartella)
	get_tree().quit()


func _scatto(cartella: String, nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(cartella.path_join(nome + ".jpg"), 0.9)
