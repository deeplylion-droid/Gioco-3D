extends "res://proposte/poster_sala/scatti_teli.gd"
## Collaudo dei due teli di Jilly bruciati (sala_cartellone_mascotte_0 e _1, enigmi, lavoro/poster-sala-bruciati), di
## ambienti-2. Stessa sala a pezzi e stesse luci di scatti_teli.gd, ma le viste del collaudo:
## - dagli occhi (1,6 m) lungo la strada dall'ingresso alla statua e di sbieco dai due lati, all'arrivo e col lampione;
## - da vicino, con una luce tecnica bianca vicino alla camera (nel gioco non c'è: serve solo a vedere i bordi): i
##   quattro angoli e i quattro lati di ogni telo dove la carta tocca la cornice, e di sbieco radente dai due lati, per
##   vedere se la carta sta sulla lamiera o se ne stacca; i buchi grandi dal davanti.
## E un controllo coi numeri: per ogni texel trasparente (alfa < 0,5) dei due teli, un raggio sulla geometria vera
## (le mesh, non le collisioni) dal davanti all'indietro: dietro il buco ci deve essere la lamiera della cornice a meno
## di 5 cm, non il muro più indietro o il vuoto.
## Uso (sotto il render.lock): xvfb-run ... --script res://tests/run.gd -- res://tests/collaudo/collaudo_teli.gd <cartella> <prima|dopo>

