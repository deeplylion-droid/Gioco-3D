extends Node
## Trova i triangoli che mancano nella mesh torre_A di torre_struttura.glb e li salva in SalaTorre.TOPPE, che il gioco
## rimette costruendo la torre (SalaTorre._toppe_torre_A), con la collisione. Mancano perché l'intaglio col booleano di
## tools/blender/torre_a.py toglie facce dove crede di essere dentro (ambienti-2, 6 novembre): dai buchi nelle pareti e
## nel tetto si vedeva il cielo. Nella 0.3.22 ambienti-2 corregge il generatore e le toppe vanno via.
## Un triangolo mancante è un giro di 3 spigoli di bordo (spigoli con una faccia sola, in tutta la mesh, saldando i
## vertici per posizione): il triangolo nuovo gira al contrario dei vicini (stessa faccia davanti) e prende da loro
## normali, tangenti, UV e colori dei vertici, e la superficie (il materiale). I giri più lunghi (aperture vere, come il
## foro dell'oblò) non si toccano: si stampano.
## Da rifare quando cambia torre_struttura.glb. Con "controlla" non scrive: confronta.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/aggiorna_toppe_torre.gd [controlla]

const GLB := "res://assets/ambiente/torre/torre_struttura.glb"
const MESH := "torre_A"
## Le superfici dove i giri di tre spigoli sono buchi verso il cielo: 0 pavimento, 1 soffitto, 2 vasca, 3 muro.
const SUPERFICIE_MAX := 3
## Un vicino dà normale, UV e tangente a un angolo solo se la sua normale è allineata alla faccia.
const ALLINEATA := 0.9


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var glb := (load(GLB) as PackedScene).instantiate()
	add_child(glb)
	var mi := glb.find_child(MESH, true, false) as MeshInstance3D
	var corpi := mi.find_children("*", "CollisionShape3D", true, false)
	print("TOPPE: %s, superfici %d, forme di collisione figlie %d" % [MESH, mi.mesh.get_surface_count(), corpi.size()])
	var toppe := calcola(mi.mesh)
	for s: Dictionary in toppe["superfici"]:
		s["materiale"] = mi.get_active_material(int(s["superficie"])).resource_name
	var testo := JSON.stringify(toppe, " ")
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and args[1] == "controlla":
		var vecchio = JSON.parse_string(FileAccess.get_file_as_string(SalaTorre.TOPPE)) if FileAccess.file_exists(SalaTorre.TOPPE) else null
		var uguale: bool = vecchio != null and JSON.stringify(vecchio, " ") == JSON.stringify(JSON.parse_string(testo), " ")
		print(("ok  " if uguale else "KO  ") + "le toppe salvate di torre_A corrispondono alla mesh")
		get_tree().quit(0 if uguale else 1)
		return
	var f := FileAccess.open(SalaTorre.TOPPE, FileAccess.WRITE)
	f.store_string(testo)
	f.close()
	print("TOPPE: scritto %s" % SalaTorre.TOPPE)
	get_tree().quit()


## Il triangolo di [param arr] nel piano della faccia (normale allineata, a meno di 1 cm) più vicino a [param centro].
static func _faccia_nel_piano(arr: Array, centro: Vector3, n_ref: Vector3) -> int:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx = arr[Mesh.ARRAY_INDEX]
	var n_tri: int = ((idx as PackedInt32Array).size() if idx != null else v.size()) / 3
	var meglio := -1
	var d_meglio := INF
	for t in n_tri:
		var a: Vector3 = v[idx[t * 3]] if idx != null else v[t * 3]
		var b: Vector3 = v[idx[t * 3 + 1]] if idx != null else v[t * 3 + 1]
		var c: Vector3 = v[idx[t * 3 + 2]] if idx != null else v[t * 3 + 2]
		var nf := -((b - a).cross(c - a))
		if nf.length() < 1e-6 or nf.normalized().dot(n_ref) < ALLINEATA or absf((centro - a).dot(n_ref)) > 0.01:
			continue
		var dist := centro.distance_to((a + b + c) / 3.0)
		if dist < d_meglio:
			d_meglio = dist
			meglio = t
	return meglio


