extends Node
## Collaudo Polaroid (0.3.24): la P16 del fiume da vicino (20-30 cm), dagli occhi (in piedi guardando giù, a 25 cm in
## orizzontale) e di lato, radente (2 cm e 6 mm sopra il pavimento), dai quattro lati. Luci del blackout e ambiente della
## sala; con LAMPADA=1 una lampadina sulla camera (le luci del blackout lì sono deboli).
## Uso (sotto il render.lock): xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720
##   --script res://tests/run.gd -- res://tests/collaudo/polaroid16_vicino.gd <cartella>


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
	cam.near = 0.01
	add_child(cam)
	cam.make_current()
	while not bool(f.get(&"costruita")):
		await get_tree().process_frame
	await get_tree().create_timer(3.0).timeout
	var ph := f.find_child("Polaroid16", true, false) as Node3D
	var c := ph.global_position
	print("VICINO: P16 in %s" % c)
	if OS.get_environment("LAMPADA") == "1":
		var lamp := OmniLight3D.new()
		lamp.omni_range = 3.0
		lamp.light_energy = 0.6
		lamp.shadow_enabled = true
		cam.add_child(lamp)
		lamp.position = Vector3(0.15, 0.25, 0)
	var viste := []
	for a in [0, 90, 180, 270]:
		var d := Vector3(sin(deg_to_rad(a)), 0, cos(deg_to_rad(a)))
		viste.append(["occhi_%03d" % a, c + d * 0.25 + Vector3.UP * 0.35, c])
		viste.append(["lato2cm_%03d" % a, c + d * 0.25 + Vector3.UP * 0.02, c + Vector3.UP * 0.003])
		viste.append(["radente_%03d" % a, c + d * 0.22 + Vector3.UP * 0.006, c + Vector3.UP * 0.002])
		# accovacciati: gli occhi a 0,97 m, a mezzo metro
		viste.append(["accovacciato_%03d" % a, c + d * 0.5 + Vector3.UP * 0.97, c])
	for v in viste:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cart.path_join("p16_%s.jpg" % v[0]), 0.9)
	print("VICINO FINITO")
	get_tree().quit()
