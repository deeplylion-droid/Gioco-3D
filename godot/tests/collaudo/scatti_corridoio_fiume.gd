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
## "veloce": per le prove, meno fotogrammi per scatto e senza le stanze del fiume e dell'infermeria (si vedono solo dalla
## porta del capannone)
var _veloce := false


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
	# "solo=a,b": solo gli scatti col nome che comincia così (per le prove)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("solo=") and not Array(a.substr(5).split(",")).any(func(x): return nome.begins_with(x)):
			return
	_guarda(occhio, punto)
	await _frames(14 if _veloce else 40)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_cartella)
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join(nome + ".jpg"), 0.9)
	print("scatto ", nome, " ", occhio)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://scatti_corridoio_fiume"
	_veloce = OS.get_cmdline_user_args().has("veloce")
	if _veloce:
		var sc := (load("res://tests/scene/risalita_prova.tscn") as PackedScene).instantiate()
		var r := sc.get_node(^"Risalita")
		r.set(&"a_richiesta", true)
		r.set_process(false)
		get_tree().change_scene_to_node(sc)
	else:
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
	# l'ambiente della sala (nel gioco la Risalita sta nella sala principale, con LookSala): riflessi e luce d'ambiente
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	# (senza GI, nebbia volumetrica e SSIL: con la Risalita intera, fiume compreso, llvmpipe passava i 12,5 GB; i
	# riflessi dello schermo, che fanno la pozza, restano)
	env.environment.sdfgi_enabled = false
	env.environment.volumetric_fog_enabled = false
	env.environment.ssil_enabled = false
	get_tree().current_scene.add_child(env)
	var ris := get_tree().current_scene.get_node(^"Risalita")
	var b := ris.find_child("BambinoCorridoioFiume", true, false) as Node3D
	if b:
		b.process_mode = Node.PROCESS_MODE_DISABLED
		b.visible = false
	var oblo := ris.find_child("ObloFiume", true, false) as ObloLei
	if oblo:
		oblo.attivo = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	if _veloce:
		ris.set_process(false)
		for k in [&"fiume", &"infermeria"]:
			var n: Node = ris.get(k)
			if n:
				n.queue_free()
	var m := ris.get_node(^"Marker")
	var cima := (m.get_node(^"CimaScalaFiume") as Node3D).global_position
	var fondo := (m.get_node(^"FondoScalaFiume") as Node3D).global_position
	var porta := (m.get_node(^"PortaFiume") as Node3D).global_position
	_guarda(cima + Vector3.UP * 1.6, fondo + Vector3.UP)
	for i in 1800:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > (30 if _veloce else 300):
			break
	var e := Vector3.UP * 1.6
	var solo_giro := _cartella.ends_with("_giro") or OS.get_cmdline_user_args().has("giro")
	# il corridoio: dal pianerottolo in fondo alla scala verso nord, a metà (all'oblò), dalla porta indietro
	await _scatto("1_corridoio_dal_fondo_scala", fondo + e + Vector3(0, 0, 1.2), porta + Vector3(0, 1.2, 1.0))
	await _scatto("2_corridoio_meta", Vector3(fondo.x - 0.3, fondo.y + 1.6, 55.0), porta + Vector3(0.3, 1.0, 1.0))
	await _scatto("3_corridoio_indietro", porta + e + Vector3(0.2, 0, 0.3), fondo + Vector3(0.2, 1.2, -0.5))
	await _scatto("3b_dalla_scala", cima + e + Vector3(-1.5, 0, 0), fondo + Vector3(-0.6, 0.6, 1.5))
	if OS.get_cmdline_user_args().has("ravvicinati"):
		# gli scatti ravvicinati di ogni oggetto appeso o appoggiato (arredo A+C del 30 ottobre), da 60-90 cm
		var Y := fondo.y
		var o := -5.9
		for v in [
				["r01_tubi_dal_muro_sala_pompe", Vector3(-5.0, Y + 1.7, 49.6), Vector3(-5.8, Y + 2.3, 48.25)],
				["r02_quadro", Vector3(-5.0, Y + 1.6, 52.4), Vector3(o, Y + 1.5, 52.4)],
				["r03_quadro_di_lato", Vector3(-5.2, Y + 1.5, 51.6), Vector3(o, Y + 1.5, 52.4)],
				["r04_fusti_e_secchio", Vector3(-4.9, Y + 1.2, 54.2), Vector3(o + 0.25, Y + 0.3, 54.3)],
				["r05_fusti_base", Vector3(-5.0, Y + 0.6, 53.0), Vector3(o + 0.25, Y + 0.05, 53.9)],
				["r06_valvola", Vector3(-4.9, Y + 1.7, 53.3), Vector3(o + 0.2, Y + 2.25, 54.0)],
				["r07_carrello", Vector3(-4.9, Y + 1.3, 56.0), Vector3(o + 0.2, Y + 0.6, 56.0)],
				["r08_carrello_base", Vector3(-5.0, Y + 0.6, 57.0), Vector3(o + 0.25, Y + 0.05, 56.2)],
				["r09_muffa_ovest", Vector3(-4.3, Y + 1.5, 58.3), Vector3(o, Y + 1.0, 58.3)],
				["r10_oblo_muffa_e_colatura", Vector3(-5.2, Y + 1.4, 57.6), Vector3(-3.9, Y + 0.9, 57.9)],
				["r11_pozza_e_p13", Vector3(-5.3, Y + 1.5, 57.2), Vector3(-4.6, Y, 58.6)],
				["r12_griglia_e_pozza", Vector3(-4.8, Y + 1.3, 59.6), Vector3(o + 0.3, Y, 60.3)],
				["r13_cartello", Vector3(-5.0, Y + 1.55, 61.6), Vector3(o, Y + 1.5, 62.3)],
				["r14_tubi_nel_muro_capannone", Vector3(-4.8, Y + 1.8, 62.4), Vector3(o, Y + 2.3, 63.5)],
				["r15_tubi_collare", Vector3(-5.1, Y + 1.8, 58.5), Vector3(o + 0.08, Y + 2.25, 59.3)]]:
			await _scatto(v[0], v[1], v[2])
	else:
		# dentro il capannone: dalla porta verso l'imbarco
		await _scatto("4_capannone_ingresso", porta + e + Vector3(-1.5, 0, 0), porta + Vector3(-12.0, 1.2, 0))
	get_tree().quit(0)
