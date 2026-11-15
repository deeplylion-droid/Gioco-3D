extends Node
## Collaudo riga del fiume (#130): per ogni triangolo delle pareti del canale (la mesh col mosaico della vasca, verticale,
## fra quota 0 e il fondo) guarda da che parte c'è l'acqua (un punto 3 cm fuori dal centro del triangolo, dentro uno dei
## poligoni d'acqua del fiume) e da che parte guarda la faccia davanti (l'avvolgimento: in Godot la faccia davanti gira in
## senso orario) e la normale salvata. Stampa i triangoli dove la faccia davanti non guarda l'acqua (PARETE:).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_pareti_fiume.gd

func _ready() -> void:
	_run.call_deferred()


func _in_acqua(polys: Array, p: Vector2) -> bool:
	for w in polys:
		if Geometry2D.is_point_in_polygon(p, w):
			return true
	return false


func _run() -> void:
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	var t0 := Time.get_ticks_msec()
	while not bool(f.get(&"costruita")) and Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
	var polys: Array = f.get(&"_poligoni_acqua_cache")
	var mat = f.get(&"mat_vasca")
	var tot := 0
	var storti := 0
	var normale_storta := 0
	var dubbi := 0
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override != mat or mi.mesh == null:
			continue
		var arr := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var cnt := idx.size() if idx.size() > 0 else v.size()
		var verticali := 0
		for k in range(0, cnt, 3):
			var i0 := idx[k] if idx.size() > 0 else k
			var i1 := idx[k + 1] if idx.size() > 0 else k + 1
			var i2 := idx[k + 2] if idx.size() > 0 else k + 2
			var a := mi.global_transform * v[i0]
			var b := mi.global_transform * v[i1]
			var c := mi.global_transform * v[i2]
			var g := (b - a).cross(c - a)
			if g.length() < 1e-6 or absf(g.normalized().y) > 0.1:
				continue
			verticali += 1
			tot += 1
			# faccia davanti in senso orario: la sua normale è -g
			var davanti := (-g).normalized()
			var m := (a + b + c) / 3.0
			var m2 := Vector2(m.x, m.z)
			var d2 := Vector2(davanti.x, davanti.z).normalized()
			var acqua_davanti := _in_acqua(polys, m2 + d2 * 0.03)
			var acqua_dietro := _in_acqua(polys, m2 - d2 * 0.03)
			var n := (nn[i0] + nn[i1] + nn[i2]).normalized()
			if acqua_davanti == acqua_dietro:
				dubbi += 1
				if dubbi <= 15:
					print("PARETE dubbio (acqua dai due lati %s) a %s, davanti %s" % [acqua_davanti, m.snappedf(0.01), davanti.snappedf(0.01)])
				continue
			if not acqua_davanti:
				storti += 1
				if storti <= 40:
					print("PARETE STORTA a %s, davanti %s, larga %.3f m" % [m.snappedf(0.01), davanti.snappedf(0.01), (b - a).length()])
			if (n.dot(davanti) < 0.0) != (not acqua_davanti) and n.dot(davanti) < 0.0:
				normale_storta += 1
		print("PARETE: mesh %s, %d triangoli verticali" % [mi.name, verticali])
	print("PARETE: %d triangoli, %d con la faccia davanti non verso l'acqua, %d con l'acqua dai due lati o da nessuno, %d con la normale contro la faccia" % [tot, storti, dubbi, normale_storta])
	get_tree().quit()
