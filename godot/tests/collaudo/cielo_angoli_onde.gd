extends Node
## Collaudo di lavoro/varchi-cielo: negli scatti della lastra (Tecnici da solo) agli angoli della giunzione fra camera delle
## onde e sala pompe (x ±2,0-2,4, vicino al pavimento) si vede il cielo. Qui nel gioco vero (la sala come in
## controllo_cielo.gd, porte aperte): occhi su una griglia attorno alla giunzione (x da -1,5 a 1,5, z 24,5-26,5, a 0,3,
## 0,8 e 1,6 m) e raggi verso gli angoli (x ±2,0/2,2/2,4, quota -9,04…-8,6, z 25,3-25,7) e oltre fino a 150 m; un raggio che
## non tocca niente (collisioni e mesh visibili, CorpiMesh) è cielo. Stampa ANGOLI:.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/cielo_angoli_onde.gd

const VARCHI := preload("res://tests/controllo_varchi.gd")
const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene as Node3D
	var p := GameState.player
	var cv: Node = VARCHI.new()
	cv.call(&"_apri_tutto", level)
	for i in 120:
		await get_tree().physics_frame
	cv.free()
	p.teleport(Vector3(0.0, -9.0, 24.0))
	for i in 60:
		await get_tree().physics_frame
	print("ANGOLI: lastra %s, corpi dalle mesh %d" % [level.find_child("pavimento_giunzione_onde", true, false) != null,
			CorpiMesh.crea(level, AABB(Vector3(0, -9.05, 25.5), Vector3.ZERO).grow(40.0), p)])
	for i in 3:
		await get_tree().physics_frame
	var spazio := level.get_world_3d().direct_space_state
	var tot := 0
	var fuori_tot := 0
	var casi := {}
	for x in [-1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5]:
		for z in [24.5, 25.0, 26.0, 26.5]:
			for h in [0.3, 0.8, 1.6]:
				var occhio := Vector3(x, -9.05 + h, z)
				for tx in [-2.4, -2.2, -2.0, 2.0, 2.2, 2.4]:
					for ty in [-9.04, -8.95, -8.8, -8.6]:
						for tz in [25.3, 25.5, 25.7]:
							var d := (Vector3(tx, ty, tz) - occhio).normalized()
							var q := PhysicsRayQueryParameters3D.create(occhio, occhio + d * 150.0, 0xFFFFFFFF, [(p as CollisionObject3D).get_rid()])
							q.hit_back_faces = true
							tot += 1
							if spazio.intersect_ray(q).is_empty():
								fuori_tot += 1
								var k := "angolo x %+.1f, quota %.2f, z %.1f" % [tx, ty, tz]
								casi[k] = int(casi.get(k, 0)) + 1
								if fuori_tot <= 40:
									# dove il raggio passa il piano del muro (x ±2,3): quota e z
									var t := (signf(tx) * 2.3 - occhio.x) / d.x if absf(d.x) > 1e-4 else 0.0
									var su := occhio + d * t
									var t2 := (signf(tx) * 3.5 - occhio.x) / d.x if absf(d.x) > 1e-4 else 0.0
									print("ANGOLI: dagli occhi %s verso %s: passa x %+.1f a quota %.2f, z %.2f; a x %+.1f quota %.2f, z %.2f" % [occhio, d.snapped(Vector3.ONE * 0.001),
											signf(tx) * 2.3, su.y, su.z, signf(tx) * 3.5, (occhio + d * t2).y, (occhio + d * t2).z])
	print("ANGOLI: raggi %d, nel cielo %d" % [tot, fuori_tot])
	var ks := casi.keys()
	ks.sort_custom(func(a, b): return casi[a] > casi[b])
	for k in ks.slice(0, 15):
		print("ANGOLI:   %s: %d raggi nel cielo" % [k, casi[k]])
	print("ANGOLI: finito")
	get_tree().quit()
