extends Node
## Collaudo: da dove si prende la Polaroid 2 (raggio dell'Interactor, 2,3 m, maschera 29): dagli occhi a 1,6 m davanti
## agli armadietti, a varie distanze, guardando il centro della foto.

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var liv := (load("res://scenes/interni/interni.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(liv)
	for i in 120:
		await get_tree().physics_frame
	var p := liv.get_node(^"Polaroid/Polaroid02") as Node3D
	var c := p.global_position
	for cs in p.find_children("*", "CollisionShape3D", false, false):
		c = (cs as Node3D).global_position
	print("P02 centro ", c)
	var spazio := (liv as Node3D).get_world_3d().direct_space_state
	for d in [1.0, 1.5, 2.0, 2.2, 2.5]:
		for lato in [0.0, 30.0, -30.0]:
			var dir := Vector3(1, 0, 0).rotated(Vector3.UP, deg_to_rad(lato))
			var occhio: Vector3 = Vector3(c.x, 1.6, c.z) + dir * float(d)
			var q := PhysicsRayQueryParameters3D.create(occhio, occhio + (c - occhio).normalized() * 2.3, 29)
			q.collide_with_areas = true
			var h := spazio.intersect_ray(q)
			var chi: String = String(h.collider.name) if not h.is_empty() else "niente"
			print("PRENDI d %.1f lato %+.0f: %s" % [d, lato, chi])
	get_tree().quit()
