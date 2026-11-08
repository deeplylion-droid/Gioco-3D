extends Node
## Collaudo riga del fiume (#130): raggi verticali (dall'alto in giù) su una griglia di 5 cm attorno ai punti del bivio
## Giusto1/Giusto2 (x ±3,1, z 24,3-25,1) dove i raggi di confronto cambiano: cosa c'è sotto (pavimento a 0, parete,
## fondo), e se il punto è in acqua. Stampa una mappa per riga (PUNTO:).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_punto_fiume.gd

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
	for cx in [-3.1, 3.1]:
		print("PUNTO: attorno a x %.1f (righe z da 24,0 a 25,4; colonne x da %.2f a %.2f, ogni 5 cm): A acqua, P pavimento a 0, F fondo sotto la banchina, altro = quota" % [cx, cx - 0.5, cx + 0.5])
		var z := 24.0
		while z <= 25.41:
			var riga := "%.2f " % z
			var x: float = cx - 0.5
			while x <= cx + 0.501:
				var acqua := false
				for w in polys:
					if Geometry2D.is_point_in_polygon(Vector2(x, z), w):
						acqua = true
				var q := PhysicsRayQueryParameters3D.create(Vector3(x, 2.0, z), Vector3(x, -2.0, z))
				var r := sp.intersect_ray(q)
				var y: float = r.position.y if not r.is_empty() else -9.0
				if acqua:
					riga += "A" if y < -0.85 else "a"
				elif absf(y) < 0.02:
					riga += "P"
				elif y < -0.85:
					riga += "F"
				else:
					riga += "?"
				x += 0.05
			print("PUNTO: " + riga)
			z += 0.05
	print("PUNTO: finito")
	get_tree().quit()
