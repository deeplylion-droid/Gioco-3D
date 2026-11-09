extends Node
## Collaudo #147 (ambienti-1): cosa c'è sotto e davanti alla lampada d'emergenza 5 (muro est, y -16,0): raggi di fisica
## e di mesh verso il basso a 0,1-3 m dal muro, e se lì si cammina (superficie quasi orizzontale) quanto spazio resta
## fino al fondo della scatola. La torre da sola, costruita a pezzi.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_sotto_lampada5.gd

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var torre: Node3D = (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate()
	torre.set(&"costruzione_a_pezzi", true)
	add_child(torre)
	await torre.call(&"costruisci_a_pezzi", 50.0)
	for i in 10:
		await get_tree().physics_frame
	var lampada: MeshInstance3D = null
	for c in torre.get_node(^"Luci").get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh and (c as Node3D).global_position.x > 39.0 \
				and (c as Node3D).global_position.y < -10.0:
			lampada = c
	var p := lampada.global_position
	print("SOTTO5: lampada a %s, fondo a y %.3f" % [p, p.y - 0.15])
	var st: PhysicsDirectSpaceState3D = (torre as Node3D).get_world_3d().direct_space_state
	for dz in [-0.6, 0.0, 0.6]:
		for d in [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.8, 1.0, 1.5, 2.0, 3.0]:
			var q := Vector3(39.92 - 0.08 - d, p.y + 0.5, p.z + dz)
			var h := st.intersect_ray(PhysicsRayQueryParameters3D.create(q, q + Vector3.DOWN * 30.0))
			var m := Posa._raggio(lampada, q, q + Vector3.DOWN * 30.0, [])
			var testo := "SOTTO5: a %.1f m dal muro, z %+.1f:" % [d, dz]
			if not h.is_empty():
				testo += " fisica y %.3f (%s, normale %s)" % [(h.position as Vector3).y, torre.get_path_to(h.collider) if torre.is_ancestor_of(h.collider) else h.collider, (h.normal as Vector3).snappedf(0.01)]
			if not m.is_empty():
				var col: Object = m.get("collider")
				testo += " | mesh y %.3f (%s)" % [(m.position as Vector3).y, torre.get_path_to(col) if col is Node and torre.is_ancestor_of(col) else col]
			print(testo)
	get_tree().quit()
