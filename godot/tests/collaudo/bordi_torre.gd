extends Node
## Classifica gli spigoli di bordo aperti (con una faccia sola, saldando i vertici per posizione) delle mesh della
## struttura della torre: torre_A con le toppe (SalaTorre._toppe_torre_A), torre_A_sostegni, torre_A_grigliati.
## 1. le giunzioni a T: un bordo che sta sulla retta di altri bordi aperti, coperto da loro per tutta la lunghezza, non è
##    un buco (fra scatole che si toccano, dopo remove_doubles);
## 2. con quelli che restano, gli anelli chiusi (area e centro, dalla somma vettoriale);
## 3. per gli anelli sopra 0,01 m², se si vedono dalla strada: raggi dagli occhi dei checkpoint e dai punti della discesa
##    (torre_percorso.json) verso il centro, coi corpi fatti dalle mesh vere; si vede se il raggio passa
##    dal centro senza toccare niente (un buco vero: dietro c'è altro; una lastra a una faccia sola invece si tocca lì).
## Stampa BORDI:. Uso (headless, sotto il render.lock):
##   godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/bordi_torre.gd

const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const MESH := ["torre_A", "torre_A_sostegni", "torre_A_grigliati"]
const OCCHI := 1.6
const SCALA := 2000.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	torre.crea_luci = false
	add_child(torre)
	for i in 10:
		await get_tree().physics_frame
	CorpiMesh.crea(torre, AABB(Vector3(-100, -100, -100), Vector3(300, 300, 300)))
	for i in 3:
		await get_tree().physics_frame
	var spazio := torre.get_world_3d().direct_space_state
	# i punti di vista: gli occhi dei checkpoint e i punti della discesa
	var viste: Array = []
	for c in torre.find_children("*", "Checkpoint", true, false):
		viste.append([String(c.name), (c as Checkpoint).get_spawn_transform().origin + Vector3.UP * OCCHI])
	var punti: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ambiente/torre/torre_percorso.json"))
	for q: Dictionary in punti:
		if q["cosa"] == "scivolo" or q["cosa"] == "pedana":
			viste.append(["discesa " + String(q["cosa"]), SalaTorre.b([q["x"], q["y"], q["z"]]) + Vector3.UP * 1.0])
	print("BORDI: punti di vista %d" % viste.size())
	for nome: String in MESH:
		var mi := torre.find_child(nome, true, false) as MeshInstance3D
		if mi == null:
			print("BORDI: %s non c'è" % nome)
			continue
		var mesh_list: Array = [mi]
		var toppe := mi.get_node_or_null(^"torre_A_toppe") as MeshInstance3D
		if toppe:
			mesh_list.append(toppe)
		_analizza(nome, mesh_list, mi.global_transform, spazio, viste)
	get_tree().quit()


