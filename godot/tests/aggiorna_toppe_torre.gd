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


static func _r(x: float) -> float:
	return snappedf(x, 0.00001)


static func calcola(mesh: Mesh) -> Dictionary:
	var ids := {}           # posizione saldata -> id
	var arrays := []
	var lato := {}          # spigolo non orientato (a, b) -> quante facce
	var orientati := {}     # spigolo orientato del buco (b -> a) -> [superficie, vertice di b, vertice di a]
	var da := {}            # id -> ids raggiungibili lungo gli spigoli del buco
	var tris := []
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
			vid[i] = ids[k]
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
			# ogni angolo dal vicino della stessa superficie che ce l'ha
			var angoli := []
			for coppia: Array in [[e1, 1, e3, 2], [e2, 1, e1, 2], [e3, 1, e2, 2]]:
				var p: Array = coppia[0]
				var q: Array = coppia[2]
				if int(p[0]) == s:
					angoli.append([s, p[coppia[1]]])
				elif int(q[0]) == s:
					angoli.append([s, q[coppia[3]]])
				else:
					angoli.append([p[0], p[coppia[1]]])
			if not per_sup.has(s):
				per_sup[s] = {"superficie": s, "v": [], "n": [], "t": [], "uv": [], "uv2": [], "c": []}
			var d: Dictionary = per_sup[s]
			var pos := []
			for an: Array in angoli:
				var arr: Array = arrays[an[0]]
				var i: int = an[1]
				var p3: Vector3 = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)[i]
				pos.append(p3)
				(d["v"] as Array).append_array([_r(p3.x), _r(p3.y), _r(p3.z)])
				if arr[Mesh.ARRAY_NORMAL] != null:
					var n: Vector3 = (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array)[i]
					(d["n"] as Array).append_array([_r(n.x), _r(n.y), _r(n.z)])
				if arr[Mesh.ARRAY_TANGENT] != null:
					var ta: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
					(d["t"] as Array).append_array([_r(ta[i * 4]), _r(ta[i * 4 + 1]), _r(ta[i * 4 + 2]), _r(ta[i * 4 + 3])])
				if arr[Mesh.ARRAY_TEX_UV] != null:
					var uv: Vector2 = (arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array)[i]
					(d["uv"] as Array).append_array([_r(uv.x), _r(uv.y)])
				if arr[Mesh.ARRAY_TEX_UV2] != null:
					var uv2: Vector2 = (arr[Mesh.ARRAY_TEX_UV2] as PackedVector2Array)[i]
					(d["uv2"] as Array).append_array([_r(uv2.x), _r(uv2.y)])
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
