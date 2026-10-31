extends Node
## Scatti dei cartelloni della torre degli scivoli rovinati come quelli del muro nord della sala (SalaTorre.
## CARTELLONI_ROVINATI: delfino e balena; il polpo resta com'è), dopo e prima nello stesso giro (prima = i materiali
## del GLB, togliendo quelli messi dal codice). La torre costruita e preparata come nel gioco, al buio dopo la sala
## pompe, con la camera vera del giocatore.
## - "_giocatore": dagli occhi del giocatore (1,6 m) sul checkpoint più vicino da cui il cartellone si vede (i
##   checkpoint sono il portone, le pedane d'arrivo e il fondo: posti dove il giocatore sta);
## - "_davanti": dagli occhi del giocatore sul pavimento davanti al cartellone (il più vicino trovato coi raggi);
## - "_vicino": ravvicinato tecnico a 1,5 m dal centro, per vedere come la carta sta sulla cornice e sul muro.
## Uso (sotto il lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60
##   --resolution 1280x720 --script res://tests/run.gd -- res://proposte/poster_sala/scatti_cartelloni_torre.gd <cartella>

const PLAYER := "res://scenes/player/player.tscn"
const OCCHI := Vector3(0.0, 1.6, 0.0)
const CARTELLONI := ["torre_cartellone_0", "torre_cartellone_1", "torre_cartellone_2", "torre_cartellone_3"]
var cartella := ""
var p: Player


func _ready() -> void:
	cartella = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	seed(31)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	var campioni := SalaTorre.materiali_campione()
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	torre.costruzione_a_pezzi = true
	torre.visible = false
	torre.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(torre)
	var pipe0 := _pipeline()
	await torre.costruisci_a_pezzi()
	await torre.prepara_materiali(get_viewport())
	torre.visible = true
	torre.process_mode = Node.PROCESS_MODE_INHERIT
	campioni.clear()
	var pipe1 := _pipeline()
	print("TORRE costruzione e preparazione: pipeline +%d / +%d" % [pipe1[0] - pipe0[0], pipe1[1] - pipe0[1]])
	if torre.oblo:
		torre.oblo.set_process(false)
	await _fotogrammi(20)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.set_physics_process(false)
	# le viste di ogni cartellone
	var spazio := torre.get_world_3d().direct_space_state
	var viste := []
	for nome: String in CARTELLONI:
		var c := torre.find_child(nome, true, false) as MeshInstance3D
		var centro := c.global_transform * Vector3(0.0, 0.9, 0.03)
		var davanti := (c.global_transform.basis * Vector3(0, 0, 1)).normalized()
		print("TORRE %s al centro %s, verso %s, rovinato: %s" % [nome, centro, davanti, c.get_surface_override_material(0) != null])
		# dal checkpoint più vicino da cui si vede
		var migliore: Vector3 = Vector3.INF
		for cp in torre.checkpoint:
			var occhio: Vector3 = (cp as Node3D).global_position + OCCHI
			if (centro - occhio).dot(davanti) > -0.5 or occhio.distance_to(centro) > 30.0:
				continue
			if not _si_vede(spazio, occhio, centro, davanti):
				continue
			if migliore == Vector3.INF or occhio.distance_to(centro) < migliore.distance_to(centro):
				migliore = occhio
		if migliore != Vector3.INF:
			viste.append(["%s_giocatore" % nome, migliore, centro, 62.0])
		# dal pavimento davanti
		var trovato := false
		for d in [3.0, 4.5, 6.0, 8.0]:
			for lato in [0.0, -1.5, 1.5]:
				var x: Vector3 = centro + davanti * float(d) + davanti.cross(Vector3.UP).normalized() * float(lato)
				var h := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(x + Vector3.UP * 1.0, x + Vector3.DOWN * 25.0, Layers.WORLD))
				if h.is_empty():
					continue
				var occhio: Vector3 = (h.position as Vector3) + OCCHI
				if _si_vede(spazio, occhio, centro, davanti):
					viste.append(["%s_davanti" % nome, occhio, centro, 62.0])
					trovato = true
					break
			if trovato:
				break
		viste.append(["%s_vicino" % nome, centro + davanti * 1.5, centro, 70.0])
	for modo in ["dopo", "prima"]:
		if modo == "prima":
			for nome: String in CARTELLONI:
				var c := torre.find_child(nome, true, false) as MeshInstance3D
				for i in c.mesh.get_surface_count():
					c.set_surface_override_material(i, null)
		for v in viste:
			p.teleport(v[1] - OCCHI)
			await _fotogrammi(4)
			p.look_at_point(v[2])
			p.camera.fov = v[3]
			await _fotogrammi(30)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(cartella.path_join("%s_%s.jpg" % [v[0], modo]), 0.9)
			print("TORRE scatto %s_%s da %s" % [v[0], modo, v[1]])
	var pipe2 := _pipeline()
	print("TORRE pipeline durante gli scatti: +%d / +%d" % [pipe2[0] - pipe1[0], pipe2[1] - pipe1[1]])
	get_tree().quit()


## Vero se dall'occhio si vede il centro del cartellone (niente del mondo in mezzo, fino a 20 cm dalla carta).
func _si_vede(spazio: PhysicsDirectSpaceState3D, occhio: Vector3, centro: Vector3, davanti: Vector3) -> bool:
	var fine := centro + davanti * 0.2
	var h := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(occhio, fine, Layers.WORLD))
	return h.is_empty()


func _pipeline() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _fotogrammi(k: int) -> void:
	for i in k:
		await get_tree().process_frame
