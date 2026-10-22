extends Node
## Sonda: i tentacoli di Jilly nella vasca centrale vicino al salvagente appoggiato al muro davanti (ogg_salvagente_nave_36).
const CP := preload("res://tests/controllo_posizionamento.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().paused = false
	var s := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(s)
	for i in 30:
		await get_tree().process_frame
	var sal := s.find_child("ogg_salvagente_nave_36", true, false) as Node3D
	var ab := AABB()
	var primo := true
	for m in sal.find_children("*", "MeshInstance3D", true, false) + ([sal] if sal is MeshInstance3D else []):
		var mi := m as MeshInstance3D
		var g := mi.global_transform * mi.get_aabb()
		ab = g if primo else ab.merge(g)
		primo = false
	printerr("SONDA salvagente pos ", sal.global_position, " aabb ", ab)
	for n in s.find_children("Medusa_Tentacoli", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		var cotta := CP._in_posa(mi, sk)
		var vicini := 0
		var box := ab.grow(0.4)
		var mx := Vector2(1e9, -1e9)
		for si in cotta.get_surface_count():
			var v: PackedVector3Array = cotta.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for p in v:
				var w := mi.global_transform * p
				if box.has_point(w):
					vicini += 1
					mx = Vector2(minf(mx.x, w.x), maxf(mx.y, w.x))
		var celle := {}
		for si in cotta.get_surface_count():
			var v2: PackedVector3Array = cotta.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for p in v2:
				var w := mi.global_transform * p
				if w.z > 12.0 and w.z < 13.2 and w.y < 0.9 and w.x > -4.5 and w.x < 1.0:
					var c := int(floor(w.x * 10.0))
					var vec: Vector3 = celle.get(c, Vector3(99, -99, 99))
					celle[c] = Vector3(minf(vec.x, w.z), maxf(vec.y, w.z), minf(vec.z, w.y))
		var ks := celle.keys()
		ks.sort()
		for c in ks:
			printerr("SONDA fascia x %.1f: z %.2f..%.2f, y min %.2f" % [c / 10.0, celle[c].x, celle[c].y, celle[c].z])
		printerr("SONDA ", mi.get_path(), " vertici vicini ", vicini, " x da ", mx.x, " a ", mx.y)
	get_tree().quit()
