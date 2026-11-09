extends Node
## Collaudo Polaroid (0.3.24, il fondo a filo): ogni Polaroid da vicino, nel sistema della foto (così sul fondo in
## pendenza la camera radente segue la pendenza): da accovacciati (occhi 0,97 m sopra la foto, a 50 cm), di lato a 25 cm
## e 2 cm sopra la foto, radente a 22 cm e 6 mm sopra, dai quattro lati. Lampadina con ombre sulla camera.
## Una zona per volta (su llvmpipe la sala intera va fuori memoria):
## - "interni": interni.tscn al suo posto nella sala (P01-P03, si appoggiano da sole);
## - "sala": la sala ridotta (tests/scena_ridotta.gd) con l'area bimbi, la piscina e gli acquari (P04, P05, P08, P09, P14);
## - "tecnici": tecnici.tscn al suo posto, con la P06 e la P07 messe dove le mette il gioco (POSTI, da polaroid_misure.gd);
## - "torre": la sala della torre da sola (P10, P12); "risalita": tests/scene/risalita_prova.tscn (P11, P13, P15, P16).
## Uso (sotto il render.lock): xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720
##   --script res://tests/run.gd -- res://tests/collaudo/polaroid_tutte_vicino.gd <cartella> <zona>

const TOGLI_SALA := ["Interni", "Tecnici", "Risalita", "Vasca", "Atmosfera", "Mascotte", "BambiniBalconata", "Scarabocchi",
		"Sala/TorreScivoli", "Sala/Dettagli", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "Gioco/LeiSbuca"]
