extends Node
## Collaudo della nebbia viola nel gioco (ambienti-2, 29 ottobre), col renderer vero: la nebbia del gioco (Grafica.nebbia_viola)
## nelle sue zone, accesa come quando il giocatore ci entra (la zona del livello, subito), dagli occhi del giocatore.
## Prima il riscaldamento della schermata di caricamento, come nel gioco. Per ogni vista lo scatto senza e con la nebbia,
## e le pipeline compilate accendendola (attese: 0 draw).
## Parti (una per processo, per la memoria):
## - sala: la sala ridotta (tests/scena_ridotta.gd), la vista lunga verso la torre, gli acquari, un cancello, una
##   Polaroid; poi col preset basso (nebbia semplice, 10 passi) la vista lunga e gli acquari;
## - infermeria: l'infermeria da sola con la sua luce, dall'ingresso e dal fondo;
## - tunnel: il tunnel costruito a pezzi, lei che risale vicina (la sua luce nell'alone), ai gommoni e sulla banchina.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 30 --script res://tests/run.gd -- res://tests/collaudo/scatti_nebbia_gioco.gd <cartella> <parte>

const TOGLI := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Atmosfera", "Sala/TorreScivoli", "Sala/Dettagli", "Sala/AreaBimbi", "Vasca", "Gioco/LeiSbuca"]

var out := ""
var cam: Camera3D
var n: NebbiaViola


func _ready() -> void:
	_run.call_deferred()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _pipeline() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[1]
	var parte: String = a[2]
	DirAccess.make_dir_recursive_absolute(out)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("medio")
	n = Grafica.nebbia_viola
	# il riscaldamento della schermata di caricamento (non per la sala: con tutti i materiali del gioco caricati la sala,
	# anche ridotta, non ci sta nella memoria della macchina di prova; le pipeline si contano nel tunnel e nell'infermeria)
	if parte != "sala":
		await _riscalda()
	match parte:
		"sala":
			await _sala()
		"infermeria":
			await _infermeria()
		"tunnel":
			await _tunnel()
	get_tree().quit()


func _riscalda() -> void:
	var env := WorldEnvironment.new()
	env.environment = RiscaldamentoShader.ambiente()
	add_child(env)
	var r := RiscaldamentoShader.new()
	add_child(r)
	while not r.concluso:
		await get_tree().process_frame
	r.queue_free()
	env.queue_free()
	await _frames(5)


func _camera() -> void:
	cam = Camera3D.new()
	cam.near = 0.05
	cam.fov = 75.0
	get_tree().root.add_child(cam)
	cam.make_current()


## Senza e con la nebbia (la zona [param zona] come se il giocatore ci entrasse), dalla stessa camera.
func _coppia(nome: String, da: Vector3, verso: Vector3, zona: Node) -> void:
	cam.look_at_from_position(da, verso, Vector3.UP)
	n.zona(zona, false, true)
	await _frames(40)
	await _scatto(nome + "_senza")
	var prima := _pipeline()
	n.zona(zona, true, true)
	await _frames(40)
	var dopo := _pipeline()
	await _scatto(nome + "_nebbia")
	print("PIPELINE %s accendendo la nebbia: draw +%d, specializzazione +%d" % [nome, dopo[0] - prima[0], dopo[1] - prima[1]])


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out.path_join(nome + ".jpg"), 0.88)
	print("SCATTO ", nome)


func _sala() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	get_tree().change_scene_to_file(load("res://tests/scena_ridotta.gd").riduci("res://scenes/sala_principale.tscn", TOGLI))
	while get_tree().current_scene == null or get_tree().current_scene == self:
		await get_tree().process_frame
	var level := get_tree().current_scene
	var pl := level.get_node_or_null(^"Player") as Node3D
	if pl:
		pl.process_mode = Node.PROCESS_MODE_DISABLED
		pl.global_position = Vector3(12.0, 0.0, -40.0)
		var hud := pl.get_node_or_null(^"HUD")
		if hud:
			hud.set(&"visible", false)
	_camera()
	await _frames(120)
	var zone := level.find_children("*", "ZonaNebbiaViola", true, false)
	var zona: Node = zone[0] if not zone.is_empty() else null
	print("ZONA ", level.get_path_to(zona) if zona else "nessuna")
	await _coppia("sala_1_verso_la_torre", Vector3(-12.0, 1.6, 0.0), Vector3(20.0, 1.2, 0.0), zona)
	var acq := level.get_node_or_null(^"Gioco/EnigmaAcquari") as Node3D
	var acq_pos := acq.global_position if acq else Vector3(-15, 1, -15)
	for m in (acq.find_children("*", "MeshInstance3D", true, false) if acq else []):
		acq_pos = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb().get_center()
		break
	print("ACQUARI in ", acq_pos)
	await _coppia("sala_2_acquari", acq_pos + Vector3(0, 1.6 - acq_pos.y, 0) + (Vector3(0, 0, 0) - acq_pos).normalized() * 4.5 * Vector3(1, 0, 1), acq_pos, zona)
	# gli acquari in tutti gli stati: vuoti (prima del magazzino), pieni, il miscuglio verde e torbido
	if acq:
		await _acquari(acq as EnigmaAcquari, zona)
	var cancello := _vicino(level, ["cancell", "Cancell", "grata", "Grata"])
	if cancello:
		var c := cancello.global_position
		print("CANCELLO ", level.get_path_to(cancello), " in ", c)
		await _coppia("sala_3_cancello", Vector3(c.x, 1.6, c.z) + (Vector3(0, 0, 0) - c).normalized() * 4.0 * Vector3(1, 0, 1), c + Vector3(0, 1.0, 0), zona)
	var pol: Node3D = null
	for x in level.find_children("*", "PolaroidPhoto", true, false):
		var q := (x as Node3D).global_position
		if absf(q.x) < 19.0 and q.z > -23.0 and q.z < 19.0:
			pol = x
			break
	if pol:
		var q := pol.global_position
		print("POLAROID ", level.get_path_to(pol), " in ", q)
		var verso_centro := (Vector3(0, q.y, 0) - q).normalized()
		await _coppia("sala_4_polaroid", q + verso_centro * 1.8 + Vector3(0, 1.6, 0), q + Vector3(0, 0.05, 0), zona)
	# il preset basso: la nebbia semplice, 10 passi
	Grafica.applica_preset("basso")
	await _frames(30)
	await _coppia("sala_5_basso_verso_la_torre", Vector3(-12.0, 1.6, 0.0), Vector3(20.0, 1.2, 0.0), zona)
	await _coppia("sala_6_basso_acquari", acq_pos + Vector3(0, 1.6 - acq_pos.y, 0) + (Vector3(0, 0, 0) - acq_pos).normalized() * 4.5 * Vector3(1, 0, 1), acq_pos, zona)


