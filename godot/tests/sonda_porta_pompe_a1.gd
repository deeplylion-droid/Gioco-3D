extends Node
## Sonda: la faccia vera (mesh) della porta della sala pompe aperta, verso il muro (z 40,9) e il telaio (40,86).
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 600:
		await get_tree().process_frame
		if get_tree().current_scene and get_tree().current_scene.find_child("PortaSalaPompeInterni", true, false):
			break
	for i in 10:
		await get_tree().physics_frame
	var lv := get_tree().current_scene
	var porta := lv.find_child("PortaSalaPompeInterni", true, false)
	porta.call(&"load_state", {"aperta": true, "bloccata": false})
	for i in 5:
		await get_tree().physics_frame
	var mi := lv.get_node("Interni/Ambienti/Corridoio/porta_sala_pompe") as Node3D
	var tri := PackedVector3Array()
	var mis: Array = [mi]
	mis.append_array(mi.find_children("*", "MeshInstance3D", true, false))
	for m in mis:
		if not m is MeshInstance3D:
			continue
		var f := (m as MeshInstance3D).mesh.get_faces()
		var g := (m as MeshInstance3D).global_transform
		for v in f:
			tri.append(g * v)
	print("triangoli ", tri.size() / 3)
	var cardine := lv.find_child("CardinePortaSalaPompe", true, false) as Node3D
	print("cardine ", cardine.global_position)
	var tutto := -9.0
	var telaio := -9.0
	var basso := -9.0
	var punti := []
	var x := 8.29
	while x < 9.26:
		var y := 0.02
		while y < 2.05:
			var z := _faccia(tri, x, y)
			if z > -8.0:
				tutto = maxf(tutto, z)
				if x < 8.40:
					telaio = maxf(telaio, z)
				if y < 0.13:
					basso = maxf(basso, z)
			y += 0.1 if y > 0.2 else 0.04
		x += 0.04
	print("faccia verso il muro: max %.4f, sul telaio (x<8,40) %.4f, sul battiscopa (y<0,13) %.4f" % [tutto, telaio, basso])
	for p in [Vector2(9.0, 0.2), Vector2(9.1, 0.2), Vector2(9.1, 0.25), Vector2(9.15, 0.2), Vector2(8.8, 1.0), Vector2(9.1, 1.0)]:
		print("faccia a x %.2f y %.2f: z %.4f" % [p.x, p.y, _faccia(tri, p.x, p.y)])
	print("RISULTATO: sonda finita")
	get_tree().quit(0)
func _faccia(tri: PackedVector3Array, x: float, y: float) -> float:
	var o := Vector3(x, y, 41.2)
	var best := -9.0
	for k in range(0, tri.size(), 3):
		var h: Variant = Geometry3D.ray_intersects_triangle(o, Vector3(0, 0, -1), tri[k], tri[k + 1], tri[k + 2])
		if h != null:
			best = maxf(best, (h as Vector3).z) if (h as Vector3).z < 40.95 else best
	return best
