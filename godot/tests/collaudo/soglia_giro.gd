extends "res://tests/test_portone_torre.gd"
## Collaudo della lastra sotto la soglia del portone della torre (lavoro/varchi-cielo 2f5cc7ab,
## SalaPrincipale.chiudi_soglia_torre). Gioco vero, mondo fatto fino al portone aperto come test_portone_torre, senza
## schermo. Stampa SOGLIA:.
##  - le collisioni sotto la soglia: raggi in giù su una griglia x 19,6-20,6, z -16,6..-13,4;
##  - il giocatore vero attraversa la soglia camminando, correndo e saltando in 5 punti della larghezza: verso la torre
##    fino a x 20,8 (prima dell'entrata, che chiude il portone) e indietro verso la sala; piedi, velocità verticale,
##    fotogrammi senza pavimento, rallentamento;
##  - alla fine l'entrata vera camminando, col portone che si chiude.
## Con SENZA_LASTRA=1 toglie la lastra prima (per il confronto).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/soglia_giro.gd

const XS := 20.1
var sigle := {}


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	await _prepara()
	var lastra := level.find_child("soglia_torre_sotto", true, false) as MeshInstance3D
	if lastra:
		var ab := lastra.global_transform * lastra.get_aabb()
		print("SOGLIA: lastra in %s, scatola %s .. %s, materiale %s" % [lastra.get_path(), ab.position.snapped(Vector3.ONE * 0.001), ab.end.snapped(Vector3.ONE * 0.001), lastra.material_override])
	else:
		print("SOGLIA: lastra NON trovata")
	var pav := level.find_child("sala_pavimento", true, false) as MeshInstance3D
	print("SOGLIA: sala_pavimento %s" % [(pav.global_transform * pav.get_aabb()) if pav else "nulla"])
	if OS.has_environment("SENZA_LASTRA") and lastra:
		lastra.free()
		print("SOGLIA: lastra tolta per il confronto")
		for i in 5:
			await get_tree().physics_frame
	var spazio := get_viewport().find_world_3d().direct_space_state
	print("SOGLIA: collisioni (y del primo colpo dall'alto da y 1,0), colonne x da 19,60 a 20,60 ogni 5 cm")
	for iz in range(0, 17):
		var z := -16.6 + iz * 0.2
		var riga := "%6.2f " % z
		for ix in range(0, 21):
			var x := 19.6 + ix * 0.05
			var r := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 1.0, z), Vector3(x, -3.0, z), 0xFFFFFFFF, [p.get_rid()]))
			riga += (" %6.3f" % (r.position as Vector3).y) if not r.is_empty() else "    -  "
		print("SOGLIA:   " + riga)
	# i due capi del vano, fitti: dentro un solido (intersect_point) e il primo colpo da y 0,3 in giù
	print("SOGLIA: capi del vano, colonne x da 19,95 a 20,30 ogni 2,5 cm: 'S' origine dentro un solido, altrimenti y del colpo da 0,3")
	for z in [-16.62, -16.58, -16.54, -16.5, -16.46, -16.42, -13.58, -13.54, -13.5, -13.46, -13.42, -13.38]:
		var riga := "%6.2f " % z
		for ix in range(0, 15):
			var x := 19.95 + ix * 0.025
			var q := PhysicsPointQueryParameters3D.new()
			q.position = Vector3(x, 0.3, z)
			q.exclude = [p.get_rid()]
			if not spazio.intersect_point(q, 1).is_empty():
				riga += "      S"
				continue
			var r := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 0.3, z), Vector3(x, -3.0, z), 0xFFFFFFFF, [p.get_rid()]))
			riga += (" %6.3f" % (r.position as Vector3).y) if not r.is_empty() else "    -  "
		print("SOGLIA:   " + riga)
	if OS.has_environment("CAPI_MESH"):
		var CorpiMesh = load("res://tests/corpi_dalle_mesh.gd")
		print("SOGLIA: corpi dalle mesh %d" % CorpiMesh.crea(level, AABB(Vector3(XS, 0.0, -15.0), Vector3.ZERO).grow(6.0), p))
		for i in 3:
			await get_tree().physics_frame
		spazio = get_viewport().find_world_3d().direct_space_state
		print("SOGLIA: capi del vano con le mesh vere, stesse colonne: y del primo colpo da 0,3 in giù (raggi che colpiscono anche il retro) e il nodo")
		for z in [-16.62, -16.58, -16.54, -16.5, -13.5, -13.46, -13.42, -13.38]:
			var riga := "%6.2f " % z
			for ix in range(0, 15):
				var x := 19.95 + ix * 0.025
				var q := PhysicsRayQueryParameters3D.create(Vector3(x, 0.3, z), Vector3(x, -3.0, z), 0xFFFFFFFF, [p.get_rid()])
				q.hit_back_faces = true
				q.hit_from_inside = true
				var r := spazio.intersect_ray(q)
				if r.is_empty():
					riga += "    -   "
					continue
				var nd := r.collider as Node
				if nd is StaticBody3D and nd.get_parent() is MeshInstance3D:
					nd = nd.get_parent()
				var nome := String(level.get_path_to(nd))
				if not sigle.has(nome):
					sigle[nome] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[mini(sigle.size(), 25)]
				riga += " %6.3f%s" % [(r.position as Vector3).y, sigle[nome]]
			print("SOGLIA:   " + riga)
		print("SOGLIA: sigle %s" % [sigle])
		# fin dove va la fessura lungo il muro, oltre il vano: raggi in giù da y 0,3 e da y 2,5, x 19,95-20,30, z -19..-11
		print("SOGLIA: lungo il muro, z da -19 a -11 ogni 10 cm: per ogni z le x (19,95-20,30 ogni 2,5 cm) dove un raggio in giù da y 0,3 non incontra niente fino a -3")
		for iz in range(0, 81):
			var z := -19.0 + iz * 0.1
			var vuoti := []
			for ix in range(0, 15):
				var x := 19.95 + ix * 0.025
				var q := PhysicsRayQueryParameters3D.create(Vector3(x, 0.3, z), Vector3(x, -3.0, z), 0xFFFFFFFF, [p.get_rid()])
				q.hit_back_faces = true
				q.hit_from_inside = true
				if spazio.intersect_ray(q).is_empty():
					var q2 := PhysicsRayQueryParameters3D.create(Vector3(x, 2.5, z), Vector3(x, 0.31, z), 0xFFFFFFFF, [p.get_rid()])
					q2.hit_back_faces = true
					var sopra := spazio.intersect_ray(q2)
					vuoti.append("%.3f%s" % [x, "" if sopra.is_empty() else "(coperto a %.2f)" % (sopra.position as Vector3).y])
			if not vuoti.is_empty():
				print("SOGLIA:   z %.1f: %s" % [z, " ".join(vuoti)])
		get_tree().quit()
		return
	for modo in ["cammino", "corsa", "salto"]:
		for z in [-16.1, -15.6, -15.0, -14.4, -13.9]:
			for verso in [1.0, -1.0]:
				print("SOGLIA: " + await _attraversa(z, verso, modo))
	# l'entrata vera
	p.teleport(Vector3(17.5, 0.05, -15.0), EST, 0.0)
	for i in 20:
		await get_tree().physics_frame
	var ym := INF
	Input.action_press(&"move_forward")
	for i in 60 * 4:
		p.set_look(EST, 0.0)
		await get_tree().physics_frame
		if absf(p.global_position.x - XS) < 0.4:
			ym = minf(ym, p.global_position.y)
		if _dentro():
			break
	Input.action_release(&"move_forward")
	print("SOGLIA: entrata vera: dentro %s a x %.2f, piedi minimi sulla soglia %.3f" % [_dentro(), p.global_position.x, ym])
	for i in 60 * 8:
		await get_tree().physics_frame
	print("SOGLIA: portone quanto %.2f, giocatore %s, lastra ancora %s" % [float(portone.get(&"quanto")), p.global_position.snapped(Vector3.ONE * 0.01), is_instance_valid(lastra) and lastra.is_inside_tree()])
	print("SOGLIA: finito")
	get_tree().quit()