var _out := ""


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[1]
	var dopo := a.size() > 2 and a[2] == "dopo"
	DirAccess.make_dir_recursive_absolute(_out)
	seed(30)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	GameState.imposta_luci(GameState.Luci.PRIMA_DEL_RISVEGLIO)
	_radice = Node3D.new()
	_radice.name = "SalaPerTeli"
	get_tree().node_added.connect(_aggiunto)
	var tutta := (load(SALA) as PackedScene).instantiate()
	var look: LookSala = null
	for percorso in PARTI:
		var n := tutta.get_node_or_null(NodePath(percorso)) as Node3D
		if n == null:
			continue
		var tr := n.transform
		var padre := n.get_parent() as Node3D
		if padre != tutta and padre:
			tr = padre.transform * tr
		n.get_parent().remove_child(n)
		n.transform = tr
		_radice.add_child(n)
		if n is LookSala:
			look = n
	tutta.free()
	var we := WorldEnvironment.new()
	we.environment = look.ambiente if look else (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment)
	we.camera_attributes = look.attributi_camera if look else null
	_radice.add_child(we)
	var cam := Camera3D.new()
	cam.near = 0.02
	cam.far = 60.0
	_radice.add_child(cam)
	get_tree().root.add_child(_radice)
	cam.make_current()
	_luci_come_nel_gioco(_radice.get_node(^"Sala/Luci"))
	var arch := _radice.get_node(^"Sala/Architettura")
	if dopo:
		var sp := load("res://scripts/game/sala_principale.gd") as Script
		print("TELI rovinati: %d superfici" % int(sp.call(&"metti_teli_rovinati", arch)))
	var sfarfallio := _radice.get_node_or_null(^"Vasca/Sfarfallio") as FlickerLight
	var lampione := _radice.get_node_or_null(^"Sala/Luci/luce_lampione") as Light3D
	if sfarfallio and lampione:
		sfarfallio.set_targets(lampione, null)
		sfarfallio.turn_off()
	var pre := "dopo_" if dopo else "prima_"
	# i teli: centro, normale (verso l'ingresso), assi
	var teli := {}
	for nome in ["sala_cartellone_mascotte_0", "sala_cartellone_mascotte_1"]:
		var mi := arch.find_child(nome, true, false) as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		print("TELO %s aabb %s" % [nome, b])
		teli[nome] = [mi, b]
	# dagli occhi: la strada dall'ingresso verso la statua, e di sbieco
	var occhi := {
		"strada_1_ingresso": [Vector3(0.0, 1.6, 21.0), Vector3(0.0, 3.6, 9.8), 70.0],
		"strada_2": [Vector3(0.0, 1.6, 17.0), Vector3(0.0, 3.8, 9.8), 75.0],
		"strada_3_arcobaleno": [Vector3(-1.5, 1.6, 14.5), Vector3(-5.6, 4.6, 9.8), 70.0],
		"strada_3_bagnina": [Vector3(1.5, 1.6, 14.5), Vector3(5.6, 4.6, 9.8), 70.0],
		"sbieco_arcobaleno": [Vector3(-9.5, 1.6, 13.5), Vector3(-5.6, 4.6, 9.8), 65.0],
		"sbieco_bagnina": [Vector3(9.5, 1.6, 13.5), Vector3(5.6, 4.6, 9.8), 65.0],
	}
	for stato in ["arrivo", "lampione"]:
		if stato == "lampione" and sfarfallio:
			sfarfallio.turn_on(true)
		for nome in occhi:
			await _scatta(cam, occhi[nome], _out.path_join("%s%s_%s.jpg" % [pre, nome, stato]))
	# da vicino con la luce tecnica: angoli, lati, di sbieco radente
	var luce := OmniLight3D.new()
	luce.light_color = Color(1, 1, 1)
	luce.light_energy = 1.6
	luce.omni_range = 5.0
	cam.add_child(luce)
	luce.position = Vector3(0.25, 0.2, 0.0)
	for nome in teli:
		var b: AABB = teli[nome][1]
		var c := b.get_center()
		# il telo è sottile lungo un asse: quello è la normale; il davanti guarda verso +z (l'ingresso)
		var fuori := Vector3(0, 0, 1)
		var u := Vector3(1, 0, 0)
		if b.size.x < b.size.z:
			fuori = Vector3(signf(-c.x), 0, 0)
			u = Vector3(0, 0, 1)
		var mezzo_u := (b.size * u).length() * 0.5
		var mezzo_v := b.size.y * 0.5
		var faccia := c + fuori * (b.size * fuori.abs()).length() * 0.5
		var corto := "arcobaleno" if nome.ends_with("0") else "bagnina"
		var punti := {
			"angolo_alto_sx": Vector2(-1, 1), "angolo_alto_dx": Vector2(1, 1), "angolo_basso_sx": Vector2(-1, -1),
			"angolo_basso_dx": Vector2(1, -1), "lato_alto": Vector2(0, 1), "lato_basso": Vector2(0, -1),
			"lato_sx": Vector2(-1, 0), "lato_dx": Vector2(1, 0),
		}
		for k in punti:
			var d: Vector2 = punti[k]
			var q := faccia + u * d.x * mezzo_u * 0.92 + Vector3.UP * d.y * mezzo_v * 0.92
			await _scatta(cam, [q + fuori * 0.75 - Vector3.UP * 0.1, q, 50.0], _out.path_join("%s%s_vicino_%s.jpg" % [pre, corto, k]))
		# di sbieco radente dai due lati, a metà altezza: la carta sulla lamiera (o staccata)
		for s in [-1.0, 1.0]:
			var q := faccia + u * s * mezzo_u
			await _scatta(cam, [q + u * s * 0.6 + fuori * 0.35, faccia - u * s * mezzo_u * 0.3, 60.0],
					_out.path_join("%s%s_radente_%s.jpg" % [pre, corto, "sx" if s < 0 else "dx"]))
		# tutto il telo dal davanti, vicino (i buchi grandi)
		await _scatta(cam, [faccia + fuori * 3.2 - Vector3.UP * 0.6, faccia, 55.0], _out.path_join("%s%s_davanti.jpg" % [pre, corto]))
		if dopo:
			_buchi(teli[nome][0] as MeshInstance3D, fuori, corto)
	get_tree().quit()


