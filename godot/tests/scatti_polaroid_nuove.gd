extends Node
## Scatti delle Polaroid nuove (P12-P16, proposta del 25 ottobre notte, docs/proposte/polaroid_nuove/) nel loro posto,
## dagli occhi del giocatore, e da vicino. Una zona per volta, con l'ambiente della sala (LookSala) e le luci del momento
## in cui ci si arriva:
## - "risalita": tests/scene/risalita_prova.tscn con le stanze costruite subito, al buio (P13, P15, P16);
## - "torre": la sala della torre da sola, al buio (P12);
## - "acquari": la sala principale ridotta (tests/scena_ridotta.gd: senza interni, ambienti tecnici, risalita e gli altri
##   pezzi che non si vedono dagli acquari; intera su llvmpipe va fuori memoria), al buio del ritorno (P14).
## Le camere: per ogni Polaroid il punto della camera è dato rispetto alla Polaroid, nello spazio del suo genitore.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_polaroid_nuove.gd <cartella> <zona>

const ZONE := {
	"risalita": "res://tests/scene/risalita_prova.tscn",
	"torre": "res://scenes/sala/torre/sala_torre.tscn",
	"acquari": "res://scenes/sala_principale.tscn",
}
## Nella sala ridotta: i pezzi tolti (come tests/collaudo/presa_ridotta.gd, ma con l'enigma degli acquari).
## (Con la torre degli scivoli, i dettagli e l'area bimbi su llvmpipe a 1280x720 andava fuori memoria: via anche loro e la
## vasca di lei al centro.)
const TOGLI_SALA := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Polaroid", "Atmosfera", "Sala/TorreScivoli", "Sala/Dettagli", "Sala/AreaBimbi", "Vasca", "Gioco/LeiSbuca"]
## Nella sala ridotta anche la piscina a onde, il posto della prima idea di enigma: dal fondo verso la pozza (come
## test_tappe56) e dall'alto.
const POSTI := {"acquari": [
	["enigma_piscina_fondo", Vector3(0.6, -0.35, 1.0), Vector3(1.6, -1.9, 4.9)],
	["enigma_piscina_alto", Vector3(-3.0, 3.2, -1.0), Vector3(1.0, -2.0, 4.0)],
]}
const DELLA_ZONA := {"risalita": ["Polaroid13", "Polaroid15", "Polaroid16"], "torre": ["Polaroid12"], "acquari": ["Polaroid14"]}
## [nome, camera "posto" (occhi del giocatore, 1,6 m sopra il pavimento), camera "vicino", dove guarda la camera "posto"
## rispetto alla Polaroid (se manca, la Polaroid)]
const CAMERE := {
	"Polaroid13": [Vector3(-1.7, 1.2, -1.6), Vector3(-0.3, 0.55, -0.25)],
	"Polaroid15": [Vector3(-1.3, 1.6, 1.4), Vector3(-0.35, 0.55, 0.2)],
	"Polaroid16": [Vector3(1.9, 1.6, -1.4), Vector3(0.35, 0.55, -0.2)],
	"Polaroid12": [Vector3(-1.1, 1.6, -1.55), Vector3(-0.3, 0.55, -0.25)],
	# (la P14 col disegno sul vetro dell'acquario giallo sopra: la camera guarda un po' più in alto e indietro)
	"Polaroid14": [Vector3(-0.6, 1.6, 2.6), Vector3(-0.35, 0.55, 0.2), Vector3(0.1, 0.9, -1.2)],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1]
	var zona: String = a[2] if a.size() > 2 else "risalita"
	DirAccess.make_dir_recursive_absolute(out)
	Engine.set_meta(&"precarica_torre_spento", true)
	Game.pause_on_focus_loss = false
	# (la sala ridotta col preset alto va fuori memoria anche così: lì il preset medio, come tests/collaudo/presa_ridotta.gd)
	Grafica.applica_preset("medio" if zona == "acquari" else "alto")
	Engine.set_meta(&"risalita_subito", true)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var we := WorldEnvironment.new()
	var look := LookSala.new()
	we.environment = look.ambiente
	we.camera_attributes = look.attributi_camera
	look.free()
	get_tree().root.add_child(we)
	var scena: Node
	if zona == "acquari":
		get_tree().change_scene_to_file(load("res://tests/scena_ridotta.gd").riduci(ZONE[zona], TOGLI_SALA))
		while get_tree().current_scene == null or get_tree().current_scene == self:
			await get_tree().process_frame
		scena = get_tree().current_scene
		# il giocatore della sala parte dove c'erano gli interni, tolti: cadrebbe, morirebbe e la sala si ricaricherebbe
		var giocatore := scena.get_node_or_null(^"Player") as Node3D
		if giocatore:
			giocatore.process_mode = Node.PROCESS_MODE_DISABLED
			giocatore.global_position = Vector3(12.0, 0.0, -18.0)
			# (fermo, anche la riga dei comandi del suo HUD resterebbe a schermo)
			var hud := giocatore.get_node_or_null(^"HUD")
			if hud:
				hud.set(&"visible", false)
		we.queue_free()
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
		# gli acquari come al ritorno dal magazzino, quando si trova la P14: pieni e con le lampadine del portone accese
		var enigma := scena.get_node_or_null(^"Gioco/EnigmaAcquari")
		if enigma:
			enigma.call(&"_mostra", true)
	else:
		scena = (load(ZONE[zona]) as PackedScene).instantiate()
		get_tree().root.add_child(scena)
	# le stanze e le parti costruite a pezzi (le stanze della risalita arrivano da un thread): si aspetta che ci siano
	# tutte le Polaroid della zona e che Posa le abbia appoggiate
	var nomi: Array = DELLA_ZONA[zona]
	var trovate: Array = []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		trovate = nomi.map(func(n): return scena.find_child(n, true, false)).filter(func(n): return n != null)
		if trovate.size() == nomi.size() and _costruite(scena):
			break
	for i in 120:
		await get_tree().process_frame
	var p := GameState.player
	if p and is_instance_valid(p):
		p.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.03
	get_tree().root.add_child(cam)
	cam.make_current()
	for f in trovate:
		var foto := f as Node3D
		var padre := foto.get_parent() as Node3D
		var c: Array = CAMERE[String(foto.name)]
		var su := padre.global_basis
		print("POLAROID %s in %s (sotto %s)" % [foto.name, foto.global_position, padre.name])
		for k in 2:
			var occhio: Vector3 = foto.global_position + su * (c[k] as Vector3)
			var guarda: Vector3 = foto.global_position + (su * (c[2] as Vector3) if k == 0 and c.size() > 2 else Vector3.ZERO)
			cam.look_at_from_position(occhio, guarda, Vector3.UP)
			for i in 40:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var nome := "%s_%s.png" % [String(foto.name).to_lower(), ["posto", "vicino"][k]]
			get_viewport().get_texture().get_image().save_png(out.path_join(nome))
			print("SCATTO ", nome)
	# i posti delle idee di enigma (docs/proposte/enigma_nuovo/): [nome, occhio, dove guarda], nel mondo
	for e in POSTI.get(zona, []):
		cam.look_at_from_position(e[1], e[2], Vector3.UP)
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(String(e[0]) + ".png"))
		print("SCATTO ", e[0])
	print("FINE")
	get_tree().quit()


func _costruite(scena: Node) -> bool:
	for n in scena.find_children("*", "", true, false):
		if &"costruita" in n and not bool(n.get(&"costruita")):
			return false
	return true
