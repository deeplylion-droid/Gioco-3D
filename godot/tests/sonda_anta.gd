extends Node
## Sonda: dove sta l'anta aperta dell'armadietto ovest 02 rispetto alle sue cerniere (nella scena degli interni).

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var s := (load("res://scenes/interni/interni.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(s)
	for i in 5:
		await get_tree().process_frame
	var anta := s.find_child("armadietti_ovest_02_anta", true, false) as MeshInstance3D
	var st := s.find_child("spogliatoi_statico", true, false) as MeshInstance3D
	var ab := anta.global_transform * anta.get_aabb()
	print("SONDA anta ", ab, " origine ", anta.global_position)
	var gt := st.global_transform
	var vicini := []
	for p in st.mesh.get_faces():
		var w := gt * p
		if w.distance_to(ab.position + Vector3(0, 0.2, 0)) < 0.4 and w.y > 0.25 and w.y < 0.5:
			vicini.append(w)
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for w in vicini:
		lo = lo.min(w); hi = hi.max(w)
	print("SONDA fisso vicino al cardine (0,25-0,5 m): ", vicini.size(), " da ", lo, " a ", hi)
	# come _staccato del controllo: la forma convessa dell'anta allargata di 5 mm contro la mesh del fisso
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1 << 20
	var cs := CollisionShape3D.new()
	cs.shape = st.mesh.create_trimesh_shape()
	corpo.add_child(cs)
	s.add_child(corpo)
	corpo.global_transform = st.global_transform
	await get_tree().physics_frame
	await get_tree().physics_frame
	var conv := anta.mesh.create_convex_shape(true, false) as ConvexPolygonShape3D
	var agt := anta.global_transform
	for stacco in [0.005, 0.01, 0.02, 0.05]:
		var punti := PackedVector3Array()
		for q in conv.points:
			var w := agt * q
			for sp in [Vector3(stacco, 0, 0), Vector3(-stacco, 0, 0), Vector3(0, stacco, 0), Vector3(0, -stacco, 0), Vector3(0, 0, stacco), Vector3(0, 0, -stacco)]:
				punti.append(w + sp)
		var forma := ConvexPolygonShape3D.new()
		forma.points = punti
		var qp := PhysicsShapeQueryParameters3D.new()
		qp.shape = forma
		qp.collision_mask = 1 << 20
		var r: Array = s.get_world_3d().direct_space_state.intersect_shape(qp, 4)
		print("SONDA stacco ", stacco, " tocca ", r.size(), " punti convessi ", conv.points.size())
	var best := 9.0
	var bp := Vector3.ZERO
	for q in anta.mesh.get_faces():
		var w := agt * q
		var d := Vector2(w.x - 3.5, w.z + 4.15).length()
		if d < best:
			best = d; bp = w
	print("SONDA punto dell'anta più vicino all'asse del cardine: ", bp, " a ", best)
	get_tree().quit()
