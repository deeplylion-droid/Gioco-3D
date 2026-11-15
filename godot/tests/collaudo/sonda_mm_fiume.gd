extends Node
## Collaudo riga del fiume (#130): attorno a (-3,40; 25,15), dove la mappa a 5 cm trova un punto senza pavimento e fuori
## dall'acqua, una griglia di 2 mm per 4 cm: A acqua (dentro un poligono), P pavimento a 0, F fondo senza acqua (buco),
## B bordo (né dentro né pavimento, ma a meno di 1 mm da un poligono d'acqua) (MM:).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_mm_fiume.gd

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	while not bool(f.get(&"costruita")):
		await get_tree().process_frame
	for i in 5:
		await get_tree().physics_frame
	var polys: Array = f.get(&"_poligoni_acqua_cache")
	var sp := get_tree().root.get_world_3d().direct_space_state
	var buchi := 0
	for iz in 21:
		var z := 25.13 + iz * 0.002
		var riga := "%.3f " % z
		for ix in 21:
			var x := -3.42 + ix * 0.002
			var p := Vector2(x, z)
			var acqua := false
			var vicino := false
			for w in polys:
				if Geometry2D.is_point_in_polygon(p, w):
					acqua = true
				for k in w.size():
					var c: Vector2 = Geometry2D.get_closest_point_to_segment(p, w[k], w[(k + 1) % w.size()])
					if c.distance_to(p) < 0.001:
						vicino = true
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 2.0, z), Vector3(x, -2.0, z))
			var r := sp.intersect_ray(q)
			var y: float = r.position.y if not r.is_empty() else -9.0
			if acqua:
				riga += "A"
			elif absf(y) < 0.02:
				riga += "P"
			elif vicino:
				riga += "B"
			else:
				riga += "F"
				buchi += 1
		print("MM: " + riga)
	print("MM: colonne x da -3.420 a -3.380 ogni 2 mm; buchi veri (F) %d" % buchi)
	get_tree().quit()
