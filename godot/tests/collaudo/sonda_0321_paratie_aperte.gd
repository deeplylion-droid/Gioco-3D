extends Node
## Sonda del collaudo 0.3.21 (mascotte): le 6 paratie delle condotte chiuse e aperte (apri_paratia, poi alzate del
## tutto): per ogni pannello, i pezzi piccoli della sala (meno di 1,5 m: lampade, staffe, montanti, led) il cui riquadro
## entra in quello del pannello di più di 5 mm, e di quanto. Poi i vertici veri di quei pezzi dentro il riquadro del
## pannello (nel suo spazio), per non contare gli angoli vuoti dei riquadri.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_0321_paratie_aperte.gd

func _ready() -> void:
	_run.call_deferred()


func _f(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	await _f(30)
	var ins := torre.inseguimento as SalaInseguimento
	ins.tempo_presa = 9999.0
	ins.comparsa = PackedFloat32Array([9999.0, 9999.0, 9999.0])
	for stato in ["chiuse", "aperte"]:
		if stato == "aperte":
			for k in ins.paratie.size():
				ins.apri_paratia(k)
			await _f(60 * 12)
		for k in ins.paratie.size():
			var d: Dictionary = ins.paratie[k]
			var pan := d["pannello_nodo"] as Node3D
			if pan == null:
				continue
			var pezzi: Array = pan.find_children("*", "MeshInstance3D", true, false)
			if stato == "chiuse":
				var tipi := {}
				for c in pan.find_children("*", "", true, false):
					tipi[c.get_class()] = int(tipi.get(c.get_class(), 0)) + 1
				print("paratia %d: nodo %s (%s), mesh %d, figli %s" % [k, pan.name, pan.get_class(), pezzi.size(), tipi])
			if pan is MeshInstance3D:
				pezzi.append(pan)
			for pm: MeshInstance3D in pezzi:
				var inv := pm.global_transform.affine_inverse()
				var box := pm.get_aabb().grow(-0.005)
				for mi: MeshInstance3D in ins.find_children("*", "MeshInstance3D", true, false):
					if mi == pm or pan.is_ancestor_of(mi) or mi == pan or mi.mesh == null or not mi.is_visible_in_tree():
						continue
					var gb := mi.global_transform * mi.get_aabb()
					if gb.size.length() > 1.5 or not gb.intersects(pm.global_transform * box):
						continue
					var dentro := 0
					var piu := 0.0
					for s in mi.mesh.get_surface_count():
						for v: Vector3 in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
							var q := inv * (mi.global_transform * v)
							if box.has_point(q):
								dentro += 1
								piu = maxf(piu, minf(minf(minf(q.x - box.position.x, box.end.x - q.x), minf(q.y - box.position.y, box.end.y - q.y)), minf(q.z - box.position.z, box.end.z - q.z)))
					print("%s paratia %d (vasca %d, %s) %s: %s %s, %d vertici dentro il pannello (al più %.1f mm)" % [stato, k, int(d["vasca"]) + 1,
							"giusta" if bool(d["giusta"]) else "sbagliata", pm.name, String(ins.get_path_to(mi)).right(70), gb.size.snapped(Vector3.ONE * 0.01), dentro, (piu + 0.005) * 1000.0 if dentro > 0 else 0.0])
	print("PARATIE FINITE")
	get_tree().quit()
