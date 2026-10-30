extends Node
## Scatti ravvicinati dell'enigma dei giocattoli per il collaudo (regola del 22 ottobre: anche 1-2 cm di distacco sono un
## difetto): i tre piatti di lato e da vicino, a piscina vuota coi giocattoli dove si posano e coi piatti scesi; i
## giocattoli sui piatti; le paperelle giganti e i palloni spostati sulla spiaggia. Nella sala ridotta
## (tests/scena_ridotta.gd), preset medio, con una torcia sulla camera come negli scatti di collaudo.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_giocattoli_vicino.gd <cartella>

const SCENA := "res://scenes/sala_principale.tscn"
const TOGLI := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Atmosfera", "Sala/TorreScivoli", "Sala/Dettagli", "Sala/AreaBimbi", "Vasca", "Gioco/LeiSbuca",
		"Gioco/EnigmaAcquari"]
const SPIAGGIA := ["ogg_paperella_gigante_0", "ogg_paperella_gigante_1", "ogg_pallone_spiaggia_2", "ogg_pallone_spiaggia_3",
	"ogg_pallone_spiaggia_43", "ogg_pallone_spiaggia_71"]

var cam: Camera3D
var out := ""


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
	var level := get_tree().current_scene
	var p := level.get_node_or_null(^"Player") as Node3D
	if p:
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.global_position = Vector3(12.0, 0.0, -18.0)
		var hud := p.get_node_or_null(^"HUD")
		if hud:
			hud.set(&"visible", false)
	var enigma := level.get_node(^"Piscina/EnigmaGiocattoli") as EnigmaGiocattoli
	var vasca := level.get_node(^"Piscina/Pozza") as WaterTank
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.02
	get_tree().root.add_child(cam)
	cam.make_current()
	var torcia := SpotLight3D.new()
	torcia.spot_range = 8.0
	torcia.spot_angle = 35.0
	torcia.light_energy = 3.0
	torcia.shadow_enabled = true
	cam.add_child(torcia)
	for i in 120:
		await get_tree().process_frame
	# 1. a piscina vuota, coi giocattoli dove si posano (all'inizio)
	vasca.fill = 0.0
	for i in 200:
		await get_tree().physics_frame
	for i in 3:
		var g := enigma.giocattolo(i).global_position
		await _scatto(g + Vector3(0.9, 0.35, 0.6), g + Vector3(0, 0.15, 0), "vuota_giocattolo_%d" % i)
		var c := enigma.cerchio(i).global_position
		await _scatto(c + Vector3(0.75, 0.12, 0.0), c + Vector3(0.45, 0.0, 0.0), "vuota_piatto_%d_fianco" % i)
		await _scatto(c + Vector3(0.0, 1.3, 0.9), c, "vuota_piatto_%d" % i)
	# 2. risolto: i giocattoli sui piatti scesi
	enigma.load_state({"risolto": true})
	for i in 60:
		await get_tree().physics_frame
	for i in 3:
		var c := enigma.cerchio(i).global_position
		await _scatto(c + Vector3(0.85, 0.25, 0.5), c + Vector3(0, 0.1, 0), "risolto_giocattolo_%d" % i)
		await _scatto(c + Vector3(-0.7, 0.1, -0.2), c + Vector3(-0.4, 0.0, -0.1), "risolto_piatto_%d_fianco" % i)
	# 3. la spiaggia: paperelle e palloni spostati
	var oggetti := level.get_node(^"Sala/Oggetti") as Node3D
	for nome in SPIAGGIA:
		var o := oggetti.get_node(NodePath(nome)) as Node3D
		var q := o.global_position
		await _scatto(q + Vector3(0.7, 0.25, 0.55), q + Vector3(0, 0.1, 0), "spiaggia_" + nome.trim_prefix("ogg_"))
	print("FINE")
	get_tree().quit()


func _scatto(da: Vector3, verso: Vector3, nome: String) -> void:
	cam.look_at_from_position(da, verso, Vector3.UP)
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(nome + ".png"))
	print("SCATTO ", nome)
