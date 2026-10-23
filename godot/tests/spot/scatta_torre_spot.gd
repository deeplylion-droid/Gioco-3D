extends Node
## Scatti dal motore dell'inquadratura 4 dello spot (scenes/spot/torre_spot.tscn): carica la torre pulita, mette la
## camera e salva un PNG per riga della lista. Serve un vero renderer (xvfb-run + vulkan, sotto il render.lock).
## Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##       --script res://tests/run.gd -- res://tests/spot/scatta_torre_spot.gd <cartella> <lista> [attesa_s]
## Righe della lista:  nome s [fov]                     (la camera di chi scende, a s metri dalla bocca del tubo)
##                     nome cx cy cz mx my mz [fov]     (camera libera in c, guarda verso m)

var _args: PackedStringArray


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _run() -> void:
	var scena := (load("res://scenes/spot/torre_spot.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(scena)
	var cartella := _args[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	var righe := FileAccess.get_file_as_string(_args[2]).split("\n", false)
	var attesa := float(_args[3]) if _args.size() > 3 else 6.0
	var cam := scena.get_node(^"Camera") as Camera3D
	cam.current = true
	var primo := true
	for r in righe:
		var c := r.strip_edges().split(" ", false)
		if c.size() < 2 or c[0].begins_with("#"):
			continue
		if c.size() >= 7:
			cam.global_position = Vector3(float(c[1]), float(c[2]), float(c[3]))
			cam.look_at(Vector3(float(c[4]), float(c[5]), float(c[6])), Vector3.UP)
			cam.fov = float(c[7]) if c.size() > 7 else 60.0
		else:
			var s := float(c[1])
			cam.global_transform = scena.call(&"posa_camera", s)
			cam.fov = float(c[2]) if c.size() > 2 else 75.0
			scena.call(&"segui_camera", s)
		var fotogrammi := int(attesa * 60.0) if primo else 60
		primo = false
		for i in fotogrammi:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(cartella.path_join(c[0] + ".png"))
		printerr("SCATTO ", c[0])
	get_tree().quit()
