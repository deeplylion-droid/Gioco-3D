extends Node
## Sonda: i triangoli della mesh della struttura di gioco (sala_area_bimbi.glb, sala_struttura_gioco: da lei
## sala_principale.gd fa la collisione trimesh) in una scatola, con la superficie e il materiale: che cosa
## chiude il passaggio in cima alla scala. SCATOLA="x0,y0,z0,x1,y1,z1" (globali).

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var s := (load("res://assets/ambiente/sala/sala_area_bimbi.glb") as PackedScene).instantiate()
	add_child(s)
	var mi := s.find_child("sala_struttura_gioco", true, false) as MeshInstance3D
	var v := OS.get_environment("SCATOLA").split_floats(",")
	var box := AABB(Vector3(v[0], v[1], v[2]), Vector3(v[3] - v[0], v[4] - v[1], v[5] - v[2]))
	var t := mi.global_transform
	print("MESH ", mi.mesh.get_surface_count(), " superfici, trasformazione ", t)
	for si in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(si)
		var vert: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var dentro := AABB()
		var n := 0
		for i in range(0, idx.size(), 3):
			var a := t * vert[idx[i]]
			var b := t * vert[idx[i + 1]]
			var c := t * vert[idx[i + 2]]
			var tri := AABB(a, Vector3.ZERO).expand(b).expand(c)
			if tri.intersects(box):
				dentro = tri if n == 0 else dentro.merge(tri)
				n += 1
		if n > 0:
			var m := mi.mesh.surface_get_material(si)
			print("SUPERFICIE %d (%s): %d triangoli nella scatola, ingombro %s" % [si, m.resource_name if m else "-", n, dentro])
	get_tree().quit()
