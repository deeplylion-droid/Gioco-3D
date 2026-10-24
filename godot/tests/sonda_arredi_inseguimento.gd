extends Node
## Sonda: gli arredi della sala pompe copiati nell'inseguimento hanno la collisione? Un raggio dall'alto e uno di
## lato su ognuno (strato del mondo), e i corpi sotto ogni gruppo.

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := (load("res://scenes/sala/inseguimento/sala_inseguimento.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(s)
	for i in 30:
		await get_tree().physics_frame
	var spazio := (s as Node3D).get_world_3d().direct_space_state
	for nome in ["POMPA_1", "POMPA_2", "POMPA_3", "POMPA_3_modello", "FILTRO_1_modello", "QUADRO_elettrico", "TURBINA_1", "SCRIVANIA", "SEDIA", "QUADRO_strumenti"]:
		for n in s.find_children(nome, "Node3D", true, false):
			var mi := n as Node3D
			var g := mi.get_parent() as Node3D
			var corpi := g.find_children("*", "CollisionObject3D", true, false).size()
			var box := AABB()
			var primo := true
			for m in [mi] + mi.find_children("*", "MeshInstance3D", true, false):
				if m is MeshInstance3D:
					var ab: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
					box = ab if primo else box.merge(ab)
					primo = false
			var c := box.get_center()
			var q := PhysicsRayQueryParameters3D.create(c + Vector3.UP * (box.size.y * 0.5 + 1.0), c + Vector3.DOWN * box.size.y, 0xFFFFFFFF)
			var h := spazio.intersect_ray(q)
			var colpo := "niente" if h.is_empty() else "%s a y %.2f (cima mesh %.2f)" % [(h.collider as Node).name, (h.position as Vector3).y, box.end.y]
			printerr("SONDA %s: %d corpi nel gruppo, raggio dall'alto: %s" % [nome, corpi, colpo])
	get_tree().quit()
