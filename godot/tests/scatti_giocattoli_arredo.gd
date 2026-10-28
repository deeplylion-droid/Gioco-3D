extends Node
## Scatti dei gonfiabili d'arredo spostati dalla parte profonda della piscina a onde alla spiaggia (enigma dei giocattoli,
## docs/proposte/enigma_giocattoli/): la parte profonda vuota dall'alto, prima (gli oggetti dove li mette il GLB della
## sala) e dopo (dove li mette la scena), e la spiaggia dopo. Nella sala ridotta (tests/scena_ridotta.gd), preset medio.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_giocattoli_arredo.gd <cartella>

const SCENA := "res://scenes/sala_principale.tscn"
const TOGLI := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Atmosfera", "Sala/TorreScivoli", "Sala/Dettagli", "Sala/AreaBimbi", "Vasca", "Gioco/LeiSbuca",
		"Gioco/EnigmaAcquari"]
const SPOSTATI := ["ogg_paperella_gigante_0", "ogg_paperella_gigante_1", "ogg_pallone_spiaggia_2", "ogg_pallone_spiaggia_3",
	"ogg_pallone_spiaggia_43", "ogg_pallone_spiaggia_71"]
const PROFONDA := [Vector3(-3.0, 3.2, -1.0), Vector3(1.0, -2.0, 4.0)]
const SPIAGGIA := [Vector3(0.5, 0.6, 3.0), Vector3(0.0, -1.2, -7.0)]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(out)
	Game.pause_on_focus_loss = false
	Grafica.applica_preset("medio")
	Engine.set_meta(&"precarica_torre_spento", true)
	get_tree().change_scene_to_file(load("res://tests/scena_ridotta.gd").riduci(SCENA, TOGLI))
	while get_tree().current_scene == null or get_tree().current_scene == self:
		await get_tree().process_frame
	var level := get_tree().current_scene
	var p := level.get_node_or_null(^"Player") as Node3D
	if p:
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.global_position = Vector3(12.0, 0.0, -18.0)
		var hud := p.get_node_or_null(^"HUD")
		if hud:
			hud.set(&"visible", false)
	(level.get_node(^"Piscina/Pozza") as WaterTank).fill = 0.0
	for i in 150:
		await get_tree().process_frame
	var cam := Camera3D.new()
	cam.fov = 70.0
	get_tree().root.add_child(cam)
	cam.make_current()
	await _scatto(cam, PROFONDA, out.path_join("arredo_dopo.png"))
	await _scatto(cam, SPIAGGIA, out.path_join("arredo_spiaggia.png"))
	# prima: gli oggetti dove li mette il GLB
	var glb := (load("res://assets/ambiente/sala/sala_oggetti.glb") as PackedScene).instantiate() as Node3D
	var oggetti := level.get_node(^"Sala/Oggetti") as Node3D
	for nome in SPOSTATI:
		var o := oggetti.get_node(NodePath(nome)) as Node3D
		o.transform = (glb.get_node(NodePath(nome)) as Node3D).transform
	glb.free()
	await _scatto(cam, PROFONDA, out.path_join("arredo_prima.png"))
	print("FINE")
	get_tree().quit()


func _scatto(cam: Camera3D, posto: Array, file: String) -> void:
	cam.look_at_from_position(posto[0], posto[1], Vector3.UP)
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(file)
	print("SCATTO ", file)
