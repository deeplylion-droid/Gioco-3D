extends Node
## Screenshot della demo della sala principale (serve un vero renderer).
## Uso (con --fixed-fps il tempo di gioco avanza di 1/60 s per frame):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1280x720 --script res://tests/run.gd -- res://tests/screenshots_sala.gd <cartella> [solo]

const LEVEL := "res://scenes/sala_principale.tscn"

var out_dir := "user://screenshots_sala"
var only := ""
var level: Node
var p: Player
var cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2:
		only = args[2]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	await _frames(15)
	get_tree().paused = false
	level = get_tree().current_scene
	p = GameState.player
	cam = Camera3D.new()
	cam.fov = 70.0
	level.add_child(cam)
	var lightning: Lightning = level.get_node("Luci/Lampi")
	lightning.min_interval = 999.0
	lightning.first_delay = 999.0
	# 1) Ingresso: dalla porta degli spogliatoi, la statua sotto il lampione.
	p.teleport(Vector3(0, 0, 18.6), 0.0, deg_to_rad(4.0))
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_release("move_forward")
	await _frames(60)
	await _player_shot("01_ingresso_statua", Vector3(0, 0, 17.2), 0.0, deg_to_rad(9.0))
	# 2) La statua da vicino, col lampo.
	p.teleport(Vector3(1.6, 0, 15.2), deg_to_rad(15.0), deg_to_rad(14.0))
	await _frames(20)
	lightning.strike(1.0)
	await _frames(4)
	await _capture("02_statua_lampo")
	await _frames(30)
	# 3) Panoramica della sala dall'alto (camera libera).
	await _cam_shot("03_panoramica", Vector3(19.0, 8.5, 15.0), Vector3(-6.0, 0.0, -6.0))
	await _cam_shot("04_panoramica_ovest", Vector3(-19.0, 7.5, 15.5), Vector3(4.0, 0.0, -8.0))
	# 5) Dalla spiaggia verso la parte profonda: la pozza, la turbina incastrata, la statua sul bordo.
	cam.current = false
	p.camera.current = true
	await _player_shot("05_piscina_pozza", Vector3(1.0, -1.25, -5.0), PI, deg_to_rad(-6.0))
	# 6) Aspirare la pozza.
	p.water_pack.set_tank_amount(2.0)
	p.teleport(Vector3(-1.5, -2.1, 0.0), PI, 0.0)
	p.look_at_point(Vector3(-1.0, -2.1, 3.2))
	Input.action_press("suck")
	await _frames(50)
	await _capture("06_aspira_pozza")
	Input.action_release("suck")
	# 7) Il gonfiabile cade, poi il getto fa girare la turbina e lo scarico fa il gorgo.
	var turbine: Turbine = level.get_node("Piscina/TurbinaScarico")
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(2.4, -2.38, 3.4), PI, 0.0)
	p.look_at_point(turbine.global_position + Vector3(0, 0.25, 0))
	Input.action_press("spray")
	await _frames(150)
	await _capture("07_getto_turbina_gorgo")
	Input.action_release("spray")
	# 8) Area bimbi e torre degli scivoli.
	cam.current = true
	await _cam_shot("08_area_bimbi", Vector3(-4.5, 3.0, 3.0), Vector3(-17.0, 3.5, -10.0))
	await _cam_shot("09_torre_scivoli", Vector3(5.0, 2.5, 4.0), Vector3(17.0, 6.0, -9.0))
	print("screenshot salvati in ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _wanted(file: String) -> bool:
	if only == "":
		return true
	for prefix in only.split(","):
		if file.begins_with(prefix):
			return true
	return false


func _player_shot(file: String, pos: Vector3, yaw: float, pitch: float) -> void:
	if not _wanted(file):
		return
	p.teleport(pos, yaw, pitch)
	await _frames(20)
	await _capture(file)


func _cam_shot(file: String, pos: Vector3, target: Vector3) -> void:
	if not _wanted(file):
		return
	cam.current = true
	cam.global_position = pos
	cam.look_at(target)
	await _frames(12)
	await _capture(file)


func _capture(file: String) -> void:
	if not _wanted(file):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("salvato ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
