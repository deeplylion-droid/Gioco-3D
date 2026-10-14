extends Node
## Vista di lavoro di una LanceRig (lato, alto, prima persona) per sistemare mani e oggetti.
## Uso: xvfb-run -a -s "-screen 0 480x360x24" godot --path godot --rendering-driver vulkan --resolution 480x360 \
##        --script res://tests/run.gd -- res://tests/rig_viewer.gd out.png res://scenes/player/lance/lancia_opzione2.tscn "0.12,-0.18,-0.8"
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	Game.pause_on_focus_loss = false
	var args := OS.get_cmdline_user_args()
	var root3d := Node3D.new()
	get_tree().root.add_child(root3d)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.3, 0.32, 0.36)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.7
	env.environment = e
	root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	root3d.add_child(sun)
	var rig: Node3D = load(args[2]).instantiate()
	var o := args[3].split_floats(",")
	var holder := Node3D.new()
	root3d.add_child(holder)
	holder.add_child(rig)
	rig.position = Vector3(o[0], o[1], o[2])
	holder.basis = Basis.looking_at(Vector3(0, 0, -6) - rig.position, Vector3.UP)
	rig.position = Vector3.ZERO
	holder.position = Vector3(o[0], o[1], o[2])
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.current = true
	cam.near = 0.03
	cam.fov = 75
	var shots: Array[Image] = []
	for v in [[Vector3(1.2, 0.0, -0.6), Vector3(0, -0.2, -0.6), 40.0], [Vector3(0.1, 1.2, -0.55), Vector3(0.1, -0.2, -0.56), 40.0], [Vector3.ZERO, Vector3(0, 0, -5), 75.0]]:
		cam.fov = v[2]
		cam.global_position = v[0]
		if v[0] == Vector3.ZERO:
			cam.rotation = Vector3.ZERO
		else:
			cam.look_at(v[1], Vector3.UP if absf(v[0].y) < 1.0 else Vector3.FORWARD)
		for f in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		shots.append(get_viewport().get_texture().get_image())
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var sheet := Image.create(w * 3, h, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	sheet.save_png(args[1])
	get_tree().quit()
