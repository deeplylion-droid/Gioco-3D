extends Node
## Collaudo: da alcuni punti della sala principale, cosa c'è sotto e intorno (raggi sul mondo, strato WORLD) e
## quali mesh visibili ci sono entro un raggio. Uso: ... geometria come geometria.gd ...
##   -- res://tests/collaudo/sonda.gd <scena> <stato> "x,y,z;x,y,z" [raggio delle mesh, 1.5]

const STATI := preload("res://tests/collaudo/stati.gd")


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	Game.pause_on_focus_loss = false
	var livello := (load(a[1]) as PackedScene).instantiate()
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	for i in 30:
		await get_tree().physics_frame
	get_tree().paused = false
	var p = GameState.player
	for i in 900:
		if p == null or not is_instance_valid(p) or p.input_enabled:
			break
		await get_tree().physics_frame
	STATI.applica(livello, a[2])
	for i in 120:
		await get_tree().physics_frame
	var raggio := float(a[4]) if a.size() > 4 else 1.5
	var spazio := (livello as Node3D).get_world_3d().direct_space_state
	for t in a[3].split(";", false):
		var c := t.split(",")
		var pt := Vector3(float(c[0]), float(c[1]), float(c[2]))
		print("SONDA punto ", pt)
		for d in [Vector3.DOWN, Vector3.UP, Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var q := PhysicsRayQueryParameters3D.create(pt, pt + d * 10.0, Layers.WORLD | Layers.BARRIERS)
			q.hit_back_faces = true
			var h := spazio.intersect_ray(q)
			if h.is_empty():
				print("  ", d, ": niente entro 10 m")
			else:
				print("  ", d, ": %.2f m  %s" % [pt.distance_to(h.position), livello.get_path_to(h.collider)])
		for n in livello.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var b := mi.global_transform * mi.get_aabb()
			var vicino := b.grow(raggio).has_point(pt)
			if vicino and b.size.length() < 6.0:
				print("  mesh ", livello.get_path_to(mi), " vis=", mi.is_visible_in_tree(), " box ", b.position.snapped(Vector3.ONE * 0.01), " ", b.size.snapped(Vector3.ONE * 0.01))
	get_tree().quit()
