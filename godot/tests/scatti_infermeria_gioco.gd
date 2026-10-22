extends Node
## Scatti di controllo dell'infermeria del gioco (scenes/risalita/infermeria.tscn), da sola con una
## luce d'ambiente come quella della proposta. Con "risolta" il pulsante è colpito, il cassetto aperto,
## la radiografia sul negatoscopio e la cassaforte aperta.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1600x900 --script res://tests/run.gd \
##        -- res://tests/scatti_infermeria_gioco.gd <cartella> [risolta] [camere separate da virgole]

const CAMERE := {
	"stanza": [Vector3(1.6, 1.65, 3.0), Vector3(-0.6, 1.0, -2.0)],
	"negatoscopio": [Vector3(0.5, 1.6, -1.2), Vector3(0.5, 1.4, -3.2)],
	"schedario": [Vector3(-1.4, 1.6, -0.4), Vector3(-3.0, 0.8, -1.1)],
	"cassaforte": [Vector3(2.0, 1.55, -0.6), Vector3(3.2, 1.3, -1.05)],
	"dentro": [Vector3(2.55, 1.5, -0.7), Vector3(3.25, 1.15, -1.05)],   # la keycard e la Polaroid della pecora
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1]
	var risolta := a.size() > 2 and a[2] == "risolta"
	var lista: PackedStringArray = a[3].split(",") if a.size() > 3 else PackedStringArray(CAMERE.keys())
	DirAccess.make_dir_recursive_absolute(out)
	Grafica.applica_preset("alto")
	Grafica.imposta("antialiasing", 2)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.1, 0.09, 0.1)
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.15
	e.ssao_enabled = true
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.015
	we.environment = e
	get_tree().root.add_child(we)
	var f: Node3D = (load("res://scenes/risalita/infermeria.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(f)
	await get_tree().process_frame
	if risolta:
		(f.get_node("Interruttore") as WaterButton).powered = true
		var cas := f.get_node("Cassetto14") as CassettoSchedario
		cas.aperto = true
		cas.call(&"_metti")
		(f.get_node("Negatoscopio") as Negatoscopio).con_radiografia = true
		var cassa := f.get_node("Cassaforte") as CassaforteRotelle
		cassa.load_state({"cifre": [4, 1, 7], "aperta": true})
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	get_tree().root.add_child(cam)
	cam.make_current()
	for nome in lista:
		var c: Array = CAMERE[nome]
		cam.global_position = c[0]
		cam.look_at(c[1], Vector3.UP)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out.path_join("infermeria_%s%s.jpg" % [nome, "_risolta" if risolta else ""]), 0.9)
		print("salvato ", nome)
	get_tree().quit()
