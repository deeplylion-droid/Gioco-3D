extends Node
## Collaudo riga del fiume (#130, seconda correzione): scatti da vicino dei punti dove la sonda delle pareti trova pareti
## con l'acqua dai due lati (dove le toppe d'acqua hanno preso il posto delle lame): da 1,5 m, dall'altezza degli occhi
## sulla ciambella (1,3) e più in basso (0,6), da quattro lati. Luci del blackout e ambiente della sala.
## Uso (sotto il render.lock): xvfb-run ... --script res://tests/run.gd -- res://tests/collaudo/fiume_pinne.gd <cartella>

const PUNTI := {"bivio_nord_ovest": Vector3(-3.1, 0, 24.83), "bivio_nord_est": Vector3(3.1, 0, 24.83),
	"bivio_est_nord": Vector3(24.9, 0, -3.1), "bivio_est_sud": Vector3(25.2, 0, 3.16), "bivio_ovest": Vector3(-25.2, 0, 3.16)}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var cart: String = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.luci = GameState.Luci.BLACKOUT
	Grafica.applica_preset("alto")
	var we := WorldEnvironment.new()
	we.environment = load("res://addons/grafica/sala/ambiente_sala.tres") as Environment
	we.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(we)
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	add_child(cam)
	cam.make_current()
	while not bool(f.get(&"costruita")):
		await get_tree().process_frame
	for i in 120:
		await get_tree().process_frame
	# una luce per vedere (le luci del blackout lì sono deboli): una lampadina sulla camera
	var lamp := OmniLight3D.new()
	lamp.omni_range = 6.0
	lamp.light_energy = 1.5
	cam.add_child(lamp)
	for nome in PUNTI:
		var p: Vector3 = PUNTI[nome]
		for a in [0, 90, 180, 270]:
			for h in [1.3, 0.6]:
				var d := Vector3(sin(deg_to_rad(a)), 0, cos(deg_to_rad(a)))
				cam.global_position = p + d * 1.5 + Vector3.UP * h
				cam.look_at(p + Vector3.DOWN * 0.2, Vector3.UP)
				for i in 8:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_jpg(cart.path_join("%s_%03d_%s.jpg" % [nome, a, "occhi" if h > 1.0 else "basso"]), 0.88)
	print("PINNE FINITO")
	get_tree().quit()
