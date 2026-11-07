extends Node
## Collaudo finale 0.3.21 (enigmi): il bambino del corridoio del fiume sparisce dietro la pila dell'angolo, guardato
## due volte dagli occhi del giocatore che lo insegue dentro il capannone:
##  - soglia: corri dietro di lui fino alla porta e ti fermi sulla soglia guardando la pila;
##  - dentro_2m: corri fino a 2 m dentro (80 cm verso ovest), da dove si vede la bocca della nicchia, e guardi la nicchia.
## Ogni 5 fotogrammi: dov'è (coordinate del fiume), se il giocatore lo vede (Bambino.visibile_da) e lo stato; quando
## sparisce, dov'era. Fotogrammi dagli occhi in <cartella>/<caso>/, e da una camera di regia (non è quella del giocatore,
## il bambino non la guarda) in <cartella>/<caso>_regia/.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 960x540 --fixed-fps 30 --script
##   res://tests/run.gd -- <questo> <caso> <cartella>

var _p: Player
var _b: BambinoSfuggita
var _fiume: Node3D
var _cartella := ""
var _n := 0
var _stato := -1
var _regia: SubViewport
var _ultimo_visibile := Vector3.ZERO
var _era_visibile := false


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func F(v: Vector3) -> Vector3:
	return _fiume.to_global(v)


func L(v: Vector3) -> Vector3:
	return _fiume.to_local(v)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var caso := a[1] if a.size() > 1 else "soglia"
	_cartella = (a[2] if a.size() > 2 else "user://bambino_pila").path_join(caso)
	DirAccess.make_dir_recursive_absolute(_cartella)
	DirAccess.make_dir_recursive_absolute(_cartella + "_regia")
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
	_guarda(Vector3(-4.9, -3.8, 66.0), Vector3(-10.0, -4.4, 66.0))
	ris.call(&"carica_subito")
	for i in 2400:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and ris.get(&"fiume") != null and i > 300:
			break
	_fiume = ris.get(&"fiume") as Node3D
	print("BP: fiume %s, pile dal file %s; bambino in %s (fiume %s)" % [_fiume != null, _fiume.get(&"pile_salvate") != null, _b.global_position.snapped(Vector3.ONE * 0.01), L(_b.global_position).snapped(Vector3.ONE * 0.01)])
	var via := PackedStringArray()
	for v in _b.via:
		via.append(str(L(ris.to_global(v)).snapped(Vector3.ONE * 0.01)))
	print("BP: la fuga in coordinate del fiume: %s" % " -> ".join(via))
	# la regia: in fondo al passaggio a sud della pila (la fuga del bambino, FiumeLento.FUGA_BAMBINO, va lungo z -26,9 e poi
	# gira a nord nella nicchia fra la pila e il muro dell'approdo), alta, guardando giù nella nicchia
	_regia = SubViewport.new()
	_regia.size = Vector2i(640, 360)
	_regia.world_3d = get_viewport().find_world_3d()
	_regia.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	var cg := get_viewport().get_camera_3d()
	if cg.environment:
		cam.environment = cg.environment.duplicate()
		cam.environment.tonemap_exposure *= 3.0
	cam.attributes = cg.attributes
	_regia.add_child(cam)
	add_child(_regia)
	cam.current = true
	cam.look_at_from_position(F(Vector3(-30.05, 2.0, -26.55)), F(Vector3(-29.9, 0.3, -28.2)))
	# come nel caso "vicino" del video del bambino: a 5 m da lui, girato verso la scala, poi ti giri
	var occhio := Vector3(-4.6, -3.8, 62.6)
	var scala := Vector3(-4.6, -4.4, 50.0)
	await _aspetta(occhio, func(_e): return scala, func(): return _b.stato == BambinoSfuggita.Stato.ATTESA, 6.0)
	await _muovi(occhio, occhio, func(e): return scala.lerp(_testa(), e), 0.5)
	await _aspetta(occhio, func(_e): return _testa() - Vector3.UP * 0.5, func(): return _b.stato == BambinoSfuggita.Stato.GUARDA, 8.0)
	# scappa: 0,6 s per accorgersene, poi di corsa (3,5 m/s, lui corre a 2,4) alla porta, guardandolo
	await _aspetta(occhio, func(_e): return _testa(), func(): return true, 0.6)
	var porta := (ris.get_node(^"Marker/PortaFiume") as Node3D).global_position + Vector3.UP * 1.6
	var pila := F(Vector3(-29.2, 1.0, -28.0))
	var segui := func(_e): return _testa() if _b.bambino.visible else pila
	await _muovi(occhio, porta, segui, occhio.distance_to(porta) / 3.5)
	var soglia := F(Vector3(-26.0, 1.6, -28.6 + 0.3))
	await _muovi(porta, soglia, segui, porta.distance_to(soglia) / 3.5)
	var fermo := soglia
	var mira := pila
	if caso == "dentro_2m":
		fermo = F(Vector3(-26.8, 1.6, -28.6 + 2.0))
		mira = F(Vector3(-29.9, 0.8, -27.6))
		await _muovi(soglia, fermo, func(e): return pila.lerp(mira, e), soglia.distance_to(fermo) / 3.0)
	await _aspetta(fermo, func(_e): return mira, func(): return _b.stato != BambinoSfuggita.Stato.FINITO, 10.0)
	await _aspetta(fermo, func(_e): return mira, func(): return true, 1.5)
	print("BP: FINE (%d fotogrammi, stato %s)" % [_n, BambinoSfuggita.Stato.keys()[_b.stato]])
	get_tree().quit(0)


