extends Node
## Collaudo: quali facce della collisione della struttura del bacino toglie la correzione T1 (_varco_scalette):
## per ogni scaletta il numero di facce tolte, la loro estensione e quante guardano di lato (pareti) invece che
## essere montanti o pioli. Una parete del bacino tolta lascerebbe un buco nella collisione.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_varco.gd

func _ready() -> void:
	var si := SalaInseguimento.new()
	si.dati = JSON.parse_string(FileAccess.get_file_as_string(SalaInseguimento.DIR + "inseguimento_gioco.json"))
	var glb: Node3D = (load(SalaInseguimento.DIR + "inseguimento_struttura.glb") as PackedScene).instantiate()
	add_child(glb)
	for k in si.dati["scale"].size():
		var s: Dictionary = si.dati["scale"][k]
		var piede := SalaInseguimento.b([s["x"], s["y"], s["z0"]])
		var verso := SalaInseguimento.b(s["verso"])
		var tolte := 0
		var pareti := 0
		var area_pareti := 0.0
		var box := AABB()
		var primo := true
		for sb in glb.find_children("*", "StaticBody3D", true, false):
			for cs in sb.get_children():
				if not cs is CollisionShape3D or not (cs as CollisionShape3D).shape is ConcavePolygonShape3D:
					continue
				var t := (cs as Node3D).global_transform
				var f := ((cs as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces()
				for i in range(0, f.size(), 3):
					var a := t * f[i]
					var b := t * f[i + 1]
					var c := t * f[i + 2]
					var si1 := SalaInseguimento.new()
					si1.dati = {"scale": [s]}
					if si1._nella_scaletta(a) and si1._nella_scaletta(b) and si1._nella_scaletta(c):
						tolte += 1
						var n := (b - a).cross(c - a)
						var ar := n.length() * 0.5
						n = n.normalized()
						if primo:
							box = AABB(a, Vector3.ZERO)
							primo = false
						box = box.expand(a).expand(b).expand(c)
						# una parete: larga più di 0,15 m² e verticale, girata come la scaletta
						if ar > 0.05 and absf(n.y) < 0.3 and absf(n.dot(verso)) > 0.8:
							pareti += 1
							area_pareti += ar
					si1.free()
		print("VARCO: scaletta %d piede %s verso %s: tolte %d facce in %s; facce larghe verso la scaletta %d (%.2f m²)" % [k, str(piede), str(verso), tolte, str(box), pareti, area_pareti])
	si.free()
	get_tree().quit()
