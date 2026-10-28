extends Node
## Calcola e salva le forme convesse dei modelli del tunnel sottomarino (SalaSottomarino.MODELLI): per ogni mesh la
## forma della collisione (create_convex_shape(true, true)) e l'involucro (create_convex_shape(true, false).points),
## in "<nome>_forme.res" accanto al GLB. Il gioco le carica nel thread invece di calcolarle (40-180 ms per modello).
## Da rilanciare quando cambia un GLB (se no il gioco se ne accorge e le ricalcola, lento come prima).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tools/genera_forme_tunnel.gd


func _ready() -> void:
	for nome in SalaSottomarino.MODELLI:
		var scena := load(String(SalaSottomarino.DIR_FIUME) + nome + ".glb") as PackedScene
		if scena == null:
			continue
		var n := scena.instantiate() as Node3D
		var d := {}
		for x in n.find_children("*", "MeshInstance3D", true, false):
			var mi := x as MeshInstance3D
			if mi.mesh == null:
				continue
			var involucro := mi.mesh.create_convex_shape(true, false)
			d[String(n.get_path_to(mi))] = [mi.mesh.create_convex_shape(true, true),
				involucro.points if involucro else mi.mesh.get_faces(), mi.mesh.get_aabb(), SalaSottomarino.impronta(mi.mesh)]
		var r := Resource.new()
		r.set_meta(&"forme", d)
		var f: String = SalaSottomarino.DIR_FIUME + nome + SalaSottomarino.FORME
		var e := ResourceSaver.save(r, f, ResourceSaver.FLAG_COMPRESS)
		print("%s: %d mesh -> %s (%s)" % [nome, d.size(), f, error_string(e)])
		n.free()
	get_tree().quit()