func _guarda(occhio: Vector3, punto: Vector3) -> void:
	_p.global_position = occhio - Vector3.UP * (_p.get_eye_position().y - _p.global_position.y)
	_p.look_at_point(punto)
	_p.camera.global_transform = _p.get_aim_transform()


func _testa() -> Vector3:
	return _b.bambino.punto_testa() if _b.bambino.visible else _b.global_position + Vector3.UP * 0.9


func _fotogramma() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join("%05d.jpg" % _n), 0.9)
	_regia.get_texture().get_image().save_jpg((_cartella + "_regia").path_join("%05d.jpg" % _n), 0.9)
	var visto := _b.bambino.visible and _b.bambino.visibile_da(_p)
	var pos := _b.bambino.global_position
	if _b.stato != _stato or _n % 5 == 0:
		print("BP: f%d (%.2f s) %s; bambino %s in fiume %s; dal giocatore %s; occhi in fiume %s" % [_n, _n / 30.0,
				BambinoSfuggita.Stato.keys()[_b.stato], "visibile" if _b.bambino.visible else "SPARITO", L(pos).snapped(Vector3.ONE * 0.01),
				"LO VEDE" if visto else "non lo vede", L(_p.get_eye_position()).snapped(Vector3.ONE * 0.01)])
	if _b.stato != _stato:
		_stato = _b.stato
		if _stato == BambinoSfuggita.Stato.FINITO:
			print("BP: SPARITO a f%d in fiume %s (l'ultima volta che lo vedeva era in %s)" % [_n, L(pos).snapped(Vector3.ONE * 0.01), L(_ultimo_visibile).snapped(Vector3.ONE * 0.01)])
	if visto:
		_ultimo_visibile = pos
	_n += 1


func _muovi(da: Vector3, a: Vector3, mira: Callable, secondi: float) -> void:
	var n := int(secondi * 30.0)
	for i in n + 1:
		var f := float(i) / maxf(n, 1)
		var e := f * f * (3.0 - 2.0 * f)
		var bob := sin(f * secondi * TAU * 1.8) * 0.02 if da.distance_to(a) > 0.1 else 0.0
		_guarda(da.lerp(a, e) + Vector3.UP * bob, mira.call(e))
		await _fotogramma()


func _aspetta(occhio: Vector3, mira: Callable, finche: Callable, massimo: float) -> void:
	var t := 0.0
	while t < massimo and finche.call():
		_guarda(occhio, mira.call(0.0))
		await _fotogramma()
		t += 1.0 / 30.0
