extends Node
## Collaudo di ambienti-1: l'impronta di quello che si vede nel tunnel (i vertici e le normali di ogni mesh visibile della
## SalaSottomarino, per materiale) e della collisione, per confrontare due versioni (il gradino che si vede non deve
## cambiare). Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/impronta_tunnel_a1.gd
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var sala := SalaSottomarino.new()
	get_tree().root.add_child(sala)
	sala.costruisci()
	for i in 5: await get_tree().process_frame
	var vis := {}
	for mi in sala.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null or not (mi as MeshInstance3D).is_visible_in_tree():
			continue
		for sidx in m.get_surface_count():
			var arr := m.surface_get_arrays(sidx)
			var mat := m.surface_get_material(sidx)
			var nome: String = mat.resource_name if mat and mat.resource_name != "" else (str(mat.resource_path.get_file()) if mat else "-")
			var chiave := "%s/%s" % [sala.get_path_to(mi), nome]
			var h := hash([arr[Mesh.ARRAY_VERTEX], arr[Mesh.ARRAY_NORMAL], arr[Mesh.ARRAY_INDEX]])
			vis[chiave] = h
	var col := []
	for cs in sala.find_children("*", "CollisionShape3D", true, false):
		var s = (cs as CollisionShape3D).shape
		if s is ConcavePolygonShape3D:
			col.append((s as ConcavePolygonShape3D).get_faces().size())
	var tutto := 0
	var nomi := vis.keys()
	nomi.sort()
	for k in nomi:
		print("VIS ", k, " ", vis[k])
	print("COLLISIONE facce: ", col)
	get_tree().quit()
