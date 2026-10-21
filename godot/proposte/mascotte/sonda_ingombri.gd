extends Node
## Elenca le mesh della sala il cui ingombro (AABB nel mondo) tocca quello degli oggetti di Jilly e delle
## statue (MascotteSala): per trovare compenetrazioni con oggetti senza collisione (tubi, cavi, neon).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://proposte/mascotte/sonda_ingombri.gd

func _ready() -> void:
	_run.call_deferred()


func _aabb_mondo(mi: MeshInstance3D) -> AABB:
	return mi.global_transform * mi.get_aabb()


func _run() -> void:
	var level := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(level)
	for i in 10:
		await get_tree().process_frame
	var m := level.get_node("Mascotte") as Node3D
	var tutte := level.find_children("*", "MeshInstance3D", true, false)
	for ob in m.get_children():
		var box := AABB()
		var primo := true
		for mi in (ob as Node).find_children("*", "MeshInstance3D", true, false):
			var a := _aabb_mondo(mi as MeshInstance3D)
			box = a if primo else box.merge(a)
			primo = false
		print("OGGETTO ", ob.name, " ", box)
		for mi in tutte:
			if m.is_ancestor_of(mi):
				continue
			var a := _aabb_mondo(mi as MeshInstance3D)
			if a.size.length() > 30.0:
				continue
			if a.intersects(box.grow(0.02)):
				print("   tocca ", level.get_path_to(mi), " ", a)
	get_tree().quit()
