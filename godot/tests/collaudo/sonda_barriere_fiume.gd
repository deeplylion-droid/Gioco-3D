extends Node
## Collaudo riga del fiume (#130, seconda correzione): le barriere nuove lungo i lati delle conche non devono chiudere
## passaggi della strada. Griglia di 0,5 m sul capannone: per ogni punto, se è pavimento (sotto c'è il pavimento a quota
## 0 e non è acqua); per ogni coppia di punti vicini (a destra e in giù) tutti e due di pavimento, un raggio a 1 m
## d'altezza fra i due, solo sullo strato delle barriere e poi su tutte le collisioni: se è bloccato. Scrive una riga per
## coppia nel file; il confronto prima/dopo lo fa python. In più, per ogni triangolo delle barriere, guarda i due lati a
## 5 cm: uno deve essere acqua (BARR:).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_barriere_fiume.gd <file>

const PASSO := 0.5


func _ready() -> void:
	_run.call_deferred()


func _in_acqua(polys: Array, p: Vector2) -> bool:
	for w in polys:
		if Geometry2D.is_point_in_polygon(p, w):
			return true
	return false


func _run() -> void:
	var file := OS.get_cmdline_user_args()[1]
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	while not bool(f.get(&"costruita")):
		await get_tree().process_frame
	for i in 5:
		await get_tree().physics_frame
	var polys: Array = f.get(&"_poligoni_acqua_cache")
	var sp := get_tree().root.get_world_3d().direct_space_state
	var pav := {}
	var x := -41.0
	while x <= 28.6:
		var z := -28.6
		while z <= 28.6:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 3.0, z), Vector3(x, -3.0, z))
			q.collision_mask = 1
			var r := sp.intersect_ray(q)
			if not r.is_empty() and absf(r.position.y) < 0.02 and not _in_acqua(polys, Vector2(x, z)):
				pav[Vector2(x, z)] = true
			z += PASSO
		x += PASSO
	var out := FileAccess.open(file, FileAccess.WRITE)
	var coppie := 0
	for p: Vector2 in pav:
		for d in [Vector2(PASSO, 0), Vector2(0, PASSO)]:
			var p2: Vector2 = p + d
			if not pav.has(p2):
				continue
			var a := Vector3(p.x, 1.0, p.y)
			var b := Vector3(p2.x, 1.0, p2.y)
			var q1 := PhysicsRayQueryParameters3D.create(a, b)
			q1.collision_mask = Layers.BARRIERS
			q1.hit_back_faces = true
			var b1 := not sp.intersect_ray(q1).is_empty()
			var q2 := PhysicsRayQueryParameters3D.create(a, b)
			q2.hit_back_faces = true
			var b2 := not sp.intersect_ray(q2).is_empty()
			out.store_line("%.1f %.1f %.1f %.1f %d %d" % [p.x, p.y, p2.x, p2.y, int(b1), int(b2)])
			coppie += 1
	out.close()
	# i triangoli delle barriere: un lato deve essere acqua
	var storte := 0
	var tot := 0
	for cs in f.find_children("*", "CollisionShape3D", true, false):
		if not (cs.get_parent() is StaticBody3D and (cs.get_parent() as StaticBody3D).collision_layer == Layers.BARRIERS):
			continue
		if not (cs.shape is ConcavePolygonShape3D):
			continue
		var fc: PackedVector3Array = (cs.shape as ConcavePolygonShape3D).get_faces()
		for k in range(0, fc.size(), 3):
			var m := (fc[k] + fc[k + 1] + fc[k + 2]) / 3.0
			var g := (fc[k + 1] - fc[k]).cross(fc[k + 2] - fc[k])
			if g.length() < 1e-6:
				continue
			var n := Vector2(g.x, g.z).normalized()
			tot += 1
			var a1 := _in_acqua(polys, Vector2(m.x, m.z) + n * 0.05)
			var a2 := _in_acqua(polys, Vector2(m.x, m.z) - n * 0.05)
			if a1 == a2:
				storte += 1
				if storte <= 30:
					print("BARR: barriera con %s dai due lati a %s" % ["acqua" if a1 else "pavimento", m.snappedf(0.01)])
	print("BARR: %d punti di pavimento, %d coppie; %d triangoli di barriera, %d senza acqua da un lato solo" % [pav.size(), coppie, tot, storte])
	get_tree().quit()
