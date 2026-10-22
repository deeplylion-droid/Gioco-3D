extends Node
## Sonda: dove sta la superficie visibile (le mesh, non la collisione) del muro dietro un punto, lungo una
## direzione (senza le cose della squadra, in Mascotte). Uso: ... -- res://proposte/mascotte/sonda_muro.gd x,y,z dx,dy,dz [altri punti ...]

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(level)
	for i in 10:
		await get_tree().physics_frame
	var a := OS.get_cmdline_user_args()
	var prove := []
	for i in range(1, a.size(), 2):
		var p := a[i].split(","); var d := a[i + 1].split(",")
		prove.append([Vector3(float(p[0]), float(p[1]), float(p[2])), Vector3(float(d[0]), float(d[1]), float(d[2])).normalized()])
	for c in level.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.skin or String(level.get_path_to(mi)).begins_with("Mascotte"):
			continue
		var bb := mi.global_transform * mi.get_aabb()
		var serve := false
		for pr in prove:
			if bb.grow(0.3).intersects_segment(pr[0] - pr[1] * 0.5, pr[0] + pr[1] * 0.6):
				serve = true
		if not serve:
			continue
		var corpo := StaticBody3D.new()
		corpo.collision_layer = 1 << 20
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_trimesh_shape()
		corpo.add_child(cs)
		mi.add_child(corpo)
		corpo.global_transform = mi.global_transform
		corpo.set_meta(&"chi", String(level.get_path_to(mi)))
	for i in 3:
		await get_tree().physics_frame
	var sp := level.get_viewport().world_3d.direct_space_state
	for pr in prove:
		for strato in [1 << 20, Layers.WORLD]:
			var q := PhysicsRayQueryParameters3D.create(pr[0] - pr[1] * 0.5, pr[0] + pr[1] * 0.6, strato)
			q.hit_back_faces = false
			var h := sp.intersect_ray(q)
			var chi = h["collider"].get_meta(&"chi", h["collider"].name) if not h.is_empty() else ""
			print("%s %s: %s" % ["mesh" if strato == 1 << 20 else "collisione", pr[0], "niente" if h.is_empty() else "%s a %.4f m dal punto (%s)" % [h["position"], ((h["position"] as Vector3) - pr[0]).dot(pr[1]), chi]])
	print("FINE")
	get_tree().quit()
