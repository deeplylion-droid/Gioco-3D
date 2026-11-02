extends Node
## Misure del bambino col cubo del corridoio del fiume (BambinoCorridoioFiume) nella sequenza vera (scelta A dell'utente
## del 1° novembre, "A ma animalo meglio"): il giocatore fermo a metà corridoio girato verso la scala, il bambino
## compare, il giocatore si gira e lo guarda, lui scappa nella porta del capannone. A ogni fotogramma:
## - la pelle vera (i vertici del modello che si vede, deformati dalle ossa: anche il cubo) dentro il mondo: un raggio
##   dall'asse del corpo (dalle anche alla testa) al vertice; dentro di più di 1 cm è una compenetrazione;
## - i piedi a terra (punta o tallone a meno di 3 cm dal pavimento): quanto scivolano in orizzontale (m/s);
## - da fermo, quanto si muovono la testa e le anche (che non sembri una statua).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/sonda_bambino_cubo.gd
## (CASO=vicino: il giocatore a 4 m, scappa subito)

const OGNI_VERTICE := 3
const TOLLERANZA := 0.01

var _p: Player
var _b: BambinoSfuggita
var _sk: Skeleton3D
# la pelle: per vertice 4 ossa, 4 pesi, 4 bind x vertice
var _ossa := PackedInt32Array()
var _pesi := PackedFloat32Array()
var _bv := PackedVector3Array()
var _nv := 0
var _piedi := PackedInt32Array()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# (SEME: una prova diversa, l'inclinazione della testa che parte a un altro momento)
	if OS.has_environment("SEME"):
		seed(int(OS.get_environment("SEME")))
	else:
		randomize()
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await get_tree().process_frame
	_p = GameState.player
	_p.process_mode = Node.PROCESS_MODE_DISABLED
	_p.camera.make_current()
	var ris := get_tree().current_scene.get_node(^"Risalita")
	_b = ris.find_child("BambinoCorridoioFiume", true, false) as BambinoSfuggita
	(ris.find_child("ObloFiume", true, false) as ObloLei).load_state({"finito": true})
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	_guarda(Vector3(-4.9, -3.8, 66.0), Vector3(-10.0, -4.4, 66.0))
	for i in 1800:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 60:
			break
	print("corpi dalle mesh: ", preload("res://tests/corpi_dalle_mesh.gd").crea(ris, AABB(Vector3(-12, -7, 56), Vector3(12, 5, 16)), null))
	_pelle_di(_b.bambino.get_node(^"Calmo") as Node3D)
	var caso := OS.get_environment("CASO") if OS.has_environment("CASO") else "fermati"
	var occhio := Vector3(-4.9, -3.8, 54.5) if caso == "fermati" else Vector3(-4.6, -3.8, 62.6)
	var scala := Vector3(-3.0, -4.6, 48.6)
	var guarda_lui := false
	# (quando ti giri a guardarlo, a caso: così la fuga parte da un momento diverso del fermo e dell'inclinazione della testa)
	var caso_rng := RandomNumberGenerator.new()
	caso_rng.seed = int(OS.get_environment("SEME")) if OS.has_environment("SEME") else int(Time.get_ticks_usec())
	var ritardo := caso_rng.randf() * 2.5
	print("ti giri a guardarlo %.2f s dopo che è comparso" % (0.8 + ritardo))
	var dati := {"pelle": 0, "pelle_max": 0.0, "peggiori": [], "fermo_testa": [], "fermo_anche": []}
	var scivoli := {}           # fase -> [somma, n, massimo]
	var prima_piedi := {}
	var prima_nodo := Vector3.INF
	var v_prima := -1.0
	var salto_v := [0.0, 0.0]          # [il più grande, quando]
	var pavimento := [0.0, 0.0, ""]    # [la punta più sotto il pavimento (m), quando, fase]
	var righe: Array[String] = []
	var t := 0.0
	var visto_da := -1.0
	var testa0 := Vector3.INF
	var anche0 := Vector3.INF
	var testa_mm := [Vector3.INF, -Vector3.INF]
	var anche_mm := [Vector3.INF, -Vector3.INF]
	while t < 20.0:
		if _b.stato == BambinoSfuggita.Stato.GUARDA and visto_da < 0.0:
			visto_da = t
		guarda_lui = visto_da >= 0.0 and t > visto_da + 0.8 + ritardo
		_guarda(occhio, _b.bambino.punto_testa() if guarda_lui else scala)
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if _b.stato == BambinoSfuggita.Stato.FINITO:
			break
		if not _b.bambino.visible:
			continue
		var ps := []
		for o in _sk.get_bone_count():
			ps.append(_sk.global_transform * _sk.get_bone_global_pose(o))
		var fase := "fermo" if _b.stato == BambinoSfuggita.Stato.GUARDA else (("girata" if bool(_b.bambino.get(&"_svolta")) else "corsa"))
		_controlla_pelle(ps, t, fase, dati)
		# i piedi
		var nodo := _b.bambino.global_position
		var v_nodo := 0.0 if prima_nodo == Vector3.INF else Vector2(nodo.x - prima_nodo.x, nodo.z - prima_nodo.z).length() * 60.0
		prima_nodo = nodo
		if fase != "fermo" and v_prima >= 0.0 and absf(v_nodo - v_prima) > salto_v[0]:
			salto_v = [absf(v_nodo - v_prima), t]
		v_prima = v_nodo if fase != "fermo" else -1.0
		var sotto := _sotto_pavimento(ps, nodo.y)
		if sotto > pavimento[0]:
			pavimento = [sotto, t, fase]
		if fase != "fermo":
			var ap := _b.bambino.get_node_or_null(^"Calmo/AnimationPlayer") as AnimationPlayer
			var perno: int = _b.bambino.get(&"_perno_osso")
			var r := "%.2f v%.2f x%.2f %s t%.2f perno %s" % [t, v_nodo, ap.speed_scale if ap else 0.0, ap.current_animation if ap else "", ap.current_animation_position if ap else 0.0, _sk.get_bone_name(perno).substr(0, 5) if perno >= 0 else "-"]
			for o in _piedi:
				if not _sk.get_bone_name(o).ends_with("ToeBase"):
					continue
				var w: Vector3 = (ps[o] as Transform3D).origin
				r += "  %s %.3f" % [_sk.get_bone_name(o).substr(0, 1), w.y - nodo.y]
				if prima_piedi.has(o):
					r += " s%.2f" % (Vector2(w.x - prima_piedi[o].x, w.z - prima_piedi[o].z).length() * 60.0)
			righe.append(r)
		var terra := _b.bambino.global_position.y
		for o in _piedi:
			var w: Vector3 = (ps[o] as Transform3D).origin
			if w.y - terra < 0.03 and prima_piedi.has(o):
				var v := Vector2(w.x - prima_piedi[o].x, w.z - prima_piedi[o].z).length() * 60.0
				var s: Array = scivoli.get(fase, [0.0, 0, 0.0, 0.0])
				scivoli[fase] = [s[0] + v, s[1] + 1, maxf(s[2], v), t if v > s[2] else s[3]]
			prima_piedi[o] = w
		if fase == "fermo" and OS.has_environment("RIGHE"):
			var apf := _b.bambino.get_node_or_null(^"Calmo/AnimationPlayer") as AnimationPlayer
			righe.append("%.2f fermo %s t%.2f" % [t, apf.current_animation, apf.current_animation_position])
		if fase == "fermo":
			var th: Vector3 = (ps[_sk.find_bone("Head")] as Transform3D).origin
			var ah: Vector3 = (ps[_sk.find_bone("Hips")] as Transform3D).origin
			testa_mm = [testa_mm[0].min(th), testa_mm[1].max(th)]
			anche_mm = [anche_mm[0].min(ah), anche_mm[1].max(ah)]
	print("== caso ", caso)
	print("pelle dentro il mondo: %d vertici-fotogramma, al più %.1f cm" % [dati["pelle"], dati["pelle_max"] * 100.0])
	var pg: Array = dati["peggiori"]
	pg.sort_custom(func(x, y): return x[0] > y[0])
	for e in pg.slice(0, 8):
		print("   %.1f cm a %.2f s (%s) in %s, vertice %s, osso %s" % [e[0] * 100.0, e[1], e[2], e[3], e[4], e[5]])
	for f in scivoli:
		var s: Array = scivoli[f]
		print("piedi a terra, %s: scivolano in media %.2f m/s, al più %.2f a %.2f s (%d campioni)" % [f, s[0] / maxf(s[1], 1), s[2], s[3], s[1]])
	print("salto di velocità più grande fra due fotogrammi: %.2f m/s a %.2f s" % salto_v)
	print("la punta più sotto il pavimento: %.1f cm a %.2f s (%s)" % [pavimento[0] * 100.0, pavimento[1], pavimento[2]])
	if testa_mm[0] != Vector3.INF:
		print("da fermo: la testa si muove di %s cm, le anche di %s cm" % [((testa_mm[1] - testa_mm[0]) * 100.0).snapped(Vector3.ONE * 0.1), ((anche_mm[1] - anche_mm[0]) * 100.0).snapped(Vector3.ONE * 0.1)])
	if OS.has_environment("RIGHE"):
		for r in righe:
			print(r)
	print("FINE")
	get_tree().quit(0)


