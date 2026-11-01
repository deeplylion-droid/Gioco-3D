extends Node
## Scatti di SB1 dagli occhi del giocatore, col renderer vero: lei sbuca dal pozzo, ti guarda, e se ne va (con il tunnel
## pronto, come nel gioco: _dopo_sb1, scende_sb1). Per il riscontro dell'utente sulla 0.3.18 ("dovrebbe scendere
## direttamente, invece sale di scatto tutta su e poi scende"). Uno scatto ogni [constant OGNI] fotogrammi da DA a A secondi
## dall'inizio di SB1, e per ognuno l'altezza della testa di lei rispetto a quella all'inizio della discesa.
## Uso (sotto il lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 --script res://tests/run.gd -- res://tests/collaudo/scatti_sb1_scende.gd <cartella>

const LEVEL := "res://scenes/test/inseguimento_prova.tscn"
const DA := 4.6
const A := 6.4
const OGNI := 2


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var cartella: String = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 10:
		await get_tree().process_frame
	var p := GameState.player
	var ins := get_tree().current_scene.get_node("SalaInseguimento") as SalaInseguimento
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	ins.dopo_sb1_continua = true
	AttesaZone.pronta(&"tunnel")
	ins.tempo_presa = 1e6
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var sc: Dictionary = ins.dati["scale"][ins.dati["scale"].size() - 1]
	var piede := SalaInseguimento.b([float(sc["x"]), float(sc["y"]), float(sc["z0"])])
	ins.cala_grata()
	p.teleport(piede + Vector3(3.0, 0.3, 0.0))
	for i in 3:
		await get_tree().process_frame
	ins.inizia_sb1()
	var t := 0.0
	var f := 0
	var testa0 := INF
	while t < A:
		await get_tree().process_frame
		t += get_process_delta_time()
		f += 1
		var occhio: Vector3 = ins.lei.get_eye_position()
		if ins.lei_stato == SalaInseguimento.Lei.SCENDE and testa0 == INF:
			testa0 = occhio.y
		if t >= DA and f % OGNI == 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(cartella.path_join("sb1_%05.2f.jpg" % t), 0.9)
			var luce := ins.get(&"_lei_luce") as OmniLight3D
			print("SB1 t %.2f stato %d anim %s occhio %+.3f luce %.2f%s" % [t, ins.lei_stato, ins.lei.animazione,
				occhio.y - testa0 if testa0 != INF else 0.0, luce.light_energy if luce else -1.0,
				"" if luce and luce.is_visible_in_tree() else " (spenta)"])
	print("FINE")
	get_tree().quit()
