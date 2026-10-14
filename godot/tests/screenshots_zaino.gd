extends Node
## Screenshot dello zaino-pompa (opzione 2) nella demo: lo zaino sulla rastrelliera dello
## stanzino, la pistola in mano mentre spruzza sulla turbina e mentre aspira dalla pozza.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1280x720 --script res://tests/run.gd -- res://tests/screenshots_zaino.gd <cartella>

const LEVEL := "res://scenes/sala_principale.tscn"

var out_dir := "user://screenshots_zaino"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	await _frames(15)
	get_tree().paused = false
	var level := get_tree().current_scene
	var p: Player = GameState.player
	var lightning: Lightning = level.get_node("Luci/Lampi")
	lightning.min_interval = 999.0
	lightning.first_delay = 999.0
	(level.get_node("Statua/Sfarfallio") as FlickerLight).turn_on()
	# 1) Lo zaino sulla rastrelliera dello stanzino dei bagnini.
	var pack_node: Node3D = level.get_node("StanzinoBagnini/Zaino")
	p.teleport(Vector3(4.6, 0, 21.6), 0.0, 0.0)
	p.look_at_point(pack_node.global_position + Vector3(0, 0.32, 0))
	await _frames(30)
	await _capture("zaino_sulla_rastrelliera")
	(level.get_node("StanzinoBagnini/Zaino/Prendi") as PackPickup).interact(p)
	await _frames(40)
	# 2) La pistola in mano mentre spruzza sulla turbina dello scarico (gonfiabile già caduto).
	var turbine: Turbine = level.get_node("Piscina/TurbinaScarico")
	(level.get_node("Piscina/GonfiabileIncastrato") as StuckInflatable).release(Vector3(0, 0, -1))
	p.water_pack.set_tank_amount(16.0)
	p.teleport(Vector3(2.9, -2.38, 5.4), PI, 0.0)
	p.look_at_point(turbine.global_position + Vector3(0.0, 0.35, 0.0))
	await _frames(20)
	Input.action_press("spray")
	await _frames(55)
	await _capture("pistola_spruzza_turbina")
	Input.action_release("spray")
	await _frames(10)
	# 3) La pistola in mano mentre aspira dalla pozza.
	p.water_pack.set_tank_amount(5.0)
	p.teleport(Vector3(-1.8, -2.15, 0.6), PI, 0.0)
	p.look_at_point(Vector3(-1.2, -2.3, 3.6))
	Input.action_press("suck")
	await _frames(45)
	await _capture("pistola_aspira_pozza")
	Input.action_release("suck")
	print("screenshot salvati in ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("salvato ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
