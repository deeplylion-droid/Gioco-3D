extends Node
## Scatti del finale del tunnel (build 0.5.0) dagli occhi del giocatore vero, nella camera stagna: chiude il portello e
## si scatta a ogni tappa (appena girato, coi due passi fatti, sul foglio), più la stanza vuota prima di chiudere.
## Per il collaudo e per il coordinatore.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 30 --script res://tests/run.gd -- res://tests/scatti_finale.gd <cartella>

var cartella := "/tmp/scatti_finale"
var sala: SalaSottomarino
var _pl: Player


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _scatta(nome: String) -> void:
	var f := cartella.path_join(nome + ".jpg")
	get_viewport().get_texture().get_image().save_jpg(f, 0.9)
	print("scatto -> ", f)


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = true
	env.environment.sdfgi_cascades = 3
	env.environment.volumetric_fog_density = 0.009
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	sala = SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	if OS.get_environment("A_PEZZI") != "":
		# (come nel gioco: a pezzi, col riscaldamento dei materiali, di lei e dei bambini del finale)
		await sala.costruisci_a_pezzi()
	else:
		sala.costruisci()
	_pl = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(_pl)
	var L := sala.lunghezza()
	var d := sala.direzione(L)
	var sg := sala.piano + SalaSottomarino.SOGLIA
	var dentro := sala.punto(L) + d * 1.2
	dentro.y = sg + 0.05
	await _fotogrammi(2)
	_pl.water_pack.set_equipped(true, false)
	_pl.teleport(dentro, atan2(-d.x, -d.z))   # (di spalle al portello: guarda la stanza)
	await _fotogrammi(60)
	_scatta("00_stanza_vuota")
	if OS.get_environment("SOLO_BRACCIO") != "":
		# (lo scatto stretto sul braccio, senza tutta la sequenza: il bambino col cubo porge davvero il foglio)
		var occhi_b := sala.punto(L) + d * SalaSottomarino.CAMERA_DOVE_GUARDA
		occhi_b.y = sg + 0.05
		_pl.teleport(occhi_b, atan2(-d.x, -d.z))
		_pl.input_enabled = false
		await sala.mostra_finale_per_controllo(true)
		await _fotogrammi(20)
		var b1: Node3D = sala._bambini_finale[0]
		_pl.look_at_point(b1.global_position + Vector3.UP * 0.7)
		var v1 := _pl.get_eye_position() - b1.global_position
		v1.y = 0.0
		var a1 := b1.global_basis.z
		a1.y = 0.0
		print("DI LATO: a %.2f m in pianta, %.1f gradi dal davanti del bambino col cubo" % [v1.length(), rad_to_deg(a1.normalized().angle_to(v1.normalized()))])
		await _stretto(b1)
		get_tree().quit()
		return
	if OS.get_environment("SOLO_STANZA") != "":
		# (prova veloce della luce: i bambini accesi e fermi, dagli occhi del giocatore a 2,2 m dal portello)
		var occhi := sala.punto(L) + d * SalaSottomarino.CAMERA_DOVE_GUARDA
		occhi.y = sg + 0.05
		_pl.teleport(occhi, atan2(-d.x, -d.z))
		for b in sala._bambini_finale:
			b.visible = true
			b.process_mode = Node.PROCESS_MODE_INHERIT
		var luce := sala.find_child("LuceStanza", true, false) as Light3D
		print("LUCE ", luce, " ", luce.global_position if luce else "", " verso ", -luce.global_basis.z if luce else "")
		await _fotogrammi(1)
		_pl.look_at_point(sala._bambini_finale[0].global_position + Vector3.UP * 0.7)
		await _fotogrammi(50)
		_scatta("01_prova_luce")
		get_tree().quit()
		return
	_pl.teleport(dentro, atan2(d.x, d.z))     # (verso il portello)
	await _fotogrammi(10)
	var fatte := {}
	sala.fase_finale_cambiata.connect(func(f: String):
		fatte[f] = Engine.get_process_frames()
		print("PIPELINE all'inizio di %s: %s" % [f, _pipeline()]))
	sala.chiudi_portello()
	var t0 := Time.get_ticks_msec()
	while not fatte.has("fermi") and Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
	await _fotogrammi(12)
	_scatta("01_fermo_col_foglio")
	while not fatte.has("porge") and Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
	# a metà del gesto (0,6 s dopo che comincia a porgere) e nella posa finale, prima che la camera scenda
	var gesto := [false]
	var bc: Node = sala._bambini_finale[0]
	if bc.has_signal(&"porge_il_foglio"):
		bc.connect(&"porge_il_foglio", func(): gesto[0] = true, CONNECT_ONE_SHOT)
	while not gesto[0] and not fatte.has("foglio") and Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
	await _fotogrammi(18)
	_scatta("02_meta_gesto")
	while not fatte.has("foglio") and Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
	_scatta("02b_posa_finale")
	# dagli stessi occhi (durante il finale il giocatore non si muove: i comandi sono spenti), stretto sul bambino col
	# cubo per vedere gli stracci dell'avambraccio; e quanto è di lato: l'angolo fra dove guarda lui e il giocatore
	var b0: Node3D = sala._bambini_finale[0]
	var occhio := _pl.get_eye_position()
	var verso := occhio - b0.global_position
	verso.y = 0.0
	var avanti := b0.global_basis.z
	avanti.y = 0.0
	print("DI LATO: a %.2f m in pianta, %.1f gradi dal davanti del bambino col cubo" % [verso.length(), rad_to_deg(avanti.normalized().angle_to(verso.normalized()))])
	await _stretto(b0)
	while sala.fase_finale == "foglio" and Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		if Engine.get_process_frames() - int(fatte["foglio"]) == int(30 * (sala.finale_abbassa + 1.5)):
			_scatta("03_sul_foglio")
	print("PIPELINE alla fine: %s" % [_pipeline()])
	print("fasi: ", fatte)
	get_tree().quit()


## Le pipeline compilate finora: [draw, specialization, surface, mesh] (RenderingServer).
static func _pipeline() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH)]


## Dagli occhi del giocatore, una camera stretta (28 gradi) sul busto del bambino [param b]: lo scatto 04.
func _stretto(b: Node3D) -> void:
	# (la camera del giocatore, col giocatore fermo per lo scatto: lui la rimette a ogni fotogramma)
	var cam := _pl.camera
	var fov := cam.fov
	_pl.look_at_point(b.global_position + Vector3.UP * 0.65)
	await _fotogrammi(2)
	_pl.process_mode = Node.PROCESS_MODE_DISABLED
	cam.fov = 28.0
	await _fotogrammi(12)
	_scatta("04_stretto_sul_braccio")
	cam.fov = fov
	_pl.process_mode = Node.PROCESS_MODE_INHERIT
