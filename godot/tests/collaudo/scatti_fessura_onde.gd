extends Node
## Scatti della giunzione fra la camera delle onde e la sala pompe (controllo del cielo, 6 novembre): la fessura di 31 cm
## nel pavimento da cui si vedeva il cielo, prima (lastra tolta) e dopo (con pavimento_giunzione_onde di tecnici.gd),
## dalle stesse pose. Tecnici da solo, con l'ambiente della sala come pozze_giro.gd e una luce bassa vicino alla giunzione.
## Le pose sono in coordinate della sala (Tecnici vi sta girato di 90 gradi, in (0, -9,05, 1,36)).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_fessura_onde.gd <cartella>

const TECNICI_IN_SALA := Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)), Vector3(0, -9.05, 1.36))
const POSE := [["da_sud", Vector3(0, -7.45, 23.6), Vector3(0, -9.05, 25.5)],
		["da_nord", Vector3(0.3, -7.45, 27.4), Vector3(0, -9.05, 25.5)],
		["vicino", Vector3(-0.6, -8.3, 24.8), Vector3(-0.3, -9.1, 25.5)]]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var cartella: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "/tmp/fessura_onde"
	DirAccess.make_dir_recursive_absolute(cartella)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	var radice := Node3D.new()
	var t := (load("res://scenes/tecnici/tecnici.tscn") as PackedScene).instantiate() as Node3D
	t.set(&"giocatore_proprio", false)
	t.transform = TECNICI_IN_SALA
	radice.add_child(t)
	var we := WorldEnvironment.new()
	we.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	we.environment.sdfgi_enabled = false
	we.environment.volumetric_fog_enabled = false
	we.environment.ssil_enabled = false
	radice.add_child(we)
	var l := OmniLight3D.new()
	l.omni_range = 6.0
	l.light_energy = 0.5
	l.position = Vector3(0.8, -7.2, 24.3)
	radice.add_child(l)
	var cam := Camera3D.new()
	cam.fov = 75.0
	radice.add_child(cam)
	get_tree().root.add_child(radice)
	get_tree().current_scene = radice
	cam.make_current()
	for i in 30:
		await get_tree().process_frame
	var lastra := t.find_child("pavimento_giunzione_onde", true, false) as Node3D
	print("SCATTI: lastra %s" % [lastra.global_position if lastra else "assente"])
	for fase in ["prima", "dopo"]:
		if lastra:
			lastra.visible = fase == "dopo"
		for v in POSE:
			cam.global_position = v[1]
			cam.look_at(v[2], Vector3.UP)
			for i in 15:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(cartella.path_join("%s_%s.jpg" % [fase, v[0]]), 0.9)
	print("FINE")
	get_tree().quit()