func _guarda(occhio: Vector3, punto: Vector3) -> void:
	_p.global_position = occhio - Vector3.UP * (_p.get_eye_position().y - _p.global_position.y)
	_p.look_at_point(punto)
	_p.camera.global_transform = _p.get_aim_transform()


func _pelle_di(m: Node3D) -> void:
	_sk = m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for nome in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
		if _sk.find_bone(nome) >= 0:
			_piedi.append(_sk.find_bone(nome))
	var n := 0
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		var skin := (mi as MeshInstance3D).skin
		if mesh == null or skin == null:
			continue
		var bind_osso := PackedInt32Array()
		for b in skin.get_bind_count():
			var nome := skin.get_bind_name(b)
			bind_osso.append(_sk.find_bone(nome) if nome != "" else skin.get_bind_bone(b))
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			if a[Mesh.ARRAY_BONES] == null:
				continue
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bo = a[Mesh.ARRAY_BONES]
			var we = a[Mesh.ARRAY_WEIGHTS]
			var per: int = bo.size() / vs.size()
			for v in vs.size():
				n += 1
				if n % OGNI_VERTICE != 0:
					continue
				var lista := []
				for j in per:
					if float(we[v * per + j]) > 0.0:
						lista.append([float(we[v * per + j]), int(bo[v * per + j])])
				lista.sort_custom(func(x, y): return x[0] > y[0])
				lista = lista.slice(0, 4)
				var somma := 0.0
				for e in lista:
					somma += e[0]
				for j in 4:
					if j < lista.size():
						_ossa.append(bind_osso[lista[j][1]])
						_pesi.append(lista[j][0] / somma)
						_bv.append(skin.get_bind_pose(lista[j][1]) * vs[v])
					else:
						_ossa.append(0)
						_pesi.append(0.0)
						_bv.append(Vector3.ZERO)
				_nv += 1
	print("pelle: %d vertici" % _nv)


