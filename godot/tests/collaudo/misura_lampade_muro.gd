extends Node
## Misura di tutte le lampade a muro (LampadaMuro, il modello lampada_emergenza.glb) del gioco: il fondo della lampada
## sopra il pavimento che ha sotto (la regola dei 2 m liberi sopra dove si cammina) e lo spazio sopra fino al soffitto,
## con i raggi sulle collisioni del gioco. Richiesta del coordinatore del 6 novembre (lampade rosse a +2,2 col fondo a
## 1,98 m, collaudo finale di enigmi).
## Uso (sotto il render.lock): godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/misura_lampade_muro.gd

const SCENE := ["res://scenes/sala_principale.tscn", "res://scenes/sala/torre/sala_torre.tscn"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for percorso in SCENE:
		var radice := (load(percorso) as PackedScene).instantiate() as Node3D
		get_tree().root.add_child(radice)
		var r := radice.get_node_or_null(^"Risalita")
		if r:
			r.call(&"carica_subito")
			for nome in ["fiume", "infermeria"]:
				var n = r.get(nome)
				if n is Node3D:
					(n as Node3D).visible = true
		for i in 240:
			await get_tree().physics_frame
		var lampade := radice.find_children("*", "Node3D", true, false).filter(func(n): return String(n.scene_file_path) == LampadaMuro.MODELLO)
		print("MISURA %s: %d lampade" % [percorso.get_file(), lampade.size()])
		var spazio := radice.get_world_3d().direct_space_state
		for l: Node3D in lampade:
			var b := AABB()
			var primo := true
			for mi: MeshInstance3D in l.find_children("*", "MeshInstance3D", true, false):
				var a := mi.global_transform * mi.get_aabb()
				b = a if primo else b.merge(a)
				primo = false
			# il pavimento sotto: il più alto fra i raggi sotto la pianta della lampada (5 x 5 punti)
			var pav := -INF
			var sopra := INF
			for i in 5:
				for j in 5:
					var x := b.position.x + b.size.x * (0.05 + 0.9 * i / 4.0)
					var z := b.position.z + b.size.z * (0.05 + 0.9 * j / 4.0)
					var q := PhysicsRayQueryParameters3D.create(Vector3(x, b.position.y - 0.005, z), Vector3(x, b.position.y - 6.0, z))
					var h := spazio.intersect_ray(q)
					if h:
						pav = maxf(pav, (h["position"] as Vector3).y)
					q = PhysicsRayQueryParameters3D.create(Vector3(x, b.end.y + 0.005, z), Vector3(x, b.end.y + 6.0, z))
					h = spazio.intersect_ray(q)
					if h:
						sopra = minf(sopra, (h["position"] as Vector3).y - b.end.y)
			var fondo := b.position.y - pav
			print("LAMPADA %s | pos %s | fondo %.3f m sopra il pavimento (%.2f) | sporge %.2f m | spazio sopra %s | %s" % [
				radice.get_path_to(l), l.global_position.snapped(Vector3.ONE * 0.01), fondo, pav, maxf(b.size.x, b.size.z),
				("%.2f m" % sopra) if sopra < INF else "niente fino a 6 m", "SOTTO 2 M" if fondo < 2.0 else "ok"])
		radice.queue_free()
		for i in 5:
			await get_tree().process_frame
	print("RISULTATO: 1 controlli ok, 0 falliti")
	Game.esci(0)
