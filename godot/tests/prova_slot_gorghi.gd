extends Node
## Prova (non è nella CI): lo stesso gorgo nello slot 0 e nello slot 1 di una WaterBody, visto
## dall'alto; salva nessuno.jpg, slot0.jpg, slot1.jpg nella cartella data.

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_cmdline_user_args()[1]
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.35, 0.4)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	get_tree().root.add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-50, 30, 0)
	get_tree().root.add_child(sole)
	var w := WaterBody.new()
	w.size = Vector2(6, 6)
	w.level = 0.0
	w.bottom = -1.0
	w.max_level = 0.0
	w.vortex_on_drain = false
	get_tree().root.add_child(w)
	var cam := Camera3D.new()
	get_tree().root.add_child(cam)
	cam.global_position = Vector3(0, 4.5, 2.5)
	cam.look_at(Vector3.ZERO)
	cam.make_current()
	for prova in ["nessuno", "slot0", "slot1"]:
		w.clear_flow(0)
		w.clear_flow(1)
		var slot := -1 if prova == "nessuno" else int(prova.right(1))
		for i in 60:
			if slot >= 0:
				w.set_flow(slot, Vector3.ZERO, 2.0, 1.0, 1.5, 0.3, 0.55, 1.0)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, prova])
		var m := w.material as ShaderMaterial
		print("PROVA %s fp0 %s fp1 %s dip_cpu %.3f" % [prova, m.get_shader_parameter("flow_point_0"), m.get_shader_parameter("flow_point_1"), w.call(&"_flow_dip", Vector2.ZERO)])
	get_tree().quit()
