extends Node
## Collaudo finale 0.3.21 (mascotte): l'album delle Polaroid nel menu di pausa (scelta A dell'utente del 4 novembre), come
## lo vede il giocatore, sopra la Risalita (il corridoio del personale, come scatti_corridoio_personale.gd): a 0, dopo
## alcune Polaroid raccolte, aperta una grande, e con le Polaroid di un salvataggio ripreso come fa Continua
## (GameState.prepara_ripresa, la stessa di continue_from_disk, con la partenza "torre" del menu di prova: 14). Stampa il
## contatore e quante cornici hanno la foto. (La Continua vera, con la sala dalla schermata di caricamento, la prova
## test_continua: "n Polaroid raccolte".)
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/collaudo_0321_album.gd <cartella>

const Y := -5.4
var cartella := "/tmp/album"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	TranslationServer.set_locale("it")
	Engine.set_meta(&"risalita_subito", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	GameState.reset_progress()
	var ris := (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate() as Node3D
	add_child(ris)
	var cam := Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	cam.make_current()
	for i in 3600:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 200:
			break
	cam.global_position = Vector3(-35.0, Y + 1.6, 51.6)
	cam.look_at(Vector3(-35.0, Y + 1.25, 48.1), Vector3.UP)
	await _f(30)

	await _album("1_album_a_zero")
	for n in ["p01", "p04", "Polaroid10", "p12", "p16"]:
		GameState.collect(&"polaroid", StringName(n))
	await _album("2_album_dopo_5", 4)
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/prova/torre.json"))
	GameState.prepara_ripresa(data)
	await _album("3_album_dopo_continua_torre")
	print("ALBUM FINITO")
	get_tree().quit()


## Apre la pausa e l'album, fa lo scatto, stampa il contatore e le cornici con la foto; con [param grande] apre quella
## cornice (1-16) e fa anche lo scatto della foto grande. Poi chiude tutto.
func _album(nome: String, grande := 0) -> void:
	Game.set_paused(true)
	await _f(3)
	var overlay := Game.get_node("PauseOverlay") as CanvasLayer
	await _scatto(nome.replace("album", "pausa"))
	for b in overlay.find_children("*", "Button", true, false):
		if (b as Button).text == "Polaroid":
			(b as Button).pressed.emit()
	await _f(5)
	var album := Game.find_child("Album", true, false) as AlbumPolaroid
	if album == null:
		print("%s: l'album non si apre" % nome)
	else:
		var conteggio := album.find_child("Conteggio", true, false) as Label
		var con_foto := 0
		for c in album.cornici():
			for t in c.find_children("*", "TextureRect", true, false):
				if (t as TextureRect).texture != null and (t as TextureRect).visible:
					con_foto += 1
					break
		print("%s: \"%s\", %d cornici, %d con la foto (trovate %d)" % [nome, conteggio.text if conteggio else "-",
				album.cornici().size(), con_foto, PolaroidPhoto.quante_trovate()])
		await _scatto(nome)
		if grande > 0:
			album.cornici()[grande - 1].grab_focus()
			album.cornici()[grande - 1].pressed.emit()
			await _f(10)
			await _scatto(nome + "_foto_%d_grande" % grande)
			var e := InputEventAction.new()
			e.action = &"ui_cancel"
			e.pressed = true
			Input.parse_input_event(e)
			await _f(3)
			var r := InputEventAction.new()
			r.action = &"ui_cancel"
			Input.parse_input_event(r)
			await _f(5)
		album.chiudi()
		await _f(3)
	Game.set_paused(false)
	await _f(5)


func _scatto(nome: String) -> void:
	await _f(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.9)


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame
