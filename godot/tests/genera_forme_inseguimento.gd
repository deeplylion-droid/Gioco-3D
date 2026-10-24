extends Node
## Genera assets/ambiente/inseguimento/inseguimento_forme_lei.json: le forme convesse (scatole) del mondo intorno a ogni
## posto dove lei sale nell'inseguimento, per la collisione dei tentacoli morbidi (MorbidezzaLei): la sala è un trimesh
## unico, e la morbidezza vuole forme convesse.
## Come (la collisione è un trimesh aperto: dentro e fuori non si sanno, si guardano solo le facce; le facce sono quelle
## delle collisioni e quelle delle mesh vere, tranne l'acqua: tests/corpi_dalle_mesh.gd):
## - i muri: raggi orizzontali corti nelle quattro direzioni degli assi, da una griglia di [constant PASSO] m in pianta e
##   in quota; i colpi su facce verticali dritte (normale lungo l'asse) si raggruppano per piano, e ogni gruppo diventa
##   una scatola spessa [constant SPESSORE] dietro la faccia, alta e larga quanto i colpi;
## - i pavimenti e le cime: la prima faccia dall'alto in ogni cella (rivolta in su), le celle vicine alla stessa quota
##   (a meno di [constant UNISCI]) diventano lastre spesse [constant SPESSORE] sotto la faccia, alte quanto la più alta.
## Poi si tolgono le scatole dentro un'altra e quelle più piccole di [constant MINIMA] m³.
## Le facce storte (i tubi tondi) non ci sono. Le scatole sono nelle coordinate della sala (SalaInseguimento).
## Da rilanciare quando cambia la struttura dell'inseguimento.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/genera_forme_inseguimento.gd

const LEVEL := "res://scenes/test/inseguimento_prova.tscn"
const USCITA := "res://assets/ambiente/inseguimento/inseguimento_forme_lei.json"
const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const MASCHERA := Layers.WORLD | CorpiMesh.STRATO   # le collisioni e le mesh vere
const PASSO := 0.1
const SOPRA := 2.5      # da quanto sopra il posto si guarda
const SOTTO := 5.6      # fino a quanto sotto (lei sale da 5 m sotto)
const SPESSORE := 0.3   # quanto sono spesse le scatole dietro le facce
const UNISCI := 0.04    # i pavimenti a meno di tanto si uniscono in una lastra (la cima è la più alta)
const MINIMA := 0.002   # le scatole più piccole (m³) non contano
const CELLA_OGGETTI := 0.75   # le celle in cui si dividono le mesh degli oggetti (m)
const FORO := 0.75      # il raggio del foro nel pavimento dove lei sale (m)

