extends Node
## Scatti e clip della valvola rossa degli acquari che gocciola (23 ottobre, l'indizio del miscuglio torbido): la sala
## vera senza i rami pesanti (memoria, come tools/scatti_acquari.sh; senza Tecnici non c'è la serranda e gli acquari
## compaiono con la tappa 8 finita), al buio del ritorno con le luci bianche al 40%, tappa 8 finita, miscuglio torbido.
## Per ogni camera, all'altezza degli occhi, una raffica di fotogrammi di fila (uno ogni due a 60 al secondo, cioè a 30
## al secondo) da montare in una clip con ffmpeg.
## Uso: tools/scatto_sicuro.sh res://tests/scatti_valvola.gd <cartella> [fotogrammi] [camere]
## SCATTI_TOGLI: altri rami da togliere, separati da virgole.
## Le camere stanno davanti alla bocca della valvola (verso fuori, -X del nodo Valvola), a 1,5, 2,5 e 4 m.

const LEVEL := "res://scenes/sala_principale.tscn"
const CAMERE := {"vicino": 1.5, "medio": 2.5, "lontano": 4.0}
const TOGLI := ["Interni", "Risalita", "Tecnici", "Sala/TorreScivoli", "BambiniBalconata", "Sala/AreaBimbi", "Polaroid"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1]
	var n_foto := int(a[2]) if a.size() > 2 else 45
	var lista: PackedStringArray = a[3].split(",") if a.size() > 3 else PackedStringArray(CAMERE.keys())
	DirAccess.make_dir_recursive_absolute(out)
	Engine.set_meta(&"precarica_torre_spento", true)
	Grafica.applica_preset("alto")
	var togli := TOGLI.duplicate()
	togli.append_array(OS.get_environment("SCATTI_TOGLI").split(",", false))
	var ridotta: String = load("res://tests/scena_ridotta.gd").riduci(LEVEL, togli)
	var livello := (load(ridotta) as PackedScene).instantiate()
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	var p := GameState.player
	var enigma := livello.find_children("*", "EnigmaAcquari", true, false)[0] as EnigmaAcquari
	var valvola := enigma.get_node(^"Valvola") as Node3D
	# il giocatore fermo e nascosto lontano dalla valvola, come in scatti_sala (senza gli interni sotto cadrebbe)
	p.teleport(Vector3(0.0, 0.0, 19.0), 0.0, 0.0)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.visible = false
	# il ritorno: buio, keycard nel lettore (la serranda si apre e gli acquari compaiono), lei andata via
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var lei := livello.get_node_or_null(^"Gioco/LeiSbuca")
	if lei:
		lei.call(&"load_state", {"finita": true})
	var lettore := livello.get_node_or_null(^"Tecnici/Logica/LettoreTessera") as LettoreTessera
	if lettore:
		p.add_item(&"keycard", 1, "Keycard")
		lettore.interact(p)
	elif enigma.serranda:
		enigma.serranda.call(&"apri")
	for i in 10:
		await get_tree().physics_frame
	# il miscuglio sbagliato: pieno e torbido
	var misto := enigma.get_node(^"AcquarioMisto") as WaterTank
	misto.fill = misto.max_fill
	misto.set_mix(WaterMix.pura(WaterMix.TORBIDA))
	enigma.stato = EnigmaAcquari.Stato.TORBIDO
	for i in 5:
		await get_tree().physics_frame
	var gocce := valvola.get_node_or_null(^"GocceValvola") as Node3D
	print("comparsi ", enigma.comparsi, " attivi ", enigma.attivi, " gocce ", gocce != null and gocce.is_visible_in_tree())
	# senza le scritte dello schermo (i comandi in basso, il mirino)
	for c in livello.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	livello.add_child(cam)
	cam.make_current()
	var bocca: Vector3 = gocce.global_position if gocce else valvola.global_position
	var fuori := -valvola.global_basis.x
	fuori.y = 0.0
	fuori = fuori.normalized()
	for nome in lista:
		var d: float = CAMERE[nome]
		cam.global_position = Vector3(bocca.x, 1.6, bocca.z) + fuori * d
		cam.look_at(bocca + Vector3(0, 0.25, 0), Vector3.UP)
		for i in 60:
			await get_tree().process_frame
		var cartella := out.path_join(nome)
		DirAccess.make_dir_recursive_absolute(cartella)
		for i in n_foto * 2:
			await RenderingServer.frame_post_draw
			if i % 2 == 0:
				get_viewport().get_texture().get_image().save_jpg(cartella.path_join("f%03d.jpg" % (i / 2)), 0.9)
		print("salvato ", nome)
	get_tree().quit()
