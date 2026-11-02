extends Node
## Video dal motore del bambino col cubo del corridoio del fiume (BambinoCorridoioFiume), dagli occhi del giocatore, nei
## casi in cui compare (scelta A dell'utente del 1° novembre: "A ma animalo meglio"; la regola resta: solo dopo lei
## all'oblò, mai sotto gli occhi). Lei all'oblò è già finita (il video comincia dopo); il bambino fa da solo.
##  - fermati: fermo a metà corridoio, girato verso la scala; quando compare ti giri, lo guardi (respiro, testa che ti
##    segue, testa inclinata), lui scappa nella porta del capannone e tu lo segui con lo sguardo;
##  - polaroid: accovacciato alla Polaroid 13 sotto l'oblò; compare alle spalle e scappa subito: ti giri di scatto e
##    lo vedi correre;
##  - vicino: a 5 m da lui, per guardare i piedi, la partenza e la svolta nella porta da vicino;
##  - indietro: torni dal capannone verso la scala; compare alle spalle, ti giri.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 30 --script res://tests/run.gd -- res://tests/collaudo/video_bambino_cubo.gd <caso> <cartella>
## I fotogrammi in <cartella>/<caso>/; in <cartella>/<caso>.txt cosa succede e quando.

var _p: Player
var _b: BambinoSfuggita
var _cartella := ""
var _n := 0
var _diario: Array[String] = []
var _stato := -1
## La camera di studio (vicina, di fianco: non è quella del giocatore e non cambia niente nel gioco), se il caso finisce
## con "_studio": i fotogrammi in <cartella>/<caso>_cam/.
var _studio: SubViewport
var _cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var caso := a[1] if a.size() > 1 else "fermati"
	_cartella = (a[2] if a.size() > 2 else "user://video_bambino").path_join(caso)
	DirAccess.make_dir_recursive_absolute(_cartella)
	var studio := caso.ends_with("_studio")
	caso = caso.trim_suffix("_studio")
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
	_b = ris.find_child("BambinoCorridoioFiume", true, false) as BambinoSfuggita
	var oblo := ris.find_child("ObloFiume", true, false) as ObloLei
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	oblo.load_state({"finito": true})
	# fuori dalla zona mentre le stanze si caricano e il bambino si riscalda
	_guarda(Vector3(-4.9, -3.8, 66.0), Vector3(-10.0, -4.4, 66.0))
	for i in 1800:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 300:
			break
	if studio:
		_studio = SubViewport.new()
		_studio.size = Vector2i(960, 540)
		_studio.world_3d = get_viewport().find_world_3d()
		_studio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_cam = Camera3D.new()
		_cam.fov = 40.0
		var cg := get_viewport().get_camera_3d()
		# (più esposta: il corridoio è rosso e buio, e qui si guardano i piedi e le pose)
		if cg.environment:
			_cam.environment = cg.environment.duplicate()
			_cam.environment.tonemap_exposure *= 3.0
		_cam.attributes = cg.attributes
		_studio.add_child(_cam)
		add_child(_studio)
		_cam.current = true
		_cam.look_at_from_position(Vector3(-4.15, -4.3, 62.9), Vector3(-5.0, -4.75, 66.3))
		DirAccess.make_dir_recursive_absolute(_cartella + "_cam")
	match caso:
		"fermati":
			await _fermati()
		"polaroid":
			await _polaroid()
		"vicino":
			await _vicino()
		"indietro":
			await _indietro()
	var f := FileAccess.open(_cartella + ".txt", FileAccess.WRITE)
	f.store_string("\n".join(_diario) + "\n")
	f.close()
	get_tree().quit(0)


func _guarda(occhio: Vector3, punto: Vector3) -> void:
	_p.global_position = occhio - Vector3.UP * (_p.get_eye_position().y - _p.global_position.y)
	_p.look_at_point(punto)
	_p.camera.global_transform = _p.get_aim_transform()


func _fotogramma() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join("%05d.jpg" % _n), 0.9)
	if _studio:
		_studio.get_texture().get_image().save_jpg((_cartella + "_cam").path_join("%05d.jpg" % _n), 0.9)
	if _b.stato != _stato:
		_stato = _b.stato
		_diario.append("f%d (%.2f s): %s" % [_n, _n / 30.0, BambinoSfuggita.Stato.keys()[_stato]])
	_n += 1


func _testa() -> Vector3:
	return _b.bambino.punto_testa() if _b.bambino.visible else _b.global_position + Vector3.UP * 0.9


