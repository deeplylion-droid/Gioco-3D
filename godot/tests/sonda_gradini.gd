extends Node
## Sonda: le superfici orizzontali basse (gradini) intorno alla struttura di gioco, in una griglia.
const LEVEL := "res://scenes/sala_principale.tscn"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 5:
		await get_tree().physics_frame
	var space := (GameState.player as Node3D).get_world_3d().direct_space_state
	var righe := PackedStringArray()
	var z := -21.5
	while z < -11.0:
		var r := "%6.1f " % z
		var x := -19.0
		while x < -9.0:
			var da := Vector3(x, 1.45, z)
			var c := "."
			var q := PhysicsRayQueryParameters3D.create(da, Vector3(x, 0.03, z), Layers.WORLD)
			q.exclude = [(GameState.player as CollisionObject3D).get_rid()]
			var h := space.intersect_ray(q)
			if not h.is_empty() and h.normal.y > 0.7:
				c = str(clampi(int(h.position.y / 0.15), 0, 9))
			elif not h.is_empty():
				c = "/"
			r += c
			x += 0.15
		righe.append(r)
		z += 0.15
	for r in righe:
		print("G ", r)
	# varchi: raggi orizzontali a 0,5 e 1,2 m sopra la cima della scala (1,24), da est verso ovest
	for zz in range(-170, -140, 5):
		var zf := zz / 10.0
		for alt in [1.75, 2.4]:
			var q := PhysicsRayQueryParameters3D.create(Vector3(-15.6, alt, zf), Vector3(-18.0, alt, zf), Layers.WORLD)
			var h := space.intersect_ray(q)
			print("VARCO z %.1f y %.2f: %s" % [zf, alt, ("muro a x %.2f (%s)" % [h.position.x, h.collider.name]) if not h.is_empty() else "libero"])
	for xx in range(-180, -140, 5):
		var xf := xx / 10.0
		var q := PhysicsRayQueryParameters3D.create(Vector3(xf, 1.75, -15.0), Vector3(xf, 1.75, -20.0), Layers.WORLD)
		var h := space.intersect_ray(q)
		print("NORD x %.1f: %s" % [xf, ("muro a z %.2f (%s)" % [h.position.z, h.collider.name]) if not h.is_empty() else "libero"])
	get_tree().quit()