## Per ogni texel trasparente (campionato ogni 8) del telo, dove sta sulla faccia (dalle UV dei triangoli) e cosa c'è
## dietro: un raggio dal davanti sulle mesh (collisioni fatte al volo dalle mesh vicine), la prima cosa colpita dopo la
## carta deve stare a meno di 5 cm dietro.
func _buchi(mi: MeshInstance3D, fuori: Vector3, nome: String) -> void:
	var mat := mi.get_surface_override_material(0) as StandardMaterial3D
	var si := 0
	for i in mi.mesh.get_surface_count():
		var m := mi.get_surface_override_material(i) as StandardMaterial3D
		if m and m.albedo_texture:
			mat = m
			si = i
	if mat == null:
		print("BUCHI %s: niente materiale" % nome)
		return
	var img := mat.albedo_texture.get_image()
	if img.is_compressed():
		img.decompress()
	var arr := mi.mesh.surface_get_arrays(si)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	# i corpi delle mesh vicine (la cornice, il muro), senza il telo stesso
	var spazio := PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(spazio, true)
	var corpi := 0
	var bt := mi.global_transform * mi.get_aabb()
	for n in _radice.find_children("*", "MeshInstance3D", true, false):
		var g := n as MeshInstance3D
		if g == mi or g.mesh == null:
			continue
		var bg := g.global_transform * g.get_aabb()
		if not bg.intersects(bt.grow(0.3)):
			continue
		var sh := g.mesh.create_trimesh_shape()
		if sh == null:
			continue
		sh.backface_collision = true
		var corpo := PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(corpo, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_add_shape(corpo, sh.get_rid())
		PhysicsServer3D.body_set_state(corpo, PhysicsServer3D.BODY_STATE_TRANSFORM, g.global_transform)
		PhysicsServer3D.body_set_space(corpo, spazio)
		corpi += 1
	var stato := PhysicsServer3D.space_get_direct_state(spazio)
	var w := img.get_width()
	var h := img.get_height()
	var tot := 0
	var lamiera := 0
	var lontano := 0
	var vuoto := 0
	var peggio := 0.0
	var xf := mi.global_transform
	for t in range(0, idx.size(), 3):
		var a := uvs[idx[t]]
		var b := uvs[idx[t + 1]]
		var c := uvs[idx[t + 2]]
		var pa := xf * vs[idx[t]]
		var pb := xf * vs[idx[t + 1]]
		var pc := xf * vs[idx[t + 2]]
		var umin := minf(a.x, minf(b.x, c.x))
		var umax := maxf(a.x, maxf(b.x, c.x))
		var vmin := minf(a.y, minf(b.y, c.y))
		var vmax := maxf(a.y, maxf(b.y, c.y))
		var x0 := int(umin * w)
		while x0 <= int(umax * w):
			var y0 := int(vmin * h)
			while y0 <= int(vmax * h):
				var uv := Vector2((x0 + 0.5) / w, (y0 + 0.5) / h)
				var bc := _baricentriche(uv, a, b, c)
				if bc.x >= 0.0 and bc.y >= 0.0 and bc.z >= 0.0 and img.get_pixel(posmod(x0, w), posmod(y0, h)).a < 0.5:
					var p := pa * bc.x + pb * bc.y + pc * bc.z
					tot += 1
					var q := PhysicsRayQueryParameters3D.create(p + fuori * 0.02, p - fuori * 0.6)
					var r := stato.intersect_ray(q)
					if r.is_empty():
						vuoto += 1
					else:
						var dist := (p - (r.position as Vector3)).dot(fuori)
						peggio = maxf(peggio, dist)
						if dist <= 0.05:
							lamiera += 1
						else:
							lontano += 1
				y0 += 8
			x0 += 8
	print("BUCHI %s: %d punti trasparenti (ogni 8 texel), dietro a meno di 5 cm %d, più lontano %d, niente %d; il più lontano %.3f m (%d mesh vicine)" % [
			nome, tot, lamiera, lontano, vuoto, peggio, corpi])
	PhysicsServer3D.free_rid(spazio)


static func _baricentriche(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d := v0.x * v1.y - v1.x * v0.y
	if absf(d) < 1e-12:
		return Vector3(-1, -1, -1)
	var v := (v2.x * v1.y - v1.x * v2.y) / d
	var ww := (v0.x * v2.y - v2.x * v0.y) / d
	return Vector3(1.0 - v - ww, v, ww)
