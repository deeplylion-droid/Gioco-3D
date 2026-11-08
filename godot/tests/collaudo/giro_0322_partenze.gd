extends Node
## Collaudo finale della 0.3.22 (ambienti-2), parte 2: le partenze dal titolo vero, dagli occhi del giocatore, col
## renderer vero. Si lancia come scena (con --script il gioco è "automatico"), con XDG_DATA_HOME su una cartella propria.
## - f9 <id>: nel titolo il tasto F9, poi il clic sulla partenza (tunnel, inseguimento); l'arrivo (scatti attorno), una
##   morte (GameState.kill_player, la scena di morte intera) e la ripartenza, poi 8 s di gioco.
## - continua: nel titolo il clic su Continua (il salvataggio lasciato dalla partenza di prima); l'arrivo e scatti attorno.
## Stampa i tempi, la memoria del processo e gli scatti; gli errori si contano nel log.
## Uso (sotto il render.lock, con 13,5 GB liberi):
##   XDG_DATA_HOME=<cartella> xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan \
##     --resolution 1280x720 res://tests/collaudo/giro_0322_partenze.tscn -- <cartella scatti> <f9 tunnel|f9 inseguimento|continua>

const TITOLO := "res://scenes/ui/menu_principale.tscn"

var registratore := false
var cartella := "/tmp/giro_0322_partenze"
var modo := "continua"
var id := ""
var _n := 0
var _t0 := 0


func _ready() -> void:
	if registratore:
		_run.call_deferred()
		return
	var a := OS.get_cmdline_user_args()
	var r := Node.new()
	r.set_script(get_script())
	r.name = "Giro0322Partenze"
	r.set(&"registratore", true)
	if a.size() > 0:
		r.set(&"cartella", a[0])
	if a.size() > 1:
		r.set(&"modo", a[1])
	if a.size() > 2:
		r.set(&"id", a[2])
	get_tree().root.add_child.call_deferred(r)
	get_tree().change_scene_to_file.call_deferred(TITOLO)


func _ora() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


func _rss_mb() -> int:
	var out := []
	OS.execute("sh", ["-c", "grep VmRSS /proc/%d/status" % OS.get_process_id()], out)
	var t := String(out[0]) if not out.is_empty() else ""
	return int(t.split(":")[1].strip_edges().split(" ")[0]) / 1024 if t.contains(":") else -1


func _scatto(nome: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("POSA %s: %s guardando %.1f gradi" % [nome, GameState.player.global_position.snapped(Vector3.ONE * 0.01) if is_instance_valid(GameState.player) else "-",
				rad_to_deg(GameState.player.yaw) if is_instance_valid(GameState.player) else 0.0])
		return
	await RenderingServer.frame_post_draw
	var f := "%s_%02d_%s" % [(modo + id).replace(" ", ""), _n, nome]
	_n += 1
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(f + ".jpg"), 0.88)
	print("SCATTO %s a %.2f s (RSS %d MB)" % [f, _ora(), _rss_mb()])


