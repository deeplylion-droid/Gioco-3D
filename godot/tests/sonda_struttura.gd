extends Node
## Sonda: mappa delle superfici calpestabili della struttura di gioco dell'area bimbi (fisica), per fasce
## d'altezza, con lo spazio libero sopra. '#' = ci si sta in piedi (1,8 m liberi), 'c' = solo accovacciati
## (1,1 m), '.' = niente in quella fascia.
const LEVEL := "res://scenes/sala_principale.tscn"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 5:
		await get_tree().physics_frame
	var space := (GameState.player as Node3D).get_world_3d().direct_space_state
	var fasce := [[0.9, 1.5], [1.5, 2.2], [2.2, 3.4], [3.4, 5.0], [5.0, 9.0]]
	var x0 := -19.0; var x1 := -9.0; var z0 := -21.5; var z1 := -13.5
	var mappe := []
	for f in fasce:
		mappe.append([])
	var passo := 0.2
	var nz := int((z1 - z0) / passo)
	var nx := int((x1 - x0) / passo)
	for j in nz:
		var righe := []
		for f in fasce:
			righe.append("")
		for i in nx:
			var x := x0 + i * passo
			var z := z0 + j * passo
			var superfici := []
			var da := Vector3(x, 12.0, z)
			var esclusi: Array[RID] = [(GameState.player as CollisionObject3D).get_rid()]
			for k in 12:
				var q := PhysicsRayQueryParameters3D.create(da, Vector3(x, -0.5, z), Layers.WORLD)
				q.exclude = esclusi
				var h := space.intersect_ray(q)
				if h.is_empty():
					break
				superfici.append([h.position.y, h.normal.y])
				da = h.position + Vector3(0, -0.02, 0)
			for b in fasce.size():
				var c := "."
				for s in superfici.size():
					var y: float = superfici[s][0]
					if y < fasce[b][0] or y >= fasce[b][1] or superfici[s][1] < 0.7:
						continue
					var sopra := 99.0
					for t in superfici.size():
						if superfici[t][0] > y + 0.05:
							sopra = minf(sopra, superfici[t][0] - y)
					c = "#" if sopra > 1.8 else ("c" if sopra > 1.1 else c)
				righe[b] += c
		for b in fasce.size():
			mappe[b].append(righe[b])
	for b in fasce.size():
		print("FASCIA %.1f-%.1f m (x da %.1f a %.1f, z da %.1f in giù a righe)" % [fasce[b][0], fasce[b][1], x0, x1, z0])
		for r in mappe[b]:
			print("M ", r)
	get_tree().quit()
