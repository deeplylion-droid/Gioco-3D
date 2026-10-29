extends Node
## Sonda: a pozza vuota, su cosa poggiano i giocattoli dell'enigma (i raggi di Posa sotto la loro impronta).

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate() as Node3D
	add_child(s)
	for i in 30:
		await get_tree().physics_frame
	(s.get_node(^"Piscina/Pozza") as WaterTank).fill = 0.0
	for i in 200:
		await get_tree().physics_frame
	var e := s.get_node(^"Piscina/EnigmaGiocattoli") as EnigmaGiocattoli
	var escludi: Array[RID] = []
	for i in 3:
		escludi.append(e.giocattolo(i).get_rid())
	for i in 3:
		var g := e.giocattolo(i)
		print("GIOCATTOLO %d y %.4f pos %s" % [i, g.global_position.y, g.global_position])
		var im: Vector2 = EnigmaGiocattoli.IMPRONTE[i]
		for k in 9:
			var l := Vector3.ZERO if k == 8 else Vector3(cos(TAU * k / 8.0) * im.x, 0.0, sin(TAU * k / 8.0) * im.y)
			var p := g.global_position + g.global_basis.orthonormalized() * l
			var h: Dictionary = Posa._raggio(g, Vector3(p.x, g.global_position.y + 0.4, p.z), Vector3(p.x, g.global_position.y - 0.5, p.z), escludi)
			var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, g.global_position.y + 0.4, p.z), Vector3(p.x, g.global_position.y - 0.5, p.z), Layers.WORLD, escludi)
			var hf := s.get_world_3d().direct_space_state.intersect_ray(q)
			print("  punto %d: posa %s su %s | fisica %s su %s" % [k, (h.position as Vector3).y if not h.is_empty() else "niente",
				(h.collider as Node).get_path() if not h.is_empty() else "-", (hf.position as Vector3).y if not hf.is_empty() else "niente",
				(hf.collider as Node).name if not hf.is_empty() else "-"])
	get_tree().quit()
