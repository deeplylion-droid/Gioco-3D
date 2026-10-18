extends Node
## Scatto di controllo della Polaroid 07 sulla scrivania del monitor nella sala pompe (Xvfb). Carica solo gli
## ambienti tecnici (con la trasformazione che hanno nella sala grande) e la Polaroid dove sta nella sala.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720
##   --script res://tests/run.gd -- res://proposte/scatto_polaroid07.gd <file.jpg>

const TECNICI_XF := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0.0, -9.05, 1.36))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1] if a.size() > 1 else "/tmp/polaroid07.jpg"
	var radice := Node3D.new()
	get_tree().root.add_child(radice)
	var tec: Node3D = (load("res://scenes/tecnici/tecnici.tscn") as PackedScene).instantiate()
	tec.transform = TECNICI_XF
	tec.set(&"giocatore_proprio", false)     # niente giocatore e Environment suoi (come nella sala grande)
	radice.add_child(tec)
	# la Polaroid 07 com'è nella sala grande (sala_principale.tscn)
	var testo := FileAccess.get_file_as_string("res://scenes/sala_principale.tscn")
	var i := testo.find("[node name=\"Polaroid07\"")
	var riga := testo.substr(testo.find("transform = ", i) + 12)
	riga = riga.substr(0, riga.find("\n"))
	var xf: Transform3D = str_to_var(riga)
	var pol: Node3D = (load("res://scenes/props/polaroid.tscn") as PackedScene).instantiate()
	pol.set(&"photo", 7)
	radice.add_child(pol)
	pol.global_transform = xf
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.02, 0.025)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.48, 0.45)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	radice.add_child(env)
	var luce := OmniLight3D.new()
	luce.omni_range = 4.0
	luce.light_energy = 1.2
	luce.light_color = Color(1.0, 0.85, 0.65)
	luce.shadow_enabled = true
	radice.add_child(luce)
	luce.global_position = xf.origin + Vector3(0.6, 1.4, 0.4)
	var cam := Camera3D.new()
	radice.add_child(cam)
	cam.fov = 55.0
	cam.current = true
	for k in 10:
		await get_tree().physics_frame
	# il punto di vista: il primo, tra alcuni attorno alla scrivania, da cui la Polaroid si vede senza muri
	var spazio := get_viewport().world_3d.direct_space_state
	var mira := xf.origin + Vector3(0, 0.02, 0)
	for off in [Vector3(1.0, 0.8, 0.45), Vector3(0.9, 0.8, -0.6), Vector3(0.2, 0.9, 1.0), Vector3(0.9, 0.9, 0.0),
			Vector3(-0.2, 0.9, -1.1), Vector3(0.5, 1.0, 0.8)]:
		var q := PhysicsRayQueryParameters3D.create(mira + (off as Vector3).normalized() * 0.1, mira + off)
		if spazio.intersect_ray(q).is_empty():
			cam.global_position = mira + off
			break
	cam.look_at(mira + Vector3(0, -0.02, 0))
	luce.global_position = cam.global_position + Vector3(0, 0.5, 0)
	for k in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg(out, 0.9)
	print("scatto ", out, " xf ", xf.origin, " mesh ", tec.find_children("*", "MeshInstance3D", true, false).size(), " cam ", cam.global_position)
	get_tree().quit(0)
