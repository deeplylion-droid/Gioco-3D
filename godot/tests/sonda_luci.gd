extends Node
## Prova (non è nella CI): misure per mettere le luci nuove.

func _ready() -> void:
	_run.call_deferred()

func _ray(a: Vector3, b: Vector3) -> String:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	var h := get_viewport().world_3d.direct_space_state.intersect_ray(q)
	return "nessuno" if h.is_empty() else "%s n=%s (%s)" % [str(h.position.snapped(Vector3.ONE * 0.01)), str(h.normal.snapped(Vector3.ONE * 0.01)), (h.collider as Node).name]

func _run() -> void:
	get_tree().change_scene_to_file("res://scenes/interni/interni.tscn")
	for i in 30:
		await get_tree().physics_frame
	var s := get_tree().current_scene
	for n in s.find_children("neon_spogliatoi*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		print("NEON %s pos=%s aabb=%s" % [mi.name, str(mi.global_position.snapped(Vector3.ONE * 0.01)), str(mi.get_aabb())])
	for p in [Vector3(9.7, 0.5, -13.4), Vector3(9.7, 0.5, -14.5), Vector3(9.5, 0.5, -16.0)]:
		print("SU da %s: %s" % [p, _ray(p, p + Vector3.UP * 10)])
	get_tree().change_scene_to_file("res://scenes/tecnici/tecnici.tscn")
	for i in 30:
		await get_tree().physics_frame
	for x in [15.5, 16.5, 17.2]:
		var p := Vector3(x, 1.5, 0.0)
		print("TUNNEL x=%.1f su: %s | nord: %s | sud: %s | ovest: %s" % [x, _ray(p, p + Vector3.UP * 10), _ray(p, p + Vector3.BACK * -10), _ray(p, p + Vector3.BACK * 10), _ray(p, p + Vector3.LEFT * 10)])
	get_tree().quit()
