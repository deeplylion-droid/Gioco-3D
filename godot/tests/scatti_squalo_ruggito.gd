extends Node
## Scatti della scena dello squalo all'inizio quando ti ruggisce in faccia (la minaccia, fra "minaccia" e "richiamo"
## dei tempi), con un preset della grafica, dalla camera del giocatore. Per ogni scatto stampa la luminanza media (0-255)
## di un quadrato di 120 px attorno alla bocca proiettata sullo schermo, e di tutta l'immagine. Per il confronto fra le
## versioni e i preset (riscontro dell'utente sulla 0.3.16: "quando ti ruggisce in faccia è troppo buio, totalmente
## nero"). Per il coordinatore, non per l'utente.
## Uso (con --fixed-fps i tempi della scena sono gli stessi a ogni giro, anche se llvmpipe è lento):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 --script res://tests/run.gd -- res://tests/scatti_squalo_ruggito.gd <cartella> <basso|medio|alto|ultra> \
##     [energia del riflesso viola sulla faccia, AtmosferaSqualo.energia_riflesso]

const LEVEL := "res://scenes/interni/interni.tscn"
const LATO := 120


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var args := OS.get_cmdline_user_args()
	var cartella: String = args[1] if args.size() > 1 else "user://scatti_ruggito"
	var preset: String = args[2] if args.size() > 2 else "alto"
	DirAccess.make_dir_recursive_absolute(cartella)
	# (le opzioni cambiate qui si salvano nelle impostazioni: alla fine si rimettono com'erano, se no restano per i
	# test dopo, come la nebbia viola spenta in test_riscaldamento_pipeline)
	var opzioni_prima: Dictionary = Grafica.valori.duplicate()
	Grafica.applica_preset(preset)
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
	var atm := s.get_node_or_null("Atmosfera")
	if args.size() > 3 and atm and &"energia_riflesso" in atm:
		atm.set(&"energia_riflesso", float(args[3]))
		preset += "_r%s" % args[3]
	var m: float = s.tempi.get("minaccia", 2.4)
	var r: float = s.tempi.get("richiamo", 5.4)
	var momenti := [[m + 0.4, "1_ruggito"], [m + 1.0, "2_ruggito"], [(m + r) * 0.5 + 0.3, "3_ruggito"], [r - 0.2, "4_prima_del_richiamo"]]
	level.call(&"fai_risveglio", p, true)
	var t := 0.0
	var k := 0
	while k < momenti.size():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t >= float(momenti[k][0]):
			await _scatto(cartella, "%s_%s" % [preset, momenti[k][1]], s, t)
			k += 1
	print("SCATTI: fatti in ", cartella)
	Grafica.valori = opzioni_prima
	Grafica.salva()
	get_tree().quit()


func _scatto(cartella: String, nome: String, s: RisveglioSqualo, t: float) -> void:
	var bocca: Vector3 = s.call(&"_punto_bocca")
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(cartella.path_join(nome + ".jpg"), 0.9)
	var cam := get_viewport().get_camera_3d()
	var faccia := -1.0
	if cam and not cam.is_position_behind(bocca):
		var c := cam.unproject_position(bocca)
		var r := Rect2i(Vector2i(c) - Vector2i(LATO, LATO) / 2, Vector2i(LATO, LATO)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.has_area():
			faccia = _luma(img, r)
	print("RUGGITO %s t %.2f bocca %.1f tutto %.1f" % [nome, t, faccia, _luma(img, Rect2i(Vector2i.ZERO, img.get_size()))])


func _luma(img: Image, r: Rect2i) -> float:
	var somma := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
			var c := img.get_pixel(x, y)
			somma += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return somma / maxf(n, 1) * 255.0