var spazio: PhysicsDirectSpaceState3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			break
	var sala := get_tree().current_scene.get_node("SalaInseguimento") as SalaInseguimento
	await get_tree().physics_frame
	# anche le mesh vere, non solo le collisioni (le pompe non hanno collisione; collaudo, 24 ottobre)
	print("corpi dalle mesh: ", CorpiMesh.crea(sala, AABB(Vector3(-1e4, -1e4, -1e4), Vector3(2e4, 2e4, 2e4)), sala.lei))
	await get_tree().physics_frame
	await get_tree().physics_frame
	spazio = sala.get_world_3d().direct_space_state
	var inv := sala.global_transform.affine_inverse()
	var posti := {}
	var L: Array = sala.dati["lei"]
	var pz: Array = sala.dati["pozzo"]["rett"]
	for k in 3:
		posti["vasca_%d" % k] = [sala.call(&"_posto_vasca", k), 3.0]
		posti["scolo_%d" % k] = [sala.call(&"_posto_scolo", k), 3.0]
	posti["grata"] = [SalaInseguimento.b(L[2]["pos"]), 3.0]
	# (sb1: lei sale dal lato del pozzo verso il giocatore: il centro del pozzo, più largo)
	posti["sb1"] = [SalaInseguimento.b([(pz[0] + pz[2]) / 2.0, (pz[1] + pz[3]) / 2.0, float(sala.dati["pozzo"]["bordo"])]), 3.8]
	var out := {}
	var fori := {}
	var convessi := {}
	var totale := 0
	for nome in posti:
		var c: Vector3 = posti[nome][0]
		var raggio: float = posti[nome][1]
		var scatole := _scatole(c, raggio)
		# lei sale da 5 m sotto: se lungo il suo asse c'è un pavimento (sale attraverso il pavimento allagato), lì sotto
		# niente lastre in un cerchio di FORO m, e il posto ha un "foro" (dove la morbidezza trattiene i tentacoli mentre
		# sale)
		var foro := []
		if nome != "sb1" and nome != "grata":
			var q := PhysicsRayQueryParameters3D.create(c, c + Vector3.DOWN * 4.8, MASCHERA)
			q.hit_back_faces = false
			var r := spazio.intersect_ray(q)
			# (solo se lei finisce a meno di 1,6 m sopra quel pavimento, o quella grata: dove finisce più in alto ci passa accanto)
			if not r.is_empty() and (r["normal"] as Vector3).y > 0.9 and (r["position"] as Vector3).y > c.y - 1.6:
				var yf: float = (r["position"] as Vector3).y
				var tenute := []
				for sc: AABB in scatole:
					var vicino := Vector2(clampf(c.x, sc.position.x, sc.end.x), clampf(c.z, sc.position.z, sc.end.z))
					if sc.end.y <= yf + 0.02 and sc.end.y > yf - 0.6 and vicino.distance_to(Vector2(c.x, c.z)) < FORO:
						continue
					tenute.append(sc)
				scatole = tenute
				var fi := inv * Vector3(c.x, yf, c.z)
				foro = [snappedf(fi.x, 0.001), snappedf(fi.y, 0.001), snappedf(fi.z, 0.001), FORO]
		var lista := []
		for s: AABB in scatole:
			# nelle coordinate della sala
			var a := inv * s.position
			var b := inv * s.end
			lista.append([snappedf(minf(a.x, b.x), 0.001), snappedf(minf(a.y, b.y), 0.001), snappedf(minf(a.z, b.z), 0.001),
					snappedf(maxf(a.x, b.x), 0.001), snappedf(maxf(a.y, b.y), 0.001), snappedf(maxf(a.z, b.z), 0.001)])
		out[nome] = lista
		# gli oggetti tondi vicini (le pompe, i tubi): la loro mesh in pezzi convessi, coi piani già fatti
		var cv := _convessi(sala, c, raggio, inv)
		if not cv.is_empty():
			convessi[nome] = cv
		if not foro.is_empty():
			fori[nome] = foro
		totale += lista.size()
		print("%s: %d scatole, %d pezzi convessi%s" % [nome, lista.size(), (convessi.get(nome, []) as Array).size(), (", foro nel pavimento a %.2f" % foro[1]) if not foro.is_empty() else ""])
	var f := FileAccess.open(USCITA, FileAccess.WRITE)
	f.store_string(JSON.stringify({"passo": PASSO, "posti": out, "fori": fori, "convessi": convessi}, "\t", true))
	f.close()
	print("scatole in tutto: %d, scritte in %s" % [totale, USCITA])
	get_tree().quit()


