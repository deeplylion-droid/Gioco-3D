extends Node
## Screenshot degli ambienti tecnici (scenes/tecnici/tecnici.tscn); serve un vero renderer.
## Uso:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/screenshots_tecnici.gd <cartella> \
##        [inquadrature separate da virgole] [preset] [frame di attesa]

const LEVEL := "res://scenes/tecnici/tecnici.tscn"

var out_dir := "user://screenshots_tecnici"
var only := PackedStringArray()
var preset := "alto"
var settle := 60
var level: Node
var p: Player


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2 and args[2] != "" and args[2] != "tutte":
		only = args[2].split(",")
	if args.size() > 3:
		preset = args[3]
	if args.size() > 4:
		settle = int(args[4])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _want(shot: String) -> bool:
	return only.is_empty() or only.has(shot)


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset(preset)
	get_tree().change_scene_to_file(LEVEL)
	await _frames(10)
	get_tree().paused = false
	level = get_tree().current_scene
	p = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	if _want("tecnici_camera"):
		# In fondo alla scala del pozzo, lungo la camera delle onde: pale, bocchette, paratie alzate.
		await _shot("tecnici_camera", Vector3(1.4, 0.0, 0.9), Vector3(20.0, 1.9, -0.4))
	if _want("tecnici_pompe"):
		# Le tre pompe con le turbine d'avviamento, la vasca di raccolta davanti.
		await _shot("tecnici_pompe", Vector3(40.5, 0.0, 3.2), Vector3(34.0, 1.0, -4.2))
	if _want("tecnici_leva"):
		# La leva grande dietro la grata e lo schema a colori sul muro est.
		await _shot("tecnici_leva", Vector3(41.8, 0.0, 0.2), Vector3(46.0, 2.9, -3.6))
	if _want("tecnici_scrivania"):
		# La scrivania col monitor a tubo.
		await _shot("tecnici_scrivania", Vector3(40.3, 0.0, 0.4), Vector3(41.8, 0.85, 3.3))
	get_tree().quit()


func _shot(file: String, pos: Vector3, look: Vector3) -> void:
	p.teleport(pos, 0.0, 0.0)
	p.look_at_point(look)
	await _frames(settle)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(out_dir.path_join(file + ".jpg"), 0.92)
	print("salvato ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
