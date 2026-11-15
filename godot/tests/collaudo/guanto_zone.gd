extends Node
## Collaudo 0.3.23, il guanto sulla lancia guardando in basso: in tre zone (il livello di prova, gli interni della sala
## dove si sveglia il giocatore, la banchina del fiume lento), con FOV 62, 75 e 90, il giocatore guarda dritto e poi in
## basso a -40, -65 e -85 gradi. A ogni posa uno scatto e le compilazioni di pipeline che fermano il fotogramma
## ("surface" e "draw") da quando il guanto entra in vista; più il fotogramma più lungo (GUANTO:).
## Uso (sotto il render.lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/guanto_zone.gd <cartella>

const LEVEL := "res://scenes/test/test_level.tscn"
const INTERNI := "res://scenes/interni/interni.tscn"
const FIUME := "res://scenes/risalita/fiume.tscn"
const PLAYER := "res://scenes/player/player.tscn"
const INTERNI_NELLA_SALA := Transform3D(Basis.IDENTITY, Vector3(-9.7, 0.0, 40.9))
var cart := ""
var p: Player
var _peggiore := 0.0
var _ultimo := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _process(_d: float) -> void:
	var ora := Time.get_ticks_usec()
	if _ultimo > 0:
		_peggiore = maxf(_peggiore, (ora - _ultimo) / 1000.0)
	_ultimo = ora


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _comp() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))


func _equipaggia() -> void:
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(18.0)


func _zona_prova() -> void:
	get_tree().change_scene_to_file(LEVEL)
	await _frames(30)
	for i in 300:
		p = GameState.player
		if p and p.input_enabled:
			break
		await get_tree().process_frame
	_equipaggia()
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)


func _radice(nome: String) -> Node3D:
	var radice := Node3D.new()
	radice.name = nome
	var look := LookSala.new()
	var we := WorldEnvironment.new()
	we.environment = look.ambiente
	we.camera_attributes = look.attributi_camera
	look.free()
	radice.add_child(we)
	return radice


func _metti(radice: Node3D, xf: Transform3D) -> void:
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	p.name = "Player"
	p.transform = xf
	radice.add_child(p)
	var vecchia := get_tree().current_scene
	get_tree().root.add_child(radice)
	get_tree().current_scene = radice
	if vecchia:
		vecchia.queue_free()
	await _frames(60)
	_equipaggia()


func _zona_interni() -> void:
	var radice := _radice("SoloInterni")
	var interni := (load(INTERNI) as PackedScene).instantiate() as Node3D
	interni.set(&"giocatore_proprio", false)
	interni.transform = INTERNI_NELLA_SALA
	radice.add_child(interni)
	await _metti(radice, INTERNI_NELLA_SALA * (interni.get_node(^"Gioco/Risveglio") as Node3D).transform)


func _zona_fiume() -> void:
	GameState.luci = GameState.Luci.BLACKOUT
	var radice := _radice("SoloFiume")
	var f := (load(FIUME) as PackedScene).instantiate() as Node3D
	radice.add_child(f)
	await _metti(radice, Transform3D(Basis.IDENTITY, Vector3(-5.0, 0.1, -5.0)))
	while not bool(f.get(&"costruita")):
		await get_tree().process_frame


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1] if a.size() > 1 else "/tmp/guanto_zone"
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	for zona in ["prova", "interni", "fiume"]:
		match zona:
			"prova":
				await _zona_prova()
			"interni":
				await _zona_interni()
			"fiume":
				await _zona_fiume()
		print("GUANTO: zona %s, giocatore a %s" % [zona, p.global_position.snappedf(0.01) if p else "?"])
		for fov in [62.0, 75.0, 90.0]:
			Grafica.imposta("fov", fov)
			p.set_look(p.yaw, 0.0)
			await _frames(40)
			for g in [-40.0, -65.0, -85.0]:
				var c0 := _comp()
				_peggiore = 0.0
				p.set_look(p.yaw, deg_to_rad(g))
				await _frames(12)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_jpg(cart.path_join("%s_fov%d_%d.jpg" % [zona, int(fov), int(-g)]), 0.88)
				print("GUANTO: %s fov %d giù %d: compilazioni %d, fotogramma più lungo %.0f ms, fov camera %.1f" % [zona, fov, -g, _comp() - c0, _peggiore, p.camera.fov])
	print("GUANTO FINITO")
	get_tree().quit()