## Le scatole del mondo intorno a [param c] (in pianta fino a [param raggio], in quota da SOTTO sotto a SOPRA sopra).
func _scatole(c: Vector3, raggio: float) -> Array:
	var n := int(ceil(raggio / PASSO))
	var nq := int(ceil((SOPRA + SOTTO) / PASSO))
	var scatole := []
	# i muri: per asse (0 = x, 2 = z) e verso della normale, i colpi per piano (la coordinata al cm)
	var piani := {}     # "asse,verso,coordinata" -> Array di Vector2 (laterale, quota)
	var fuori := {}     # "asse,verso,coordinata" -> la coordinata della faccia (il colpo più verso fuori)
	for asse in [0, 2]:
		var altro: int = 2 - asse
		for verso in [-1.0, 1.0]:
			# il raggio va contro la normale: verso la faccia che guarda di qua
			var dir := Vector3.ZERO
			dir[asse] = -verso
			for i in range(-n, n + 1):
				for j in range(-n, n + 1):
					for h in nq + 1:
						var p := Vector3(c.x + i * PASSO, c.y - SOTTO + h * PASSO, c.z + j * PASSO)
						var q := PhysicsRayQueryParameters3D.create(p, p + dir * PASSO, MASCHERA)
						q.hit_back_faces = false
						var r := spazio.intersect_ray(q)
						if r.is_empty():
							continue
						var nr: Vector3 = r["normal"]
						if nr[asse] * verso < 0.98:
							continue
						var pos: Vector3 = r["position"]
						# (i piani si contano al cm: la faccia sta al colpo più verso fuori)
						var chiave := "%d,%d,%d" % [asse, int(verso), roundi(pos[asse] / 0.01)]
						if not piani.has(chiave):
							piani[chiave] = []
							fuori[chiave] = pos[asse]
						piani[chiave].append(Vector2(pos[altro], pos.y))
						fuori[chiave] = maxf(fuori[chiave], pos[asse]) if verso > 0.0 else minf(fuori[chiave], pos[asse])
	for chiave in piani:
		var parti: PackedStringArray = chiave.split(",")
		var asse := int(parti[0])
		var verso := float(parti[1])
		var coord: float = fuori[chiave]
		var altro: int = 2 - asse
		for gruppo in _gruppi(piani[chiave]):
			var lo := Vector3.ZERO
			var hi := Vector3.ZERO
			var r: Rect2 = gruppo
			lo[altro] = r.position.x
			hi[altro] = r.end.x
			lo.y = r.position.y
			hi.y = r.end.y
			# dietro la faccia, dentro il muro
			lo[asse] = coord - SPESSORE if verso > 0.0 else coord
			hi[asse] = coord if verso > 0.0 else coord + SPESSORE
			scatole.append(AABB(lo, hi - lo))
	# i pavimenti e le cime: la prima faccia in su dall'alto, cella per cella
	var quote := {}
	for i in range(-n, n):
		for j in range(-n, n):
			var p := Vector3(c.x + (i + 0.5) * PASSO, c.y + SOPRA, c.z + (j + 0.5) * PASSO)
			var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * (SOPRA + SOTTO), MASCHERA)
			q.hit_back_faces = false
			var r := spazio.intersect_ray(q)
			if r.is_empty() or (r["normal"] as Vector3).y < 0.9:
				continue
			quote[Vector2i(i, j)] = (r["position"] as Vector3).y
	var fatte := {}
	for j in range(-n, n):
		for i in range(-n, n):
			var cella := Vector2i(i, j)
			if not quote.has(cella) or fatte.has(cella):
				continue
			var y: float = quote[cella]
			var i1 := i
			while _va(quote, fatte, Vector2i(i1 + 1, j), y):
				i1 += 1
			var j1 := j
			while true:
				var tutta := true
				for ii in range(i, i1 + 1):
					if not _va(quote, fatte, Vector2i(ii, j1 + 1), y):
						tutta = false
						break
				if not tutta:
					break
				j1 += 1
			var ymax := y
			for jj in range(j, j1 + 1):
				for ii in range(i, i1 + 1):
					var q2: float = quote[Vector2i(ii, jj)]
					if absf(q2 - y) < UNISCI:
						fatte[Vector2i(ii, jj)] = true
						ymax = maxf(ymax, q2)
			var lo := Vector3(c.x + i * PASSO, ymax - SPESSORE, c.z + j * PASSO)
			var hi := Vector3(c.x + (i1 + 1) * PASSO, ymax, c.z + (j1 + 1) * PASSO)
			scatole.append(AABB(lo, hi - lo))
	# senza le scatole dentro un'altra e quelle piccolissime
	var tenute := []
	for k in scatole.size():
		var a: AABB = scatole[k]
		if a.get_volume() < MINIMA:
			continue
		var dentro := false
		for k2 in scatole.size():
			if k2 != k and (scatole[k2] as AABB).grow(0.005).encloses(a) and (k2 < k or not a.grow(0.005).encloses(scatole[k2])):
				dentro = true
				break
		if not dentro:
			tenute.append(a)
	return tenute


## Vero se la cella [param c] può stare nella lastra alla quota [param y]: alla stessa quota e non ancora in una lastra,
## o più alta (lì sopra il pavimento c'è qualcos'altro: la lastra ci passa sotto). Le celle più basse (un pozzo) o
## senza niente no.
func _va(quote: Dictionary, fatte: Dictionary, c: Vector2i, y: float) -> bool:
	if not quote.has(c):
		return false
	var q: float = quote[c]
	if absf(q - y) < UNISCI:
		return not fatte.has(c)
	return q > y


