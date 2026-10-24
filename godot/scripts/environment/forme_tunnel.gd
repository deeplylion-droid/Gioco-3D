class_name FormeTunnel
extends RefCounted
## Le forme del tunnel del viaggio sottomarino (SalaSottomarino) per i tentacoli morbidi di lei (MorbidezzaLei):
## dalla collisione vera del tunnel, i triangoli vicini allo spazio dove lei fluttua (sull'asse del canale, fino a
## mezza_larghezza_coi_tentacoli dall'asse, fra quota_bassa e quota_alta del JSON della strada), ognuno allungato in un
## prisma convesso spesso [constant SPESSORE] ([constant SPESSORE_PAVIMENTO] sotto i pavimenti) verso il pieno (dalla parte opposta allo spazio di lei). Più giù nella
## presa (lei sale da lì) e tutto in fondo all'approdo (lo schianto sul portello). I gommoni che dondolano sono forme
## che si muovono col loro corpo. Nell'inseguimento la sezione tiene lei lontana da tutto: le forme ci sono per quello
## che rientra nel suo spazio (gli ostacoli, la presa, il portello) e per sicurezza.
## Uso: mentre il tunnel si costruisce (dopo SalaSottomarino.costruisci_a_pezzi), await FormeTunnel.prepara_a_pezzi(sala):
## circa 1 s di calcolo, a pochi ms per fotogramma. Poi quando lei compare: la morbidezza (MorbidezzaLei.su(lei),
## quanto = 1, accendi()) e FormeTunnel.aggiungi(morbidezza, sala), qualche decina di ms. Se le forme non sono ancora
## pronte, aggiungi le prepara subito (un fotogramma lungo).

## Quanto oltre lo spazio di lei si prendono i triangoli (m): più delle sezioni più larghe dei tentacoli e di VICINO.
const OLTRE := 0.6
## Lo spessore dei prismi verso il pieno (m); sotto i pavimenti (le facce verso l'alto) di più: un tentacolo che
## nell'animazione passa sotto il fondo (la rampa della presa) torna su, non resta sotto il prisma.
const SPESSORE := 0.3
const SPESSORE_PAVIMENTO := 1.0
## In fondo all'approdo (gli ultimi metri della strada) si prende tutto, dal fondo del canale in su: lo schianto.
const FONDO_APPRODO := 14.0
## Cella della griglia dell'asse (m).
const CELLA := 2.0

## sala (instance id) -> [Array di [piani, AABB]]
static var _cache := {}


## Prepara (una volta per sala) le forme ferme, tutto subito (test, scene di prova). Restituisce quante sono.
static func prepara(sala: SalaSottomarino) -> int:
	var id := sala.get_instance_id()
	if _cache.has(id):
		return (_cache[id] as Array).size()
	var t0 := Time.get_ticks_msec()
	var ctx := _contesto(sala)
	for c3 in _forme_collisione(sala):
		var nt := _quanti(c3)
		_forme_di(c3, ctx, 0, nt)
	_cache[id] = ctx["forme"]
	print_verbose("FormeTunnel: %d forme in %d ms" % [(ctx["forme"] as Array).size(), Time.get_ticks_msec() - t0])
	return (ctx["forme"] as Array).size()


## Come [method prepara], ma al più [param ms_per_fotogramma] millisecondi per fotogramma (mentre il tunnel si
## costruisce, per non fermare il gioco). Da chiamare con await, dopo che il tunnel è costruito.
static func prepara_a_pezzi(sala: SalaSottomarino, ms_per_fotogramma := 4.0) -> int:
	var id := sala.get_instance_id()
	if _cache.has(id):
		return (_cache[id] as Array).size()
	var ctx := _contesto(sala)
	var t0 := Time.get_ticks_usec()
	for c3 in _forme_collisione(sala):
		var nt := _quanti(c3)
		var da := 0
		while da < nt:
			if not is_instance_valid(sala) or not sala.is_inside_tree():
				return 0
			var a := mini(da + 64, nt)
			_forme_di(c3, ctx, da, a)
			da = a
			if (Time.get_ticks_usec() - t0) / 1000.0 > ms_per_fotogramma:
				await sala.get_tree().process_frame
				t0 = Time.get_ticks_usec()
	if not _cache.has(id):
		_cache[id] = ctx["forme"]
	return (_cache[id] as Array).size()


