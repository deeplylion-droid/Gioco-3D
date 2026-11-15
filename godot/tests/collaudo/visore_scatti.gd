extends Node
## Collaudo 0.3.23: il visore delle Polaroid col suggerimento «E · Spazio · clic · A · B per continuare»: raccolta nel
## mondo (la Polaroid01 del livello di prova, col tasto E vero dell'interazione) e riaperta dall'album della pausa (A del
## joypad sulla prima cornice). Scatti e testo del suggerimento (VIS:). La lingua con LINGUA=en.
## Uso (sotto il render.lock): xvfb-run ... --script res://tests/run.gd -- res://tests/collaudo/visore_scatti.gd <cartella> <prefisso>

const LEVEL := "res://scenes/test/test_level.tscn"
var cart := ""
var pre := ""


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(pre + nome + ".jpg"), 0.9)


func _visore() -> CanvasLayer:
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.get_script() == PolaroidPhoto.VIEWER:
			return n
	return null


func _testo(v: CanvasLayer) -> String:
	for l: Label in v.find_children("*", "Label", true, false):
		if l.text.contains("·"):
			return "%s → «%s», dentro lo schermo %s" % [l.text, tr(l.text), get_viewport().get_visible_rect().encloses(l.get_global_rect())]
	return "nessun suggerimento"


func _joy(b: JoyButton) -> void:
	for pr in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = pr
		Input.parse_input_event(e)
		await _frames(3)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	pre = a[2] if a.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	get_tree().change_scene_to_file(LEVEL)
	await _frames(30)
	var p: Player = null
	for i in 300:
		p = GameState.player
		if p and p.input_enabled:
			break
		await get_tree().process_frame
	# una Polaroid vera del capitolo (la P01, nome p01 nella raccolta) messa davanti al giocatore
	GameState.reset_progress()
	var pol := (load(PolaroidPhoto.SCENA) as PackedScene).instantiate() as PolaroidPhoto
	pol.photo = 1
	pol.entry_id = &"p01"
	pol.snap_to_surface = false
	get_tree().current_scene.add_child(pol)
	pol.global_position = p.global_position + Vector3(0, 0.9, -0.8)
	await _frames(20)
	print("VIS: polaroid %s, script %s, puoi usarla %s, già raccolta %s" % [pol, pol.get_script().resource_path, pol.can_interact(p), PolaroidPhoto.trovata(1)])
	pol.interact(p)
	var v := _visore()
	print("VIS: subito dopo E: visore %s, pausa %s" % [v != null, get_tree().paused])
	for i in 20:
		await get_tree().process_frame
		if _visore() == null:
			print("VIS: il visore sparisce al fotogramma %d" % i)
			break
	v = _visore()
	print("VIS: raccolta nel mondo: visore %s; %s" % [v != null, _testo(v) if v else ""])
	await _scatto("raccolta")
	await _joy(JOY_BUTTON_A)
	await _frames(10)
	print("VIS: A lo chiude: %s" % (_visore() == null))
	Game.set_paused(true)
	await _frames(5)
	Game.call(&"open_album")
	await _frames(10)
	var album := Game.find_child("Album", true, false) as AlbumPolaroid
	await _scatto("album")
	(album.cornici()[0] as Control).grab_focus()
	await _frames(3)
	await _joy(JOY_BUTTON_A)
	await _frames(10)
	v = _visore()
	print("VIS: dall'album: visore %s; %s" % [v != null, _testo(v) if v else ""])
	await _scatto("album_foto")
	await _joy(JOY_BUTTON_B)
	await _frames(10)
	print("VIS: B la chiude e resta l'album: %s" % (_visore() == null and is_instance_valid(album)))
	print("VIS: finito")
	get_tree().quit()
