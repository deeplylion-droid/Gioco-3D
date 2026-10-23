extends Node
## Sonda: cosa c'è nelle celle d'ingombro di ambienti-1 (controllo del 23 ottobre): i vertici delle mesh vicino all'asse
## della cella e, a 1,6 m, quanto passaggio resta libero (raggi orizzontali sulle collisioni).

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(s)
	for i in 20:
		await get_tree().physics_frame
	for c in [["Interni/Ambienti/Corridoio/corridoio_statico", Vector3(8.75, 0, 42.25)],
			["Interni/Ambienti/Stanzino/cassetta_pronto_soccorso", Vector3(4.5, 0, 30.75)],
			["Sala/Interattivi/sala_portone_torre", Vector3(19.5, 0, -12.25)]]:
		var n := s.get_node_or_null(NodePath(c[0]))
		if n == null:
			printerr("SONDA manca ", c[0])
			continue
		var cen: Vector3 = c[1]
		for m in [n] + n.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var ab := AABB()
			var primo := true
			var conta := 0
			for si in mi.mesh.get_surface_count():
				var v: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
				for p in v:
					var w := mi.global_transform * p
					if Vector2(w.x - cen.x, w.z - cen.z).length() < 0.35 and w.y > -1.7 and w.y < 2.1:
						ab = AABB(w, Vector3.ZERO) if primo else ab.expand(w)
						primo = false
						conta += 1
			printerr("SONDA ", c[0], " ", mi.name, " vertici vicini ", conta, " ", ab, " aabb tutto ", mi.global_transform * mi.get_aabb())
	# passaggio libero a 1,6 m davanti alla cassetta: raggi lungo x e z dal centro della cella
	var sp: PhysicsDirectSpaceState3D = (s as Node3D).get_world_3d().direct_space_state
	for c in [Vector3(4.5, 1.6, 30.75), Vector3(19.5, 1.6, -12.25), Vector3(8.75, 1.6, 42.25), Vector3(8.75, 0.6, 42.25)]:
		var r := []
		for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var q := PhysicsRayQueryParameters3D.create(c, c + d * 5.0)
			var h: Dictionary = sp.intersect_ray(q)
			r.append("%s:%s" % [d, "%.2f %s" % [c.distance_to(h.position), h.collider.get_path()] if h else "-"])
		printerr("SONDA raggi da ", c, " ", r)
	# muro della vasca dietro la bava (BavaMuroVasca, x -0,5): la faccia del muro più avanti, per fasce d'altezza
	for nome in ["sala_vasca_offerte", "sala_vasca_centrale"]:
		for m in s.find_children(nome, "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var fasce := {}
			for si in mi.mesh.get_surface_count():
				var v: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
				for p in v:
					var w := mi.global_transform * p
					if absf(w.x + 0.5) < 0.2 and w.y > -0.05 and w.y < 1.05 and w.z > 12.1 and w.z < 12.6:
						var k := int(floor(w.y * 10.0))
						fasce[k] = maxf(float(fasce.get(k, -99.0)), w.z)
			var ks := fasce.keys()
			ks.sort()
			for k in ks:
				printerr("SONDA muro ", nome, " y %.1f z max %.4f" % [k / 10.0, fasce[k]])
	var bava := s.find_child("BavaMuroVasca", true, false)
	printerr("SONDA bava ", bava)
	get_tree().quit()
