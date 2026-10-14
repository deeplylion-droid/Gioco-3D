extends Node3D
## Prova rapida: una parete con il materiale bagnabile e una luce rossa vicina (cerca NaN).
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else ""
	var we := WorldEnvironment.new()
	var env: Environment = load("res://demo/ambiente_notte.tres").duplicate()
	env.glow_enabled = false
	env.ssr_enabled = mode.contains("ssr")
	env.ssao_enabled = mode.contains("ssao")
	env.volumetric_fog_enabled = false
	we.environment = env
	add_child(we)
	var m := ShaderMaterial.new()
	m.shader = load("res://water/shaders/wet_surface.gdshader")
	m.set_shader_parameter("albedo_tex", load("res://demo/textures/intonaco_albedo.jpg"))
	m.set_shader_parameter("normal_tex", load("res://demo/textures/intonaco_normal.jpg"))
	m.set_shader_parameter("orh_tex", load("res://demo/textures/intonaco_orh.jpg"))
	m.set_shader_parameter("uv_scale", 0.4)
	if mode.contains("std"):
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = load("res://demo/textures/intonaco_albedo.jpg")
		var mi0 := MeshInstance3D.new(); var bm0 := BoxMesh.new(); bm0.size = Vector3(0.3, 4, 6); mi0.mesh = bm0; mi0.material_override = sm; mi0.position = Vector3(0.15, 2, 0); add_child(mi0)
	else:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.3, 4, 6); mi.mesh = bm; mi.material_override = m; mi.position = Vector3(0.15, 2, 0); add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.06, 0.035); l.light_energy = 2.4; l.omni_range = 11.0; l.omni_attenuation = 1.5
	l.shadow_enabled = not mode.contains("noshadow")
	l.position = Vector3(-0.42, 2.5, 0)
	add_child(l)
	if mode.contains("moon"):
		var d := DirectionalLight3D.new()
		d.light_color = Color(0.55, 0.65, 0.95); d.light_energy = 0.05; d.shadow_enabled = true
		d.rotation_degrees = Vector3(-62, 25, 0)
		add_child(d)
	if mode.contains("area"):
		var al := AreaLight3D.new(); al.area_size = Vector2(1.5, 0.08); al.light_energy = 2.2; al.area_range = 13.0
		al.rotation_degrees = Vector3(-90, 0, 0); al.position = Vector3(-2, 4.0, 0); add_child(al)
	var c := Camera3D.new(); add_child(c); c.position = Vector3(-4, 2.2, 1.0); c.look_at(Vector3(0, 2.3, 0)); c.current = true
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-user/07654ebb-af35-5717-9d4e-86afbe1a6c7d/scratchpad/tp_%s.png" % mode)
	get_tree().quit()
