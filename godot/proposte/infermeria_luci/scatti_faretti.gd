extends Node
## Scatti ravvicinati dei due faretti a soffitto dell'infermeria (cassaforte e negatoscopio): la piastra sul soffitto,
## il gambo, il barattolo, il cavo contro il soffitto e la scatola di derivazione contro il muro. Con una lampadina
## neutra accanto alla camera, solo per vederli bene (stanza da sola, come tests/scatti_infermeria_gioco.gd).
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720 --script res://tests/run.gd \
##        -- res://proposte/infermeria_luci/scatti_faretti.gd <cartella>

const CAMERE := {
	"faretto_cassaforte": [Vector3(2.0, 2.3, 0.3), Vector3(2.6, 2.95, -0.55)],
	"faretto_cassaforte_scatola": [Vector3(2.6, 2.5, 0.1), Vector3(3.15, 2.97, -0.55)],
	"faretto_negatoscopio": [Vector3(1.1, 2.3, -1.2), Vector3(0.3, 2.9, -2.4)],
	"faretto_negatoscopio_scatola": [Vector3(1.0, 2.4, -2.2), Vector3(0.3, 2.95, -3.15)],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(out)
	Grafica.applica_preset("alto")
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.1, 0.09, 0.1)
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.15
	we.environment = e
	get_tree().root.add_child(we)
	var f: Node3D = (load("res://scenes/risalita/infermeria.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(f)
	var cam := Camera3D.new()
	cam.near = 0.02
	cam.fov = 50.0
	get_tree().root.add_child(cam)
	cam.current = true
	var luce := OmniLight3D.new()
	luce.light_energy = 0.8
	luce.omni_range = 3.0
	get_tree().root.add_child(luce)
	for nome in CAMERE:
		var c: Array = CAMERE[nome]
		cam.global_position = c[0]
		cam.look_at(c[1], Vector3.UP)
		luce.global_position = c[0] + Vector3(0, -0.2, 0)
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out.path_join(nome + ".jpg"), 0.9)
		print("scatto ", nome)
	get_tree().quit()
