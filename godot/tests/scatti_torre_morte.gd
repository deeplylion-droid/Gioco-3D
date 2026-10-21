extends Node
## Scatti di controllo della torre degli scivoli dopo una morte (riscontro del 19 ottobre: "dopo che sono
## morto una volta, è diventata tutta buia"). Ripartendo da un checkpoint della torre la sala si ricarica,
## la torre si costruisce subito e LuciRisveglio rimette il blackout a tutte le luci della scena che non
## hanno risveglio_ignora. Qui lo stesso meccanismo con la torre da sola (la sala intera più la torre non
## stanno nella memoria di llvmpipe): l'ambiente della sala, LuciRisveglio, il blackout, la torre costruita
## tutta insieme; la camera sulla pedana del terzo checkpoint.
## 1_con_la_correzione: com'è adesso; 2_come_nella_v037: le luci della torre senza risveglio_ignora
## (tranne quelle di lei, che lo avevano già), come prima della correzione.
## Uso (sotto flock /home/user/tools/render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --script res://tests/run.gd -- res://tests/scatti_torre_morte.gd [cartella]

const TORRE := "res://scenes/sala/torre/sala_torre.tscn"

var out_dir := "user://scatti_torre_morte"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var scena := Node3D.new()
	scena.name = "ProvaTorre"
	var we := WorldEnvironment.new()
	we.environment = load("res://addons/grafica/sala/ambiente_sala.tres")
	we.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	scena.add_child(we)
	var risveglio: Node = (load("res://scripts/tecnici/luci_risveglio.gd") as GDScript).new()
	risveglio.name = "LuciRisveglio"
	scena.add_child(risveglio)
	var torre := (load(TORRE) as PackedScene).instantiate() as SalaTorre
	scena.add_child(torre)
	var cam := Camera3D.new()
	cam.fov = 75.0
	scena.add_child(cam)
	get_tree().root.add_child(scena)
	get_tree().current_scene = scena
	var cp := torre.checkpoint[3]
	var spawn := cp.get_spawn_transform()
	var occhio := spawn.origin + Vector3.UP * 1.7
	cam.look_at_from_position(occhio, occhio - spawn.basis.z * 10.0 + Vector3.DOWN * 3.0, Vector3.UP)
	cam.current = true
	await _frames(60)
	await _scatto("1_con_la_correzione", torre)
	var lei: Array = torre.get(&"_lei")
	for l in torre.find_children("*", "Light3D", true, false):
		if not lei.has(l):
			l.remove_meta(&"risveglio_ignora")
	risveglio.call(&"_applica", GameState.Luci.BLACKOUT)
	await _frames(30)
	await _scatto("2_come_nella_v037", torre)
	get_tree().quit()


func _scatto(nome: String, torre: Node) -> void:
	await RenderingServer.frame_post_draw
	var accese := 0
	var luci := torre.find_children("*", "Light3D", true, false)
	for l in luci:
		if (l as Light3D).is_visible_in_tree():
			accese += 1
	var percorso := out_dir.path_join(nome + ".jpg")
	get_viewport().get_texture().get_image().save_jpg(percorso, 0.9)
	print("scatto: %s (luci della torre accese: %d su %d)" % [ProjectSettings.globalize_path(percorso), accese, luci.size()])


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame
