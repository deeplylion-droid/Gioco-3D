extends Node
## Scatti di controllo del fiume lento del gioco (scenes/risalita/fiume.tscn), da solo con una luce
## d'ambiente come quella della proposta (nel gioco la dà la sala). Più scatti per processo.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1600x900 --script res://tests/run.gd \
##        -- res://tests/scatti_fiume_gioco.gd <cartella> [camere separate da virgole]
## I file: fiume_arrivo_<camera>.jpg; con SCATTI_GIRATE=1 le tre paratie sono girate (fiume_girate_<camera>.jpg).

const F := preload("res://scripts/risalita/fiume_gioco.gd")


static func camere() -> Dictionary:
	return {
		"piazza": [Vector3(F.INGRESSO_X, 1.7, F.Z0 + 1.0), Vector3(-3.6, 0.6, -3.6)],
		"imbarco": [Vector3(-2.3, 0.6, -2.3), Vector3(0.0, 0.9, -13.0)],
		"bivio1": [F.anello(62.0) + Vector3(0, 0.6, 0), F.anello(90.0) + Vector3(0, 1.6, 0)],
		"ramo": [F.anello(115.0) + Vector3(0, 0.6, 0), F.anello(150.0) + Vector3(0, 1.2, 0)],
		"bivio3": [F.anello(238.0) + Vector3(0, 0.6, 0), F.anello(229.0, F.R - 2.2) + Vector3(0, 1.8, 0)],
		"approdo": [Vector3(-29.6, 0.6, 0.0), Vector3(-40.0, 0.8, 0.0)],
		"alto": [Vector3(-6.0, 70.0, 0.1), Vector3(-6.0, 0.0, 0.0)],
		# lo scivolo in fondo al ramo sbagliato 2 (scelta B): dalla ciambella e dalla banchina
		"scivolo_ciambella": [Vector3(0.0, 0.75, 11.0), Vector3(0.0, 0.0, 2.0)],
		# (prima la camera era a x 3,0, dentro la faccia di un pannello di roccia: ora sulla banchina davanti)
		"scivolo_banchina": [Vector3(1.95, 1.6, 12.0), Vector3(0.0, 0.2, 5.0)],
		# le tre paratie dalla barca, poco prima di arrivarci
		"paratia1": [F.anello(45.0) + Vector3(0, 0.6, 0), F.anello(55.0) + Vector3(0, 1.0, 0)],
		"paratia2": [F.anello(135.0) + Vector3(0, 0.6, 0), F.anello(145.0) + Vector3(0, 1.0, 0)],
		"paratia3": [F.anello(222.0) + Vector3(0, 0.6, 0), F.anello(232.0) + Vector3(0, 1.0, 0)],
		# da vicino, per il collaudo: la pila di ciambelle, il cartello dei tuffi
		"pila_ciambelle": [Vector3(-2.7, 1.6, -7.7), Vector3(-4.6, 0.4, -9.2)],
		"cartello_tuffi": [Vector3(-2.7, 1.7, -5.3), Vector3(-4.2, 1.6, -6.0)],
	}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1]
	var cam_tutte := camere()
	var lista: PackedStringArray = a[2].split(",") if a.size() > 2 else PackedStringArray(cam_tutte.keys())
	DirAccess.make_dir_recursive_absolute(out)
	Grafica.applica_preset("alto")
	Grafica.imposta("antialiasing", 2)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.2, 0.18, 0.17)
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.1
	e.ssr_enabled = true
	e.ssao_enabled = true
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.025
	we.environment = e
	get_tree().root.add_child(we)
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(f)
	var girate := OS.get_environment("SCATTI_GIRATE") == "1"
	if girate:
		await get_tree().process_frame
		for pf in f.find_children("*", "ParatiaFiume", true, false):
			(pf as ParatiaFiume).gira()
		for i in 240:
			await get_tree().physics_frame
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 200.0
	get_tree().root.add_child(cam)
	cam.make_current()
	for nome in lista:
		var c: Array = cam_tutte[nome]
		f.get_node("Tetto").visible = nome != "alto"
		cam.global_position = c[0]
		cam.look_at(c[1], Vector3.UP if nome != "alto" else Vector3.FORWARD)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out.path_join("fiume_%s_%s.jpg" % ["girate" if girate else "arrivo", nome]), 0.9)
		print("salvato fiume_gioco_", nome)
	get_tree().quit()
