extends Node
## Collaudo riga del fiume (#130): le collisioni del fiume lento prima e dopo il verso nuovo delle pareti. Raggi da:
## - la ciambella, lungo tutti i tratti ogni metro, all'altezza degli occhi (ciambella + 0,05 + 1,6) e a mezzo metro sopra
##   il pelo, in 16 direzioni x 3 inclinazioni (giù 35°, piano, su 20°);
## - la banchina: griglia di 1 m sul capannone, dove sotto c'è il pavimento a quota 0, a 1,6 e a 0,3 m, stesse direzioni.
## Scrive una riga per raggio (origine, direzione, distanza del colpo o -1, collisore) nel file dato; il confronto lo fa
## lo script python accanto. Il fiume senza la sala, senza schermo.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/fiume_raggi.gd <file>

const LUNGO := 15.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var file := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "/tmp/raggi.txt"
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	var t0 := Time.get_ticks_msec()
	while not bool(f.get(&"costruita")) and Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
	for i in 10:
		await get_tree().physics_frame
	var spazio := get_tree().root.get_world_3d().direct_space_state
	var out := FileAccess.open(file, FileAccess.WRITE)
	var dirs: Array[Vector3] = []
	for k in 16:
		for inc in [-35.0, 0.0, 20.0]:
			var d := Vector3(sin(TAU * k / 16.0), 0, cos(TAU * k / 16.0))
			d = (d * cos(deg_to_rad(inc)) + Vector3.UP * sin(deg_to_rad(inc))).normalized()
			dirs.append(d)
	var origini: Array = []
	for t: TrattoFiume in f.find_children("*", "TrattoFiume", true, false):
		var s := 0.0
		while s <= t.lunghezza():
			var p := t.punto(s)
			origini.append(["ciambella_%s_%03d_occhi" % [t.name, int(s)], p + Vector3.UP * 1.65])
			origini.append(["ciambella_%s_%03d_basso" % [t.name, int(s)], p + Vector3.UP * 0.5])
			s += 1.0
	var x := -41.0
	while x <= 28.6:
		var z := -28.6
		while z <= 28.6:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 3.0, z), Vector3(x, -3.0, z))
			var r := spazio.intersect_ray(q)
			if not r.is_empty() and absf(r.position.y) < 0.02:
				origini.append(["banchina_%.0f_%.0f_occhi" % [x, z], Vector3(x, 1.6, z)])
				origini.append(["banchina_%.0f_%.0f_basso" % [x, z], Vector3(x, 0.3, z)])
			z += 1.0
		x += 1.0
	var n := 0
	for o in origini:
		var p: Vector3 = o[1]
		for i in dirs.size():
			var q := PhysicsRayQueryParameters3D.create(p, p + dirs[i] * LUNGO)
			q.collision_mask = 0xFFFFFFFF
			var r := spazio.intersect_ray(q)
			var dist := -1.0
			var chi := "-"
			if not r.is_empty():
				dist = p.distance_to(r.position)
				var c: Object = r.collider
				chi = "%s/%s" % [(c as Node).get_parent().name if c is Node and (c as Node).get_parent() else "?", (c as Node).name if c is Node else "?"]
			out.store_line("%s %d %.3f %s %.2f %.2f %.2f" % [o[0], i, dist, chi, p.x, p.y, p.z])
			n += 1
	out.close()
	print("RAGGI: %d origini, %d raggi in %s" % [origini.size(), n, file])
	get_tree().quit()