func _attraversa(z: float, verso: float, modo: String) -> String:
	# verso +1: dalla sala verso la torre (est), da x 18,6 a 21,0; -1: indietro, da 21,0 a 18,6
	var x_da := 18.6 if verso > 0.0 else 20.8
	var x_a := 20.8 if verso > 0.0 else 18.6
	var yaw := EST if verso > 0.0 else OVEST
	p.teleport(Vector3(x_da, 0.05, z), yaw, 0.0)
	for i in 20:
		await get_tree().physics_frame
	p.velocity = Vector3.ZERO
	Input.action_press(&"move_forward")
	if modo == "corsa":
		Input.action_press(&"sprint")
	var y_min := INF
	var y_max := -INF
	var vy := 0.0
	var aria := 0
	var v_prima := 0.0
	var v_min := INF
	var saltato := false
	var arrivato := false
	for f in 60 * 4:
		p.set_look(yaw, 0.0)
		if modo == "salto" and not saltato and absf(p.global_position.x - XS) < 0.7:
			saltato = true
			Input.action_press(&"jump")
		await get_tree().physics_frame
		Input.action_release(&"jump")
		var x := p.global_position.x
		var vh := Vector2(p.velocity.x, p.velocity.z).length()
		if absf(x - XS) < 0.4:
			y_min = minf(y_min, p.global_position.y)
			y_max = maxf(y_max, p.global_position.y)
			if modo != "salto":
				vy = maxf(vy, absf(p.velocity.y))
				if not p.is_on_floor():
					aria += 1
				v_min = minf(v_min, vh)
		elif absf(x - XS) > 0.8 and (x - XS) * verso < 0.0:
			v_prima = maxf(v_prima, vh)
		if _dentro():
			break
		if (x - x_a) * verso > -0.05:
			arrivato = true
			p.velocity = Vector3.ZERO
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	p.velocity = Vector3.ZERO
	var r := "%s z %.1f %s: arrivato %s (x %.2f, z %.2f)%s, piedi sulla soglia fra %.3f e %.3f" % [modo, z, "verso la torre" if verso > 0.0 else "verso la sala", arrivato, p.global_position.x, p.global_position.z, " ENTRATO" if _dentro() else "", y_min, y_max]
	if modo != "salto":
		r += ", vel. verticale max %.3f, fotogrammi senza pavimento %d, velocità prima %.2f e minima sulla soglia %.2f" % [vy, aria, v_prima, v_min]
	for i in 10:
		await get_tree().physics_frame
	return r
