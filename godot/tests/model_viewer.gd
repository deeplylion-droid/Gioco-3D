extends Node
## Anteprima di modelli glTF/GLB (anche fuori dal progetto): render da 4 lati in un foglio.
## Uso: xvfb-run -a -s "-screen 0 480x360x24" godot --path godot --rendering-driver vulkan \
##        --resolution 480x360 --script res://tests/run.gd -- res://tests/model_viewer.gd out.png a.glb b.glb
## Argomenti: <png_uscita> <glb1> [<glb2> ...]
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	Game.pause_on_focus_loss = false
	var args := OS.get_cmdline_user_args()
	var out: String = args[1]
	var root3d := Node3D.new()
	get_tree().root.add_child(root3d)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.17, 0.19)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.85)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(35), 0)
	sun.light_energy = 1.6
	root3d.add_child(sun)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.current = true
	var shots: Array[Image] = []
	for i in range(2, args.size()):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(args[i], state) != OK:
			printerr("non carico ", args[i])
			continue
		var model: Node3D = doc.generate_scene(state)
		root3d.add_child(model)
		var aabb := _aabb(model)
		print(args[i].get_file(), " misure: ", aabb.size, " centro: ", aabb.get_center())
		var c := aabb.get_center()
		var r := aabb.size.length() * 0.9
		for yaw in [35.0, 125.0, 215.0, 305.0]:
			var dir := Vector3(sin(deg_to_rad(yaw)), 0.45, cos(deg_to_rad(yaw))).normalized()
			cam.global_position = c + dir * r
			cam.look_at(c)
			for f in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			shots.append(get_viewport().get_texture().get_image())
		model.queue_free()
		await get_tree().process_frame
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var rows := int(ceil(shots.size() / 4.0))
	var sheet := Image.create(w * 4, h * rows, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 4) * w, (i / 4) * h))
	sheet.save_png(out)
	get_tree().quit()
func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
