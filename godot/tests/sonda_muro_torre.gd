extends Node
## Sonda (non in CI): il muro est della sala vicino al portone della torre, per il disegno D3 (build 0.5.0). Raggi
## orizzontali a 1,1 m verso est da x 12, ogni 0,5 m in z: dove sta il muro e cosa c'è davanti.
const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var level := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate()
	add_child(level)
	for i in 30:
		await get_tree().physics_frame
	CorpiMesh.crea(level, AABB(Vector3(16, 1, -15), Vector3.ZERO).grow(14.0), null)
	for i in 5:
		await get_tree().physics_frame
	var spazio := get_viewport().find_world_3d().direct_space_state
	for y: float in [1.1]:
		var z := -26.0
		while z <= -4.0:
			var q := PhysicsRayQueryParameters3D.create(Vector3(10.0, y, z), Vector3(30.0, y, z))
			var h := spazio.intersect_ray(q)
			var g := PhysicsRayQueryParameters3D.create(Vector3(17.0, 3.0, z), Vector3(17.0, -2.0, z))
			var hg := spazio.intersect_ray(g)
			print("z %.1f: est %s %s n %s | pavimento x17 %s" % [z, (h.position as Vector3).snapped(Vector3.ONE * 0.01) if h else "-",
					String((h.collider as Node).get_path()).right(60) if h else "", (h.normal as Vector3).snapped(Vector3.ONE * 0.01) if h else "",
					(hg.position as Vector3).snapped(Vector3.ONE * 0.01) if hg else "-"])
			z += 0.5
	get_tree().quit()
