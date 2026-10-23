extends Node
## Collaudo: elenca quello che serve per provare il caricamento della Risalita: i checkpoint (ordine, posizione,
## dove si riparte), i nodi "persist" e i corpi rigidi delle stanze, i raccoglibili, i segnaposto.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_risalita.gd

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and get_tree().current_scene:
			break
	for i in 30:
		await get_tree().physics_frame
	var level := get_tree().current_scene
	var ris := level.get_node(^"Risalita")
	print("SONDA checkpoint")
	for cp in level.find_children("*", "Checkpoint", true, false):
		var c := cp as Checkpoint
		print("  cp %3d %s pos=%s spawn=%s" % [c.order, level.get_path_to(c), c.global_position.snapped(Vector3.ONE * 0.01),
			c.get_spawn_transform().origin.snapped(Vector3.ONE * 0.01)])
	print("SONDA persist nella Risalita")
	for n in get_tree().get_nodes_in_group(&"persist"):
		if ris.is_ancestor_of(n):
			var cl: String = String((n.get_script() as Script).get_global_name()) if n.get_script() else n.get_class()
			var s: Variant = n.call(&"save_state") if n.has_method(&"save_state") else null
			print("  %s [%s] %s pos=%s" % [level.get_path_to(n), cl, s, (n as Node3D).global_position.snapped(Vector3.ONE * 0.01) if n is Node3D else ""])
	print("SONDA corpi rigidi e raccoglibili nella Risalita")
	for n in ris.find_children("*", "RigidBody3D", true, false):
		print("  rigido %s pos=%s" % [level.get_path_to(n), (n as Node3D).global_position.snapped(Vector3.ONE * 0.01)])
	for n in ris.find_children("*", "Node", true, false):
		if n.has_method(&"pickup") or n is Pickup or String(n.name).begins_with("Polaroid"):
			print("  raccoglibile %s %s" % [level.get_path_to(n), n.get_class()])
	print("SONDA segnaposto")
	for n in ris.find_children("*", "Marker3D", true, false):
		print("  %s pos=%s" % [level.get_path_to(n), (n as Node3D).global_position.snapped(Vector3.ONE * 0.01)])
	print("SONDA porte e passaggi della Risalita")
	for n in ris.find_children("*", "Node3D", false, false):
		print("  figlio %s %s pos=%s" % [n.name, n.get_class(), (n as Node3D).global_position.snapped(Vector3.ONE * 0.01)])
	print("SONDA zone ", ris.get(&"_zone"))
	print("SONDA polaroid totale %d raccolte %d" % [GameState.get_total(&"polaroid"), GameState.get_collected_count(&"polaroid")])
	print("SONDA velocita ", GameState.player.get(&"run_speed"), " ", GameState.player.get(&"walk_speed"), " ", GameState.player.get(&"speed"))
	Game.esci(0)
