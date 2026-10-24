extends Node
## Sonda: le lampade d'emergenza rosse della torre (scatole 16x30x30 cm) e quanto distano dal muro o dal tubo dietro
## (raggi dai 9 punti del retro: la distanza minima deve essere 0, a pochi mm).

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	var s := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(s)
	for i in 30:
		await get_tree().physics_frame
	for mi in s.find_children("*", "MeshInstance3D", true, false):
		var b := (mi as MeshInstance3D).mesh as BoxMesh
		if b == null or not (b.size.is_equal_approx(Vector3(0.16, 0.3, 0.3)) or b.size.is_equal_approx(Vector3(0.3, 0.3, 0.16))):
			continue
		var p: Vector3 = (mi as Node3D).global_position
		var v := Vector3(signf(p.x - 31.0), 0, 0) if b.size.x < 0.2 else Vector3(0, 0, signf(p.z - 0.0))
		# il retro guarda il muro: verso la stanza è -v rispetto al muro più vicino; prova i due versi
		var minimo := INF
		for verso in [v, -v]:
			var a1 := (verso as Vector3).cross(Vector3.UP).normalized()
			var d := INF
			for i in [-1, 0, 1]:
				for j in [-1, 0, 1]:
					var o: Vector3 = a1 * (i * 0.14) + Vector3.UP * (j * 0.14)
					var da: Vector3 = p + o - (verso as Vector3) * 0.079
					var h := Posa._raggio(mi, da, da - (verso as Vector3) * 0.5, [])
					if not h.is_empty():
						d = minf(d, da.distance_to(h.position))
			minimo = minf(minimo, d)
		printerr("SONDA lampada %s distanza dal retro %.1f mm" % [p.snappedf(0.01), minimo * 1000.0])
	get_tree().quit()
