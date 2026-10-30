extends Node
## Sonda: i muri oltre la porta tagliafuoco del corridoio degli interni (raggi in orizzontale a 1 m dal pavimento).

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file("res://scenes/interni/interni.tscn")
	for i in 120:
		await get_tree().physics_frame
	var sp := get_viewport().find_world_3d().direct_space_state
	for x in [21.5, 22.3, 23.0, 23.6, 24.2]:
		for z in [-1.3, -0.8, -1.8]:
			var o := Vector3(x, 0.9, z)
			var r := ""
			for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.DOWN]:
				var h: Dictionary = sp.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * 8.0))
				r += " %s:%s" % [d, ("%.2f %s" % [(h.position as Vector3).distance_to(o), (h.collider as Node).name]) if not h.is_empty() else "-"]
			print("(%.1f, %.1f)%s" % [x, z, r])
	get_tree().quit()
