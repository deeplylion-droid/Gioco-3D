extends Node
## Prova veloce del disegno dei bambini (materiale e nastro) fuori dalla sala: un acquario A alto
## della proposta con la luce di una torcia. Uso: ... --script res://tests/run.gd -- res://tests/prova_disegno.gd <out.jpg>

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_cmdline_user_args()[1]
	var P: GDScript = load("res://proposte/acquari/proposta_acquari.gd")
	var p: Node3D = P.new()
	p.set(&"posizione", "1")
	p.set(&"miscuglio", "verde")
	var args := OS.get_cmdline_user_args()
	if args.size() > 2:
		p.set(&"stile", args[2])
	get_tree().root.add_child(p)
	var cam := Camera3D.new()
	get_tree().root.add_child(cam)
	cam.global_position = Vector3(-10.4, 1.5, 12.3)
	cam.look_at(Vector3(-11.1, 0.95, 10.2))
	cam.make_current()
	var l := SpotLight3D.new()
	l.light_energy = 6.0
	l.spot_range = 15.0
	cam.add_child(l)
	await get_tree().process_frame
	var nascondi := OS.get_environment("PROVA_NASCONDI")
	if nascondi != "":
		var acq := p.find_child("AcquarioMiscuglio", true, false).get_node("Acqua")
		for c in acq.get_children(true):
			if c.name == nascondi:
				c.visible = false
				print("nascosto ", c.name)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.05, 0.05)
	env.environment.ambient_light_color = Color(0.4, 0.1, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	get_tree().root.add_child(env)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out, 0.9)
	print("salvato")
	get_tree().quit()
