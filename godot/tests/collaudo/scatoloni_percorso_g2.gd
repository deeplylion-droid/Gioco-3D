extends Node
## grafica-2 (1 novembre): il corridoio delle pile del fiume dopo il caricamento VERO, come ci arriva l'utente:
## partenza F9 "risalita" (il giocatore fuori dal fiume), il fiume chiesto al thread, costruito a pezzi, disegnato fuori
## vista (RiscaldamentoShader.disegna_fuori_vista) e riacceso a pezzi; poi il giocatore nei punti fissi del
## corridoio, scatti dagli occhi e luminanza (media, mediana, 10%). Per confrontare 0.3.18 e 0.3.19 (ipotesi del
## coordinatore: nella 0.3.18 il riscaldamento cambiava gli strati senza Strati e alcune mesh restavano senza luci).
## Con PARTENZA=fiume nell'ambiente: la partenza F9 del fiume (senza il riscaldamento), per confronto.
const F := preload("res://scripts/risalita/fiume_gioco.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Game.pause_on_focus_loss = false
	var cartella: String = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	var partenza := OS.get_environment("PARTENZA")
	if partenza == "":
		partenza = "risalita"
	print("PERCORSO versione %s, partenza %s" % [ProjectSettings.get_setting("application/config/version"), partenza])
	MenuProva.parti(get_tree(), partenza)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1800000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p.is_inside_tree() and p.input_enabled:
			break
	print("PERCORSO giocatore pronto dopo %d s a %s" % [(Time.get_ticks_msec() - t0) / 1000, GameState.player.global_position])
	var ris: Node = get_tree().current_scene.find_child("Risalita", true, false)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3600000:
		await get_tree().process_frame
		if ris and ris.get(&"fiume") != null and not bool(ris.get(&"_riaccendendo")) and AttesaZone.e_pronta(&"risalita"):
			break
	print("PERCORSO fiume costruito e riacceso dopo %d s" % [(Time.get_ticks_msec() - t0) / 1000])
	var fiume := ris.get(&"fiume") as Node3D
	for i in 120:
		await get_tree().process_frame
	var p := GameState.player as Player
	p.set_physics_process(false)
	var da := Vector3(F.INGRESSO_X, 0, F.Z0 + 1.0)
	var dir := (F.FINE_FILA - da).normalized()
	var lungo := da.distance_to(F.FINE_FILA)
	var punti := [["porta_ingresso", Vector3(F.INGRESSO_X, 0, F.Z0 + 2.5), Vector3(F.INGRESSO_X, 1.4, F.Z0 - 2.0)]]
	for k in 4:
		var q: Vector3 = da + dir * lungo * [0.08, 0.35, 0.62, 0.9][k]
		punti.append(["corridoio_%d" % (k + 1), q, q + dir * 8.0 + Vector3(0, 1.3, 0)])
	punti.append(["imbarco", Vector3(-2.3, 0, -2.3), Vector3(0.0, 0.9, -13.0)])
	for pt in punti:
		p.global_position = fiume.to_global(pt[1])
		for i in 120:
			p.look_at_point(fiume.to_global(pt[2]))
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_jpg(cartella.path_join("%s.jpg" % pt[0]), 0.9)
		var v := PackedFloat32Array()
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				v.append(img.get_pixel(x, y).get_luminance() * 255.0)
		var somma := 0.0
		for x in v:
			somma += x
		v.sort()
		print("PERCORSO %s: media %.1f, mediana %.1f, 10%% %.1f" % [pt[0], somma / v.size(), v[v.size() / 2], v[int(v.size() * 0.1)]])
	print("PERCORSO FINE")
	Game.esci(0)
