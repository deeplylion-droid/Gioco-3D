extends Node
## Scatti della proposta d'aspetto dell'infermeria (godot/proposte/infermeria_aspetto/infermeria_aspetto.gd).
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1600x900 --script res://tests/run.gd \
##        -- res://tests/scatti_infermeria.gd <cartella> <aspetto A|B> [camere separate da virgole]

const CAMERE := {
	"porta": [Vector3(1.6, 1.65, 3.0), Vector3(-0.5, 1.0, -2.3)],             # dalla porta d'ingresso
	"stanza": [Vector3(-2.7, 1.7, 2.9), Vector3(1.2, 0.9, -1.6)],            # dall'angolo vicino al lavandino
	"negatoscopio": [Vector3(0.2, 1.62, -2.35), Vector3(0.18, 1.66, -3.2)],  # la radiografia da vicino
	"scrivania": [Vector3(0.55, 1.2, -2.15), Vector3(0.5, 0.81, -2.68)],     # la Polaroid sulla scrivania
	"schedario": [Vector3(-1.3, 1.45, -0.3), Vector3(-3.0, 0.8, -1.05)],     # l'adesivo rosa nel buio
	"cassaforte": [Vector3(2.45, 1.4, -0.85), Vector3(3.2, 1.3, -1.05)],     # le tre rotelle da vicino
	"tessera": [Vector3(3.1, 1.3, -0.96), Vector3(3.32, 1.06, -0.99)],        # aperta: la keycard nel vano
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
	var P: GDScript = load("res://proposte/infermeria_aspetto/infermeria_aspetto.gd")
	var f: Node3D = P.new()
	f.set(&"aspetto", aspetto)
	# la camera "tessera" vuole la cassaforte aperta: TESSERA=1 o 2 sceglie la keycard
	if lista.size() == 1 and lista[0] == "tessera":
		f.set(&"cassaforte_aperta", true)
		f.set(&"tessera", OS.get_environment("TESSERA") if OS.get_environment("TESSERA") != "" else "1")
	get_tree().root.add_child(f)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 30.0
	get_tree().root.add_child(cam)
	cam.make_current()
	for nome in lista:
		var c: Array = CAMERE[nome]
		cam.global_position = c[0]
		cam.look_at(c[1], Vector3.UP)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out.path_join("infermeria_%s_%s%s.jpg" % [aspetto, nome, OS.get_environment("TESSERA") if nome == "tessera" else ""]), 0.92)
		print("salvato infermeria_", aspetto, "_", nome)
	get_tree().quit()
