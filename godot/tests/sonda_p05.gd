extends Node
## Sonda: il fondo visibile della piscina a onde sotto gli angoli della Polaroid05 (per appoggiarla sul piano giusto).

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().paused = false
	var s := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(s)
	for i in 5:
		await get_tree().process_frame
	var fondo := s.find_child("sala_piscina_onde", true, false) as MeshInstance3D
	var tm := fondo.mesh.generate_triangle_mesh()
	var inv := fondo.global_transform.affine_inverse()
	var p := s.get_node("Polaroid/Polaroid05") as Node3D
	var c := Vector3(1.19978, 0.0, 2.899858)
	var yaw := p.global_rotation.y
	for a in [Vector3(0, 0, 0), Vector3(0.07, 0, 0.07), Vector3(-0.07, 0, 0.07), Vector3(0.07, 0, -0.07), Vector3(-0.07, 0, -0.07)]:
		var w: Vector3 = c + Basis(Vector3.UP, yaw) * (a as Vector3)
		var da := inv * (w + Vector3(0, 1.0, 0))
		var r := tm.intersect_ray(da, (inv.basis * Vector3.DOWN).normalized())
		printerr("SONDA angolo ", a, " fondo visibile ", (fondo.global_transform * (r["position"] as Vector3)).y if not r.is_empty() else 99.0, " in ", w)
	get_tree().quit()
