extends Node
## Sonda: da fermo, quanto stanno sopra il pavimento le ossa delle punte e il vertice più basso della mesh (posa
## "fermo" dopo un secondo), per il bambino col cubo e l'agnellino.

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var p := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector3(0, 0, -40)
	GameState.player = p
	for scena in ["res://scenes/creature/bambino_cubo.tscn", "res://scenes/creature/bambino_agnello.tscn"]:
		var b := (load(scena) as PackedScene).instantiate() as Bambino
		b.modalita = Bambino.Modalita.OSSERVA
		add_child(b)
		b.global_position = Vector3.ZERO
		for i in 60:
			await get_tree().process_frame
		var m := b.get_node("Calmo") as Node3D
		var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var ossa := ""
		for n in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
			var o := sk.find_bone(n)
			ossa += "%s %.4f  " % [n, (sk.global_transform * sk.get_bone_global_pose(o).origin).y]
		var minimo := INF
		for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			if mi.skin == null or not mi.visible:
				continue
			# vertici con la pelle, calcolati a mano: somma pesata di posa dell'osso per bind pose
			var msk := mi.get_node(mi.skeleton) as Skeleton3D
			var skin := mi.skin
			var mats: Array[Transform3D] = []
			for i in skin.get_bind_count():
				var o := skin.get_bind_bone(i)
				if o < 0:
					o = msk.find_bone(skin.get_bind_name(i))
				mats.append(msk.global_transform * msk.get_bone_global_pose(o) * skin.get_bind_pose(i))
			for s in mi.mesh.get_surface_count():
				var a: Array = mi.mesh.surface_get_arrays(s)
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var bo = a[Mesh.ARRAY_BONES]
				var w = a[Mesh.ARRAY_WEIGHTS]
				var k := int(bo.size() / v.size())
				for j in v.size():
					var pos := Vector3.ZERO
					for h in k:
						var ww: float = w[j * k + h]
						if ww > 0.0:
							pos += (mats[int(bo[j * k + h])] * v[j]) * ww
					minimo = minf(minimo, pos.y)
		print(scena.get_file(), ": ", ossa, " mesh più bassa %.4f  modello y %.4f" % [minimo, m.position.y])
		b.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)
