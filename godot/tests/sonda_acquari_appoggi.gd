extends Node
## Strumento (non è un test della CI): controlla la geometria degli acquari davanti al portone (pezzo per
## pezzo) con gli acquari comparsi e pieni. Per ogni mesh dell'enigma prende i vertici nel mondo e conta:
## - quanti finiscono dentro le collisioni di altro (muri, pavimento, portone, gli altri pezzi
##   dell'enigma: acquari, pedana, valvola);
## - quanti stanno sotto il pavimento (y < -1 cm);
## e per ogni mesh senza niente sotto (raggio verso il basso dal suo punto più basso) lo segnala.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_acquari_appoggi.gd

const LEVEL := "res://scenes/sala_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	var level := get_tree().current_scene
	var enigma := level.get_node(^"Gioco/EnigmaAcquari")
	enigma.call(&"_mostra", true)
	for i in 20:
		await get_tree().physics_frame
	var space := (enigma as Node).get_viewport().world_3d.direct_space_state
	var corpi_enigma := {}
	for b in enigma.find_children("*", "CollisionObject3D", true, false):
		corpi_enigma[(b as CollisionObject3D).get_rid()] = b
	var q := PhysicsPointQueryParameters3D.new()
	q.collide_with_areas = false
	q.exclude = [GameState.player.get_rid()]
	var problemi := 0
	for mi in enigma.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var facce := m.mesh.get_faces()
		if facce.is_empty():
			continue
		var xf := m.global_transform
		# il gruppo del pezzo: l'acquario, la pedana, la valvola... (il figlio diretto dell'enigma)
		var gruppo: Node = m
		while gruppo.get_parent() != enigma:
			gruppo = gruppo.get_parent()
		var dentro := {}
		var sotto := 0
		var passo := maxi(1, facce.size() / 600)
		var n := 0
		var basso := Vector3(0, INF, 0)
		for i in range(0, facce.size(), passo):
			var v := xf * facce[i]
			n += 1
			if v.y < basso.y:
				basso = v
			if v.y < -0.01:
				sotto += 1
			q.position = v
			for r in space.intersect_point(q, 8):
				var c := r.get("collider") as Node
				if c == null:
					continue
				if gruppo.is_ancestor_of(c) or c == gruppo:
					continue   # le collisioni del suo stesso pezzo
				var nome := String(level.get_path_to(c))
				dentro[nome] = int(dentro.get(nome, 0)) + 1
		var nome_m := String(enigma.get_path_to(m))
		for k in dentro:
			if dentro[k] * 100 / n >= 2:
				print("COMPENETRA %s dentro %s: %d%% dei vertici" % [nome_m, k, dentro[k] * 100 / n])
				problemi += 1
		if sotto * 100 / n >= 2:
			print("SOTTO IL PAVIMENTO %s: %d%% dei vertici (fino a %.2f)" % [nome_m, sotto * 100 / n, basso.y])
			problemi += 1
		# appoggio: dal punto più basso un raggio di 5 cm in giù (o qualcosa a 2 cm di lato)
		var rq := PhysicsRayQueryParameters3D.create(basso + Vector3(0, 0.02, 0), basso - Vector3(0, 0.05, 0))
		rq.exclude = [GameState.player.get_rid()]
		if basso.y > 0.03 and space.intersect_ray(rq).is_empty():
			print("SOSPESO? %s: punto più basso %s, niente sotto entro 5 cm" % [nome_m, basso.snapped(Vector3(0.01, 0.01, 0.01))])
			problemi += 1
	print("RISULTATO SONDA: %d problemi" % problemi)
	get_tree().quit(0)
