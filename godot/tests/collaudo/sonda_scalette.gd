extends Node
## Sonda: misure delle scalette della piscina (area della Ladder, corpi della scala, capsula del giocatore).

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene != self:
			break
	for i in 30:
		await get_tree().physics_frame
	var level := get_tree().current_scene
	var p := GameState.player
	var cs := p.collision_shape
	print("SONDA giocatore forma %s %s" % [cs.shape, (cs.shape as CapsuleShape3D).radius if cs.shape is CapsuleShape3D else -1.0])
	for nome in ["Piscina/ScalettaEst", "Piscina/ScalettaOvest"]:
		var l := level.get_node(nome) as Ladder
		print("SONDA %s pos %s cima %.2f normale %s altezza %.2f" % [nome, l.global_position, l.get_top_y(), l.get_climb_normal(), l.height])
		for c in l.find_children("*", "CollisionShape3D", true, false):
			var sh := (c as CollisionShape3D).shape
			print("SONDA   area %s %s a %s base %s" % [c.name, (sh as BoxShape3D).size if sh is BoxShape3D else sh, (c as Node3D).global_position, (c as Node3D).global_basis.get_euler()])
		for b in l.corpi_da_attraversare():
			for c in b.find_children("*", "CollisionShape3D", true, false):
				var sh2 := (c as CollisionShape3D).shape
				var aabb := AABB()
				if sh2 is ConvexPolygonShape3D:
					var pts := (sh2 as ConvexPolygonShape3D).points
					aabb = AABB((c as Node3D).global_transform * pts[0], Vector3.ZERO)
					for q in pts:
						aabb = aabb.expand((c as Node3D).global_transform * q)
				elif sh2 is BoxShape3D:
					aabb = (c as Node3D).global_transform * AABB(-(sh2 as BoxShape3D).size * 0.5, (sh2 as BoxShape3D).size)
				print("SONDA   corpo %s forma %s aabb %s fine %s" % [b.name, sh2.get_class(), aabb.position, aabb.end])
	get_tree().quit()
