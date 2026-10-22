extends Node
## Scatti della proposta d'aspetto del fiume lento (godot/proposte/fiume_aspetto/fiume_aspetto.gd).
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1600x900 --script res://tests/run.gd \
##        -- res://tests/scatti_fiume.gd <cartella> <aspetto A|B> [camere separate da virgole]

const CAMERE := {
	"imbarco": [Vector3(2.4, 1.7, 10.0), Vector3(-0.6, 0.5, -12.0)],       # in piedi sulla banchina dell'imbarco
	"bivio": [Vector3(0.0, 0.5, -9.0), Vector3(0.6, 1.3, -23.0)],           # seduti sulla ciambella verso il bivio
	"bersaglio": [Vector3(0.0, 0.5, 1.5), Vector3(2.3, 1.9, -5.0)],          # il disco sul palo, da vicino
	"ramo": [Vector3(3.6, 0.5, -28.0), Vector3(12.5, 0.9, -34.6)],         # nel ramo giusto, verso l'approdo
	"approdo": [Vector3(13.0, 0.5, -34.0), Vector3(22.0, 0.4, -35.2)],     # l'approdo con la scaletta e la porta
}

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1]
	var aspetto := a[2]
	var lista: PackedStringArray = a[3].split(",") if a.size() > 3 else PackedStringArray(CAMERE.keys())
	DirAccess.make_dir_recursive_absolute(out)
	Grafica.applica_preset("alto")
	Grafica.imposta("antialiasing", 2)
	var P: GDScript = load("res://proposte/fiume_aspetto/fiume_aspetto.gd")
	var f: Node3D = P.new()
	f.set(&"aspetto", aspetto)
	get_tree().root.add_child(f)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 150.0
	get_tree().root.add_child(cam)
	cam.make_current()
	for nome in lista:
		var c: Array = CAMERE[nome]
		cam.global_position = c[0]
		cam.look_at(c[1], Vector3.UP)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out.path_join("fiume_%s_%s.jpg" % [aspetto, nome]), 0.92)
		print("salvato fiume_", aspetto, "_", nome)
	get_tree().quit()