## I colpi di un piano (laterale, quota), in gruppi vicini (a meno di 1,5 passi): per ognuno il rettangolo che li
## contiene, allargato di mezzo passo (fino a dove arriva la faccia fra un raggio e l'altro).
func _gruppi(punti: Array) -> Array:
	# (su una griglia di un passo: i vicini sono le 8 celle intorno)
	var celle := {}
	for p: Vector2 in punti:
		var k := Vector2i(roundi(p.x / PASSO), roundi(p.y / PASSO))
		if not celle.has(k):
			celle[k] = []
		celle[k].append(p)
	var visti := {}
	var out := []
	for k0 in celle:
		if visti.has(k0):
			continue
		visti[k0] = true
		var coda: Array[Vector2i] = [k0]
		var r := Rect2(celle[k0][0], Vector2.ZERO)
		while not coda.is_empty():
			var k: Vector2i = coda.pop_back()
			for p: Vector2 in celle[k]:
				r = r.expand(p)
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var v := k + Vector2i(dx, dy)
					if celle.has(v) and not visti.has(v):
						visti[v] = true
						coda.append(v)
		if r.size.x >= PASSO * 0.5 or r.size.y >= PASSO * 0.5:
			out.append(r.grow(PASSO * 0.5))
	return out


## I pezzi convessi delle mesh degli oggetti intorno a [param c] (non la struttura, già nelle scatole, non l'acqua, non
## lei): i triangoli divisi in celle di [constant CELLA_OGGETTI] m (dal loro centro), e per ogni cella un poliedro di
## 26 facce (gli assi, le diagonali delle facce e degli spigoli) spinte fino al vertice più fuori: stretto intorno a un
## pezzo di tubo o di pompa, e coi piani già fatti. Nelle coordinate della sala:
## {"piani": [nx, ny, nz, d, ...], "lo": [x, y, z], "hi": [x, y, z]}.
func _convessi(sala: Node3D, c: Vector3, raggio: float, inv: Transform3D) -> Array:
	var zona := AABB(c - Vector3(raggio, SOTTO, raggio), Vector3(raggio * 2.0, SOTTO + SOPRA, raggio * 2.0))
	var struttura := sala.find_child("InseguimentoStruttura", true, false)
	var dirs: Array[Vector3] = []
	for d in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 1, 0), Vector3(1, -1, 0), Vector3(1, 0, 1),
			Vector3(1, 0, -1), Vector3(0, 1, 1), Vector3(0, 1, -1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, 1),
			Vector3(-1, 1, 1)]:
		dirs.append((d as Vector3).normalized())
	var out := []
	for mi in sala.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree() or (struttura and struttura.is_ancestor_of(m)) or sala.lei.is_ancestor_of(m):
			continue
		var nome := String(m.name).to_lower() + " " + String(m.get_parent().name).to_lower()
		if nome.contains("acqua") or nome.contains("bava") or nome.contains("water"):
			continue
		if not (m.global_transform * m.get_aabb()).intersects(zona):
			continue
		var celle := {}     # Vector3i -> PackedVector3Array (i vertici dei triangoli della cella, nel mondo)
		var xf := m.global_transform
		for k in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(k)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ind = arr[Mesh.ARRAY_INDEX]
			var n := (ind as PackedInt32Array).size() if ind != null else vs.size()
			for t in range(0, n - 2, 3):
				var a := xf * vs[ind[t] if ind != null else t]
				var b := xf * vs[ind[t + 1] if ind != null else t + 1]
				var cc := xf * vs[ind[t + 2] if ind != null else t + 2]
				var centro := (a + b + cc) / 3.0
				if not zona.grow(0.3).has_point(centro):
					continue
				var key := Vector3i((centro / CELLA_OGGETTI).floor())
				if not celle.has(key):
					celle[key] = PackedVector3Array()
				celle[key].append_array(PackedVector3Array([a, b, cc]))
		for key in celle:
			var punti: PackedVector3Array = celle[key]
			var pl := []
			var bb := AABB(punti[0], Vector3.ZERO)
			for q in punti:
				bb = bb.expand(q)
			for d in dirs:
				var mx := -INF
				var mn := INF
				for q in punti:
					var pr := q.dot(d)
					mx = maxf(mx, pr)
					mn = minf(mn, pr)
				for piano in [Plane(d, mx), Plane(-d, -mn)]:
					var lp: Plane = inv * piano
					pl.append_array([snappedf(lp.normal.x, 0.0001), snappedf(lp.normal.y, 0.0001), snappedf(lp.normal.z, 0.0001), snappedf(lp.d, 0.0001)])
			var a2 := inv * bb.position
			var b2 := inv * bb.end
			out.append({"piani": pl, "lo": [minf(a2.x, b2.x), minf(a2.y, b2.y), minf(a2.z, b2.z)], "hi": [maxf(a2.x, b2.x), maxf(a2.y, b2.y), maxf(a2.z, b2.z)]})
	return out
