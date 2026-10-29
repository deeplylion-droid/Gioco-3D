extends Node
## Scatti ravvicinati del disegno dei bambini sul muro ovest della piscina, con la camera del giocatore e la luce del
## gioco (luce_disegno), dal punto del video e più vicino: per confrontare l'import della texture (Lossless o VRAM con
## le mipmap) sulle linee fini e sui cerchi colorati. Nella sala ridotta (tests/scena_ridotta.gd), preset medio.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_disegno_vicino.gd <cartella>

const SCENA := "res://scenes/sala_principale.tscn"
const TOGLI := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Atmosfera", "Sala/TorreScivoli", "Sala/Dettagli", "Sala/AreaBimbi", "Vasca", "Gioco/LeiSbuca",
		"Gioco/EnigmaAcquari"]
const MURO := Vector3(-6.97, -0.75, -0.2)
## Dove sta il giocatore: il punto del video, poi più vicino, poi quasi al muro.
const PUNTI := [Vector3(-3.6, 0, -0.25), Vector3(-4.8, 0, -0.25), Vector3(-5.9, 0, -0.25)]

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
	await _metti(PUNTI[0], MURO)
	for i in 90:
		await get_tree().process_frame
	p.process_mode = Node.PROCESS_MODE_INHERIT
	var hud := p.get_node_or_null(^"HUD")
	if hud and hud.has_method(&"show_hint"):
		hud.call(&"show_hint", "", 0.01)
	var disegno := level.get_node(^"Piscina/EnigmaGiocattoli/Disegno") as Decal
	print("texture del disegno: %s, formato %s, mipmap %s" % [disegno.texture_albedo.resource_path,
		disegno.texture_albedo.get_image().get_format(), disegno.texture_albedo.get_image().has_mipmaps()])
	for k in PUNTI.size():
		await _metti(PUNTI[k], MURO)
		await _attendi(0.8)
		await _scatto("disegno_%d" % k)
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
	get_viewport().get_texture().get_image().save_jpg(out.path_join(nome + ".jpg"), 0.95)
	print("SCATTO ", nome)
