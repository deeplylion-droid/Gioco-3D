extends Node
## Sonda: lei nei suoi posti dell'inseguimento (come li mette SalaInseguimento) e le animazioni fotogramma per
## fotogramma: quali ossa entrano nelle collisioni della sala (pareti, fondi, ringhiere), dove sta rispetto
## all'acqua e se all'inizio della salita si vede già. Per la squadra (proposte/ è esclusa dall'export).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://proposte/mascotte/sonda_lei_inseguimento.gd

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"

var sala: SalaInseguimento
var lei: MedusaAffacciata
var ap: AnimationPlayer
var sk: Skeleton3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	sala = (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	sala.crea_luci = false
	add_child(sala)
	for i in 10:
		await get_tree().physics_frame
	sala.set_physics_process(false)
	lei = sala.lei
	ap = lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	sk = lei.get_model_instance().find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var d := sala.dati
	var posti := []
	for v in 3:
		var r: Array = d["vasche"][v]["rett"]
		var centro := SalaInseguimento.b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(d["vasche"][v]["fondo"]) + 1.0])
		posti.append(["vasca_%d" % v, sala._posto_vasca(v), centro, ["sale_dall_acqua", "incombe", "presa", "respinta", "scende"]])
	for k in d["scolo"].size():
		var r: Array = d["scolo"][k]["rett"]
		var centro := SalaInseguimento.b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(d["scolo"][k]["fondo"]) + 1.0])
		posti.append(["scolo_%d" % k, sala._posto_scolo(k), centro, ["sale_dall_acqua_veloce", "incombe", "presa"]])
	var g: Dictionary = d["grata"]
	posti.append(["grata", SalaInseguimento.b(d["lei"][2]["pos"]), SalaInseguimento.b(g["perno"]), ["sale_dall_acqua_veloce", "colpo_grata", "scende"]])
	var s: Dictionary = d["scale"][0]
	posti.append(["sb1", Vector3.ZERO, SalaInseguimento.b([float(s["x"]), float(s["y"]), float(s["z0"]) + 1.0]), ["affacciata_sb1"]])
	var spazio := get_viewport().world_3d.direct_space_state
	for posto in posti:
		var nome: String = posto[0]
		var pos: Vector3 = posto[1]
		var guarda: Vector3 = posto[2]
		if nome == "sb1":
			# come in gioco: il giocatore verso la scaletta
			pos = _sb1_da(guarda)
		else:
			lei.global_position = pos
			var gg := guarda
			gg.y = pos.y
			lei.look_at(gg, Vector3.UP, true)
		lei.visible = true
		print("== ", nome, " origine ", _bl(pos), " (verso ", _bl(guarda), ")")
		_acqua(nome, pos)
		for an: String in posto[3]:
			var a := ap.get_animation(StringName("inseguimento/" + an))
			var dentro := {}
			var n := int(a.length * 15.0)
			var cima_inizio := -999.0
			var fondo_inizio := 999.0
			for k in n + 1:
				var t := minf(k / 15.0, a.length - 0.001)
				ap.play(StringName("inseguimento/" + an))
				ap.seek(t, true)
				ap.advance(0.0)
				var glob := {}
				for i in sk.get_bone_count():
					glob[i] = sk.global_transform * sk.get_bone_global_pose(i).origin
					if k == 0:
						cima_inizio = maxf(cima_inizio, (glob[i] as Vector3).y)
						fondo_inizio = minf(fondo_inizio, (glob[i] as Vector3).y)
				for i in sk.get_bone_count():
					var pa := sk.get_bone_parent(i)
					if pa < 0 or (glob[pa] as Vector3).distance_to(glob[i]) < 0.005:
						continue
					var bn := sk.get_bone_name(i)
					var q := PhysicsRayQueryParameters3D.create(glob[pa], glob[i])
					q.hit_back_faces = true
					var hit := spazio.intersect_ray(q)
					if not hit.is_empty():
						var nodo := hit["collider"] as Node
						var chi := String(nodo.get_parent().name) + "/" + String(nodo.name) if nodo.get_parent() else String(nodo.name)
						var parte := bn.substr(0, 12) if bn.begins_with("tentacolo") else bn
						var key := "%s attraversa %s" % [parte, chi]
						if not dentro.has(key):
							dentro[key] = [t, hit["position"]]
			var righe := []
			for key in dentro:
				righe.append("%s (%.2f s, %s)" % [key, dentro[key][0], _bl(dentro[key][1])])
			print("  ", an, ": ", "niente attraversato" if righe.is_empty() else ", ".join(righe.slice(0, 8)) + (" ... (%d)" % righe.size() if righe.size() > 8 else ""))
			if an.begins_with("sale") or an == "affacciata_sb1":
				print("    all'inizio: punto più alto %.2f, più basso %.2f (origine %.2f)" % [cima_inizio, fondo_inizio, pos.y])
			if an == "incombe" or an == "affacciata_sb1":
				print("    su: punto più basso %.2f" % fondo_inizio)
	print("FINE")
	get_tree().quit()


func _sb1_da(scaletta: Vector3) -> Vector3:
	# come _posto_sb1, con il giocatore alla scaletta
	var pz: Dictionary = sala.dati["pozzo"]
	var r: Array = pz["rett"]
	var c := Vector2((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0)
	var mezzo := Vector2((r[2] - r[0]) / 2.0, (r[3] - r[1]) / 2.0)
	var dd := Vector2(scaletta.x, -scaletta.z) - c
	var fuori := Vector2(signf(dd.x), 0.0) if absf(dd.x) / mezzo.x > absf(dd.y) / mezzo.y else Vector2(0.0, signf(dd.y))
	var spigolo := c + fuori * (mezzo.x if fuori.x != 0.0 else mezzo.y)
	var o := spigolo - fuori * 1.0
	var pos := SalaInseguimento.b([o.x, o.y, float(pz["bordo"]) - 0.8])
	lei.global_position = pos
	lei.look_at(SalaInseguimento.b([o.x + fuori.x, o.y + fuori.y, float(pz["bordo"]) - 0.8]), Vector3.UP, true)
	return pos


## In che acqua sta: dentro una vasca, una vasca di scolo, il bacino o sopra la sala allagata.
func _acqua(nome: String, pos: Vector3) -> void:
	var x := pos.x
	var y := -pos.z
	var d := sala.dati
	var dove := "sopra la sala allagata (acqua %.2f, fondo %.2f)" % [float(d["allagato"]["acqua"]), float(d["allagato"]["fondo"])]
	for gruppo in ["vasche", "scolo"]:
		for v in d[gruppo]:
			var r: Array = v["rett"]
			if x > r[0] and x < r[2] and y > r[1] and y < r[3]:
				dove = "dentro %s (acqua %.2f, fondo %.2f)" % [gruppo, float(v["acqua"]), float(v["fondo"])]
	var bc: Array = d["bacino"]["rett"]
	if x > bc[0] and x < bc[2] and y > bc[1] and y < bc[3]:
		dove = "dentro il bacino (acqua %.2f, fondo %.2f)" % [float(d["bacino"]["acqua"]), float(d["bacino"]["fondo"])]
	print("  origine a quota %.2f, %s" % [pos.y, dove])


func _bl(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, -v.z, v.y]