## Quello che serve per scegliere i triangoli: lo spazio di lei allargato, l'asse in una griglia in pianta (per trovare
## il punto più vicino senza guardarli tutti), la presa e l'approdo, e le forme fatte fin qui.
static func _contesto(sala: SalaSottomarino) -> Dictionary:
	var lei: Dictionary = sala.dati["lei"]
	var asse: Array = sala.dati["asse"]
	var griglia := {}
	for i in asse.size():
		var a: Array = asse[i]["pos"]
		var k := Vector2i(floori(float(a[0]) / CELLA), floori(float(a[2]) / CELLA))
		# (un Array, non un PackedInt32Array: quello preso dal dizionario e convertito è una copia)
		if not griglia.has(k):
			griglia[k] = []
		(griglia[k] as Array).append(i)
	var lung := sala.lunghezza()
	return {"largo": float(lei["mezza_larghezza_coi_tentacoli"]) + OLTRE, "basso": float(lei["quota_bassa"]) - OLTRE,
		"alto": float(lei["quota_alta"]) + OLTRE, "lung": lung, "asse": asse, "griglia": griglia, "fondo": sala.fondo,
		"presa": sala.punto(0.0), "approdo": sala.punto(lung), "forme": []}


## Le forme di collisione ferme del tunnel (strato del mondo; i gommoni a parte).
static func _forme_collisione(sala: SalaSottomarino) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	for cs in sala.find_children("*", "CollisionShape3D", true, false):
		var c3 := cs as CollisionShape3D
		if c3.disabled or c3.shape == null or c3.get_parent() is AnimatableBody3D:
			continue
		var co := c3.get_parent() as CollisionObject3D
		if co == null or (co.collision_layer & Layers.WORLD) == 0:
			continue
		out.append(c3)
	return out


## Quanti pezzi da guardare in [param c3]: i triangoli di una trimesh, 1 per le forme convesse.
static func _quanti(c3: CollisionShape3D) -> int:
	if c3.shape is ConcavePolygonShape3D:
		return (c3.shape as ConcavePolygonShape3D).get_faces().size() / 3
	return 1


## Le forme dai triangoli da [param da] ad [param a] di [param c3] (o la forma convessa intera), in ctx["forme"].
static func _forme_di(c3: CollisionShape3D, ctx: Dictionary, da: int, a_: int) -> void:
	var largo: float = ctx["largo"]
	var basso: float = ctx["basso"]
	var alto: float = ctx["alto"]
	var lung: float = ctx["lung"]
	var asse: Array = ctx["asse"]
	var griglia: Dictionary = ctx["griglia"]
	var presa: Vector3 = ctx["presa"]
	var approdo: Vector3 = ctx["approdo"]
	var forme: Array = ctx["forme"]
	var xf := c3.global_transform
	if not c3.shape is ConcavePolygonShape3D:
		# le forme convesse (i modelli degli ostacoli, le scatole): intere, se toccano lo spazio di lei
		var pc := _punti_convessi(c3.shape)
		if pc.is_empty():
			return
		var mondo := PackedVector3Array()
		for q in pc:
			mondo.append(xf * q)
		var vicina := false
		for q in mondo:
			if _nello_spazio(q, asse, griglia, largo, basso, alto, lung, ctx["fondo"]):
				vicina = true
				break
		if vicina:
			var pl := _piani(mondo)
			if pl.size() >= 4:
				var bbc := AABB(mondo[0], Vector3.ZERO)
				for q in mondo:
					bbc = bbc.expand(q)
				forme.append([pl, bbc])
		return
	var facce := (c3.shape as ConcavePolygonShape3D).get_faces()
	for t in range(da, a_):
		var a := xf * facce[t * 3]
		var b := xf * facce[t * 3 + 1]
		var c := xf * facce[t * 3 + 2]
		# (prima, solo con le quote: sopra lo spazio di lei, o sotto lontano dalla presa e dall'approdo, no)
		var ymin := minf(a.y, minf(b.y, c.y))
		var ymax := maxf(a.y, maxf(b.y, c.y))
		if ymin > alto:
			continue
		if ymax < basso:
			var cc := (a + b + c) / 3.0
			var vicino_presa := Vector2(cc.x - presa.x, cc.z - presa.z).length() < largo + SalaSottomarino.PRESA_FINO + 6.0
			var vicino_approdo := Vector2(cc.x - approdo.x, cc.z - approdo.z).length() < largo + FONDO_APPRODO + 2.0
			if not vicino_presa and not vicino_approdo:
				continue
		# vicino allo spazio di lei? (i vertici e i punti di mezzo dei lati)
		var dentro := false
		var q_vicino := Vector3.ZERO
		for p: Vector3 in [a, b, c, (a + b) * 0.5, (b + c) * 0.5, (c + a) * 0.5, (a + b + c) / 3.0]:
			var pr := _vicino(p, asse, griglia)
			if pr.is_empty():
				continue
			var s: float = pr[0]
			var lo := basso
			if s <= SalaSottomarino.PRESA_FINO + 1.0:
				lo = SalaSottomarino.PRESA_FONDO - OLTRE
			elif s >= lung - FONDO_APPRODO:
				lo = float(ctx["fondo"]) - OLTRE
			if float(pr[1]) <= largo and p.y >= lo and p.y <= alto:
				dentro = true
				q_vicino = Vector3(float(pr[2].x), clampf(p.y, lo + OLTRE, alto - OLTRE), float(pr[2].z))
				break
		if not dentro:
			continue
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-10:
			continue
		n = n.normalized()
		# verso lo spazio di lei (fuori dal pieno)
		var centro := (a + b + c) / 3.0
		if n.dot(q_vicino - centro) < 0.0:
			n = -n
		forme.append(_prisma(a, b, c, n))


