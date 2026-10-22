extends Node
## Strumento (non è un test della CI): come sonda_acquari.gd, ma per una zona costruita da sola (il fiume,
## l'infermeria), in uno stato a scelta. Per ogni mesh visibile prende i vertici nel mondo e conta:
## - quanti finiscono dentro le collisioni di un altro oggetto (l'oggetto è il figlio diretto della zona
##   che contiene la mesh: le collisioni del suo stesso oggetto non contano);
## - quanti stanno sotto il pavimento della zona (y < quota - 1 cm);
## e per ogni mesh senza niente sotto (raggio verso il basso dal suo punto più basso) lo segnala, con la
## misura della mesh (le mesh grandi di solito sono attaccate di lato e sono falsi allarmi).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_scena.gd <scena> [stato] [quota]
## Stati: "risolta" (infermeria: pulsante colpito, cassetto aperto, radiografia sul negatoscopio,
## cassaforte aperta), "girate" (fiume: tutte le paratie girate una volta).


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var scena := a[1]
	var stato := a[2] if a.size() > 2 else ""
	var quota := float(a[3]) if a.size() > 3 else 0.0
	var zona: Node3D = (load(scena) as PackedScene).instantiate()
	get_tree().root.add_child(zona)
	for i in 10:
		await get_tree().physics_frame
	match stato:
		"risolta":
			(zona.get_node("Interruttore") as WaterButton).powered = true
			var cas := zona.get_node("Cassetto14") as CassettoSchedario
			cas.aperto = true
			cas.call(&"_metti")
			(zona.get_node("Negatoscopio") as Negatoscopio).con_radiografia = true
			(zona.get_node("Cassaforte") as CassaforteRotelle).load_state({"cifre": [4, 1, 7], "aperta": true})
		"girate":
			for p in zona.find_children("*", "ParatiaFiume", true, false):
				(p as ParatiaFiume).gira()
	for i in 240:
		await get_tree().physics_frame
	var space := zona.get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.collide_with_areas = false
	var problemi := 0
	for mi in zona.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var facce := m.mesh.get_faces()
		if facce.is_empty():
			continue
		var xf := m.global_transform
		var gruppo: Node = m
		while gruppo.get_parent() != zona:
			gruppo = gruppo.get_parent()
		var dentro := {}
		var sotto := 0
		var passo := maxi(1, facce.size() / 600)
		var n := 0
		var basso := Vector3(0, INF, 0)
		var box := AABB(xf * facce[0], Vector3.ZERO)
		for i in range(0, facce.size(), passo):
			var v := xf * facce[i]
			n += 1
			box = box.expand(v)
			if v.y < basso.y:
				basso = v
			if v.y < quota - 0.01:
				sotto += 1
			q.position = v
			for r in space.intersect_point(q, 8):
				var c := r.get("collider") as Node
				if c == null or gruppo.is_ancestor_of(c) or c == gruppo:
					continue
				var nome := String(zona.get_path_to(c))
				dentro[nome] = int(dentro.get(nome, 0)) + 1
		var nome_m := String(zona.get_path_to(m))
		var misura := "%.2fx%.2fx%.2f" % [box.size.x, box.size.y, box.size.z]
		for k in dentro:
			if dentro[k] * 100 / n >= 2:
				print("COMPENETRA %s (%s) dentro %s: %d%% dei vertici" % [nome_m, misura, k, dentro[k] * 100 / n])
				problemi += 1
		if sotto * 100 / n >= 2:
			print("SOTTO IL PAVIMENTO %s (%s): %d%% dei vertici (fino a %.2f)" % [nome_m, misura, sotto * 100 / n, basso.y])
			problemi += 1
		var rq := PhysicsRayQueryParameters3D.create(basso + Vector3(0, 0.02, 0), basso - Vector3(0, 0.05, 0))
		if basso.y > quota + 0.03 and space.intersect_ray(rq).is_empty():
			print("SOSPESO? %s (%s): punto più basso %s, niente sotto entro 5 cm" % [nome_m, misura, basso.snapped(Vector3(0.01, 0.01, 0.01))])
			problemi += 1
	print("RISULTATO SONDA: %d problemi" % problemi)
	get_tree().quit(0)
