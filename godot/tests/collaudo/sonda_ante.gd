extends Node
## Collaudo: per le ante degli armadietti, superfici, materiali (cull, trasparenza, alpha) e area delle facce dritte o
## rovesciate rispetto alle normali dei vertici.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var sc := (load("res://scenes/interni/interni.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(sc)
	for i in 10:
		await get_tree().process_frame
	for n in sc.find_children("*_anta", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var m := mi.mesh
		print("ANTA ", n.name, " superfici ", m.get_surface_count(), " scala ", mi.global_transform.basis.get_scale(), " det ", snappedf(mi.global_transform.basis.determinant(), 0.001))
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx = arr[Mesh.ARRAY_INDEX]
			var ii: PackedInt32Array = idx if idx != null else PackedInt32Array(range(v.size()))
			var dritta := 0.0
			var storta := 0.0
			for k in range(0, ii.size(), 3):
				var a := v[ii[k]]
				var g := (v[ii[k + 1]] - a).cross(v[ii[k + 2]] - a)
				var med := nn[ii[k]] + nn[ii[k + 1]] + nn[ii[k + 2]]
				if g.dot(med) < 0.0:
					dritta += g.length() * 0.5
				else:
					storta += g.length() * 0.5
			var mat := mi.get_active_material(s)
			var info := ""
			if mat is BaseMaterial3D:
				var b := mat as BaseMaterial3D
				info = "cull %d trasp %d alpha %.2f tex %s" % [b.cull_mode, b.transparency, b.albedo_color.a, b.albedo_texture.resource_path.get_file() if b.albedo_texture else "-"]
			else:
				info = str(mat)
			var box := AABB()
			for k in range(ii.size()):
				box = AABB(v[ii[k]], Vector3.ZERO) if k == 0 else box.expand(v[ii[k]])
			print("   superficie %d tri %d area dritta %.3f rovesciata %.3f box %s %s" % [s, ii.size() / 3, dritta, storta, box.size.snapped(Vector3.ONE * 0.001), info])
		if n.name == "armadietti_ovest_02_anta":
			pass
	get_tree().quit()