## Da [param da] a [param a] (occhi) in [param secondi], guardando dove dice [param mira] (Callable(f) -> Vector3).
func _muovi(da: Vector3, a: Vector3, mira: Callable, secondi: float) -> void:
	var n := int(secondi * 30.0)
	for i in n + 1:
		var f := float(i) / maxf(n, 1)
		var e := f * f * (3.0 - 2.0 * f)
		var bob := sin(f * secondi * TAU * 1.8) * 0.02 if da.distance_to(a) > 0.1 else 0.0
		_guarda(da.lerp(a, e) + Vector3.UP * bob, mira.call(e))
		await _fotogramma()


## Fermo in [param occhio] guardando [param mira] finché vale [param finche] (al più [param massimo] s).
func _aspetta(occhio: Vector3, mira: Callable, finche: Callable, massimo: float) -> void:
	var t := 0.0
	while t < massimo and finche.call():
		_guarda(occhio, mira.call(0.0))
		await _fotogramma()
		t += 1.0 / 30.0


func _fermati() -> void:
	var occhio := Vector3(-4.9, -3.8, 54.5)
	var scala := Vector3(-3.0, -4.6, 48.6)
	await _aspetta(occhio, func(_e): return scala, func(): return _b.stato == BambinoSfuggita.Stato.ATTESA, 6.0)
	await _aspetta(occhio, func(_e): return scala, func(): return true, 1.0)
	# ti giri verso il fondo del corridoio
	await _muovi(occhio, occhio, func(e): return scala.lerp(_testa(), e), 1.0)
	await _aspetta(occhio, func(_e): return _testa(), func(): return _b.stato == BambinoSfuggita.Stato.GUARDA, 8.0)
	await _aspetta(occhio, func(_e): return _testa(), func(): return _b.stato == BambinoSfuggita.Stato.SCAPPA, 6.0)
	await _aspetta(occhio, func(_e): return Vector3(-6.4, -4.4, 66.0), func(): return true, 1.5)


func _polaroid() -> void:
	var occhio := Vector3(-4.5, -4.0, 58.2)
	var foto := Vector3(-4.06, -5.37, 58.4)
	await _aspetta(occhio, func(_e): return foto, func(): return _b.stato == BambinoSfuggita.Stato.ATTESA, 6.0)
	await _aspetta(occhio, func(_e): return foto, func(): return true, 0.3)
	# si alza e si gira di scatto verso il fondo
	var su := Vector3(-4.6, -3.8, 58.2)
	await _muovi(occhio, su, func(e): return foto.lerp(_testa(), e), 0.6)
	await _aspetta(su, func(_e): return _testa(), func(): return _b.stato != BambinoSfuggita.Stato.FINITO, 5.0)
	await _aspetta(su, func(_e): return Vector3(-6.4, -4.4, 66.0), func(): return true, 1.0)


func _vicino() -> void:
	# girato verso la scala a 5 m da lui (fuori dalla zona: entra nella zona voltandosi indietro), poi si gira
	var occhio := Vector3(-4.6, -3.8, 62.6)
	var scala := Vector3(-4.6, -4.4, 50.0)
	await _aspetta(occhio, func(_e): return scala, func(): return _b.stato == BambinoSfuggita.Stato.ATTESA, 6.0)
	await _muovi(occhio, occhio, func(e): return scala.lerp(_testa(), e), 0.5)
	await _aspetta(occhio, func(_e): return _testa() - Vector3.UP * 0.5, func(): return _b.stato != BambinoSfuggita.Stato.FINITO, 6.0)
	await _aspetta(occhio, func(_e): return Vector3(-6.4, -4.6, 66.0), func(): return true, 1.0)


func _indietro() -> void:
	var da := Vector3(-5.6, -3.8, 66.0)
	var a := Vector3(-4.9, -3.8, 60.0)
	await _muovi(da, a, func(_e): return Vector3(-4.9, -3.9, 50.0), 2.0)
	await _aspetta(a, func(_e): return Vector3(-4.9, -3.9, 50.0), func(): return _b.stato == BambinoSfuggita.Stato.ATTESA, 3.0)
	await _aspetta(a, func(_e): return Vector3(-4.9, -3.9, 50.0), func(): return true, 0.3)
	await _muovi(a, a, func(e): return Vector3(-4.9, -3.9, 50.0).lerp(_testa(), e), 0.6)
	await _aspetta(a, func(_e): return _testa(), func(): return _b.stato != BambinoSfuggita.Stato.FINITO, 5.0)
	await _aspetta(a, func(_e): return Vector3(-6.4, -4.4, 66.0), func(): return true, 1.0)
