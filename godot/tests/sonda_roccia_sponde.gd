extends Node
## Sonda delle interruzioni della roccia lungo il fiume (riscontro dell'utente sulla v0.3.14: "due punti dove si
## interrompe la roccia"). Lungo ogni tratto, dal punto della ciambella, ogni 0,5 m un raggio a sinistra e uno a
## destra a tre altezze, contro le facce che si vedono (non le collisioni: i pannelli hanno bordi irregolari).
## Scrive per ogni raggio cosa vede per primo; stampa i tratti dove si vede il muro (o niente) invece della roccia.
## Uso (sotto il render.lock):
##   godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_roccia_sponde.gd [file.json]

const LIVELLO := 1 << 19
const ALTEZZE := [0.9, 1.7, 2.6]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var uscita := a[1] if a.size() > 1 else "user://sonda_roccia_sponde.json"
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	for i in 3000:
		await get_tree().process_frame
		if f.get(&"costruita"):
			break
	# le facce che si vedono, in un corpo solo per mesh, su un livello tutto loro
	var nomi := {}
	for mi in f.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var facce := m.mesh.get_faces()
		if facce.is_empty():
			continue
		var xf := m.global_transform
		for i in facce.size():
			facce[i] = xf * facce[i]
		var mat := m.material_override if m.material_override != null else m.get_active_material(0)
		var etichetta := str(f.get_path_to(m))
		if etichetta.contains("@") and mat != null:
			etichetta += " [%s %s %s]" % [mat.resource_name, mat.resource_path.get_file(), m.mesh.get_class()]
		_corpo(facce, etichetta, nomi)
	for mm in f.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := mm as MultiMeshInstance3D
		if not mmi.is_visible_in_tree() or mmi.multimesh == null or mmi.multimesh.mesh == null:
			continue
		var base := mmi.multimesh.mesh.get_faces()
		var tutte := PackedVector3Array()
		for k in mmi.multimesh.instance_count:
			var xf := mmi.global_transform * mmi.multimesh.get_instance_transform(k)
			for v in base:
				tutte.append(xf * v)
		_corpo(tutte, str(f.get_path_to(mmi)), nomi)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := f.get_world_3d().direct_space_state
	var out := []
	for t in f.find_children("*", "TrattoFiume", true, false):
		var tr := t as TrattoFiume
		var L: float = tr.lunghezza()
		var s := 0.0
		while s <= L:
			var p: Vector3 = tr.punto(s)
			var dir: Vector3 = tr.direzione(s)
			dir.y = 0
			dir = dir.normalized()
			var sx := Vector3.UP.cross(dir)
			for lato: float in [1.0, -1.0]:
				var viste := []
				for h: float in ALTEZZE:
					var da := Vector3(p.x, f.global_position.y + h, p.z)
					var q := PhysicsRayQueryParameters3D.create(da, da + sx * lato * 25.0, LIVELLO)
					var hit := space.intersect_ray(q)
					if hit.is_empty():
						viste.append(["-", -1.0])
					else:
						var hp := f.to_local(hit.position)
						viste.append([nomi.get((hit.collider as Node).get_instance_id(), "?"), snappedf(da.distance_to(hit.position), 0.01),
								snappedf(hp.x, 0.01), snappedf(hp.z, 0.01)])
				var lp := f.to_local(p)
				out.append({"tratto": String(tr.name), "s": snappedf(s, 0.1), "lato": "S" if lato > 0 else "D",
						"x": snappedf(lp.x, 0.01), "z": snappedf(lp.z, 0.01), "viste": viste})
			s += 0.5
	var fa := FileAccess.open(uscita, FileAccess.WRITE)
	fa.store_string(JSON.stringify(out, "\t"))
	fa.close()
	# i raggi che non vedono roccia
	var buchi := 0
	for r in out:
		var nr := []
		for v in r["viste"]:
			if not String(v[0]).contains("roccia"):
				nr.append(v)
		if not nr.is_empty():
			buchi += 1
			print("NON ROCCIA %s s %.1f %s (%.2f, %.2f): %s" % [r["tratto"], r["s"], r["lato"], r["x"], r["z"], nr])
	print("SONDA raggi %d, senza roccia %d -> %s" % [out.size(), buchi, uscita])
	get_tree().quit()


func _corpo(facce: PackedVector3Array, nome: String, nomi: Dictionary) -> void:
	var c := StaticBody3D.new()
	c.collision_layer = LIVELLO
	c.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.backface_collision = true
	sh.set_faces(facce)
	cs.shape = sh
	c.add_child(cs)
	add_child(c)
	nomi[c.get_instance_id()] = nome
