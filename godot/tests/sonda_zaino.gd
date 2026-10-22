extends Node
## Sonda: quanto manca allo zaino-pompa per toccare la rastrelliera (raggi verso +X dal suo retro).

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var s := (load("res://scenes/interni/interni.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(s)
	for i in 5:
		await get_tree().process_frame
	var zaino := s.get_node("Zaino") as Node3D
	var rack := s.find_child("rastrelliera_zaino", true, false) as MeshInstance3D
	var tm := rack.mesh.generate_triangle_mesh()
	var inv := rack.global_transform.affine_inverse()
	var minimo := 9.0
	for mi in zaino.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var gt := m.global_transform
		var pts := m.mesh.get_faces()
		var xmax := -INF
		for p in pts:
			xmax = maxf(xmax, (gt * p).x)
		for p in pts:
			var w := gt * p
			if w.x < xmax - 0.03:
				continue
			var r := tm.intersect_ray(inv * w, (inv.basis * Vector3(1, 0, 0)).normalized())
			if not r.is_empty():
				minimo = minf(minimo, ((rack.global_transform * (r["position"] as Vector3)) - w).length())
		print("SONDA ", m.name, " xmax ", xmax)
	print("SONDA distanza minima verso la rastrelliera: ", minimo, " zaino in ", zaino.global_position)
	get_tree().quit()