## La P06 e la P07 (nella sala sotto il nodo Polaroid, sopra i tecnici): [foto, posizione, base] come nel gioco.
var POSTI := {}


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
	DirAccess.make_dir_recursive_absolute(out)
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	Game.pause_on_focus_loss = false
	Grafica.applica_preset("medio" if zona.begins_with("sala") else "alto")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var we := WorldEnvironment.new()
	var look := LookSala.new()
	we.environment = look.ambiente
	we.camera_attributes = look.attributi_camera
	look.free()
	get_tree().root.add_child(we)
	var scena: Node3D
	if zona == "sala" or zona == "sala_vasca":
		# ("sala_vasca": anche il bordo dell'arrivo degli scivoli, sotto la P08)
		var togli := TOGLI_SALA.filter(func(n): return n != "Sala/TorreScivoli") if zona == "sala_vasca" else TOGLI_SALA
		get_tree().change_scene_to_file(load("res://tests/scena_ridotta.gd").riduci("res://scenes/sala_principale.tscn", togli))
		while get_tree().current_scene == null or get_tree().current_scene == self:
			await get_tree().process_frame
		scena = get_tree().current_scene as Node3D
		var giocatore := scena.get_node_or_null(^"Player") as Node3D
		if giocatore:
			giocatore.process_mode = Node.PROCESS_MODE_DISABLED
			giocatore.global_position = Vector3(12.0, 0.0, -18.0)
			var hud := giocatore.get_node_or_null(^"HUD")
			if hud:
				hud.set(&"visible", false)
		we.queue_free()
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
		var enigma := scena.get_node_or_null(^"Gioco/EnigmaAcquari")
		if enigma:
			enigma.call(&"_mostra", true)
	else:
		scena = Node3D.new()
		get_tree().root.add_child(scena)
		var dentro: Node3D
		match zona:
			"interni":
				dentro = (load("res://scenes/interni/interni.tscn") as PackedScene).instantiate()
				dentro.transform = Transform3D(Basis(), Vector3(-9.7, 0, 40.9))
			"tecnici":
				dentro = (load("res://scenes/tecnici/tecnici.tscn") as PackedScene).instantiate()
				dentro.transform = Transform3D(Basis(Vector3(-4.371139e-08, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, -4.371139e-08)), Vector3(0, -9.05, 1.36))
				dentro.set(&"giocatore_proprio", false)
			"torre":
				dentro = (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate()
			"risalita":
				dentro = (load("res://tests/scene/risalita_prova.tscn") as PackedScene).instantiate()
		scena.add_child(dentro)
		# (negli interni da soli c'è il loro giocatore: fermo e nascosto, se no cade e parte la scena di morte)
		for n in dentro.find_children("*", "CharacterBody3D", true, false):
			n.process_mode = Node.PROCESS_MODE_DISABLED
			(n as Node3D).visible = false
		for n in dentro.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		if zona == "tecnici":
			for pr in [[6, Vector3(-1.75, -9.046, 10.56), -67.1], [7, Vector3(-3.23, -8.2661, 43.36), 77.3]]:
				var ph := (load("res://scenes/props/polaroid.tscn") as PackedScene).instantiate() as PolaroidPhoto
				ph.name = "Polaroid%02d" % pr[0]
				ph.photo = pr[0]
				ph.position = pr[1] + Vector3.UP * 0.05
				ph.rotation_degrees.y = pr[2]
				scena.add_child(ph)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		if _costruite(scena) and Time.get_ticks_msec() - t0 > 5000:
			break
	await get_tree().create_timer(5.0).timeout
	var p := GameState.player
	if p and is_instance_valid(p):
		p.process_mode = Node.PROCESS_MODE_DISABLED
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.005
	get_tree().root.add_child(cam)
	cam.make_current()
	var lamp := OmniLight3D.new()
	lamp.omni_range = 3.0
	lamp.light_energy = 0.6
	lamp.shadow_enabled = true
	cam.add_child(lamp)
	lamp.position = Vector3(0.15, 0.25, 0)
	var foto := scena.find_children("*", "PolaroidPhoto", true, false)
	foto.sort_custom(func(x, y): return int(x.get(&"photo")) < int(y.get(&"photo")))
	# APRI=1: le casseforti aperte (lo stato dopo il codice; la P11 è dentro quella dell'infermeria)
	if OS.get_environment("APRI") == "1":
		for n in scena.find_children("*", "CassaforteRotelle", true, false):
			n.call(&"load_state", {"aperta": true})
		for i in 30:
			await get_tree().process_frame
	var solo := OS.get_environment("SOLO").split(",", false)
	for f in foto:
		var ph := f as PolaroidPhoto
		if not solo.is_empty() and not solo.has(str(ph.photo)):
			continue
		var b := ph.global_basis.orthonormalized()
		var c := ph.global_position
		print("VICINO P%02d %s in %s, su %s, visibile %s" % [ph.photo, ph.name, c.snappedf(0.0001), b.y.snappedf(0.001), ph.is_visible_in_tree()])
		var viste := []
		for g in [0, 90, 180, 270]:
			var d := b * Vector3(sin(deg_to_rad(g)), 0, cos(deg_to_rad(g)))
			viste.append(["lato2cm_%03d" % g, c + d * 0.25 + b.y * 0.02, c + b.y * 0.003, b.y])
			viste.append(["radente_%03d" % g, c + d * 0.22 + b.y * 0.006, c + b.y * 0.002, b.y])
		# APRI=1: anche da davanti, a 45 cm e 12 cm sopra, da otto direzioni (dentro la cassaforte, dallo sportello aperto)
		if OS.get_environment("APRI") == "1":
			for g in range(0, 360, 45):
				var d := Vector3(sin(deg_to_rad(g)), 0, cos(deg_to_rad(g)))
				viste.append(["fronte_%03d" % g, c + d * 0.45 + Vector3.UP * 0.12, c, Vector3.UP])
		var d0 := b * Vector3(0, 0, 1)
		viste.append(["accovacciato", c + d0 * 0.5 + b.y * 0.97, c, Vector3.UP if absf(b.y.dot(Vector3.UP)) < 0.9 else b.y])
		for v in viste:
			var su: Vector3 = v[3]
			if absf((v[2] - v[1]).normalized().dot(su)) > 0.98:
				su = b.z
			cam.look_at_from_position(v[1], v[2], su)
			for i in 12:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(out.path_join("p%02d_%s.jpg" % [ph.photo, v[0]]), 0.9)
	print("VICINO FINITO")
	get_tree().quit()