func _vicino(level: Node, parole: Array) -> Node3D:
	var meglio: Node3D = null
	var d := 1e9
	for x in level.find_children("*", "Node3D", true, false):
		var nome := String(x.name)
		if not parole.any(func(w): return nome.contains(w)):
			continue
		var q := (x as Node3D).global_position
		if absf(q.x) > 19.0 or q.z < -23.0 or q.z > 19.0 or q.y < -3.0:
			continue
		var dd := q.length()
		if dd < d:
			d = dd
			meglio = x
	return meglio


func _infermeria() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.1, 0.09, 0.1)
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.15
	e.ssao_enabled = true
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.015
	we.environment = e
	get_tree().root.add_child(we)
	var f: Node3D = (load("res://scenes/risalita/infermeria.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(f)
	_camera()
	await _frames(60)
	var zone := f.find_children("*", "ZonaNebbiaViola", true, false)
	var zona: Node = zone[0] if not zone.is_empty() else f
	print("ZONA ", f.get_path_to(zona))
	await _coppia("infermeria_1_ingresso", Vector3(1.6, 1.6, 2.7), Vector3(-0.5, 1.0, -2.5), zona)
	await _coppia("infermeria_2_negatoscopio", Vector3(0.5, 1.6, -1.2), Vector3(0.5, 1.4, -3.2), zona)


func _tunnel() -> void:
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var sala := (load("res://scenes/sala/sottomarino/sala_sottomarino.tscn") as PackedScene).instantiate() as SalaSottomarino
	add_child(sala)
	await sala.costruisci_a_pezzi()
	await _frames(20)
	_camera()
	var zone := sala.find_children("*", "ZonaNebbiaViola", true, false)
	var zona: Node = zone[0] if not zone.is_empty() else sala
	print("ZONA ", sala.get_path_to(zona))
	for v in [["tunnel_1_gommoni_lei", 74.0, 64.0, 69.0], ["tunnel_2_banchina_lei", 30.0, 22.0, 25.0], ["tunnel_3_testa", 2.0, 14.0, -1.0]]:
		var da := _occhio(sala, v[1], -1.0, 1.6)
		var verso := _occhio(sala, v[2], 0.0, 1.2)
		cam.look_at_from_position(da, verso, Vector3.UP)
		if float(v[3]) >= 0.0:
			var dove := sala.punto(float(v[3]))
			dove.y = sala.acqua
			sala.lei_tunnel.riemergi(dove, da - dove)
			await _frames(150)
		await _coppia(v[0], da, verso, zona)


func _occhio(sala: SalaSottomarino, s: float, lato: float, su: float) -> Vector3:
	var di_lato := lato * sala.canale if absf(lato) < 0.99 else signf(lato) * (sala.canale + sala.banchina * 0.5)
	return sala.punto(s) + sala.destra(s) * di_lato + Vector3.UP * (sala.piano - sala.acqua + su)


func _acquari(e: EnigmaAcquari, zona: Node) -> void:
	var tanks := [e._giallo, e._blu, e._misto]
	var c := Vector3.ZERO
	for tk in tanks:
		c += (tk as Node3D).global_position
	c /= 3.0
	var verso := (Vector3(0, c.y, 0) - c).normalized()
	var da := c + verso * 6.5
	da.y = 1.6
	var guarda := c + Vector3(0, 1.2, 0)
	e._mostra(false)
	await _frames(20)
	await _coppia("acquari_1_vuoti", da, guarda, zona)
	e._mostra(true)
	await _frames(20)
	await _coppia("acquari_2_pieni", da, guarda, zona)
	e._misto.fill = e._misto.max_fill
	e._misto.set_mix({WaterMix.GIALLO: 0.5, WaterMix.BLU: 0.5})
	await _frames(20)
	await _coppia("acquari_3_miscuglio_verde", da, guarda, zona)
	e._misto.set_mix({WaterMix.GIALLO: 0.8, WaterMix.BLU: 0.2})
	await _frames(20)
	await _coppia("acquari_4_miscuglio_sbagliato", da, guarda, zona)
	for i in 3:
		var tk := tanks[i] as Node3D
		var p := tk.global_position
		var v := (Vector3(0, p.y, 0) - p).normalized()
		await _coppia("acquari_5_vicino_%d" % i, p + v * 3.0 + Vector3(0, 1.6 - p.y, 0), p + Vector3(0, 1.0, 0), zona)

