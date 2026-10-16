extends Node
## Screenshot della scena di prova da alcuni punti di vista (serve un vero renderer).
## Uso (con --fixed-fps il tempo di gioco avanza di 1/60 s per frame, anche se il rendering è lento):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1280x720 --script res://tests/run.gd -- res://tests/screenshots.gd <cartella>

const LEVEL := "res://scenes/test/test_level.tscn"

var out_dir := "user://screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	await _frames(20)
	get_tree().paused = false
	var p: Player = GameState.player
	var level := get_tree().current_scene
	p.input_enabled = false
	# 1) Stanza di partenza dal punto d'inizio.
	await _shot(p, "01_partenza", Vector3(0, 0, 5.2), 0.0, -0.08)
	# 2) Getto sulla turbina, la porta si apre.
	p.input_enabled = true
	p.teleport(Vector3(-2.2, 0, -1.5), 0.0, 0.0)
	p.look_at_point(Vector3(-3.5, 2.2, -5.8))
	Input.action_press("spray")
	await _frames(90)
	await _capture("02_getto_turbina")
	Input.action_release("spray")
	p.input_enabled = false
	# 3) Ballatoio e scala a pioli.
	await _shot(p, "03_scala_ballatoio", Vector3(1.0, 0, 0.5), deg_to_rad(-60.0), 0.15)
	# 4) Passaggio basso e nicchia.
	await _shot(p, "04_passaggio_basso", Vector3(-3.5, 0, 2.0), deg_to_rad(90.0), -0.1)
	# 5) Sala delle vasche dal corridoio.
	(level.get_node("StanzaPartenza/PortaTurbina") as PoweredDoor).stay_open = true
	await _shot(p, "05_sala_vasche", Vector3(0, 0, -9.5), 0.0, 0.05)
	# 6) Aspirazione dalla vasca sorgente.
	p.input_enabled = true
	p.teleport(Vector3(-3.6, 0, -18.0), 0.0, 0.0)
	p.look_at_point(Vector3(-5.6, 0.9, -19.6))
	Input.action_press("suck")
	await _frames(60)
	await _capture("06_aspirazione")
	Input.action_release("suck")
	# 7) Getto nella vasca grande, piattaforma che sale.
	var tank: WaterTank = level.get_node("SalaVasche/VascaGrande")
	tank.fill = 0.55
	p.teleport(Vector3(-1.2, 1.4, -15.6), 0.0, 0.0)
	p.look_at_point(Vector3(0.6, 0.0, -21.5))
	Input.action_press("spray")
	await _frames(70)
	await _capture("07_getto_vasca_piattaforma")
	Input.action_release("spray")
	p.input_enabled = false
	# 8) Dall'alto della sporgenza.
	await _shot(p, "08_sporgenza", Vector3(1.5, 2.5, -25.6), deg_to_rad(160.0), -0.35)
	print("screenshot salvati in ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _shot(p: Player, file: String, pos: Vector3, yaw: float, pitch: float) -> void:
	p.teleport(pos, yaw, pitch)
	await _frames(25)
	await _capture(file)


func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file + ".png"))
	print("salvato ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
