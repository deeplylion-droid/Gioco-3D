extends Node
## grafica-2 (6 novembre): lo scatto vero del corridoio delle pile del fiume (lampade al 20%) per la seconda prova
## della schermata «Luminosità» (scelta A dell'utente). Partenza F9 del fiume, preset di serie (alto), luminosità 1,0
## (gamma neutra), niente HUD: dagli occhi del giocatore in più punti della fila, guardando verso il fondo.
## Salva PNG senza perdita e stampa media, mediana e 10° percentile.
const F := preload("res://scripts/risalita/fiume_gioco.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var cartella: String = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	Grafica.applica_preset("alto")
	Grafica.imposta("luminosita", 1.0)
	print("SCATTO versione %s, preset %s, luminosita %s" % [ProjectSettings.get_setting("application/config/version"),
			Grafica.valore("preset"), Grafica.valore("luminosita")])
	MenuProva.parti(get_tree(), "fiume")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1800000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p.is_inside_tree() and p.input_enabled:
			break
	if Game.has_method(&"aspetta_caricamenti"):
		await Game.aspetta_caricamenti(get_tree().current_scene, 600.0)
	for i in 240:
		await get_tree().process_frame
	var fiume: Node3D = null
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if n.get_script() == F:
			fiume = n
			break
	print("SCATTO fiume %s" % fiume)
	var p := GameState.player as Player
	p.set_physics_process(false)
	var da := Vector3(F.INGRESSO_X, 0, F.Z0 + 1.0)
	var dir := (F.FINE_FILA - da).normalized()
	var lungo := da.distance_to(F.FINE_FILA)
	var punti := [["porta_ingresso", Vector3(F.INGRESSO_X, 0, F.Z0 + 2.5), Vector3(F.INGRESSO_X, 1.4, F.Z0 - 2.0)]]
	for f: float in [0.05, 0.15, 0.25, 0.35, 0.45, 0.55, 0.62, 0.7]:
		var q: Vector3 = da + dir * lungo * f
		# verso il fondo della fila e un po' in basso, dove stanno le scatole
		punti.append(["fila_%02d" % int(f * 100), q, q + dir * 10.0 + Vector3(0, 1.1, 0)])
		punti.append(["fila_%02d_basso" % int(f * 100), q, q + dir * 10.0 + Vector3(0, 0.6, 0)])
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c.get_parent() != Grafica and not String(c.get_path()).contains("PostProcessing"):
			(c as CanvasLayer).visible = false
	for pt in punti:
		p.global_position = fiume.to_global(pt[1]) if fiume else pt[1]
		for i in 120:
			p.look_at_point(fiume.to_global(pt[2]) if fiume else pt[2])
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(cartella.path_join("%s.png" % pt[0]))
		var v := PackedFloat32Array()
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				v.append(img.get_pixel(x, y).get_luminance() * 255.0)
		var somma := 0.0
		for x in v:
			somma += x
		v.sort()
		print("SCATTO %s: media %.1f, mediana %.1f, 10%% %.1f, 90%% %.1f" % [pt[0], somma / v.size(), v[v.size() / 2],
				v[int(v.size() * 0.1)], v[int(v.size() * 0.9)]])
	print("SCATTO FINE")
	Game.esci(0)
