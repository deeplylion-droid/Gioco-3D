extends Node
## Ricontrollo (ambienti-1, 29 ottobre) del rosso dentro la vasca dell'oblò della torre (lavoro/torre-rosso, scelta B
## dell'utente), da lanciare uguale sulla 0.3.15 e sul branch per il confronto. Con la camera vera del giocatore, la torre
## costruita a pezzi e preparata come nel gioco:
## - la vasca vuota prima che lei compaia ("prima_vuota");
## - lei comparsa, dalla strada verso l'oblò a 9, 6, 3,5, 2 e 1,2 m dal vetro, più una da sotto e di lato ("sotto");
## - le condotte dietro la cisterna, dai due lati ("condotte_a", "condotte_b");
## - lei che si stacca e va via, poi la vasca di nuovo vuota ("dopo_vuota").
## Stampa le pipeline compilate alla comparsa e dopo, e il rosso medio del vetro in ogni scatto. Le righe "ERROR: BUG,"
## le cerca chi lancia, nell'uscita.
## Uso (sotto il render.lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan
##   --resolution 1280x720 --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/torre_rosso_a1.gd <cartella> <prefisso>

const PLAYER := "res://scenes/player/player.tscn"
var cartella := ""
var prefisso := ""
var p: Player
var o: ObloLei


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	cartella = a[1]
	prefisso = a[2]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _fotogrammi(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _info() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	var campioni := SalaTorre.materiali_campione()
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	torre.costruzione_a_pezzi = true
	torre.visible = false
	torre.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(torre)
	await torre.costruisci_a_pezzi()
	await torre.prepara_materiali(get_viewport())
	torre.visible = true
	torre.process_mode = Node.PROCESS_MODE_INHERIT
	campioni.clear()
	o = torre.oblo
	await _fotogrammi(20)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	o.set_process(false)
	p.set_physics_process(false)
	var c := o.centro_vetro()
	var n := o.normale()
	var lato := n.cross(Vector3.UP).normalized()
	await _vista("prima_vuota", c + n * 3.5, c, true)
	var base := _info()
	o._mostra()
	await _fotogrammi(90)
	var dopo_comparsa := _info()
	print("ROSSO pipeline alla comparsa di lei: disegno +%d, specializzazione +%d" % [dopo_comparsa[0] - base[0], dopo_comparsa[1] - base[1]])
	for d in [9.0, 6.0, 3.5, 2.0, 1.2]:
		await _vista("lei_%s_m" % str(d), c + n * d, c, true)
	await _vista("sotto", c + n * 2.5 - Vector3.UP * 1.6 + lato * 1.2, c, true)
	var dietro := c - n * 1.8
	await _vista("condotte_a", dietro - lato * 3.6 - Vector3.UP * 1.6, dietro - lato * 1.6, false)
	await _vista("condotte_b", dietro + lato * 3.6 - Vector3.UP * 1.6, dietro + lato * 1.6, false)
	o.set_process(true)
	o.via()
	var t0 := Time.get_ticks_msec()
	while o.stato != ObloLei.Stato.FINITA and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	o.set_process(false)
	print("ROSSO dopo il distacco: stato %d, lei %s" % [o.stato, "c'è ancora" if (o.lei and is_instance_valid(o.lei) and o.lei.is_visible_in_tree()) else "non c'è più"])
	await _vista("dopo_vuota", c + n * 3.5, c, true)
	var fine := _info()
	print("ROSSO pipeline dopo la comparsa, in tutti gli scatti e nel distacco: disegno +%d, specializzazione +%d" % [fine[0] - dopo_comparsa[0], fine[1] - dopo_comparsa[1]])
	get_tree().quit()


## Mette gli occhi del giocatore in [param occhi] (la camera vera) e guarda [param verso].
func _vista(nome: String, occhi: Vector3, verso: Vector3, vetro: bool) -> void:
	var testa := p.camera.global_position - p.global_position
	p.global_position = occhi - testa
	await _fotogrammi(2)
	p.look_at_point(verso)
	await _fotogrammi(40)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(cartella.path_join("%s_%s.jpg" % [prefisso, nome]), 0.92)
	if vetro:
		var cen := p.camera.unproject_position(o.centro_vetro())
		var r := int(clampf(1100.0 / maxf(occhi.distance_to(o.centro_vetro()), 0.5), 20.0, 300.0))
		var s := Color(0, 0, 0)
		var k := 0
		for y in range(int(cen.y) - r, int(cen.y) + r, 3):
			for x in range(int(cen.x) - r, int(cen.x) + r, 3):
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					s += img.get_pixel(x, y)
					k += 1
		s /= maxf(k, 1)
		print("ROSSO %-14s vetro (%d px): R %.1f G %.1f B %.1f" % [nome, r, s.r * 255, s.g * 255, s.b * 255])
	else:
		print("ROSSO scatto ", nome)
