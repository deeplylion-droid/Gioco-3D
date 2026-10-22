extends Node
## Sonda: il portellone di scarico della piscina a onde, il suo anello di luce, la Polaroid05 e il fondo intorno.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var s := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate()
	get_tree().paused = false
	get_tree().root.add_child(s)
	printerr("SONDA caricata")
	for i in 10:
		await get_tree().process_frame
	var sp := s.get_world_3d().direct_space_state
	for n in ["Sala/Interattivi/sala_portello_scarico", "Piscina/LucePortellone", "Polaroid/Polaroid05", "Tecnici/Ambienti/CameraOnde/CAMERA_pozzo"]:
		var nodo := s.get_node_or_null(NodePath(n)) as Node3D
		if nodo == null:
			printerr("SONDA manca ", n)
			continue
		var ab := AABB()
		var primo := true
		for m in nodo.find_children("*", "MeshInstance3D", true, false) + ([nodo] if nodo is MeshInstance3D else []):
			var mi := m as MeshInstance3D
			if not mi.is_visible_in_tree() and n != "Tecnici/Ambienti/CameraOnde/CAMERA_pozzo":
				continue
			var b := mi.global_transform * mi.get_aabb()
			ab = b if primo else ab.merge(b)
			primo = false
		printerr("SONDA ", n, " ", ab, " origine ", nodo.global_position)
	# il fondo (raggi dall'alto) intorno al portellone
	for x in [-1.2, -0.9, -0.71, -0.5, 0.0, 0.5, 0.71, 0.9, 1.2]:
		var riga := ""
		for z in [1.2, 1.36, 1.6, 2.0, 2.4, 2.64, 2.7, 2.9, 3.2]:
			var r := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 1.0, z), Vector3(x, -5.0, z)))
			riga += " %.3f" % ((r["position"] as Vector3).y if not r.is_empty() else 99.0)
		printerr("SONDA fondo x %.2f:%s" % [x, riga])
	var r2 := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(1.2, 1.0, 2.9), Vector3(1.2, -5.0, 2.9)))
	printerr("SONDA sotto la Polaroid05: ", r2.get("position"), " ", r2.get("collider"))
	get_tree().quit()