func _analizza(nome: String, mesh_list: Array, xf: Transform3D, spazio: PhysicsDirectSpaceState3D, viste: Array) -> void:
	var ids := {}
	var pos: Array[Vector3] = []
	var lato := {}
	var orientati: Array = []     # [da, a] del buco (al contrario del triangolo)
	var tris: Array = []
	for m: MeshInstance3D in mesh_list:
		var verso := xf.affine_inverse() * m.global_transform
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var vid := PackedInt32Array()
			vid.resize(v.size())
			for i in v.size():
				var p := xf * (verso * v[i])
				var k := Vector3i((p * SCALA).round())
				if not ids.has(k):
					ids[k] = pos.size()
					pos.append(p)
				vid[i] = ids[k]
			var idx = arr[Mesh.ARRAY_INDEX]
			var n: int = (idx as PackedInt32Array).size() if idx != null else v.size()
			for t in n / 3:
				var a: int = vid[idx[t * 3]] if idx != null else vid[t * 3]
				var b: int = vid[idx[t * 3 + 1]] if idx != null else vid[t * 3 + 1]
				var c: int = vid[idx[t * 3 + 2]] if idx != null else vid[t * 3 + 2]
				tris.append(Vector3i(a, b, c))
	for tr: Vector3i in tris:
		for e in 3:
			var a: int = tr[e]
			var b: int = tr[(e + 1) % 3]
			if a == b:
				continue
			var k := mini(a, b) * 10000000 + maxi(a, b)
			lato[k] = int(lato.get(k, 0)) + 1
	for tr: Vector3i in tris:
		for e in 3:
			var a: int = tr[e]
			var b: int = tr[(e + 1) % 3]
			if a != b and int(lato[mini(a, b) * 10000000 + maxi(a, b)]) == 1:
				orientati.append([b, a])
	# 1. giunzioni a T: per retta (direzione e distanza dall'origine, arrotondate), gli intervalli coperti dagli altri
	var rette := {}
	for i in orientati.size():
		var e: Array = orientati[i]
		var p0 := pos[e[0]]
		var p1 := pos[e[1]]
		var d := (p1 - p0).normalized()
		if d.x < -1e-4 or (absf(d.x) <= 1e-4 and (d.y < -1e-4 or (absf(d.y) <= 1e-4 and d.z < 0.0))):
			d = -d
		var o := p0 - d * p0.dot(d)
		var k := str(Vector3i((d * 200.0).round())) + str(Vector3i((o * 100.0).round()))
		if not rette.has(k):
			rette[k] = []
		(rette[k] as Array).append([i, d, p0.dot(d), p1.dot(d)])
	var a_t := {}
	for k: String in rette:
		var lista: Array = rette[k]
		if lista.size() < 2:
			continue
		for x: Array in lista:
			var lo := minf(x[2], x[3])
			var hi := maxf(x[2], x[3])
			var pezzi: Array = []
			for y: Array in lista:
				if y[0] == x[0]:
					continue
				var plo := maxf(minf(y[2], y[3]), lo)
				var phi := minf(maxf(y[2], y[3]), hi)
				if phi > plo:
					pezzi.append([plo, phi])
			pezzi.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
			var fino := lo
			for p: Array in pezzi:
				if p[0] > fino + 0.002:
					break
				fino = maxf(fino, p[1])
			if fino >= hi - 0.002:
				a_t[x[0]] = true
	# 2. anelli coi bordi che restano
	var da := {}
	for i in orientati.size():
		if a_t.has(i):
			continue
		var e: Array = orientati[i]
		if not da.has(e[0]):
			da[e[0]] = []
		(da[e[0]] as Array).append(i)
	var usato := {}
	var anelli: Array = []
	var aperti := 0
	for i in orientati.size():
		if a_t.has(i) or usato.has(i):
			continue
		var giro: Array[int] = []
		var j := i
		var chiuso := false
		while true:
			usato[j] = true
			giro.append(j)
			var fine: int = orientati[j][1]
			if fine == orientati[i][0]:
				chiuso = true
				break
			var dopo := -1
			for c: int in da.get(fine, []):
				if not usato.has(c):
					dopo = c
					break
			if dopo < 0 or giro.size() > 5000:
				break
			j = dopo
		if not chiuso:
			aperti += 1
			continue
		var somma := Vector3.ZERO
		var centro := Vector3.ZERO
		var lunghezza := 0.0
		for g in giro:
			var p0 := pos[orientati[g][0]]
			var p1 := pos[orientati[g][1]]
			somma += p0.cross(p1)
			centro += p0
			lunghezza += p0.distance_to(p1)
		centro /= giro.size()
		anelli.append({"area": somma.length() * 0.5, "centro": centro, "lati": giro.size(), "giro": lunghezza,
				"normale": somma.normalized()})
	var grandi := anelli.filter(func(a: Dictionary) -> bool: return a["area"] > 0.01)
	grandi.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["area"] > b["area"])
	print("BORDI: %s: spigoli di bordo %d, giunzioni a T %d, restano %d; anelli chiusi %d (sopra 0,01 m2: %d), catene non chiuse %d" % [
			nome, orientati.size(), a_t.size(), orientati.size() - a_t.size(), anelli.size(), grandi.size(), aperti])
	# 3. si vedono dalla strada?
	var visti := 0
	for a: Dictionary in grandi:
		var c: Vector3 = a["centro"]
		var da_dove := ""
		for v: Array in viste:
			var occhio: Vector3 = v[1]
			if occhio.distance_to(c) > 60.0:
				continue
			var q := PhysicsRayQueryParameters3D.create(occhio, c + (c - occhio).normalized() * 0.3)
			q.hit_back_faces = true
			var h := spazio.intersect_ray(q)
			if h.is_empty() or (h.position as Vector3).distance_to(occhio) > occhio.distance_to(c) + 0.03:
				da_dove = "%s (%.1f m)" % [v[0], occhio.distance_to(c)]
				break
		if da_dove != "":
			visti += 1
		print("BORDI:   %s anello %s area %.3f m2, %d lati, giro %.2f m, normale %s, %s" % [nome, c.snapped(Vector3.ONE * 0.01),
				a["area"], a["lati"], a["giro"], (a["normale"] as Vector3).snapped(Vector3.ONE * 0.01),
				"SI VEDE da " + da_dove if da_dove != "" else "non si vede"])
	print("BORDI: %s: anelli sopra 0,01 m2 che si vedono dalla strada %d" % [nome, visti])