## Le coordinate [param quale] (UV o UV2) in [param p] con la mappa affine del triangolo [param t] (nel suo piano).
static func _uv_nel_piano(arr: Array, quale: int, t: int, p: Vector3) -> Vector2:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[quale]
	var idx = arr[Mesh.ARRAY_INDEX]
	var i0: int = idx[t * 3] if idx != null else t * 3
	var i1: int = idx[t * 3 + 1] if idx != null else t * 3 + 1
	var i2: int = idx[t * 3 + 2] if idx != null else t * 3 + 2
	var e1 := v[i1] - v[i0]
	var e2 := v[i2] - v[i0]
	var q := p - v[i0]
	var d11 := e1.dot(e1)
	var d12 := e1.dot(e2)
	var d22 := e2.dot(e2)
	var den := d11 * d22 - d12 * d12
	if absf(den) < 1e-12:
		return uvs[i0]
	var a := (q.dot(e1) * d22 - q.dot(e2) * d12) / den
	var b := (q.dot(e2) * d11 - q.dot(e1) * d12) / den
	return uvs[i0] + (uvs[i1] - uvs[i0]) * a + (uvs[i2] - uvs[i0]) * b


static func _r(x: float) -> float:
	return snappedf(x, 0.00001)


static func calcola(mesh: Mesh) -> Dictionary:
	var ids := {}           # posizione saldata -> id
	var arrays := []
	var lato := {}          # spigolo non orientato (a, b) -> quante facce
	var orientati := {}     # spigolo orientato del buco (b -> a) -> [superficie, vertice di b, vertice di a]
	var da := {}            # id -> ids raggiungibili lungo gli spigoli del buco
	var tris := []
	var pos_id := {}        # id -> posizione
	var per_pos := {}       # id -> [[superficie, vertice], ...]
	var scartati := []
	var proiettati := 0
	var degeneri := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		arrays.append(arr)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var vid := PackedInt64Array()
		vid.resize(v.size())
		for i in v.size():
			var k := Vector3i((v[i] * 2000.0).round())
			if not ids.has(k):
				ids[k] = ids.size()
				pos_id[ids[k]] = v[i]
			vid[i] = ids[k]
			if not per_pos.has(ids[k]):
				per_pos[ids[k]] = []
			(per_pos[ids[k]] as Array).append([s, i])
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
		for t in idx.size() / 3:
			tris.append([s, idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2], vid[idx[t * 3]], vid[idx[t * 3 + 1]], vid[idx[t * 3 + 2]]])
	for tr: Array in tris:
		for e in 3:
			var a: int = tr[4 + e]
			var b: int = tr[4 + (e + 1) % 3]
			var k := mini(a, b) * 10000000 + maxi(a, b)
			lato[k] = int(lato.get(k, 0)) + 1
	for tr: Array in tris:
		for e in 3:
			var a: int = tr[4 + e]
			var b: int = tr[4 + (e + 1) % 3]
			if a == b or int(lato[mini(a, b) * 10000000 + maxi(a, b)]) != 1:
				continue
			orientati[b * 10000000 + a] = [tr[0], tr[1 + (e + 1) % 3], tr[1 + e]]
			if not da.has(b):
				da[b] = []
			(da[b] as Array).append(a)
	var per_sup := {}
	var buchi := []
	var fatti := {}
	var usati := {}
	for k: int in orientati:
		var u := k / 10000000
		var v := k % 10000000
		for w: int in da.get(v, []):
			if not orientati.has(w * 10000000 + u) or w == u:
				continue
			var chiave := [u, v, w]
			chiave.sort()
			if fatti.has(str(chiave)):
				continue
			fatti[str(chiave)] = true
			var e1: Array = orientati[u * 10000000 + v]
			var e2: Array = orientati[v * 10000000 + w]
			var e3: Array = orientati[w * 10000000 + u]
			for e: int in [u * 10000000 + v, v * 10000000 + w, w * 10000000 + u]:
				usati[e] = true
			# la superficie: quella dei vicini (la più presente)
			var conta := {}
			for e: Array in [e1, e2, e3]:
				conta[e[0]] = int(conta.get(e[0], 0)) + 1
			var s: int = e1[0]
			for c: int in conta:
				if conta[c] > conta[s]:
					s = c
			# solo i buchi verso il cielo: pavimento, soffitto, vasca e muro (ambienti-2, 7 novembre). Sulle altre
			# superfici (inox, metallo, giochi, scivoli) i giri di tre spigoli sono anelli fra pezzi che si toccano,
			# col giro al contrario delle normali: come gli anelli di docs/tecnico/varchi_cielo/LEGGIMI.md, si lasciano
			if s > SUPERFICIE_MAX:
				scartati.append([s, u, v, w])
				continue
			var pu: Vector3 = pos_id[u]
			var pv: Vector3 = pos_id[v]
			var pw: Vector3 = pos_id[w]
			# tre punti in fila (area sotto 1 cm², fra pezzi che si toccano lungo uno spigolo): non c'è niente da chiudere
			if (pv - pu).cross(pw - pu).length() < 2e-4:   # sotto 1 cm²
				degeneri += 1
				continue
			# la normale della faccia (davanti in senso orario, come il motore)
			var n_ref := -((pv - pu).cross(pw - pu)).normalized()
			# ogni angolo dal vertice della stessa superficie, in quel punto, con la normale allineata alla faccia
			# (un angolo sullo spigolo fra due pareti non la prende dalla parete perpendicolare)
			var angoli := []
			for c: int in [u, v, w]:
				var meglio := -1
				var d_meglio := ALLINEATA
				for cand: Array in per_pos.get(c, []):
					if int(cand[0]) != s:
						continue
					var nn: Vector3 = (arrays[s][Mesh.ARRAY_NORMAL] as PackedVector3Array)[cand[1]]
					if nn.dot(n_ref) > d_meglio:
						d_meglio = nn.dot(n_ref)
						meglio = cand[1]
				angoli.append(meglio)
			var arr: Array = arrays[s]
			var vicina := -1
			if angoli.has(-1):
				vicina = _faccia_nel_piano(arr, (pu + pv + pw) / 3.0, n_ref)
				proiettati += 1
				if vicina < 0:
					push_warning("toppa senza faccia vicina nel piano: superficie %d, centro %s" % [s, (pu + pv + pw) / 3.0])
					continue
			if not per_sup.has(s):
				per_sup[s] = {"superficie": s, "v": [], "n": [], "t": [], "uv": [], "uv2": [], "c": []}
			var d: Dictionary = per_sup[s]
			var pos := [pu, pv, pw]
			var idx_v = arr[Mesh.ARRAY_INDEX]
			for j in 3:
				var p3: Vector3 = pos[j]
				var i: int = angoli[j]
				if vicina >= 0:
					i = int(idx_v[vicina * 3]) if idx_v != null else vicina * 3
				(d["v"] as Array).append_array([_r(p3.x), _r(p3.y), _r(p3.z)])
				var n: Vector3 = n_ref if vicina >= 0 else (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array)[i]
				(d["n"] as Array).append_array([_r(n.x), _r(n.y), _r(n.z)])
				if arr[Mesh.ARRAY_TANGENT] != null:
					var ta: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
					(d["t"] as Array).append_array([_r(ta[i * 4]), _r(ta[i * 4 + 1]), _r(ta[i * 4 + 2]), _r(ta[i * 4 + 3])])
				for quale: int in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
					if arr[quale] == null:
						continue
					var uv: Vector2 = _uv_nel_piano(arr, quale, vicina, p3) if vicina >= 0 else (arr[quale] as PackedVector2Array)[i]
					(d["uv" if quale == Mesh.ARRAY_TEX_UV else "uv2"] as Array).append_array([_r(uv.x), _r(uv.y)])
				if arr[Mesh.ARRAY_COLOR] != null:
					var c: Color = (arr[Mesh.ARRAY_COLOR] as PackedColorArray)[i]
					(d["c"] as Array).append_array([_r(c.r), _r(c.g), _r(c.b), _r(c.a)])
			var area := 0.5 * ((pos[1] - pos[0]) as Vector3).cross(pos[2] - pos[0]).length()
			var centro: Vector3 = (pos[0] + pos[1] + pos[2]) / 3.0
			buchi.append({"superficie": s, "centro": [_r(centro.x), _r(centro.y), _r(centro.z)], "area": snappedf(area, 0.001)})
	# gli spigoli di bordo rimasti: aperture vere o buchi con più di 3 lati (non si toccano)
	var resto := 0
	for k: int in orientati:
		if not usati.has(k):
			resto += 1
	buchi.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["area"] > b["area"])
	var area_tot := 0.0
	for bu: Dictionary in buchi:
		area_tot += float(bu["area"])
	print("TOPPE: triangoli mancanti %d (%.2f m2), spigoli di bordo rimasti (aperture, non toccati) %d" % [buchi.size(), area_tot, resto])
	print("TOPPE: lasciati (anelli su superfici oltre la %d) %d; in fila (area zero) %d; con normali e UV proiettati dalla faccia vicina nel piano %d" % [
			SUPERFICIE_MAX, scartati.size(), degeneri, proiettati])
	for bu: Dictionary in buchi.slice(0, 40):
		print("TOPPE:   superficie %d centro %s area %.3f m2" % [bu["superficie"], bu["centro"], bu["area"]])
	var sup := []
	var chiavi := per_sup.keys()
	chiavi.sort()
	for s: int in chiavi:
		var d: Dictionary = per_sup[s]
		for nome: String in ["n", "t", "uv", "uv2", "c"]:
			if (d[nome] as Array).is_empty():
				d.erase(nome)
		sup.append(d)
	return {"mesh": MESH, "superfici": sup, "buchi": buchi}