## Quanto il vertice più basso dei piedi (la pelle vera) è sotto il pavimento ([param terra], dove poggia il bambino).
func _sotto_pavimento(ps: Array, terra: float) -> float:
	var peggio := 0.0
	for v in _nv:
		var pos_y := 0.0
		var dei_piedi := false
		for j in 4:
			var w := _pesi[v * 4 + j]
			if w > 0.0:
				pos_y += ((ps[_ossa[v * 4 + j]] as Transform3D) * _bv[v * 4 + j]).y * w
				if _piedi.has(_ossa[v * 4 + j]) and w > 0.5:
					dei_piedi = true
		if dei_piedi:
			peggio = maxf(peggio, terra - pos_y)
	return peggio


func _controlla_pelle(ps: Array, t: float, fase: String, dati: Dictionary) -> void:
	var spazio := _sk.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = Layers.WORLD | preload("res://tests/corpi_dalle_mesh.gd").STRATO
	q.hit_back_faces = false
	q.exclude = [_p.get_rid()]
	var anche: Vector3 = (ps[_sk.find_bone("Hips")] as Transform3D).origin
	var testa: Vector3 = (ps[_sk.find_bone("Head")] as Transform3D).origin
	var cima := testa + (testa - anche).normalized() * 0.25
	for v in _nv:
		var pos := Vector3.ZERO
		var osso := -1
		var pm := 0.0
		for j in 4:
			var w := _pesi[v * 4 + j]
			if w > 0.0:
				pos += ((ps[_ossa[v * 4 + j]] as Transform3D) * _bv[v * 4 + j]) * w
				if w > pm:
					pm = w
					osso = _ossa[v * 4 + j]
		var asse := Geometry3D.get_closest_point_to_segment(pos, anche, cima)
		if asse.distance_to(pos) < 1e-4:
			continue
		q.from = asse
		q.to = pos
		var hit := spazio.intersect_ray(q)
		if hit.is_empty():
			continue
		var d := (hit["position"] as Vector3).distance_to(pos)
		if d <= TOLLERANZA:
			continue
		dati["pelle"] += 1
		dati["pelle_max"] = maxf(dati["pelle_max"], d)
		var c: Object = hit["collider"]
		dati["peggiori"].append([d, t, fase, (c as Node).get_parent().name + "/" + (c as Node).name if c is Node else "?", pos.snapped(Vector3.ONE * 0.01), _sk.get_bone_name(osso)])
