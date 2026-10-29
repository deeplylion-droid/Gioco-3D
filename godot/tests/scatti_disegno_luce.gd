extends Node
## Prove per il video e per la proposta dell'enigma dei giocattoli, con la camera del giocatore:
## - il disegno dei bambini sul muro ovest con un filo di luce propria (come le Polaroid) a più intensità, dal punto del
##   video e più vicino: al buio della piscina, senza, non si legge;
## - da dove si vedono bene i piatti che scendono: punti sul bordo della piscina (stampa la quota del pavimento).
## Nella sala ridotta (tests/scena_ridotta.gd), preset medio.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_disegno_luce.gd <cartella>

const SCENA := "res://scenes/sala_principale.tscn"
const TOGLI := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Atmosfera", "Sala/TorreScivoli", "Sala/Dettagli", "Sala/AreaBimbi", "Vasca", "Gioco/LeiSbuca",
		"Gioco/EnigmaAcquari"]
const MURO := Vector3(-6.97, -0.75, -0.2)
const ENERGIE := [0.0, 0.3, 0.6, 1.0]
## Punti sul bordo (in pianta) e dove guardano.
const BORDO := [[Vector3(-2.5, 0, 5.8), Vector3(-3.9, -2.0, 3.3)], [Vector3(0.0, 0, 6.2), Vector3(0.0, -2.0, 2.6)],
		[Vector3(-7.8, 0, 2.6), Vector3(-3.9, -2.0, 3.3)], [Vector3(2.5, 0, 5.8), Vector3(3.9, -2.0, 3.3)]]

var out := ""
var level: Node3D
var p: Player


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	out = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(out)
	Game.pause_on_focus_loss = false
	Grafica.applica_preset("medio")
	Engine.set_meta(&"precarica_torre_spento", true)
	get_tree().change_scene_to_file(load("res://tests/scena_ridotta.gd").riduci(SCENA, TOGLI))
	while get_tree().current_scene == null or get_tree().current_scene == self:
		await get_tree().process_frame
	level = get_tree().current_scene
	p = level.get_node_or_null(^"Player") as Player
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var enigma := level.get_node(^"Piscina/EnigmaGiocattoli") as EnigmaGiocattoli
	var vasca := level.get_node(^"Piscina/Pozza") as WaterTank
	await _metti(Vector3(-2.9, 0, -0.25), MURO)
	for i in 90:
		await get_tree().process_frame
	p.process_mode = Node.PROCESS_MODE_INHERIT
	var hud := p.get_node_or_null(^"HUD")
	if hud and hud.has_method(&"show_hint"):
		hud.call(&"show_hint", "", 0.01)
	var disegno := enigma.get_node(^"Disegno") as Decal
	disegno.texture_emission = disegno.texture_albedo
	for dove in [Vector3(-2.9, 0, -0.25), Vector3(-4.6, 0, -0.25)]:
		await _metti(dove, MURO)
		for e: float in ENERGIE:
			disegno.emission_energy = e
			await _attendi(0.5)
			await _scatto("disegno_%s_luce%02d" % ["vicino" if dove.x < -4.0 else "lontano",roundi(e * 10.0)])
	disegno.emission_energy = 0.0
	# i punti sul bordo, coi piatti scesi
	vasca.fill = 0.0
	enigma.load_state({"risolto": true})
	await _attendi(1.0)
	for k in BORDO.size():
		await _metti(BORDO[k][0], BORDO[k][1])
		print("BORDO %d: piedi a %s" % [k, p.global_position])
		await _attendi(0.8)
		await _scatto("bordo_%d" % k)
	print("FINE")
	get_tree().quit()


func _metti(dove: Vector3, punto: Vector3) -> void:
	var q := PhysicsRayQueryParameters3D.create(Vector3(dove.x, 1.0, dove.z), Vector3(dove.x, -4.0, dove.z), Layers.WORLD)
	var h := level.get_world_3d().direct_space_state.intersect_ray(q)
	var y: float = (h.position as Vector3).y + 0.05 if not h.is_empty() else dove.y
	var piedi := Vector3(dove.x, y, dove.z)
	var d := punto - (piedi + Vector3(0, 1.6, 0))
	p.teleport(piedi, atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _attendi(0.3)
	# dopo che il giocatore si è posato, lo sguardo di nuovo sul punto
	d = punto - p.get_eye_position()
	p.set_look(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _attendi(secondi: float) -> void:
	for k in int(secondi * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out.path_join(nome + ".jpg"), 0.9)
	print("SCATTO ", nome)