## Dà a [param m] le forme del tunnel [param sala] (ferme e i gommoni che si muovono). Restituisce quante.
static func aggiungi(m: MorbidezzaLei, sala: SalaSottomarino) -> int:
	prepara(sala)
	var n := 0
	for fo in _cache[sala.get_instance_id()]:
		m.aggiungi_piani(fo[0], fo[1])
		n += 1
	# i gommoni: una scatola sola per gommone, quella di tutta la sua collisione (tubolare, fondo, sedili) nel sistema
	# del corpo che dondola: lei ci passa sopra (10 cm sopra le punte), e sopra il buco del tubolare non entra niente
	for g in sala.get(&"_gommoni"):
		var corpo := (g as Dictionary)["corpo"] as Node3D
		var bb := AABB()
		var primo := true
		for cs in corpo.find_children("*", "CollisionShape3D", false, false):
			var c3 := cs as CollisionShape3D
			for q in _punti_convessi(c3.shape):
				if primo:
					bb = AABB(c3.transform * q, Vector3.ZERO)
					primo = false
				else:
					bb = bb.expand(c3.transform * q)
		if not primo:
			m.aggiungi_mobile_piani(corpo, _piani_scatola(bb), bb)
			n += 1
	return n


## I sei piani (verso fuori) della scatola [param bb].
static func _piani_scatola(bb: AABB) -> Array[Plane]:
	var a := bb.position
	var b := bb.end
	var out: Array[Plane] = [Plane(Vector3.RIGHT, b.x), Plane(Vector3.LEFT, -a.x), Plane(Vector3.UP, b.y),
		Plane(Vector3.DOWN, -a.y), Plane(Vector3.BACK, b.z), Plane(Vector3.FORWARD, -a.z)]
	return out


