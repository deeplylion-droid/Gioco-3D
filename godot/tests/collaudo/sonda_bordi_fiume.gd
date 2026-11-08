extends Node
## Sonda (#130): i bordi dell'acqua in un rettangolo del fiume: i lati in cima alle pareti del canale (quota 0) e i lati
## del pavimento, per trovare dove manca una parete. Rettangolo da env RETT="x0,x1,z0,z1".
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_bordi_fiume.gd

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var r := OS.get_environment("RETT").split_floats(",")
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	while not bool(f.get(&"costruita")):
		await get_tree().process_frame
	var dentro := func(p: Vector3) -> bool: return p.x >= r[0] and p.x <= r[1] and p.z >= r[2] and p.z <= r[3]
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", false, false):
		if mi.mesh == null or mi.mesh.get_surface_count() != 1:
			continue
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			continue
		var tipo := ""
		if mi.material_override == f.get(&"mat_vasca"):
			tipo = "VASCA"
		elif mi.material_override == f.get(&"mat_banca"):
			tipo = "BANCA"
		else:
			continue
		for k in range(0, idx.size(), 3):
			var t := [mi.global_transform * v[idx[k]], mi.global_transform * v[idx[k + 1]], mi.global_transform * v[idx[k + 2]]]
			if t.any(dentro):
				print("TRI %s %s %s %s" % [tipo, t[0].snappedf(0.001), t[1].snappedf(0.001), t[2].snappedf(0.001)])
	print("FINE")
	get_tree().quit()
