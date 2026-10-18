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
	get_tree().root.add_child(p)
	var cam := Camera3D.new()
	get_tree().root.add_child(cam)
	cam.global_position = Vector3(-12.4, 1.5, 12.0)
	cam.look_at(Vector3(-14.3, 1.3, 10.1))
	cam.make_current()
	var l := SpotLight3D.new()
	l.light_energy = 6.0
	l.spot_range = 15.0
	cam.add_child(l)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out, 0.9)
	print("salvato")
	get_tree().quit()