func _secondi(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await get_tree().process_frame


func _clic(b: Control) -> void:
	var scena := get_tree().current_scene
	var c := b.get_global_rect().get_center()
	var mossa := InputEventMouseMotion.new()
	mossa.position = c
	mossa.global_position = c
	Input.parse_input_event(mossa)
	await get_tree().process_frame
	for premuto in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = premuto
		ev.position = c
		ev.global_position = c
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame
	# (se il clic simulato non arriva al pulsante, come col menu F9 sopra il titolo: il pulsante premuto, come col joypad)
	await _secondi(2.0)
	if get_tree().current_scene == scena and is_instance_valid(b) and b.is_visible_in_tree() and not (b as BaseButton).disabled:
		print("GIRO0322P: il clic non è arrivato a «%s»: premuto col segnale" % (b as Button).text)
		(b as BaseButton).pressed.emit()


func _bottone(radice: Node, testo: String) -> Button:
	for n in radice.find_children("*", "Button", true, false):
		if String((n as Button).text).to_lower().contains(testo.to_lower()) and (n as Button).is_visible_in_tree():
			return n as Button
	return null


func _run() -> void:
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(cartella)
	print("GIRO0322P: %s %s, cartella utente %s, salvataggio %s" % [modo, id, OS.get_user_data_dir(), GameState.has_save()])
	await _secondi(2.0)
	var t_tit := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_tit < 300000 and (not Dissolvenza.presente(get_tree()) or Dissolvenza.di(get_tree()).opacita() > 0.02):
		await get_tree().process_frame
	await _secondi(1.0)
	await _scatto("titolo")
	if modo == "f9":
		var ev := InputEventKey.new()
		ev.keycode = KEY_F9
		ev.physical_keycode = KEY_F9
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
		var su := ev.duplicate() as InputEventKey
		su.pressed = false
		Input.parse_input_event(su)
		await _secondi(1.0)
		await _scatto("menu_f9")
		var nome := {"tunnel": "Tunnel sottomarino", "inseguimento": "Inseguimento"}.get(id, id) as String
		var b := _bottone(get_tree().root, nome)
		if b == null:
			# (con la lingua di sistema inglese)
			b = _bottone(get_tree().root, {"tunnel": "Underwater tunnel", "inseguimento": "Chase"}.get(id, id))
		if b == null:
			print("GIRO0322P: KO la partenza %s non c'è nel menu F9" % nome)
			get_tree().quit(1)
			return
		await _clic(b)
	else:
		var b := get_tree().current_scene.find_child("Continua", true, false) as Button
		if b == null:
			print("GIRO0322P: KO la voce Continua non c'è")
			get_tree().quit(1)
			return
		await _clic(b)
	# il caricamento e l'arrivo: i comandi al giocatore e lo schermo chiaro
	var t_in := Time.get_ticks_msec()
	var car_scatto := false
	while Time.get_ticks_msec() - t_in < 900000:
		await get_tree().process_frame
		var sc := get_tree().current_scene
		if not car_scatto and sc and sc.get_script() and String((sc.get_script() as Script).resource_path).ends_with("caricamento.gd"):
			await _secondi(2.0)
			await _scatto("caricamento")
			car_scatto = true
		var p := GameState.player
		if is_instance_valid(p) and p.input_enabled and (not Dissolvenza.presente(get_tree()) or Dissolvenza.di(get_tree()).opacita() < 0.02):
			break
	var p := GameState.player
	if not is_instance_valid(p) or not p.input_enabled:
		print("GIRO0322P: KO dopo 15 minuti non si gioca")
		get_tree().quit(1)
		return
	print("GIRO0322P: si gioca a %.2f s in %s (RSS %d MB)" % [_ora(), p.global_position.snapped(Vector3.ONE * 0.01), _rss_mb()])
	await _secondi(2.0)
	await _attorno(p, "arrivo")
	if modo != "f9":
		print("GIRO0322P: FINE a %.2f s" % _ora())
		get_tree().quit()
		return
	# una morte, la scena intera, e la ripartenza
	var morto := [false, false]
	GameState.player_died.connect(func(_c): morto[0] = true)
	GameState.player_respawned.connect(func(): morto[1] = true)
	GameState.kill_player(&"collaudo")
	await _secondi(0.6)
	await _scatto("morte_0.6s")
	await _secondi(1.0)
	await _scatto("morte_1.6s")
	t_in = Time.get_ticks_msec()
	var p2: Player = null
	while Time.get_ticks_msec() - t_in < 900000:
		await get_tree().process_frame
		var q := GameState.player
		if is_instance_valid(q) and q != p and q.input_enabled and (not Dissolvenza.presente(get_tree()) or Dissolvenza.di(get_tree()).opacita() < 0.02):
			p2 = q
			break
	if p2 == null:
		print("GIRO0322P: KO dopo la morte non si torna a giocare")
		get_tree().quit(1)
		return
	print("GIRO0322P: ripartito a %.2f s in %s (RSS %d MB)" % [_ora(), p2.global_position.snapped(Vector3.ONE * 0.01), _rss_mb()])
	await _secondi(2.0)
	await _attorno(p2, "ripartenza")
	await _secondi(6.0)
	await _scatto("ripartenza_8s")
	# (scorciatoia, per provare Continua dopo: il checkpoint più vicino raggiunto e scritto su disco)
	var cp: Checkpoint = null
	for n in get_tree().current_scene.find_children("*", "Checkpoint", true, false):
		if cp == null or (n as Node3D).global_position.distance_to(p2.global_position) < cp.global_position.distance_to(p2.global_position):
			cp = n as Checkpoint
	if cp:
		GameState.reach_checkpoint(cp)
		await _secondi(3.0)
		print("GIRO0322P: (scorciatoia) checkpoint %s raggiunto, salvataggio su disco %s" % [cp.name, GameState.has_save()])
	print("GIRO0322P: FINE a %.2f s (RSS %d MB)" % [_ora(), _rss_mb()])
	get_tree().quit()


## Quattro scatti attorno dagli occhi (avanti, destra, dietro, sinistra), poi lo sguardo com'era.
func _attorno(p: Player, nome: String) -> void:
	var yaw := p.yaw
	var pitch := p.pitch
	for k in 4:
		p.set_look(yaw - k * PI * 0.5, deg_to_rad(-8.0))
		for i in 4:
			await get_tree().process_frame
		await _scatto("%s_%d" % [nome, k])
	p.set_look(yaw, pitch)
