extends Node
## Screenshot dello zaino-pompa nella sala vera: lo zaino sulla rastrelliera dei bagnini, la
## pistola in mano mentre spruzza sulla turbina dello scarico e mentre aspira dalla pozza.
## Uso: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1920x1080 --script res://tests/run.gd -- res://tests/screenshots_zaino.gd <cartella> \
##        [preset] [frame di attesa]

const LEVEL := "res://scenes/sala_principale.tscn"

var out_dir := "user://screenshots_zaino"
var preset := "ultra"
var settle := 40


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2:
		preset = args[2]
	if args.size() > 3:
		settle = int(args[3])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("ultra" if preset == "ultra" else preset)
	if preset == "ultra":
		Grafica.imposta("gi", 2)
	get_tree().change_scene_to_file(LEVEL)
	await _frames(10)
	get_tree().paused = false
	var level := get_tree().current_scene
	var p: Player = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var storm: Tempesta = level.get_node("Tempesta")
	storm.automatica = false
	(level.get_node("Statua/Sfarfallio") as FlickerLight).turn_on()
	# 1) Lo zaino sulla rastrelliera dei bagnini, all'ingresso.
	var pack_node: Node3D = level.get_node("PostazioneBagnini/Zaino")
	p.teleport(Vector3(3.7, 0, 9.9), 0.0, 0.0)
	p.look_at_point(pack_node.global_position + Vector3(0, 0.3, 0))
	await _frames(settle)
	await _capture("zaino_sulla_rastrelliera")
	(level.get_node("PostazioneBagnini/Zaino/Prendi") as PackPickup).interact(p)
	await _frames(40)
	# 2) La pistola in mano mentre spruzza sulla turbina dello scarico (gonfiabile già caduto).
	var turbine: Turbine = level.get_node("Piscina/TurbinaScarico")
	(level.get_node("Piscina/GonfiabileIncastrato") as StuckInflatable).release(Vector3(0, 0, -1))
	p.water_pack.set_tank_amount(18.0)
	p.teleport(Vector3(2.6, -1.95, 1.6), PI, 0.0)
	await _frames(10)
	p.look_at_point(turbine.global_position + Vector3(0.0, 0.25, 0.0))
	await _frames(maxi(settle - 20, 10))
	Input.action_press("spray")
	await _frames(50)
	await _capture("pistola_spruzza_turbina")
	Input.action_release("spray")
	await _frames(10)
	# 3) La pistola in mano mentre aspira dalla pozza.
	p.water_pack.set_tank_amount(4.0)
	p.teleport(Vector3(-2.5, -1.95, -0.4), PI, 0.0)
	await _frames(10)
	p.look_at_point(Vector3(-0.8, -2.07, 1.7))
	await _frames(maxi(settle - 20, 10))
	Input.action_press("suck")
	await _frames(45)
	await _capture("pistola_aspira_pozza")
	Input.action_release("suck")
	print("screenshot salvati in ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out_dir.path_join(file + ".jpg"), 0.92)
	print("salvato ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
