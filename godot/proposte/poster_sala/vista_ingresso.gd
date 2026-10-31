extends Node
## Che cosa si vede sul muro in fondo della sala dall'ingresso (dove si entra dagli spogliatoi, (0; 0; 19,2)): solo la
## geometria della sala e la statua, con una luce piatta. Uso (sotto il lock): xvfb-run ... --script res://tests/run.gd --
## res://proposte/poster_sala/vista_ingresso.gd <cartella>

const PEZZI := ["sala_architettura", "sala_cupola", "sala_piscina", "sala_area_bimbi", "sala_torre_scivoli", "sala_oggetti",
	"sala_interattivi", "sala_vasca_centrale"]
var cartella := ""


func _ready() -> void:
	cartella = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.2, 0.25)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 1.0
	add_child(env)
	for p in PEZZI:
		add_child((load("res://assets/ambiente/sala/%s.glb" % p) as PackedScene).instantiate())
	var statua := (load("res://assets/models/medusa/medusa.glb") as PackedScene).instantiate() as Node3D
	add_child(statua)
	statua.position = Vector3(0, 0, 10.15)
	var cam := Camera3D.new()
	cam.fov = 75.0
	add_child(cam)
	cam.current = true
	for v in [["ingresso", Vector3(0, 1.6, 19.2), Vector3(0, 3.0, -24)],
			["ingresso_destra", Vector3(3, 1.6, 17), Vector3(0, 3.0, -24)],
			["ingresso_sinistra", Vector3(-3, 1.6, 17), Vector3(0, 3.0, -24)],
			["muro_nord", Vector3(-1.5, 1.6, -8), Vector3(-1.5, 4.5, -24)]]:
		cam.look_at_from_position(v[1], v[2], Vector3.UP)
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cartella.path_join(v[0] + ".jpg"), 0.88)
		print("VISTA %s" % v[0])
	get_tree().quit()