## Il prisma del triangolo a, b, c spesso SPESSORE dalla parte opposta a [param n]: [piani verso fuori, AABB].
static func _prisma(a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> Array:
	var sp := SPESSORE_PAVIMENTO if n.y > 0.7 else SPESSORE
	var piani: Array[Plane] = [Plane(n, a), Plane(-n, a - n * sp)]
	for lato in [[a, b, c], [b, c, a], [c, a, b]]:
		var p0: Vector3 = lato[0]
		var p1: Vector3 = lato[1]
		var opp: Vector3 = lato[2]
		var nl := (p1 - p0).cross(n).normalized()
		if nl.dot(opp - p0) > 0.0:
			nl = -nl
		piani.append(Plane(nl, p0))
	var bb := AABB(a, Vector3.ZERO).expand(b).expand(c)
	bb = bb.merge(AABB(a - n * sp, Vector3.ZERO).expand(b - n * sp).expand(c - n * sp))
	return [piani, bb]


## Il campione dell'asse più vicino a [param p] in pianta: [s, distanza in pianta, posizione], o vuoto se lontano.
static func _vicino(p: Vector3, asse: Array, griglia: Dictionary) -> Array:
	var k0 := Vector2i(floori(p.x / CELLA), floori(p.z / CELLA))
	var best := INF
	var bi := -1
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var cella := k0 + Vector2i(dx, dz)
			if not griglia.has(cella):
				continue
			for i: int in griglia[cella]:
				var q: Array = asse[i]["pos"]
				var d := Vector2(p.x - float(q[0]), p.z - float(q[2])).length_squared()
				if d < best:
					best = d
					bi = i
	if bi < 0:
		return []
	var q: Array = asse[bi]["pos"]
	return [float(asse[bi]["s"]), sqrt(best), Vector3(float(q[0]), float(q[1]), float(q[2]))]


## Vero se il punto [param p] è nello spazio di lei allargato (vedi [method prepara]).
static func _nello_spazio(p: Vector3, asse: Array, griglia: Dictionary, largo: float, basso: float, alto: float,
		lung: float, fondo: float) -> bool:
	var pr := _vicino(p, asse, griglia)
	if pr.is_empty():
		return false
	var s: float = pr[0]
	var lo := basso
	if s <= SalaSottomarino.PRESA_FINO + 1.0:
		lo = SalaSottomarino.PRESA_FONDO - OLTRE
	elif s >= lung - FONDO_APPRODO:
		lo = fondo - OLTRE
	return float(pr[1]) <= largo and p.y >= lo and p.y <= alto


## I punti (nel sistema della forma) di una forma convessa: i punti del poligono convesso (oltre 40, la sua scatola),
## gli spigoli della scatola, un prisma di 12 lati fuori dal cilindro o dalla capsula; vuoto per le altre.
static func _punti_convessi(sh: Shape3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if sh is ConvexPolygonShape3D:
		out = (sh as ConvexPolygonShape3D).points
		if out.size() > 40:
			var bb := AABB(out[0], Vector3.ZERO)
			for q in out:
				bb = bb.expand(q)
			out = PackedVector3Array()
			for k in 8:
				out.append(bb.get_endpoint(k))
	elif sh is BoxShape3D:
		var m := (sh as BoxShape3D).size * 0.5
		for k in 8:
			out.append(Vector3(m.x if k & 1 else -m.x, m.y if k & 2 else -m.y, m.z if k & 4 else -m.z))
	elif sh is CylinderShape3D or sh is CapsuleShape3D:
		var r: float = sh.radius / cos(PI / 12.0)
		var h: float = sh.height * 0.5
		for k in 12:
			var ang := TAU * k / 12.0
			out.append(Vector3(cos(ang) * r, -h, sin(ang) * r))
			out.append(Vector3(cos(ang) * r, h, sin(ang) * r))
	return out


## I piani (verso fuori) dell'involucro convesso di [param punti] (pochi punti: le facce da ogni terna).
static func _piani(punti: PackedVector3Array) -> Array[Plane]:
	var piani: Array[Plane] = []
	var nn := punti.size()
	for a in nn:
		for b in range(a + 1, nn):
			for c in range(b + 1, nn):
				var nrm := (punti[b] - punti[a]).cross(punti[c] - punti[a])
				if nrm.length() < 1e-6:
					continue
				var pl := Plane(nrm.normalized(), punti[a])
				var sopra := 0
				var sotto := 0
				for q in punti:
					var d := pl.distance_to(q)
					if d > 1e-4:
						sopra += 1
					elif d < -1e-4:
						sotto += 1
				if sopra > 0 and sotto > 0:
					continue
				if sopra > 0:
					pl = -pl
				var doppio := false
				for e in piani:
					if e.normal.dot(pl.normal) > 0.9999 and absf(e.d - pl.d) < 1e-4:
						doppio = true
						break
				if not doppio:
					piani.append(pl)
	return piani
