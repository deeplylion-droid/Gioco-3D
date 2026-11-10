extends Node
## Collaudo acque (0.3.26): scatti di ogni acqua di una zona dagli stessi punti, per confrontare due versioni. Il tempo
## dell'acqua fermo a 0 (WaterManager.time_running), le luci del blackout. Per ogni WaterBody (al più 8, i più grandi):
## "sopra" (occhi 1,6 m sopra il pelo, dal bordo, verso il centro) e "pelo" (gli occhi 2 cm sopra il pelo).
## Zone: "risalita" (tests/scene/risalita_prova.tscn: fiume, pozze), "sala" (la sala ridotta con la piscina a onde, le
## vasche e gli acquari pieni), "torre" (la sala della torre da sola).
## Uso (sotto il render.lock): xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720
##   --script res://tests/run.gd -- res://tests/collaudo/acque_scatti.gd <cartella> <zona> <basso|alto>

const TOGLI_SALA := ["Interni", "Tecnici", "Risalita", "Vasca", "Atmosfera", "Mascotte", "BambiniBalconata", "Scarabocchi",
		"Sala/TorreScivoli", "Sala/Dettagli", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "Gioco/LeiSbuca", "Sala/AreaBimbi"]


func _ready() -> void:
	_run.call_deferred()


func _costruite(scena: Node) -> bool:
	for n in scena.find_children("*", "", true, false):
		if &"costruita" in n and not bool(n.get(&"costruita")):
			return false
	return true


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[1]
	var zona: String = a[2]
	var preset: String = a[3]
	DirAccess.make_dir_recursive_absolute(out)
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	Game.pause_on_focus_loss = false
	Grafica.applica_preset(preset)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var wm := get_node("/root/WaterManager")
	wm.set(&"time_running", false)
	wm.set(&"time", 0.0)
	var we := WorldEnvironment.new()
	var look := LookSala.new()
	we.environment = look.ambiente
	we.camera_attributes = look.attributi_camera
	look.free()
	get_tree().root.add_child(we)
	var scena: Node
	if zona == "sala":
		get_tree().change_scene_to_file(load("res://tests/scena_ridotta.gd").riduci("res://scenes/sala_principale.tscn", TOGLI_SALA))
		while get_tree().current_scene == null or get_tree().current_scene == self:
			await get_tree().process_frame
		scena = get_tree().current_scene
		var giocatore := scena.get_node_or_null(^"Player") as Node3D
		if giocatore:
			giocatore.process_mode = Node.PROCESS_MODE_DISABLED
			giocatore.global_position = Vector3(12.0, 0.0, -18.0)
		we.queue_free()
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
		var enigma := scena.get_node_or_null(^"Gioco/EnigmaAcquari")
		if enigma:
			enigma.call(&"_mostra", true)
	else:
		scena = (load({"risalita": "res://tests/scene/risalita_prova.tscn", "torre": "res://scenes/sala/torre/sala_torre.tscn", "tunnel": "res://scenes/sala/sottomarino/sala_sottomarino.tscn"}[zona]) as PackedScene).instantiate()
		get_tree().root.add_child(scena)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		if _costruite(scena) and Time.get_ticks_msec() - t0 > 5000:
			break
	# le acque ferme al loro livello (niente riempimenti in corso: il livello dipenderebbe dal tempo passato)
	var corpi := scena.find_children("*", "WaterBody", true, false).filter(func(n): return (n as Node3D).is_visible_in_tree())
	for b in corpi:
		b.set(&"level", b.get(&"target_level"))
	await get_tree().create_timer(4.0).timeout
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var p := GameState.player
	if p and is_instance_valid(p):
		p.process_mode = Node.PROCESS_MODE_DISABLED
	corpi.sort_custom(func(x, y): return (x.get(&"size") as Vector2).length() > (y.get(&"size") as Vector2).length())
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.02
	get_tree().root.add_child(cam)
	cam.make_current()
	for b in corpi.slice(0, 8):
		var w := b as Node3D
		var s := w.call(&"get_surface") as MeshInstance3D
		var c := s.global_position if s else w.global_position
		var sz: Vector2 = w.get(&"size")
		var lato := w.global_basis.x.normalized() * minf(sz.x * 0.45, 6.0)
		var nome := String(scena.get_path_to(w)).replace("/", "_").replace("@", "")
		for v in [["sopra", c + lato + Vector3.UP * 1.6, c], ["pelo", c + lato + Vector3.UP * 0.02, c - lato + Vector3.UP * 0.02]]:
			cam.look_at_from_position(v[1], v[2], Vector3.UP)
			for i in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var f := "%s_%s_%s.png" % [zona, nome, v[0]]
			get_viewport().get_texture().get_image().save_png(out.path_join(f))
			print("SCATTO %s qualità %s, pelo a %.3f" % [f, w.get(&"_quality"), c.y])
	print("SCATTI FINITO")
	get_tree().quit()
