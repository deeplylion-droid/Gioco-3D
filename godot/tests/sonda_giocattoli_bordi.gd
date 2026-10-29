extends Node
## Sonda per l'enigma dei giocattoli: dove sono i muri della parte profonda, le scalette e i gonfiabili sul fondo (con la
## loro forma vera, non solo il riquadro), per i posti dove un giocattolo si incastrava (collaudo di ambienti-2, 29 ottobre).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/sonda_giocattoli_bordi.gd

const SCENA := "res://scenes/sala_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(SCENA)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	for i in 60:
		await get_tree().physics_frame
	var level := get_tree().current_scene
	var enigma := level.get_node(^"Piscina/EnigmaGiocattoli") as EnigmaGiocattoli
	var spazio := (level as Node3D).get_world_3d().direct_space_state
	print("enigma in ", enigma.global_position, " base ", enigma.global_basis)
	# i muri: raggi orizzontali dal centro della parte profonda, a 30 cm dal fondo
	for z in [-3.6, -3.0, -2.0, -1.0, 0.0, 1.3, 2.2, 3.2, 4.0, 4.5]:
		for verso in [-1.0, 1.0]:
			var da := enigma.to_global(Vector3(0, 0, z)) + Vector3(0, 0.3, 0)
			da.y = _fondo(spazio, da) + 0.3
			var q := PhysicsRayQueryParameters3D.create(da, da + Vector3(verso * 9.0, 0, 0), Layers.WORLD)
			var h := spazio.intersect_ray(q)
			print("muro x%s a z %.1f: %s (fondo %.2f)" % ["+" if verso > 0 else "-", z, enigma.to_local(h.position) if h else "niente", da.y - 0.3])
	for x in [-6.6, -6.0, -3.9, 0.0, 3.9, 6.0, 6.6]:
		for verso in [-1.0, 1.0]:
			var da := enigma.to_global(Vector3(x, 0, 1.0))
			da.y = _fondo(spazio, da) + 0.3
			var q := PhysicsRayQueryParameters3D.create(da, da + Vector3(0, 0, verso * 9.0), Layers.WORLD)
			var h := spazio.intersect_ray(q)
			print("muro z%s a x %.1f: %s" % ["+" if verso > 0 else "-", x, enigma.to_local(h.position) if h else "niente"])
	# il fondo lungo z (la pendenza verso la spiaggia)
	for z in [-3.6, -3.0, -2.5, -2.0, -1.5, -1.0, 0.0, 4.5]:
		var p := enigma.to_global(Vector3(0, 0, z))
		print("fondo a z %.1f: %.2f" % [z, _fondo(spazio, p)])
	# i gonfiabili e le scalette
	for n in level.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var bb := mi.global_transform * mi.get_aabb()
		var c := enigma.to_local(bb.get_center())
		if bb.position.y > -0.5 or c.x < -8 or c.x > 8 or c.z < -5 or c.z > 6:
			continue
		if not (String(mi.name).begins_with("ogg_") or String(mi.name).to_lower().contains("scal")):
			continue
		var la := mi.get_aabb()
		var bx := mi.global_basis
		print("%s: centro %s, riquadro %s, locale %s, asse x %s, asse z %s" % [mi.name, c, bb.size, la.size,
			Vector3(bx.x.x, 0, bx.x.z).snapped(Vector3.ONE * 0.01), Vector3(bx.z.x, 0, bx.z.z).snapped(Vector3.ONE * 0.01)])
	print("ostacoli calcolati: ", enigma.get(&"_ostacoli"))
	# le collisioni degli oggetti del fondo e la quota che vede un raggio attorno al gonfiabile del collaudo
	for n in level.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		var c := enigma.to_local(cs.global_position)
		if cs.global_position.y > -1.0 or c.x < -7.5 or c.x > 7.5 or c.z < -4 or c.z > 5.5 or cs.shape == null:
			continue
		var corpo := cs.get_parent()
		print("collisione %s/%s: %s in %s, strato %d, aabb %s" % [corpo.get_parent().name if corpo.get_parent() else "", corpo.name,
			cs.shape.get_class(), c, (corpo as CollisionObject3D).collision_layer if corpo is CollisionObject3D else -1,
			cs.shape.get_debug_mesh().get_aabb().size if cs.shape.get_debug_mesh() else Vector3.ZERO])
	var righe := []
	for zz in range(-2, 9):
		var riga := ""
		for xx in range(-14, 2):
			var p := enigma.to_global(Vector3(xx * 0.2, 0, zz * 0.2))
			var y := _fondo(spazio, p)
			riga += "%6.2f" % y
		righe.append("z %.1f: %s" % [zz * 0.2, riga])
	print("quote da x -2,8 a 0,2 (passo 0,2):")
	for r in righe:
		print(r)
	print("liberi: ", enigma.liberi, " area ", enigma.area)
	print("FINE")
	get_tree().quit()


func _fondo(spazio: PhysicsDirectSpaceState3D, p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 0.5, p.z), Vector3(p.x, -4.0, p.z), Layers.WORLD)
	var h := spazio.intersect_ray(q)
	return (h.position as Vector3).y if h else -9.0
