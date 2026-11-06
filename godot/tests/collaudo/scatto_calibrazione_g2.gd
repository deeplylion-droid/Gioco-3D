extends Node
## grafica-2 (6 novembre): lo scatto vero del corridoio delle pile del fiume (lampade al 20%) per la seconda prova
## della schermata «Luminosità» (scelta A dell'utente). Come ci arriva il giocatore: partenza F9 "risalita", il fiume
## chiesto al thread e riacceso a pezzi (come scatoloni_percorso_g2.gd); preset di serie (alto), luminosità 1,0, senza
## HUD. Dagli occhi in più punti della fila, guardando verso il fondo. PNG senza perdita, e media, mediana, 10° e 90°.
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
	MenuProva.parti(get_tree(), "risalita")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1800000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p.is_inside_tree() and p.input_enabled:
			break
	print("SCATTO giocatore pronto dopo %d s" % [(Time.get_ticks_msec() - t0) / 1000])
	var ris: Node = get_tree().current_scene.find_child("Risalita", true, false)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3600000:
		await get_tree().process_frame
		if ris and ris.get(&"fiume") != null and not bool(ris.get(&"_riaccendendo")) and AttesaZone.e_pronta(&"risalita"):
			break
	print("SCATTO fiume costruito e riacceso dopo %d s" % [(Time.get_ticks_msec() - t0) / 1000])
	var fiume := ris.get(&"fiume") as Node3D
	for i in 120:
		await get_tree().process_frame
	var p := GameState.player as Player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.set_physics_process(false)
	var da := Vector3(F.INGRESSO_X, 0, F.Z0 + 1.0)
	var dir := (F.FINE_FILA - da).normalized()
	var lungo := da.distance_to(F.FINE_FILA)
	var punti := []
	for f: float in [0.08, 0.2, 0.3, 0.35, 0.45, 0.55, 0.62, 0.9]:
		var q: Vector3 = da + dir * lungo * f
		punti.append(["fila_%02d" % int(f * 100), q, q + dir * 8.0 + Vector3(0, 1.3, 0)])
		punti.append(["fila_%02d_lungo" % int(f * 100), q, q + dir * 14.0 + Vector3(0, 1.0, 0)])
	for pt in punti:
		p.global_position = fiume.to_global(pt[1])
		for i in 120:
			p.look_at_point(fiume.to_global(pt[2]))
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
		print("SCATTO %s: occhi %s, media %.1f, mediana %.1f, 10%% %.1f, 90%% %.1f" % [pt[0], p.get_eye_position().snapped(Vector3.ONE * 0.01),
				somma / v.size(), v[v.size() / 2], v[int(v.size() * 0.1)], v[int(v.size() * 0.9)]])
	print("SCATTO FINE")
	Game.esci(0)
