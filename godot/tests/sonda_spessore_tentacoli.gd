extends Node
## Sonda: lo spessore vero della pelle dei tentacoli di lei (la medusa della fossa, scala del gioco). Per ogni vertice
## della pelle, l'osso che lo muove di più e la sua distanza dall'asse di quell'osso (dalla testa alla testa del figlio,
## o alla punta), nella posa di riposo. Stampa, per posizione lungo la catena (0 = radice), il raggio mediano, il 95% e
## il massimo su tutti i tentacoli, e il raggio della morbidezza (MorbidezzaLei) lì.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_spessore_tentacoli.gd

const LEVEL := "res://scenes/sala_principale.tscn"


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 400:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var lei := get_tree().current_scene.get_node(^"Gioco/LeiSbuca") as LeiSbuca
	var m := MorbidezzaLei.su(lei.medusa)
	var sk := m.get_parent() as Skeleton3D
	m.call(&"_catene_di", sk)
	var catene: Array = m.get(&"_catene")
	# osso -> [catena, indice]
	var dove := {}
	for k in catene.size():
		var c: PackedInt32Array = catene[k]
		for i in c.size():
			dove[c[i]] = [k, i]
	var sezioni := {}  # osso -> [indice, asse, scarti di traverso]
	var raggi := {}   # indice lungo la catena (0..n-1) -> Array di raggi
	var n_max := 0
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null or (mi as MeshInstance3D).skin == null:
			continue
		var skin := (mi as MeshInstance3D).skin
		# l'indice di bind -> osso dello scheletro
		var bind_osso := PackedInt32Array()
		for b in skin.get_bind_count():
			var nome := skin.get_bind_name(b)
			bind_osso.append(sk.find_bone(nome) if nome != "" else skin.get_bind_bone(b))
		var scala := ((mi as MeshInstance3D).global_basis.get_scale().x)
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			if a[Mesh.ARRAY_BONES] == null:
				continue
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bo = a[Mesh.ARRAY_BONES]
			var we = a[Mesh.ARRAY_WEIGHTS]
			var per := (bo as Array).size() / vs.size() if bo is Array else (bo as PackedInt32Array).size() / vs.size()
			for v in vs.size():
				var mig := -1
				var pm := 0.0
				for j in per:
					if float(we[v * per + j]) > pm:
						pm = float(we[v * per + j])
						mig = int(bo[v * per + j])
				if mig < 0:
					continue
				var osso := bind_osso[mig]
				if not dove.has(osso):
					continue
				var k: int = dove[osso][0]
				var i: int = dove[osso][1]
				var c: PackedInt32Array = catene[k]
				# il vertice nello spazio dello scheletro, a riposo: col bind dell'osso e la sua posa di riposo
				var rest := sk.get_bone_global_rest(osso)
				var q: Vector3 = rest * (skin.get_bind_pose(mig) * vs[v])
				var a0 := rest.origin
				var a1: Vector3 = sk.get_bone_global_rest(c[i + 1]).origin if i + 1 < c.size() else rest.origin + rest.basis.y.normalized() * (rest.origin - sk.get_bone_global_rest(c[i - 1]).origin).length()
				var d := Geometry3D.get_closest_point_to_segment(q, a0, a1).distance_to(q) * scala
				if not raggi.has(i):
					raggi[i] = []
				raggi[i].append(d)
				# lo scarto di traverso all'asse, per la sezione (larghezza e spessore) di ogni osso
				var asse := (a1 - a0).normalized()
				var off := (q - Geometry3D.get_closest_point_to_segment(q, a0, a1)) * scala
				off -= asse * off.dot(asse)
				if not sezioni.has(osso):
					sezioni[osso] = [i, asse, []]
				sezioni[osso][2].append(off)
				n_max = maxi(n_max, c.size())
	var rr: float = m.raggio_radice
	var rp: float = m.raggio_punta
	print("osso | vertici | mediano | 95% | massimo | raggio della morbidezza (cm)")
	for i in n_max:
		if not raggi.has(i):
			continue
		var l: Array = raggi[i]
		l.sort()
		var r_m := lerpf(rr, rp, (float(i) + 0.5) / n_max)
		print("%d | %d | %.1f | %.1f | %.1f | %.1f" % [i, l.size(), l[l.size() / 2] * 100.0, l[int(l.size() * 0.95)] * 100.0, l.back() * 100.0, r_m * 100.0])
	# la sezione: le due direzioni principali degli scarti (larghezza e spessore), al 95%
	var larg := {}
	var spes := {}
	for osso in sezioni:
		var i: int = sezioni[osso][0]
		var asse: Vector3 = sezioni[osso][1]
		var offs: Array = sezioni[osso][2]
		if offs.size() < 8:
			continue
		var u := asse.cross(Vector3.UP if absf(asse.y) < 0.9 else Vector3.RIGHT).normalized()
		var w := asse.cross(u).normalized()
		# covarianza 2D
		var cuu := 0.0
		var cww := 0.0
		var cuw := 0.0
		for o: Vector3 in offs:
			cuu += o.dot(u) * o.dot(u)
			cww += o.dot(w) * o.dot(w)
			cuw += o.dot(u) * o.dot(w)
		var ang := 0.5 * atan2(2.0 * cuw, cuu - cww)
		var e1 := u * cos(ang) + w * sin(ang)
		var e2 := asse.cross(e1).normalized()
		var p1 := []
		var p2 := []
		for o: Vector3 in offs:
			p1.append(absf(o.dot(e1)))
			p2.append(absf(o.dot(e2)))
		p1.sort()
		p2.sort()
		var a := maxf(p1[int(p1.size() * 0.95)], p2[int(p2.size() * 0.95)])
		var b := minf(p1[int(p1.size() * 0.95)], p2[int(p2.size() * 0.95)])
		if not larg.has(i):
			larg[i] = []
			spes[i] = []
		larg[i].append(a)
		spes[i].append(b)
	print("osso | mezza larghezza mediana / massima | mezzo spessore mediano / massimo (cm, 95% dei vertici di ogni osso)")
	for i in n_max:
		if not larg.has(i):
			continue
		var l: Array = larg[i]
		var t: Array = spes[i]
		l.sort()
		t.sort()
		print("%d | %.1f / %.1f | %.1f / %.1f" % [i, l[l.size() / 2] * 100.0, l.back() * 100.0, t[t.size() / 2] * 100.0, t.back() * 100.0])
	get_tree().quit()
