extends Node
## Scatti dal motore, dagli occhi del giocatore, dei passaggi della risalita subito prima del fiume lento (riscontro
## dell'utente sulla v0.3.16, "c'è un corridoio vuoto prima della zona del fiume"): il corridoio in fondo alla scala
## con l'oblò di lei e, dentro il capannone, il passaggio fra le pile verso l'imbarco. Luci del gioco (blackout dopo il
## risveglio della sala pompe); il bambino e lei dell'oblò fermi, per vedere il corridoio com'è.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_corridoio_fiume.gd <cartella>

var _p: Player
var _cartella := ""


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _guarda(occhio: Vector3, punto: Vector3) -> void:
	_p.global_position = occhio - Vector3.UP * (_p.get_eye_position().y - _p.global_position.y)
	_p.look_at_point(punto)
	_p.camera.global_transform = _p.get_aim_transform()


func _scatto(nome: String, occhio: Vector3, punto: Vector3) -> void:
	_guarda(occhio, punto)
	await _frames(40)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_cartella)
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join(nome + ".jpg"), 0.9)
	print("scatto ", nome, " ", occhio)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://scatti_corridoio_fiume"
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	_p = GameState.player
	_p.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := _p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	_p.camera.make_current()
	var ris := get_tree().current_scene.get_node(^"Risalita")
	var b := ris.find_child("BambinoCorridoioFiume", true, false) as Node3D
	if b:
		b.process_mode = Node.PROCESS_MODE_DISABLED
		b.visible = false
	var oblo := ris.find_child("ObloFiume", true, false) as ObloLei
	if oblo:
		oblo.attivo = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var m := ris.get_node(^"Marker")
	var cima := (m.get_node(^"CimaScalaFiume") as Node3D).global_position
	var fondo := (m.get_node(^"FondoScalaFiume") as Node3D).global_position
	var porta := (m.get_node(^"PortaFiume") as Node3D).global_position
	_guarda(cima + Vector3.UP * 1.6, fondo + Vector3.UP)
	for i in 1800:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 300:
			break
	var e := Vector3.UP * 1.6
	# il corridoio: dal pianerottolo in fondo alla scala verso nord, a metà (all'oblò), dalla porta indietro
	await _scatto("1_corridoio_dal_fondo_scala", fondo + e + Vector3(0, 0, 1.2), porta + Vector3(0, 1.2, 1.0))
	await _scatto("2_corridoio_meta", Vector3(fondo.x - 0.3, fondo.y + 1.6, 55.0), porta + Vector3(0.3, 1.0, 1.0))
	await _scatto("3_corridoio_indietro", porta + e + Vector3(0.2, 0, 0.3), fondo + Vector3(0.2, 1.2, -0.5))
	# dentro il capannone: dalla porta verso l'imbarco, fra le pile
	await _scatto("4_capannone_ingresso", porta + e + Vector3(-1.5, 0, 0), porta + Vector3(-12.0, 1.2, 0))
	await _scatto("5_capannone_fra_le_pile", porta + e + Vector3(-9.0, 0, 0), porta + Vector3(-20.0, 1.2, 0))
	get_tree().quit(0)
