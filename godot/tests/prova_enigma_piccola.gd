extends Node
## Prova veloce dell'aspetto dell'enigma degli acquari fuori dalla sala (memoria bassa): la scena
## enigma_acquari.tscn da sola, con un pavimento, luce rossa d'ambiente e una luce come quelle della
## sala; il miscuglio pieno di [verde | torbido] o vuoto. Uso: ... -- res://tests/prova_enigma_piccola.gd <out.jpg> [miscuglio]

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[1]
	var mis := args[2] if args.size() > 2 else "verde"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.01, 0.01)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.35, 0.08, 0.08)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	get_tree().root.add_child(env)
	var pav := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	pav.mesh = pm
	pav.position = Vector3(15, 0, -5)
	get_tree().root.add_child(pav)
	var e := (load("res://scenes/sala/enigma_acquari.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(e)
	var luce := OmniLight3D.new()
	luce.position = Vector3(11.0, 4.0, -2.0)
	luce.light_color = Color(1.0, 0.25, 0.2)
	luce.light_energy = 2.0
	luce.omni_range = 12.0
	get_tree().root.add_child(luce)
	await get_tree().process_frame
	var misto := e.get_node("AcquarioMisto") as WaterTank
	if mis != "vuoto":
		e.set(&"stato", 3 if mis == "verde" else 1)
		misto.set_mix({"verde": 1.0} if mis == "verde" else {"torbida": 1.0})
		if mis == "gorgo":
			misto.set_mix({"torbida": 1.0})
		misto.fill = misto.max_fill
	if OS.get_environment("PROVA_GIALLO") != "":
		(e.get_node("AcquarioGiallo") as WaterTank).set_mix({OS.get_environment("PROVA_GIALLO"): 1.0})
	var cam := Camera3D.new()
	cam.fov = 62.0
	get_tree().root.add_child(cam)
	cam.global_position = Vector3(11.4, 1.7, -3.2)
	cam.look_at(Vector3(15.5, 1.0, -3.6))
	if mis == "gorgo":
		cam.global_position = Vector3(13.7, 1.85, -3.0)
		cam.look_at(Vector3(15.25, 0.55, -3.6))
	cam.make_current()
	for i in 40:
		await get_tree().process_frame
	if mis == "gorgo":
		e.call(&"svuota")
		for i in 100:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out, 0.9)
	for n in ["AcquarioGiallo", "AcquarioMisto"]:
		var t := e.get_node(n) as WaterTank
		var v := t.get_node("Vetro")
		print(n, " fill ", t.fill, " level ", t.get_level(), " vis ", t.is_visible_in_tree(), " mix ", t.mix)
		for c in v.get_children(true):
			print("   ", c.name, " vis ", c.visible, " ", c.get(&"position"))
	var gz := e.get_node("Gorgo")
	var link := e.get_node("AcquarioMisto/Acqua")
	print("gorgo in corso ", gz.call(&"in_corso"), " stato ", e.get(&"stato"), " flow1 ", link.get(&"material").get_shader_parameter("flow_point_1"), " ", link.get(&"material").get_shader_parameter("flow_shape_1"))
	var st := AcquarioVetro.stile_per({"giallo": 1.0})
	print("stile giallo ", st.absorption, " ", st.turbidity, " ", st.scatter_color, " ", st.scatter_ambient)
	var vm := ((e.get_node("AcquarioGiallo/Vetro") as Node).get_children(true)[0] as MeshInstance3D).material_override as ShaderMaterial
	for k in ["absorption", "turbidity", "scatter_color", "scatter_ambient", "level_local", "box_size", "cylinder"]:
		print("  ", k, " = ", vm.get_shader_parameter(k))
	print("salvato")
	get_tree().quit()
