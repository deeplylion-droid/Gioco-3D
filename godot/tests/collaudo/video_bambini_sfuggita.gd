extends Node
## Video dal motore dei bambini visti di sfuggita (BambinoSfuggita), dagli occhi del giocatore, per la proposta
## all'utente (docs/proposte/bambini_sfuggita). Il giocatore è fermo (lo muove questo script, a passo d'uomo) e il
## bambino fa da solo: compare fuori vista, guarda, scappa.
## Uso (sotto il render.lock): salva i fotogrammi della scena (a 30 al secondo di gioco) in <cartella>/fotogrammi e
## lo scatto in <cartella>; il video si monta con ffmpeg (tools/video_da_fotogrammi o a mano).
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 30 --script res://tests/run.gd -- \
##     res://tests/collaudo/video_bambini_sfuggita.gd corridoio|galleria <cartella>
## "corridoio": il corridoio del fiume nella risalita (scena di prova); "galleria": il tunnel sottomarino.

var _p: Player
var _cartella := ""
var _registra := false
var _n := 0


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var cosa := a[1] if a.size() > 1 else "corridoio"
	_cartella = a[2] if a.size() > 2 else ""
	if cosa == "galleria":
		await _galleria()
	else:
		await _corridoio()
	get_tree().quit(0)


## Lo sguardo e la camera insieme (il giocatore non si muove da solo).
func _guarda(occhio: Vector3, punto: Vector3) -> void:
	_p.global_position = occhio - Vector3.UP * (_p.get_eye_position().y - _p.global_position.y)
	_p.look_at_point(punto)
	_p.camera.global_transform = _p.get_aim_transform()


## Da [param da] a [param a] (occhi) in [param secondi], guardando da [param mira_da] a [param mira_a], con un
## dondolio del passo.
func _cammina(da: Vector3, a: Vector3, mira_da: Vector3, mira_a: Vector3, secondi: float) -> void:
	var n := int(secondi * 30.0)
	for i in n + 1:
		var f := float(i) / maxf(n, 1)
		var e := f * f * (3.0 - 2.0 * f)
		var bob := sin(f * secondi * 2.0 * TAU * 0.9) * 0.025 if da.distance_to(a) > 0.1 else 0.0
		_guarda(da.lerp(a, e) + Vector3.UP * bob, mira_da.lerp(mira_a, e))
		await _fotogramma()


## Un fotogramma del video (se si registra): aspetta il disegno e lo salva.
func _fotogramma() -> void:
	await get_tree().process_frame
	if not _registra or _cartella == "":
		return
	await RenderingServer.frame_post_draw
	var d := _cartella.path_join("fotogrammi")
	DirAccess.make_dir_recursive_absolute(d)
	get_viewport().get_texture().get_image().save_jpg(d.path_join("%05d.jpg" % _n), 0.92)
	_n += 1


func _scatto(nome: String) -> void:
	if _cartella == "":
		return
	DirAccess.make_dir_recursive_absolute(_cartella)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join(nome + ".jpg"), 0.9)


func _giocatore() -> void:
	_p = GameState.player
	if _p == null:
		_p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
		add_child(_p)
		GameState.player = _p
	_p.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := _p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	_p.camera.make_current()


func _corridoio() -> void:
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	_giocatore()
	var ris := get_tree().current_scene.get_node(^"Risalita")
	var b := ris.find_child("BambinoCorridoioFiume", true, false) as BambinoSfuggita
	var oblo := ris.find_child("ObloFiume", true, false) as ObloLei
	if oblo:
		oblo.attivo = false    # (nel video solo il bambino: lei dell'oblò c'è già nel gioco)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var m := ris.get_node(^"Marker")
	var cima := (m.get_node(^"CimaScalaFiume") as Node3D).global_position
	var fondo := (m.get_node(^"FondoScalaFiume") as Node3D).global_position
	var porta := (m.get_node(^"PortaFiume") as Node3D).global_position
	# le stanze vicine caricate, il bambino pronto (in attesa, preparato fuori vista)
	_guarda(cima + Vector3.UP * 1.6, fondo + Vector3.UP * 1.0)
	for i in 1800:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 300:
			break
	# giù per la scala, verso ovest, poi in fondo girati verso nord: il corridoio
	_registra = true
	# (un passo dentro il corridoio: dal pianerottolo lo spigolo del muro copriva mezza inquadratura)
	var occhio_fondo := Vector3(fondo.x, fondo.y + 1.6, fondo.z + 1.4)
	await _cammina(cima + Vector3.UP * 1.6, occhio_fondo, fondo + Vector3(-2.0, 1.0, 0), fondo + Vector3(-2.0, 1.2, 0.5), 5.5)
	var lontano := Vector3(fondo.x + 0.4, fondo.y + 1.4, porta.z + 1.0)
	await _cammina(occhio_fondo, occhio_fondo, fondo + Vector3(-2.0, 1.2, 0.5), lontano, 1.6)
	await _frames(20)
	await _scatto("corridoio_fiume")
	# fermo a guardarlo, poi qualche passo avanti mentre scappa
	var t := 0.0
	while t < 6.0 and b.stato == BambinoSfuggita.Stato.GUARDA:
		_guarda(occhio_fondo, b.bambino.punto_testa())
		await _fotogramma()
		t += 1.0 / 30.0
	var avanti := occhio_fondo + Vector3(0, 0, 4.0)
	await _cammina(occhio_fondo, avanti, b.bambino.punto_testa(), porta + Vector3(-1.0, 1.0, 0), 3.0)
	for i in 45:
		await _fotogramma()


func _galleria() -> void:
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = true
	env.environment.sdfgi_cascades = 3
	env.environment.volumetric_fog_density = 0.009
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	_giocatore()
	var sala := SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	sala.costruisci()
	var b := sala.find_child("BambinoGalleria", true, false) as BambinoSfuggita
	await _frames(240)    # (il riscaldamento del bambino, a schermo nero nel gioco)
	var occhi := func(s: float, u: float) -> Vector3:
		return sala.punto(s) * Vector3(1, 0, 1) - sala.destra(s) * u + Vector3.UP * (sala.piano + 1.6)
	var s0 := 190.0
	var bocca := 203.6
	# di corsa sulla banchina sinistra verso la galleria, poi ci si ferma a guardarlo
	_registra = true
	await _cammina(occhi.call(s0 - 18.0, 3.9), occhi.call(s0, 3.9), occhi.call(s0 + 4.0, 3.9), occhi.call(bocca, 4.0), 4.5)
	await _scatto("galleria_tunnel")
	var t := 0.0
	var qui: Vector3 = occhi.call(s0, 3.9)
	while t < 6.0 and b.stato != BambinoSfuggita.Stato.FINITO:
		_guarda(qui, b.bambino.punto_testa() if b.stato != BambinoSfuggita.Stato.ATTESA else occhi.call(bocca, 4.0))
		await _fotogramma()
		t += 1.0 / 30.0
	await _cammina(qui, occhi.call(s0 + 6.0, 3.9), occhi.call(bocca, 4.4), occhi.call(bocca + 1.0, 5.4), 3.0)
	for i in 30:
		await _fotogramma()
