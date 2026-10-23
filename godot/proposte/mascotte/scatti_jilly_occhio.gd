extends Node
## Scatti dal motore dell'occhio di Jilly per il finale dello spot (inquadratura 8): gli instance uniform "pupilla" e
## "vene" di medusa_occhio.gdshader su JillySpot (scripts/spot/jilly_spot.gd), in primo piano. In più prova saluta() e
## pupilla_battito() (senza l'OcchioIpnotico: il battito semplice) e stampa i valori.
## Uso (sotto render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 60 --script res://tests/run.gd -- res://proposte/mascotte/scatti_jilly_occhio.gd <cartella>

## nome: [pupilla, vene]
const SCATTI := [
	["pupilla_0_5", 0.5, 0.0], ["pupilla_1", 1.0, 0.0], ["pupilla_2", 2.0, 0.0],
	["vene_0_5", 1.4, 0.5], ["vene_1", 1.8, 1.0],
]

var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var radice := Node3D.new()
	add_child(radice)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.75)
	env.ambient_light_energy = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	radice.add_child(we)
	var jilly: Node3D = load("res://scripts/spot/jilly_spot.gd").new()
	jilly.name = "Jilly"
	jilly.set(&"model", load("res://assets/models/medusa/medusa.glb"))
	jilly.set(&"bell_material", load("res://assets/models/medusa/medusa_campana.tres"))
	jilly.set(&"material_map", {"M_occhio_bulbo": load("res://assets/models/medusa/medusa_occhio.tres")})
	radice.add_child(jilly)
	for i in 5:
		await get_tree().process_frame
	var occhio: Vector3 = jilly.call(&"get_eye_position")
	var dir := Vector3.BACK          # lei guarda verso +Z
	var o := jilly.call(&"occhio") as GeometryInstance3D
	# l'occhio dritto davanti (lo sguardo che segue il giocatore qui non ha un giocatore)
	for m in jilly.find_children("SguardoOcchio", "", true, false):
		(m as SkeletonModifier3D).active = false
	print("occhio ", occhio, " mesh ", o)
	var luce := SpotLight3D.new()
	luce.light_color = Color(1.0, 0.9, 0.95)
	luce.light_energy = 3.0
	luce.spot_range = 6.0
	luce.spot_angle = 25.0
	radice.add_child(luce)
	luce.global_position = occhio + dir * 2.0 + Vector3(0.4, 0.6, 0)
	luce.look_at(occhio, Vector3.UP)
	var rosa := OmniLight3D.new()
	rosa.light_color = Color(1.0, 0.35, 0.72)
	rosa.light_energy = 1.5
	rosa.omni_range = 4.0
	radice.add_child(rosa)
	rosa.global_position = occhio + dir * 1.0 + Vector3(-0.8, -0.3, 0)
	var cam := Camera3D.new()
	radice.add_child(cam)
	cam.current = true
	cam.near = 0.02
	cam.global_position = occhio + dir * 0.95
	cam.look_at(occhio, Vector3.UP)
	cam.fov = 35.0
	for s in SCATTI:
		o.set_instance_shader_parameter(&"pupilla", s[1])
		o.set_instance_shader_parameter(&"vene", s[2])
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var f := out_dir.path_join(String(s[0]) + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.9)
		print("scatto -> ", f)
	# prova dei metodi per la regia
	o.set_instance_shader_parameter(&"pupilla", 1.0)
	o.set_instance_shader_parameter(&"vene", 0.0)
	jilly.call(&"saluta", 1.0)
	var ap := jilly.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	for i in 30:
		await get_tree().process_frame
	print("saluto, dopo 0,5 s: ", ap.current_animation)
	for i in 60:
		await get_tree().process_frame
	print("saluto, dopo 1,5 s: ", ap.current_animation)
	for i in 60:
		await get_tree().process_frame
	print("saluto, dopo 2,5 s: ", ap.current_animation)
	jilly.call(&"pupilla_battito", 1.0)
	var massimo := 0.0
	for i in 70:
		await get_tree().process_frame
		massimo = maxf(massimo, float(o.get_instance_shader_parameter(&"pupilla")))
	print("battito: pupilla fino a %.2f, vene alla fine %.2f" % [massimo, float(o.get_instance_shader_parameter(&"vene"))])
	get_tree().quit()
