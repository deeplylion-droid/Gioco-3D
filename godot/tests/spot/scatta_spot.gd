extends Node
## Scatti dal motore delle inquadrature dello spot VHS (godot/scenes/spot/), a qualità piena: carica la scena, mette
## la camera e salva un PNG per riga della lista. Serve un vero renderer (xvfb-run + vulkan, sotto il render.lock).
## Uso:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver vulkan --resolution 1920x1080 \
##       --script res://tests/run.gd -- res://tests/spot/scatta_spot.gd <scena.tscn> <cartella> <lista> [attesa_s]
## La lista ha una riga per scatto: nome cx cy cz mx my mz [fov]  (camera in c, guarda verso m).
## attesa_s: secondi di gioco prima del primo scatto (la GI e le sonde si assestano), di serie 6.

var _args: PackedStringArray


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _run() -> void:
	var scena := (load(_args[1]) as PackedScene).instantiate()
	get_tree().root.add_child(scena)
	var cartella := _args[2]
	DirAccess.make_dir_recursive_absolute(cartella)
	var righe := FileAccess.get_file_as_string(_args[3]).split("\n", false)
	var attesa := float(_args[4]) if _args.size() > 4 else 6.0
	var cam := scena.get_node_or_null(^"Camera") as Camera3D
	if cam == null:
		cam = Camera3D.new()
		scena.add_child(cam)
	cam.current = true
	var primo := true
	for r in righe:
		var c := r.strip_edges().split(" ", false)
		if c.size() < 7 or c[0].begins_with("#"):
			continue
		cam.global_position = Vector3(float(c[1]), float(c[2]), float(c[3]))
		cam.look_at(Vector3(float(c[4]), float(c[5]), float(c[6])), Vector3.UP)
		cam.fov = float(c[7]) if c.size() > 7 else 60.0
		# la prima volta si aspetta che GI, sonde e acqua si assestino; poi bastano pochi fotogrammi
		var fotogrammi := int(attesa * 60.0) if primo else 90
		primo = false
		for i in fotogrammi:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(cartella.path_join(c[0] + ".png"))
		printerr("SCATTO ", c[0], " ", Performance.get_monitor(Performance.TIME_FPS), " fps")
	get_tree().quit()
